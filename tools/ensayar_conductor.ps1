param([string]$PgBin='C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dest=Join-Path $repo ('.dart_tool\conductor-sql-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $dest
$data=Join-Path $dest 'data'
$started=$false
try {
 & "$PgBin\initdb.exe" -D $data -U postgres --auth=trust --encoding=UTF8 --locale=C *> (Join-Path $dest 'init.log')
 if($LASTEXITCODE -ne 0){throw 'Fallo initdb'}
 & "$PgBin\pg_ctl.exe" -D $data -l (Join-Path $dest 'server.log') -o '-h 127.0.0.1 -p 55439' -w start
 if($LASTEXITCODE -ne 0){throw 'Fallo pg_ctl'}
 $started=$true
 foreach($file in @('tools/test_conductor_fixture.sql','sql/pruebas/114_conductores.sql','tools/test_conductor.sql')){
  & "$PgBin\psql.exe" -X -w --dbname='host=127.0.0.1 port=55439 user=postgres dbname=postgres sslmode=disable' -v ON_ERROR_STOP=1 -f (Join-Path $repo $file) *> (Join-Path $dest ([IO.Path]::GetFileName($file)+'.log'))
  if($LASTEXITCODE -ne 0){Get-Content (Join-Path $dest ([IO.Path]::GetFileName($file)+'.log')) -Tail 15; throw "Fallo $file"}
 }
 Write-Output "SQL conductor: migración, aislamiento, permisos, checklist y kilometraje correctos. $dest"
} finally {
 if($started){ & "$PgBin\pg_ctl.exe" -D $data -m fast -w stop }
}
