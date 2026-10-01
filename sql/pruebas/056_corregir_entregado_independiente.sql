-- v56: correccion independiente del entregado. SOLO DEV; aplicar despues de 055.
-- No reduce recepciones, despachos ni stock. Conserva movimientos y auditoria.
-- Recalcula pendientes. Una recepcion superior a la entrega corregida queda
-- como novedad, sin borrar ni ajustar sus cantidades automaticamente.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
    RAISE EXCEPTION 'Este archivo es exclusivo de PRUEBAS. No ejecutar en produccion.';
  END IF;
  IF to_regprocedure('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero 055_edicion_admin.sql en PRUEBAS.';
  END IF;
END $$;
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
    IF v_p < 0 OR v_r < 0 OR v_d < 0 OR v_p > v_q OR v_d > v_q OR v_d > v_r OR (p_campo <> 'producido' AND v_r > v_p AND v_r-v_p > greatest((a->>'recibido')::bigint-(a->>'producido')::bigint,0)) THEN
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
        IF li.cantidad_enviada + v_delta <= 0 THEN
          RAISE EXCEPTION 'La entrega del lote debe ser positiva. Distribuye la corrección entre los lotes afectados.';
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
      UPDATE public.lote_items SET estado = CASE WHEN coalesce(cantidad_recibida,0) > cantidad_enviada THEN 'recibido_con_novedad' WHEN coalesce(cantidad_recibida,0) = cantidad_enviada
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

NOTIFY pgrst, 'reload schema';
COMMIT;

