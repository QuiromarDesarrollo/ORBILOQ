-- ORBILOQ PRODUCCION: cxrflhgnxvomcvxzugda. Validar proyecto en el panel antes de ejecutar.
-- Optimiza SOLO la evaluacion del predicado USING, conservando permisos y datos.
-- wms_cuenta_activa no recibe datos de fila: SELECT permite un InitPlan por sentencia.
BEGIN;
SET LOCAL lock_timeout = '500ms';
SET LOCAL statement_timeout = '5s';
DO $migration$
DECLARE t text; p record;
BEGIN
  IF md5(replace(pg_get_functiondef('public.wms_cuenta_activa()'::regprocedure), E'\r\n', E'\n'))
      <> '22ed4e3986b546d43054c2014765043f' THEN
    RAISE EXCEPTION 'Cambio la funcion de acceso. Revisar antes de optimizar.';
  END IF;
  FOREACH t IN ARRAY ARRAY['items_orden','lote_items','lotes','ordenes_produccion','ubicaciones'] LOOP
    SELECT * INTO p FROM pg_policies WHERE schemaname='public' AND tablename=t
      AND policyname='wms_requiere_cuenta_activa';
    IF NOT FOUND OR p.permissive <> 'RESTRICTIVE' OR p.cmd <> 'ALL'
      OR p.roles <> ARRAY['authenticated']::name[]
      OR p.qual <> 'wms_cuenta_activa()' OR p.with_check <> 'wms_cuenta_activa()' THEN
      RAISE EXCEPTION 'Politica inesperada en %. No se aplico el cambio.', t;
    END IF;
    EXECUTE format('ALTER POLICY wms_requiere_cuenta_activa ON public.%I USING ((SELECT public.wms_cuenta_activa()))', t);
  END LOOP;
END $migration$;
COMMIT;


