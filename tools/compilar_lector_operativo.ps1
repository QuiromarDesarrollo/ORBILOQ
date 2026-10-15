$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    dart compile js -O2 --no-source-maps tools/operativo_excel_worker.dart -o web/operativo_excel_worker.js
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el lector operativo.' }
    Remove-Item -LiteralPath 'web/operativo_excel_worker.js.deps' -ErrorAction SilentlyContinue
} finally { Pop-Location }
