-- SOLO ORBILOQ-DEV. Requiere 068. No repara correcciones anteriores.
-- Al reducir el total entregado, reduce también los envíos aún por recibir.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
 IF position('validacion_entregado_recibido_v68' in pg_get_functiondef('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 068'; END IF;
END $$;
-- Un envío anulado conserva su identificador para auditoría, con cantidad cero.
ALTER TABLE public.lote_items DROP CONSTRAINT lote_items_cantidad_enviada_check;
ALTER TABLE public.lote_items ADD CONSTRAINT lote_items_cantidad_enviada_check CHECK(cantidad_enviada>=0);
CREATE OR REPLACE FUNCTION public.admin_sincronizar_envios_corregidos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; restante integer := -NEW.cantidad; reducir integer;
 v_antes jsonb := '[]'; v_despues jsonb := '[]';
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.admin_correcciones
   WHERE id=NEW.admin_correccion_id AND item_id=NEW.item_orden_id AND campo='producido') THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM public.admin_correcciones ac WHERE ac.id=NEW.admin_correccion_id
   AND (ac.nuevo #>> '{}')::bigint < (ac.despues->>'recibido')::bigint) THEN
   RAISE EXCEPTION 'No se puede reducir el envío por debajo de lo ya recibido por Bodega.';
 END IF;
 -- La RPC mantiene bloqueadas las tablas hasta confirmar toda la corrección.
 -- Primero los envíos recientes; nunca reducir lo recibido ni los reprocesos.
 FOR r IN SELECT li.* FROM public.lote_items li JOIN public.lotes l ON l.id=li.lote_id
   WHERE li.item_orden_id=NEW.item_orden_id AND li.origen='entrega'
     AND li.estado='en_transito' AND li.cantidad_enviada>coalesce(li.cantidad_recibida,0)
     AND NOT EXISTS(SELECT 1 FROM public.movimientos m WHERE m.lote_item_id=li.id AND m.tipo='ajuste_faltante_entrega')
   ORDER BY l.fecha_envio DESC,li.id DESC FOR UPDATE OF li
 LOOP
   EXIT WHEN restante=0;
   reducir:=least(restante,r.cantidad_enviada-coalesce(r.cantidad_recibida,0));
   v_antes:=v_antes||jsonb_build_array(to_jsonb(r));
   UPDATE public.lote_items SET cantidad_enviada=cantidad_enviada-reducir,
     estado=CASE WHEN cantidad_enviada-reducir=coalesce(cantidad_recibida,0) THEN 'recibido_con_novedad' ELSE 'en_transito' END,
     novedad=concat_ws(' | ',nullif(novedad,''),'Envío corregido: -'||reducir||' prendas. Corrección '||NEW.admin_correccion_id)
     WHERE id=r.id;
   v_despues:=v_despues||jsonb_build_array((SELECT to_jsonb(li) FROM public.lote_items li WHERE li.id=r.id));
   UPDATE public.lotes SET estado=CASE
     WHEN NOT EXISTS(SELECT 1 FROM public.lote_items WHERE lote_id=r.lote_id AND estado='en_transito') THEN 'recibido_completo'
     WHEN EXISTS(SELECT 1 FROM public.lote_items WHERE lote_id=r.lote_id AND coalesce(cantidad_recibida,0)>0) THEN 'recibido_parcial'
     ELSE 'en_transito' END WHERE id=r.lote_id;
   restante:=restante-reducir;
 END LOOP;
 -- El resto puede corresponder a totales históricos sin lote, que ya permite la RPC.
 UPDATE public.admin_correcciones SET lote_antes=v_antes,lote_despues=v_despues WHERE id=NEW.admin_correccion_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.admin_sincronizar_envios_corregidos() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS admin_sincronizar_envios_corregidos ON public.movimientos;
CREATE TRIGGER admin_sincronizar_envios_corregidos AFTER INSERT ON public.movimientos
FOR EACH ROW WHEN (NEW.tipo='entrega_produccion' AND NEW.cantidad<0 AND NEW.admin_correccion_id IS NOT NULL AND NEW.lote_item_id IS NULL)
EXECUTE FUNCTION public.admin_sincronizar_envios_corregidos();
COMMIT;


