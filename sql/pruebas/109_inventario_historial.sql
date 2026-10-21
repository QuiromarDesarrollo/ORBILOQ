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


DO $$ BEGIN IF to_regclass('public.inventario_estantes_origen') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 108'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.inventario_historial_transferencias() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 WITH eventos AS (
 SELECT t.id,t.id transferencia,t.fecha,t.actor,t.cantidad,t.motivo,'Transferencia a inventario'::text tipo,false reversion FROM public.inventario_transferencias t JOIN public.items_orden i ON i.id=t.item_id WHERE NOT i.inventario_manual
 UNION ALL
 SELECT r.id,r.transferencia,r.fecha,r.actor,r.cantidad,r.motivo,'Devolución a OP original',true FROM public.inventario_reversiones r
 )
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.fecha DESC,q.id),'[]') INTO resultado FROM (
 SELECT e.*,t.item_id,t.ficha,t.cliente,i.descripcion producto,i.talla,i.codigo,o.numero_op,
 u.nombre responsable,
 CASE WHEN e.reversion THEN destino.codigo ELSE origen.codigo END estante_origen,
 CASE WHEN e.reversion THEN origen.codigo ELSE destino.codigo END estante_destino
 FROM eventos e JOIN public.inventario_transferencias t ON t.id=e.transferencia
 JOIN public.items_orden i ON i.id=t.item_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN public.usuarios u ON u.id=e.actor
 LEFT JOIN public.inventario_estantes_origen eo ON eo.transferencia=t.id
 JOIN public.ubicaciones origen ON origen.id=coalesce(eo.ubicacion_origen,t.ubicacion_id)
 JOIN public.ubicaciones destino ON destino.id=t.ubicacion_id
 ) q;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.inventario_historial_transferencias() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_historial_transferencias() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
