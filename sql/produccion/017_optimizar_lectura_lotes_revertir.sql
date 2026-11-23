-- Reversion exclusiva del cambio 017; no altera registros ni otras politicas.
-- PRODUCCION cxrflhgnxvomcvxzugda; misma sentencia aplicable a DEV para restaurar 144.
BEGIN;
SET LOCAL lock_timeout='500ms';
SET LOCAL statement_timeout='5s';
DO $rollback$
DECLARE t text; p record;
BEGIN
  FOREACH t IN ARRAY ARRAY['items_orden','lote_items','lotes','ordenes_produccion','ubicaciones'] LOOP
    SELECT * INTO p FROM pg_policies WHERE schemaname='public' AND tablename=t
      AND policyname='wms_requiere_cuenta_activa';
    IF NOT FOUND OR p.permissive <> 'RESTRICTIVE' OR p.cmd <> 'ALL'
      OR p.roles <> ARRAY['authenticated']::name[]
      OR p.with_check <> 'wms_cuenta_activa()'
      OR regexp_replace(p.qual,'\s','','g') <> '(SELECTwms_cuenta_activa()ASwms_cuenta_activa)' THEN
      RAISE EXCEPTION 'Politica inesperada en %. Revisar antes de revertir.',t;
    END IF;
    EXECUTE format('ALTER POLICY wms_requiere_cuenta_activa ON public.%I USING (public.wms_cuenta_activa())',t);
  END LOOP;
END $rollback$;
COMMIT;
