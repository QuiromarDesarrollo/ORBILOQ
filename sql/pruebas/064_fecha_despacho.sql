-- SOLO PRUEBAS. Aplicar después de 063. No modifica ni elimina movimientos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $migracion$
DECLARE definicion text;
BEGIN
 IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
   RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS.';
 END IF;
 IF to_regprocedure('public.despachar_oc(text,text,text,jsonb)') IS NULL THEN
   RAISE EXCEPTION 'Aplicar primero 063.';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='vista_kardex' AND column_name='fecha_ultimo_despacho') THEN
   definicion := rtrim(pg_get_viewdef('public.vista_kardex'::regclass,true), E';\n ');
   EXECUTE 'CREATE OR REPLACE VIEW public.vista_kardex AS SELECT k.*, '
     || '(SELECT max(m.fecha) FROM public.movimientos m WHERE m.item_orden_id=k.item_orden_id AND m.tipo=''despacho'' AND m.cantidad>0) AS fecha_ultimo_despacho '
     || 'FROM (' || definicion || ') k';
 END IF;
END $migracion$;
NOTIFY pgrst,'reload schema';
COMMIT;
