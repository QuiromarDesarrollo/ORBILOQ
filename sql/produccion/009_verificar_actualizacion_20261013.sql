-- Verificación de solo lectura posterior a 008_actualizacion_20261013.sql.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
DO $$ DECLARE firma text; BEGIN
 FOREACH firma IN ARRAY ARRAY[
 'public.admin_empaque_guardar_v92(uuid,text,jsonb)',
 'public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)',
 'public.le_importar_clientes_internacionales(jsonb)',
 'public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)'
 ] LOOP
  IF to_regprocedure(firma) IS NULL OR has_function_privilege('anon',firma,'EXECUTE') OR NOT has_function_privilege('authenticated',firma,'EXECUTE') THEN RAISE EXCEPTION 'RPC o permisos incorrectos: %',firma; END IF;
 END LOOP;
 firma:='public.admin_usuario_registrar_roles(uuid,uuid,text,text,text[])';
 IF to_regprocedure(firma) IS NULL OR has_function_privilege('anon',firma,'EXECUTE') OR has_function_privilege('authenticated',firma,'EXECUTE') OR NOT has_function_privilege('service_role',firma,'EXECUTE') THEN RAISE EXCEPTION 'Alta de usuarios expuesta o no disponible'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Falta soporte multiperfil'; END IF;
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='admin' AND auth_id IS NOT NULL LIMIT 1),true);
 IF nullif(current_setting('request.jwt.claim.sub',true),'') IS NULL THEN RAISE EXCEPTION 'No hay administrador vinculado'; END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT jsonb_build_object(
 'trazabilidad_filas',jsonb_array_length(public.admin_trazabilidad_op()),
 'tipo_resumen',jsonb_typeof(public.admin_reporte_resumen()),
 'tipo_historial',jsonb_typeof(public.historial_despachos_empaques()),
 'destinatarios',jsonb_array_length(public.destinatarios_para_empaque()),
 'seguimiento',jsonb_array_length(public.seguimiento_entregas_listar()),
 'usuarios',jsonb_array_length(public.admin_catalogos_listar('usuarios')),
 'admin_seguimiento',public.seguimiento_acceso()
) AS verificacion;
ROLLBACK;
