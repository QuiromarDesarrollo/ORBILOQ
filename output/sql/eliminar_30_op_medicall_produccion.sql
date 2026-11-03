-- PRODUCCION: eliminacion permanente de las 30 OP indicadas por el usuario.
-- Ejecutar TODO el archivo en una sola ejecucion. COMMIT al final.
-- No desactiva restricciones ni triggers. Cualquier excepcion revierte el bloque.
BEGIN ISOLATION LEVEL SERIALIZABLE;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';

CREATE TEMP TABLE dep_objetivos(id uuid PRIMARY KEY, numero_op text) ON COMMIT DROP;
INSERT INTO dep_objetivos VALUES
('79898c39-0631-4bab-a1ae-61d86ff61b39', '25309-'),
('4bb87ca6-669e-4ed4-bad7-456fd63980f9', '25370-'),
('1a8db96d-2cbb-4827-a15d-82e8efd5c771', '25371-'),
('f5e9ccf2-714f-474a-b62f-a31f0aca6c12', '25381-'),
('1016dc61-6fbf-40f4-aaa7-f732b12eccfe', '25383-'),
('8510aef9-b5bd-468f-a2ff-7df9155f50d0', '25387-'),
('5621d20f-60a9-41c8-94d2-4004c32d97a4', '25390-'),
('f2505842-8bc5-4ea3-b07a-bf629fd243e8', '25391-'),
('17f77f23-3252-4b94-be49-c5090b2626d5', '25392-'),
('8bf61f2a-531a-4efc-8a86-b3aa85daea4f', '25393-'),
('c449719d-b064-45c6-a67c-0acd99790a42', '25394-'),
('3f8c5681-3e48-4267-93e9-5a66ff953577', '25395-'),
('17cd8e07-d842-44e8-8e88-498c5ee0ebae', '25396-'),
('df4e4c3d-24c4-4bf3-b41d-6a0b20321602', '25397-'),
('5c532ba9-5efa-41c1-b29d-0e0b13a428ff', '25398-'),
('6041979b-260d-4fa7-9f24-b9884487afb3', '25399-'),
('bb259f93-dd84-4db4-8ae5-21a55e9cb857', '25400-'),
('64563e92-bfc8-41c1-8baa-b6bfff9ff55e', '25401-'),
('a409b8a9-95c0-4890-bff6-874e2d7002f0', '25402-'),
('1fc0e578-5173-4d22-a62d-8bdca0d08f1f', '25412-'),
('305d15e9-483f-4a99-a69d-99f388d3e1d7', '25413-'),
('da63f8df-4e57-4adf-a2b6-3b619b67a466', '25415-'),
('a350339e-03e4-48ea-95fa-c5c22ca458c9', '25416-'),
('ed4b812e-308c-4478-bc43-0f947206ac94', '25417-'),
('6b0a24a6-fda3-4521-bb43-a059196a29a8', '25418-'),
('afcca484-eab5-43cd-a4d6-32530b8bcf5d', '25419-'),
('20ede621-1b0c-44e7-b0fc-78dff20be1d1', '25420-'),
('e9f1f86e-d267-4009-85d2-e0804323ef23', '25421-'),
('d45ab44f-2caa-4189-a954-4b454a665a98', '25422-'),
('2d32a7f8-abf4-408e-94f1-5e4dbac03d45', '25787-');

-- Bloqueo corto: evita cambios operativos mientras se elimina.
LOCK TABLE public.ordenes_produccion, public.items_orden,
 public.lote_items, public.lotes, public.movimientos, public.admin_correcciones,
 public.inventario_recepciones, public.inventario_transferencias,
 public.inventario_despachos, public.inventario_estantes_origen,
 public.inventario_excel_eliminaciones, public.inventario_reversiones,
 public.devoluciones_cliente, public.devoluciones_produccion,
 public.liberaciones_no_conforme, public.no_conformes_aliados,
 public.liberaciones_aliados, public.reservas_despacho, public.sobrantes_bodega
 IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE dep_items ON COMMIT DROP AS
 SELECT i.id FROM public.items_orden i JOIN dep_objetivos o ON o.id=i.orden_id;
CREATE TEMP TABLE dep_li ON COMMIT DROP AS
 SELECT id,lote_id FROM public.lote_items WHERE item_orden_id IN (SELECT id FROM dep_items);
CREATE TEMP TABLE dep_ac ON COMMIT DROP AS
 SELECT id FROM public.admin_correcciones
 WHERE orden_id IN (SELECT id FROM dep_objetivos)
 OR item_id IN (SELECT id FROM dep_items)
 OR lote_item_id IN (SELECT id FROM dep_li);
CREATE TEMP TABLE dep_mov ON COMMIT DROP AS
 SELECT id FROM public.movimientos
 WHERE item_orden_id IN (SELECT id FROM dep_items)
 OR lote_item_id IN (SELECT id FROM dep_li)
 OR admin_correccion_id IN (SELECT id FROM dep_ac);
CREATE TEMP TABLE dep_trans ON COMMIT DROP AS
 SELECT id FROM public.inventario_transferencias WHERE item_id IN (SELECT id FROM dep_items);
CREATE TEMP TABLE dep_nc ON COMMIT DROP AS
 SELECT id FROM public.no_conformes_aliados WHERE item_orden_id IN (SELECT id FROM dep_items);
CREATE TEMP TABLE dep_recepciones ON COMMIT DROP AS
 SELECT r.solicitud FROM public.inventario_recepciones r
 WHERE EXISTS (
 SELECT 1 FROM jsonb_array_elements(
 CASE WHEN jsonb_typeof(r.pedido->0)='array' THEN r.pedido->0 ELSE '[]'::jsonb END
 ) x WHERE x->>'linea' IN (SELECT id::text FROM dep_li));

CREATE TEMP TABLE dep_patron ON COMMIT DROP AS
 SELECT string_agg(valor,'|') expresion FROM (
 SELECT id::text valor FROM dep_objetivos
 UNION SELECT '"' || numero_op || '"' FROM dep_objetivos
 UNION SELECT id::text FROM dep_items
 UNION SELECT id::text FROM dep_li
 UNION SELECT id::text FROM dep_mov
 UNION SELECT id::text FROM dep_ac
 UNION SELECT id::text FROM dep_trans
 UNION SELECT id::text FROM dep_nc
 ) t;

DO $$
BEGIN
 IF (SELECT count(*) FROM public.ordenes_produccion o JOIN dep_objetivos t
 ON o.id=t.id AND o.numero_op=t.numero_op
 WHERE o.cliente='MEDICALL TALENTO HUMANO') <> 30 THEN
 RAISE EXCEPTION 'Las 30 OP ya no coinciden con los identificadores, numeros y cliente revisados';
 END IF;
 IF (SELECT count(*) FROM dep_items) <> 151 OR
    (SELECT count(*) FROM dep_recepciones) <> 287 THEN
 RAISE EXCEPTION 'Los conteos cambiaron: se esperaban 151 prendas y 287 recepciones. No se elimina nada';
 END IF;
 IF EXISTS (
 SELECT 1 FROM public.inventario_recepciones r
 JOIN dep_recepciones d USING(solicitud)
 CROSS JOIN LATERAL jsonb_array_elements(r.pedido->0) x
 WHERE NOT EXISTS (SELECT 1 FROM dep_li WHERE id::text=x->>'linea')
 ) THEN RAISE EXCEPTION 'Una recepcion incluye otras prendas o referencias desconocidas'; END IF;
 IF EXISTS (
 SELECT 1 FROM public.admin_correcciones a JOIN dep_ac d USING(id)
 WHERE a.item_id NOT IN (SELECT id FROM dep_items)
 OR a.orden_id NOT IN (SELECT id FROM dep_objetivos)
 OR (a.lote_item_id IS NOT NULL AND a.lote_item_id NOT IN (SELECT id FROM dep_li))
 ) THEN RAISE EXCEPTION 'Correccion compartida con otra OP'; END IF;
 IF EXISTS (
 SELECT 1 FROM public.movimientos m JOIN dep_mov d USING(id)
 WHERE m.item_orden_id NOT IN (SELECT id FROM dep_items)
 OR (m.lote_item_id IS NOT NULL AND m.lote_item_id NOT IN (SELECT id FROM dep_li))
 ) THEN RAISE EXCEPTION 'Movimiento compartido con otra OP'; END IF;
 IF EXISTS (
 SELECT 1 FROM public.devoluciones_cliente
 WHERE movimiento_id IN (SELECT id FROM dep_mov)
 AND item_orden_id NOT IN (SELECT id FROM dep_items)
 ) OR EXISTS (
 SELECT 1 FROM public.sobrantes_bodega
 WHERE lote_item_id IN (SELECT id FROM dep_li)
 AND item_orden_id NOT IN (SELECT id FROM dep_items)
 ) THEN RAISE EXCEPTION 'Devolucion o sobrante asociado a otra OP'; END IF;
END $$;

DELETE FROM public.inventario_recepciones WHERE solicitud IN (SELECT solicitud FROM dep_recepciones);
DELETE FROM public.devoluciones_cliente
 WHERE item_orden_id IN (SELECT id FROM dep_items) OR movimiento_id IN (SELECT id FROM dep_mov);
DELETE FROM public.devoluciones_produccion WHERE item_orden_id IN (SELECT id FROM dep_items);
DELETE FROM public.liberaciones_no_conforme WHERE item_orden_id IN (SELECT id FROM dep_items);
DELETE FROM public.liberaciones_aliados WHERE solicitud_id IN (SELECT id FROM dep_nc);
DELETE FROM public.no_conformes_aliados WHERE id IN (SELECT id FROM dep_nc);
DELETE FROM public.reservas_despacho WHERE item_id IN (SELECT id FROM dep_items);
DELETE FROM public.sobrantes_bodega
 WHERE item_orden_id IN (SELECT id FROM dep_items) OR lote_item_id IN (SELECT id FROM dep_li);
DELETE FROM public.inventario_despachos WHERE transferencia IN (SELECT id FROM dep_trans);
DELETE FROM public.inventario_estantes_origen WHERE transferencia IN (SELECT id FROM dep_trans);
DELETE FROM public.inventario_excel_eliminaciones WHERE transferencia IN (SELECT id FROM dep_trans);
DELETE FROM public.inventario_reversiones WHERE transferencia IN (SELECT id FROM dep_trans);
DELETE FROM public.inventario_transferencias WHERE id IN (SELECT id FROM dep_trans);
DELETE FROM public.movimientos WHERE id IN (SELECT id FROM dep_mov);
DELETE FROM public.admin_correcciones WHERE id IN (SELECT id FROM dep_ac);
DELETE FROM public.lote_items WHERE id IN (SELECT id FROM dep_li);
-- Solo cabeceras de lotes que quedan vacias, sin movimientos de otras OP.
DELETE FROM public.lotes l
 WHERE l.id IN (SELECT lote_id FROM dep_li)
 AND NOT EXISTS (SELECT 1 FROM public.lote_items li WHERE li.lote_id=l.id)
 AND NOT EXISTS (SELECT 1 FROM public.movimientos m WHERE m.lote_id=l.id);
DELETE FROM public.items_orden WHERE id IN (SELECT id FROM dep_items);
DELETE FROM public.ordenes_produccion WHERE id IN (SELECT id FROM dep_objetivos);

-- Si quedan referencias JSON, revierte TODO para poder revisarlas.
DO $$
DECLARE c record; n bigint; patron text;
BEGIN
 SELECT expresion INTO patron FROM dep_patron;
 FOR c IN
 SELECT a.table_schema,a.table_name,a.column_name
 FROM information_schema.columns a
 JOIN information_schema.tables t USING(table_schema,table_name)
 WHERE a.table_schema='public' AND a.data_type IN ('json','jsonb')
 AND t.table_type='BASE TABLE'
 LOOP
 EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I::text ~ $1',
 c.table_schema,c.table_name,c.column_name) INTO n USING patron;
 IF n>0 THEN
 RAISE EXCEPTION 'Quedan % referencias en %.%. Se revierte toda la eliminacion',
 n,c.table_name,c.column_name;
 END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE id IN (SELECT id FROM dep_objetivos))
 OR EXISTS(SELECT 1 FROM public.items_orden WHERE id IN (SELECT id FROM dep_items)) THEN
 RAISE EXCEPTION 'La comprobacion final fallo. Se revierte toda la eliminacion';
 END IF;
END $$;

SELECT (SELECT count(*) FROM dep_objetivos) AS ordenes_eliminadas,
 (SELECT count(*) FROM dep_items) AS prendas_eliminadas,
 (SELECT count(*) FROM dep_mov) AS movimientos_eliminados,
 (SELECT count(*) FROM dep_recepciones) AS recepciones_eliminadas;
COMMIT;

