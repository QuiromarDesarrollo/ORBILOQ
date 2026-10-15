-- SOLO LECTURA. Ejecutar completo en la base de pruebas que contiene la OP 90006.
-- No elimina, modifica ni reinicia nada. Compartir todas las filas del resultado.
-- Incluye registros de otras OP si comparten lotes/despachos: no autoriza borrarlos.
BEGIN TRANSACTION READ ONLY;
WITH items AS (
 SELECT i.id, i.orden_id FROM public.items_orden i
 JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE o.numero_op='90006'
), lotes_ids AS (
 SELECT lote_id id FROM public.lote_items WHERE item_orden_id IN (SELECT id FROM items)
 UNION SELECT lote_id FROM public.movimientos WHERE item_orden_id IN (SELECT id FROM items) AND lote_id IS NOT NULL
), despachos_ids AS (
 SELECT despacho_oc_id id FROM public.movimientos WHERE item_orden_id IN (SELECT id FROM items) AND despacho_oc_id IS NOT NULL
 UNION SELECT despacho_id FROM public.reservas_despacho WHERE item_id IN (SELECT id FROM items)
), claves AS (
 SELECT id::text clave FROM items UNION SELECT orden_id::text FROM items
 UNION SELECT id::text FROM lotes_ids UNION SELECT id::text FROM despachos_ids
), filas AS (
SELECT 'ordenes_produccion'::text tabla, to_jsonb(t) fila FROM public.ordenes_produccion t
 UNION ALL
SELECT 'items_orden'::text tabla, to_jsonb(t) fila FROM public.items_orden t
 UNION ALL
SELECT 'movimientos'::text tabla, to_jsonb(t) fila FROM public.movimientos t
 UNION ALL
SELECT 'lotes'::text tabla, to_jsonb(t) fila FROM public.lotes t
 UNION ALL
SELECT 'lote_items'::text tabla, to_jsonb(t) fila FROM public.lote_items t
 UNION ALL
SELECT 'despachos_oc'::text tabla, to_jsonb(t) fila FROM public.despachos_oc t
 UNION ALL
SELECT 'listas_empaque'::text tabla, to_jsonb(t) fila FROM public.listas_empaque t
 UNION ALL
SELECT 'reservas_despacho'::text tabla, to_jsonb(t) fila FROM public.reservas_despacho t
 UNION ALL
SELECT 'despacho_revisiones'::text tabla, to_jsonb(t) fila FROM public.despacho_revisiones t
 UNION ALL
SELECT 'empaque_solicitudes'::text tabla, to_jsonb(t) fila FROM public.empaque_solicitudes t
 UNION ALL
SELECT 'seguimiento_entregas'::text tabla, to_jsonb(t) fila FROM public.seguimiento_entregas t
 UNION ALL
SELECT 'documentos'::text tabla, to_jsonb(t) fila FROM public.documentos t
 UNION ALL
SELECT 'devoluciones_cliente'::text tabla, to_jsonb(t) fila FROM public.devoluciones_cliente t
 UNION ALL
SELECT 'liberaciones_aliados'::text tabla, to_jsonb(t) fila FROM public.liberaciones_aliados t
 UNION ALL
SELECT 'no_conformes_aliados'::text tabla, to_jsonb(t) fila FROM public.no_conformes_aliados t
 UNION ALL
SELECT 'liberaciones_no_conforme'::text tabla, to_jsonb(t) fila FROM public.liberaciones_no_conforme t
 UNION ALL
SELECT 'devoluciones_produccion'::text tabla, to_jsonb(t) fila FROM public.devoluciones_produccion t
 UNION ALL
SELECT 'sobrantes_bodega'::text tabla, to_jsonb(t) fila FROM public.sobrantes_bodega t
 UNION ALL
SELECT 'admin_correcciones'::text tabla, to_jsonb(t) fila FROM public.admin_correcciones t
), salida AS (
 SELECT tabla AS seccion, fila AS detalle FROM filas
 WHERE EXISTS(SELECT 1 FROM claves WHERE strpos(fila::text,clave)>0)
 UNION ALL
 SELECT 'funciones_validacion', jsonb_build_object('firma',p.oid::regprocedure::text,'definicion',pg_get_functiondef(p.oid))
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('registrar_no_conforme','validar_stock_no_conforme')
 UNION ALL
 SELECT 'relaciones_fk', jsonb_build_object('tabla',c.conrelid::regclass::text,'nombre',c.conname,'definicion',pg_get_constraintdef(c.oid))
 FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
 WHERE c.contype='f' AND n.nspname='public'
 UNION ALL
 SELECT 'control',jsonb_build_object('fecha',now(),'project_ref',current_setting('app.settings.project_ref',true),
 'lineas_op',(SELECT count(*) FROM items),
 'identidad_conocida',(SELECT count(*) FROM items WHERE id='53b8074d-f912-4e06-bd60-15e01a8a88b5'::uuid))
)
SELECT seccion,detalle FROM salida ORDER BY seccion,detalle::text;
COMMIT;
