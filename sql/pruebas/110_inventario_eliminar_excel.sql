-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;


DO $$ BEGIN IF to_regclass('public.inventario_estantes_origen') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 108'; END IF; END $$;
CREATE TABLE IF NOT EXISTS public.inventario_excel_eliminaciones (
 transferencia uuid PRIMARY KEY REFERENCES public.inventario_transferencias(id),
 solicitud text UNIQUE NOT NULL, actor uuid NOT NULL REFERENCES public.usuarios(id),
 fecha timestamptz NOT NULL DEFAULT now(), motivo text NOT NULL CHECK(length(btrim(motivo)) BETWEEN 1 AND 500),
 entrada jsonb NOT NULL, movimientos jsonb NOT NULL
);
ALTER TABLE public.inventario_excel_eliminaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_excel_eliminaciones FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_excel_eliminaciones;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_excel_eliminaciones
 FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
-- Mantener las entradas originales para auditoría, excluyéndolas de todo saldo operativo.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_viewdef('public.inventario_saldos'::regclass,true);
 IF strpos(ddl,'inventario_excel_eliminaciones')=0 THEN
 EXECUTE 'CREATE OR REPLACE VIEW public.inventario_saldos AS SELECT original.* FROM ('||rtrim(ddl,E';\n ')||') original WHERE NOT EXISTS (SELECT 1 FROM public.inventario_excel_eliminaciones e WHERE e.transferencia=original.id)';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_eliminar_excel(p_solicitud text,p_transferencia uuid,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t public.inventario_transferencias%rowtype; e public.inventario_excel_eliminaciones%rowtype; s record; m jsonb;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica el motivo de eliminación'; END IF;
 SELECT * INTO e FROM public.inventario_excel_eliminaciones WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (e.transferencia,e.actor,e.motivo) IS DISTINCT FROM (p_transferencia,a,btrim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN e.transferencia; END IF;
 SELECT * INTO t FROM public.inventario_transferencias WHERE id=p_transferencia;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id=t.item_id AND inventario_manual AND orden_id IS NULL) THEN RAISE EXCEPTION 'Solo se pueden eliminar entradas por Excel'; END IF;
 SELECT * INTO s FROM public.inventario_saldos WHERE id=t.id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Esta entrada ya fue eliminada'; END IF;
 IF s.reservado<>0 OR s.despachado<>0 OR s.libre<>t.cantidad
 OR EXISTS(SELECT 1 FROM public.reservas_despacho WHERE item_id=t.item_id)
 OR EXISTS(SELECT 1 FROM public.inventario_despachos WHERE transferencia=t.id AND NOT cancelado) THEN
 RAISE EXCEPTION 'No se puede eliminar: hay prendas reservadas, despachadas o movimientos posteriores'; END IF;
 -- La fila de importación tiene su propio artículo; no se toca ningún otro ingreso.
 IF (SELECT count(*) FROM public.inventario_transferencias WHERE item_id=t.item_id)<>1
 OR EXISTS(SELECT 1 FROM public.movimientos WHERE item_orden_id=t.item_id AND (tipo<>'recepcion' OR ubicacion_id IS DISTINCT FROM t.ubicacion_id))
 OR (SELECT coalesce(sum(cantidad),0) FROM public.movimientos WHERE item_orden_id=t.item_id)<>t.cantidad THEN RAISE EXCEPTION 'La entrada tiene ajustes posteriores; requiere revisión'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO m FROM public.movimientos x WHERE item_orden_id=t.item_id;
 INSERT INTO public.inventario_excel_eliminaciones(transferencia,solicitud,actor,motivo,entrada,movimientos)
 VALUES(t.id,p_solicitud,a,btrim(p_motivo),to_jsonb(t),m);
 DELETE FROM public.movimientos WHERE item_orden_id=t.item_id;
 UPDATE public.items_orden SET admin_eliminado_en=now() WHERE id=t.item_id;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN t.id;
END $$;
REVOKE ALL ON FUNCTION public.inventario_eliminar_excel(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_eliminar_excel(text,uuid,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
