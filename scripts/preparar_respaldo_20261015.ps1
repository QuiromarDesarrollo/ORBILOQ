# Ejecutar en una terminal interactiva. Solo lectura de produccion.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$pg = 'C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin'
$anterior = $env:PGPASSWORD
$secreto = Read-Host 'Contrasena PostgreSQL de PRODUCCION (no se mostrara)' -AsSecureString
$ptr = [IntPtr]::Zero
try {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secreto)
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $destino = 'D:\ORBILOQ-respaldos\preparacion-20261015-' + (Get-Date -Format 'HHmmss')
    # El proceso hijo evita que un exit del exportador cierre esta limpieza.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'respaldo_produccion.ps1') -BackupRoot $destino -UsarCredencialEntorno
    if ($LASTEXITCODE -ne 0) { throw 'El respaldo no finalizo. No desplegar.' }
    $copia = Get-ChildItem -LiteralPath $destino -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $conexion = 'host=aws-0-us-west-2.pooler.supabase.com port=5432 dbname=postgres user=postgres.cxrflhgnxvomcvxzugda sslmode=require connect_timeout=20 application_name=orbiloq_diagnostico_lectura'
    & "$pg\psql.exe" -X -w --dbname=$conexion -v ON_ERROR_STOP=1 -q -t -A -f (Join-Path $repo 'sql\produccion\010_diagnostico_20261015.sql') -o (Join-Path $copia.FullName 'diagnostico-20261015.json')
    if ($LASTEXITCODE -ne 0) { throw 'Respaldo exportado, pero fallo el diagnostico. No desplegar.' }
    Write-Host "Respaldo y diagnostico guardados en: $($copia.FullName)"
    Write-Host 'Falta verificar restauracion y archivos de Storage. Esta copia no sustituye el respaldo final durante la pausa.'
} finally {
    $env:PGPASSWORD = $anterior
    if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    $secreto.Dispose()
}
