-- Producción cxrflhgnxvomcvxzugda. Equivalente a 151, verificada en ORBILOQ-DEV.
-- Amplía solo masiva_empaque_consultar; no modifica kits ni movimientos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $patch$
DECLARE original text; nuevo text; anterior pg_catalog.pg_proc; posterior pg_catalog.pg_proc;
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda'
 THEN RAISE EXCEPTION 'Solo producción ORBILOQ'; END IF;
 SELECT * INTO anterior FROM pg_catalog.pg_proc WHERE oid='public.masiva_empaque_consultar(uuid,text)'::regprocedure;
 original:=pg_get_functiondef(anterior.oid);
 IF position('masiva151_avance_validacion_lista' IN original)>0 THEN RETURN; END IF;
 IF position('public.masiva_acceso()' IN original)=0
 OR position('''terminados'',(SELECT count(*)' IN original)=0
 OR position('''id'',k.id,''numero_persona'',k.numero_persona' IN original)=0
 THEN RAISE EXCEPTION 'Lectura de empaque no reconocida; revisar antes de actualizar'; END IF;
 nuevo:=replace(original,'''terminados'',(SELECT count(*)',
 '''validados'',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=p_operacion AND lista=trim(p_lista) AND estado=''validado''),''terminados'',(SELECT count(*)');
 nuevo:=replace(nuevo,'''id'',k.id,''numero_persona'',k.numero_persona',
 '''id'',k.id,''estado'',k.estado,''numero_persona'',k.numero_persona');
 nuevo:=regexp_replace(nuevo,'\mBEGIN\M',E'BEGIN\n -- masiva151_avance_validacion_lista\n','i');
 EXECUTE nuevo;
 SELECT * INTO posterior FROM pg_catalog.pg_proc WHERE oid='public.masiva_empaque_consultar(uuid,text)'::regprocedure;
 IF (posterior.oid,posterior.proowner,posterior.proacl,posterior.provolatile,posterior.prosecdef,posterior.proconfig)
 IS DISTINCT FROM (anterior.oid,anterior.proowner,anterior.proacl,anterior.provolatile,anterior.prosecdef,anterior.proconfig)
 THEN RAISE EXCEPTION 'Identidad, permisos o configuración alterados'; END IF;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
