-- SOLO DEV. Requiere 055..059. No ejecutar en produccion.
-- Conserva IDs, relaciones e historial. No elimina registros existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS.'; END IF;
 IF to_regprocedure('public.admin_exportar_kardex()') IS NULL THEN RAISE EXCEPTION 'Aplicar primero hasta 059 en DEV.'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_catalogos_historial (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid NOT NULL,
 fecha timestamptz NOT NULL DEFAULT now(), catalogo text NOT NULL, registro_id uuid NOT NULL,
 antes jsonb, despues jsonb NOT NULL
);
ALTER TABLE public.admin_catalogos_historial ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_catalogos_historial FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_catalogos_historial TO authenticated;
DROP POLICY IF EXISTS admin_lectura ON public.admin_catalogos_historial;
CREATE POLICY admin_lectura ON public.admin_catalogos_historial FOR SELECT TO authenticated USING(public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.wms_cuenta_activa() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo);
$$;
REVOKE ALL ON FUNCTION public.wms_cuenta_activa() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_cuenta_activa() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_catalogos_listar(p_tipo text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN ('usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados') THEN RAISE EXCEPTION 'Catalogo no permitido.'; END IF;
 EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object(''version'',md5(to_jsonb(t)::text)) ORDER BY %I,id),''[]''::jsonb) FROM public.%I t',CASE p_tipo WHEN 'ubicaciones' THEN 'codigo' ELSE 'nombre' END,p_tipo) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.admin_catalogos_guardar(p_tipo text,p_id uuid,p_nombre text,p_activo boolean,p_version text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; nombre_col text; activo_col text; ident uuid; nombre text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN ('ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados') THEN RAISE EXCEPTION 'Catalogo no permitido.'; END IF;
 nombre:=trim(p_nombre);
 IF coalesce(length(nombre),0) NOT BETWEEN 1 AND 150 OR p_activo IS NULL THEN RAISE EXCEPTION 'Indica un nombre de 1 a 150 caracteres y el estado.'; END IF;
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
 IF p_tipo='ubicaciones' THEN
   LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos,public.admin_correcciones,public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
 ELSE EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE',p_tipo); END IF;
 nombre_col:=CASE p_tipo WHEN 'ubicaciones' THEN 'codigo' ELSE 'nombre' END;
 activo_col:=CASE WHEN p_tipo IN ('ubicaciones','causales_devolucion') THEN 'activa' ELSE 'activo' END;
 IF p_id IS NOT NULL THEN
   EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_tipo) INTO anterior USING p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El registro cambio. Actualiza la lista y vuelve a editar.'; END IF;
 END IF;
 EXECUTE format('SELECT id FROM public.%I WHERE lower(trim(%I))=lower($1) AND id IS DISTINCT FROM $2 LIMIT 1',p_tipo,nombre_col) INTO ident USING nombre,p_id;
 IF ident IS NOT NULL AND (p_id IS NULL OR nombre IS DISTINCT FROM anterior->>nombre_col OR (p_activo AND NOT (anterior->>activo_col)::boolean)) THEN
   RAISE EXCEPTION 'Ya existe ese nombre, incluso si esta inactivo. Edita o reactiva el registro existente.';
 END IF;
 IF p_tipo='ubicaciones' AND NOT p_activo AND p_id IS NOT NULL THEN
   IF EXISTS(SELECT 1 FROM public.movimientos WHERE ubicacion_id=p_id GROUP BY item_orden_id
     HAVING sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END)<>0)
     OR EXISTS(SELECT 1 FROM public.lote_items WHERE ubicacion_destino_id=p_id AND estado='en_transito') THEN
     RAISE EXCEPTION 'El estante tiene existencias o recepciones pendientes. Concilialas antes de desactivarlo.';
   END IF;
 END IF;
 IF p_id IS NULL THEN
   EXECUTE format('INSERT INTO public.%I(%I,%I) VALUES($1,$2) RETURNING to_jsonb(%I.*)',p_tipo,nombre_col,activo_col,p_tipo) INTO nuevo USING nombre,p_activo;
 ELSE
   EXECUTE format('UPDATE public.%I SET %I=$1,%I=$2 WHERE id=$3 RETURNING to_jsonb(%I.*)',p_tipo,nombre_col,activo_col,p_tipo) INTO nuevo USING nombre,p_activo,p_id;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),p_tipo,(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_guardar(p_id uuid,p_nombre text,p_rol text,p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
 SELECT to_jsonb(u) INTO anterior FROM public.usuarios u WHERE id=p_id;
 IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'La cuenta cambio. Actualiza la lista antes de guardar.'; END IF;
 IF p_rol IS NULL OR p_rol NOT IN ('admin','produccion','logistica') OR p_activo IS NULL OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Nombre, rol o estado invalido.'; END IF;
 IF (anterior->>'auth_id')::uuid=auth.uid() AND NOT p_activo THEN RAISE EXCEPTION 'No puedes desactivar tu propia cuenta.'; END IF;
 IF (anterior->>'activo')::boolean AND anterior->>'rol'='admin' AND (NOT p_activo OR p_rol<>'admin')
    AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE id<>p_id AND rol='admin' AND activo AND auth_id IS NOT NULL) THEN RAISE EXCEPTION 'Debe permanecer al menos un administrador activo con acceso.'; END IF;
 UPDATE public.usuarios SET nombre=trim(p_nombre),rol=p_rol,activo=p_activo WHERE id=p_id RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),'usuarios',p_id,anterior,nuevo);
 RETURN nuevo;
END $$;

-- Solo la funcion de servidor puede vincular un alta de Auth; nunca el navegador.
CREATE OR REPLACE FUNCTION public.admin_usuario_registrar(p_actor uuid,p_auth_id uuid,p_numero text,p_nombre text,p_rol text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE nuevo jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_actor AND rol='admin' AND activo) THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_auth_id IS NULL OR p_numero IS NULL OR p_numero !~ '^[0-9]{1,30}$' OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 OR p_rol IS NULL OR p_rol NOT IN ('admin','produccion','logistica') THEN RAISE EXCEPTION 'Datos del usuario invalidos.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_auth_id AND email=p_numero||'@orbiloq.local') THEN RAISE EXCEPTION 'La cuenta de acceso no corresponde al numero de usuario.'; END IF;
 SELECT to_jsonb(u) INTO nuevo FROM public.usuarios u WHERE auth_id=p_auth_id AND numero_usuario=p_numero;
 IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_auth_id OR numero_usuario=p_numero) THEN RAISE EXCEPTION 'La cuenta o numero de usuario ya existe.'; END IF;
 INSERT INTO public.usuarios(numero_usuario,nombre,rol,auth_id,email,activo) VALUES(p_numero,trim(p_nombre),p_rol,p_auth_id,p_numero||'@orbiloq.local',true) RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(p_actor,'usuarios',(nuevo->>'id')::uuid,NULL,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_registrar(uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_registrar(uuid,uuid,text,text,text) TO service_role;

-- Reintentar un alta interrumpida solo recupera cuentas creadas por esta funcion.
CREATE OR REPLACE FUNCTION public.admin_usuario_alta_pendiente(p_numero text) RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT id FROM auth.users WHERE email=p_numero||'@orbiloq.local'
 AND raw_app_meta_data->>'orbiloq_alta_catalogo'='true'
 AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.users.id);
$$;
REVOKE ALL ON FUNCTION public.admin_usuario_alta_pendiente(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_alta_pendiente(text) TO service_role;

REVOKE ALL ON FUNCTION public.admin_catalogos_listar(text),public.admin_catalogos_guardar(text,uuid,text,boolean,text),public.admin_usuario_guardar(uuid,text,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_catalogos_listar(text),public.admin_catalogos_guardar(text,uuid,text,boolean,text),public.admin_usuario_guardar(uuid,text,text,boolean,text) TO authenticated;

-- Evitar saltarse las validaciones con escrituras directas.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.usuarios,public.ubicaciones,public.causales_devolucion,public.personal_logistica,public.personal_produccion,public.personal_aliados FROM authenticated,anon;

-- Una cuenta desactivada no puede leer ni escribir datos con un JWT aun vigente.
DO $politicas$ DECLARE t record; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
   EXECUTE format('DROP POLICY IF EXISTS wms_requiere_cuenta_activa ON public.%I',t.tablename);
   EXECUTE format('CREATE POLICY wms_requiere_cuenta_activa ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.wms_cuenta_activa()) WITH CHECK (public.wms_cuenta_activa())',t.tablename);
 END LOOP;
 FOR t IN SELECT viewname FROM pg_views WHERE schemaname='public' LOOP
   EXECUTE format('ALTER VIEW public.%I SET (security_invoker=true)',t.viewname);
 END LOOP;
END $politicas$;

-- Altas rapidas conservan su uso operativo, pero nunca reactivan duplicados.
DO $personal$ DECLARE tabla text; funcion text; BEGIN
 FOREACH tabla IN ARRAY ARRAY['personal_logistica','personal_produccion','personal_aliados'] LOOP
   funcion:=CASE tabla WHEN 'personal_aliados' THEN 'agregar_personal_aliado' ELSE 'agregar_'||tabla END;
   EXECUTE format($ddl$
   CREATE OR REPLACE FUNCTION public.%I(p_nombre text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $body$
   DECLARE n text:=trim(p_nombre); v jsonb; BEGIN
     IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
     IF coalesce(length(n),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Indica un nombre de 1 a 150 caracteres.'; END IF;
     LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE;
     SELECT to_jsonb(t) INTO v FROM public.%I t WHERE lower(trim(nombre))=lower(n) ORDER BY activo DESC,id LIMIT 1;
     IF v IS NOT NULL THEN
       IF NOT (v->>'activo')::boolean THEN RAISE EXCEPTION 'Ese nombre esta inactivo. Solicita su revision al administrador.'; END IF;
       RETURN v;
     END IF;
     INSERT INTO public.%I(nombre) VALUES(n) RETURNING to_jsonb(%I.*) INTO v;
     INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),%L,(v->>'id')::uuid,NULL,v);
     RETURN v;
   END $body$;
   $ddl$,funcion,tabla,tabla,tabla,tabla,tabla);
   EXECUTE format('REVOKE ALL ON FUNCTION public.%I(text) FROM PUBLIC,anon',funcion);
   EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(text) TO authenticated',funcion);
 END LOOP;
END $personal$;

-- Las RPC antiguas tambien verifican la cuenta en el servidor, no solo la UI.
DO $rpc$ DECLARE f record; ddl text; guardia text; BEGIN
 FOR f IN SELECT p.oid,p.proname, p.oid::regprocedure firma,pg_get_function_arguments(p.oid) args
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN ('crear_lote','recibir_lote_item','cerrar_lote_item_con_faltante','despachar','registrar_no_conforme','liberar_no_conforme','enviar_no_conforme_aliado','liberar_no_conforme_aliado','registrar_sobrante','resolver_sobrante','importar_ordenes_produccion','importar_fechas_esperadas') LOOP
   ddl:=pg_get_functiondef(f.oid);
   IF strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN
     guardia:=E'BEGIN\n -- ORBILOQ_CUENTA_V60\n IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION ''Cuenta inactiva o sin acceso.'' USING ERRCODE=''42501''; END IF;\n';
     IF f.proname IN ('crear_lote','liberar_no_conforme','enviar_no_conforme_aliado','liberar_no_conforme_aliado') THEN
       guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN (''admin'',''produccion'')) THEN RAISE EXCEPTION ''Esta operacion requiere Produccion o Administrador.'' USING ERRCODE=''42501''; END IF;\n';
     ELSIF f.proname NOT LIKE 'importar_%' THEN
       guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN (''admin'',''logistica'')) THEN RAISE EXCEPTION ''Esta operacion requiere Logistica o Administrador.'' USING ERRCODE=''42501''; END IF;\n';
     END IF;
     IF f.proname LIKE 'importar_%' THEN guardia:=guardia||E' IF NOT public.admin_es_admin() THEN RAISE EXCEPTION ''Acceso exclusivo del administrador.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_ubicacion_id %' THEN guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN RAISE EXCEPTION ''Estante inactivo o inexistente.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_por %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_por_logistica %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por_logistica)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_de_produccion %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_produccion WHERE lower(trim(nombre))=lower(trim(p_recibido_de_produccion)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_persona_aliado_entrega %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_entrega)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_persona_aliado_libera %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_libera)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     ddl:=regexp_replace(ddl,E'\\mbegin\\M',guardia,'i');
     IF strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN RAISE EXCEPTION 'No se pudo proteger %.',f.firma; END IF;
     EXECUTE ddl;
   END IF;
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.firma);
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.firma);
 END LOOP;
END $rpc$;
DO $$ DECLARE tabla text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
   FOREACH tabla IN ARRAY ARRAY['usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados'] LOOP
     IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=tabla) THEN
       EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',tabla);
     END IF;
   END LOOP;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
