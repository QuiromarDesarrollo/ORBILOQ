# Ejecutar solo durante la pausa confirmada. No publica el frontend.
param([switch]$PausaConfirmada)
$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = 'ORBILOQ - DESPLIEGUE ACTUAL'
Write-Host 'ORBILOQ - DESPLIEGUE ACTUAL. Version corregida: mensajes NOTICE permitidos.'
function Get-FileHash([string]$Path) {
 $sha = [Security.Cryptography.SHA256]::Create()
 $stream = [IO.File]::OpenRead($Path)
 try { [pscustomobject]@{Hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')} }
 finally { $stream.Dispose(); $sha.Dispose() }
}
if (!$PausaConfirmada) { throw 'Falta confirmar que los usuarios sincronizaron y cerraron ORBILOQ.' }
$repo = Split-Path $PSScriptRoot -Parent
$pg = 'C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin'
$sql = Join-Path $repo 'sql\produccion\015_actualizacion_20261030.sql'
$check = Join-Path $repo 'sql\produccion\016_verificar_actualizacion_20261030.sql'
if ((Get-FileHash $sql).Hash -ne '7A5531C0DC88276B8E6E830F858AF95A0E7BB163E7898831E20EB0FE019C67D0') { throw 'Cambió la migración ensayada.' }
if ((Get-FileHash $check).Hash -ne '8243CAB896C9A959512188BC076CB50DB21FB348BE15E43295F37F007EB7EAF7') { throw 'Cambió la verificación.' }
$anterior = $env:PGPASSWORD
$secreto = Read-Host 'Contrasena PostgreSQL de PRODUCCION (no se mostrara)' -AsSecureString
$ptr = [IntPtr]::Zero
try {
 $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secreto)
 $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 # Solo se reintenta la exportacion de lectura; nunca se reintenta la migracion.
 $respaldoOk = $false
 for ($intento = 1; $intento -le 3; $intento++) {
  $root = 'D:\ORBILOQ-respaldos\final-20261030-' + (Get-Date -Format 'HHmmss') + '-' + $intento
  Write-Host "Respaldo final: intento $intento de 3. No se modifica la base."
  & 'powershell.exe' -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'respaldo_produccion.ps1') -BackupRoot $root -UsarCredencialEntorno
  if ($LASTEXITCODE -eq 0) { $respaldoOk = $true; break }
  if ($intento -lt 3) { Start-Sleep -Seconds 3 }
 }
 if (!$respaldoOk) { throw 'Fallo respaldo final; no se aplica SQL.' }
 $backup = (Get-ChildItem -LiteralPath $root -Directory | Select-Object -First 1).FullName
 $conn = 'host=aws-0-us-west-2.pooler.supabase.com port=5432 dbname=postgres user=postgres.cxrflhgnxvomcvxzugda sslmode=require connect_timeout=20 application_name=orbiloq_despliegue_20261030'
 $antes = Join-Path $backup 'datos-antes.sql'
 & "$pg\pg_restore.exe" --data-only --file=$antes (Join-Path $backup 'produccion.dump')
 if ($LASTEXITCODE -ne 0) { throw 'Fallo lectura del respaldo final.' }
 # La migracion no escribe Storage; los metadatos originales se comparan dentro de la transaccion.
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -qAt -f (Join-Path $repo 'sql\produccion\010_diagnostico_20261015.sql') -o (Join-Path $backup 'diagnostico-antes.json')
 if ($LASTEXITCODE -ne 0) { throw 'Fallo diagnóstico previo.' }
 $diag = Get-Content (Join-Path $backup 'diagnostico-antes.json') -Raw | ConvertFrom-Json
 if (@($diag.nuevas_instaladas.PSObject.Properties | Where-Object { -not $_.Value }).Count -gt 0) { throw 'Falta parte del despliegue anterior; revisar antes de continuar.' }
 Write-Host 'Respaldo final completo. Aplicando únicamente migración incremental ensayada.'
 # Windows PowerShell convierte NOTICE de stderr en errores terminantes.
 # Conservar el mensaje, pero decidir exito por el codigo de psql (ON_ERROR_STOP).
 $ErrorActionPreference = 'Continue'
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $sql *> (Join-Path $backup 'migracion.log')
 $ErrorActionPreference = 'Stop'
 if ($LASTEXITCODE -ne 0) { throw "Migración no confirmada; revisar $backup\migracion.log. NO repetir sin diagnóstico." }
 $ErrorActionPreference = 'Continue'
 & "$pg\psql.exe" -X -w --dbname=$conn -v ON_ERROR_STOP=1 -f $check *> (Join-Path $backup 'verificacion.log')
 $ErrorActionPreference = 'Stop'
 if ($LASTEXITCODE -ne 0) { throw 'Migración aplicada, pero falló verificación. No publicar; revisar verificacion.log.' }
 $despues = Join-Path $backup 'datos-despues.sql'
 & "$pg\pg_dump.exe" --dbname=$conn --no-password --data-only --file=$despues 2> (Join-Path $backup 'dump-despues.log')
 if ($LASTEXITCODE -ne 0) { throw 'Migración aplicada, pero falló exportación posterior. No publicar.' }
 [IO.File]::WriteAllText((Join-Path $repo '.dart_tool/produccion-20261030-aplicada.txt'), $backup)
 & (Join-Path $PSScriptRoot 'comparar_datos_migracion.ps1') -Antes $antes -Despues $despues -Informe (Join-Path $backup 'comparacion-final.csv')
 [ordered]@{fecha_utc=[DateTime]::UtcNow.ToString('o');project='cxrflhgnxvomcvxzugda';backup=$backup;migracion='aplicada_y_verificada';frontend='pendiente';sql_sha256=(Get-FileHash $sql).Hash} | ConvertTo-Json | Set-Content (Join-Path $backup 'resultado.json') -Encoding UTF8
 Write-Host "ACTUALIZACION SQL VERIFICADA. Evidencia: $backup"
 Write-Host 'Mantener pausa hasta que se publique y verifique el frontend.'
} finally {
 $env:PGPASSWORD = $anterior
 if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
 $secreto.Dispose()
}


Read-Host 'Pulsa Enter al terminar'
