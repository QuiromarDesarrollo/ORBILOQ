$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    dart compile js -O2 --no-source-maps tools/ciclos_excel_worker.dart -o web/ciclos_excel_worker.js
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el lector de ciclos.' }
    Remove-Item -LiteralPath 'web/ciclos_excel_worker.js.deps' -ErrorAction SilentlyContinue
} finally { Pop-Location }
