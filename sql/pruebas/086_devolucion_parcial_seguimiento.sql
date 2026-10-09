-- SOLO ORBILOQ-DEV. Requiere 085. Ejecutar completo.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
ALTER TABLE public.seguimiento_entregas DROP CONSTRAINT IF EXISTS seguimiento_estado_valido;
ALTER TABLE public.seguimiento_entregas ADD CONSTRAINT seguimiento_estado_valido
 CHECK(estado IN ('en_transito','entregado','devuelto_cliente','devolucion_parcial'));
NOTIFY pgrst,'reload schema';
COMMIT;
