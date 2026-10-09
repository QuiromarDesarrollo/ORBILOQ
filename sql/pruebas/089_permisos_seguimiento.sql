-- ORBILOQ-DEV. Ejecutar después de 087 y 088. No altera inventario.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere migracion 087'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_acceso() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','seguimiento'))
$$;
REVOKE ALL ON FUNCTION public.seguimiento_acceso() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_acceso() TO authenticated;
-- Conserva las validaciones, firmas, permisos y lógica de las versiones instaladas.
-- Las RPC v87 delegan en estas funciones base, sin acceso directo para authenticated.
DO $$ DECLARE nombre text; oid_func oid; definicion text; BEGIN
 FOREACH nombre IN ARRAY ARRAY['seguimiento_confirmar','seguimiento_guardar_base_v87','seguimiento_listar_base_v87','seguimiento_archivo_permitido'] LOOP
  SELECT p.oid INTO STRICT oid_func FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=nombre;
  definicion:=pg_get_functiondef(oid_func);
  IF position('public.le_acceso()' IN definicion)=0 AND position('public.seguimiento_acceso()' IN definicion)=0 THEN RAISE EXCEPTION 'Validacion inesperada en %',nombre; END IF;
  definicion:=replace(definicion,'public.le_acceso()','public.seguimiento_acceso()');
  definicion:=replace(definicion,'Se requiere Seguimiento o Despacho','Se requiere Seguimiento o Administrador');
  EXECUTE definicion;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
