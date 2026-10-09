-- ORBILOQ-DEV: requiere 081. Conserva todos los movimientos existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.validar_stock_no_conforme(p_item uuid,p_cantidad integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE disponible bigint; reservado bigint; ubicable bigint;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN
  RAISE EXCEPTION 'Se requiere Logistica o Administrador' USING ERRCODE='42501';
 END IF;
 IF p_cantidad IS NULL OR p_cantidad<=0 THEN RAISE EXCEPTION 'La cantidad debe ser mayor a 0'; END IF;
 -- Mismo bloqueo que las operaciones de stock: el saldo no puede cambiar entre validar e insertar.
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos IN SHARE ROW EXCLUSIVE MODE;
 LOCK TABLE public.reservas_despacho IN SHARE ROW EXCLUSIVE MODE;
 SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
   WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO disponible
 FROM public.movimientos WHERE item_orden_id=p_item;
 SELECT coalesce(sum(cantidad),0) INTO reservado FROM public.reservas_despacho WHERE item_id=p_item;
 IF p_cantidad>disponible-reservado THEN
  RAISE EXCEPTION 'LÍMITE EXCEDIDO: quedan % prendas disponibles sin reservar en Bodega (% en bodega, % reservadas).',greatest(0,disponible-reservado),disponible,reservado;
 END IF;
 SELECT coalesce(sum(greatest(0,s.stock-coalesce(r.cantidad,0))),0) INTO ubicable
 FROM (SELECT ubicacion_id,sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END) stock
 FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id IS NOT NULL GROUP BY ubicacion_id) s
 LEFT JOIN (SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item GROUP BY ubicacion_id) r USING(ubicacion_id);
 IF p_cantidad>ubicable THEN RAISE EXCEPTION 'No hay suficientes prendas disponibles en estantes. Revisa las ubicaciones antes de devolver.'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.validar_stock_no_conforme(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.validar_stock_no_conforme(uuid,integer) TO authenticated;
-- Protege ambas firmas sin reemplazar sus validaciones, auditoría ni atribución del usuario.
DO $$ DECLARE r record; definicion text; cantidad integer:=0; BEGIN
 FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='registrar_no_conforme' LOOP
  definicion:=pg_get_functiondef(r.oid);
  IF position('public.validar_stock_no_conforme(p_item_orden_id, p_cantidad)' in definicion)=0 THEN
   IF definicion !~* E'\nBEGIN' THEN RAISE EXCEPTION 'Revisar función registrar_no_conforme'; END IF;
   definicion:=regexp_replace(definicion,E'\nBEGIN',E'\nBEGIN\n PERFORM public.validar_stock_no_conforme(p_item_orden_id, p_cantidad);','i');
   -- Retira las unidades de estantes con stock libre para impedir que luego se vuelvan a despachar.
   IF position('insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)' in definicion)=0 THEN
     RAISE EXCEPTION 'Revisar inserción de devolución: definición inesperada';
   END IF;
   definicion:=replace(definicion,
     'insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)',
     'insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota, ubicacion_id)');
   IF position($old$values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);$old$ in definicion)=0 THEN
     RAISE EXCEPTION 'Revisar valores de devolución: definición inesperada';
   END IF;
   definicion:=replace(definicion,$old$values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);$old$,$new$
   WITH stock AS (
    SELECT ubicacion_id,sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END) cantidad
    FROM public.movimientos WHERE item_orden_id=p_item_orden_id AND ubicacion_id IS NOT NULL GROUP BY ubicacion_id
   ), libres AS (
    SELECT s.ubicacion_id,greatest(0,s.cantidad-coalesce(r.cantidad,0)) cantidad FROM stock s
    LEFT JOIN (SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item_orden_id GROUP BY ubicacion_id) r USING(ubicacion_id)
   ), reparto AS (
    SELECT ubicacion_id,least(cantidad,greatest(0,p_cantidad-coalesce(sum(cantidad) OVER(ORDER BY ubicacion_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING),0))) cantidad FROM libres
   )
   SELECT 'devolucion_produccion',p_item_orden_id,cantidad::integer,v_usuario_id,p_nota,ubicacion_id FROM reparto WHERE cantidad>0;
   $new$);
   EXECUTE definicion;
  END IF;
  cantidad:=cantidad+1;
 END LOOP;
 IF cantidad<>2 THEN RAISE EXCEPTION 'Se esperaban ambas firmas de registrar_no_conforme'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
