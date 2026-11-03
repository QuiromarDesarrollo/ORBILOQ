-- ORBILOQ-DEV. Historial paginado de recepciones confirmadas en el puesto.
-- Aplica después de 139. Solo consulta movimientos existentes.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
   AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden
   WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
END $$;

CREATE INDEX IF NOT EXISTS masiva_movimientos_recepcion_historial
 ON public.masiva_movimientos(operacion_id,creado DESC,id DESC)
 WHERE tipo='recepcion';

CREATE OR REPLACE FUNCTION public.masiva_recepcion_historial(
 p_operacion uuid,p_buscar text DEFAULT '',p_pagina integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE v_total bigint; v_filas jsonb;
BEGIN
 IF NOT public.masiva_acceso() THEN
  RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501';
 END IF;
 IF p_operacion IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN
  RAISE EXCEPTION 'Operación no encontrada';
 END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000
   OR length(coalesce(p_buscar,''))>200 THEN
  RAISE EXCEPTION 'Consulta inválida';
 END IF;
 p_buscar:=trim(coalesce(p_buscar,''));
 WITH datos AS (
  SELECT m.id,m.creado,m.cantidad,m.soporte,i.sku,i.descripcion,
   i.proveedor,i.pedido,coalesce(u.nombre,'Operario') AS operario
  FROM public.masiva_movimientos m
  JOIN public.masiva_inventario i ON i.id=m.inventario_id
  LEFT JOIN public.usuarios u ON u.auth_id=m.actor_id
  WHERE m.operacion_id=p_operacion AND m.tipo='recepcion'
   AND (p_buscar='' OR i.sku ILIKE '%'||p_buscar||'%'
    OR i.descripcion ILIKE '%'||p_buscar||'%'
    OR i.proveedor ILIKE '%'||p_buscar||'%'
    OR i.pedido ILIKE '%'||p_buscar||'%'
    OR m.soporte ILIKE '%'||p_buscar||'%')
 ), pagina AS (
  SELECT * FROM datos ORDER BY creado DESC,id DESC
  LIMIT 50 OFFSET (p_pagina-1)*50
 )
 SELECT (SELECT count(*) FROM datos),
  coalesce(jsonb_agg(to_jsonb(pagina) ORDER BY pagina.creado DESC,pagina.id DESC),'[]'::jsonb)
 INTO v_total,v_filas FROM pagina;
 RETURN jsonb_build_object('filas',v_filas,'total',v_total,'pagina',p_pagina);
END $$;

REVOKE ALL ON FUNCTION public.masiva_recepcion_historial(uuid,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_recepcion_historial(uuid,text,integer) TO authenticated;
COMMIT;
