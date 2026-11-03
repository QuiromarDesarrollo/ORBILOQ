-- ORBILOQ-DEV: borradores privados, recuperables desde cualquier equipo.
-- No modifica reservas, inventario, movimientos ni despachos confirmados.
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

CREATE TABLE IF NOT EXISTS public.despacho_borradores (
 usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 clave text NOT NULL CHECK (clave IN ('nuevo','inventario') OR clave ~ '^(correccion|inventario):[0-9a-fA-F-]{36}$'),
 datos jsonb NOT NULL CHECK (jsonb_typeof(datos)='object' AND octet_length(datos::text)<=2000000),
 version bigint NOT NULL DEFAULT 1 CHECK (version>0),
 actualizado timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(usuario_id,clave)
);
ALTER TABLE public.despacho_borradores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.despacho_borradores DROP CONSTRAINT IF EXISTS despacho_borradores_clave_check;
ALTER TABLE public.despacho_borradores ADD CONSTRAINT despacho_borradores_clave_check
 CHECK (clave IN ('nuevo','inventario') OR clave ~ '^(correccion|inventario):[0-9a-fA-F-]{36}$');
DROP POLICY IF EXISTS despacho_borradores_propios ON public.despacho_borradores;
CREATE POLICY despacho_borradores_propios ON public.despacho_borradores
 FOR SELECT TO authenticated USING (usuario_id=(SELECT auth.uid()));
REVOKE ALL ON public.despacho_borradores FROM anon,authenticated;
GRANT SELECT ON public.despacho_borradores TO authenticated;

CREATE OR REPLACE FUNCTION public.despacho_borrador_cargar(p_clave text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=pg_catalog,public AS $$
DECLARE v_resultado jsonb;
BEGIN
 IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 SELECT jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
 INTO v_resultado FROM public.despacho_borradores
 WHERE usuario_id=auth.uid() AND clave=p_clave;
 RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.despacho_borrador_guardar(
 p_clave text,p_datos jsonb,p_version bigint DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
DECLARE v_usuario uuid:=auth.uid(); v_resultado jsonb;
BEGIN
 IF v_usuario IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 IF p_version IS NULL OR p_version<0 THEN
  RAISE EXCEPTION 'Versión de borrador inválida';
 END IF;
 IF p_version=0 THEN
  INSERT INTO public.despacho_borradores(usuario_id,clave,datos)
  VALUES(v_usuario,p_clave,p_datos)
  ON CONFLICT(usuario_id,clave) DO NOTHING
  RETURNING jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
  INTO v_resultado;
 ELSE
  UPDATE public.despacho_borradores SET datos=p_datos,
   version=version+1,actualizado=clock_timestamp()
  WHERE usuario_id=v_usuario AND clave=p_clave AND version=p_version
  RETURNING jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
  INTO v_resultado;
 END IF;
 IF v_resultado IS NULL THEN
  RAISE EXCEPTION 'El borrador cambió en otro equipo. Vuelve a cargarlo antes de guardar.'
   USING ERRCODE='40001';
 END IF;
 RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.despacho_borrador_eliminar(p_clave text,p_version bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 DELETE FROM public.despacho_borradores
 WHERE usuario_id=auth.uid() AND clave=p_clave AND version=p_version;
 IF NOT FOUND AND EXISTS(SELECT 1 FROM public.despacho_borradores
   WHERE usuario_id=auth.uid() AND clave=p_clave) THEN
  RAISE EXCEPTION 'El borrador cambió en otro equipo. Vuelve a cargarlo antes de descartarlo.'
   USING ERRCODE='40001';
 END IF;
END $$;

REVOKE ALL ON FUNCTION public.despacho_borrador_cargar(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.despacho_borrador_guardar(text,jsonb,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.despacho_borrador_eliminar(text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_cargar(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_guardar(text,jsonb,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_eliminar(text,bigint) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
