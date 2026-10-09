-- Solo lectura. Ejecutar en SQL Editor de ORBILOQ-DEV y compartir los resultados.
BEGIN TRANSACTION READ ONLY;
SELECT current_database() base, current_setting('app.settings.project_ref',true) proyecto;
WITH requeridas(migracion,firma) AS (VALUES
 ('087','public.admin_trazabilidad_op(text)'),
 ('087','public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb)'),
 ('088','public.validar_stock_no_conforme(uuid,integer)'),
 ('089','public.seguimiento_acceso()')
)
SELECT migracion,firma,to_regprocedure(firma) IS NOT NULL existe FROM requeridas;
SELECT table_name,column_name FROM information_schema.columns
WHERE table_schema='public' AND (table_name='despachos_oc' AND column_name='fecha_empacado'
 OR table_name='seguimiento_entregas' AND column_name IN ('numero_guia','placa'));
SELECT p.proname,pg_get_function_identity_arguments(p.oid) firma,
 position('public.seguimiento_acceso()' IN pg_get_functiondef(p.oid))>0 permiso_seguimiento,
 position('public.validar_stock_no_conforme(' IN pg_get_functiondef(p.oid))>0 valida_stock_nc,
 CASE WHEN p.proname='seguimiento_acceso' THEN pg_get_functiondef(p.oid) END regla_acceso
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('seguimiento_acceso','seguimiento_confirmar',
 'seguimiento_guardar_base_v87','seguimiento_listar_base_v87','seguimiento_archivo_permitido','registrar_no_conforme');
COMMIT;
