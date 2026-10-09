-- SOLO LECTURA. Ejecutar en la misma base que muestra la OP 90006.
-- No modifica inventario ni oculta saldos negativos.
WITH seleccion AS (
 SELECT * FROM public.vista_kardex WHERE numero_op='90006'
), ledger AS (
 SELECT m.*, k.numero_op,k.talla,k.codigo,
 CASE m.tipo WHEN 'recepcion' THEN m.cantidad
 WHEN 'despacho' THEN -m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END efecto_bodega
 FROM public.movimientos m JOIN seleccion k USING(item_orden_id)
), cronologia AS (
 SELECT *,sum(efecto_bodega) OVER(PARTITION BY item_orden_id ORDER BY fecha,id ROWS UNBOUNDED PRECEDING) saldo_bodega
 FROM ledger
), salida AS (
 SELECT '01_resumen' seccion,k.talla,k.item_orden_id::text referencia,
 to_jsonb(k)||jsonb_build_object('bodega',k.recibido-k.despachado) detalle
 FROM seleccion k
 UNION ALL
 SELECT '02_movimientos',m.talla,m.id::text,to_jsonb(m) FROM cronologia m
 UNION ALL
 SELECT '03_correcciones',k.talla,a.id::text,to_jsonb(a)
 FROM public.admin_correcciones a JOIN seleccion k ON k.item_orden_id=a.item_id
 UNION ALL
 SELECT '04_lotes',k.talla,li.id::text,to_jsonb(li)
 FROM public.lote_items li JOIN seleccion k USING(item_orden_id)
 UNION ALL
 SELECT DISTINCT '05_despachos',k.talla,d.id::text,to_jsonb(d)
 FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.detalle) x
 JOIN seleccion k ON k.item_orden_id::text=x->>'item_id'
 UNION ALL
 SELECT '06_reservas',k.talla,k.item_orden_id::text,to_jsonb(r)
 FROM public.reservas_despacho r JOIN seleccion k ON k.item_orden_id=r.item_id
)
SELECT seccion,talla,referencia,detalle FROM salida
ORDER BY seccion,talla,detalle->>'fecha',referencia;
