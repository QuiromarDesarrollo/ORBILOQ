-- Solo lectura, posterior a 015. No crea movimientos ni documentos.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='60s';
DO $$ DECLARE firma text; t record; BEGIN
 FOREACH firma IN ARRAY ARRAY[
 'public.masiva_consultar(uuid,text,text,integer,text)',
 'public.masiva_ejecutar(text,jsonb)',
 'public.masiva_recepcion_historial(uuid,text,integer)',
 'public.despacho_borrador_cargar(text)',
 'public.despacho_borrador_guardar(text,jsonb,bigint)',
 'public.despacho_borrador_eliminar(text,bigint)',
 'public.seguimiento_placas_quiromar()'
 ] LOOP
  IF to_regprocedure(firma) IS NULL OR has_function_privilege('anon',firma,'EXECUTE') OR NOT has_function_privilege('authenticated',firma,'EXECUTE') THEN
   RAISE EXCEPTION 'RPC o permisos incorrectos: %',firma;
  END IF;
 END LOOP;
 IF to_regclass('public.despacho_borradores') IS NULL OR to_regclass('public.masiva_operaciones') IS NULL THEN RAISE EXCEPTION 'Faltan tablas'; END IF;
 FOR t IN SELECT oid,relname,relrowsecurity FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind='r' AND (relname LIKE 'masiva_%' OR relname='despacho_borradores') LOOP
  IF NOT t.relrowsecurity OR has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Tabla expuesta: %',t.relname; END IF;
 END LOOP;
 IF position('DESPACHO_FECHA_LIBRE_V141' IN pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure))=0 THEN RAISE EXCEPTION 'Falta fecha libre'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='masiva_listas' AND column_name='fecha_generado') THEN
  RAISE EXCEPTION 'Falta fecha de PDF';
 END IF;
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND 'admin'=ANY(coalesce(roles,ARRAY[rol])) LIMIT 1),true);
 IF nullif(current_setting('request.jwt.claim.sub',true),'') IS NULL THEN RAISE EXCEPTION 'Falta administrador vinculado'; END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT jsonb_typeof(public.masiva_consultar()) AS masiva,
 (SELECT count(*) FROM public.seguimiento_placas_quiromar()) AS placas;
ROLLBACK;
