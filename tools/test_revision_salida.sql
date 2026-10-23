RESET ROLE;
SELECT set_config('test.vehiculo',(SELECT id::text FROM public.conductor_vehiculos WHERE placa='TEST01'),false);
SELECT set_config('test.registro',(SELECT id::text FROM public.conductor_registros WHERE vehiculo_id=current_setting('test.vehiculo')::uuid AND tipo='Inicio de jornada'),false);
UPDATE public.conductor_registros SET datos=jsonb_set(datos,'{respuestas,Estado frenos}','"Con novedad"') WHERE id=current_setting('test.registro')::uuid;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$ DECLARE resumen jsonb; BEGIN
 resumen:=public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid,true);
 IF resumen->>'estado'<>'Pendiente de aprobación' OR resumen ? 'checklists' THEN RAISE EXCEPTION 'Estado o privacidad incorrectos'; END IF;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Autorizado','Yo mismo'); RAISE EXCEPTION 'Se autorizó solo'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Crear actividad','Falso','Estado frenos'); RAISE EXCEPTION 'Creó tarea sin permiso'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.conductor_autorizaciones SET estado='Autorizado'; RAISE EXCEPTION 'Escritura directa'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid); RAISE EXCEPTION 'Vio otro vehículo'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Autorizado','Revisado');
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Crear actividad','Reparar frenos','Estado frenos');
DO $$ BEGIN
 IF public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid)->>'estado'<>'No autorizado' THEN RAISE EXCEPTION 'No retiró permiso'; END IF;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Autorizado','Revisado'); RAISE EXCEPTION 'ERROR: aprobó con tarea'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Crear actividad','Inventada','No existe'); RAISE EXCEPTION 'ERROR: permitió punto falso'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Crear actividad','Duplicada','Estado frenos'); RAISE EXCEPTION 'Duplicó actividad'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
SELECT set_config('test.tarea',public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid)->'tareas'->0->>'id',false);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Por verificar','Reparado',NULL,current_setting('test.tarea')::uuid);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Cerrada','Listo',NULL,current_setting('test.tarea')::uuid); RAISE EXCEPTION 'Conductor cerró actividad'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Cerrada','Verificado',NULL,current_setting('test.tarea')::uuid);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Autorizado','Vehículo verificado, salida autorizada');
DO $$ BEGIN
 IF public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid)->>'estado'<>'Autorizado' THEN RAISE EXCEPTION 'No aprobó'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN IF (SELECT count(*) FROM public.conductor_revision_eventos)<5 THEN RAISE EXCEPTION 'Auditoría incompleta'; END IF; END $$;
