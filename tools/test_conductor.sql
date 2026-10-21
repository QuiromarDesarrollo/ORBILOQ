SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT public.conductor_asignar_vehiculo('TEST01','Vehículo A',100,'2') AS vid \gset
SELECT set_config('test.vehiculo',:'vid',false);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.conductor_vehiculos) THEN RAISE EXCEPTION 'Filtración de vehículo'; END IF;
 BEGIN
 PERFORM public.conductor_registrar(current_setting('test.vehiculo')::uuid,'Registro diario',100,'{}');
 RAISE EXCEPTION 'Escritura ajena permitida';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.conductor_vehiculos)<>1 THEN RAISE EXCEPTION 'Conductor no ve asignación'; END IF;
 BEGIN
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(current_setting('test.vehiculo')::uuid,auth.uid(),'Falso','Registro diario',101,'{}');
 RAISE EXCEPTION 'Inserción directa permitida';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT public.conductor_registrar(:'vid','Registro diario',101,'{"notas":"Prueba","enlace":"https://drive.google.com/file/d/demo/view"}');
DO $$ DECLARE id uuid:=current_setting('test.vehiculo')::uuid; BEGIN
 BEGIN PERFORM public.conductor_registrar(id,'Registro diario',99,'{}');
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE '%kilometraje%' THEN RAISE; END IF;
 RETURN; END;
 RAISE EXCEPTION 'Permitió reducir kilometraje';
END $$;
DO $$ DECLARE id uuid:=current_setting('test.vehiculo')::uuid; BEGIN
 BEGIN PERFORM public.conductor_registrar(id,'Inicio de jornada',101,'{}');
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE '%Checklist%' THEN RAISE; END IF;
 RETURN; END;
 RAISE EXCEPTION 'Permitió checklist vacío';
END $$;
RESET ROLE;
DO $$ DECLARE datos jsonb; id uuid:=current_setting('test.vehiculo')::uuid; BEGIN
 SELECT jsonb_build_object('respuestas',jsonb_object_agg(p,'Buen estado'))
 INTO datos FROM unnest(ARRAY['Estado frenos','Nivel de aceite','Nivel de refrigerante',
 'Direccionales delanteras','Direccionales traseras','Luces altas','Luces bajas','Luces stop','Luces de parqueo',
 'Llantas delanteras','Llantas traseras','Llanta de repuesto','Limpiabrisas','Espejo lateral izquierdo',
 'Espejo lateral derecho','Vidrio panorámico','Pito','Pito reversa','Cinturón de seguridad','Puertas seguras',
 'Área de cargue','Interior cabina','Techos libres','Botiquín','Herramientas','Kit de derrames','Extintor']) p;
 PERFORM public.conductor_registrar(id,'Inicio de jornada',101,datos);
 BEGIN
 PERFORM public.conductor_registrar(id,'Inicio de jornada',101,datos);
 RAISE EXCEPTION 'Inicio duplicado permitido';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM public.conductor_registrar(id,'Fin de jornada',110,datos || '{"siniestro":false}');
 IF (SELECT km FROM public.conductor_vehiculos v WHERE v.id=current_setting('test.vehiculo')::uuid)<>110
 THEN RAISE EXCEPTION 'Kilometraje final incorrecto'; END IF;
END $$;
