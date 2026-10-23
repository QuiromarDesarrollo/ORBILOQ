BEGIN;
RESET ROLE;
SELECT set_config('test.v',(SELECT id::text FROM public.conductor_vehiculos WHERE placa='TEST02'),true);
SELECT set_config('test.r',(SELECT id::text FROM public.conductor_registros WHERE vehiculo_id=current_setting('test.v')::uuid AND tipo='Inicio de jornada' LIMIT 1),true);
UPDATE public.conductor_registros SET datos=jsonb_set(datos,'{respuestas}','{"Luces altas":"Con novedad"}') WHERE id=current_setting('test.r')::uuid;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.t',public.conductor_actividad_mantenimiento_crear(current_setting('test.v')::uuid,NULL,ARRAY[]::text[],'Programar aceite',current_date,'Mantenimiento preventivo','Cambio de aceite','aceite')::text,true);
SELECT set_config('test.c',public.conductor_actividad_mantenimiento_crear(current_setting('test.v')::uuid,current_setting('test.r')::uuid,ARRAY['Luces altas'],'Reparar luces',current_date,'Mantenimiento correctivo','Cambiar bombillo',NULL)::text,true);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.conductor_flota_resumen() j WHERE j->>'id'=current_setting('test.v') AND (j->>'pendientes')::int>=2) THEN RAISE EXCEPTION 'No incluye independientes en flota'; END IF;
 BEGIN PERFORM public.conductor_actividad_mantenimiento_crear(current_setting('test.v')::uuid,current_setting('test.r')::uuid,ARRAY['Luces altas'],'Duplicada',current_date,'Mantenimiento correctivo','Otro',NULL); RAISE EXCEPTION 'ERROR duplicado'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 IF jsonb_array_length(public.conductor_revision_resumen(current_setting('test.v')::uuid)->'tareas')<2 THEN RAISE EXCEPTION 'Conductor no ve ambas actividades'; END IF;
 BEGIN PERFORM public.conductor_actividad_mantenimiento_crear(current_setting('test.v')::uuid,NULL,ARRAY[]::text[],'No permitido',current_date,'Mantenimiento correctivo','Otro',NULL); RAISE EXCEPTION 'ERROR permisos'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.conductor_actividad_entregar(current_setting('test.c')::uuid,'Intento anterior','https://drive.google.com/file/d/test/view'); RAISE EXCEPTION 'ERROR bypass'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('test.d',jsonb_build_object('actividad_id',current_setting('test.t'),'servicio_id','aceite','servicio','Cambio de aceite','taller','Taller prueba','valor','100','enlace','https://drive.google.com/file/d/test/view','fecha_inicio','2026-10-23','hora_inicio','10:00','fecha_fin','2026-10-23','hora_fin','11:00')::text,true);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento preventivo',1000,current_setting('test.d')::jsonb||'{"servicio":"Otro trabajo"}'); RAISE EXCEPTION 'ERROR cambio trabajo'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR%' THEN RAISE; END IF; END;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.conductor_revision_resumen(current_setting('test.v')::uuid)->'tareas') t WHERE t->>'id'=current_setting('test.t') AND t->>'estado'='Pendiente') THEN RAISE EXCEPTION 'Entrega fallida cambia estado'; END IF;
END $$;
SELECT public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento preventivo',1000,current_setting('test.d')::jsonb);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.conductor_revision_resumen(current_setting('test.v')::uuid)->'tareas') t WHERE t->>'id'=current_setting('test.t') AND t->>'estado'='Por verificar' AND t->>'mantenimiento_registro_id' IS NOT NULL) THEN RAISE EXCEPTION 'Entrega no vinculada'; END IF;
 BEGIN PERFORM public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento preventivo',1000,current_setting('test.d')::jsonb); RAISE EXCEPTION 'ERROR doble entrega'; EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR%' THEN RAISE; END IF; END;
 BEGIN PERFORM public.conductor_revision_accion(NULL,'Cerrada','Auto aprobar',NULL,current_setting('test.t')::uuid); RAISE EXCEPTION 'ERROR autocierre'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento preventivo',1000,current_setting('test.d')::jsonb); RAISE EXCEPTION 'ERROR ajeno'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SELECT public.conductor_revision_accion(NULL,'Pendiente','Completar evidencia',NULL,current_setting('test.t')::uuid);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento preventivo',1000,current_setting('test.d')::jsonb);
SELECT public.conductor_registrar(current_setting('test.v')::uuid,'Mantenimiento correctivo',1000,(current_setting('test.d')::jsonb-'servicio_id')||jsonb_build_object('actividad_id',current_setting('test.c'),'servicio','Cambiar bombillo'));
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SELECT public.conductor_revision_accion(NULL,'Cerrada','Validado',NULL,current_setting('test.t')::uuid);
SELECT public.conductor_revision_accion(current_setting('test.r')::uuid,'Cerrada','Validado',NULL,current_setting('test.c')::uuid);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.conductor_revision_resumen(current_setting('test.v')::uuid,true)->'tareas') t WHERE t->>'id'=current_setting('test.t') AND t->>'estado'='Cerrada') THEN RAISE EXCEPTION 'No cerró independiente'; END IF;
END $$;
ROLLBACK;
