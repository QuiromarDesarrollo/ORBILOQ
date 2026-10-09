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
 & "$PgBin\pg_ctl.exe" -D (Join-Path $dest 'data') -l (Join-Path $dest 'servidor.log') -o '-h 127.0.0.1 -p 55434' -w start
 if($LASTEXITCODE -ne 0){throw 'Fallo pg_ctl'}
 $started=$true
 $init=Join-Path $dest 'init.sql'
 [IO.File]::WriteAllText($init,'CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE ROLE supabase_admin; CREATE DATABASE ensayo;')
 RunSql 'postgres' $init 'roles.log'
 RunSql 'ensayo' (Join-Path $repo '.dart_tool/alinear/fixture-produccion.sql') 'fixture.log'
 $seed=Join-Path $dest 'seed.sql'
 [IO.File]::WriteAllText($seed,"INSERT INTO public.ordenes_produccion(id,numero_op,cliente) VALUES('20000000-0000-0000-0000-000000000001','90001','TEST'); INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc) VALUES('0701856a-7771-4536-9762-658a58af8803','20000000-0000-0000-0000-000000000001','DEMO-001','TEST','M',20,'TEST-OC');")
 RunSql 'ensayo' $seed 'seed.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/065_empaques_despacho.sql') 'migracion.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/066_prendas_por_empaque.sql') 'migracion066.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_empaques.sql') 'funcional.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_prendas_empaques.sql') 'prendas.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/067_empaques_repetidos.sql') 'migracion067.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_empaques_repetidos.sql') 'repetidos.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/068_validar_entregado_recibido.sql') 'migracion068.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/068_validar_entregado_recibido.sql') 'migracion068_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_validacion_entregado.sql') 'validacion_entregado.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/070_separar_bodega_despacho.sql') 'migracion070.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/070_separar_bodega_despacho.sql') 'migracion070_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_separacion_roles.sql') 'separacion_roles.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/073_lista_empaque.sql') 'migracion073.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/073_lista_empaque.sql') 'migracion073_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_lista_empaque.sql') 'lista_empaque.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/074_correccion_multilote.sql') 'migracion074.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/075_proteger_despachadas_correccion.sql') 'migracion075.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_correccion_multilote.sql') 'multilote.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/077_destinatarios_sede.sql') 'migracion077.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_destinatarios_sede.sql') 'destinatarios_sede.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/078_corregir_pendiente_recepcion.sql') 'migracion078.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_corregir_envios.sql') 'envios.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/079_historial_despachos_le.sql') 'historial079.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/080_corregir_despacho_le.sql') 'correcciones080.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/080_corregir_despacho_le.sql') 'correcciones080_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_corregir_despacho_le.sql') 'corregir_despacho_le.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/071_ciclos_gerencia.sql') 'compatibilidad071.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/081_empaque_seguimiento.sql') 'seguimiento081.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/081_empaque_seguimiento.sql') 'seguimiento081_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_seguimiento.sql') 'seguimiento.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/082_destinatario_antes_empaque.sql') 'destino082.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/082_destinatario_antes_empaque.sql') 'destino082_repetida.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_destinatario_empaque.sql') 'destino_empaque.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_reset_rotulos_preparar.sql') 'reset_preparar.log'
 RunSql 'ensayo' (Join-Path $repo 'sql/pruebas/083_reiniciar_movimientos_y_empaques.sql') 'reset083.log'
 RunSql 'ensayo' (Join-Path $repo 'tools/test_reset_rotulos_verificar.sql') 'reset_verificar.log'
 Write-Output "OK: listas de empaque, numeracion, tallas compartidas, stock, consecutivos, reimpresion, sedes y seguimiento. Logs: $dest"
} finally {
 if($started){ & "$PgBin\pg_ctl.exe" -D (Join-Path $dest 'data') -m fast -w stop | Out-Null }
 $env:PGPASSWORD=$prev
}
