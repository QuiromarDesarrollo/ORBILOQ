-- Solo lectura, posterior a 011. No crea órdenes ni movimientos.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='120s';
DO $$ DECLARE firma text; tabla text; BEGIN
 FOREACH firma IN ARRAY ARRAY[
 'public.admin_destinatario_editar(uuid,jsonb,jsonb)',
 'public.admin_destinatario_eliminar(uuid,jsonb)',
 'public.dashboard_despachos_mensuales(date,date,text,timestamptz)',
 'public.dashboard_facturacion_semanal(date,date,text,timestamptz)',
 'public.dashboard_puntualidad_mensual(date,date,text,timestamptz)',
 'public.facturacion_le_listar(boolean,bigint)',
 'public.facturacion_le_guardar(uuid,integer,integer,integer,text,text)',
 'public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'
 ] LOOP
  IF to_regprocedure(firma) IS NULL OR has_function_privilege('anon',firma,'EXECUTE') OR NOT has_function_privilege('authenticated',firma,'EXECUTE') THEN RAISE EXCEPTION 'RPC o permisos incorrectos: %',firma; END IF;
 END LOOP;
 IF has_function_privilege('authenticated','public.facturacion_le_dato(uuid)','EXECUTE') OR has_function_privilege('anon','public.facturacion_le_dato(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Función interna expuesta'; END IF;
 FOREACH tabla IN ARRAY ARRAY['public.facturacion_le','public.le_ajustes_admin'] LOOP
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass(tabla)) OR has_table_privilege('authenticated',tabla,'SELECT,INSERT,UPDATE,DELETE') OR has_table_privilege('anon',tabla,'SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Tabla interna expuesta: %',tabla; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.seguimiento_entregas'::regclass AND conname='seguimiento_estado_valido' AND pg_get_constraintdef(oid) LIKE '%entregado_con_novedad%') THEN RAISE EXCEPTION 'Falta estado con novedad'; END IF;
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='admin' AND auth_id IS NOT NULL LIMIT 1),true);
 IF nullif(current_setting('request.jwt.claim.sub',true),'') IS NULL THEN RAISE EXCEPTION 'No hay administrador vinculado'; END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT jsonb_build_object(
 'facturacion_pendiente',jsonb_typeof(public.facturacion_le_listar(false)),
 'facturacion_completa',jsonb_typeof(public.facturacion_le_listar(true)),
 'despachos_mensuales',jsonb_typeof(public.dashboard_despachos_mensuales(current_date-30,current_date)),
 'facturacion_semanal',jsonb_typeof(public.dashboard_facturacion_semanal(current_date-30,current_date)),
 'puntualidad_mensual',jsonb_typeof(public.dashboard_puntualidad_mensual(current_date-30,current_date))
) AS verificacion;
ROLLBACK;
