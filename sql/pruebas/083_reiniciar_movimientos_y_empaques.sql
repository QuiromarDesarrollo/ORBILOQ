-- REINICIO OPERACIONAL SOLO ORBILOQ-DEV: igfuafcekcpugpmsoqbe.
-- Compatible con reservas, correcciones de LE y destinatario antes de empacar (080–082).
-- Ejecutar UNA VEZ, completo, sin otros usuarios operando.
-- Conserva OP, líneas, cantidades pedidas, fechas esperadas, usuarios, catálogos,
-- destinatarios, parámetros, importaciones y el histórico independiente de ciclos.
-- Conserva consecutivos para no reutilizar números de documentos anteriores.
-- Retira operaciones y listas de empaque. Los archivos externos de Storage no se borran.
-- Guarda las tablas afectadas en respaldo_pruebas.reinicios, dentro de esta transacción.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $guardia$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
   RAISE EXCEPTION 'Solo ORBILOQ-DEV. Nunca ejecutar en producción.';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
   RAISE EXCEPTION 'No coincide la identificación de la base de pruebas. No se borró nada.';
 END IF;
END $guardia$;
-- Verificar también en el SQL Editor que el proyecto es igfuafcekcpugpmsoqbe.
LOCK TABLE public.ordenes_produccion,public.items_orden,public.documentos,
public.devoluciones_cliente,
public.liberaciones_aliados,
public.no_conformes_aliados,
public.liberaciones_no_conforme,
public.devoluciones_produccion,
public.sobrantes_bodega,
public.movimientos,
public.admin_correcciones,
public.lote_items,
public.lotes,
public.listas_empaque,
public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
CREATE SCHEMA IF NOT EXISTS respaldo_pruebas;
REVOKE ALL ON SCHEMA respaldo_pruebas FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS respaldo_pruebas.reinicios (
 clave text PRIMARY KEY, fecha timestamptz NOT NULL DEFAULT now(), datos jsonb NOT NULL
);
ALTER TABLE respaldo_pruebas.reinicios ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON respaldo_pruebas.reinicios FROM PUBLIC,anon,authenticated;
DO $reinicio$
DECLARE t text; filas jsonb; copia jsonb:='{}';
BEGIN
 IF EXISTS(SELECT 1 FROM respaldo_pruebas.reinicios WHERE clave='reinicio-operacional-rotulos-20261008-01') THEN
   RAISE EXCEPTION 'Este reinicio ya se ejecutó. No se borrará el trabajo nuevo.';
 END IF;
 FOREACH t IN ARRAY ARRAY['reservas_despacho','despacho_revisiones','empaque_solicitudes','seguimiento_entregas'] LOOP
   IF to_regclass('public.'||t) IS NOT NULL THEN
     EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE',t);
     EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) FROM public.%I x',t) INTO filas;
     copia:=copia||jsonb_build_object(t,filas);
   END IF;
 END LOOP;
 FOREACH t IN ARRAY ARRAY['ordenes_produccion','items_orden','documentos','devoluciones_cliente','liberaciones_aliados','no_conformes_aliados','liberaciones_no_conforme','devoluciones_produccion','sobrantes_bodega','movimientos','admin_correcciones','lote_items','lotes','listas_empaque','despachos_oc'] LOOP
   EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) FROM public.%I x',t) INTO filas;
   copia:=copia||jsonb_build_object(t,filas);
 END LOOP;
 INSERT INTO respaldo_pruebas.reinicios(clave,datos) VALUES('reinicio-operacional-rotulos-20261008-01',copia);
 -- Liberar reservas antes de retirar stock, sin desactivar validaciones.
 IF to_regclass('public.reservas_despacho') IS NOT NULL THEN
   EXECUTE 'DELETE FROM public.reservas_despacho WHERE true';
 END IF;
 -- Retirar solo metadatos de documentos relacionados con los registros a borrar.
 DELETE FROM public.documentos WHERE entidad_id IN (
   SELECT id FROM public.lotes UNION SELECT id FROM public.lote_items
   UNION SELECT id FROM public.movimientos UNION SELECT id FROM public.despachos_oc
   UNION SELECT id FROM public.no_conformes_aliados UNION SELECT id FROM public.liberaciones_aliados
   UNION SELECT id FROM public.devoluciones_produccion UNION SELECT id FROM public.liberaciones_no_conforme
   UNION SELECT id FROM public.sobrantes_bodega UNION SELECT id FROM public.devoluciones_cliente
   UNION SELECT id FROM public.admin_correcciones
 );
 DELETE FROM public.devoluciones_cliente WHERE true;
 DELETE FROM public.liberaciones_aliados WHERE true;
 DELETE FROM public.no_conformes_aliados WHERE true;
 DELETE FROM public.liberaciones_no_conforme WHERE true;
 DELETE FROM public.devoluciones_produccion WHERE true;
 DELETE FROM public.sobrantes_bodega WHERE true;
 DELETE FROM public.movimientos WHERE true;
 DELETE FROM public.admin_correcciones WHERE true;
 DELETE FROM public.lote_items WHERE true;
 DELETE FROM public.lotes WHERE true;
 DELETE FROM public.listas_empaque WHERE true;
 FOREACH t IN ARRAY ARRAY['despacho_revisiones','empaque_solicitudes','seguimiento_entregas'] LOOP
   IF to_regclass('public.'||t) IS NOT NULL THEN
     EXECUTE format('DELETE FROM public.%I WHERE true',t);
   END IF;
 END LOOP;
 DELETE FROM public.despachos_oc WHERE true;

 UPDATE public.items_orden SET admin_fecha_entrega=NULL,admin_fecha_entrega_activa=false
 WHERE admin_fecha_entrega IS NOT NULL OR admin_fecha_entrega_activa;
 -- Los borrados lógicos de líneas se conservan; no se reactivan OP ocultas.
 IF EXISTS(SELECT 1 FROM public.vista_kardex WHERE producido<>0 OR recibido<>0 OR despachado<>0 OR pendiente_reproceso<>0 OR pendiente_aliados<>0) THEN
   RAISE EXCEPTION 'La verificación de saldos falló. Se revierte todo.';
 END IF;
 IF (SELECT count(*) FROM public.items_orden)<>jsonb_array_length(copia->'items_orden')
 OR (SELECT count(*) FROM public.ordenes_produccion)<>jsonb_array_length(copia->'ordenes_produccion') THEN
   RAISE EXCEPTION 'Cambió el número de órdenes o líneas. Se revierte todo.';
 END IF;
END $reinicio$;
COMMIT;
SELECT count(*) AS lineas_conservadas,
       coalesce(sum(cantidad_pedida),0) AS prendas_pedidas,
       coalesce(sum(producido),0) AS entregado_produccion,
       coalesce(sum(recibido),0) AS recibido_bodega,
       coalesce(sum(despachado),0) AS despachado,
       coalesce(sum(pendiente_reproceso),0) AS pendiente_reproceso,
       coalesce(sum(pendiente_aliados),0) AS pendiente_aliados
FROM public.vista_kardex;
SELECT clave,fecha FROM respaldo_pruebas.reinicios WHERE clave='reinicio-operacional-rotulos-20261008-01';
-- Para exportar el respaldo a un archivo, consultar en otra ejecución:
-- SELECT datos FROM respaldo_pruebas.reinicios WHERE clave='reinicio-operacional-rotulos-20261008-01';
