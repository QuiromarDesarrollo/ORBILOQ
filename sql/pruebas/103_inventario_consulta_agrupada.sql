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
-- Calcula los saldos una sola vez por consulta, no una vez por línea del kardex.
CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT item_id,libre,reservado,despachado,ficha,cliente FROM public.inventario_saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM componentes WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
