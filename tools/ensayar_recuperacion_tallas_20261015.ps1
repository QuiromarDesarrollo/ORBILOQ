param([string]$PgBin='C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dest=Join-Path $repo ('.dart_tool\empaques-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $dest
$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $dest /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if($LASTEXITCODE -ne 0){throw 'No se pudo proteger el ensayo'}
$prev=$env:PGPASSWORD
$env:PGPASSWORD=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$pw=Join-Path $dest 'clave.txt'
[IO.File]::WriteAllText($pw,$env:PGPASSWORD)
$started=$false
function RunSql([string]$db,[string]$file,[string]$log) {
 & "$PgBin\psql.exe" -X -w --dbname="host=127.0.0.1 port=55434 user=postgres dbname=$db sslmode=disable" -v ON_ERROR_STOP=1 -f $file *> (Join-Path $dest $log)
 if($LASTEXITCODE -ne 0){Get-Content (Join-Path $dest $log) -Tail 18;throw "Fallo: $log"}
}
try {
 & "$PgBin\initdb.exe" -D (Join-Path $dest 'data') -U postgres --auth=scram-sha-256 --encoding=UTF8 --locale=C "--pwfile=$pw" *> (Join-Path $dest 'initdb.log')
 if($LASTEXITCODE -ne 0){throw 'Fallo initdb'}
 Remove-Item -LiteralPath $pw
 # Redirigir pg_ctl a archivos evita que el servidor herede la tubería de PowerShell.
 $pgArgs=@('-D', ('"'+(Join-Path $dest 'data')+'"'), '-l', ('"'+(Join-Path $dest 'servidor.log')+'"'), '-o', '"-h 127.0.0.1 -p 55434"', '-w', 'start')
 $pgStart=Start-Process -FilePath "$PgBin\pg_ctl.exe" -ArgumentList $pgArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $dest 'arranque.log') -RedirectStandardError (Join-Path $dest 'arranque-error.log')
 $pgStart.WaitForExit()
 if($pgStart.ExitCode -ne 0){throw 'Fallo pg_ctl'}
 $started=$true
 $init=Join-Path $dest 'init.sql'
 [IO.File]::WriteAllText($init,'CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE ROLE supabase_admin; CREATE DATABASE ensayo;')
 RunSql 'postgres' $init 'roles.log'
 RunSql 'ensayo' (Join-Path $repo '.dart_tool/alinear/fixture-produccion.sql') 'fixture.log'

 RunSql 'ensayo' (Join-Path $repo '.dart_tool/recuperacion_seed.sql') 'seed.log'
 RunSql 'ensayo' (Join-Path $repo 'outputs/diagnostico_ordenes_20261015/02_recuperar_tallas_v2.sql') 'recuperacion.log'
 RunSql 'ensayo' (Join-Path $repo 'outputs/diagnostico_ordenes_20261015/01_diagnosticar_op_v2.sql') 'diagnostico.log'
 Get-Content (Join-Path $dest 'recuperacion.log') -Tail 9
 & "$PgBin\psql.exe" -X -w --dbname="host=127.0.0.1 port=55434 user=postgres dbname=ensayo sslmode=disable" -v ON_ERROR_STOP=1 -f (Join-Path $repo 'outputs/diagnostico_ordenes_20261015/02_recuperar_tallas_v2.sql') *> (Join-Path $dest 'repeticion.log')
 if($LASTEXITCODE -eq 0){throw 'La segunda ejecucion debio rechazarse'}
 if(-not (Select-String -Path (Join-Path $dest 'repeticion.log') -SimpleMatch 'Una OP ya tiene lineas' -Quiet)){ Get-Content (Join-Path $dest 'repeticion.log'); throw 'Rechazo inesperado' }
 Write-Output "OK recuperacion y rechazo de duplicacion. Logs: $dest"
} finally {
 if($started){ & "$PgBin\pg_ctl.exe" -D (Join-Path $dest 'data') -m fast -w stop | Out-Null }
 $env:PGPASSWORD=$prev
}
