-- SOLO ORBILOQ-DEV. Requiere 089. No modifica fechas ya guardadas.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ DECLARE f text;
 regla text := $regla$IF f IS NOT NULL AND (f<(d.fecha AT TIME ZONE 'America/Bogota')::date OR f>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'La recepción debe estar entre el despacho y hoy'; END IF;$regla$;
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 SELECT pg_get_functiondef('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)'::regprocedure) INTO f;
 IF position('public.seguimiento_acceso()' in f)=0 THEN RAISE EXCEPTION 'Requiere permisos de 089'; END IF;
 IF position('FECHA_LIBRE_V91' in f)>0 THEN RETURN; END IF;
 IF position(regla in f)=0 THEN RAISE EXCEPTION 'Validación de fecha inesperada; revisar antes de aplicar'; END IF;
 -- Conserva conversión a date, control de versiones, estados, archivos y permisos.
 EXECUTE replace(f,regla,'-- FECHA_LIBRE_V91: la fecha válida la elige el usuario, sin límites relativos al despacho o a hoy.');
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
