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
-- Una solicitud/LE puede consumir varias entradas; cada origen queda auditado.
ALTER TABLE public.inventario_despachos DROP CONSTRAINT IF EXISTS inventario_despachos_pkey;
ALTER TABLE public.inventario_despachos ADD PRIMARY KEY(solicitud,transferencia);
ALTER TABLE public.inventario_despachos DROP CONSTRAINT IF EXISTS inventario_despachos_despacho_id_key;
CREATE INDEX IF NOT EXISTS inventario_despachos_le_idx ON public.inventario_despachos(despacho_id);

CREATE OR REPLACE FUNCTION public.inventario_preparar_despacho(p_seleccion jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE q jsonb; s record; cliente_elegido text; faltan integer; tomar integer; resultado jsonb:='[]'; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','despacho']);
 IF jsonb_typeof(p_seleccion) IS DISTINCT FROM 'array' OR jsonb_array_length(p_seleccion) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona entre 1 y 100 prendas'; END IF;
 cliente_elegido:=public.inventario_clave(p_seleccion->0->>'cliente');
 IF nullif(cliente_elegido,'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_seleccion) x WHERE public.inventario_clave(x->>'cliente') IS DISTINCT FROM cliente_elegido) THEN RAISE EXCEPTION 'Selecciona prendas de un mismo cliente'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_seleccion) x GROUP BY public.inventario_clave(x->>'ficha'),public.inventario_clave(x->>'talla') HAVING count(*)>1) THEN RAISE EXCEPTION 'Prenda repetida en la selección'; END IF;
 FOR q IN SELECT value FROM jsonb_array_elements(p_seleccion) LOOP
 IF coalesce(q->>'cantidad','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'Indica cantidades enteras positivas'; END IF;
 faltan:=(q->>'cantidad')::integer;
 FOR s IN SELECT v.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel
 FROM public.inventario_saldos v JOIN public.items_orden i ON i.id=v.item_id
 LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=v.ubicacion_id
 WHERE public.inventario_clave(v.cliente)=cliente_elegido AND public.inventario_clave(v.ficha)=public.inventario_clave(q->>'ficha')
 AND public.inventario_clave(i.talla) IS NOT DISTINCT FROM public.inventario_clave(q->>'talla') AND v.libre>0 AND u.activa
 ORDER BY v.fecha,v.id LOOP
 tomar:=least(faltan,s.libre)::integer;
 resultado:=resultado||jsonb_build_array(to_jsonb(s)||jsonb_build_object('libre',tomar));
 faltan:=faltan-tomar; EXIT WHEN faltan=0;
 END LOOP;
 IF faltan>0 THEN RAISE EXCEPTION 'Stock insuficiente para ficha %, talla %. Actualiza la selección',q->>'ficha',q->>'talla'; END IF;
 END LOOP;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_empacar_multiple(p_solicitud text,p_asignaciones jsonb,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_despachos%rowtype; pedido jsonb; cliente text; x record; t record; r jsonb; lineas jsonb; BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_oc)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Indica OC y solicitud'; END IF;
 IF jsonb_typeof(p_asignaciones) IS DISTINCT FROM 'array' OR jsonb_array_length(p_asignaciones) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Indica las prendas de origen'; END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' OR jsonb_array_length(p_empaques)=0 THEN RAISE EXCEPTION 'Indica los empaques'; END IF;
 pedido:=jsonb_build_array('multiple',p_asignaciones,btrim(p_oc),p_destinatario,p_destinatario_version,p_empaques);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud LIMIT 1;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_asignaciones) q WHERE coalesce(q->>'cantidad','') !~ '^[1-9][0-9]{0,5}$')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_asignaciones) q GROUP BY q->>'transferencia' HAVING count(*)>1) THEN RAISE EXCEPTION 'Cantidades u orígenes inválidos'; END IF;
 FOR x IN SELECT * FROM jsonb_to_recordset(p_asignaciones) AS q(transferencia uuid,cantidad integer) LOOP
 SELECT v.*,u.codigo ubicacion INTO t FROM public.inventario_saldos v JOIN public.ubicaciones u ON u.id=v.ubicacion_id WHERE v.id=x.transferencia AND u.activa;
 IF NOT FOUND OR x.cantidad>t.libre THEN RAISE EXCEPTION 'El stock cambió o el estante está inactivo. Actualiza la selección'; END IF;
 IF cliente IS NULL THEN cliente:=t.cliente; END IF;
 IF public.inventario_clave(t.cliente)<>public.inventario_clave(cliente) THEN RAISE EXCEPTION 'No se pueden mezclar clientes'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,t.id,x.cantidad,a,pedido);
 END LOOP;
 -- Comparar los totales por artículo: no basta con que coincida el total de prendas.
 IF EXISTS(WITH origen AS (
 SELECT it.item_id,sum(d.cantidad) n FROM public.inventario_despachos d JOIN public.inventario_transferencias it ON it.id=d.transferencia WHERE d.solicitud=p_solicitud GROUP BY it.item_id),
 empaque AS (SELECT (e->>'item_id')::uuid item_id,sum((e->>'cantidad')::bigint) n FROM jsonb_array_elements(p_empaques) e GROUP BY 1)
 SELECT 1 FROM origen o FULL JOIN empaque e USING(item_id) WHERE o.n IS DISTINCT FROM e.n)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e WHERE coalesce(e->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Los empaques no coinciden con las prendas seleccionadas'; END IF;
 SELECT jsonb_agg(to_jsonb(q) ORDER BY item_id,ubicacion) INTO lineas FROM (
 SELECT it.item_id,u.codigo ubicacion,sum(d.cantidad) cantidad FROM public.inventario_despachos d JOIN public.inventario_transferencias it ON it.id=d.transferencia JOIN public.ubicaciones u ON u.id=it.ubicacion_id WHERE d.solicitud=p_solicitud GROUP BY it.item_id,u.codigo) q;
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,cliente,btrim(p_oc),lineas,p_empaques,p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.inventario_preparar_despacho(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_preparar_despacho(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
