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
CREATE OR REPLACE FUNCTION public.inventario_empacar_flujo(p_solicitud text,p_transferencia uuid,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t record; previo public.inventario_despachos%rowtype; r jsonb; pedido jsonb; p_cantidad bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' OR jsonb_array_length(p_empaques)=0 THEN RAISE EXCEPTION 'Indica los empaques'; END IF;
 SELECT sum((e->>'cantidad')::bigint) INTO p_cantidad FROM jsonb_array_elements(p_empaques)e;
 pedido:=jsonb_build_array(p_transferencia,trim(p_oc),p_destinatario,p_destinatario_version,p_empaques);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(trim(p_oc)),0) NOT BETWEEN 1 AND 150 OR coalesce(p_cantidad,0)<=0 THEN RAISE EXCEPTION 'Indica OC y cantidad'; END IF;
 SELECT s.*,u.codigo ubicacion INTO t FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id WHERE s.id=p_transferencia;
 IF NOT FOUND OR p_cantidad>t.libre THEN RAISE EXCEPTION 'Inventario libre insuficiente'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques)e
 WHERE (e->>'item_id') IS DISTINCT FROM t.item_id::text
 OR coalesce((e->>'cantidad')::bigint,0)<=0) THEN RAISE EXCEPTION 'Los empaques deben pertenecer a la prenda seleccionada'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,p_transferencia,p_cantidad,a,pedido);
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,t.cliente,trim(p_oc),
 jsonb_build_array(jsonb_build_object('item_id',t.item_id,'ubicacion',t.ubicacion,'cantidad',p_cantidad)),
 p_empaques,
 p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.inventario_empacar_flujo(text,uuid,text,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_empacar_flujo(text,uuid,text,uuid,text,jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
