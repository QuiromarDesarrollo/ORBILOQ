SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SET ROLE authenticated;
SELECT public.conductor_asignar_vehiculo('TEST02','Vehículo B',10,'3');
DO $$ BEGIN
 IF (SELECT count(*) FROM public.conductor_flota_resumen())<>2 THEN RAISE EXCEPTION 'Flota incompleta'; END IF;
END $$;
SELECT public.conductor_asignar_vehiculo('TEST02','Vehículo B',10,'2');
RESET ROLE;
DO $$ BEGIN
 IF (SELECT conductor_id FROM public.conductor_vehiculos WHERE placa='TEST01') IS NOT NULL THEN RAISE EXCEPTION 'Asignación duplicada'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.conductor_registros r JOIN public.conductor_vehiculos v ON v.id=r.vehiculo_id WHERE v.placa='TEST01' AND r.tipo='Inicio de jornada' AND r.actor_id='00000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'Historia modificada'; END IF;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 SELECT id,'00000000-0000-0000-0000-000000000002','Conductor A','Inicio de jornada',10,jsonb_build_object('fecha',to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD')) FROM public.conductor_vehiculos WHERE placa='TEST02';
END $$;
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN
 PERFORM public.conductor_asignar_vehiculo('TEST02','Vehículo B',10,'3');
 RAISE EXCEPTION 'Reasignación durante jornada permitida';
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE 'Finaliza la jornada%' THEN RAISE; END IF;
 END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_flota_resumen(); RAISE EXCEPTION 'Flota expuesta a conductor';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF (SELECT count(*) FROM public.conductor_vehiculos)<>1 OR NOT EXISTS(SELECT 1 FROM public.conductor_vehiculos WHERE placa='TEST02') THEN RAISE EXCEPTION 'Acceso no actualizado'; END IF;
END $$;
RESET ROLE;
