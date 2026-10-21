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
-- Solo combinaciones de ficha, cliente y talla con entradas reales al inventario.
CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT s.item_id,s.libre,s.reservado,s.despachado,s.ficha,s.cliente,i.talla FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), fichas_ingresadas AS MATERIALIZED (
 SELECT DISTINCT public.inventario_clave(cliente) cliente,public.inventario_clave(ficha) ficha,public.inventario_clave(talla) talla FROM saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 AND EXISTS(SELECT 1 FROM fichas_ingresadas f
 WHERE f.cliente=public.inventario_clave(o.cliente)
 AND f.ficha=public.inventario_clave(o.nombre_ficha_tecnica)
 AND f.talla IS NOT DISTINCT FROM public.inventario_clave(i.talla))
 ), componentes AS (
 SELECT ficha,cliente,talla,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,s.talla,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,talla,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM (SELECT public.inventario_clave(ficha) ficha,public.inventario_clave(cliente) cliente,public.inventario_clave(talla) talla,descripcion,pendiente_producir,bodega,libre,reservado,despachado FROM componentes) c WHERE concat_ws(' ',ficha,cliente,talla,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente,talla
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha,talla LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_detalle_talla(p_cliente text,p_ficha text,p_talla text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE public.inventario_clave(s.cliente)=public.inventario_clave(p_cliente) AND public.inventario_clave(s.ficha)=public.inventario_clave(p_ficha) AND public.inventario_clave(i.talla) IS NOT DISTINCT FROM public.inventario_clave(p_talla) ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

REVOKE ALL ON FUNCTION public.inventario_detalle_talla(text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_detalle_talla(text,text,text,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
