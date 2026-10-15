-- ORBILOQ-DEV. Requiere Seguimiento, roles y datos ERP existentes.
-- No altera inventario, estados de entrega ni documentos históricos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.facturacion_le(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id),
 revision integer NOT NULL,
 remision text NOT NULL DEFAULT '' CHECK(length(remision)<=150),
 id_oc text NOT NULL DEFAULT '' CHECK(length(id_oc)<=150),
 version integer NOT NULL DEFAULT 1,
 actualizado_en timestamptz NOT NULL DEFAULT now(),
 actualizado_por uuid NOT NULL REFERENCES auth.users(id),
 PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.facturacion_le ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.facturacion_le FROM PUBLIC,anon,authenticated;

-- Uso interno: la fecha de recibido en la revision vigente habilita la tarjeta.
CREATE OR REPLACE FUNCTION public.facturacion_le_dato(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 WITH base AS (
 SELECT d.id,d.ediciones revision,d.cliente,l.numero le,
 coalesce(nullif(trim(d.oc_documento),''),d.oc,'') oc,
 s.recibido,s.version version_seguimiento,coalesce(f.version,0) version,
 coalesce(f.remision,l.datos->>'remision','') remision,
 coalesce(f.id_oc,CASE WHEN cardinality(ids.valores)=1 THEN ids.valores[1] ELSE '' END) id_oc,
 coalesce(to_jsonb(ids.valores),'[]'::jsonb) ids_erp
 FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id
 JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 LEFT JOIN public.facturacion_le f ON f.despacho_id=d.id AND f.revision=d.ediciones
 LEFT JOIN LATERAL (
  SELECT array_agg(DISTINCT o.oc_id_erp::text ORDER BY o.oc_id_erp::text) FILTER(WHERE o.oc_id_erp IS NOT NULL) valores
  FROM jsonb_array_elements(coalesce(d.detalle,'[]'::jsonb)) e
  JOIN public.items_orden i ON i.id::text=e->>'item_id'
  JOIN public.ordenes_produccion o ON o.id=i.orden_id
 ) ids ON true
 WHERE d.id=p_id AND d.fase='despachado' AND s.recibido IS NOT NULL AND l.numero IS NOT NULL
 ) SELECT to_jsonb(b)||jsonb_build_object('completa',length(trim(b.remision))>0 AND length(trim(b.id_oc))>0 AND length(trim(b.oc))>0) FROM base b
$$;
REVOKE ALL ON FUNCTION public.facturacion_le_dato(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.facturacion_le_listar(p_completa boolean DEFAULT false,p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Administrador' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.dato ORDER BY x.numero DESC) FROM (
  SELECT l.numero, public.facturacion_le_dato(l.despacho_id) dato FROM public.listas_empaque l
  WHERE (p_antes IS NULL OR l.numero<p_antes)
   AND (public.facturacion_le_dato(l.despacho_id)->>'completa')::boolean=p_completa
  ORDER BY l.numero DESC LIMIT 200
 ) x),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.facturacion_le_guardar(p_id uuid,p_revision integer,p_version integer,p_version_seguimiento integer,p_remision text,p_id_oc text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; v integer; s public.seguimiento_entregas%rowtype;
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.fase<>'despachado' OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambió. Actualiza Facturación'; END IF;
 SELECT * INTO s FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision FOR UPDATE;
 IF NOT FOUND OR s.recibido IS NULL OR s.version IS DISTINCT FROM p_version_seguimiento THEN RAISE EXCEPTION 'Cambió el seguimiento o falta fecha de entrega. Actualiza Facturación'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.listas_empaque WHERE despacho_id=p_id AND numero IS NOT NULL) THEN RAISE EXCEPTION 'Falta la lista de empaque'; END IF;
 SELECT version INTO v FROM public.facturacion_le WHERE despacho_id=p_id AND revision=p_revision;
 IF coalesce(v,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Otra persona editó la facturación. Recarga antes de guardar'; END IF;
 IF length(coalesce(p_remision,''))>150 OR length(coalesce(p_id_oc,''))>150 THEN RAISE EXCEPTION 'Máximo 150 caracteres por campo'; END IF;
 INSERT INTO public.facturacion_le(despacho_id,revision,remision,id_oc,version,actualizado_por)
 VALUES(p_id,p_revision,trim(coalesce(p_remision,'')),trim(coalesce(p_id_oc,'')),coalesce(v,0)+1,auth.uid())
 ON CONFLICT(despacho_id,revision) DO UPDATE SET remision=excluded.remision,id_oc=excluded.id_oc,version=excluded.version,actualizado_por=excluded.actualizado_por,actualizado_en=now();
 RETURN coalesce(v,0)+1;
END $$;
REVOKE ALL ON FUNCTION public.facturacion_le_listar(boolean,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.facturacion_le_guardar(uuid,integer,integer,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.facturacion_le_listar(boolean,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facturacion_le_guardar(uuid,integer,integer,integer,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
