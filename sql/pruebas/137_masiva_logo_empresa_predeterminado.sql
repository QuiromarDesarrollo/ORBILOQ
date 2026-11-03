-- Solo ORBILOQ-DEV, después de 136. El logo de Quiromar queda compartido
-- entre operaciones; los snapshots de documentos ya emitidos no se tocan.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF position('masiva136_catalogo_compartido' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 136'; END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.masiva137_reemplazar(fuente text,patron text,nuevo text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE encontrado text;
BEGIN
 encontrado:=CASE WHEN position(patron IN fuente)>0 THEN patron END;
 IF encontrado IS NULL THEN RAISE EXCEPTION 'Definición inesperada en logo predeterminado de Masiva'; END IF;
 RETURN replace(fuente,encontrado,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva137_logo_empresa_predeterminado' IN f)=0 THEN
  f:=pg_temp.masiva137_reemplazar(
   f,
   $pattern$INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;$pattern$,
   $new$INSERT INTO public.masiva_operaciones(nombre,cliente,logo_empresa,creado_por)
  SELECT trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),
   coalesce((SELECT o.logo_empresa FROM public.masiva_operaciones o WHERE o.logo_empresa<>'' ORDER BY o.creado DESC LIMIT 1),''),actor
  RETURNING id INTO operacion; -- masiva137_logo_empresa_predeterminado$new$);
  f:=pg_temp.masiva137_reemplazar(
   f,
   $pattern$SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;$pattern$,
   $new$/* masiva137_logo_empresa_predeterminado: conservar en todas las operaciones. */
  IF p_datos ? 'logo_empresa' AND coalesce(p_datos->>'logo_empresa','')<>'' THEN
   UPDATE public.masiva_operaciones SET logo_empresa=p_datos->>'logo_empresa';
  END IF;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;$new$);
  EXECUTE f;
 END IF;
END $migration$;
NOTIFY pgrst,'reload schema';
COMMIT;
