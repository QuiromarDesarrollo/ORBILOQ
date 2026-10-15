$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    dart compile js -O2 --no-source-maps tools/ordenes_excel_worker.dart -o web/ordenes_excel_worker.js
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el lector ERP.' }
    Remove-Item -LiteralPath 'web/ordenes_excel_worker.js.deps' -ErrorAction SilentlyContinue
} finally { Pop-Location }
