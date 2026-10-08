-- DIAGNOSTICO DE SOLO LECTURA. Ejecutar completo en Supabase de PRUEBAS.
-- No crea, actualiza ni elimina datos. Exportar el resultado completo como CSV.
-- Investiga la OP 90003: incluye lineas ocultas, identificadas como tales.
-- Las cantidades son firmadas: las correcciones negativas NO se convierten a positivas.
-- "diferencia_por_explicar" no significa perdida de unidades: requiere revisar
-- los movimientos, correcciones y lotes incluidos en las otras secciones.
WITH seleccion AS (
  SELECT k.* FROM public.vista_kardex k
  WHERE k.numero_op = '90003'
), movimientos AS (
  SELECT m.*,
    CASE m.tipo
      WHEN 'entrega_produccion' THEN m.cantidad
      WHEN 'devolucion_produccion' THEN -m.cantidad
      WHEN 'liberacion_no_conforme' THEN m.cantidad
      WHEN 'envio_aliado' THEN -m.cantidad
      WHEN 'liberacion_aliado' THEN m.cantidad
      WHEN 'ajuste_faltante_entrega' THEN -m.cantidad
      ELSE 0 END::bigint AS efecto_producido,
    CASE m.tipo WHEN 'recepcion' THEN m.cantidad
      WHEN 'devolucion_produccion' THEN -m.cantidad
      ELSE 0 END::bigint AS efecto_recibido
  FROM public.movimientos m
  JOIN seleccion k ON k.item_orden_id = m.item_orden_id
), resumen_movimientos AS (
  SELECT item_orden_id, count(*) AS numero_movimientos,
    sum(efecto_producido) AS producido_calculado,
    sum(efecto_recibido) AS recibido_calculado,
    sum(CASE WHEN tipo = 'despacho' THEN cantidad ELSE 0 END) AS despachado_calculado,
    sum(CASE WHEN admin_correccion_id IS NOT NULL THEN efecto_producido ELSE 0 END) AS ajuste_admin_producido,
    sum(CASE WHEN admin_correccion_id IS NOT NULL THEN efecto_recibido ELSE 0 END) AS ajuste_admin_recibido,
    sum(CASE WHEN tipo = 'entrega_produccion' AND lote_item_id IS NULL THEN cantidad ELSE 0 END) AS entregas_sin_lote_item
  FROM movimientos GROUP BY item_orden_id
), resumen_lotes AS (
  SELECT li.item_orden_id, count(*) AS numero_lotes_items,
    sum(li.cantidad_enviada) AS enviado_en_lotes,
    sum(coalesce(li.cantidad_recibida, 0)) AS recibido_en_lotes,
    count(*) FILTER (WHERE li.estado = 'en_transito') AS lineas_en_transito,
    sum(CASE WHEN li.estado = 'en_transito'
      THEN li.cantidad_enviada - coalesce(li.cantidad_recibida, 0) ELSE 0 END) AS pendiente_en_lotes_abiertos
  FROM public.lote_items li
  JOIN seleccion k ON k.item_orden_id = li.item_orden_id
  GROUP BY li.item_orden_id
), resumen AS (
  SELECT k.numero_op, k.item_orden_id, k.codigo, k.talla,
    k.admin_eliminado_en IS NOT NULL AS fila_oculta,
    k.cantidad_pedida, k.producido, k.recibido, k.despachado,
    k.recibido - k.despachado AS bodega_segun_app,
    greatest(0, k.cantidad_pedida - k.despachado) AS pendiente_del_pedido,
    (k.recibido - k.despachado) - greatest(0, k.cantidad_pedida - k.despachado) AS diferencia_bodega_vs_pendiente,
    k.recibido - k.cantidad_pedida AS recibido_por_encima_del_pedido,
    greatest(0, k.recibido - k.despachado) AS disponible_para_despachar,
    k.pendiente_reproceso, k.pendiente_aliados,
    k.producido - k.recibido AS diferencia_entregado_recibido,
    coalesce(l.pendiente_en_lotes_abiertos, 0) AS pendiente_en_lotes_abiertos,
    k.producido - k.recibido - coalesce(l.pendiente_en_lotes_abiertos, 0) AS diferencia_por_explicar,
    coalesce(m.ajuste_admin_producido, 0) AS ajuste_admin_producido,
    coalesce(m.ajuste_admin_recibido, 0) AS ajuste_admin_recibido,
    coalesce(m.ajuste_admin_producido, 0) - coalesce(m.ajuste_admin_recibido, 0) AS efecto_admin_en_diferencia,
    k.producido - k.recibido - coalesce(l.pendiente_en_lotes_abiertos, 0)
      - coalesce(m.ajuste_admin_producido, 0) + coalesce(m.ajuste_admin_recibido, 0) AS diferencia_sin_efecto_admin,
    coalesce(m.entregas_sin_lote_item, 0) AS entregas_sin_lote_item,
    coalesce(l.enviado_en_lotes, 0) AS enviado_en_lotes,
    coalesce(l.recibido_en_lotes, 0) AS recibido_en_lotes,
    coalesce(l.lineas_en_transito, 0) AS lineas_en_transito,
    coalesce(m.numero_movimientos, 0) AS numero_movimientos,
    k.producido = coalesce(m.producido_calculado, 0)
      AND k.recibido = coalesce(m.recibido_calculado, 0)
      AND k.despachado = coalesce(m.despachado_calculado, 0) AS vista_coincide_con_movimientos
  FROM seleccion k
  LEFT JOIN resumen_movimientos m USING (item_orden_id)
  LEFT JOIN resumen_lotes l USING (item_orden_id)
), salida AS (
  SELECT '00_control'::text AS seccion, ''::text AS numero_op,
    ''::text AS codigo, ''::text AS talla,
    jsonb_build_object('fecha_consulta', current_timestamp,
      'lineas_encontradas', (SELECT count(*) FROM seleccion),
      'nota', 'Solo lectura. Si no hay lineas, comprobar proyecto de pruebas y numeros de OP. Los totales siguientes excluyen filas ocultas.') AS detalle_json
  UNION ALL
  SELECT '01_totales_visibles', '', '', '', jsonb_build_object(
    'lineas', count(*), 'pedidas', coalesce(sum(cantidad_pedida), 0),
    'producido', coalesce(sum(producido), 0), 'recibido', coalesce(sum(recibido), 0),
    'despachado', coalesce(sum(despachado), 0),
    'disponible_para_despachar', coalesce(sum(disponible_para_despachar), 0),
    'pendiente_lotes', coalesce(sum(pendiente_en_lotes_abiertos), 0),
    'diferencia_por_explicar', coalesce(sum(diferencia_por_explicar), 0),
    'efecto_admin_en_diferencia', coalesce(sum(efecto_admin_en_diferencia), 0),
    'diferencia_sin_efecto_admin', coalesce(sum(diferencia_sin_efecto_admin), 0))
  FROM resumen WHERE NOT fila_oculta
  UNION ALL
  SELECT '02_resumen_por_linea', r.numero_op, r.codigo, r.talla, to_jsonb(r)
  FROM resumen r
  UNION ALL
  SELECT '03_movimientos_por_tipo', k.numero_op, k.codigo, k.talla,
    jsonb_build_object('item_id', k.item_orden_id, 'tipo', m.tipo,
      'correccion_admin', m.admin_correccion_id IS NOT NULL,
      'numero_movimientos', count(*), 'cantidad_neta', sum(m.cantidad),
      'efecto_producido', sum(m.efecto_producido), 'efecto_recibido', sum(m.efecto_recibido))
  FROM seleccion k JOIN movimientos m USING (item_orden_id)
  GROUP BY k.numero_op, k.codigo, k.talla, k.item_orden_id, m.tipo, (m.admin_correccion_id IS NOT NULL)
  UNION ALL
  SELECT '04_lotes_detalle', k.numero_op, k.codigo, k.talla,
    to_jsonb(li) || jsonb_build_object('pendiente_si_abierto',
      CASE WHEN li.estado = 'en_transito' THEN li.cantidad_enviada - coalesce(li.cantidad_recibida, 0) ELSE 0 END)
  FROM seleccion k JOIN public.lote_items li USING (item_orden_id)
  UNION ALL
  SELECT '05_correcciones_detalle', k.numero_op, k.codigo, k.talla, to_jsonb(a)
  FROM seleccion k JOIN public.admin_correcciones a ON a.item_id = k.item_orden_id
  UNION ALL
  SELECT '06_movimientos_detalle', k.numero_op, k.codigo, k.talla, to_jsonb(m) || jsonb_build_object('fecha_bogota', m.fecha AT TIME ZONE 'America/Bogota', 'saldo_bodega_acumulado', sum(m.efecto_recibido - CASE WHEN m.tipo='despacho' THEN m.cantidad ELSE 0 END) OVER (PARTITION BY m.item_orden_id ORDER BY m.fecha,m.id ROWS UNBOUNDED PRECEDING))
  FROM seleccion k JOIN movimientos m USING (item_orden_id)
  UNION ALL
  SELECT '07_sobrantes', k.numero_op, k.codigo, k.talla, to_jsonb(s)
  FROM seleccion k JOIN public.sobrantes_bodega s USING (item_orden_id)
  UNION ALL
  SELECT '08_definicion_vista', '', '', '',
    jsonb_build_object('vista', pg_get_viewdef('public.vista_kardex'::regclass, true))
)
SELECT seccion, numero_op, codigo, talla, detalle_json,
  count(*) OVER () AS total_filas_exportacion
FROM salida
ORDER BY seccion, numero_op, codigo, talla, detalle_json->>'fecha', detalle_json->>'id';
