-- SOLO ORBILOQ-DEV. Ejecutar UNA VEZ, completo, sin usuarios operando.
-- Reinicia exclusivamente OP 90003 y agrega OP 90004, 90005 y 90006.
-- Guarda copia JSON de las filas afectadas en un esquema privado, en la misma transaccion.
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE SCHEMA IF NOT EXISTS respaldo_pruebas;
REVOKE ALL ON SCHEMA respaldo_pruebas FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS respaldo_pruebas.reinicios (
  clave text PRIMARY KEY, fecha timestamptz NOT NULL DEFAULT now(), datos jsonb NOT NULL
);
ALTER TABLE respaldo_pruebas.reinicios ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON respaldo_pruebas.reinicios FROM PUBLIC,anon,authenticated;
DO $reinicio$
DECLARE
  item uuid := '3bf42515-968d-4505-aae4-8fd62408bec2';
  orden uuid := '75b814c7-e6c0-4526-ba4d-cf5ac8d5e649';
  lotes_ids uuid[]; despachos_ids uuid[]; copia jsonb; nueva uuid; n integer;
BEGIN
  IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
    RAISE EXCEPTION 'Solo ORBILOQ-DEV. No ejecutar en produccion.';
  END IF;
  LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,
    public.movimientos,public.admin_correcciones,public.despachos_oc,
    public.sobrantes_bodega,public.devoluciones_produccion,public.devoluciones_cliente,
    public.liberaciones_no_conforme,public.no_conformes_aliados,public.documentos
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
    OR NOT EXISTS(SELECT 1 FROM public.items_orden i JOIN public.ordenes_produccion o ON o.id=i.orden_id
      WHERE i.id=item AND o.id=orden AND o.numero_op='90003' AND i.codigo='TEST-TRAZ-001' AND i.talla='M'
      AND o.cliente='CLIENTE PRUEBA TRAZABILIDAD') THEN
    RAISE EXCEPTION 'No coincide la identidad de la OP de pruebas. No se cambio nada.';
  END IF;
  IF (SELECT count(*) FROM public.items_orden WHERE orden_id=orden)<>1 THEN
    RAISE EXCEPTION 'La OP tiene otras lineas. Revisar antes de reiniciar.';
  END IF;
  IF EXISTS(SELECT 1 FROM respaldo_pruebas.reinicios WHERE clave='reinicio-90003-20261006') THEN
    RAISE EXCEPTION 'Este reinicio ya fue ejecutado. No se repetira ni borrara trabajo nuevo.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE numero_op IN ('90004','90005','90006')) THEN
    RAISE EXCEPTION 'Ya existe alguna OP nueva propuesta. No se reemplazara.';
  END IF;
  SELECT coalesce(array_agg(DISTINCT id),ARRAY[]::uuid[]) INTO lotes_ids FROM (
    SELECT lote_id id FROM public.lote_items WHERE item_orden_id=item
    UNION SELECT lote_id FROM public.movimientos WHERE item_orden_id=item AND lote_id IS NOT NULL
  ) x;
  SELECT coalesce(array_agg(DISTINCT despacho_oc_id),ARRAY[]::uuid[]) INTO despachos_ids
    FROM public.movimientos WHERE item_orden_id=item AND despacho_oc_id IS NOT NULL;
  IF EXISTS(SELECT 1 FROM public.lote_items WHERE lote_id=ANY(lotes_ids) AND item_orden_id<>item)
    OR EXISTS(SELECT 1 FROM public.movimientos WHERE (lote_id=ANY(lotes_ids) OR despacho_oc_id=ANY(despachos_ids)) AND item_orden_id<>item)
    OR EXISTS(SELECT 1 FROM public.admin_correcciones WHERE orden_id=orden AND item_id<>item) THEN
    RAISE EXCEPTION 'Hay lotes o despachos compartidos. Se requiere revision; no se modifico nada.';
  END IF;
  -- No adivinar como eliminar dependencias que no aparecieron en el diagnostico.
  IF EXISTS(SELECT 1 FROM public.sobrantes_bodega WHERE item_orden_id=item)
    OR EXISTS(SELECT 1 FROM public.devoluciones_produccion WHERE item_orden_id=item)
    OR EXISTS(SELECT 1 FROM public.devoluciones_cliente WHERE item_orden_id=item)
    OR EXISTS(SELECT 1 FROM public.liberaciones_no_conforme WHERE item_orden_id=item)
    OR EXISTS(SELECT 1 FROM public.no_conformes_aliados WHERE item_orden_id=item)
    OR EXISTS(SELECT 1 FROM public.documentos WHERE entidad_id=item OR entidad_id=orden OR entidad_id=ANY(lotes_ids) OR entidad_id=ANY(despachos_ids)) THEN
    RAISE EXCEPTION 'Hay dependencias adicionales. Detener y revisar sin borrar datos.';
  END IF;
  copia := jsonb_build_object(
    'ordenes_produccion',(SELECT jsonb_agg(to_jsonb(t)) FROM public.ordenes_produccion t WHERE id=orden),
    'items_orden',(SELECT jsonb_agg(to_jsonb(t)) FROM public.items_orden t WHERE id=item),
    'lotes',(SELECT jsonb_agg(to_jsonb(t)) FROM public.lotes t WHERE id=ANY(lotes_ids)),
    'lote_items',(SELECT jsonb_agg(to_jsonb(t)) FROM public.lote_items t WHERE item_orden_id=item),
    'movimientos',(SELECT jsonb_agg(to_jsonb(t)) FROM public.movimientos t WHERE item_orden_id=item),
    'admin_correcciones',(SELECT jsonb_agg(to_jsonb(t)) FROM public.admin_correcciones t WHERE item_id=item),
    'despachos_oc',(SELECT jsonb_agg(to_jsonb(t)) FROM public.despachos_oc t WHERE id=ANY(despachos_ids)));
  INSERT INTO respaldo_pruebas.reinicios(clave,datos) VALUES('reinicio-90003-20261006',copia);
  DELETE FROM public.movimientos WHERE item_orden_id=item;
  DELETE FROM public.admin_correcciones WHERE item_id=item;
  DELETE FROM public.lote_items WHERE item_orden_id=item;
  DELETE FROM public.lotes WHERE id=ANY(lotes_ids);
  DELETE FROM public.despachos_oc WHERE id=ANY(despachos_ids);
  UPDATE public.items_orden SET cantidad_pedida=20,admin_fecha_entrega=NULL,
    admin_fecha_entrega_activa=false,admin_eliminado_en=NULL WHERE id=item;
  -- Fechas vigentes para un nuevo recorrido de prueba.
  UPDATE public.ordenes_produccion SET fecha_esperada_produccion=current_date+7,
    fecha_esperada_logistica=current_date+10 WHERE id=orden;
  FOR n IN 4..6 LOOP
    INSERT INTO public.ordenes_produccion(numero_op,cliente,oc_cabecera,fecha_esperada_produccion,fecha_esperada_logistica,observaciones)
    VALUES('9000'||n,CASE WHEN n<6 THEN 'CLIENTE PRUEBA A' ELSE 'CLIENTE PRUEBA B' END,
      CASE WHEN n<6 THEN 'OC-PRUEBA-A' ELSE 'OC-PRUEBA-B' END,current_date+7,current_date+10,
      'Prueba aislada sin movimientos iniciales') RETURNING id INTO nueva;
    INSERT INTO public.items_orden(orden_id,codigo,descripcion,talla,cantidad_pedida,oc)
    VALUES(nueva,'TEST-9000'||n,'PRENDA PRUEBA 9000'||n,'M',20,CASE WHEN n<6 THEN 'OC-PRUEBA-A' ELSE 'OC-PRUEBA-B' END),
      (nueva,'TEST-9000'||n,'PRENDA PRUEBA 9000'||n,'L',10,CASE WHEN n<6 THEN 'OC-PRUEBA-A' ELSE 'OC-PRUEBA-B' END);
  END LOOP;
  IF EXISTS(SELECT 1 FROM public.vista_kardex WHERE numero_op IN ('90003','90004','90005','90006')
    AND (producido<>0 OR recibido<>0 OR despachado<>0)) THEN
    RAISE EXCEPTION 'La verificacion de saldos fallo. Se revierte todo.';
  END IF;
END $reinicio$;
COMMIT;
SELECT numero_op,codigo,talla,cantidad_pedida,producido,recibido,despachado
FROM public.vista_kardex WHERE numero_op IN ('90003','90004','90005','90006') ORDER BY numero_op,talla;
-- Exportar este resultado como JSON/CSV y guardarlo fuera de Supabase.
SELECT clave,fecha,datos FROM respaldo_pruebas.reinicios WHERE clave='reinicio-90003-20261006';
