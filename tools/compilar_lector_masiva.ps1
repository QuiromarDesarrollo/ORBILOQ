$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    dart compile js -O2 --no-source-maps tools/masiva_excel_worker.dart -o web/masiva_excel_worker.js
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el lector de Masiva.' }
    Remove-Item -LiteralPath 'web/masiva_excel_worker.js.deps' -ErrorAction SilentlyContinue
} finally { Pop-Location }
