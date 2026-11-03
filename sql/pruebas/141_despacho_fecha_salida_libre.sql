-- ORBILOQ-DEV. Permite elegir cualquier fecha de salida en la LE administrativa.
-- Conserva el resto de la función, incluidos permisos, idempotencia y auditoría.
BEGIN;
SET LOCAL lock_timeout='5s';

DO $$
DECLARE
 f text;
 limite text := 'IF p_fecha IS NOT NULL AND (p_fecha<''2000-01-01''::date OR p_fecha>(now() AT TIME ZONE ''America/Bogota'')::date) THEN RAISE EXCEPTION ''Fecha de salida invalida''; END IF;';
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
   AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden
   WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;

 SELECT pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure) INTO f;
 IF position('LE_DISPONIBLE_V120' IN f)=0 THEN
  RAISE EXCEPTION 'Requiere el ajuste de consecutivos de 120';
 END IF;
 IF position('DESPACHO_FECHA_LIBRE_V141' IN f)=0 THEN
  IF position(limite IN f)=0 THEN
   RAISE EXCEPTION 'No se encontró el límite de fechas esperado en admin_confirmar_le';
  END IF;
  f:=replace(f,limite,'-- DESPACHO_FECHA_LIBRE_V141: fecha administrativa libre.');
  EXECUTE f;
 END IF;
END $$;

DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure) INTO f;
 IF position('DESPACHO_FECHA_LIBRE_V141' IN f)=0 OR position('Fecha de salida invalida' IN f)>0 THEN
  RAISE EXCEPTION 'La fecha libre de salida no quedó instalada';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
