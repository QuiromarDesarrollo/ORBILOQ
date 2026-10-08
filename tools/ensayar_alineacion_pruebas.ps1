param([string]$PgBin='C:\Users\analistadatos\Downloads\postgresql-17.11-5-windows-x64-binaries\pgsql\bin')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dest=Join-Path $repo ('.dart_tool\alinear\ensayo-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $dest
$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $dest /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if($LASTEXITCODE -ne 0){throw 'No se pudo proteger el ensayo.'}
$prev=$env:PGPASSWORD
$env:PGPASSWORD=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$pw=Join-Path $dest 'clave.txt'
[IO.File]::WriteAllText($pw,$env:PGPASSWORD)
$started=$false
function RunSql([string]$db,[string]$file,[string]$log,[bool]$expectSuccess=$true) {
 & "$PgBin\psql.exe" -X -w --dbname="host=127.0.0.1 port=55433 user=postgres dbname=$db sslmode=disable" -v ON_ERROR_STOP=1 -f $file *> (Join-Path $dest $log)
 if($expectSuccess -and $LASTEXITCODE -ne 0){Get-Content (Join-Path $dest $log) -Tail 18;throw "Fallo: $log"}
 if(!$expectSuccess -and $LASTEXITCODE -eq 0){throw "Se esperaba rechazo: $log"}
}
try {
 & "$PgBin\initdb.exe" -D (Join-Path $dest 'data') -U postgres --auth=scram-sha-256 --encoding=UTF8 --locale=C "--pwfile=$pw" *> (Join-Path $dest 'initdb.log')
 if($LASTEXITCODE -ne 0){throw 'Fallo initdb'}
 Remove-Item -LiteralPath $pw
 & "$PgBin\pg_ctl.exe" -D (Join-Path $dest 'data') -l (Join-Path $dest 'servidor.log') -o '-h 127.0.0.1 -p 55433' -w start
 if($LASTEXITCODE -ne 0){throw 'Fallo pg_ctl'}
 $started=$true
 $init=Join-Path $dest 'init.sql'
 [IO.File]::WriteAllText($init,'CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE ROLE supabase_admin; CREATE DATABASE ensayo; CREATE DATABASE referencia;')
 RunSql 'postgres' $init 'roles.log'
 RunSql 'ensayo' (Join-Path $repo '.dart_tool/alinear/fixture-pruebas.sql') 'fixture.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_alineacion_semilla.sql') 'semilla.log'
 $cases=Join-Path $dest 'clones.sql'
 [IO.File]::WriteAllText($cases,'CREATE DATABASE caso_documentos TEMPLATE ensayo; CREATE DATABASE caso_cantidad TEMPLATE ensayo; CREATE DATABASE caso_cambio TEMPLATE ensayo; CREATE DATABASE caso_conservacion TEMPLATE ensayo;')
 RunSql 'postgres' $cases 'clones.log'
 $documento=Join-Path $dest 'documento.sql'
 [IO.File]::WriteAllText($documento,"INSERT INTO public.documentos(nombre_archivo,storage_path) VALUES ('local.xlsx','local/prueba.xlsx');")
 RunSql 'caso_documentos' $documento 'documento.log'
 RunSql 'caso_documentos' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'documento-rechazado.log' $false
 RunSql 'caso_documentos' (Join-Path $repo '.dart_tool/alinear/verificar-origen.sql') 'documento-origen-intacto.log'
 $cantidad=Join-Path $dest 'cantidad.sql'
 [IO.File]::WriteAllText($cantidad,'UPDATE public.items_orden SET cantidad_pedida=0;')
 RunSql 'caso_cantidad' $cantidad 'cantidad.log'
 RunSql 'caso_cantidad' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'cantidad-rechazada.log' $false
 RunSql 'caso_cantidad' (Join-Path $repo '.dart_tool/alinear/verificar-origen.sql') 'cantidad-origen-intacto.log'
 $cambio=Join-Path $dest 'cambio.sql'
 [IO.File]::WriteAllText($cambio,'CREATE INDEX cambio_no_inventariado ON public.usuarios(nombre);')
 RunSql 'caso_cambio' $cambio 'cambio.log'
 RunSql 'caso_cambio' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'cambio-rechazado.log' $false
 $corrupto=Join-Path $dest 'corrupcion-simulada.sql'
 $sqlOriginal=[IO.File]::ReadAllText((Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql'))
 # Alterar DESPUÉS de capturar los originales para verificar el detector de pérdida.
 $sqlCorrupto=$sqlOriginal.Replace('EXECUTE $ddl$ALTER TABLE public.documentos',"UPDATE public.items_orden SET cantidad_pedida=28;`n"+'EXECUTE $ddl$ALTER TABLE public.documentos')
 [IO.File]::WriteAllText($corrupto,$sqlCorrupto)
 RunSql 'caso_conservacion' $corrupto 'conservacion-rechazada.log' $false
 RunSql 'caso_conservacion' (Join-Path $repo '.dart_tool/alinear/verificar-origen.sql') 'conservacion-origen-intacto.log'
 RunSql 'referencia' (Join-Path $repo '.dart_tool/alinear/fixture-produccion.sql') 'referencia.log'
 RunSql 'referencia' (Join-Path $repo 'sql/alinear_pruebas/003_verificar_estructura.sql') 'referencia-verificada.log'
 RunSql 'referencia' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'produccion-rechazada.log' $false
 RunSql 'referencia' (Join-Path $repo 'sql/alinear_pruebas/003_verificar_estructura.sql') 'referencia-intacta.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'migracion.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/alinear_pruebas/003_verificar_estructura.sql') 'verificacion.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_migracion_produccion.sql') 'funcional.log'
 $verificar=Join-Path $dest 'comprobar-datos.sql'
 [IO.File]::WriteAllText($verificar,"DO `$`$ BEGIN IF (SELECT cantidad_pedida FROM public.items_orden LIMIT 1)<>29 OR (SELECT count(*) FROM public.movimientos)<>2 THEN RAISE EXCEPTION 'Se alteraron los originales'; END IF; END `$`$;")
 RunSql 'caso_conservacion' $verificar 'rollback-datos.log'
 RunSql 'ensayo' $verificar 'datos-conservados.log'
 $fechas=Join-Path $dest 'fechas.sql'
 [IO.File]::WriteAllText($fechas,"DO `$`$ BEGIN IF EXISTS(SELECT 1 FROM public.movimientos WHERE creado_en IS DISTINCT FROM fecha) THEN RAISE EXCEPTION 'Fecha historica incorrecta'; END IF; END `$`$;")
 RunSql 'ensayo' $fechas 'fechas-conservadas.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/alinear_pruebas/002_alinear_solo_pruebas.sql') 'repeticion-rechazada.log' $false
 Write-Output "Ensayo correcto: $dest"
} finally {
 if($started){& "$PgBin\pg_ctl.exe" -D (Join-Path $dest 'data') -m fast -w stop}
 if(Test-Path -LiteralPath $pw){Remove-Item -LiteralPath $pw}
 $env:PGPASSWORD=$prev
}
