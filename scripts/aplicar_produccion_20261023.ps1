# Ejecutar solo durante la pausa confirmada. No publica el frontend.
param([switch]$PausaConfirmada)
$ErrorActionPreference = 'Stop'
if (!$PausaConfirmada) { throw 'Falta confirmar que los usuarios sincronizaron y cerraron ORBILOQ.' }
$repo = Split-Path $PSScriptRoot -Parent
$pg = 'C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin'
$sql = Join-Path $repo 'sql\produccion\013_actualizacion_20261023.sql'
$check = Join-Path $repo 'sql\produccion\014_verificar_actualizacion_20261023.sql'
if ((Get-FileHash $sql).Hash -ne '4FD2B4230C6E5167919035CACEBE0A99D53C129EACE33EC6234300D6C94F192C') { throw 'Cambió la migración ensayada.' }
if ((Get-FileHash $check).Hash -ne '93D79A081AA231DCC1CF8712A02C7A77DE66DDAEE8152410D4C37AF1AF2D3615') { throw 'Cambió la verificación.' }
$anterior = $env:PGPASSWORD
$secreto = Read-Host 'Contrasena PostgreSQL de PRODUCCION (no se mostrara)' -AsSecureString
$ptr = [IntPtr]::Zero
try {
 $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secreto)
 $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 $root = 'D:\ORBILOQ-respaldos\final-20261023-' + (Get-Date -Format 'HHmmss')
 & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'respaldo_produccion.ps1') -BackupRoot $root -UsarCredencialEntorno
 if ($LASTEXITCODE -ne 0) { throw 'Fallo respaldo final; no se aplica SQL.' }
 $backup = (Get-ChildItem -LiteralPath $root -Directory | Select-Object -First 1).FullName
 $conn = 'host=aws-0-us-west-2.pooler.supabase.com port=5432 dbname=postgres user=postgres.cxrflhgnxvomcvxzugda sslmode=require connect_timeout=20 application_name=orbiloq_despliegue_20261023'
 $antes = Join-Path $backup 'datos-antes.sql'
 & "$pg\pg_restore.exe" --data-only --file=$antes (Join-Path $backup 'produccion.dump')
 if ($LASTEXITCODE -ne 0) { throw 'Fallo lectura del respaldo final.' }
 # Exige que todos los objetos del respaldo final estén en el ZIP verificado.
 & 'C:\Users\analistadatos\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' (Join-Path $PSScriptRoot 'verificar_storage_20261023.py') --snapshot $antes --dest (Join-Path $backup 'storage')
 if ($LASTEXITCODE -ne 0) { throw 'Respaldo de adjuntos incompleto; no aplicar.' }
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -qAt -f (Join-Path $repo 'sql\produccion\010_diagnostico_20261015.sql') -o (Join-Path $backup 'diagnostico-antes.json')
 if ($LASTEXITCODE -ne 0) { throw 'Fallo diagnóstico previo.' }
 $diag = Get-Content (Join-Path $backup 'diagnostico-antes.json') -Raw | ConvertFrom-Json
 if (@($diag.nuevas_instaladas.PSObject.Properties | Where-Object { -not $_.Value }).Count -gt 0) { throw 'Falta parte del despliegue anterior; revisar antes de continuar.' }
 Write-Host 'Respaldo final completo. Aplicando únicamente migración incremental ensayada.'
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $sql *> (Join-Path $backup 'migracion.log')
 if ($LASTEXITCODE -ne 0) { throw "Migración no confirmada; revisar $backup\migracion.log. NO repetir sin diagnóstico." }
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $check *> (Join-Path $backup 'verificacion.log')
 if ($LASTEXITCODE -ne 0) { throw 'Migración aplicada, pero falló verificación. No publicar; revisar verificacion.log.' }
 $despues = Join-Path $backup 'datos-despues.sql'
 & "$pg\pg_dump.exe" --dbname=$conn --no-password --data-only --file=$despues 2> (Join-Path $backup 'dump-despues.log')
 if ($LASTEXITCODE -ne 0) { throw 'Migración aplicada, pero falló exportación posterior. No publicar.' }
 & (Join-Path $PSScriptRoot 'comparar_datos_migracion.ps1') -Antes $antes -Despues $despues -Informe (Join-Path $backup 'comparacion-final.csv')
 [ordered]@{fecha_utc=[DateTime]::UtcNow.ToString('o');project='cxrflhgnxvomcvxzugda';backup=$backup;migracion='aplicada_y_verificada';frontend='pendiente';sql_sha256=(Get-FileHash $sql).Hash} | ConvertTo-Json | Set-Content (Join-Path $backup 'resultado.json') -Encoding UTF8
 Write-Host "ACTUALIZACION SQL VERIFICADA. Evidencia: $backup"
 Write-Host 'Mantener pausa hasta que se publique y verifique el frontend.'
} finally {
 $env:PGPASSWORD = $anterior
 if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
 $secreto.Dispose()
}

