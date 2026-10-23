-- SOLO PRUEBAS. Aplicar después de 124.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
-- El resumen pertenece al vehículo; no expone el historial privado del conductor.
CREATE OR REPLACE FUNCTION public.conductor_actualizar_preventivo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE inicio timestamp; fin timestamp; anterior timestamp; servicio text; dias integer; resumen jsonb; vdatos jsonb;
BEGIN
 IF NEW.tipo NOT IN ('Mantenimiento preventivo','Mantenimiento correctivo') THEN RETURN NEW; END IF;
 -- Compatibilidad con registros anteriores a esta versión.
 IF NOT (NEW.datos ? 'fecha_inicio' OR NEW.datos ? 'fecha_fin' OR NEW.datos ? 'servicio_id') THEN RETURN NEW; END IF;
 IF coalesce(NEW.datos->>'fecha_inicio','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'fecha_fin','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'hora_inicio','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 OR coalesce(NEW.datos->>'hora_fin','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 THEN RAISE EXCEPTION 'Fecha y hora de inicio y fin requeridas'; END IF;
 inicio := ((NEW.datos->>'fecha_inicio')||' '||(NEW.datos->>'hora_inicio'))::timestamp;
 fin := ((NEW.datos->>'fecha_fin')||' '||(NEW.datos->>'hora_fin'))::timestamp;
 IF fin < inicio THEN RAISE EXCEPTION 'El fin no puede ser anterior al inicio'; END IF;
 IF NEW.tipo <> 'Mantenimiento preventivo' THEN RETURN NEW; END IF;
 servicio:=NEW.datos->>'servicio_id';
 IF servicio IS NULL OR servicio NOT IN ('limpieza','limpiabrisas','combustible','aceite','refrigerante','neumaticos','discos','calibracion') THEN RAISE EXCEPTION 'Servicio preventivo invalido'; END IF;
 SELECT datos INTO vdatos FROM public.conductor_vehiculos WHERE id=NEW.vehiculo_id FOR UPDATE;
 resumen:=coalesce(vdatos->'mantenimientos_preventivos','{}'::jsonb);
 anterior:=nullif(resumen->servicio->>'fin','')::timestamp;
 IF anterior IS NOT NULL AND anterior > fin THEN RETURN NEW; END IF;
 resumen:=jsonb_set(resumen,ARRAY[servicio],jsonb_build_object('fin',to_char(fin,'YYYY-MM-DD"T"HH24:MI:SS'),'km',NEW.km));
 UPDATE public.conductor_vehiculos SET datos=jsonb_set(datos,'{mantenimientos_preventivos}',resumen)
   || CASE WHEN servicio='aceite' THEN jsonb_build_object('proximo_aceite',NEW.km+8000) ELSE '{}'::jsonb END
 WHERE id=NEW.vehiculo_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.conductor_actualizar_preventivo() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS conductor_actualizar_preventivo ON public.conductor_registros;
CREATE TRIGGER conductor_actualizar_preventivo AFTER INSERT ON public.conductor_registros
FOR EACH ROW EXECUTE FUNCTION public.conductor_actualizar_preventivo();
NOTIFY pgrst,'reload schema';
COMMIT;
