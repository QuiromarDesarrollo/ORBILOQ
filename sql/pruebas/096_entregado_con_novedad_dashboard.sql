-- ORBILOQ-DEV. Requiere estados de Seguimiento y acceso a dashboards (071, 086).
-- Conserva estados, cantidades y movimientos existentes. Ejecutar completo.
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
ALTER TABLE public.seguimiento_entregas DROP CONSTRAINT IF EXISTS seguimiento_estado_valido;
ALTER TABLE public.seguimiento_entregas ADD CONSTRAINT seguimiento_estado_valido
 CHECK(estado IN ('en_transito','entregado','entregado_con_novedad','devuelto_cliente','devolucion_parcial'));

CREATE OR REPLACE FUNCTION public.dashboard_despachos_mensuales(
 p_desde date, p_hasta date, p_cliente text DEFAULT NULL, p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN
  RAISE EXCEPTION 'Acceso exclusivo de Administracion y Gerencia' USING ERRCODE='42501';
 END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde
 OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
  WITH meses AS (
   SELECT generate_series(date_trunc('month',p_desde::timestamp),date_trunc('month',p_hasta::timestamp),interval '1 month')::date mes
  ), datos AS (
   SELECT date_trunc('month',d.fecha AT TIME ZONE 'America/Bogota')::date mes,
    count(*) total,
    count(*) FILTER(WHERE s.estado='entregado') sin_contratiempo,
    count(*) FILTER(WHERE s.estado='entregado_con_novedad') con_contratiempo
   FROM public.despachos_oc d
   LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
   WHERE d.fase='despachado'
    AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
    AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
    AND d.fecha<=least(p_corte,now())
    AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
    AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
   GROUP BY 1
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('mes',m.mes,'total',coalesce(d.total,0),
   'sin_contratiempo',coalesce(d.sin_contratiempo,0),'con_contratiempo',coalesce(d.con_contratiempo,0)) ORDER BY m.mes),'[]'::jsonb)
  FROM meses m LEFT JOIN datos d USING(mes)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_despachos_mensuales(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_despachos_mensuales(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
