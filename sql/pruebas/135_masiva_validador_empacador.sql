-- Solo ORBILOQ-DEV, después de 134. Una persona puede empacar y validar.
-- Conserva permisos, identidad autenticada, inventario y penalización MAL EMPAQUE.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $migration$
DECLARE definicion text; actual text; bloqueo text := $block$IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo empacó'; END IF;$block$;
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 SELECT replace(pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure),chr(13),'') INTO definicion;
 IF position('masiva_135_roles_compatibles' IN definicion)>0 THEN RETURN; END IF;
 actual:=substring(definicion from 'IF EXISTS\(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios[^;]+; END IF;');
 IF actual IS NULL OR regexp_replace(actual,'\s+',' ','g')<>regexp_replace(bloqueo,'\s+',' ','g') OR position('asignacion_tardia' IN definicion)=0
 THEN RAISE EXCEPTION 'Definición inesperada: se requiere la versión 134'; END IF;
 EXECUTE replace(definicion,actual,'/* masiva_135_roles_compatibles: el empacador también puede validar su kit. */');
END $migration$;
COMMIT;
