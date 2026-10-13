-- Fixture exclusivo del ensayo local: definición enviada desde DEV, 2026-10-13.
DO $$ BEGIN
 IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo local'; END IF;
 IF to_regprocedure('public.kardex_historico(date)') IS NOT NULL THEN RAISE EXCEPTION 'Fixture ya instalado'; END IF;
END $$;
CREATE TABLE public.kardex_historico_config(activado_en timestamptz);
CREATE TABLE public.kardex_versiones(item_id uuid,datos jsonb,registrado_en timestamptz,version bigint);
INSERT INTO public.kardex_historico_config VALUES(now()-interval '2 days');
INSERT INTO public.kardex_versiones VALUES
 ('94000000-0000-0000-0000-000000000001','{"cantidad":1}',now()-interval '1 day',1),
 ('94000000-0000-0000-0000-000000000001','{"cantidad":2}',now()-interval '1 hour',2),
 ('94000000-0000-0000-0000-000000000002','{"admin_eliminado_en":"2026-01-01"}',now()-interval '1 hour',1);
CREATE OR REPLACE FUNCTION public.kardex_historico(p_fecha date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE inicio timestamptz; limite timestamptz; filas jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion','logistica')) THEN
   RAISE EXCEPTION 'Se requiere una cuenta activa.' USING ERRCODE='42501';
 END IF;
 SELECT activado_en INTO inicio FROM public.kardex_historico_config;
 IF p_fecha IS NULL THEN RETURN jsonb_build_object('activado_en',inicio,'hoy',(now() AT TIME ZONE 'America/Bogota')::date); END IF;
 IF p_fecha < (inicio AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'Historico disponible desde %. No existen versiones verificables anteriores.',(inicio AT TIME ZONE 'America/Bogota')::date; END IF;
 IF p_fecha > (now() AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'No se puede consultar una fecha futura.'; END IF;
 limite := least((p_fecha+1)::timestamp AT TIME ZONE 'America/Bogota',clock_timestamp());
 SELECT coalesce(jsonb_agg(v.datos ORDER BY v.item_id),'[]') INTO filas FROM (
   SELECT DISTINCT ON(item_id) item_id,datos FROM public.kardex_versiones
   WHERE registrado_en < limite ORDER BY item_id,registrado_en DESC,version DESC
 ) v WHERE v.datos IS NOT NULL AND v.datos->>'admin_eliminado_en' IS NULL;
 RETURN jsonb_build_object('activado_en',inicio,'fecha',p_fecha,'corte',limite,'en_curso',p_fecha=(now() AT TIME ZONE 'America/Bogota')::date,'filas',filas);
END $function$;
REVOKE ALL ON FUNCTION public.kardex_historico(date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.kardex_historico(date) TO authenticated;
CREATE TABLE public.test_historico_definicion AS
 SELECT prosrc,proacl,prosecdef,proconfig FROM pg_proc WHERE oid='public.kardex_historico(date)'::regprocedure;
