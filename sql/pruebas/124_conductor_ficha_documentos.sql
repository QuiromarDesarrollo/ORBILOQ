-- SOLO PRUEBAS. Aplicar después de 123.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_limpiar_ficha_reasignada()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
 IF OLD.conductor_id IS DISTINCT FROM NEW.conductor_id THEN
   NEW.datos := coalesce(NEW.datos,'{}'::jsonb) - ARRAY[
     'conductor_documento','foto_conductor','Licencia de conducción','doc_licencia',
     'licencia_desde','licencia_expedido','licencia_valor','licencia_observaciones'];
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.conductor_limpiar_ficha_reasignada() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS conductor_limpiar_ficha_reasignada ON public.conductor_vehiculos;
CREATE TRIGGER conductor_limpiar_ficha_reasignada BEFORE UPDATE OF conductor_id ON public.conductor_vehiculos
FOR EACH ROW EXECUTE FUNCTION public.conductor_limpiar_ficha_reasignada();
NOTIFY pgrst,'reload schema';
COMMIT;
