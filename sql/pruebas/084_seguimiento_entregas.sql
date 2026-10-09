-- SOLO ORBILOQ-DEV. Requiere 082. Ejecutar completo.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.seguimiento_entregas(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), revision integer NOT NULL,
 transportadora text NOT NULL DEFAULT '', placa_guia text NOT NULL DEFAULT '', recibido date,
 evidencia_le jsonb, evidencia_guia jsonb, observaciones text NOT NULL DEFAULT '',
 version integer NOT NULL DEFAULT 1, actualizado_en timestamptz NOT NULL DEFAULT now(), actualizado_por uuid,
 PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.seguimiento_entregas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.seguimiento_entregas FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.fila ORDER BY x.numero DESC) FROM (
 SELECT l.numero, jsonb_build_object('id',d.id,'revision',d.ediciones,'le',l.numero,'cliente',d.cliente,'fecha',d.fecha,
 'cajas',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria'))='CAJA') a),
 'empaques',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria')) IN ('BOLSA','EMPAQUE')) a),
 'transportadora',coalesce(s.transportadora,''),'placa_guia',coalesce(s.placa_guia,''),'recibido',s.recibido,
 'evidencia_le',s.evidencia_le,'evidencia_guia',s.evidencia_guia,'observaciones',coalesce(s.observaciones,''),'version',coalesce(s.version,0)) fila
 FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id
 LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 WHERE d.fase='despachado' AND (p_antes IS NULL OR l.numero<p_antes)
 ORDER BY l.numero DESC LIMIT 200) x),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; v integer; f date; k text; a jsonb;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.fase<>'despachado' OR d.ediciones<>p_revision THEN RAISE EXCEPTION 'La LE cambió o volvió a empaque. Actualiza Seguimiento'; END IF;
 SELECT version INTO v FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision;
 IF coalesce(v,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Otra persona actualizó esta LE. Recarga antes de guardar'; END IF;
 IF length(coalesce(p_datos->>'transportadora',''))>150 OR length(coalesce(p_datos->>'placa_guia',''))>150 OR length(coalesce(p_datos->>'observaciones',''))>3000 THEN RAISE EXCEPTION 'Los textos superan el tamaño permitido'; END IF;
 f:=nullif(p_datos->>'recibido','')::date;
 IF f IS NOT NULL AND (f<(d.fecha AT TIME ZONE 'America/Bogota')::date OR f>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'La recepción debe estar entre el despacho y hoy'; END IF;
 FOREACH k IN ARRAY ARRAY['evidencia_le','evidencia_guia'] LOOP
  a:=p_datos->k;
  IF a IS NOT NULL AND a<>'null'::jsonb THEN
   IF jsonb_typeof(a)<>'object' OR nullif(a->>'nombre','') IS NULL OR length(a->>'nombre')>255 OR coalesce(a->>'path','') NOT LIKE p_id::text||'/'||p_revision||'/'||k||'/%' THEN RAISE EXCEPTION 'Evidencia inválida'; END IF;
   IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='seguimiento-evidencias' AND name=a->>'path') THEN RAISE EXCEPTION 'La evidencia no terminó de cargarse'; END IF;
  END IF;
 END LOOP;
 INSERT INTO public.seguimiento_entregas(despacho_id,revision,transportadora,placa_guia,recibido,evidencia_le,evidencia_guia,observaciones,version,actualizado_por)
 VALUES(p_id,p_revision,trim(coalesce(p_datos->>'transportadora','')),trim(coalesce(p_datos->>'placa_guia','')),f,nullif(p_datos->'evidencia_le','null'::jsonb),nullif(p_datos->'evidencia_guia','null'::jsonb),coalesce(p_datos->>'observaciones',''),coalesce(v,0)+1,auth.uid())
 ON CONFLICT(despacho_id,revision) DO UPDATE SET transportadora=excluded.transportadora,placa_guia=excluded.placa_guia,recibido=excluded.recibido,evidencia_le=excluded.evidencia_le,evidencia_guia=excluded.evidencia_guia,observaciones=excluded.observaciones,version=excluded.version,actualizado_por=excluded.actualizado_por,actualizado_en=now();
 RETURN coalesce(v,0)+1;
END $$;
-- Bucket privado: las evidencias se abren con una URL temporal.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('seguimiento-evidencias','seguimiento-evidencias',false,10485760,ARRAY['application/pdf','image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
CREATE OR REPLACE FUNCTION public.seguimiento_archivo_permitido(p_name text,p_escritura boolean) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT public.le_acceso() AND EXISTS(SELECT 1 FROM public.despachos_oc d WHERE d.id::text=split_part(p_name,'/',1)
 AND (NOT p_escritura OR (d.fase='despachado' AND d.ediciones::text=split_part(p_name,'/',2)))
 AND split_part(p_name,'/',3) IN ('evidencia_le','evidencia_guia'));
$$;
DROP POLICY IF EXISTS seguimiento_archivo_leer ON storage.objects;
CREATE POLICY seguimiento_archivo_leer ON storage.objects FOR SELECT TO authenticated USING(bucket_id='seguimiento-evidencias' AND public.seguimiento_archivo_permitido(name,false));
DROP POLICY IF EXISTS seguimiento_archivo_subir ON storage.objects;
CREATE POLICY seguimiento_archivo_subir ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='seguimiento-evidencias' AND public.seguimiento_archivo_permitido(name,true));
-- Las políticas amplias de otros módulos no deben volver público este bucket ni permitir sobrescribir evidencias.
DROP POLICY IF EXISTS seguimiento_archivo_limitar_lectura ON storage.objects;
CREATE POLICY seguimiento_archivo_limitar_lectura ON storage.objects AS RESTRICTIVE FOR SELECT TO public USING(bucket_id<>'seguimiento-evidencias' OR public.seguimiento_archivo_permitido(name,false));
DROP POLICY IF EXISTS seguimiento_archivo_limitar_alta ON storage.objects;
CREATE POLICY seguimiento_archivo_limitar_alta ON storage.objects AS RESTRICTIVE FOR INSERT TO public WITH CHECK(bucket_id<>'seguimiento-evidencias' OR public.seguimiento_archivo_permitido(name,true));
DROP POLICY IF EXISTS seguimiento_archivo_inmutable ON storage.objects;
CREATE POLICY seguimiento_archivo_inmutable ON storage.objects AS RESTRICTIVE FOR UPDATE TO public USING(bucket_id<>'seguimiento-evidencias');
DROP POLICY IF EXISTS seguimiento_archivo_conservar ON storage.objects;
CREATE POLICY seguimiento_archivo_conservar ON storage.objects AS RESTRICTIVE FOR DELETE TO public USING(bucket_id<>'seguimiento-evidencias');
REVOKE ALL ON FUNCTION public.seguimiento_entregas_listar(bigint),public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_listar(bigint),public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
