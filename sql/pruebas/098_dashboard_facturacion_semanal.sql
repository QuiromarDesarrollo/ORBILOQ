-- Reporte semanal de facturacion. Requiere 097. Solo lectura de datos existentes.
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
CREATE OR REPLACE FUNCTION public.dashboard_facturacion_semanal(
 p_desde date, p_hasta date, p_cliente text DEFAULT NULL, p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso al dashboard' USING ERRCODE='42501'; END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
 WITH semanas AS (
 SELECT generate_series(date_trunc('week',p_desde::timestamp),date_trunc('week',least(p_hasta,(least(p_corte,now()) AT TIME ZONE 'America/Bogota')::date)::timestamp),interval '1 week')::date semana
 ), datos AS (
 SELECT date_trunc('week',d.fecha AT TIME ZONE 'America/Bogota')::date semana,
 count(*) total,
 count(*) FILTER(WHERE coalesce((public.facturacion_le_dato(d.id)->>'completa')::boolean,false)) completas
 FROM public.despachos_oc d
 WHERE d.fase='despachado'
 AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<=least(p_corte,now())
 AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
 AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
 GROUP BY 1
 ) SELECT coalesce(jsonb_agg(jsonb_build_object('semana',s.semana,'total',coalesce(d.total,0),'completas',coalesce(d.completas,0),'pendientes',coalesce(d.total,0)-coalesce(d.completas,0)) ORDER BY s.semana),'[]'::jsonb)
 FROM semanas s LEFT JOIN datos d USING(semana)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_facturacion_semanal(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_facturacion_semanal(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
