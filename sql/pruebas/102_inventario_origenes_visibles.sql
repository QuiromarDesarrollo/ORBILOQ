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
CREATE OR REPLACE FUNCTION public.inventario_origenes(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT i.id item_id,u.id ubicacion_id,o.numero_op,o.cliente,o.nombre_ficha_tecnica ficha,i.descripcion producto,i.talla,u.codigo ubicacion,
 s.cantidad en_bodega,u.activa estante_activo,
 public.inventario_disponible_op(i.id,u.id) disponible
 FROM public.vista_stock_ubicacion_detalle s JOIN public.items_orden i ON i.id=s.item_orden_id
 JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.codigo=s.ubicacion_codigo
 WHERE i.admin_eliminado_en IS NULL
 AND concat_ws(' ',o.numero_op,o.cliente,o.nombre_ficha_tecnica,i.descripcion) ILIKE '%'||trim(coalesce(p_buscar,''))||'%'
 ORDER BY o.numero_op,i.id,u.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN r;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
