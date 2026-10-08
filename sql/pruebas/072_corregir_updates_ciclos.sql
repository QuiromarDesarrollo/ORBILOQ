-- SOLO ORBILOQ-DEV. Aplicar completo después de 071; se puede repetir.
-- Corrige funciones, sin borrar datos ni desactivar la protección de UPDATE.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $parche$
DECLARE
 firma text;
 definicion text;
 anterior_revision constant text := 'UPDATE public.ciclos_revision SET revision=revision+1;';
 nueva_revision constant text := 'UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;';
 anterior_ordenes constant text := 'UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o);';
 nueva_ordenes constant text := 'UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o) WHERE o.versiones IS DISTINCT FROM public.ciclos_versiones(o.inicio,o.fines,o);';
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe'
 THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide el inventario DEV'; END IF;
 FOREACH firma IN ARRAY ARRAY[
   'public.ciclos_configurar(text,date,integer,integer,integer,text,integer)',
   'public.ciclos_importar(jsonb,text,boolean,text)'
 ] LOOP
   IF to_regprocedure(firma) IS NULL THEN RAISE EXCEPTION 'Falta 071: %',firma; END IF;
   definicion:=pg_get_functiondef(to_regprocedure(firma));
   IF position(anterior_revision IN definicion)=0 AND position(nueva_revision IN definicion)=0
   THEN RAISE EXCEPTION 'La funcion % cambio; revisar antes de aplicar',firma; END IF;
   definicion:=replace(definicion,anterior_revision,nueva_revision);
   IF firma LIKE 'public.ciclos_configurar(%' THEN
     IF position(anterior_ordenes IN definicion)=0 AND position(nueva_ordenes IN definicion)=0
     THEN RAISE EXCEPTION 'La asignacion de versiones cambio; revisar antes de aplicar'; END IF;
     definicion:=replace(definicion,anterior_ordenes,nueva_ordenes);
   END IF;
   -- pg_get_functiondef conserva firma, SECURITY DEFINER y configuración.
   -- CREATE OR REPLACE mantiene propietario y permisos existentes.
   EXECUTE definicion;
 END LOOP;
END $parche$;
NOTIFY pgrst,'reload schema';
COMMIT;
SELECT 'OK: actualizaciones de ciclos corregidas; vuelve a importar el Excel.' AS resultado;
