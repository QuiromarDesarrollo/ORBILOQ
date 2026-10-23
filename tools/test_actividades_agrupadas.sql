RESET ROLE;
SELECT set_config('test.vehiculo',(SELECT id::text FROM public.conductor_vehiculos WHERE placa='TEST01'),false);
SELECT set_config('test.registro',(SELECT id::text FROM public.conductor_registros WHERE vehiculo_id=current_setting('test.vehiculo')::uuid AND tipo='Inicio de jornada'),false);
UPDATE public.conductor_registros SET datos=jsonb_set(datos,'{respuestas,Nivel de aceite}','"Con novedad"') WHERE id=current_setting('test.registro')::uuid;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.actividad', public.conductor_actividad_crear(current_setting('test.registro')::uuid,ARRAY['Estado frenos','Nivel de aceite'],'Revisar sistema de frenos y aceite',(now() AT TIME ZONE 'America/Bogota')::date)::text,false);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Autorizado','Salida permitida, corrección programada');
DO $$ BEGIN
 IF public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid)->>'estado'<>'Autorizado' THEN RAISE EXCEPTION 'Actividad bloquea autorización'; END IF;
 BEGIN PERFORM public.conductor_actividad_crear(current_setting('test.registro')::uuid,ARRAY['Estado frenos'],'Duplicada',current_date); RAISE EXCEPTION 'ERROR: duplicó motivo abierto'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_actividad_crear(current_setting('test.registro')::uuid,ARRAY['Estado frenos'],'Sin permiso',current_date); RAISE EXCEPTION 'Creó como conductor'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.conductor_actividad_entregar(current_setting('test.actividad')::uuid,'Listo',NULL); RAISE EXCEPTION 'ERROR: entrega sin foto'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Por verificar','Sin foto',NULL,current_setting('test.actividad')::uuid); RAISE EXCEPTION 'ERROR: bypass antiguo'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
END $$;
SELECT public.conductor_actividad_entregar(current_setting('test.actividad')::uuid,'Se cambiaron piezas','https://drive.google.com/file/d/abc123/view');
SELECT public.conductor_actividad_entregar(current_setting('test.actividad')::uuid,'Se cambiaron piezas','https://drive.google.com/file/d/abc123/view');
DO $$ DECLARE r jsonb; BEGIN
 r:=public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid);
 IF r->'tareas'->0->>'estado'<>'Por verificar' OR r->'tareas'->0->>'entregado_en' IS NULL OR jsonb_array_length(r->'tareas'->0->'motivos')<>2 THEN RAISE EXCEPTION 'Falta entrega o motivos: %',r; END IF;
 IF r ? 'checklists' THEN RAISE EXCEPTION 'Conductor ve respuestas'; END IF;
 BEGIN PERFORM public.conductor_revision_accion(current_setting('test.registro')::uuid,'Cerrada','Yo',NULL,current_setting('test.actividad')::uuid); RAISE EXCEPTION 'Autocierre'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_actividad_entregar(current_setting('test.actividad')::uuid,'Ajeno','https://drive.google.com/file/d/falso/view'); RAISE EXCEPTION 'Entregó tarea ajena'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT public.conductor_revision_accion(current_setting('test.registro')::uuid,'Cerrada','Revisado',NULL,current_setting('test.actividad')::uuid);
DO $$ BEGIN
 IF jsonb_array_length(public.conductor_revision_resumen(current_setting('test.vehiculo')::uuid,true)->'tareas')<2 THEN RAISE EXCEPTION 'Admin perdió historial de tareas'; END IF;
END $$;
RESET ROLE;
