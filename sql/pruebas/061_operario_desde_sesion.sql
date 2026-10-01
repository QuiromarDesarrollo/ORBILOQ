-- SOLO PRUEBAS. Aplicar después de 060. No ejecutar en producción.
-- Cambia exclusivamente funciones para operaciones futuras; no modifica historial.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
   RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS.';
 END IF;
 IF to_regprocedure('public.wms_cuenta_activa()') IS NULL THEN
   RAISE EXCEPTION 'Aplicar primero 060 en PRUEBAS.';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.wms_nombre_actor() RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE nombre_actor text;
BEGIN
 SELECT nullif(trim(nombre),'') INTO nombre_actor FROM public.usuarios
 WHERE auth_id=auth.uid() AND activo;
 IF nombre_actor IS NULL THEN
   RAISE EXCEPTION 'Se requiere una cuenta activa con nombre para registrar la operación.' USING ERRCODE='42501';
 END IF;
 RETURN nombre_actor;
END $$;
REVOKE ALL ON FUNCTION public.wms_nombre_actor() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_nombre_actor() TO authenticated;

DO $rpc$
DECLARE f record; ddl text; guardia text; parametro text;
BEGIN
 FOR f IN SELECT p.oid,p.proname,p.oid::regprocedure firma,p.proargnames nombres,
   l.lanname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   JOIN pg_language l ON l.oid=p.prolang
   WHERE n.nspname='public' AND p.proname IN
   ('crear_lote','recibir_lote_item','registrar_no_conforme','liberar_no_conforme',
    'enviar_no_conforme_aliado','liberar_no_conforme_aliado','registrar_sobrante','importar_ordenes_produccion')
 LOOP
   ddl:=pg_get_functiondef(f.oid);
   IF strpos(ddl,'ORBILOQ_ACTOR_V61')>0 THEN CONTINUE; END IF;
   IF f.lanname<>'plpgsql' OR strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN
     RAISE EXCEPTION 'Definición inesperada en %. Revisar antes de continuar.',f.firma;
   END IF;
   guardia:=E'BEGIN\n -- ORBILOQ_ACTOR_V61\n PERFORM public.wms_nombre_actor();\n';
   FOREACH parametro IN ARRAY ARRAY['p_operario_nombre','p_usuario_nombre','p_recibido_por'] LOOP
     IF parametro=ANY(f.nombres) THEN
       guardia:=guardia||format(E' %I := public.wms_nombre_actor();\n',parametro);
     END IF;
   END LOOP;
   -- La FK del responsable se resuelve por Auth, nunca por un nombre duplicado.
   ddl:=regexp_replace(ddl,'where nombre = p_operario_nombre limit 1',
     'where auth_id = auth.uid() and activo limit 1','gi');
   -- El actor ahora pertenece a usuarios, no al catálogo ampliable de terceros.
   ddl:=replace(ddl,
     ' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;', '');
   ddl:=regexp_replace(ddl,E'\\mbegin\\M',guardia,'i');
   IF strpos(ddl,'ORBILOQ_ACTOR_V61')=0 THEN RAISE EXCEPTION 'No se pudo actualizar %.',f.firma; END IF;
   EXECUTE ddl;
 END LOOP;
END $rpc$;
NOTIFY pgrst,'reload schema';
COMMIT;
