-- SOLO PRUEBAS. NO ejecutar en produccion.
-- Basado en el informe (15), PostgreSQL 17.6, esquema public.
-- No copia, elimina ni reinicia datos. Cambios incrementales, transaccionales.
-- Las correcciones se agregan al ledger con signo y referencia de auditoria.
-- Se conservan movimientos originales y se sincronizan los totales de lotes.
-- Preparar una migracion DISTINTA de produccion al autorizar el despliegue.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $$ BEGIN
  IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
    RAISE EXCEPTION 'DETENIDO: estructura de produccion/ERP detectada. Este archivo es exclusivo de PRUEBAS.';
  END IF;
  IF to_regprocedure('public.recibir_lote_item(uuid,integer,uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Falta la recepcion de cinco parametros esperada en PRUEBAS.';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_correcciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.items_orden(id),
  orden_id uuid NOT NULL REFERENCES public.ordenes_produccion(id),
  actor_id uuid NOT NULL,
  actor text NOT NULL,
  fecha timestamptz NOT NULL DEFAULT now(),
  campo text NOT NULL,
  anterior jsonb, nuevo jsonb,
  motivo text NOT NULL CHECK (length(trim(motivo)) > 0),
  antes jsonb NOT NULL, despues jsonb NOT NULL,
  lote_item_id uuid REFERENCES public.lote_items(id),
  ubicacion_id uuid REFERENCES public.ubicaciones(id),
  lote_antes jsonb, lote_despues jsonb
);
CREATE INDEX IF NOT EXISTS admin_correcciones_item_fecha ON public.admin_correcciones(item_id, fecha DESC);
ALTER TABLE public.admin_correcciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_fecha_entrega date;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_fecha_entrega_activa boolean NOT NULL DEFAULT false;
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS admin_correccion_id uuid REFERENCES public.admin_correcciones(id);
CREATE INDEX IF NOT EXISTS movimientos_admin_correccion_idx ON public.movimientos(admin_correccion_id)
  WHERE admin_correccion_id IS NOT NULL;

-- La restriccion de cantidad de PRUEBAS no existia en el informe (15).
-- NOT VALID mantiene datos historicos, pero valida TODOS los nuevos cambios.
-- No permite cantidades negativas ordinarias: solo correcciones auditadas.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.movimientos'::regclass
                 AND conname = 'movimientos_cantidad_admin_check') THEN
    ALTER TABLE public.movimientos ADD CONSTRAINT movimientos_cantidad_admin_check
      CHECK (cantidad > 0 OR (cantidad < 0 AND admin_correccion_id IS NOT NULL)) NOT VALID;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_es_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT auth.uid() IS NOT NULL AND EXISTS (
  SELECT 1 FROM public.usuarios WHERE auth_id = auth.uid() AND rol = 'admin' AND activo
); $$;
REVOKE ALL ON FUNCTION public.admin_es_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_es_admin() TO authenticated;

-- Impide elevar el propio rol usando la politica historica solo_autenticados.
DROP POLICY IF EXISTS admin_proteger_usuarios_insert ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_insert ON public.usuarios AS RESTRICTIVE
  FOR INSERT TO authenticated WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_usuarios_update ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_update ON public.usuarios AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_usuarios_delete ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_delete ON public.usuarios AS RESTRICTIVE
  FOR DELETE TO authenticated USING (public.admin_es_admin());

-- Las correcciones solo pueden escribirse dentro de la RPC SECURITY DEFINER.
REVOKE ALL ON public.admin_correcciones FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_correcciones TO authenticated;
DROP POLICY IF EXISTS admin_leer_auditoria ON public.admin_correcciones;
CREATE POLICY admin_leer_auditoria ON public.admin_correcciones FOR SELECT
  TO authenticated USING (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_movimientos ON public.movimientos;
CREATE POLICY admin_proteger_movimientos ON public.movimientos AS RESTRICTIVE
  FOR ALL TO authenticated USING (true) WITH CHECK (admin_correccion_id IS NULL);
DROP POLICY IF EXISTS admin_no_borrar_ajustes ON public.movimientos;
CREATE POLICY admin_no_borrar_ajustes ON public.movimientos AS RESTRICTIVE
  FOR DELETE TO authenticated USING (admin_correccion_id IS NULL);
DROP POLICY IF EXISTS admin_no_modificar_ajustes ON public.movimientos;
CREATE POLICY admin_no_modificar_ajustes ON public.movimientos AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (admin_correccion_id IS NULL);

DROP POLICY IF EXISTS admin_editar_items ON public.items_orden;
CREATE POLICY admin_editar_items ON public.items_orden AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_editar_ordenes ON public.ordenes_produccion;
CREATE POLICY admin_editar_ordenes ON public.ordenes_produccion AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());

-- Misma lista y orden de columnas que el informe de PRUEBAS.
-- Aliados conserva el comportamiento historico de esta vista: no se migra
-- ese flujo como efecto secundario de la edicion del administrador.
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
  coalesce(sum(CASE m.tipo WHEN 'envio_aliado' THEN m.cantidad WHEN 'liberacion_aliado' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_aliados
FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id = io.orden_id
LEFT JOIN public.movimientos m ON m.item_orden_id = io.id
GROUP BY io.id, op.numero_op, op.cliente, op.fecha_esperada_produccion, op.fecha_esperada_logistica;

-- Las correcciones de PNC nuevas SI identifican la ubicacion afectada.
-- Los PNC antiguos sin ubicacion no se asignan automaticamente a un estante.
CREATE OR REPLACE VIEW public.vista_stock_ubicacion_detalle AS
SELECT m.item_orden_id, u.codigo AS ubicacion_codigo,
  sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad
    WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) AS cantidad
FROM public.movimientos m JOIN public.ubicaciones u ON u.id = m.ubicacion_id
WHERE m.tipo IN ('recepcion','despacho','devolucion_produccion')
GROUP BY m.item_orden_id, u.codigo
HAVING sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad
  WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) > 0;

CREATE OR REPLACE FUNCTION public.admin_contexto_edicion(p_item_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE v jsonb; k jsonb; o uuid; v_version text;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  SELECT orden_id INTO o FROM public.items_orden WHERE id = p_item_id;
  IF o IS NULL THEN RAISE EXCEPTION 'La fila no existe.'; END IF;
  SELECT to_jsonb(t) INTO k FROM public.vista_kardex t WHERE item_orden_id = p_item_id;
  k := jsonb_set(k, '{fecha_ultima_entrega}', coalesce(to_jsonb(
    ((k->>'fecha_ultima_entrega')::timestamptz AT TIME ZONE 'America/Bogota')::date), 'null'::jsonb));
  -- El token incluye operaciones, metadatos, ubicaciones y lineas de la OP.
  SELECT md5(jsonb_build_array(
    (SELECT to_jsonb(t) FROM public.ordenes_produccion t WHERE id = o),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.items_orden t WHERE orden_id = o),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.movimientos t WHERE item_orden_id = p_item_id),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.lote_items t WHERE item_orden_id = p_item_id),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ubicaciones t),
    (SELECT count(*) FROM public.admin_correcciones WHERE orden_id = o)
  )::text) INTO v_version;
  v := jsonb_build_object('version', v_version, 'valores', k,
    'filas_orden', (SELECT count(*) FROM public.items_orden WHERE orden_id = o),
    'lotes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', li.id, 'numero', l.numero,
      'enviada', li.cantidad_enviada, 'recibida', coalesce(li.cantidad_recibida,0),
      'origen', li.origen) ORDER BY l.fecha_envio DESC,li.id)
      FROM public.lote_items li JOIN public.lotes l ON l.id = li.lote_id WHERE li.item_orden_id = p_item_id),'[]'::jsonb),
    'ubicaciones', coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'codigo',codigo) ORDER BY codigo)
      FROM public.ubicaciones WHERE activa),'[]'::jsonb),
    'historial', coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.fecha DESC) FROM (
      SELECT campo, anterior, nuevo, motivo, actor, fecha FROM public.admin_correcciones
      WHERE item_id = p_item_id OR (orden_id = o AND campo IN ('numero_op','cliente','fecha_esperada_produccion','fecha_esperada_logistica'))
      ORDER BY fecha DESC, id DESC LIMIT 20) h),'[]'::jsonb));
  RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.admin_contexto_edicion(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_contexto_edicion(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_editar_kardex(
  p_item_id uuid, p_campo text, p_valor jsonb, p_motivo text, p_version text,
  p_lote_item_id uuid DEFAULT NULL, p_ubicacion_id uuid DEFAULT NULL, p_confirmar boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE
  ctx jsonb; a jsonb; d jsonb; v jsonb; li public.lote_items%rowtype;
  io public.items_orden%rowtype; v_actor public.usuarios%rowtype;
  v_id uuid; v_tipo text; v_col text; v_num integer; v_delta integer;
  v_stock bigint; v_registrado bigint; v_p bigint; v_r bigint; v_d bigint; v_q bigint;
  v_text text; v_fecha date; v_lote_antes jsonb; v_lote_despues jsonb;
  v_nuevo_lote boolean := false;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF p_confirmar IS NULL THEN RAISE EXCEPTION 'Falta confirmar la operación.'; END IF;
  IF coalesce(length(trim(p_motivo)),0) = 0 THEN RAISE EXCEPTION 'Indica el motivo de la corrección.'; END IF;
  IF p_campo IS NULL OR p_campo NOT IN ('numero_op','cliente','oc','codigo','descripcion','talla','observacion_op',
    'cantidad_pedida','producido','recibido','despachado','pendiente_reproceso',
    'fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    RAISE EXCEPTION 'Campo no editable; selecciona el dato de origen del cálculo.';
  END IF;
  -- Bloqueo breve para validar y guardar una correccion como una unidad.
  -- Todas las correcciones adquieren tablas en el mismo orden.
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'La cuenta ya no es administradora.'; END IF;
  SELECT * INTO v_actor FROM public.usuarios WHERE auth_id = auth.uid() AND rol = 'admin' AND activo;
  SELECT * INTO io FROM public.items_orden WHERE id = p_item_id;
  ctx := public.admin_contexto_edicion(p_item_id);
  IF p_version IS DISTINCT FROM ctx->>'version' THEN
    RAISE EXCEPTION 'La fila cambió. Cierra y vuelve a abrir la edición antes de guardar.';
  END IF;
  a := ctx->'valores'; d := a; v := coalesce(p_valor, 'null'::jsonb);
  IF a->p_campo IS NOT DISTINCT FROM v THEN RAISE EXCEPTION 'El valor no cambió.'; END IF;

  IF p_campo IN ('cantidad_pedida','producido','recibido','despachado','pendiente_reproceso') THEN
    IF jsonb_typeof(v) <> 'number' OR (v #>> '{}') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'Ingresa una cantidad entera no negativa.';
    END IF;
    v_num := (v #>> '{}')::integer;
    IF p_campo = 'cantidad_pedida' AND v_num = 0 THEN RAISE EXCEPTION 'La cantidad pedida debe ser mayor a cero.'; END IF;
    v_delta := v_num - (a->>p_campo)::integer;
    d := jsonb_set(d, ARRAY[p_campo], v);
    IF p_campo = 'pendiente_reproceso' THEN
      d := jsonb_set(d, '{producido}', to_jsonb((a->>'producido')::bigint-v_delta));
      d := jsonb_set(d, '{recibido}', to_jsonb((a->>'recibido')::bigint-v_delta));
    END IF;
    v_q := (d->>'cantidad_pedida')::bigint; v_p := (d->>'producido')::bigint;
    v_r := (d->>'recibido')::bigint; v_d := (d->>'despachado')::bigint;
    IF v_p < 0 OR v_r < 0 OR v_d < 0 OR v_p > v_q OR v_d > v_q OR v_d > v_r OR v_r > v_p THEN
      RAISE EXCEPTION 'La corrección dejaría cantidades incompatibles. Revisa las operaciones relacionadas.';
    END IF;
    IF p_campo IN ('producido','recibido') THEN
      IF p_campo = 'producido' AND p_lote_item_id IS NULL AND v_delta > 0 THEN
        v_nuevo_lote := true;
        li.cantidad_enviada := 0; li.cantidad_recibida := 0; li.origen := 'entrega';
      ELSE
      SELECT * INTO li FROM public.lote_items WHERE id = p_lote_item_id AND item_orden_id = p_item_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona el lote afectado de esta fila.'; END IF;
      v_lote_antes := to_jsonb(li);
      END IF;
      IF EXISTS (SELECT 1 FROM public.movimientos WHERE lote_item_id = li.id AND tipo = 'ajuste_faltante_entrega') THEN
        RAISE EXCEPTION 'El lote está cerrado con faltante. Revisa esa corrección antes de cambiar su entrega o recepción.';
      END IF;
      IF p_campo = 'producido' THEN
        IF li.origen <> 'entrega' THEN RAISE EXCEPTION 'Selecciona un lote de entrega, no de reproceso.'; END IF;
        IF li.cantidad_enviada + v_delta <= 0 OR li.cantidad_enviada + v_delta < coalesce(li.cantidad_recibida,0) THEN
          RAISE EXCEPTION 'La entrega del lote debe ser positiva y cubrir lo recibido.';
        END IF;
      ELSIF coalesce(li.cantidad_recibida,0)+v_delta < 0 OR coalesce(li.cantidad_recibida,0)+v_delta > li.cantidad_enviada THEN
        RAISE EXCEPTION 'La recepción corregida debe estar entre cero y lo enviado en el lote.';
      END IF;
    END IF;
    IF p_campo IN ('recibido','despachado','pendiente_reproceso') THEN
      IF NOT EXISTS (SELECT 1 FROM public.ubicaciones WHERE id = p_ubicacion_id AND activa) THEN
        RAISE EXCEPTION 'Selecciona una ubicación válida.';
      END IF;
      SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
        WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO v_stock
      FROM public.movimientos WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id;
      IF v_stock + (CASE WHEN p_campo = 'recibido' THEN v_delta ELSE -v_delta END) < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente en la ubicación.';
      END IF;
      IF v_delta < 0 THEN
        v_tipo := CASE p_campo WHEN 'recibido' THEN 'recepcion' WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
        SELECT coalesce(sum(cantidad),0) INTO v_registrado FROM public.movimientos
        WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id AND tipo = v_tipo
          AND (p_campo <> 'recibido' OR lote_item_id = p_lote_item_id);
        IF v_registrado + v_delta < 0 THEN
          RAISE EXCEPTION 'No hay suficiente cantidad registrada en esa ubicación/lote para reducirla. Los registros históricos sin ubicación requieren conciliación explícita.';
        END IF;
      END IF;
    END IF;
  ELSIF p_campo IN ('fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    IF v <> 'null'::jsonb THEN
      IF jsonb_typeof(v) <> 'string' OR (v #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha inválida; usa AAAA-MM-DD.'; END IF;
      v_fecha := (v #>> '{}')::date;
    END IF;
    d := jsonb_set(d, ARRAY[p_campo], v);
  ELSE
    IF jsonb_typeof(v) <> 'string' THEN RAISE EXCEPTION 'El campo requiere texto.'; END IF;
    v_text := trim(v #>> '{}');
    IF p_campo IN ('numero_op','cliente','codigo','descripcion') AND v_text = '' THEN RAISE EXCEPTION 'Completa el valor del campo.'; END IF;
    IF p_campo = 'numero_op' AND EXISTS (SELECT 1 FROM public.ordenes_produccion WHERE numero_op = v_text AND id <> io.orden_id) THEN
      RAISE EXCEPTION 'Ya existe otra orden con ese número.';
    END IF;
    IF p_campo IN ('codigo','talla') AND EXISTS (SELECT 1 FROM public.items_orden WHERE orden_id = io.orden_id AND id <> io.id
      AND codigo = CASE WHEN p_campo = 'codigo' THEN v_text ELSE io.codigo END
      AND talla = CASE WHEN p_campo = 'talla' THEN v_text ELSE io.talla END) THEN
      RAISE EXCEPTION 'Ya existe el código y talla en esta OP.';
    END IF;
    v := to_jsonb(v_text); d := jsonb_set(d, ARRAY[p_campo],v);
  END IF;
  IF NOT p_confirmar THEN RETURN jsonb_build_object('antes',a,'despues',d,'guardado',false); END IF;
  INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues,lote_item_id,ubicacion_id,lote_antes)
  VALUES(io.id,io.orden_id,auth.uid(),v_actor.nombre,p_campo,a->p_campo,v,trim(p_motivo),a,d,
    CASE WHEN p_campo IN ('producido','recibido') THEN p_lote_item_id END,
    CASE WHEN p_campo IN ('recibido','despachado','pendiente_reproceso') THEN p_ubicacion_id END,v_lote_antes)
  RETURNING id INTO v_id;
  IF p_campo IN ('producido','recibido','despachado','pendiente_reproceso') THEN
    IF v_nuevo_lote THEN
      INSERT INTO public.lotes(numero,operario_id,operario_nombre)
      VALUES('AJUSTE-'||v_id::text,v_actor.id,v_actor.nombre) RETURNING id INTO li.lote_id;
      INSERT INTO public.lote_items(lote_id,item_orden_id,cantidad_enviada,origen)
      VALUES(li.lote_id,io.id,v_delta,'entrega') RETURNING id INTO li.id;
      UPDATE public.admin_correcciones SET lote_item_id=li.id WHERE id=v_id;
    END IF;
    v_tipo := CASE p_campo WHEN 'producido' THEN 'entrega_produccion' WHEN 'recibido' THEN 'recepcion'
      WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
    INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,lote_id,lote_item_id,usuario_id,nota,admin_correccion_id)
    VALUES(v_tipo,p_item_id,v_delta,CASE WHEN p_campo <> 'producido' THEN p_ubicacion_id END,
      li.lote_id,li.id,v_actor.id,'Corrección administrativa: '||trim(p_motivo),v_id);
    IF p_campo IN ('producido','recibido') THEN
      UPDATE public.lote_items SET
        cantidad_enviada = cantidad_enviada + CASE WHEN p_campo = 'producido' AND NOT v_nuevo_lote THEN v_delta ELSE 0 END,
        cantidad_recibida = CASE WHEN p_campo = 'recibido' THEN coalesce(cantidad_recibida,0)+v_delta ELSE cantidad_recibida END
      WHERE id = li.id;
      UPDATE public.lote_items SET estado = CASE WHEN coalesce(cantidad_recibida,0) >= cantidad_enviada
        THEN 'recibido_conforme' ELSE 'en_transito' END WHERE id = li.id;
      UPDATE public.lotes SET estado = CASE
        WHEN NOT EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND estado = 'en_transito') THEN 'recibido_completo'
        WHEN EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND coalesce(cantidad_recibida,0)>0) THEN 'recibido_parcial'
        ELSE 'en_transito' END WHERE id = li.lote_id;
      SELECT to_jsonb(t) INTO v_lote_despues FROM public.lote_items t WHERE id = li.id;
      UPDATE public.admin_correcciones SET lote_despues = v_lote_despues WHERE id = v_id;
    END IF;
  ELSIF p_campo = 'cantidad_pedida' THEN
    UPDATE public.items_orden SET cantidad_pedida = v_num WHERE id = io.id;
  ELSIF p_campo = 'fecha_ultima_entrega' THEN
    UPDATE public.items_orden SET admin_fecha_entrega = v_fecha, admin_fecha_entrega_activa = true WHERE id = io.id;
  ELSIF p_campo IN ('fecha_esperada_produccion','fecha_esperada_logistica') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_fecha, io.orden_id;
  ELSIF p_campo IN ('numero_op','cliente') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_text, io.orden_id;
  ELSE
    v_col := CASE WHEN p_campo = 'observacion_op' THEN 'observacion' ELSE p_campo END;
    EXECUTE format('UPDATE public.items_orden SET %I = $1 WHERE id = $2', v_col) USING v_text, io.id;
  END IF;
  RETURN jsonb_build_object('antes',a,'despues',d,'guardado',true,'auditoria_id',v_id);
END $$;
REVOKE ALL ON FUNCTION public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean) TO authenticated;

-- Despacho debe descontar el PNC ubicado que ahora puede registrar el admin.
-- Misma firma: no se agrega una sobrecarga ni se modifica el contrato Flutter.
CREATE OR REPLACE FUNCTION public.despachar(p_item_orden_id uuid, p_cantidad integer, p_ubicacion_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE v_stock bigint; v_recibido bigint; v_despachado bigint; v_pedida integer;
BEGIN
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN RAISE EXCEPTION 'La cantidad debe ser mayor a cero.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN
    RAISE EXCEPTION 'Ubicación no válida.';
  END IF;
  SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
    WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO v_stock
  FROM public.movimientos WHERE item_orden_id=p_item_orden_id AND ubicacion_id=p_ubicacion_id;
  SELECT recibido,despachado,cantidad_pedida INTO v_recibido,v_despachado,v_pedida
  FROM public.vista_kardex WHERE item_orden_id=p_item_orden_id;
  IF v_pedida IS NULL THEN RAISE EXCEPTION 'El producto no existe.'; END IF;
  IF p_cantidad > v_stock OR p_cantidad > v_recibido-v_despachado THEN
    RAISE EXCEPTION 'Stock insuficiente para despachar.';
  END IF;
  IF p_cantidad > v_pedida-v_despachado THEN RAISE EXCEPTION 'La cantidad supera el pendiente por despachar.'; END IF;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id)
  VALUES('despacho',p_item_orden_id,p_cantidad,p_ubicacion_id);
  RETURN jsonb_build_object('item_orden_id',p_item_orden_id,'cantidad',p_cantidad);
END $$;

-- Las RPC operativas deben tomar el mismo bloqueo ANTES de leer saldos.
-- Evita que una entrega calcule un limite viejo mientras el admin corrige.
-- Solo agrega un prefijo al cuerpo; conserva firmas, defaults y ACL actuales.
DO $locks$
DECLARE f record; ddl text;
BEGIN
  FOR f IN SELECT p.oid, p.oid::regprocedure AS firma FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prokind='f' AND p.proname IN (
      'crear_lote','recibir_lote_item','cerrar_lote_item_con_faltante',
      'registrar_no_conforme','liberar_no_conforme','enviar_no_conforme_aliado',
      'liberar_no_conforme_aliado','importar_ordenes_produccion','importar_fechas_esperadas')
  LOOP
    ddl := pg_get_functiondef(f.oid);
    IF strpos(ddl,'ORBILOQ_ADMIN_LOCK_V55')=0 THEN
      IF ddl !~* E'\\mbegin\\M' THEN RAISE EXCEPTION 'No se reconoce el cuerpo de %',f.firma; END IF;
      ddl := regexp_replace(ddl, '^begin[ \t]*\r?$',
        E'begin\n  -- ORBILOQ_ADMIN_LOCK_V55\n  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;', 'im');
      IF strpos(ddl,'ORBILOQ_ADMIN_LOCK_V55')=0 THEN RAISE EXCEPTION 'No se pudo proteger %',f.firma; END IF;
      EXECUTE ddl;
    END IF;
    EXECUTE format('ALTER FUNCTION %s SET lock_timeout = %L',f.firma,'5s');
  END LOOP;
END $locks$;

-- Publicar metadatos para que otras sesiones refresquen al editar una OP.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='items_orden') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.items_orden;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='ordenes_produccion') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.ordenes_produccion;
    END IF;
  END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
