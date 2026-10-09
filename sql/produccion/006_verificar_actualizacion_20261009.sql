-- Solo lectura. Ejecutar después de 005, antes de reabrir operaciones.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
DO $$ DECLARE firma text; BEGIN
 IF (SELECT siguiente FROM public.lista_empaque_config WHERE id=true) IS DISTINCT FROM 3000::bigint THEN RAISE EXCEPTION 'Próxima LE inesperada'; END IF;
 IF EXISTS(SELECT 1 FROM public.empaques) OR EXISTS(SELECT 1 FROM public.destinatarios_empaque) THEN RAISE EXCEPTION 'Catálogos no vacíos'; END IF;
 IF (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename IN ('items_orden','ordenes_produccion','movimientos','lotes','lote_items','reservas_despacho'))<>6 THEN RAISE EXCEPTION 'Realtime incompleto'; END IF;
 FOREACH firma IN ARRAY ARRAY['public.seguimiento_acceso()','public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb)','public.admin_trazabilidad_op(text)','public.guardar_empaque_destinatario(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text)'] LOOP
  IF to_regprocedure(firma) IS NULL THEN RAISE EXCEPTION 'Falta RPC %',firma; END IF;
  IF has_function_privilege('anon',firma,'EXECUTE') OR NOT has_function_privilege('authenticated',firma,'EXECUTE') THEN RAISE EXCEPTION 'Permisos RPC inesperados: %',firma; END IF;
 END LOOP;
 FOREACH firma IN ARRAY ARRAY['public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)','public.seguimiento_listar_base_v87(bigint)','public.admin_usuario_registrar(uuid,uuid,text,text,text)'] LOOP
  IF has_function_privilege('authenticated',firma,'EXECUTE') OR has_function_privilege('anon',firma,'EXECUTE') THEN RAISE EXCEPTION 'RPC interna expuesta: %',firma; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM storage.buckets WHERE id='seguimiento-evidencias' AND NOT public AND file_size_limit=10485760) THEN RAISE EXCEPTION 'Bucket incorrecto'; END IF;
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='admin' AND auth_id IS NOT NULL LIMIT 1),true);
 IF nullif(current_setting('request.jwt.claim.sub',true),'') IS NULL THEN RAISE EXCEPTION 'No hay administrador vinculado'; END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT jsonb_build_object(
 'trazabilidad_filas',jsonb_array_length(public.admin_trazabilidad_op()),
 'tipo_resumen',jsonb_typeof(public.admin_reporte_resumen()),
 'tipo_historial',jsonb_typeof(public.historial_despachos_empaques()),
 'destinatarios',jsonb_array_length(public.destinatarios_para_empaque()),
 'seguimiento',jsonb_array_length(public.seguimiento_entregas_listar())
) AS comprobacion_rpc;
RESET ROLE;
SELECT jsonb_build_object('ordenes',(SELECT count(*) FROM public.ordenes_produccion),
 'items',(SELECT count(*) FROM public.items_orden),'movimientos',(SELECT count(*) FROM public.movimientos),
 'lotes',(SELECT count(*) FROM public.lotes),'lote_items',(SELECT count(*) FROM public.lote_items),
 'usuarios',(SELECT count(*) FROM public.usuarios),'siguiente_le',(SELECT siguiente FROM public.lista_empaque_config WHERE id=true)) AS conteos;
COMMIT;
