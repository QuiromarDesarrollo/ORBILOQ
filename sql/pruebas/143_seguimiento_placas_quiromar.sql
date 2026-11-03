-- ORBILOQ-DEV: catálogo de placas para el seguimiento de entregas.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe'
 THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_placas_quiromar()
RETURNS TABLE(placa text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN
  RAISE EXCEPTION 'Sin acceso a seguimiento' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT v.placa FROM public.conductor_vehiculos v ORDER BY v.placa;
END $$;
REVOKE ALL ON FUNCTION public.seguimiento_placas_quiromar() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_placas_quiromar() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
