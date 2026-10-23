BEGIN;
DO $$ DECLARE v uuid; actor uuid; d jsonb; BEGIN
 SELECT id INTO actor FROM auth.users LIMIT 1;
 SELECT id INTO v FROM public.conductor_vehiculos WHERE placa='TEST02';
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos) VALUES(v,actor,'Prueba','Mantenimiento preventivo',1000,'{"servicio_id":"aceite","fecha_inicio":"2026-10-23","hora_inicio":"10:00","fecha_fin":"2026-10-24","hora_fin":"11:00"}');
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos) VALUES(v,actor,'Prueba','Mantenimiento preventivo',1000,'{"servicio_id":"revision_preventiva","fecha_inicio":"2026-10-23","hora_inicio":"10:00","fecha_fin":"2026-10-24","hora_fin":"11:00"}');
 IF (SELECT datos->'mantenimientos_preventivos'->'revision_preventiva'->>'fin' FROM public.conductor_vehiculos WHERE id=v) IS DISTINCT FROM '2026-10-24T11:00:00' THEN RAISE EXCEPTION 'Revision preventiva no guardada'; END IF;
 SELECT datos INTO d FROM public.conductor_vehiculos WHERE id=v;
 IF (d->>'proximo_aceite')::int<>9000 OR d->'mantenimientos_preventivos'->'aceite'->>'fin'<>'2026-10-24T11:00:00' THEN RAISE EXCEPTION 'Programacion incorrecta'; END IF;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos) VALUES(v,actor,'Prueba','Mantenimiento preventivo',900,'{"servicio_id":"aceite","fecha_inicio":"2026-10-22","hora_inicio":"10:00","fecha_fin":"2026-10-22","hora_fin":"11:00"}');
 IF (SELECT datos->>'proximo_aceite' FROM public.conductor_vehiculos WHERE id=v)<>'9000' THEN RAISE EXCEPTION 'Registro antiguo reinicia intervalo'; END IF;
 BEGIN
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos) VALUES(v,actor,'Prueba','Mantenimiento preventivo',1000,'{"servicio_id":"aceite","fecha_inicio":"2026-10-23","hora_inicio":"12:00","fecha_fin":"2026-10-23","hora_fin":"11:00"}');
 RAISE EXCEPTION 'NO_VALIDO';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='NO_VALIDO' THEN RAISE; END IF; END;
END $$;
ROLLBACK;
