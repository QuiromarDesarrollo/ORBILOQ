-- Restringe pantallas administrativas de Masiva. No modifica datos operativos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $patch$
DECLARE r record; original text; nuevo text; condicion text; guardia text; total integer:=0;
BEGIN
 FOR r IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN('masiva_consultar','masiva_maestro_consultar','masiva_conciliacion_consultar','masiva_ejecutar') LOOP
  original:=pg_get_functiondef(r.oid);
  IF position('masiva_admin_pantallas_20261125' IN original)>0 THEN total:=total+1; CONTINUE; END IF;
  IF position('public.masiva_acceso()' IN original)=0 THEN RAISE EXCEPTION 'Definicion inesperada: %',r.proname; END IF;
  condicion:=CASE r.proname
   WHEN 'masiva_consultar' THEN 'p_vista IN (''listas'',''listado'',''base'',''conciliacion'',''auditoria'',''documentos'',''configuracion'')'
   WHEN 'masiva_ejecutar' THEN 'p_accion IN (''documento'',''registrar_impresion'')'
   ELSE 'true' END;
  guardia:=E'BEGIN
 -- masiva_admin_pantallas_20261125
 IF ('||condicion||E') AND NOT EXISTS (SELECT 1 FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo AND ''admin''=ANY(coalesce(u.roles,ARRAY[u.rol]))) THEN RAISE EXCEPTION ''Esta pantalla de Masiva requiere rol Administrador'' USING ERRCODE=''42501''; END IF;
';
  nuevo:=regexp_replace(original,'\mBEGIN\M',guardia,'i');
  IF nuevo=original THEN RAISE EXCEPTION 'No se encontro bloque principal: %',r.proname; END IF;
  EXECUTE nuevo;
  total:=total+1;
 END LOOP;
 IF total<>4 THEN RAISE EXCEPTION 'Se esperaban 4 funciones, encontradas %',total; END IF;
END $patch$;
COMMIT;
SELECT proname,position('masiva_admin_pantallas_20261125' IN pg_get_functiondef(oid))>0 AS protegido FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN('masiva_consultar','masiva_maestro_consultar','masiva_conciliacion_consultar','masiva_ejecutar');
