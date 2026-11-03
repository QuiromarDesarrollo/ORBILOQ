-- DEV. Después de 132. Solo agrega consultas; no altera datos ni reglas de recepción.
BEGIN;
CREATE FUNCTION public.masiva_recepcion_puesto(p_operacion uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 RETURN jsonb_build_object('pedidos',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.proveedor,x.orden_carga) FROM (
  SELECT p.proveedor,p.pedido,p.orden_carga,sum(i.esperado) AS esperado,sum(i.recibido) AS recibido,
   count(*) AS referencias,count(*) FILTER(WHERE i.recibido=i.esperado) AS completas
  FROM public.masiva_pedidos p JOIN public.masiva_inventario i USING(operacion_id,proveedor,pedido)
  WHERE p.operacion_id=p_operacion GROUP BY p.proveedor,p.pedido,p.orden_carga
 ) x),'[]'));
END $$;

CREATE FUNCTION public.masiva_conciliacion_consultar(p_operacion uuid,p_buscar text DEFAULT '',p_estado text DEFAULT '',p_pagina integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE resultado jsonb; base boolean;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200
 OR p_estado IS NULL OR p_estado NOT IN('','faltante','sobrante','equilibrado','pendiente','sin_pedido') THEN RAISE EXCEPTION 'Filtro de conciliación inválido'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=p_operacion AND tipo='personal' AND estado='confirmada') INTO base;
 WITH inventario AS MATERIALIZED (
  SELECT sku,min(descripcion) descripcion,string_agg(DISTINCT proveedor,', ' ORDER BY proveedor) proveedores,
   sum(esperado) esperado,sum(recibido) recibido,sum(validado) validado,count(*) pedidos
  FROM public.masiva_inventario WHERE operacion_id=p_operacion GROUP BY sku
 ), demanda AS MATERIALIZED (
  SELECT a.sku,min(a.descripcion) descripcion,sum(a.cantidad) requerido
  FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion GROUP BY a.sku
 ), datos AS MATERIALIZED (
  SELECT coalesce(i.sku,d.sku) sku,coalesce(i.descripcion,d.descripcion) descripcion,coalesce(i.proveedores,'Sin pedido') proveedores,
   coalesce(i.esperado,0) esperado,coalesce(i.recibido,0) recibido,coalesce(i.esperado,0)-coalesce(i.recibido,0) pendiente,
   CASE WHEN base THEN coalesce(d.requerido,0) END requerido,coalesce(i.validado,0) validado,
   coalesce(i.recibido,0)-coalesce(i.validado,0) disponible,
   CASE WHEN base THEN coalesce(i.recibido,0)-coalesce(d.requerido,0) END saldo,
   CASE WHEN base THEN coalesce(i.esperado,0)-coalesce(d.requerido,0) END proyeccion,
   coalesce(i.pedidos,0) pedidos
  FROM inventario i FULL JOIN demanda d USING(sku)
 ), filtrados AS MATERIALIZED (
  SELECT * FROM datos WHERE (coalesce(p_buscar,'')='' OR position(lower(trim(p_buscar)) IN lower(sku||' '||descripcion||' '||proveedores))>0)
   AND CASE p_estado WHEN 'faltante' THEN proyeccion<0 WHEN 'sobrante' THEN proyeccion>0 WHEN 'equilibrado' THEN proyeccion=0
    WHEN 'pendiente' THEN pendiente>0 WHEN 'sin_pedido' THEN pedidos=0 ELSE true END
 ), pagina AS (SELECT * FROM filtrados ORDER BY sku LIMIT 50 OFFSET (p_pagina-1)*50)
 SELECT jsonb_build_object('filas',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.sku) FROM pagina p),'[]'),
  'total',(SELECT count(*) FROM filtrados),'pagina',p_pagina,'metricas',
  (SELECT jsonb_build_object('base_personal_cargada',base,'esperado',coalesce(sum(esperado),0),'recibido',coalesce(sum(recibido),0),
   'pendiente',coalesce(sum(pendiente),0),'requerido',CASE WHEN base THEN coalesce(sum(requerido),0) END,
   'validado',coalesce(sum(validado),0),'disponible',coalesce(sum(disponible),0),
   'sobrante_previsto',CASE WHEN base THEN coalesce(sum(greatest(proyeccion,0)),0) END,
   'faltante_previsto',CASE WHEN base THEN coalesce(sum(greatest(-proyeccion,0)),0) END,
   'referencias_faltantes',count(*) FILTER(WHERE proyeccion<0),'sin_pedido',count(*) FILTER(WHERE pedidos=0)) FROM datos)) INTO resultado;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.masiva_recepcion_puesto(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.masiva_conciliacion_consultar(uuid,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_recepcion_puesto(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.masiva_conciliacion_consultar(uuid,text,text,integer) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
