-- SOLO PRUEBAS. Requiere 055 y 057. Ejecutar completo antes de abrir la nueva UI.
-- Borrado logico: conserva items, OP, lotes, movimientos, stock y auditoria.
-- No ejecutar en PRODUCCION: preparar migracion especifica al desplegar.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
    RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS. No ejecutar en produccion.';
  END IF;
  IF to_regprocedure('public.admin_contexto_edicion(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero 055 y 057 en PRUEBAS.';
  END IF;
END $$;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_eliminado_en timestamptz;
-- La vista conserva todas las filas: las tablas de la app filtran la marca.
CREATE OR REPLACE VIEW public.vista_kardex AS
SELECT io.id AS item_orden_id, op.numero_op, op.cliente, io.oc, io.codigo,
  io.descripcion, io.talla, io.cantidad_pedida, io.observacion AS observacion_op,
  op.fecha_esperada_produccion, op.fecha_esperada_logistica,
  coalesce(sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad
    WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad
    WHEN 'envio_aliado' THEN -m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad
    WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END),0)::bigint AS producido,
  coalesce(sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0)::bigint AS recibido,
  coalesce(sum(CASE WHEN m.tipo = 'despacho' THEN m.cantidad ELSE 0 END),0)::bigint AS despachado,
  CASE WHEN io.admin_fecha_entrega_activa THEN io.admin_fecha_entrega::timestamp AT TIME ZONE 'America/Bogota'
    ELSE max(CASE WHEN m.tipo = 'entrega_produccion' AND m.admin_correccion_id IS NULL THEN m.fecha END) END AS fecha_ultima_entrega,
  max(CASE WHEN m.tipo = 'recepcion' AND m.admin_correccion_id IS NULL THEN m.fecha END) AS fecha_ultima_recepcion,
  coalesce(sum(CASE m.tipo WHEN 'devolucion_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_reproceso,
  coalesce(sum(CASE m.tipo WHEN 'envio_aliado' THEN m.cantidad WHEN 'liberacion_aliado' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_aliados, io.admin_eliminado_en
FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id = io.orden_id
LEFT JOIN public.movimientos m ON m.item_orden_id = io.id
GROUP BY io.id, op.numero_op, op.cliente, op.fecha_esperada_produccion, op.fecha_esperada_logistica;

CREATE OR REPLACE FUNCTION public.admin_eliminar_linea(p_item_id uuid, p_version text, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE ctx jsonb; io public.items_orden%rowtype; actor_nombre text; marca timestamptz;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF coalesce(length(trim(p_motivo)),0) = 0 THEN RAISE EXCEPTION 'Indica el motivo del borrado.'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  ctx := public.admin_contexto_edicion(p_item_id);
  IF p_version IS DISTINCT FROM ctx->>'version' THEN
    RAISE EXCEPTION 'La fila cambio. Cierra y vuelve a abrir la confirmacion.';
  END IF;
  SELECT * INTO io FROM public.items_orden WHERE id = p_item_id;
  IF io.admin_eliminado_en IS NOT NULL THEN RAISE EXCEPTION 'La fila ya esta borrada.'; END IF;
  SELECT nombre INTO actor_nombre FROM public.usuarios WHERE auth_id = auth.uid() AND activo AND rol = 'admin';
  marca := clock_timestamp();
  UPDATE public.items_orden SET admin_eliminado_en = marca WHERE id = p_item_id;
  INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues)
  VALUES(io.id,io.orden_id,auth.uid(),actor_nombre,'admin_eliminado_en','null'::jsonb,to_jsonb(marca),trim(p_motivo),
    ctx->'valores',jsonb_set(ctx->'valores','{admin_eliminado_en}',to_jsonb(marca)));
END $$;
REVOKE ALL ON FUNCTION public.admin_eliminar_linea(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_eliminar_linea(uuid,text,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
