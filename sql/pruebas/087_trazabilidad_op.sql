-- ORBILOQ-DEV. Requiere 086. No clasifica automáticamente la placa/guía histórica.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
ALTER TABLE public.seguimiento_entregas ADD COLUMN IF NOT EXISTS numero_guia text NOT NULL DEFAULT '';
ALTER TABLE public.seguimiento_entregas ADD COLUMN IF NOT EXISTS placa text NOT NULL DEFAULT '';
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS fecha_empacado timestamptz;
-- Solo se recuperan fechas inequívocas. En las LE liberadas antiguas fecha ya fue sobrescrita.
UPDATE public.despachos_oc SET fecha_empacado=fecha WHERE fase='empacado' AND fecha_empacado IS NULL;
CREATE OR REPLACE FUNCTION public.traza_fecha_empaque() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
 IF NEW.fase='empacado' THEN NEW.fecha_empacado:=now(); END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS traza_fecha_empaque ON public.despachos_oc;
CREATE TRIGGER traza_fecha_empaque BEFORE INSERT OR UPDATE OF fase ON public.despachos_oc FOR EACH ROW EXECUTE FUNCTION public.traza_fecha_empaque();
DO $$ BEGIN
 IF to_regprocedure('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)') IS NULL THEN
 ALTER FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) RENAME TO seguimiento_guardar_base_v87;
 ALTER FUNCTION public.seguimiento_entregas_listar(bigint) RENAME TO seguimiento_listar_base_v87;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.seguimiento_listar_base_v87(bigint) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v integer;
BEGIN
 IF length(coalesce(p_datos->>'numero_guia',''))>150 OR length(coalesce(p_datos->>'placa',''))>150 THEN RAISE EXCEPTION 'Guía y placa admiten hasta 150 caracteres'; END IF;
 v:=public.seguimiento_guardar_base_v87(p_id,p_revision,p_version,p_datos);
 UPDATE public.seguimiento_entregas SET numero_guia=CASE WHEN p_datos ? 'numero_guia' THEN trim(coalesce(p_datos->>'numero_guia','')) ELSE numero_guia END,
 placa=CASE WHEN p_datos ? 'placa' THEN trim(coalesce(p_datos->>'placa','')) ELSE placa END WHERE despacho_id=p_id AND revision=p_revision;
 RETURN v;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.seguimiento_listar_base_v87(p_antes);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('numero_guia',coalesce(s.numero_guia,''),'placa',coalesce(s.placa,'')) ORDER BY (f.value->>'le')::bigint DESC)
 FROM jsonb_array_elements(filas) f LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=(f.value->>'id')::uuid AND s.revision=(f.value->>'revision')::integer),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.admin_trazabilidad_op(p_op text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador' USING ERRCODE='42501'; END IF;
 WITH items AS (
  SELECT k.*, i.orden_id FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id
  WHERE k.admin_eliminado_en IS NULL AND (coalesce(p_op,'')='' OR k.numero_op ILIKE '%'||p_op||'%')
 ), progreso AS (
  SELECT m.item_orden_id,m.fecha,row_number() OVER w pos,
   sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'envio_aliado' THEN -m.cantidad WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END) OVER w prod,
   sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) OVER w rec
  FROM public.movimientos m JOIN items i ON i.item_orden_id=m.item_orden_id
  WINDOW w AS (PARTITION BY m.item_orden_id ORDER BY m.fecha,m.id ROWS UNBOUNDED PRECEDING)
 ), completado AS (
  SELECT i.*,
   (SELECT min(p.fecha) FROM progreso p WHERE p.item_orden_id=i.item_orden_id AND p.prod>=i.cantidad_pedida AND p.pos>coalesce((SELECT max(q.pos) FROM progreso q WHERE q.item_orden_id=i.item_orden_id AND q.prod<i.cantidad_pedida),0)) fecha_produccion,
   (SELECT min(p.fecha) FROM progreso p WHERE p.item_orden_id=i.item_orden_id AND p.rec>=i.cantidad_pedida AND p.pos>coalesce((SELECT max(q.pos) FROM progreso q WHERE q.item_orden_id=i.item_orden_id AND q.rec<i.cantidad_pedida),0)) fecha_recibido
  FROM items i
 ), op_completa AS (
  SELECT orden_id,bool_and(producido>=cantidad_pedida) produccion_completa,bool_and(recibido>=cantidad_pedida) recepcion_completa,
   CASE WHEN bool_and(fecha_produccion IS NOT NULL) THEN max(fecha_produccion) END fecha_produccion,
   CASE WHEN bool_and(fecha_recibido IS NOT NULL) THEN max(fecha_recibido) END fecha_recibido
  FROM completado GROUP BY orden_id
 ), salidas AS (
  SELECT d.id,d.ediciones,d.fase,d.fecha,d.fecha_empacado,d.empaques,(x->>'item_id')::uuid item_id,sum((x->>'cantidad')::integer) cantidad
  FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.detalle) x GROUP BY d.id,(x->>'item_id')::uuid
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'item_id',i.item_orden_id,'op',i.numero_op,'cliente',i.cliente,'oc',i.oc,'prenda',i.descripcion,'codigo',i.codigo,'talla',i.talla,'cantidad',i.cantidad_pedida,
  'entregado_produccion',i.producido,'recibido_cantidad',i.recibido,'produccion_completa',o.produccion_completa,'recepcion_completa',o.recepcion_completa,
  'fecha_produccion',o.fecha_produccion,'fecha_recibido',o.fecha_recibido,'despacho_id',d.id,'fecha_despachado',d.fecha_empacado,
  'fecha_liberado',CASE WHEN d.fase='despachado' THEN d.fecha END,'cantidad_le',d.cantidad,'le',l.numero,'fase',d.fase,
  'numero_guia',s.numero_guia,'placa',s.placa,'placa_guia_historica',s.placa_guia,'transportadora',s.transportadora,'recibido_cliente',s.recibido,
  'piezas',CASE WHEN d.id IS NOT NULL THEN (SELECT count(DISTINCT e->>'numero') FROM jsonb_array_elements(d.empaques) e WHERE e->>'item_id'=i.item_orden_id::text) END
 ) ORDER BY i.numero_op,i.codigo,i.talla,l.numero),'[]') INTO resultado
 FROM items i JOIN op_completa o USING(orden_id) LEFT JOIN salidas d ON d.item_id=i.item_orden_id
 LEFT JOIN public.listas_empaque l ON l.despacho_id=d.id LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_op(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_trazabilidad_op(text) TO authenticated;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb),public.seguimiento_entregas_listar(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb),public.seguimiento_entregas_listar(bigint) TO authenticated;
-- Entrada versionada: el cliente no puede guardar campos nuevos en un servidor antiguo que los ignore.
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar_v87(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT public.seguimiento_entregas_guardar(p_id,p_revision,p_version,p_datos);
$$;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
