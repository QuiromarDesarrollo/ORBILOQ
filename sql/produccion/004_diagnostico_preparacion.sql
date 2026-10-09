-- PRODUCCION: cxrflhgnxvomcvxzugda. SOLO LECTURA. No es una migracion ni un respaldo.
-- Ejecutar completo y exportar la fila JSON como CSV, junto al inventario de estructura.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='60s';
SELECT jsonb_build_object(
 'fecha_utc',now(),
 'proyecto_configurado',current_setting('app.settings.project_ref',true),
 'base',current_database(),
 'postgres',version(),
 'conteos',jsonb_build_object(
   'op',(SELECT count(*) FROM public.ordenes_produccion),
   'items',(SELECT count(*) FROM public.items_orden),
   'movimientos',(SELECT count(*) FROM public.movimientos),
   'lotes',(SELECT count(*) FROM public.lotes),
   'lote_items',(SELECT count(*) FROM public.lote_items),
   'usuarios',(SELECT count(*) FROM public.usuarios),
   'auth_usuarios',(SELECT count(*) FROM auth.users)),
 'cuentas_por_rol',(SELECT jsonb_agg(x) FROM (
   SELECT rol,activo,count(*) cantidad,count(auth_id) vinculados_auth FROM public.usuarios GROUP BY rol,activo) x),
 'perfiles_sin_auth',(SELECT count(*) FROM public.usuarios u WHERE u.auth_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM auth.users a WHERE a.id=u.auth_id)),
 'items_sin_op',(SELECT count(*) FROM public.items_orden i WHERE NOT EXISTS(SELECT 1 FROM public.ordenes_produccion o WHERE o.id=i.orden_id)),
 'storage',(SELECT jsonb_agg(x) FROM (
   SELECT b.id,b.public,count(o.id) objetos,sum(CASE WHEN o.metadata->>'size' ~ '^[0-9]+$' THEN (o.metadata->>'size')::bigint ELSE 0 END) bytes
   FROM storage.buckets b LEFT JOIN storage.objects o ON o.bucket_id=b.id GROUP BY b.id,b.public) x),
 'rpc_requeridas',(SELECT jsonb_agg(jsonb_build_object('firma',firma,'existe',to_regprocedure(firma) IS NOT NULL)) FROM (VALUES
   ('public.seguimiento_acceso()'),
   ('public.validar_stock_no_conforme(uuid,integer)'),
   ('public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb)'),
   ('public.admin_trazabilidad_op(text)'),
   ('public.recibir_lote_item(uuid,integer,uuid,text,text)')) f(firma)),
 'extensiones',(SELECT jsonb_agg(jsonb_build_object('nombre',extname,'version',extversion)) FROM pg_extension),
 'publicaciones',(SELECT jsonb_agg(jsonb_build_object('publicacion',pubname,'esquema',schemaname,'tabla',tablename)) FROM pg_publication_tables),
 'conexiones_actuales',(SELECT jsonb_agg(x) FROM (
   SELECT usename,application_name,state,count(*) cantidad FROM pg_stat_activity
   WHERE datname=current_database() AND pid<>pg_backend_pid() GROUP BY usename,application_name,state) x),
 'nota','Una instantanea de conexiones no demuestra ausencia de integraciones externas. No incluye archivos Storage ni configuracion de Edge Functions, secretos, Auth o GitHub Pages.'
) AS diagnostico;
COMMIT;
