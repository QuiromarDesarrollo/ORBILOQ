-- Puntualidad por salida de bodega. Solo lectura; DEV.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.dashboard_puntualidad_mensual(
 p_desde date,p_hasta date,p_cliente text DEFAULT NULL,p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso al dashboard' USING ERRCODE='42501'; END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
 WITH meses AS (
 SELECT generate_series(date_trunc('month',p_desde::timestamp),date_trunc('month',p_hasta::timestamp),interval '1 month')::date mes
 ), salidas AS (
 SELECT date_trunc('month',d.fecha AT TIME ZONE 'America/Bogota')::date mes,
 (d.fecha AT TIME ZONE 'America/Bogota')::date salida,plazo.esperada,
 plazo.lineas>0 AND plazo.faltantes=0 evaluable
 FROM public.despachos_oc d
 CROSS JOIN LATERAL (
  SELECT count(*) lineas,count(*) FILTER(WHERE o.fecha_esperada_logistica IS NULL) faltantes,min(o.fecha_esperada_logistica) esperada
  FROM jsonb_array_elements(coalesce(d.detalle,'[]'::jsonb)) x
  LEFT JOIN public.items_orden i ON i.id::text=x->>'item_id'
  LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id
 ) plazo
 WHERE d.fase='despachado'
 AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<=least(p_corte,now())
 AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
 AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
 ), grupos AS (
 SELECT mes,count(*) total,count(*) FILTER(WHERE evaluable AND salida<=esperada) a_tiempo,
 count(*) FILTER(WHERE evaluable AND salida>esperada) con_retraso,
 count(*) FILTER(WHERE NOT evaluable) sin_fecha
 FROM salidas GROUP BY mes
 ) SELECT coalesce(jsonb_agg(jsonb_build_object('mes',m.mes,'total',coalesce(g.total,0),
 'a_tiempo',coalesce(g.a_tiempo,0),'con_retraso',coalesce(g.con_retraso,0),'sin_fecha',coalesce(g.sin_fecha,0)) ORDER BY m.mes),'[]'::jsonb)
 FROM meses m LEFT JOIN grupos g USING(mes)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_puntualidad_mensual(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_puntualidad_mensual(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
