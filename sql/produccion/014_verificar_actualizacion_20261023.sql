-- Solo lectura, posterior a 013. No crea órdenes ni movimientos.
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
DO $$ DECLARE t text; f text; BEGIN
 FOREACH t IN ARRAY ARRAY['inventario_transferencias','inventario_reversiones','inventario_despachos','inventario_recepciones','inventario_actualizacion','inventario_importaciones','inventario_estantes_origen','inventario_excel_eliminaciones','despacho_eventos','conductor_vehiculos','conductor_registros','conductor_autorizaciones','conductor_tareas','conductor_revision_eventos','entrega_correos','le_numeros_disponibles'] LOOP
  IF to_regclass('public.'||t) IS NULL OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.'||t)) THEN RAISE EXCEPTION 'Falta tabla privada: %',t; END IF;
 END LOOP;
 FOREACH f IN ARRAY ARRAY['public.inventario_historial_transferencias()','public.conductor_flota_resumen()','public.conductor_historial(uuid,date,date,integer,integer)','public.conductor_actividad_mantenimiento_crear(uuid,uuid,text[],text,date,text,text,text)','public.conductor_registrar_kit(uuid,jsonb)','public.seguimiento_entregas_listar_v117(bigint)'] LOOP
  IF to_regprocedure(f) IS NULL OR has_function_privilege('anon',f,'EXECUTE') OR NOT has_function_privilege('authenticated',f,'EXECUTE') THEN RAISE EXCEPTION 'RPC o permisos incorrectos: %',f; END IF;
 END LOOP;
 IF has_function_privilege('authenticated','public.entrega_correo_reclamar(uuid)','EXECUTE') OR has_function_privilege('anon','public.entrega_correo_reclamar(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Cola de correo expuesta'; END IF;
END $$;
SELECT jsonb_build_object('flota',jsonb_typeof(public.conductor_flota_resumen()),'inventario',jsonb_typeof(public.inventario_historial_transferencias())) AS modulos_nuevos;
ROLLBACK;
