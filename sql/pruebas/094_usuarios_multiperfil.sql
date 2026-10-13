-- SOLO ORBILOQ-DEV. Ejecutar después de 093. Conserva cuentas, accesos e historial.
-- Después actualizar admin-crear-usuario (index.ts y handler.mjs) en DEV.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.le_importar_clientes_internacionales(jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere migracion 093'; END IF;
END $$;
-- NULL conserva exactamente el rol anterior, sin reescribir cuentas históricas.
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS roles text[];
CREATE TEMP TABLE perfiles_usuarios_previos ON COMMIT DROP AS SELECT to_jsonb(u) fila FROM public.usuarios u;
CREATE OR REPLACE FUNCTION public.usuario_roles_normalizar(p_roles text[]) RETURNS text[]
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE resultado text[];
BEGIN
 IF p_roles IS NULL OR cardinality(p_roles) NOT BETWEEN 1 AND 6 OR array_ndims(p_roles)<>1
    OR array_position(p_roles,NULL) IS NOT NULL
    OR NOT p_roles <@ ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia']::text[] THEN
  RAISE EXCEPTION 'Selecciona al menos un perfil valido.';
 END IF;
 SELECT array_agg(r ORDER BY n) INTO resultado FROM unnest(ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia']) WITH ORDINALITY AS t(r,n) WHERE r=ANY(p_roles);
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.usuario_roles_normalizar(text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.usuario_roles_normalizar(text[]) TO authenticated,service_role;
ALTER TABLE public.usuarios DROP CONSTRAINT IF EXISTS usuarios_roles_check;
-- Admin siempre es principal. Gerencia es principal únicamente si no hay perfiles operativos.
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_roles_check CHECK (
 roles IS NULL OR (roles=public.usuario_roles_normalizar(roles) AND rol=roles[1])
);

-- Actualiza solamente predicados de autorización de las RPC instaladas.
-- Se conservan sus firmas, grants y el resto de validaciones de cada operación.
DO $$ DECLARE r record; d text; nuevo text;
 patron text := $p$\mrol\s+IN\s*\(('(?:admin|produccion|logistica|despacho|seguimiento|gerencia)'(?:\s*,\s*'(?:admin|produccion|logistica|despacho|seguimiento|gerencia)')*)\)$p$;
BEGIN
 FOR r IN SELECT p.oid,p.proname,p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc ~ patron LOOP
  IF r.proname NOT IN (
   'crear_lote','enviar_no_conforme_aliado','liberar_no_conforme','liberar_no_conforme_aliado',
   'recibir_lote_item','cerrar_lote_item_con_faltante','registrar_no_conforme','registrar_sobrante','resolver_sobrante','validar_stock_no_conforme',
   'despachar_oc','despachar_oc_empaques','despachar_oc_prendas_empaques','historial_despachos_oc','empaques_listar',
   'le_acceso','seguimiento_acceso','wms_cuenta_operativa','puede_ver_dashboards','kardex_historico'
  ) THEN RAISE EXCEPTION 'Revisar predicado de perfiles en % antes de migrar',r.proname; END IF;
  d:=pg_get_functiondef(r.oid);
  nuevo:=regexp_replace(d,patron,'(coalesce(roles,ARRAY[rol]) && ARRAY[\1]::text[])','g');
  EXECUTE nuevo;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_guardar_roles(p_id uuid,p_nombre text,p_roles text[],p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; perfiles text[];
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 perfiles:=public.usuario_roles_normalizar(p_roles);
 SELECT to_jsonb(u) INTO anterior FROM public.usuarios u WHERE id=p_id;
 IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'La cuenta cambio. Actualiza la lista antes de guardar.'; END IF;
 IF p_activo IS NULL OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Nombre o estado invalido.'; END IF;
 IF (anterior->>'auth_id')::uuid=auth.uid() AND NOT p_activo THEN RAISE EXCEPTION 'No puedes desactivar tu propia cuenta.'; END IF;
 IF (anterior->>'activo')::boolean AND anterior->>'rol'='admin' AND (NOT p_activo OR NOT 'admin'=ANY(perfiles))
    AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE id<>p_id AND rol='admin' AND activo AND auth_id IS NOT NULL) THEN RAISE EXCEPTION 'Debe permanecer al menos un administrador activo con acceso.'; END IF;
 UPDATE public.usuarios SET nombre=trim(p_nombre),rol=perfiles[1],roles=perfiles,activo=p_activo WHERE id=p_id RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),'usuarios',p_id,anterior,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text) TO authenticated;

-- Clientes antiguos pueden cambiar nombre/estado, pero nunca descartar perfiles extra sin verlo.
CREATE OR REPLACE FUNCTION public.admin_usuario_guardar(p_id uuid,p_nombre text,p_rol text,p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE perfiles text[]; principal text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 SELECT roles,rol INTO perfiles,principal FROM public.usuarios WHERE id=p_id;
 IF cardinality(perfiles)>1 AND p_rol IS DISTINCT FROM principal THEN RAISE EXCEPTION 'Actualiza la aplicación para editar varios perfiles.'; END IF;
 RETURN public.admin_usuario_guardar_roles(p_id,p_nombre,CASE WHEN p_rol=principal THEN coalesce(perfiles,ARRAY[p_rol]) ELSE ARRAY[p_rol] END,p_activo,p_version);
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_registrar_roles(p_actor uuid,p_auth_id uuid,p_numero text,p_nombre text,p_roles text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE nuevo jsonb; perfiles text[];
BEGIN
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_actor AND rol='admin' AND activo) THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 perfiles:=public.usuario_roles_normalizar(p_roles);
 IF p_auth_id IS NULL OR p_numero IS NULL OR p_numero !~ '^[0-9]{1,30}$' OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Datos del usuario invalidos.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_auth_id AND email=p_numero||'@orbiloq.local') THEN RAISE EXCEPTION 'La cuenta de acceso no corresponde al numero de usuario.'; END IF;
 SELECT to_jsonb(u) INTO nuevo FROM public.usuarios u WHERE auth_id=p_auth_id AND numero_usuario=p_numero;
 IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_auth_id OR numero_usuario=p_numero) THEN RAISE EXCEPTION 'La cuenta o numero de usuario ya existe.'; END IF;
 INSERT INTO public.usuarios(numero_usuario,nombre,rol,roles,auth_id,email,activo) VALUES(p_numero,trim(p_nombre),perfiles[1],perfiles,p_auth_id,p_numero||'@orbiloq.local',true) RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(p_actor,'usuarios',(nuevo->>'id')::uuid,NULL,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_registrar_roles(uuid,uuid,text,text,text[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_registrar_roles(uuid,uuid,text,text,text[]) TO service_role;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.usuarios FROM authenticated,anon;
DO $$ BEGIN
 IF EXISTS(SELECT fila FROM perfiles_usuarios_previos EXCEPT ALL SELECT to_jsonb(u) FROM public.usuarios u)
 OR EXISTS(SELECT to_jsonb(u) FROM public.usuarios u EXCEPT ALL SELECT fila FROM perfiles_usuarios_previos) THEN
  RAISE EXCEPTION 'La migración no debe modificar cuentas existentes';
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
