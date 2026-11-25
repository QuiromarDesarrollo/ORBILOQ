BEGIN;
SET LOCAL statement_timeout='60s';
DO $test$
DECLARE admin_id uuid; operario_id uuid; operacion uuid; vista text; bloqueadas integer:=0; permitidas integer:=0;
BEGIN
 SELECT auth_id INTO STRICT admin_id FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND 'admin'=ANY(coalesce(roles,ARRAY[rol])) LIMIT 1;
 SELECT auth_id INTO STRICT operario_id FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND 'masiva'=ANY(coalesce(roles,ARRAY[rol])) AND NOT 'admin'=ANY(coalesce(roles,ARRAY[rol])) LIMIT 1;
 SELECT id INTO STRICT operacion FROM public.masiva_operaciones ORDER BY creado DESC LIMIT 1;
 EXECUTE 'SET LOCAL ROLE authenticated';
 PERFORM set_config('request.jwt.claim.sub',operario_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',operario_id,'role','authenticated')::text,true);
 FOREACH vista IN ARRAY ARRAY['listas','listado','base','conciliacion','auditoria','documentos','configuracion'] LOOP
  BEGIN PERFORM public.masiva_consultar(p_operacion=>operacion,p_vista=>vista); RAISE EXCEPTION 'Acceso no bloqueado: %',vista; EXCEPTION WHEN insufficient_privilege THEN bloqueadas:=bloqueadas+1; END;
 END LOOP;
 BEGIN PERFORM public.masiva_maestro_consultar(p_operacion=>operacion,p_vista=>'listado'); RAISE EXCEPTION 'Maestro no bloqueado'; EXCEPTION WHEN insufficient_privilege THEN bloqueadas:=bloqueadas+1; END;
 BEGIN PERFORM public.masiva_maestro_consultar(p_operacion=>operacion,p_vista=>'base'); RAISE EXCEPTION 'Base no bloqueada'; EXCEPTION WHEN insufficient_privilege THEN bloqueadas:=bloqueadas+1; END;
 BEGIN PERFORM public.masiva_conciliacion_consultar(p_operacion=>operacion); RAISE EXCEPTION 'Conciliacion no bloqueada'; EXCEPTION WHEN insufficient_privilege THEN bloqueadas:=bloqueadas+1; END;
 FOREACH vista IN ARRAY ARRAY['documento','registrar_impresion'] LOOP
  BEGIN PERFORM public.masiva_ejecutar(vista,'{}'); RAISE EXCEPTION 'Documento no bloqueado'; EXCEPTION WHEN insufficient_privilege THEN bloqueadas:=bloqueadas+1; END;
 END LOOP;
 FOREACH vista IN ARRAY ARRAY['resumen','inventario','kits','personal','empaques','indicadores'] LOOP
  PERFORM public.masiva_consultar(p_operacion=>operacion,p_vista=>vista); permitidas:=permitidas+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 FOREACH vista IN ARRAY ARRAY['auditoria','documentos','configuracion'] LOOP
  PERFORM public.masiva_consultar(p_operacion=>operacion,p_vista=>vista); permitidas:=permitidas+1;
 END LOOP;
 PERFORM public.masiva_maestro_consultar(p_operacion=>operacion,p_vista=>'listado');
 PERFORM public.masiva_maestro_consultar(p_operacion=>operacion,p_vista=>'base');
 PERFORM public.masiva_conciliacion_consultar(p_operacion=>operacion);
 IF bloqueadas<>12 OR permitidas<>9 THEN RAISE EXCEPTION 'Conteos inesperados'; END IF;
END $test$;
ROLLBACK;
SELECT 'OK: 12 accesos bloqueados a operario; 6 consultas operativas y 6 administrativas permitidas; sin escrituras de datos' AS resultado;
