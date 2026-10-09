# Solo exporta. No ejecuta SQL de escritura ni restaura sobre ninguna base.
# Ejecutar interactivamente: PostgreSQL pide la contraseña sin mostrarla.
[CmdletBinding()]
param(
    [string]$BackupRoot = 'D:\ORBILOQ-respaldos',
    [switch]$UsarCredencialEntorno
)

$ErrorActionPreference = 'Stop'
if ($UsarCredencialEntorno -and !$env:PGPASSWORD) { throw 'Falta la credencial temporal de PostgreSQL.' }
$passwordOption = if ($UsarCredencialEntorno) { '--no-password' } else { '--password' }
$pgBin = 'C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin'
$connection = 'host=aws-0-us-west-2.pooler.supabase.com port=5432 dbname=postgres user=postgres.cxrflhgnxvomcvxzugda sslmode=require connect_timeout=20 application_name=orbiloq_respaldo'
$backupDir = Join-Path $backupRoot ('produccion-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))

foreach ($tool in @('pg_dump.exe', 'pg_dumpall.exe', 'pg_restore.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $pgBin $tool))) { throw "Falta $tool en $pgBin" }
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $backupDir /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo proteger la carpeta del respaldo.' }
$dumpPartial = Join-Path $backupDir 'produccion.dump.partial'
$dumpFinal = Join-Path $backupDir 'produccion.dump'
$rolesPartial = Join-Path $backupDir 'roles.sql.partial'
$rolesFinal = Join-Path $backupDir 'roles.sql'
$toc = Join-Path $backupDir 'contenido.txt'
$started = [DateTime]::UtcNow.ToString('o')

try {
    Write-Host 'PRODUCCION: cxrflhgnxvomcvxzugda. Solo lectura.'
    Write-Host "Destino privado (no subir a GitHub): $backupDir"
    Write-Host '1/3 Exportando estructura y datos.'
    & (Join-Path $pgBin 'pg_dump.exe') --dbname=$connection $passwordOption --format=custom --lock-wait-timeout=30s --file=$dumpPartial
    if ($LASTEXITCODE -ne 0) { throw 'pg_dump falló. El archivo parcial NO es un respaldo utilizable.' }
    if ((Get-Item -LiteralPath $dumpPartial).Length -eq 0) { throw 'El archivo exportado está vacío.' }

    Write-Host '2/3 Exportando roles sin sus contraseñas.'
    & (Join-Path $pgBin 'pg_dumpall.exe') --dbname=$connection $passwordOption --roles-only --no-role-passwords --file=$rolesPartial
    if ($LASTEXITCODE -ne 0) { throw 'Falló la exportación de roles. Conservar los archivos y revisar antes de continuar.' }

    Write-Host '3/3 Leyendo el índice local del archivo. No se conecta para restaurar.'
    & (Join-Path $pgBin 'pg_restore.exe') --list --file=$toc $dumpPartial
    if ($LASTEXITCODE -ne 0) { throw 'pg_restore no pudo leer el índice del archivo.' }

    Move-Item -LiteralPath $dumpPartial -Destination $dumpFinal
    Move-Item -LiteralPath $rolesPartial -Destination $rolesFinal
    $manifest = [ordered]@{
        proyecto = 'cxrflhgnxvomcvxzugda'
        inicio_utc = $started
        fin_utc = [DateTime]::UtcNow.ToString('o')
        estado = 'exportacion_finalizada_pendiente_prueba_restauracion'
        archivos = @(Get-FileHash -LiteralPath $dumpFinal,$rolesFinal,$toc -Algorithm SHA256 | Select-Object Path,Algorithm,Hash)
        notas = @(
            'Leer el índice no demuestra que todos los datos puedan restaurarse. Falta ensayo en una base separada.',
            'No incluye archivos de Supabase Storage, código o secretos de Edge Functions ni configuración externa.',
            'Roles exportados sin contraseñas. No aplicar roles del servicio gestionado ciegamente a otro proyecto.',
            'No es el respaldo final del despliegue si se registran nuevas operaciones después de esta copia.',
            'El archivo puede contener datos personales y de Auth. Mantener privado; no subir a GitHub.'
        )
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupDir 'resumen.json') -Encoding UTF8
    Write-Host "EXPORTACION FINALIZADA: $backupDir"
    Write-Host 'Pendiente: revisar advertencias y probar restauración en una base separada. No desplegar todavía.'
} catch {
    Write-Host "RESPALDO NO VALIDADO. Archivos conservados en: $backupDir"
    Write-Host $_.Exception.Message
    exit 1
}
