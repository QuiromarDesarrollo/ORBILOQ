-- Solo ORBILOQ-DEV, después de 137. Permite cambiar el logo global de Quiromar
-- cumpliendo la política del entorno, que exige una cláusula WHERE en UPDATE.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
   AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
 IF position('masiva137_logo_empresa_predeterminado' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Aplica primero 137';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.masiva138_reemplazar(fuente text,patron text,nuevo text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
 IF position(patron IN fuente)=0 THEN
  RAISE EXCEPTION 'Definición inesperada al corregir actualización del logo';
 END IF;
 RETURN replace(fuente,patron,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva138_logo_update_where' IN f)=0 THEN
  f:=pg_temp.masiva138_reemplazar(
   f,
   $pattern$UPDATE public.masiva_operaciones SET logo_empresa=p_datos->>'logo_empresa';$pattern$,
   $new$UPDATE public.masiva_operaciones
   SET logo_empresa=p_datos->>'logo_empresa'
   WHERE logo_empresa IS DISTINCT FROM p_datos->>'logo_empresa'; -- masiva138_logo_update_where$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $$ DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva138_logo_update_where' IN f)=0
   OR position('WHERE logo_empresa IS DISTINCT FROM p_datos->>' IN f)=0 THEN
  RAISE EXCEPTION 'No quedó instalada la corrección del logo global';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
