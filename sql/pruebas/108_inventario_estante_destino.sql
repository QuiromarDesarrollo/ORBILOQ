-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;

-- Ledger de ubicación: no crea recepciones o despachos ficticios.
CREATE TABLE IF NOT EXISTS public.inventario_estantes_origen(
 transferencia uuid PRIMARY KEY REFERENCES public.inventario_transferencias(id),
 ubicacion_origen uuid NOT NULL REFERENCES public.ubicaciones(id)
);
ALTER TABLE public.inventario_estantes_origen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_estantes_origen FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.inventario_delta_estante(p_item uuid,p_ubicacion uuid) RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT coalesce(sum((s.cantidad-s.revertido) *
 (CASE WHEN s.ubicacion_id=p_ubicacion THEN 1 ELSE 0 END - CASE WHEN o.ubicacion_origen=p_ubicacion THEN 1 ELSE 0 END)),0)::bigint
 FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia WHERE s.item_id=p_item;
$$;
REVOKE ALL ON FUNCTION public.inventario_delta_estante(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE VIEW public.vista_stock_ubicacion_detalle AS
WITH componentes AS (
 SELECT m.item_orden_id,m.ubicacion_id,
 CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END::bigint cantidad
 FROM public.movimientos m WHERE m.tipo IN ('recepcion','despacho','devolucion_produccion')
 UNION ALL
 SELECT s.item_id,s.ubicacion_id,(s.cantidad-s.revertido)::bigint FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia
 UNION ALL
 SELECT s.item_id,o.ubicacion_origen,-(s.cantidad-s.revertido)::bigint FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia
)
SELECT c.item_orden_id,u.codigo ubicacion_codigo,sum(c.cantidad)::bigint cantidad
FROM componentes c JOIN public.ubicaciones u ON u.id=c.ubicacion_id GROUP BY c.item_orden_id,u.codigo HAVING sum(c.cantidad)>0;
-- Conserva el algoritmo de disponibilidad, sumando solo el cambio neto de ubicación.
DO $$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.inventario_disponible_op(uuid,uuid)'::regprocedure);
 IF strpos(f,'inventario_delta_estante')=0 THEN
 f:=replace(f,'-coalesce((SELECT sum(libre)', '+public.inventario_delta_estante(p_item,p_ubicacion) -coalesce((SELECT sum(libre)');
 EXECUTE f;
 END IF;
END $$;
-- Validaciones existentes de reservas/salidas/ajustes también deben usar stock trasladado.
DO $$ DECLARE f record; ddl text; nuevo text; par text[]; BEGIN
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc LIKE '%INTO%stock%' AND p.prosrc LIKE '%FROM public.movimientos%' LOOP
 ddl:=pg_get_functiondef(f.oid); nuevo:=ddl;
 FOREACH par SLICE 1 IN ARRAY ARRAY[
 ['item_orden_id=r.item_id AND ubicacion_id=ubic;', 'stock','r.item_id','ubic'],
 ['item_orden_id=p_item AND ubicacion_id=r.ubicacion_id;', 'stock','p_item','r.ubicacion_id'],
 ['item_orden_id=ident AND ubicacion_id=ubic;', 'stock','ident','ubic'],
 ['item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id;', 'v_stock','p_item_id','p_ubicacion_id'],
 ['item_orden_id=p_item_orden_id AND ubicacion_id=p_ubicacion_id;', 'v_stock','p_item_orden_id','p_ubicacion_id']
 ] LOOP
 IF strpos(nuevo,'-- ESTANTE_108')=0 AND strpos(nuevo,par[1])>0 THEN
 nuevo:=replace(nuevo,par[1],par[1]||format(E'
 -- ESTANTE_108
 %s:=%s+public.inventario_delta_estante(%s,%s);',par[2],par[2],par[3],par[4]));
 END IF;
 END LOOP;
 IF nuevo<>ddl THEN EXECUTE nuevo; END IF;
 END LOOP;
END $$;
-- Un ajuste posterior tampoco puede consumir prendas que ya cambiaron de estante.
DO $$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.inventario_validar_stock()'::regprocedure);
 IF strpos(f,'ESTANTE_FISICO_108')=0 THEN
 f:=replace(f,' RETURN NULL;', $patch$
 -- ESTANTE_FISICO_108
 FOR r IN SELECT DISTINCT t.item_id,o.ubicacion_origen ubicacion_id FROM public.inventario_estantes_origen o JOIN public.inventario_transferencias t ON t.id=o.transferencia WHERE t.item_id=ANY(afectados) LOOP
 IF coalesce((SELECT sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) FROM public.movimientos m WHERE m.item_orden_id=r.item_id AND m.ubicacion_id=r.ubicacion_id),0)+public.inventario_delta_estante(r.item_id,r.ubicacion_id)<0 THEN RAISE EXCEPTION 'El ajuste consume prendas trasladadas a otro estante'; END IF;
 END LOOP;
 RETURN NULL;$patch$);
 EXECUTE f;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_transferir_estante(p_solicitud text,p_item uuid,p_ubicacion uuid,p_cantidad integer,p_motivo text,p_estante_destino text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_transferencias%rowtype; f text; c text; nuevo uuid; destino uuid; origen uuid;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT id INTO destino FROM public.ubicaciones WHERE codigo=p_estante_destino AND activa;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona un estante de destino activo'; END IF;
 SELECT * INTO previo FROM public.inventario_transferencias WHERE solicitud=p_solicitud;
 IF FOUND THEN
 SELECT ubicacion_origen INTO origen FROM public.inventario_estantes_origen WHERE transferencia=previo.id;
 IF origen IS DISTINCT FROM p_ubicacion THEN RAISE EXCEPTION 'Solicitud utilizada con otro origen'; END IF;
 IF (previo.actor,previo.item_id,previo.ubicacion_id,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_item,destino,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la transferencia'; END IF;
 SELECT trim(o.nombre_ficha_tecnica),o.cliente INTO f,c FROM public.items_orden i JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE i.id=p_item AND i.admin_eliminado_en IS NULL;
 IF nullif(f,'') IS NULL THEN RAISE EXCEPTION 'La OP no tiene ficha técnica. Importa NOMBRE FICHA TECNICA antes de transferir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion AND activa) THEN RAISE EXCEPTION 'Estante no disponible'; END IF;
 IF p_cantidad>public.inventario_disponible_op(p_item,p_ubicacion) THEN RAISE EXCEPTION 'Cantidad superior al stock libre de la OP en ese estante'; END IF;
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES(p_solicitud,p_item,destino,c,f,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 INSERT INTO public.inventario_estantes_origen(transferencia,ubicacion_origen) VALUES(nuevo,p_ubicacion);
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;


REVOKE ALL ON FUNCTION public.inventario_transferir_estante(text,uuid,uuid,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_transferir_estante(text,uuid,uuid,integer,text,text) TO authenticated;
DROP TRIGGER IF EXISTS inventario_estantes_inmutable ON public.inventario_estantes_origen;
CREATE TRIGGER inventario_estantes_inmutable BEFORE UPDATE OR DELETE ON public.inventario_estantes_origen FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
NOTIFY pgrst, 'reload schema';
COMMIT;
