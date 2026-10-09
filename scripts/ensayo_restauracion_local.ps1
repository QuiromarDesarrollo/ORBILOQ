param(
 [Parameter(Mandatory=$true)][string]$Backup,
 [string]$DiagnosticoSql = '',
 [string]$MigracionSql = '',
 [string]$PruebaSql = ''
)
$ErrorActionPreference = 'Stop'
$bin = 'C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin'
$backup = (Resolve-Path -LiteralPath $Backup).Path
foreach ($name in @('produccion.dump','roles.sql')) {
 if (!(Test-Path -LiteralPath (Join-Path $backup $name))) { throw "Falta $name en el respaldo seleccionado" }
}
$dest = Join-Path 'D:\' ('ORBILOQ-restauracion-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$null = New-Item -ItemType Directory -Path $dest
# Restrict the local copy (including Auth data) to this Windows account.
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $dest /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo proteger el directorio local.' }
$data = Join-Path $dest 'data'
$pw = Join-Path $dest 'clave-temporal.txt'
$started = $false
$previousPassword = $env:PGPASSWORD
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$env:PGPASSWORD = [Convert]::ToBase64String($bytes)
[IO.File]::WriteAllText($pw, $env:PGPASSWORD, [Text.Encoding]::ASCII)
try {
    & "$bin\initdb.exe" -D $data -U postgres --auth=scram-sha-256 --encoding=UTF8 --locale=C -c timezone=UTC "--pwfile=$pw" *> (Join-Path $dest 'initdb.log')
    if ($LASTEXITCODE -ne 0) { throw 'Falló initdb; revisar initdb.log.' }
    Remove-Item -LiteralPath $pw
    & "$bin\pg_ctl.exe" -D $data -l (Join-Path $dest 'servidor.log') -o '-h 127.0.0.1 -p 55432' -w start
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar el servidor local.' }
    $started = $true
    $conn = 'host=127.0.0.1 port=55432 dbname=postgres user=postgres sslmode=disable connect_timeout=10'
    $roleStatements = @('CREATE DATABASE ensayo;')
    foreach ($line in Get-Content -LiteralPath (Join-Path $backup 'roles.sql')) {
        if ($line -match '^CREATE ROLE (.+);$' -and $Matches[1] -ne 'postgres') {
            $roleStatements += ('CREATE ROLE ' + $Matches[1] + ' NOLOGIN;')
        }
    }
    $rolesPath = Join-Path $dest 'roles-locales.sql'
    [IO.File]::WriteAllLines($rolesPath, $roleStatements, [Text.UTF8Encoding]::new($false))
    & "$bin\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $rolesPath *> (Join-Path $dest 'roles.log')
    if ($LASTEXITCODE -ne 0) { throw 'Falló la preparación de roles locales.' }
    $conn = 'host=127.0.0.1 port=55432 dbname=ensayo user=postgres sslmode=disable connect_timeout=10'
    $toc = Get-Content -LiteralPath (Join-Path $backup 'contenido.txt')
    $excluded = @($toc | Where-Object { $_ -cmatch 'EXTENSION.*supabase_vault|\svault\s|\sEVENT TRIGGER\s|\sPUBLICATION(?: TABLE| TABLES IN SCHEMA)?\s|\sSUBSCRIPTION\s' -and $_ -notmatch '^;' })
    [IO.File]::WriteAllLines((Join-Path $dest 'objetos-excluidos.txt'), $excluded, [Text.UTF8Encoding]::new($false))
    $filtered = @($toc | Where-Object { $_ -notin $excluded })
    $list = Join-Path $dest 'restaurar.list'
    [IO.File]::WriteAllLines($list, $filtered, [Text.UTF8Encoding]::new($false))
    & "$bin\pg_restore.exe" --dbname=$conn --no-password --no-owner --no-privileges --use-list=$list (Join-Path $backup 'produccion.dump') *> (Join-Path $dest 'restauracion.log')
    $restoreExit = $LASTEXITCODE
    if ($DiagnosticoSql -ne '') {
        if ($restoreExit -ne 0) { throw 'No ejecutar diagnóstico sobre una restauración con errores.' }
        & "$bin\psql.exe" -X -w --dbname=$conn -qAt -v ON_ERROR_STOP=1 -f $DiagnosticoSql 1> (Join-Path $dest 'diagnostico.json') 2> (Join-Path $dest 'diagnostico-errores.log')
        if ($LASTEXITCODE -ne 0) { throw 'Falló el diagnóstico de solo lectura.' }
    }
    # Extract COPY blocks locally to compare the exact snapshot counts, not a later production state.
    $sqlData = Join-Path $dest 'datos-verificacion.sql'
    & "$bin\pg_restore.exe" --data-only --no-owner --no-privileges --file=$sqlData (Join-Path $backup 'produccion.dump')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer el contenido de datos del respaldo.' }
    $expected = @{}
    $currentTable = $null
    foreach ($line in [IO.File]::ReadLines($sqlData)) {
        if ($line -match '^COPY (.+?) \(.+\) FROM stdin;$') {
            $currentTable = $Matches[1]
            $expected[$currentTable] = 0L
        } elseif ($line -eq '\.') { $currentTable = $null }
        elseif ($null -ne $currentTable) { $expected[$currentTable]++ }
    }
    $checks = @()
    foreach ($table in ($expected.Keys | Sort-Object)) {
        if ($table -like 'vault.*') { continue }
        $actual = & "$bin\psql.exe" -X -w --dbname=$conn -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM $table;" 2>> (Join-Path $dest 'verificacion-errores.log')
        $ok = $LASTEXITCODE -eq 0
        $checks += [pscustomobject]@{ tabla=$table; filas_respaldo=$expected[$table]; filas_restauradas= $(if ($ok) { [long]$actual } else { $null }); coincide=($ok -and [long]$actual -eq $expected[$table]) }
    }
    $checks | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $dest 'conteos.csv')
    $localData = Join-Path $dest 'datos-locales.sql'
    & "$bin\pg_dump.exe" --dbname=$conn --no-password --data-only --no-owner --no-privileges --file=$localData 2> (Join-Path $dest 'exportacion-local.log')
    if ($LASTEXITCODE -ne 0) { throw 'Falló la exportación de verificación local.' }
    function Get-CopyHashes([string]$path) {
        $result = @{}
        $table = $null
        $rows = [Collections.Generic.List[string]]::new()
        foreach ($line in [IO.File]::ReadLines($path)) {
            if ($line -match '^COPY (.+?) \(.+\) FROM stdin;$') {
                $table = $Matches[1]
                $rows.Clear()
            } elseif ($line -eq '\.' -and $null -ne $table) {
                $arr = $rows.ToArray()
                [Array]::Sort($arr, [StringComparer]::Ordinal)
                $hash = [Security.Cryptography.SHA256]::Create()
                $result[$table] = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $arr)))).Replace('-', '')
                $hash.Dispose()
                $table = $null
            } elseif ($null -ne $table) { $rows.Add($line) }
        }
        return $result
    }
    $originalHashes = Get-CopyHashes $sqlData
    $restoredHashes = Get-CopyHashes $localData
    $hashChecks = @($checks | ForEach-Object {
        [pscustomobject]@{ tabla=$_.tabla; coincide=($originalHashes[$_.tabla] -eq $restoredHashes[$_.tabla]); sha256_respaldo=$originalHashes[$_.tabla]; sha256_local=$restoredHashes[$_.tabla] }
    })
    $hashChecks | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $dest 'contenido-comparado.csv')
    $report = [ordered]@{ fecha_utc=[DateTime]::UtcNow.ToString('o'); destino=$dest; codigo_restauracion=$restoreExit; tablas_comparadas=$checks.Count; tablas_coincidentes=@($checks | Where-Object coincide).Count; filas_respaldo=($checks | Measure-Object filas_respaldo -Sum).Sum; objetos_excluidos=$excluded.Count; alcance='Ensayo PostgreSQL local, roles NOLOGIN, sin propietarios ni ACL originales. No valida servicios Supabase, Storage físico, Vault ni políticas de acceso de producción.' }
    $report['tablas_con_contenido_identico'] = @($hashChecks | Where-Object coincide).Count
    $report | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $dest 'resultado.json')
    $report | ConvertTo-Json -Compress
    if ($restoreExit -ne 0 -or @($checks | Where-Object { -not $_.coincide }).Count -gt 0 -or @($hashChecks | Where-Object { -not $_.coincide }).Count -gt 0) {
        throw 'El ensayo tiene diferencias o errores. Revisar resultado.json; no considerar validada la restauración.'
    }
    if ($MigracionSql -ne '') {
        $aclList = Join-Path $dest 'permisos.list'
        [IO.File]::WriteAllLines($aclList, [string[]]@($filtered | Where-Object { $_ -match '\s(?:DEFAULT )?ACL\s' }), [Text.UTF8Encoding]::new($false))
        & "$bin\pg_restore.exe" --dbname=$conn --no-password --no-owner --use-list=$aclList (Join-Path $backup 'produccion.dump') *> (Join-Path $dest 'permisos.log')
        if ($LASTEXITCODE -ne 0) { throw 'No se pudieron restaurar los permisos para las pruebas locales.' }
        & "$bin\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -c 'CREATE PUBLICATION supabase_realtime FOR TABLE public.usuarios,public.ubicaciones,public.causales_devolucion,public.personal_logistica,public.personal_produccion,public.personal_aliados,public.items_orden,public.ordenes_produccion;' *> (Join-Path $dest 'publicacion-local.log')
        if ($LASTEXITCODE -ne 0) { throw 'Falló la preparación de la publicación local.' }
        # Only the disposable localhost database above can receive this migration.
        $migrationPath = (Resolve-Path -LiteralPath $MigracionSql).Path
        & "$bin\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $migrationPath *> (Join-Path $dest 'migracion.log')
        if ($LASTEXITCODE -ne 0) { throw 'La migración falló en la copia local. Revisar migracion.log; producción no fue modificada.' }
        $after = Join-Path $dest 'datos-despues.sql'
        & "$bin\pg_dump.exe" --dbname=$conn --no-password --data-only --no-owner --no-privileges --file=$after 2> (Join-Path $dest 'exportacion-despues.log')
        if ($LASTEXITCODE -ne 0) { throw 'Falló la exportación posterior.' }
        & (Join-Path $PSScriptRoot 'comparar_datos_migracion.ps1') -Antes $localData -Despues $after -Informe (Join-Path $dest 'comparacion-migracion.csv') -PermitirBucketSeguimiento
        if ($PruebaSql -ne '') {
            & "$bin\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f (Resolve-Path -LiteralPath $PruebaSql).Path *> (Join-Path $dest 'pruebas.log')
            if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas funcionales locales; revisar pruebas.log.' }
            Write-Output 'Pruebas funcionales locales: correctas.'
        }
    }
} finally {
    if (Test-Path -LiteralPath $pw) { Remove-Item -LiteralPath $pw }
    if ($started) { & "$bin\pg_ctl.exe" -D $data -m fast -w stop }
    $env:PGPASSWORD = $previousPassword
    Write-Output "Archivos del ensayo: $dest"
}
