/* ORBILOQ: diagnóstico previo, SOLO LECTURA.
   Base objetivo: producción cxrflhgnxvomcvxzugda (o su copia local).
   Ejecutar completo. No es una migración ni autoriza el despliegue.
   Compara fórmulas sin guardar resultados ni modificar registros.
   No exporta nombres, contraseñas ni registros individuales de Auth.
*/
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
WITH
conteos(tabla, filas) AS (
 SELECT 'ordenes_produccion',count(*) FROM public.ordenes_produccion UNION ALL
 SELECT 'items_orden',count(*) FROM public.items_orden UNION ALL
 SELECT 'movimientos',count(*) FROM public.movimientos UNION ALL
 SELECT 'lotes',count(*) FROM public.lotes UNION ALL
 SELECT 'lote_items',count(*) FROM public.lote_items UNION ALL
 SELECT 'clientes',count(*) FROM public.clientes UNION ALL
 SELECT 'devoluciones_cliente',count(*) FROM public.devoluciones_cliente UNION ALL
 SELECT 'devoluciones_produccion',count(*) FROM public.devoluciones_produccion UNION ALL
 SELECT 'liberaciones_no_conforme',count(*) FROM public.liberaciones_no_conforme UNION ALL
 SELECT 'no_conformes_aliados',count(*) FROM public.no_conformes_aliados UNION ALL
 SELECT 'liberaciones_aliados',count(*) FROM public.liberaciones_aliados UNION ALL
 SELECT 'sobrantes_bodega',count(*) FROM public.sobrantes_bodega UNION ALL
 SELECT 'documentos',count(*) FROM public.documentos UNION ALL
 SELECT 'importaciones',count(*) FROM public.importaciones UNION ALL
 SELECT 'usuarios',count(*) FROM public.usuarios UNION ALL
 SELECT 'ubicaciones',count(*) FROM public.ubicaciones UNION ALL
 SELECT 'causales_devolucion',count(*) FROM public.causales_devolucion UNION ALL
 SELECT 'personal_logistica',count(*) FROM public.personal_logistica UNION ALL
 SELECT 'personal_produccion',count(*) FROM public.personal_produccion UNION ALL
 SELECT 'personal_aliados',count(*) FROM public.personal_aliados
),
formulas_pruebas AS (
 SELECT io.id,
 coalesce(sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad
   WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad
   WHEN 'envio_aliado' THEN -m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad
   WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END),0) AS producido,
 coalesce(sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad
   WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0) AS recibido
 FROM public.items_orden io LEFT JOIN public.movimientos m ON m.item_orden_id=io.id
 GROUP BY io.id
),
comparacion AS (
 SELECT f.*,k.producido AS producido_actual,k.recibido AS recibido_actual
 FROM formulas_pruebas f JOIN public.vista_kardex k ON k.item_orden_id=f.id
),
stock AS (
 SELECT item_orden_id,ubicacion_id,
 sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad ELSE 0 END) AS anterior,
 sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
   WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END) AS propuesto
 FROM public.movimientos WHERE ubicacion_id IS NOT NULL
 GROUP BY item_orden_id,ubicacion_id
)
SELECT jsonb_build_object(
 'version','orbiloq_preflight_v1',
 'fecha_utc',now(),
 'base',current_database(),
 'conteos', (SELECT jsonb_object_agg(tabla,filas) FROM conteos),
 'usuarios',jsonb_build_object(
   'admins_activos',(SELECT count(*) FROM public.usuarios WHERE activo AND rol='admin'),
   'activos_sin_auth',(SELECT count(*) FROM public.usuarios u WHERE activo AND
       (auth_id IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users a WHERE a.id=u.auth_id))),
   'activos_sin_nombre',(SELECT count(*) FROM public.usuarios WHERE activo AND coalesce(trim(nombre),'')=''),
   'identidades_duplicadas',(SELECT count(*) FROM (SELECT auth_id FROM public.usuarios WHERE auth_id IS NOT NULL GROUP BY auth_id HAVING count(*)>1) d)),
 'integridad',jsonb_build_object(
   'items_sin_orden',(SELECT count(*) FROM public.items_orden i LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE o.id IS NULL),
   'movimientos_sin_item',(SELECT count(*) FROM public.movimientos m LEFT JOIN public.items_orden i ON i.id=m.item_orden_id WHERE i.id IS NULL),
   'movimientos_no_positivos',(SELECT count(*) FROM public.movimientos WHERE cantidad<=0),
   'items_oc_vacia',(SELECT count(*) FROM public.items_orden WHERE coalesce(trim(oc),'')=''),
   'lote_items_recibido_supera_enviado',(SELECT count(*) FROM public.lote_items WHERE cantidad_recibida>cantidad_enviada),
   'nc_sin_ubicacion',(SELECT count(*) FROM public.movimientos WHERE tipo='devolucion_produccion' AND ubicacion_id IS NULL)),
 'impacto_formulas_pruebas',jsonb_build_object(
   'lineas_cambia_producido',(SELECT count(*) FROM comparacion WHERE producido IS DISTINCT FROM producido_actual),
   'lineas_cambia_recibido',(SELECT count(*) FROM comparacion WHERE recibido IS DISTINCT FROM recibido_actual),
   'diferencia_total_producido',(SELECT coalesce(sum(producido-producido_actual),0) FROM comparacion),
   'diferencia_total_recibido',(SELECT coalesce(sum(recibido-recibido_actual),0) FROM comparacion),
   'ubicaciones_cambia_saldo',(SELECT count(*) FROM stock WHERE anterior<>propuesto),
   'ubicaciones_saldo_propuesto_negativo',(SELECT count(*) FROM stock WHERE propuesto<0)),
 'tipos_movimiento',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM
     (SELECT tipo,count(*) AS registros,sum(cantidad) AS unidades FROM public.movimientos GROUP BY tipo ORDER BY tipo) t),
 'recepcion_firmas',(SELECT coalesce(jsonb_agg(jsonb_build_object('argumentos',pg_get_function_arguments(p.oid),
       'resultado',pg_get_function_result(p.oid))),'[]'::jsonb)
     FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proname='recibir_lote_item'),
 'restricciones_no_validadas',(SELECT coalesce(jsonb_agg(c.conname),'[]'::jsonb) FROM pg_constraint c
     JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='public' AND NOT c.convalidated),
 'storage',jsonb_build_object('buckets',(SELECT count(*) FROM storage.buckets),
   'objetos_registrados',(SELECT count(*) FROM storage.objects),
   'aviso','El dump conserva metadatos; los archivos físicos requieren respaldo separado.'),
 'aviso','Hallazgos para revisar, no correcciones automáticas. Las diferencias de fórmulas no significan pérdida de filas.'
) AS diagnostico;
COMMIT;
