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
 foreach($file in @('tools/test_conductor_fixture.sql','sql/pruebas/114_conductores.sql','tools/test_conductor.sql','sql/pruebas/115_conductor_historial_privado.sql','sql/pruebas/118_conductor_kit_semanal.sql','sql/pruebas/118_conductor_kit_semanal.sql','tools/test_kit_semanal.sql','sql/pruebas/119_conductor_autorizacion_salida.sql','sql/pruebas/119_conductor_autorizacion_salida.sql','tools/test_revision_salida.sql','sql/pruebas/121_conductor_actividades_agrupadas.sql','sql/pruebas/121_conductor_actividades_agrupadas.sql','tools/test_actividades_agrupadas.sql','sql/diagnostico/activar_conductor_actividades_pruebas.sql','sql/pruebas/122_conductor_motivos_atendidos.sql','sql/pruebas/122_conductor_motivos_atendidos.sql','tools/test_motivos_atendidos.sql','sql/pruebas/123_conductor_panel_flota.sql','sql/pruebas/123_conductor_panel_flota.sql','tools/test_flota_admin.sql','sql/pruebas/124_conductor_ficha_documentos.sql','sql/pruebas/124_conductor_ficha_documentos.sql','tools/test_ficha_documentos.sql','sql/pruebas/125_conductor_periodicidad_mantenimiento.sql','sql/pruebas/125_conductor_periodicidad_mantenimiento.sql','sql/pruebas/126_conductor_revision_preventiva.sql','sql/pruebas/126_conductor_revision_preventiva.sql','tools/test_preventivo.sql','sql/pruebas/127_conductor_actividades_mantenimiento.sql','sql/pruebas/127_conductor_actividades_mantenimiento.sql','tools/test_actividades_mantenimiento.sql','sql/pruebas/128_conductor_kit_admin_epp.sql','sql/pruebas/128_conductor_kit_admin_epp.sql','tools/test_kit_admin_epp.sql')){
  & "$PgBin\psql.exe" -X -w --dbname='host=127.0.0.1 port=55439 user=postgres dbname=postgres sslmode=disable' -v ON_ERROR_STOP=1 -f (Join-Path $repo $file) *> (Join-Path $dest ([IO.Path]::GetFileName($file)+'.log'))
  if($LASTEXITCODE -ne 0){Get-Content (Join-Path $dest ([IO.Path]::GetFileName($file)+'.log')) -Tail 15; throw "Fallo $file"}
 }
 Write-Output "SQL conductor: migración, aislamiento, permisos, checklist y kilometraje correctos. $dest"
} finally {
 if($started){ & "$PgBin\pg_ctl.exe" -D $data -m fast -w stop }
}
