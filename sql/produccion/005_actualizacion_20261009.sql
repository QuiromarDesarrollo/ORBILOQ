-- CANDIDATO: ensayar y revisar antes de aplicar. No ejecutar junto con 002.
-- Destino previsto: cxrflhgnxvomcvxzugda. Sin datos ni catálogos DEV.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regclass('public.empaques') IS NOT NULL THEN RAISE EXCEPTION 'Actualización ya iniciada/instalada; detener'; END IF;
 IF to_regclass('public.clientes') IS NULL OR to_regclass('public.admin_correcciones') IS NULL THEN RAISE EXCEPTION 'Baseline incorrecto'; END IF;
END $$;
DO $baseline$ BEGIN
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_guardar(text,uuid,text,boolean,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28d15223e73f3b181d881e592f7b1cda' THEN RAISE EXCEPTION 'Función cambió: admin_catalogos_guardar'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_listar(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '15ca446753397c8af4df941f3a90ab8b' THEN RAISE EXCEPTION 'Función cambió: admin_catalogos_listar'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_contexto_edicion(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM '92eed44998dfea36a342ff6f55f06d71' THEN RAISE EXCEPTION 'Función cambió: admin_contexto_edicion'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '8b091656c7ddd5b9329e63def8cbdb72' THEN RAISE EXCEPTION 'Función cambió: admin_editar_kardex'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_eliminar_linea(uuid,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '058c432424ea51fda0232a875cdec68d' THEN RAISE EXCEPTION 'Función cambió: admin_eliminar_linea'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_es_admin()')), E'\r\n', E'\n')) IS DISTINCT FROM '5ce1b98b713dde03a81a64f4dfa459a9' THEN RAISE EXCEPTION 'Función cambió: admin_es_admin'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_exportar_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '28dda8245e0bba92af1167368d9f9f8a' THEN RAISE EXCEPTION 'Función cambió: admin_exportar_kardex'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_importar_kardex(text,text,jsonb,text,boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e39d438c21344efac59b39473d5872f7' THEN RAISE EXCEPTION 'Función cambió: admin_importar_kardex'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_pagina(text,text,timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd6222e6de38dcbd5f88864282df81323' THEN RAISE EXCEPTION 'Función cambió: admin_reporte_pagina'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_resumen()')), E'\r\n', E'\n')) IS DISTINCT FROM 'cc9a40ea24ce75bc900391dc28421f08' THEN RAISE EXCEPTION 'Función cambió: admin_reporte_resumen'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_alta_pendiente(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '58cd4920a2523e673613349dc15d0be1' THEN RAISE EXCEPTION 'Función cambió: admin_usuario_alta_pendiente'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_guardar(uuid,text,text,boolean,text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'ad3d6c019fe78a6d744b905df88ef5f6' THEN RAISE EXCEPTION 'Función cambió: admin_usuario_guardar'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_registrar(uuid,uuid,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f8c71d43489eade1601a7060a65eef04' THEN RAISE EXCEPTION 'Función cambió: admin_usuario_registrar'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_version_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '15c1d98c07bf0877b8b91023c7e90a84' THEN RAISE EXCEPTION 'Función cambió: admin_version_kardex'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_aliado(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '523acc2c48b06dcd00ca6f614b6c81d8' THEN RAISE EXCEPTION 'Función cambió: agregar_personal_aliado'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_logistica(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '414235408a8b48175489cf86c9e03cab' THEN RAISE EXCEPTION 'Función cambió: agregar_personal_logistica'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_produccion(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f67144e32633c38788ed2f9ffb4434a6' THEN RAISE EXCEPTION 'Función cambió: agregar_personal_produccion'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.cerrar_lote_item_con_faltante(uuid,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '450b8fc998509b50dda4d0b8c42181e2' THEN RAISE EXCEPTION 'Función cambió: cerrar_lote_item_con_faltante'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.crear_lote(jsonb,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '60e88726eb944ab8a3bfd95188de4bde' THEN RAISE EXCEPTION 'Función cambió: crear_lote'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar(uuid,integer,uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fdf4c441ccc75070926e9f92b41b6180' THEN RAISE EXCEPTION 'Función cambió: despachar'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc(text,text,text,jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b04b81bfbd62ad9fe6cf6747c264511a' THEN RAISE EXCEPTION 'Función cambió: despachar_oc'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.enviar_no_conforme_aliado(uuid,integer,uuid,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a7128d516cbb2e7e874f53b1798ca548' THEN RAISE EXCEPTION 'Función cambió: enviar_no_conforme_aliado'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_oc(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '7b5a8e856223e1d176a37681183421f3' THEN RAISE EXCEPTION 'Función cambió: historial_despachos_oc'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_fechas_esperadas(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '3f476b6f8a61d837a20f1c6e18aa1847' THEN RAISE EXCEPTION 'Función cambió: importar_fechas_esperadas'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_ordenes_produccion(jsonb,jsonb,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b86b1facd9c4e60212094ed8f16ae230' THEN RAISE EXCEPTION 'Función cambió: importar_ordenes_produccion'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid,integer,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '1574f52aa971397c2d1f008eddfed0cf' THEN RAISE EXCEPTION 'Función cambió: liberar_no_conforme'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid,integer,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28ed6cc883e2117b4685add1108e35a6' THEN RAISE EXCEPTION 'Función cambió: liberar_no_conforme'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme_aliado(uuid,integer,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28daa411ac4d996db0790205e2deda97' THEN RAISE EXCEPTION 'Función cambió: liberar_no_conforme_aliado'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid,integer,uuid,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '2b4b2166522e7b33c6b96a9b5ace3b5a' THEN RAISE EXCEPTION 'Función cambió: recibir_lote_item'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid,integer,uuid,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e3ac09f616f60ec3abd307cefa103a65' THEN RAISE EXCEPTION 'Función cambió: recibir_lote_item'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid,integer,uuid,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '3df89a7e6ddca69f3755fc1108d00974' THEN RAISE EXCEPTION 'Función cambió: registrar_no_conforme'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid,integer,uuid,text,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '7c89bd07afe46260f391c480e2c8d42a' THEN RAISE EXCEPTION 'Función cambió: registrar_no_conforme'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_sobrante(uuid,uuid,integer,text,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '2eb426455a40dbabc2db9ae658ef5e1a' THEN RAISE EXCEPTION 'Función cambió: registrar_sobrante'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.resolver_sobrante(uuid,text)')), E'\r\n', E'\n')) IS DISTINCT FROM '365787e186500ae8f3f326b59271d3ae' THEN RAISE EXCEPTION 'Función cambió: resolver_sobrante'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_cuenta_activa()')), E'\r\n', E'\n')) IS DISTINCT FROM '22ed4e3986b546d43054c2014765043f' THEN RAISE EXCEPTION 'Función cambió: wms_cuenta_activa'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_nombre_actor()')), E'\r\n', E'\n')) IS DISTINCT FROM 'dafe4b70701bdf326cdf2bf0edc80652' THEN RAISE EXCEPTION 'Función cambió: wms_nombre_actor'; END IF;
END $baseline$;

-- Captura todas las columnas originales y filas operativas; aborta si cambia alguna.
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY, columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text, fila jsonb) ON COMMIT DROP;
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  -- Auth pertenece al servicio gestionado: se compara, pero no se bloquea.
  IF t.nspname<>'auth' THEN
   EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname);
  END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;

-- Adaptación 065_empaques_despacho.sql




SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

CREATE TABLE public.empaques (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 categoria text NOT NULL CHECK (categoria IN ('CAJA','BOLSA')),
 nombre text NOT NULL CHECK (length(trim(nombre)) BETWEEN 1 AND 150),
 largo_cm numeric NOT NULL CHECK (largo_cm > 0 AND largo_cm <= 100000),
 ancho_cm numeric NOT NULL CHECK (ancho_cm > 0 AND ancho_cm <= 100000),
 alto_cm numeric NOT NULL CHECK (alto_cm > 0 AND alto_cm <= 100000),
 peso_neto_kg numeric NOT NULL CHECK (peso_neto_kg > 0 AND peso_neto_kg <= 100000),
 peso_bruto_kg numeric NOT NULL CHECK (peso_bruto_kg >= peso_neto_kg AND peso_bruto_kg <= 100000),
 activo boolean NOT NULL DEFAULT true,
 creado_en timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX empaques_nombre_idx ON public.empaques(lower(trim(nombre)));
ALTER TABLE public.empaques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.empaques FROM PUBLIC,anon,authenticated;

ALTER TABLE public.despachos_oc ADD COLUMN empaques jsonb;
ALTER TABLE public.despachos_oc ADD COLUMN empaques_pedido jsonb;

CREATE FUNCTION public.empaques_listar(p_todos boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN
   RAISE EXCEPTION 'Acceso exclusivo de Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 IF p_todos IS TRUE AND NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('version',md5(to_jsonb(e)::text)) ORDER BY nombre,id),'[]') INTO resultado
 FROM public.empaques e WHERE e.activo OR p_todos IS TRUE;
 RETURN resultado;
END $$;

CREATE FUNCTION public.admin_empaque_guardar(p_id uuid,p_version text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.empaques IN SHARE ROW EXCLUSIVE MODE;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object'
 OR p_datos->>'categoria' IS NULL OR p_datos->>'categoria' NOT IN ('CAJA','BOLSA')
 OR coalesce(length(trim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 150
 OR jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Datos del empaque invalidos.'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['largo_cm','ancho_cm','alto_cm','peso_neto_kg','peso_bruto_kg']) k
   WHERE jsonb_typeof(p_datos->k) IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Medidas y pesos deben ser numeros.'; END IF;
 IF p_id IS NOT NULL THEN
   SELECT to_jsonb(e) INTO anterior FROM public.empaques e WHERE id=p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza la lista.'; END IF;
   UPDATE public.empaques SET nombre=trim(p_datos->>'nombre'),categoria=p_datos->>'categoria',
     largo_cm=(p_datos->>'largo_cm')::numeric,ancho_cm=(p_datos->>'ancho_cm')::numeric,alto_cm=(p_datos->>'alto_cm')::numeric,
     peso_neto_kg=(p_datos->>'peso_neto_kg')::numeric,peso_bruto_kg=(p_datos->>'peso_bruto_kg')::numeric,activo=(p_datos->>'activo')::boolean
   WHERE id=p_id RETURNING to_jsonb(empaques.*) INTO nuevo;
 ELSE
   INSERT INTO public.empaques(nombre,categoria,largo_cm,ancho_cm,alto_cm,peso_neto_kg,peso_bruto_kg,activo)
   VALUES(trim(p_datos->>'nombre'),p_datos->>'categoria',(p_datos->>'largo_cm')::numeric,(p_datos->>'ancho_cm')::numeric,
     (p_datos->>'alto_cm')::numeric,(p_datos->>'peso_neto_kg')::numeric,(p_datos->>'peso_bruto_kg')::numeric,(p_datos->>'activo')::boolean)
   RETURNING to_jsonb(empaques.*) INTO nuevo;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues)
 VALUES(auth.uid(),'empaques',(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;


CREATE FUNCTION public.despachar_oc_empaques(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE previo public.despachos_oc%rowtype; e public.empaques%rowtype; r jsonb;
 actor uuid; copia jsonb:='[]'; resultado jsonb; cantidad integer;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 SELECT id INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
 IF actor IS NULL THEN RAISE EXCEPTION 'Acceso exclusivo de Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.despachos_oc WHERE solicitud=p_solicitud;
 IF FOUND THEN
   IF previo.actor_id<>actor OR previo.empaques_pedido IS DISTINCT FROM p_empaques THEN RAISE EXCEPTION 'Solicitud usada con otros empaques.'; END IF;
   RETURN public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Selecciona empaques.'; END IF;
 IF jsonb_array_length(p_empaques) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona de 1 a 100 tipos de empaque.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x GROUP BY x->>'empaque_id' HAVING count(*)>1) THEN
   RAISE EXCEPTION 'No repitas el mismo empaque; indica su cantidad.'; END IF;
 LOCK TABLE public.empaques IN SHARE MODE;
 FOR r IN SELECT value FROM jsonb_array_elements(p_empaques) LOOP
   IF coalesce(r->>'cantidad','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'La cantidad de empaques debe ser entera entre 1 y 999999.'; END IF;
   cantidad:=(r->>'cantidad')::integer;
   SELECT * INTO e FROM public.empaques WHERE id=(r->>'empaque_id')::uuid AND activo;
   IF NOT FOUND THEN RAISE EXCEPTION 'Empaque inactivo o inexistente. Actualiza el catalogo.'; END IF;
   IF r->>'version' IS DISTINCT FROM md5(to_jsonb(e)::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza antes de confirmar.'; END IF;
   copia:=copia||jsonb_build_array((to_jsonb(e)-'activo'-'creado_en')||jsonb_build_object('cantidad',cantidad));
 END LOOP;
 resultado:=public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 UPDATE public.despachos_oc SET empaques=copia,empaques_pedido=p_empaques WHERE id=(resultado->>'id')::uuid;
 RETURN resultado||jsonb_build_object('empaques',copia);
END $$;

CREATE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb; resultado jsonb;
BEGIN
 -- La funcion existente verifica la cuenta activa y su rol.
 filas:=public.historial_despachos_oc(p_despues);
 SELECT coalesce(jsonb_agg(x.value||jsonb_build_object('empaques',d.empaques) ORDER BY x.value->>'registro'),'[]') INTO resultado
 FROM jsonb_array_elements(filas) x LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_oc_id')::uuid;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.empaques_listar(boolean),public.admin_empaque_guardar(uuid,text,jsonb),
 public.despachar_oc_empaques(text,text,text,jsonb,jsonb),public.historial_despachos_empaques(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.empaques_listar(boolean),public.admin_empaque_guardar(uuid,text,jsonb),
 public.despachar_oc_empaques(text,text,text,jsonb,jsonb),public.historial_despachos_empaques(text) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 066_prendas_por_empaque.sql





SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

CREATE OR REPLACE FUNCTION public.despachar_oc_prendas_empaques(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE previo public.despachos_oc%rowtype; e public.empaques%rowtype; r jsonb;
 actor uuid; copia jsonb:='[]'; resultado jsonb; cantidad integer;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 SELECT id INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
 IF actor IS NULL THEN RAISE EXCEPTION 'Acceso exclusivo de Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.despachos_oc WHERE solicitud=p_solicitud;
 IF FOUND THEN
   IF previo.actor_id<>actor OR previo.empaques_pedido IS DISTINCT FROM p_empaques THEN RAISE EXCEPTION 'Solicitud usada con otros empaques.'; END IF;
   RETURN public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Selecciona empaques.'; END IF;
 IF jsonb_array_length(p_empaques) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona de 1 a 100 tipos de empaque.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x GROUP BY x->>'item_id',x->>'empaque_id' HAVING count(*)>1) THEN
   RAISE EXCEPTION 'No repitas el mismo empaque; indica su cantidad.'; END IF;
 IF jsonb_typeof(p_lineas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Retiros invalidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x WHERE nullif(x->>'item_id','') IS NULL OR coalesce(x->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Indica la prenda y su cantidad por empaque.'; END IF;
 IF EXISTS(
   SELECT 1 FROM
   (SELECT (x->>'item_id')::uuid id,sum((x->>'cantidad')::bigint) n FROM jsonb_array_elements(p_empaques) x GROUP BY 1) asignado
   FULL JOIN
   (SELECT (x->>'item_id')::uuid id,sum((x->>'cantidad')::bigint) n FROM jsonb_array_elements(p_lineas) x GROUP BY 1) l USING(id)
   WHERE asignado.n IS DISTINCT FROM l.n
 ) THEN RAISE EXCEPTION 'Las prendas asignadas a empaques deben coincidir con el despacho de cada referencia y talla.'; END IF;
 LOCK TABLE public.empaques IN SHARE MODE;
 FOR r IN SELECT value FROM jsonb_array_elements(p_empaques) LOOP
   IF coalesce(r->>'cantidad','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'La cantidad de prendas debe ser entera entre 1 y 999999.'; END IF;
   cantidad:=(r->>'cantidad')::integer;
   SELECT * INTO e FROM public.empaques WHERE id=(r->>'empaque_id')::uuid AND activo;
   IF NOT FOUND THEN RAISE EXCEPTION 'Empaque inactivo o inexistente. Actualiza el catalogo.'; END IF;
   IF r->>'version' IS DISTINCT FROM md5(to_jsonb(e)::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza antes de confirmar.'; END IF;
   copia:=copia||jsonb_build_array((to_jsonb(e)-'activo'-'creado_en')||jsonb_build_object('cantidad',cantidad,'contenido','prendas','item_id',r->>'item_id','op',(SELECT op.numero_op FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE io.id=(r->>'item_id')::uuid),'talla',(SELECT talla FROM public.items_orden WHERE id=(r->>'item_id')::uuid)));
 END LOOP;
 resultado:=public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 UPDATE public.despachos_oc SET empaques=copia,empaques_pedido=p_empaques WHERE id=(resultado->>'id')::uuid;
 RETURN resultado||jsonb_build_object('empaques',copia);
END $$;

REVOKE ALL ON FUNCTION public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 067_empaques_repetidos.sql





SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

CREATE OR REPLACE FUNCTION public.despachar_oc_prendas_empaques(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE previo public.despachos_oc%rowtype; e public.empaques%rowtype; r jsonb;
 actor uuid; copia jsonb:='[]'; resultado jsonb; cantidad integer;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 SELECT id INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
 IF actor IS NULL THEN RAISE EXCEPTION 'Acceso exclusivo de Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.despachos_oc WHERE solicitud=p_solicitud;
 IF FOUND THEN
   IF previo.actor_id<>actor OR previo.empaques_pedido IS DISTINCT FROM p_empaques THEN RAISE EXCEPTION 'Solicitud usada con otros empaques.'; END IF;
   RETURN public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Selecciona empaques.'; END IF;
 IF jsonb_array_length(p_empaques) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona de 1 a 100 empaques.'; END IF;

 IF jsonb_typeof(p_lineas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Retiros invalidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x WHERE nullif(x->>'item_id','') IS NULL OR coalesce(x->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Indica la prenda y su cantidad por empaque.'; END IF;
 IF EXISTS(
   SELECT 1 FROM
   (SELECT (x->>'item_id')::uuid id,sum((x->>'cantidad')::bigint) n FROM jsonb_array_elements(p_empaques) x GROUP BY 1) asignado
   FULL JOIN
   (SELECT (x->>'item_id')::uuid id,sum((x->>'cantidad')::bigint) n FROM jsonb_array_elements(p_lineas) x GROUP BY 1) l USING(id)
   WHERE asignado.n IS DISTINCT FROM l.n
 ) THEN RAISE EXCEPTION 'Las prendas asignadas a empaques deben coincidir con el despacho de cada referencia y talla.'; END IF;
 LOCK TABLE public.empaques IN SHARE MODE;
 FOR r IN SELECT value FROM jsonb_array_elements(p_empaques) LOOP
   IF coalesce(r->>'cantidad','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'La cantidad de prendas debe ser entera entre 1 y 999999.'; END IF;
   cantidad:=(r->>'cantidad')::integer;
   SELECT * INTO e FROM public.empaques WHERE id=(r->>'empaque_id')::uuid AND activo;
   IF NOT FOUND THEN RAISE EXCEPTION 'Empaque inactivo o inexistente. Actualiza el catalogo.'; END IF;
   IF r->>'version' IS DISTINCT FROM md5(to_jsonb(e)::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza antes de confirmar.'; END IF;
   copia:=copia||jsonb_build_array((to_jsonb(e)-'activo'-'creado_en')||jsonb_build_object('cantidad',cantidad,'contenido','prendas','item_id',r->>'item_id','op',(SELECT op.numero_op FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE io.id=(r->>'item_id')::uuid),'talla',(SELECT talla FROM public.items_orden WHERE id=(r->>'item_id')::uuid)));
 END LOOP;
 resultado:=public.despachar_oc(p_solicitud,p_cliente,p_oc,p_lineas);
 UPDATE public.despachos_oc SET empaques=copia,empaques_pedido=p_empaques WHERE id=(resultado->>'id')::uuid;
 RETURN resultado||jsonb_build_object('empaques',copia);
END $$;

REVOKE ALL ON FUNCTION public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 068_validar_entregado_recibido.sql



SET LOCAL lock_timeout = '5s';
DO $migracion$
DECLARE
  definicion text;
  ancla text := 'v_r := (d->>''recibido'')::bigint; v_d := (d->>''despachado'')::bigint;';
  validacion text := $regla$
    -- validacion_entregado_recibido_v68
    IF p_campo = 'producido' AND v_p < v_r THEN
      RAISE EXCEPTION 'No puedes dejar lo entregado por Produccion en % prendas: Logistica ya tiene % recibidas. Revisa las recepciones relacionadas antes de corregir la entrega.', v_p, v_r;
    END IF;
$regla$;
BEGIN
  
  
  SELECT pg_get_functiondef(to_regprocedure('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)')) INTO definicion;
  IF definicion IS NULL THEN RAISE EXCEPTION 'No existe el RPC de edicion administrativa.'; END IF;
  IF position('validacion_entregado_recibido_v68' in definicion)>0 THEN RETURN; END IF;
  IF (length(definicion)-length(replace(definicion,ancla,''))) / length(ancla) <> 1
     OR position('IN SHARE ROW EXCLUSIVE MODE' in definicion)=0 THEN
    RAISE EXCEPTION 'El RPC cambio; detener y revisar antes de aplicar la validacion.';
  END IF;
  EXECUTE replace(definicion,ancla,ancla || validacion);
END $migracion$;
NOTIFY pgrst,'reload schema';


-- Adaptación 070_separar_bodega_despacho.sql




SET LOCAL lock_timeout = '5s';
DO $migracion$
DECLARE r record; definicion text; vieja text; nueva text; veces integer;
BEGIN
 
 
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
 ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
   CHECK (rol IN ('admin','produccion','logistica','despacho'));

 -- Cambia solo los controles de rol, conservando las validaciones y auditoria.
 FOR r IN SELECT * FROM (VALUES
   ('public.despachar_oc(text,text,text,jsonb)',2,false),
   ('public.despachar_oc_empaques(text,text,text,jsonb,jsonb)',1,false),
   ('public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb)',1,false),
   ('public.historial_despachos_oc(text)',1,false),
   ('public.empaques_listar(boolean)',1,false),
   ('public.admin_usuario_guardar(uuid,text,text,boolean,text)',1,true),
   ('public.admin_usuario_registrar(uuid,uuid,text,text,text)',1,true)
 ) AS funciones(firma,esperadas,administracion) LOOP
   SELECT pg_get_functiondef(to_regprocedure(r.firma)) INTO definicion;
   IF definicion IS NULL THEN RAISE EXCEPTION 'Falta la funcion %. Detener y revisar.',r.firma; END IF;
   vieja:=CASE WHEN r.administracion THEN '(''admin'',''produccion'',''logistica'')' ELSE '(''admin'',''logistica'')' END;
   nueva:=CASE WHEN r.administracion THEN '(''admin'',''produccion'',''logistica'',''despacho'')' ELSE '(''admin'',''despacho'')' END;
   veces:=(length(definicion)-length(replace(definicion,vieja,'')))/length(vieja);
   IF veces=0 AND (length(definicion)-length(replace(definicion,nueva,'')))/length(nueva)=r.esperadas THEN
     CONTINUE; -- ya aplicado
   END IF;
   IF veces<>r.esperadas THEN RAISE EXCEPTION 'La funcion % cambio; revisar sus permisos.',r.firma; END IF;
   definicion:=replace(definicion,vieja,nueva);
   IF NOT r.administracion THEN
     definicion:=replace(replace(definicion,'Logística o Administrador','Despacho o Administrador'),'Logistica o Administrador','Despacho o Administrador');
   END IF;
   EXECUTE definicion;
 END LOOP;
END $migracion$;



REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
DO $$ DECLARE r record; d text; BEGIN
 FOR r IN SELECT * FROM (VALUES
   ('public.crear_lote(jsonb,text,text)','produccion'),
   ('public.enviar_no_conforme_aliado(uuid,integer,uuid,text,text,text)','produccion'),
   ('public.liberar_no_conforme(uuid,integer,text,text)','produccion'),
   ('public.liberar_no_conforme(uuid,integer,text,text,text)','produccion'),
   ('public.liberar_no_conforme_aliado(uuid,integer,text,text,text)','produccion'),
   ('public.recibir_lote_item(uuid,integer,uuid,text)','logistica'),
   ('public.recibir_lote_item(uuid,integer,uuid,text,text)','logistica'),
   ('public.cerrar_lote_item_con_faltante(uuid,text)','logistica'),
   ('public.registrar_no_conforme(uuid,integer,uuid,text,text)','logistica'),
   ('public.registrar_no_conforme(uuid,integer,uuid,text,text,text)','logistica'),
   ('public.registrar_sobrante(uuid,uuid,integer,text,text)','logistica'),
   ('public.resolver_sobrante(uuid,text)','logistica'),
   ('public.importar_fechas_esperadas(jsonb)','admin'),
   ('public.importar_ordenes_produccion(jsonb,jsonb,text,text,text)','admin')
 ) AS f(firma,rol) LOOP
   SELECT pg_get_functiondef(to_regprocedure(r.firma)) INTO d;
   IF d IS NULL OR position('public.wms_cuenta_activa()' in d)=0
      OR (r.rol='admin' AND position('public.admin_es_admin()' in d)=0)
      OR (r.rol<>'admin' AND position('rol IN (''admin'','''||r.rol||''')' in d)=0) THEN
     RAISE EXCEPTION 'No se verificaron los controles de acceso de %',r.firma;
   END IF;
   EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER',r.firma);
   EXECUTE format('ALTER FUNCTION %s SET search_path=pg_catalog,public,pg_temp',r.firma);
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',r.firma);
 END LOOP;
END $$;



REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
 public.ordenes_produccion, public.items_orden, public.movimientos,
 public.lotes, public.lote_items, public.devoluciones_produccion,
 public.liberaciones_no_conforme, public.no_conformes_aliados,
 public.liberaciones_aliados, public.sobrantes_bodega, public.despachos_oc
 FROM anon, authenticated;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind='v'
 LOOP
   EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON public.%I FROM anon, authenticated',r.relname);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';

SELECT 'OK: Bodega y Despacho separados; datos conservados' AS resultado;


-- Adaptación 071_ciclos_gerencia.sql



SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF position('(''admin'',''despacho'')' in pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 070'; END IF;
END $$;
ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check CHECK(rol IN('admin','produccion','logistica','despacho','gerencia'));
CREATE OR REPLACE FUNCTION public.puede_ver_dashboards() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN('admin','gerencia'));
$$;
REVOKE ALL ON FUNCTION public.puede_ver_dashboards() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.puede_ver_dashboards() TO authenticated;
DO $$ DECLARE firma text; d text; BEGIN
 FOREACH firma IN ARRAY ARRAY['public.admin_usuario_guardar(uuid,text,text,boolean,text)','public.admin_usuario_registrar(uuid,uuid,text,text,text)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('''gerencia''' in d)>0 THEN CONTINUE; END IF;
   IF position('(''admin'',''produccion'',''logistica'',''despacho'')' in d)=0 THEN RAISE EXCEPTION 'Validacion de roles inesperada: %',firma; END IF;
   EXECUTE replace(d,'(''admin'',''produccion'',''logistica'',''despacho'')','(''admin'',''produccion'',''logistica'',''despacho'',''gerencia'')');
 END LOOP;
 -- Lectura de dashboards. Auditoría e importaciones siguen siendo solo Admin.
 FOREACH firma IN ARRAY ARRAY['public.admin_reporte_resumen()','public.admin_reporte_pagina(text,text,timestamp with time zone)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('public.puede_ver_dashboards()' in d)>0 THEN CONTINUE; END IF;
   IF position('IF NOT public.admin_es_admin() THEN' in d)=0 THEN RAISE EXCEPTION 'Reporte inesperado: %',firma; END IF;
   IF firma LIKE '%pagina%' THEN
     d:=replace(d,'IF NOT public.admin_es_admin() THEN','IF NOT public.puede_ver_dashboards() OR (p_tipo = ''auditoria'' AND NOT public.admin_es_admin()) THEN');
   ELSE d:=replace(d,'IF NOT public.admin_es_admin() THEN','IF NOT public.puede_ver_dashboards() THEN'); END IF;
   EXECUTE d;
 END LOOP;
 -- Estos tres RPC antiguos permitían agregar nombres con cualquier cuenta activa.
 FOREACH firma IN ARRAY ARRAY['public.agregar_personal_logistica(text)','public.agregar_personal_produccion(text)','public.agregar_personal_aliado(text)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('gerencia' in d)>0 THEN CONTINUE; END IF;
   IF position('IF NOT public.wms_cuenta_activa() THEN' in d)=0 THEN RAISE EXCEPTION 'RPC inesperado: %',firma; END IF;
   EXECUTE replace(d,'IF NOT public.wms_cuenta_activa() THEN',
    'IF NOT public.wms_cuenta_activa() OR EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND rol=''gerencia'') THEN');
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.wms_cuenta_operativa() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN('admin','produccion','logistica','despacho'));
$$;
REVOKE ALL ON FUNCTION public.wms_cuenta_operativa() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_cuenta_operativa() TO authenticated;
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity AND c.relname IN ('usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados','ordenes_produccion','items_orden','movimientos','lotes','lote_items','devoluciones_produccion','liberaciones_no_conforme','no_conformes_aliados','liberaciones_aliados','sobrantes_bodega','despachos_oc','admin_correcciones','empaques') LOOP
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_insert ON public.%I',t.relname);
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_update ON public.%I',t.relname);
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_delete ON public.%I',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.wms_cuenta_operativa())',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.wms_cuenta_operativa()) WITH CHECK(public.wms_cuenta_operativa())',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING(public.wms_cuenta_operativa())',t.relname);
 END LOOP;
END $$;


DO $$ BEGIN
 IF to_regclass('storage.objects') IS NOT NULL THEN
   CREATE POLICY gerencia_sin_insert ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa());
   CREATE POLICY gerencia_sin_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa()) WITH CHECK(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa());
   CREATE POLICY gerencia_sin_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa());
 END IF;
END $$;

CREATE TABLE public.ciclos_revision(id boolean PRIMARY KEY DEFAULT true CHECK(id), revision bigint NOT NULL DEFAULT 0);
INSERT INTO public.ciclos_revision DEFAULT VALUES;
CREATE TABLE public.ciclos_parametros(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), proceso text NOT NULL CHECK(proceso IN('compras','trazo','corte','separado','aliados','terminado','logistica')),
 vigente_desde date NOT NULL CHECK(vigente_desde BETWEEN '1900-01-01' AND '2200-12-31'), dias integer NOT NULL CHECK(dias BETWEEN 0 AND 3650),
 capacidad_diaria integer CHECK(capacidad_diaria>0), capacidad_semanal integer CHECK(capacidad_semanal>0), umbral_cola integer CHECK(umbral_cola>0),
 creado_en timestamptz NOT NULL DEFAULT now(), actor uuid NOT NULL, UNIQUE(proceso,vigente_desde));
CREATE TABLE public.ciclos_ordenes(
 op text PRIMARY KEY CHECK(length(trim(op)) BETWEEN 1 AND 100), cliente text NOT NULL CHECK(length(trim(cliente)) BETWEEN 1 AND 300),
 cantidad integer NOT NULL CHECK(cantidad>0), inicio date, fines jsonb NOT NULL, versiones jsonb NOT NULL DEFAULT '{}',
 actualizado_en timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.ciclos_importaciones(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), archivo text NOT NULL, actor uuid NOT NULL,
 creado_en timestamptz NOT NULL DEFAULT now(), antes jsonb NOT NULL, despues jsonb NOT NULL);
ALTER TABLE public.ciclos_revision ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_parametros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_ordenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ciclos_revision,public.ciclos_parametros,public.ciclos_ordenes,public.ciclos_importaciones FROM PUBLIC,anon,authenticated;
CREATE POLICY ciclos_auditoria_admin ON public.ciclos_importaciones FOR SELECT TO authenticated USING(public.admin_es_admin());
GRANT SELECT ON public.ciclos_importaciones TO authenticated;


CREATE FUNCTION public.ciclos_versiones(p_inicio date,p_fines jsonb,p_anterior public.ciclos_ordenes) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE procesos text[]:=ARRAY['compras','trazo','corte','separado','aliados','terminado','logistica']; i int; f date; antigua date; v uuid; r jsonb:='{}';
BEGIN
 FOR i IN 1..7 LOOP
   f:=CASE WHEN i=1 THEN p_inicio ELSE (p_fines->>procesos[i-1])::date END;
   antigua:=CASE WHEN i=1 THEN p_anterior.inicio ELSE (p_anterior.fines->>procesos[i-1])::date END;
   v:=NULL;
   IF f IS NOT NULL THEN
     IF f IS NOT DISTINCT FROM antigua THEN v:=(p_anterior.versiones->>procesos[i])::uuid; END IF;
     IF v IS NULL THEN SELECT id INTO v FROM public.ciclos_parametros WHERE proceso=procesos[i] AND vigente_desde<=f ORDER BY vigente_desde DESC LIMIT 1; END IF;
   END IF;
   r:=r||jsonb_build_object(procesos[i],v);
 END LOOP;
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.ciclos_versiones(date,jsonb,public.ciclos_ordenes) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.ciclos_estado() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso a dashboards' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('revision',(SELECT revision::text FROM public.ciclos_revision),'hoy',(now() AT TIME ZONE 'America/Bogota')::date,
  'parametros',(SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY proceso,vigente_desde),'[]') FROM public.ciclos_parametros p));
END $$;
CREATE FUNCTION public.ciclos_pagina(p_despues text,p_revision text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso a dashboards' USING ERRCODE='42501'; END IF;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los datos cambiaron. Actualiza e intenta de nuevo.'; END IF;
 RETURN (SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY op),'[]') FROM (SELECT * FROM public.ciclos_ordenes WHERE op>p_despues ORDER BY op LIMIT 1000)o);
END $$;
CREATE FUNCTION public.ciclos_configurar(p_proceso text,p_desde date,p_dias integer,p_diaria integer,p_semanal integer,p_revision text,p_cola integer DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp SET lock_timeout='5s' AS $$
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.ciclos_revision FOR UPDATE;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los parámetros cambiaron. Actualiza antes de guardar.'; END IF;
 INSERT INTO public.ciclos_parametros(proceso,vigente_desde,dias,capacidad_diaria,capacidad_semanal,umbral_cola,actor) VALUES(p_proceso,p_desde,p_dias,p_diaria,p_semanal,p_cola,auth.uid());
 -- Solo completa asignaciones faltantes; jamás sustituye versiones ya asociadas.
 UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o) WHERE o.versiones IS DISTINCT FROM public.ciclos_versiones(o.inicio,o.fines,o);
 UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;
END $$;
CREATE FUNCTION public.ciclos_importar(p_filas jsonb,p_revision text,p_confirmar boolean,p_archivo text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp SET lock_timeout='5s' AS $$
DECLARE x jsonb; f date; anterior date; p text; cantidad numeric; old public.ciclos_ordenes; nuevo int:=0; cambios int:=0; borradas int:=0; antes jsonb; despues jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF p_confirmar IS NULL OR p_archivo IS NULL OR length(p_archivo)>300 OR jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo invalido'; END IF;
 IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Carga entre 1 y 10000 OP'; END IF;
 PERFORM 1 FROM public.ciclos_revision FOR UPDATE;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los datos cambiaron. Revisa una nueva vista previa.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) AS fila(valor) GROUP BY trim(fila.valor->>'op') HAVING count(*)>1) THEN RAISE EXCEPTION 'OP repetida'; END IF;
 FOR x IN SELECT * FROM jsonb_array_elements(p_filas) LOOP
   IF jsonb_typeof(x->'op') IS DISTINCT FROM 'string' OR coalesce(length(trim(x->>'op')),0) NOT BETWEEN 1 AND 100
     OR jsonb_typeof(x->'cliente') IS DISTINCT FROM 'string' OR coalesce(length(trim(x->>'cliente')),0) NOT BETWEEN 1 AND 300 OR jsonb_typeof(x->'fines') IS DISTINCT FROM 'object'
     OR NOT (x ? 'inicio') THEN RAISE EXCEPTION 'Fila invalida'; END IF;
   cantidad:=(x->>'cantidad')::numeric;
   IF cantidad IS NULL OR cantidad<>trunc(cantidad) OR cantidad NOT BETWEEN 1 AND 2147483647 THEN RAISE EXCEPTION 'Cantidad invalida'; END IF;
   IF x->>'inicio' IS NOT NULL AND (x->>'inicio') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha inicial no ISO'; END IF;
   anterior:=(x->>'inicio')::date;
   IF anterior IS NOT NULL AND anterior NOT BETWEEN '1900-01-01' AND '2200-12-31' THEN RAISE EXCEPTION 'Fecha fuera de rango'; END IF;
   IF (SELECT count(*) FROM jsonb_object_keys(x->'fines'))<>7 THEN RAISE EXCEPTION 'Se requieren los siete procesos'; END IF;
   SELECT * INTO old FROM public.ciclos_ordenes WHERE op=trim(x->>'op');
   IF NOT FOUND THEN nuevo:=nuevo+1;
   ELSIF (to_jsonb(old)-'versiones'-'actualizado_en') IS DISTINCT FROM jsonb_build_object('op',trim(x->>'op'),'cliente',trim(x->>'cliente'),'cantidad',cantidad::int,'inicio',x->'inicio','fines',x->'fines') THEN cambios:=cambios+1; END IF;
   IF old.inicio IS NOT NULL AND x->>'inicio' IS NULL THEN borradas:=borradas+1; END IF;
   FOREACH p IN ARRAY ARRAY['compras','trazo','corte','separado','aliados','terminado','logistica'] LOOP
     IF NOT ((x->'fines') ? p) THEN RAISE EXCEPTION 'Falta proceso %',p; END IF;
     IF x->'fines'->>p IS NOT NULL AND (x->'fines'->>p) !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha no ISO'; END IF;
     f:=(x->'fines'->>p)::date;
     IF f IS NOT NULL AND (f NOT BETWEEN '1900-01-01' AND '2200-12-31' OR f<anterior) THEN RAISE EXCEPTION 'Fechas contradictorias en OP %, proceso %',x->>'op',p; END IF;
     anterior:=coalesce(f,anterior);
     IF old.fines->>p IS NOT NULL AND f IS NULL THEN borradas:=borradas+1; END IF;
   END LOOP;
 END LOOP;
 IF p_confirmar THEN
   SELECT coalesce(jsonb_agg(to_jsonb(o)),'[]') INTO antes FROM public.ciclos_ordenes o WHERE op IN(SELECT trim(fila.valor->>'op') FROM jsonb_array_elements(p_filas) AS fila(valor));
   FOR x IN SELECT * FROM jsonb_array_elements(p_filas) LOOP
     SELECT * INTO old FROM public.ciclos_ordenes WHERE op=trim(x->>'op');
     INSERT INTO public.ciclos_ordenes(op,cliente,cantidad,inicio,fines,versiones)
     VALUES(trim(x->>'op'),trim(x->>'cliente'),(x->>'cantidad')::integer,(x->>'inicio')::date,x->'fines',public.ciclos_versiones((x->>'inicio')::date,x->'fines',old))
     ON CONFLICT(op) DO UPDATE SET cliente=excluded.cliente,cantidad=excluded.cantidad,inicio=excluded.inicio,fines=excluded.fines,versiones=excluded.versiones,actualizado_en=now();
   END LOOP;
   SELECT jsonb_agg(to_jsonb(o)) INTO despues FROM public.ciclos_ordenes o WHERE op IN(SELECT trim(fila.valor->>'op') FROM jsonb_array_elements(p_filas) AS fila(valor));
   INSERT INTO public.ciclos_importaciones(archivo,actor,antes,despues) VALUES(p_archivo,auth.uid(),antes,despues);
   UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;
 END IF;
 RETURN jsonb_build_object('nuevas',nuevo,'actualizadas',cambios,'fechas_borradas',borradas,'total',jsonb_array_length(p_filas));
END $$;
REVOKE ALL ON FUNCTION public.ciclos_estado(),public.ciclos_pagina(text,text),public.ciclos_configurar(text,date,integer,integer,integer,text,integer),public.ciclos_importar(jsonb,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ciclos_estado(),public.ciclos_pagina(text,text),public.ciclos_configurar(text,date,integer,integer,integer,text,integer),public.ciclos_importar(jsonb,text,boolean,text) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 072_corregir_updates_ciclos.sql



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

SELECT 'OK: actualizaciones de ciclos corregidas; vuelve a importar el Excel.' AS resultado;


-- Adaptación 073_lista_empaque.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE TABLE IF NOT EXISTS public.destinatarios_empaque(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),clave text UNIQUE NOT NULL,datos jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS public.lista_empaque_config(id boolean PRIMARY KEY DEFAULT true CHECK(id),siguiente bigint CHECK(siguiente>0));
INSERT INTO public.lista_empaque_config(id) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.listas_empaque(despacho_id uuid PRIMARY KEY REFERENCES public.despachos_oc(id),numero bigint UNIQUE,datos jsonb NOT NULL,creado_en timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.destinatarios_empaque ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lista_empaque_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listas_empaque ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.destinatarios_empaque,public.lista_empaque_config,public.listas_empaque FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.le_acceso() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','despacho'))
$$;
CREATE OR REPLACE FUNCTION public.le_clientes() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Administrador' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'datos',datos) ORDER BY datos->>'nombre',id) FROM public.destinatarios_empaque),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.le_importar_clientes(p_filas jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; n integer:=0; k text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Archivo de clientes invalido'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
  IF coalesce(length(trim(r->>'nombre')),0) NOT BETWEEN 1 AND 500 OR length(r::text)>10000 THEN RAISE EXCEPTION 'Destinatario invalido'; END IF;
  k:=md5(jsonb_build_array(r->>'nombre',r->>'nit',r->>'direccion',r->>'ciudad',r->>'contacto',r->>'telefono',r->>'celular')::text);
  -- Solo combina coincidencias exactas; conserva sedes y contactos diferentes.
  INSERT INTO public.destinatarios_empaque(clave,datos) VALUES(k,r) ON CONFLICT(clave) DO UPDATE SET datos=excluded.datos;
  n:=n+1;
 END LOOP;
 RETURN n;
END $$;
CREATE OR REPLACE FUNCTION public.le_configurar(p_siguiente bigint) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.lista_empaque_config IN EXCLUSIVE MODE;
 IF p_siguiente IS NULL OR p_siguiente<1 OR p_siguiente<=coalesce((SELECT max(numero) FROM public.listas_empaque),0) THEN RAISE EXCEPTION 'El siguiente LE debe ser mayor que los ya emitidos'; END IF;
 UPDATE public.lista_empaque_config SET siguiente=p_siguiente WHERE id=true;
END $$;

CREATE OR REPLACE FUNCTION public.despachar_oc_bultos(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE resultado jsonb; copia jsonb;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Solo Despacho o Administrador' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Empaques invalidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e WHERE coalesce(e->>'numero','') !~ '^[1-9][0-9]{0,3}$') THEN RAISE EXCEPTION 'Numera cada empaque'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e GROUP BY e->>'numero' HAVING count(DISTINCT e->>'empaque_id')<>1) THEN RAISE EXCEPTION 'Un numero solo puede identificar un empaque'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e GROUP BY e->>'numero',e->>'item_id' HAVING count(*)>1) THEN RAISE EXCEPTION 'Agrupa la cantidad de cada talla dentro de su empaque'; END IF;
 IF (SELECT count(DISTINCT e->>'numero') FROM jsonb_array_elements(p_empaques) e)<>(SELECT max((e->>'numero')::integer) FROM jsonb_array_elements(p_empaques) e) THEN RAISE EXCEPTION 'Numeracion discontinua'; END IF;
 resultado:=public.despachar_oc_prendas_empaques(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 SELECT jsonb_agg(e.value||jsonb_build_object('numero',(p_empaques->(e.ordinality::integer-1)->>'numero')::integer) ORDER BY e.ordinality) INTO copia FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.empaques) WITH ORDINALITY e WHERE d.id=(resultado->>'id')::uuid;
 UPDATE public.despachos_oc SET empaques=copia WHERE id=(resultado->>'id')::uuid;
 RETURN resultado||jsonb_build_object('empaques',copia);
END $$;

CREATE OR REPLACE FUNCTION public.le_documento(p_solicitud text,p_destinatario uuid DEFAULT NULL,p_datos jsonb DEFAULT '{}',p_emitir boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; doc public.listas_empaque%rowtype; destino jsonb; contenido jsonb; n bigint;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Solo Despacho o Administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE solicitud=p_solicitud OR id::text=p_solicitud FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Despacho inexistente'; END IF;
 SELECT * INTO doc FROM public.listas_empaque WHERE despacho_id=d.id;
 IF FOUND THEN RETURN doc.datos||jsonb_build_object('numero',doc.numero); END IF;
 IF NOT p_emitir THEN RETURN jsonb_build_object('pendiente',true,'cliente',d.cliente,'oc',d.oc); END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d.empaques) e WHERE e->>'numero' IS NULL) OR jsonb_array_length(d.empaques)=0 THEN RAISE EXCEPTION 'Este despacho historico no tiene empaques numerados; no se inventara su distribucion'; END IF;
 SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona el destinatario'; END IF;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR length(p_datos::text)>3000 THEN RAISE EXCEPTION 'Datos del documento invalidos'; END IF;
 SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
 IF n IS NULL THEN RAISE EXCEPTION 'El administrador debe configurar el proximo consecutivo LE. El despacho ya esta guardado'; END IF;
 contenido:=jsonb_build_object('despacho_id',d.id,'fecha',d.fecha,'actor',d.actor,'cliente',d.cliente,'oc',d.oc,'detalle',d.detalle,'empaques',d.empaques,'destinatario',destino,'remision',coalesce(p_datos->>'remision',''),'id_oc',coalesce(p_datos->>'id_oc',''),'factura',coalesce(p_datos->>'factura',''));
 INSERT INTO public.listas_empaque(despacho_id,numero,datos) VALUES(d.id,n,contenido);
 UPDATE public.lista_empaque_config SET siguiente=n+1 WHERE id=true;
 RETURN contenido||jsonb_build_object('numero',n);
END $$;
REVOKE ALL ON FUNCTION public.le_acceso(),public.le_clientes(),public.le_importar_clientes(jsonb),public.le_configurar(bigint),public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.le_documento(text,uuid,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.le_acceso(),public.le_clientes(),public.le_importar_clientes(jsonb),public.le_configurar(bigint),public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.le_documento(text,uuid,jsonb,boolean) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 074_correccion_multilote.sql


DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.admin_editar_recepciones(p_item_id uuid,p_campo text,p_valor jsonb,p_motivo text,p_version text,p_recepciones jsonb,p_ubicacion_id uuid,p_confirmar boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE ctx jsonb; antes jsonb; e jsonb; li public.lote_items%rowtype; delta integer; total integer; suma integer:=0; resultado jsonb; paso jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_campo IS DISTINCT FROM 'recibido' OR p_confirmar IS NULL OR coalesce(trim(p_motivo),'')='' THEN RAISE EXCEPTION 'Corrección inválida.'; END IF;
 IF jsonb_typeof(p_recepciones) IS DISTINCT FROM 'array' OR jsonb_array_length(p_recepciones)=0 THEN RAISE EXCEPTION 'Selecciona cantidades por lote.'; END IF;
 IF jsonb_typeof(p_valor) IS DISTINCT FROM 'number' OR (p_valor #>> '{}') !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Total inválido.'; END IF;
 LOCK TABLE public.usuarios IN SHARE MODE;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos,public.admin_correcciones,public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
 ctx:=public.admin_contexto_edicion(p_item_id); antes:=ctx->'valores';
 IF p_version IS DISTINCT FROM ctx->>'version' THEN RAISE EXCEPTION 'La fila cambió. Cierra y vuelve a abrir la edición.'; END IF;
 IF (SELECT count(*) <> count(DISTINCT (x->>'id')::uuid) FROM jsonb_array_elements(p_recepciones) x) THEN RAISE EXCEPTION 'Lote repetido.'; END IF;
 FOR e IN SELECT * FROM jsonb_array_elements(p_recepciones) LOOP
   IF jsonb_typeof(e->'cantidad') IS DISTINCT FROM 'number' OR (e->>'cantidad') !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Cantidad por lote inválida.'; END IF;
   SELECT * INTO li FROM public.lote_items WHERE id=(e->>'id')::uuid AND item_orden_id=p_item_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Lote ajeno a la fila.'; END IF;
   IF (e->>'cantidad')::integer > li.cantidad_enviada THEN RAISE EXCEPTION 'La recepción corregida supera lo enviado en el lote.'; END IF;
   suma:=suma+(e->>'cantidad')::integer-coalesce(li.cantidad_recibida,0);
 END LOOP;
 IF suma=0 OR (antes->>'recibido')::integer+suma<>(p_valor #>> '{}')::integer THEN RAISE EXCEPTION 'La suma por lote no coincide con el total deseado.'; END IF;
 -- La revisión ejecuta las mismas validaciones que guardar y revierte todas sus escrituras.
 BEGIN
   total:=(antes->>'recibido')::integer;
   -- Reducciones primero: evita exceder temporalmente lo producido al redistribuir.
   FOR e IN SELECT x FROM jsonb_array_elements(p_recepciones) x JOIN public.lote_items l ON l.id=(x->>'id')::uuid ORDER BY (x->>'cantidad')::integer-coalesce(l.cantidad_recibida,0) LOOP
     SELECT * INTO li FROM public.lote_items WHERE id=(e->>'id')::uuid;
     delta:=(e->>'cantidad')::integer-coalesce(li.cantidad_recibida,0);
     IF delta=0 THEN CONTINUE; END IF;
     total:=total+delta;
     ctx:=public.admin_contexto_edicion(p_item_id);
     paso:=public.admin_editar_kardex(p_item_id,'recibido',to_jsonb(total),p_motivo,ctx->>'version',li.id,p_ubicacion_id,true);
   END LOOP;
   resultado:=jsonb_build_object('antes',antes,'despues',paso->'despues','guardado',p_confirmar);
   IF NOT p_confirmar THEN RAISE EXCEPTION USING ERRCODE='Z0740',MESSAGE='Revisión sin guardar'; END IF;
 EXCEPTION WHEN SQLSTATE 'Z0740' THEN NULL;
 END;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';


-- Adaptación 075_proteger_despachadas_correccion.sql


DO $m$
DECLARE definicion text; ancla text := ' -- La revisión ejecuta las mismas validaciones que guardar y revierte todas sus escrituras.';
BEGIN
 
 
 SELECT pg_get_functiondef(to_regprocedure('public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean)')) INTO definicion;
 IF definicion IS NULL THEN RAISE EXCEPTION 'Instala primero 074'; END IF;
 IF position('proteccion_despachadas_075' in definicion)>0 THEN RETURN; END IF;
 IF position(ancla in definicion)=0 THEN RAISE EXCEPTION 'La función cambió. Revisar antes de instalar.'; END IF;
 definicion:=replace(definicion,ancla,$regla$
 -- proteccion_despachadas_075: no compensar una reducción de stock despachado con otra recepción.
 IF (SELECT coalesce(sum(greatest(coalesce(l.cantidad_recibida,0)-(x->>'cantidad')::integer,0)),0)
     FROM jsonb_array_elements(p_recepciones) x JOIN public.lote_items l ON l.id=(x->>'id')::uuid)
     > (antes->>'recibido')::integer-(antes->>'despachado')::integer THEN
   RAISE EXCEPTION 'La reducción supera las prendas que siguen en bodega. Las despachadas están protegidas.';
 END IF;
$regla$ || ancla);
 EXECUTE definicion;
END $m$;
NOTIFY pgrst,'reload schema';


-- Adaptación 077_destinatarios_sede.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.le_importar_clientes(p_filas jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; n integer:=0; k text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Archivo de clientes invalido'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
  IF coalesce(length(trim(r->>'nombre')),0) NOT BETWEEN 1 AND 500 OR length(r::text)>10000 THEN RAISE EXCEPTION 'Destinatario invalido'; END IF;
  k:=md5(jsonb_build_array(r->>'nombre',r->>'nit',r->>'direccion',r->>'ciudad',r->>'contacto',r->>'telefono',r->>'celular')::text);
  IF nullif(trim(r->>'sede'),'') IS NOT NULL THEN
    k:=md5(jsonb_build_array(k,trim(r->>'sede'))::text);
  END IF;
  -- Solo combina coincidencias exactas; conserva sedes y contactos diferentes.
  INSERT INTO public.destinatarios_empaque(clave,datos) VALUES(k,r) ON CONFLICT(clave) DO UPDATE SET datos=excluded.datos;
  n:=n+1;
 END LOOP;
 RETURN n;
END $$;



-- Adaptación 078_corregir_pendiente_recepcion.sql



SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF position('validacion_entregado_recibido_v68' in pg_get_functiondef('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 068'; END IF;
END $$;

ALTER TABLE public.lote_items DROP CONSTRAINT lote_items_cantidad_enviada_check;
ALTER TABLE public.lote_items ADD CONSTRAINT lote_items_cantidad_enviada_check CHECK(cantidad_enviada>=0);
CREATE OR REPLACE FUNCTION public.admin_sincronizar_envios_corregidos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; restante integer := -NEW.cantidad; reducir integer;
 v_antes jsonb := '[]'; v_despues jsonb := '[]';
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.admin_correcciones
   WHERE id=NEW.admin_correccion_id AND item_id=NEW.item_orden_id AND campo='producido') THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM public.admin_correcciones ac WHERE ac.id=NEW.admin_correccion_id
   AND (ac.nuevo #>> '{}')::bigint < (ac.despues->>'recibido')::bigint) THEN
   RAISE EXCEPTION 'No se puede reducir el envío por debajo de lo ya recibido por Bodega.';
 END IF;
 -- La RPC mantiene bloqueadas las tablas hasta confirmar toda la corrección.
 -- Primero los envíos recientes; nunca reducir lo recibido ni los reprocesos.
 FOR r IN SELECT li.* FROM public.lote_items li JOIN public.lotes l ON l.id=li.lote_id
   WHERE li.item_orden_id=NEW.item_orden_id AND li.origen='entrega'
     AND li.estado='en_transito' AND li.cantidad_enviada>coalesce(li.cantidad_recibida,0)
     AND NOT EXISTS(SELECT 1 FROM public.movimientos m WHERE m.lote_item_id=li.id AND m.tipo='ajuste_faltante_entrega')
   ORDER BY l.fecha_envio DESC,li.id DESC FOR UPDATE OF li
 LOOP
   EXIT WHEN restante=0;
   reducir:=least(restante,r.cantidad_enviada-coalesce(r.cantidad_recibida,0));
   v_antes:=v_antes||jsonb_build_array(to_jsonb(r));
   UPDATE public.lote_items SET cantidad_enviada=cantidad_enviada-reducir,
     estado=CASE WHEN cantidad_enviada-reducir=coalesce(cantidad_recibida,0) THEN 'recibido_con_novedad' ELSE 'en_transito' END,
     novedad=concat_ws(' | ',nullif(novedad,''),'Envío corregido: -'||reducir||' prendas. Corrección '||NEW.admin_correccion_id)
     WHERE id=r.id;
   v_despues:=v_despues||jsonb_build_array((SELECT to_jsonb(li) FROM public.lote_items li WHERE li.id=r.id));
   UPDATE public.lotes SET estado=CASE
     WHEN NOT EXISTS(SELECT 1 FROM public.lote_items WHERE lote_id=r.lote_id AND estado='en_transito') THEN 'recibido_completo'
     WHEN EXISTS(SELECT 1 FROM public.lote_items WHERE lote_id=r.lote_id AND coalesce(cantidad_recibida,0)>0) THEN 'recibido_parcial'
     ELSE 'en_transito' END WHERE id=r.lote_id;
   restante:=restante-reducir;
 END LOOP;
 -- El resto puede corresponder a totales históricos sin lote, que ya permite la RPC.
 UPDATE public.admin_correcciones SET lote_antes=v_antes,lote_despues=v_despues WHERE id=NEW.admin_correccion_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.admin_sincronizar_envios_corregidos() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS admin_sincronizar_envios_corregidos ON public.movimientos;
CREATE TRIGGER admin_sincronizar_envios_corregidos AFTER INSERT ON public.movimientos
FOR EACH ROW WHEN (NEW.tipo='entrega_produccion' AND NEW.cantidad<0 AND NEW.admin_correccion_id IS NOT NULL AND NEW.lote_item_id IS NULL)
EXECUTE FUNCTION public.admin_sincronizar_envios_corregidos();


-- Adaptación 079_historial_despachos_le.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb; resultado jsonb;
BEGIN
 -- La funcion existente verifica la cuenta activa y su rol.
 filas:=public.historial_despachos_oc(p_despues);
 SELECT coalesce(jsonb_agg(x.value||jsonb_build_object('empaques',d.empaques,'le_numero',le.numero) ORDER BY x.value->>'registro'),'[]') INTO resultado
 FROM jsonb_array_elements(filas) x LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_oc_id')::uuid LEFT JOIN public.listas_empaque le ON le.despacho_id=d.id;
 RETURN resultado;
END $$;

NOTIFY pgrst,'reload schema';


-- Adaptación 080_corregir_despacho_le.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS ediciones integer NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS public.despacho_revisiones(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id),
 solicitud text UNIQUE NOT NULL, edicion integer NOT NULL, actor uuid NOT NULL REFERENCES public.usuarios(id),
 fecha timestamptz NOT NULL DEFAULT now(), motivo text NOT NULL, pedido jsonb NOT NULL,
 anterior jsonb NOT NULL, documento_anterior jsonb, resultado jsonb,
 UNIQUE(despacho_id,edicion)
);
ALTER TABLE public.despacho_revisiones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.despacho_revisiones FROM PUBLIC,anon,authenticated;
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS despacho_revision_id uuid REFERENCES public.despacho_revisiones(id);
ALTER TABLE public.movimientos DROP CONSTRAINT movimientos_cantidad_admin_check;
ALTER TABLE public.movimientos ADD CONSTRAINT movimientos_cantidad_admin_check CHECK(
 cantidad>0 OR (cantidad<0 AND (admin_correccion_id IS NOT NULL OR (tipo='despacho' AND despacho_revision_id IS NOT NULL)))
) NOT VALID;
DROP POLICY IF EXISTS proteger_revision_despacho ON public.movimientos;
CREATE POLICY proteger_revision_despacho ON public.movimientos AS RESTRICTIVE FOR ALL TO authenticated
 USING(true) WITH CHECK(despacho_revision_id IS NULL);

CREATE OR REPLACE FUNCTION public.despacho_para_corregir(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE d public.despachos_oc%rowtype; le public.listas_empaque%rowtype;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Despacho inexistente'; END IF;
 IF jsonb_array_length(d.empaques)=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(d.empaques) e WHERE e->>'numero' IS NULL) THEN RAISE EXCEPTION 'El despacho no tiene empaques numerados para corregir'; END IF;
 SELECT * INTO le FROM public.listas_empaque WHERE despacho_id=p_id;
 RETURN to_jsonb(d)||jsonb_build_object('le_numero',le.numero,'version',md5(to_jsonb(d)::text||coalesce(le.datos::text,'')));
END $$;

CREATE OR REPLACE FUNCTION public.corregir_despacho_le(p_id uuid,p_version text,p_solicitud text,p_motivo text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; nuevo public.despachos_oc%rowtype; le public.listas_empaque%rowtype;
 rev public.despacho_revisiones%rowtype; actor_id uuid; rid uuid:=gen_random_uuid(); r jsonb; v_resultado jsonb;
 pedido jsonb:=jsonb_build_object('id',p_id,'version',p_version,'motivo',p_motivo,'cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques);
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Administrador' USING ERRCODE='42501'; END IF;
 SELECT id INTO actor_id FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 IF coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 1000 OR coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 90 THEN RAISE EXCEPTION 'Indica motivo e identificador de corrección'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO rev FROM public.despacho_revisiones WHERE solicitud=p_solicitud;
 IF FOUND THEN
   IF rev.pedido IS DISTINCT FROM pedido OR rev.actor<>actor_id THEN RAISE EXCEPTION 'Identificador usado para otra corrección'; END IF;
   RETURN rev.resultado;
 END IF;
 IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud='correccion:'||p_solicitud) THEN
   RAISE EXCEPTION 'Identificador reservado por otro despacho. Abre la corrección nuevamente';
 END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Despacho inexistente'; END IF;
 SELECT * INTO le FROM public.listas_empaque WHERE despacho_id=p_id FOR UPDATE;
 IF p_version IS DISTINCT FROM (public.despacho_para_corregir(p_id)->>'version') THEN RAISE EXCEPTION 'El despacho cambió. Vuelve a abrir su corrección'; END IF;
 -- Un ajuste administrativo externo requiere conciliación, no una doble devolución.
 IF EXISTS(
  SELECT 1 FROM
   (SELECT item_orden_id id,ubicacion_id u,sum(cantidad) n FROM public.movimientos WHERE despacho_oc_id=p_id AND tipo='despacho' GROUP BY 1,2) m
   FULL JOIN (SELECT (x->>'item_id')::uuid id,(x->>'ubicacion_id')::uuid u,sum((x->>'cantidad')::integer) n FROM jsonb_array_elements(d.detalle) x GROUP BY 1,2) x USING(id,u)
   WHERE coalesce(m.n,0)<>coalesce(x.n,0)
 ) THEN RAISE EXCEPTION 'El despacho tiene ajustes externos. Revisa sus movimientos antes de corregirlo'; END IF;
 INSERT INTO public.despacho_revisiones(id,despacho_id,solicitud,edicion,actor,motivo,pedido,anterior,documento_anterior)
 VALUES(rid,p_id,p_solicitud,d.ediciones+1,actor_id,trim(p_motivo),pedido,to_jsonb(d),CASE WHEN le.despacho_id IS NOT NULL THEN to_jsonb(le) END);
 INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,despacho_revision_id,nota)
 SELECT 'despacho',(x->>'item_id')::uuid,-(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,actor_id,p_id,rid,'Reversión por corrección: '||trim(p_motivo) FROM jsonb_array_elements(d.detalle) x;
 -- Valida stock, pedido, cliente, ubicaciones y empaques con las mismas RPC de un despacho nuevo.
 v_resultado:=public.despachar_oc_bultos('correccion:'||p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 SELECT * INTO nuevo FROM public.despachos_oc WHERE id=(v_resultado->>'id')::uuid;
 UPDATE public.movimientos SET despacho_oc_id=p_id,despacho_revision_id=rid WHERE despacho_oc_id=nuevo.id;
 UPDATE public.despachos_oc SET fecha=nuevo.fecha,actor_id=nuevo.actor_id,actor=nuevo.actor,
 cliente=nuevo.cliente,oc=nuevo.oc,pedido=nuevo.pedido,detalle=nuevo.detalle,
 empaques=nuevo.empaques,empaques_pedido=nuevo.empaques_pedido,ediciones=d.ediciones+1 WHERE id=p_id;
 DELETE FROM public.despachos_oc WHERE id=nuevo.id;
 -- Reserva la misma LE y exige volver a elegir destinatario antes de emitir su versión vigente.
 UPDATE public.listas_empaque SET datos=jsonb_build_object('pendiente',true) WHERE despacho_id=p_id;
 v_resultado:=jsonb_build_object('id',p_id,'ediciones',d.ediciones+1,'le_numero',le.numero);
 UPDATE public.despacho_revisiones SET resultado=v_resultado WHERE id=rid;
 RETURN v_resultado;
END $$;


DO $patch$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('LE_REVISION_V80' in f)>0 THEN RETURN; END IF;
 IF position('IF FOUND THEN RETURN doc.datos' in f)=0 THEN RAISE EXCEPTION 'RPC de documento inesperada'; END IF;
 f:=replace(f,'IF FOUND THEN RETURN doc.datos', 'IF FOUND AND coalesce((doc.datos->>''pendiente'')::boolean,false)=false THEN RETURN doc.datos');
 f:=replace(f,'SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE;',
   '/* LE_REVISION_V80 */ IF doc.numero IS NOT NULL THEN n:=doc.numero; ELSE SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE; END IF;');
 f:=replace(f,'VALUES(d.id,n,contenido);','VALUES(d.id,n,contenido) ON CONFLICT(despacho_id) DO UPDATE SET datos=excluded.datos;');
 f:=replace(f,'UPDATE public.lista_empaque_config SET siguiente=n+1 WHERE id=true;',
   'IF doc.numero IS NULL THEN UPDATE public.lista_empaque_config SET siguiente=n+1 WHERE id=true; END IF;');
 EXECUTE f;
END $patch$;

CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Administrador' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY registro),'[]') INTO resultado FROM (
  SELECT * FROM (
   SELECT d.id::text||':'||lpad(x.ordinality::text,6,'0') registro,d.fecha,(x.value->>'cantidad')::integer cantidad,
    d.cliente,d.oc,d.actor persona,x.value->>'op' op,x.value->>'item_id' item_id,x.value->>'codigo' codigo,
    x.value->>'producto' producto,x.value->>'talla' talla,x.value->>'ubicacion' ubicacion,
    'Despacho registrado'::text nota,d.id despacho_oc_id,d.empaques,le.numero le_numero,d.ediciones
   FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.detalle) WITH ORDINALITY x
   LEFT JOIN public.listas_empaque le ON le.despacho_id=d.id
   UNION ALL
   SELECT m.id::text,m.fecha,m.cantidad,coalesce(d.cliente,op.cliente),coalesce(d.oc,io.oc),coalesce(u.nombre,'Sin registrar'),op.numero_op,io.id::text,
    io.codigo,io.descripcion,io.talla,ub.codigo,m.nota,d.id,coalesce(d.empaques,'[]'::jsonb),le.numero,coalesce(d.ediciones,0)
   FROM public.movimientos m JOIN public.items_orden io ON io.id=m.item_orden_id JOIN public.ordenes_produccion op ON op.id=io.orden_id
   LEFT JOIN public.usuarios u ON u.id=m.usuario_id LEFT JOIN public.ubicaciones ub ON ub.id=m.ubicacion_id
   LEFT JOIN public.despachos_oc d ON d.id=m.despacho_oc_id LEFT JOIN public.listas_empaque le ON le.despacho_id=d.id
   WHERE m.tipo='despacho' AND (m.despacho_oc_id IS NULL OR m.admin_correccion_id IS NOT NULL)
  ) q WHERE registro>p_despues ORDER BY registro LIMIT 1000
 ) t;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.despacho_para_corregir(uuid),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despacho_para_corregir(uuid),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 081_empaque_seguimiento.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check CHECK(rol IN('admin','produccion','logistica','despacho','seguimiento','gerencia'));
DO $$ DECLARE r record; f text; BEGIN
 FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN('despachar_oc','despachar_oc_empaques','despachar_oc_prendas_empaques','historial_despachos_oc','empaques_listar','le_acceso','wms_cuenta_operativa','admin_usuario_guardar','admin_usuario_registrar') LOOP
  f:=pg_get_functiondef(r.oid);
  IF position('''seguimiento''' in f)=0 THEN
   f:=replace(f,'(''admin'',''despacho'')','(''admin'',''despacho'',''seguimiento'')');
   f:=replace(f,'(''admin'',''produccion'',''logistica'',''despacho'')','(''admin'',''produccion'',''logistica'',''despacho'',''seguimiento'')');
   f:=replace(f,'(''admin'',''produccion'',''logistica'',''despacho'',''gerencia'')','(''admin'',''produccion'',''logistica'',''despacho'',''seguimiento'',''gerencia'')');
   EXECUTE f;
  END IF;
 END LOOP;
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS fase text NOT NULL DEFAULT 'despachado' CHECK(fase IN('empacado','despachado'));
CREATE TABLE IF NOT EXISTS public.reservas_despacho(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), item_id uuid NOT NULL REFERENCES public.items_orden(id),
 ubicacion_id uuid NOT NULL REFERENCES public.ubicaciones(id), cantidad integer NOT NULL CHECK(cantidad>0),
 PRIMARY KEY(despacho_id,item_id,ubicacion_id)
);
ALTER TABLE public.reservas_despacho ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reservas_despacho FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reservas_despacho TO authenticated;
DROP POLICY IF EXISTS leer_reservas ON public.reservas_despacho;
CREATE POLICY leer_reservas ON public.reservas_despacho FOR SELECT TO authenticated USING(public.wms_cuenta_activa());
DO $$ BEGIN
 IF to_regprocedure('public.despachar_oc_bultos_base_v81(text,text,text,jsonb,jsonb)') IS NULL THEN
  ALTER FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb) RENAME TO despachar_oc_bultos_base_v81;
  ALTER FUNCTION public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb) RENAME TO corregir_despacho_le_base_v81;
 END IF;
END $$;

DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.corregir_despacho_le_base_v81(uuid,text,text,text,text,text,jsonb,jsonb)'::regprocedure) INTO f;
 EXECUTE replace(f,'public.despachar_oc_bultos(','public.despachar_oc_bultos_base_v81(');
END $$;

CREATE OR REPLACE FUNCTION public.validar_reservas_item(p_item uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; stock bigint; pedido integer; salidas bigint;
BEGIN
 SELECT cantidad_pedida INTO pedido FROM public.items_orden WHERE id=p_item FOR UPDATE;
 FOR r IN SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item GROUP BY 1 LOOP
  SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
  INTO stock FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id=r.ubicacion_id;
  IF stock<r.cantidad THEN RAISE EXCEPTION 'Estas prendas están reservadas en una LE. Corrige su empaque antes de retirar o ajustar el stock.'; END IF;
 END LOOP;
 SELECT coalesce(sum(cantidad),0) INTO salidas FROM public.movimientos WHERE item_orden_id=p_item AND tipo='despacho';
 IF EXISTS(SELECT 1 FROM public.reservas_despacho WHERE item_id=p_item) AND
 salidas+(SELECT coalesce(sum(cantidad),0) FROM public.reservas_despacho WHERE item_id=p_item)>pedido THEN
  RAISE EXCEPTION 'Las prendas despachadas y reservadas superan lo pedido';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.proteger_reservas() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF TG_TABLE_NAME='movimientos' THEN
  IF TG_OP<>'INSERT' THEN PERFORM public.validar_reservas_item(OLD.item_orden_id); END IF;
  IF TG_OP<>'DELETE' THEN PERFORM public.validar_reservas_item(NEW.item_orden_id); END IF;
 ELSIF TG_TABLE_NAME='items_orden' THEN PERFORM public.validar_reservas_item(NEW.id);
 ELSE PERFORM public.validar_reservas_item(NEW.item_id); END IF;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS proteger_reservas ON public.movimientos;
CREATE TRIGGER proteger_reservas AFTER INSERT OR UPDATE OR DELETE ON public.movimientos FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();
DROP TRIGGER IF EXISTS proteger_reservas ON public.items_orden;
CREATE TRIGGER proteger_reservas AFTER UPDATE OF cantidad_pedida ON public.items_orden FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();
DROP TRIGGER IF EXISTS proteger_reservas ON public.reservas_despacho;
CREATE TRIGGER proteger_reservas AFTER INSERT OR UPDATE ON public.reservas_despacho FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();

CREATE OR REPLACE FUNCTION public.reservar_empaque_interno(p_id uuid,p_nuevo boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE d public.despachos_oc%rowtype; n bigint; rev uuid;
BEGIN
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF p_nuevo THEN
  DELETE FROM public.movimientos WHERE despacho_oc_id=p_id;
 ELSE
  SELECT id INTO rev FROM public.despacho_revisiones WHERE despacho_id=p_id ORDER BY edicion DESC LIMIT 1;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,despacho_revision_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,-(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,d.actor_id,p_id,rev,'Corrección reservada para Seguimiento'
  FROM jsonb_array_elements(d.detalle) x;
 END IF;
 INSERT INTO public.reservas_despacho(despacho_id,item_id,ubicacion_id,cantidad)
 SELECT p_id,(x->>'item_id')::uuid,(x->>'ubicacion_id')::uuid,sum((x->>'cantidad')::integer)
 FROM jsonb_array_elements(d.detalle) x GROUP BY 2,3;
 UPDATE public.despachos_oc SET fase='empacado' WHERE id=p_id;
 IF NOT EXISTS(SELECT 1 FROM public.listas_empaque WHERE despacho_id=p_id) THEN
  SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
  IF n IS NULL THEN RAISE EXCEPTION 'Configura el consecutivo LE antes de confirmar el empaque'; END IF;
  INSERT INTO public.listas_empaque(despacho_id,numero,datos) VALUES(p_id,n,'{"pendiente":true}');
  UPDATE public.lista_empaque_config SET siguiente=n+1 WHERE id=true;
 ELSE UPDATE public.listas_empaque SET datos='{"pendiente":true}' WHERE despacho_id=p_id;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.despachar_oc_bultos(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE r jsonb;
BEGIN
 r:=public.despachar_oc_bultos_base_v81(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 IF coalesce((r->>'repetido')::boolean,false)=false THEN PERFORM public.reservar_empaque_interno((r->>'id')::uuid,true); END IF;
 RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.corregir_despacho_le(p_id uuid,p_version text,p_solicitud text,p_motivo text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; r jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN
  RETURN public.corregir_despacho_le_base_v81(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF d.fase='empacado' THEN
  DELETE FROM public.reservas_despacho WHERE despacho_id=p_id;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,d.actor_id,p_id,'Revisión interna de empaque'
  FROM jsonb_array_elements(d.detalle) x;
 END IF;
 r:=public.corregir_despacho_le_base_v81(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 PERFORM public.reservar_empaque_interno(p_id,false);
 RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_confirmar(p_id uuid,p_revision integer,p_destinatario uuid,p_datos jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; a public.usuarios%rowtype;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Despacho' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambió. Actualiza Seguimiento antes de confirmar'; END IF;
 IF d.fase='empacado' THEN
  IF NOT EXISTS(SELECT 1 FROM public.destinatarios_empaque WHERE id=p_destinatario) THEN RAISE EXCEPTION 'Selecciona el destinatario'; END IF;
  SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
  DELETE FROM public.reservas_despacho WHERE despacho_id=p_id;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,a.id,p_id,'Salida confirmada en Seguimiento'
  FROM jsonb_array_elements(d.detalle) x;
  UPDATE public.despachos_oc SET fase='despachado',fecha=now(),actor_id=a.id,actor=a.nombre WHERE id=p_id;
 END IF;
 RETURN public.le_documento(p_id::text,p_destinatario,p_datos,true);
END $$;

DO $$ DECLARE f text; ancla text:='IF NOT FOUND THEN RAISE EXCEPTION ''Despacho inexistente''; END IF;'; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('SEGUIMIENTO_V81' in f)=0 THEN
  IF position(ancla in f)=0 THEN RAISE EXCEPTION 'Revisar RPC de PDF'; END IF;
  EXECUTE replace(f,ancla,ancla||$x$
  -- SEGUIMIENTO_V81
  IF d.fase='empacado' THEN
   IF p_emitir THEN RAISE EXCEPTION 'Confirma la salida desde Seguimiento'; END IF;
   RETURN jsonb_build_object('pendiente',true,'fase',d.fase,'ediciones',d.ediciones,'cliente',d.cliente,'oc',d.oc);
  END IF;
  $x$);
 END IF;
END $$;

DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.historial_despachos_empaques(text)'::regprocedure) INTO f;
 IF position('d.fase' in f)=0 THEN
  f:=replace(f,'le.numero le_numero,d.ediciones','le.numero le_numero,d.ediciones,d.fase');
  f:=replace(f,'le.numero,coalesce(d.ediciones,0)','le.numero,coalesce(d.ediciones,0),coalesce(d.fase,''despachado'')');
  EXECUTE f;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.despachar_oc_bultos_base_v81(text,text,text,jsonb,jsonb),public.corregir_despacho_le_base_v81(uuid,text,text,text,text,text,jsonb,jsonb),public.reservar_empaque_interno(uuid,boolean),public.validar_reservas_item(uuid),public.proteger_reservas() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.despachar_oc(text,text,text,jsonb),public.despachar_oc_empaques(text,text,text,jsonb,jsonb),public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb),public.despachar(uuid,integer,uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb),public.seguimiento_confirmar(uuid,integer,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb),public.seguimiento_confirmar(uuid,integer,uuid,jsonb) TO authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='reservas_despacho') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.reservas_despacho;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';


-- Adaptación 082_destinatario_antes_empaque.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS destinatario_id uuid REFERENCES public.destinatarios_empaque(id);
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS destinatario_empaque jsonb;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS empacado_por text;
CREATE TABLE IF NOT EXISTS public.empaque_solicitudes(
 solicitud text PRIMARY KEY, actor uuid NOT NULL, pedido jsonb NOT NULL, resultado jsonb NOT NULL,
 creado_en timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.empaque_solicitudes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.empaque_solicitudes FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.destinatarios_para_empaque() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'datos',datos,'version',md5(datos::text)) ORDER BY datos->>'nombre',id) FROM public.destinatarios_empaque),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.guardar_empaque_destinatario(
 p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb,p_destinatario uuid,p_destinatario_version text,
 p_id uuid DEFAULT NULL,p_version text DEFAULT NULL,p_motivo text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE a public.usuarios%rowtype; previo public.empaque_solicitudes%rowtype; destino jsonb; r jsonb;
 pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques,
 'destinatario',p_destinatario,'destinatario_version',p_destinatario_version,'id',p_id,'version',p_version,'motivo',p_motivo);
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.empaque_solicitudes WHERE solicitud=p_solicitud;
 IF FOUND THEN
  IF previo.actor<>a.id OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada para otro empaque'; END IF;
  RETURN previo.resultado;
 END IF;
 SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario FOR SHARE;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona el destinatario antes de empacar'; END IF;
 IF p_destinatario_version IS DISTINCT FROM md5(destino::text) THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo y vuelve a generar los rótulos'; END IF;
 IF p_id IS NULL THEN
  IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud ya registrada. Abre su LE para corregir'; END IF;
  r:=public.despachar_oc_bultos(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 ELSE
  IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud de corrección ya registrada'; END IF;
  r:=public.corregir_despacho_le(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 UPDATE public.despachos_oc SET destinatario_id=p_destinatario,destinatario_empaque=destino,empacado_por=a.nombre WHERE id=(r->>'id')::uuid;
 INSERT INTO public.empaque_solicitudes(solicitud,actor,pedido,resultado) VALUES(p_solicitud,a.id,pedido,r);
 RETURN r;
END $$;
DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('DESTINO_EMPAQUE_V82' in f)=0 THEN
  f:=replace(f,'''oc'',d.oc);','''oc'',d.oc,''destinatario_id'',d.destinatario_id,''destinatario_empaque'',d.destinatario_empaque);');
  IF position('SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario;' in f)=0 THEN RAISE EXCEPTION 'Revisar generador LE'; END IF;
  f:=replace(f,'SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario;',$x$
   -- DESTINO_EMPAQUE_V82: conserva el destinatario impreso al empacar.
   IF d.destinatario_id IS NOT NULL THEN
    IF p_destinatario IS DISTINCT FROM d.destinatario_id THEN RAISE EXCEPTION 'Corrige el empaque para cambiar su destinatario y reimprimir los rótulos'; END IF;
    destino:=d.destinatario_empaque;
   ELSE SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario; END IF;
  $x$);
  EXECUTE f;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb) FROM authenticated;
REVOKE ALL ON FUNCTION public.guardar_empaque_destinatario(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text),public.destinatarios_para_empaque() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.guardar_empaque_destinatario(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text),public.destinatarios_para_empaque() TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 084_seguimiento_entregas.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE TABLE IF NOT EXISTS public.seguimiento_entregas(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), revision integer NOT NULL,
 transportadora text NOT NULL DEFAULT '', placa_guia text NOT NULL DEFAULT '', recibido date,
 evidencia_le jsonb, evidencia_guia jsonb, observaciones text NOT NULL DEFAULT '',
 version integer NOT NULL DEFAULT 1, actualizado_en timestamptz NOT NULL DEFAULT now(), actualizado_por uuid,
 PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.seguimiento_entregas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.seguimiento_entregas FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.fila ORDER BY x.numero DESC) FROM (
 SELECT l.numero, jsonb_build_object('id',d.id,'revision',d.ediciones,'le',l.numero,'cliente',d.cliente,'fecha',d.fecha,
 'cajas',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria'))='CAJA') a),
 'empaques',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria')) IN ('BOLSA','EMPAQUE')) a),
 'transportadora',coalesce(s.transportadora,''),'placa_guia',coalesce(s.placa_guia,''),'recibido',s.recibido,
 'evidencia_le',s.evidencia_le,'evidencia_guia',s.evidencia_guia,'observaciones',coalesce(s.observaciones,''),'version',coalesce(s.version,0)) fila
 FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id
 LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 WHERE d.fase='despachado' AND (p_antes IS NULL OR l.numero<p_antes)
 ORDER BY l.numero DESC LIMIT 200) x),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; v integer; f date; k text; a jsonb;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.fase<>'despachado' OR d.ediciones<>p_revision THEN RAISE EXCEPTION 'La LE cambió o volvió a empaque. Actualiza Seguimiento'; END IF;
 SELECT version INTO v FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision;
 IF coalesce(v,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Otra persona actualizó esta LE. Recarga antes de guardar'; END IF;
 IF length(coalesce(p_datos->>'transportadora',''))>150 OR length(coalesce(p_datos->>'placa_guia',''))>150 OR length(coalesce(p_datos->>'observaciones',''))>3000 THEN RAISE EXCEPTION 'Los textos superan el tamaño permitido'; END IF;
 f:=nullif(p_datos->>'recibido','')::date;
 IF f IS NOT NULL AND (f<(d.fecha AT TIME ZONE 'America/Bogota')::date OR f>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'La recepción debe estar entre el despacho y hoy'; END IF;
 FOREACH k IN ARRAY ARRAY['evidencia_le','evidencia_guia'] LOOP
  a:=p_datos->k;
  IF a IS NOT NULL AND a<>'null'::jsonb THEN
   IF jsonb_typeof(a)<>'object' OR nullif(a->>'nombre','') IS NULL OR length(a->>'nombre')>255 OR coalesce(a->>'path','') NOT LIKE p_id::text||'/'||p_revision||'/'||k||'/%' THEN RAISE EXCEPTION 'Evidencia inválida'; END IF;
   IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='seguimiento-evidencias' AND name=a->>'path') THEN RAISE EXCEPTION 'La evidencia no terminó de cargarse'; END IF;
  END IF;
 END LOOP;
 INSERT INTO public.seguimiento_entregas(despacho_id,revision,transportadora,placa_guia,recibido,evidencia_le,evidencia_guia,observaciones,version,actualizado_por)
 VALUES(p_id,p_revision,trim(coalesce(p_datos->>'transportadora','')),trim(coalesce(p_datos->>'placa_guia','')),f,nullif(p_datos->'evidencia_le','null'::jsonb),nullif(p_datos->'evidencia_guia','null'::jsonb),coalesce(p_datos->>'observaciones',''),coalesce(v,0)+1,auth.uid())
 ON CONFLICT(despacho_id,revision) DO UPDATE SET transportadora=excluded.transportadora,placa_guia=excluded.placa_guia,recibido=excluded.recibido,evidencia_le=excluded.evidencia_le,evidencia_guia=excluded.evidencia_guia,observaciones=excluded.observaciones,version=excluded.version,actualizado_por=excluded.actualizado_por,actualizado_en=now();
 RETURN coalesce(v,0)+1;
END $$;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('seguimiento-evidencias','seguimiento-evidencias',false,10485760,ARRAY['application/pdf','image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
CREATE OR REPLACE FUNCTION public.seguimiento_archivo_permitido(p_name text,p_escritura boolean) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT public.le_acceso() AND EXISTS(SELECT 1 FROM public.despachos_oc d WHERE d.id::text=split_part(p_name,'/',1)
 AND (NOT p_escritura OR (d.fase='despachado' AND d.ediciones::text=split_part(p_name,'/',2)))
 AND split_part(p_name,'/',3) IN ('evidencia_le','evidencia_guia'));
$$;
DROP POLICY IF EXISTS seguimiento_archivo_leer ON storage.objects;
CREATE POLICY seguimiento_archivo_leer ON storage.objects FOR SELECT TO authenticated USING(bucket_id='seguimiento-evidencias' AND public.seguimiento_archivo_permitido(name,false));
DROP POLICY IF EXISTS seguimiento_archivo_subir ON storage.objects;
CREATE POLICY seguimiento_archivo_subir ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='seguimiento-evidencias' AND public.seguimiento_archivo_permitido(name,true));

DROP POLICY IF EXISTS seguimiento_archivo_limitar_lectura ON storage.objects;
CREATE POLICY seguimiento_archivo_limitar_lectura ON storage.objects AS RESTRICTIVE FOR SELECT TO public USING(bucket_id<>'seguimiento-evidencias' OR public.seguimiento_archivo_permitido(name,false));
DROP POLICY IF EXISTS seguimiento_archivo_limitar_alta ON storage.objects;
CREATE POLICY seguimiento_archivo_limitar_alta ON storage.objects AS RESTRICTIVE FOR INSERT TO public WITH CHECK(bucket_id<>'seguimiento-evidencias' OR public.seguimiento_archivo_permitido(name,true));
DROP POLICY IF EXISTS seguimiento_archivo_inmutable ON storage.objects;
CREATE POLICY seguimiento_archivo_inmutable ON storage.objects AS RESTRICTIVE FOR UPDATE TO public USING(bucket_id<>'seguimiento-evidencias');
DROP POLICY IF EXISTS seguimiento_archivo_conservar ON storage.objects;
CREATE POLICY seguimiento_archivo_conservar ON storage.objects AS RESTRICTIVE FOR DELETE TO public USING(bucket_id<>'seguimiento-evidencias');
REVOKE ALL ON FUNCTION public.seguimiento_entregas_listar(bigint),public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_listar(bigint),public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 085_estados_seguimiento.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.seguimiento_entregas ADD COLUMN IF NOT EXISTS estado text;
UPDATE public.seguimiento_entregas SET estado=CASE WHEN recibido IS NOT NULL THEN 'entregado' ELSE 'en_transito' END WHERE estado IS NULL;
ALTER TABLE public.seguimiento_entregas ALTER COLUMN estado SET DEFAULT 'en_transito';
ALTER TABLE public.seguimiento_entregas ALTER COLUMN estado SET NOT NULL;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.seguimiento_entregas'::regclass AND conname='seguimiento_estado_valido') THEN
  ALTER TABLE public.seguimiento_entregas ADD CONSTRAINT seguimiento_estado_valido CHECK(estado IN ('en_transito','entregado','devuelto_cliente'));
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.fila ORDER BY x.numero DESC) FROM (
 SELECT l.numero, jsonb_build_object('id',d.id,'revision',d.ediciones,'le',l.numero,'cliente',d.cliente,'fecha',d.fecha,
 'cajas',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria'))='CAJA') a),
 'empaques',(SELECT count(*) FROM (SELECT DISTINCT e->>'numero' FROM jsonb_array_elements(l.datos->'empaques') e WHERE upper(trim(e->>'categoria')) IN ('BOLSA','EMPAQUE')) a),
 'transportadora',coalesce(s.transportadora,''),'placa_guia',coalesce(s.placa_guia,''),'recibido',s.recibido,'estado',coalesce(s.estado,'en_transito'),
 'evidencia_le',s.evidencia_le,'evidencia_guia',s.evidencia_guia,'observaciones',coalesce(s.observaciones,''),'version',coalesce(s.version,0)) fila
 FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id
 LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 WHERE d.fase='despachado' AND (p_antes IS NULL OR l.numero<p_antes)
 ORDER BY l.numero DESC LIMIT 200) x),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; v integer; f date; k text; a jsonb;
BEGIN
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.fase<>'despachado' OR d.ediciones<>p_revision THEN RAISE EXCEPTION 'La LE cambió o volvió a empaque. Actualiza Seguimiento'; END IF;
 SELECT version INTO v FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision;
 IF coalesce(v,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Otra persona actualizó esta LE. Recarga antes de guardar'; END IF;
 IF length(coalesce(p_datos->>'transportadora',''))>150 OR length(coalesce(p_datos->>'placa_guia',''))>150 OR length(coalesce(p_datos->>'observaciones',''))>3000 THEN RAISE EXCEPTION 'Los textos superan el tamaño permitido'; END IF;
 f:=nullif(p_datos->>'recibido','')::date;
 IF f IS NOT NULL AND (f<(d.fecha AT TIME ZONE 'America/Bogota')::date OR f>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'La recepción debe estar entre el despacho y hoy'; END IF;
 FOREACH k IN ARRAY ARRAY['evidencia_le','evidencia_guia'] LOOP
  a:=p_datos->k;
  IF a IS NOT NULL AND a<>'null'::jsonb THEN
   IF jsonb_typeof(a)<>'object' OR nullif(a->>'nombre','') IS NULL OR length(a->>'nombre')>255 OR coalesce(a->>'path','') NOT LIKE p_id::text||'/'||p_revision||'/'||k||'/%' THEN RAISE EXCEPTION 'Evidencia inválida'; END IF;
   IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='seguimiento-evidencias' AND name=a->>'path') THEN RAISE EXCEPTION 'La evidencia no terminó de cargarse'; END IF;
  END IF;
 END LOOP;
 INSERT INTO public.seguimiento_entregas(despacho_id,revision,transportadora,placa_guia,recibido,evidencia_le,evidencia_guia,observaciones,version,actualizado_por,estado)
 VALUES(p_id,p_revision,trim(coalesce(p_datos->>'transportadora','')),trim(coalesce(p_datos->>'placa_guia','')),f,nullif(p_datos->'evidencia_le','null'::jsonb),nullif(p_datos->'evidencia_guia','null'::jsonb),coalesce(p_datos->>'observaciones',''),coalesce(v,0)+1,auth.uid(),coalesce(p_datos->>'estado',(SELECT estado FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision),CASE WHEN f IS NOT NULL THEN 'entregado' ELSE 'en_transito' END))
 ON CONFLICT(despacho_id,revision) DO UPDATE SET transportadora=excluded.transportadora,placa_guia=excluded.placa_guia,recibido=excluded.recibido,evidencia_le=excluded.evidencia_le,evidencia_guia=excluded.evidencia_guia,observaciones=excluded.observaciones,version=excluded.version,actualizado_por=excluded.actualizado_por,actualizado_en=now(),estado=excluded.estado;
 RETURN coalesce(v,0)+1;
END $$;
NOTIFY pgrst,'reload schema';


-- Adaptación 086_devolucion_parcial_seguimiento.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.seguimiento_entregas DROP CONSTRAINT IF EXISTS seguimiento_estado_valido;
ALTER TABLE public.seguimiento_entregas ADD CONSTRAINT seguimiento_estado_valido
 CHECK(estado IN ('en_transito','entregado','devuelto_cliente','devolucion_parcial'));
NOTIFY pgrst,'reload schema';


-- Adaptación 087_trazabilidad_op.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.seguimiento_entregas ADD COLUMN IF NOT EXISTS numero_guia text NOT NULL DEFAULT '';
ALTER TABLE public.seguimiento_entregas ADD COLUMN IF NOT EXISTS placa text NOT NULL DEFAULT '';
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS fecha_empacado timestamptz;

UPDATE public.despachos_oc SET fecha_empacado=fecha WHERE fase='empacado' AND fecha_empacado IS NULL;
CREATE OR REPLACE FUNCTION public.traza_fecha_empaque() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
 IF NEW.fase='empacado' THEN NEW.fecha_empacado:=now(); END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS traza_fecha_empaque ON public.despachos_oc;
CREATE TRIGGER traza_fecha_empaque BEFORE INSERT OR UPDATE OF fase ON public.despachos_oc FOR EACH ROW EXECUTE FUNCTION public.traza_fecha_empaque();
DO $$ BEGIN
 IF to_regprocedure('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)') IS NULL THEN
 ALTER FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb) RENAME TO seguimiento_guardar_base_v87;
 ALTER FUNCTION public.seguimiento_entregas_listar(bigint) RENAME TO seguimiento_listar_base_v87;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.seguimiento_listar_base_v87(bigint) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v integer;
BEGIN
 IF length(coalesce(p_datos->>'numero_guia',''))>150 OR length(coalesce(p_datos->>'placa',''))>150 THEN RAISE EXCEPTION 'Guía y placa admiten hasta 150 caracteres'; END IF;
 v:=public.seguimiento_guardar_base_v87(p_id,p_revision,p_version,p_datos);
 UPDATE public.seguimiento_entregas SET numero_guia=CASE WHEN p_datos ? 'numero_guia' THEN trim(coalesce(p_datos->>'numero_guia','')) ELSE numero_guia END,
 placa=CASE WHEN p_datos ? 'placa' THEN trim(coalesce(p_datos->>'placa','')) ELSE placa END WHERE despacho_id=p_id AND revision=p_revision;
 RETURN v;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.seguimiento_listar_base_v87(p_antes);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('numero_guia',coalesce(s.numero_guia,''),'placa',coalesce(s.placa,'')) ORDER BY (f.value->>'le')::bigint DESC)
 FROM jsonb_array_elements(filas) f LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=(f.value->>'id')::uuid AND s.revision=(f.value->>'revision')::integer),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.admin_trazabilidad_op(p_op text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador' USING ERRCODE='42501'; END IF;
 WITH items AS (
  SELECT k.*, i.orden_id FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id
  WHERE k.admin_eliminado_en IS NULL AND (coalesce(p_op,'')='' OR k.numero_op ILIKE '%'||p_op||'%')
 ), progreso AS (
  SELECT m.item_orden_id,m.fecha,row_number() OVER w pos,
   sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'envio_aliado' THEN -m.cantidad WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END) OVER w prod,
   sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) OVER w rec
  FROM public.movimientos m JOIN items i ON i.item_orden_id=m.item_orden_id
  WINDOW w AS (PARTITION BY m.item_orden_id ORDER BY m.fecha,m.id ROWS UNBOUNDED PRECEDING)
 ), completado AS (
  SELECT i.*,
   (SELECT min(p.fecha) FROM progreso p WHERE p.item_orden_id=i.item_orden_id AND p.prod>=i.cantidad_pedida AND p.pos>coalesce((SELECT max(q.pos) FROM progreso q WHERE q.item_orden_id=i.item_orden_id AND q.prod<i.cantidad_pedida),0)) fecha_produccion,
   (SELECT min(p.fecha) FROM progreso p WHERE p.item_orden_id=i.item_orden_id AND p.rec>=i.cantidad_pedida AND p.pos>coalesce((SELECT max(q.pos) FROM progreso q WHERE q.item_orden_id=i.item_orden_id AND q.rec<i.cantidad_pedida),0)) fecha_recibido
  FROM items i
 ), op_completa AS (
  SELECT orden_id,bool_and(producido>=cantidad_pedida) produccion_completa,bool_and(recibido>=cantidad_pedida) recepcion_completa,
   CASE WHEN bool_and(fecha_produccion IS NOT NULL) THEN max(fecha_produccion) END fecha_produccion,
   CASE WHEN bool_and(fecha_recibido IS NOT NULL) THEN max(fecha_recibido) END fecha_recibido
  FROM completado GROUP BY orden_id
 ), salidas AS (
  SELECT d.id,d.ediciones,d.fase,d.fecha,d.fecha_empacado,d.empaques,(x->>'item_id')::uuid item_id,sum((x->>'cantidad')::integer) cantidad
  FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.detalle) x GROUP BY d.id,(x->>'item_id')::uuid
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'item_id',i.item_orden_id,'op',i.numero_op,'cliente',i.cliente,'oc',i.oc,'prenda',i.descripcion,'codigo',i.codigo,'talla',i.talla,'cantidad',i.cantidad_pedida,
  'entregado_produccion',i.producido,'recibido_cantidad',i.recibido,'produccion_completa',o.produccion_completa,'recepcion_completa',o.recepcion_completa,
  'fecha_produccion',o.fecha_produccion,'fecha_recibido',o.fecha_recibido,'despacho_id',d.id,'fecha_despachado',d.fecha_empacado,
  'fecha_liberado',CASE WHEN d.fase='despachado' THEN d.fecha END,'cantidad_le',d.cantidad,'le',l.numero,'fase',d.fase,
  'numero_guia',s.numero_guia,'placa',s.placa,'placa_guia_historica',s.placa_guia,'transportadora',s.transportadora,'recibido_cliente',s.recibido,
  'piezas',CASE WHEN d.id IS NOT NULL THEN (SELECT count(DISTINCT e->>'numero') FROM jsonb_array_elements(d.empaques) e WHERE e->>'item_id'=i.item_orden_id::text) END
 ) ORDER BY i.numero_op,i.codigo,i.talla,l.numero),'[]') INTO resultado
 FROM items i JOIN op_completa o USING(orden_id) LEFT JOIN salidas d ON d.item_id=i.item_orden_id
 LEFT JOIN public.listas_empaque l ON l.despacho_id=d.id LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_op(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_trazabilidad_op(text) TO authenticated;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb),public.seguimiento_entregas_listar(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar(uuid,integer,integer,jsonb),public.seguimiento_entregas_listar(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar_v87(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT public.seguimiento_entregas_guardar(p_id,p_revision,p_version,p_datos);
$$;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar_v87(uuid,integer,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Adaptación 088_no_conforme_stock_disponible.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.validar_stock_no_conforme(p_item uuid,p_cantidad integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE disponible bigint; reservado bigint; ubicable bigint;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN
  RAISE EXCEPTION 'Se requiere Logistica o Administrador' USING ERRCODE='42501';
 END IF;
 IF p_cantidad IS NULL OR p_cantidad<=0 THEN RAISE EXCEPTION 'La cantidad debe ser mayor a 0'; END IF;
 -- Mismo bloqueo que las operaciones de stock: el saldo no puede cambiar entre validar e insertar.
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos IN SHARE ROW EXCLUSIVE MODE;
 LOCK TABLE public.reservas_despacho IN SHARE ROW EXCLUSIVE MODE;
 SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
   WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO disponible
 FROM public.movimientos WHERE item_orden_id=p_item;
 SELECT coalesce(sum(cantidad),0) INTO reservado FROM public.reservas_despacho WHERE item_id=p_item;
 IF p_cantidad>disponible-reservado THEN
  RAISE EXCEPTION 'LÍMITE EXCEDIDO: quedan % prendas disponibles sin reservar en Bodega (% en bodega, % reservadas).',greatest(0,disponible-reservado),disponible,reservado;
 END IF;
 SELECT coalesce(sum(greatest(0,s.stock-coalesce(r.cantidad,0))),0) INTO ubicable
 FROM (SELECT ubicacion_id,sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END) stock
 FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id IS NOT NULL GROUP BY ubicacion_id) s
 LEFT JOIN (SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item GROUP BY ubicacion_id) r USING(ubicacion_id);
 IF p_cantidad>ubicable THEN RAISE EXCEPTION 'No hay suficientes prendas disponibles en estantes. Revisa las ubicaciones antes de devolver.'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.validar_stock_no_conforme(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.validar_stock_no_conforme(uuid,integer) TO authenticated;

DO $$ DECLARE r record; definicion text; cantidad integer:=0; BEGIN
 FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='registrar_no_conforme' LOOP
  definicion:=pg_get_functiondef(r.oid);
  IF position('public.validar_stock_no_conforme(p_item_orden_id, p_cantidad)' in definicion)=0 THEN
   IF definicion !~* E'\nBEGIN' THEN RAISE EXCEPTION 'Revisar función registrar_no_conforme'; END IF;
   definicion:=regexp_replace(definicion,E'\nBEGIN',E'\nBEGIN\n PERFORM public.validar_stock_no_conforme(p_item_orden_id, p_cantidad);','i');
   -- Retira las unidades de estantes con stock libre para impedir que luego se vuelvan a despachar.
   IF position('insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)' in definicion)=0 THEN
     RAISE EXCEPTION 'Revisar inserción de devolución: definición inesperada';
   END IF;
   definicion:=replace(definicion,
     'insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)',
     'insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota, ubicacion_id)');
   IF position($old$values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);$old$ in definicion)=0 THEN
     RAISE EXCEPTION 'Revisar valores de devolución: definición inesperada';
   END IF;
   definicion:=replace(definicion,$old$values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);$old$,$new$
   WITH stock AS (
    SELECT ubicacion_id,sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END) cantidad
    FROM public.movimientos WHERE item_orden_id=p_item_orden_id AND ubicacion_id IS NOT NULL GROUP BY ubicacion_id
   ), libres AS (
    SELECT s.ubicacion_id,greatest(0,s.cantidad-coalesce(r.cantidad,0)) cantidad FROM stock s
    LEFT JOIN (SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item_orden_id GROUP BY ubicacion_id) r USING(ubicacion_id)
   ), reparto AS (
    SELECT ubicacion_id,least(cantidad,greatest(0,p_cantidad-coalesce(sum(cantidad) OVER(ORDER BY ubicacion_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING),0))) cantidad FROM libres
   )
   SELECT 'devolucion_produccion',p_item_orden_id,cantidad::integer,v_usuario_id,p_nota,ubicacion_id FROM reparto WHERE cantidad>0;
   $new$);
   EXECUTE definicion;
  END IF;
  cantidad:=cantidad+1;
 END LOOP;
 IF cantidad<>2 THEN RAISE EXCEPTION 'Se esperaban ambas firmas de registrar_no_conforme'; END IF;
END $$;
NOTIFY pgrst,'reload schema';


-- Adaptación 089_permisos_seguimiento.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere migracion 087'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_acceso() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','seguimiento'))
$$;
REVOKE ALL ON FUNCTION public.seguimiento_acceso() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_acceso() TO authenticated;


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


-- Completa las suscripciones usadas por el repositorio sin quitar tablas existentes.
DO $$ DECLARE tabla text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
  FOREACH tabla IN ARRAY ARRAY['items_orden','ordenes_produccion','movimientos','lotes','lote_items','reservas_despacho'] LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=tabla) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',tabla);
   END IF;
  END LOOP;
 END IF;
END $$;
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
END $$;
-- Consecutivo confirmado por el usuario: próxima LE 3000 por instrucción expresa del usuario.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero>=3000) THEN RAISE EXCEPTION 'Consecutivo LE ocupado'; END IF;
 IF EXISTS(SELECT 1 FROM public.lista_empaque_config WHERE siguiente IS NOT NULL) THEN RAISE EXCEPTION 'Consecutivo ya configurado'; END IF;
 UPDATE public.lista_empaque_config SET siguiente=3000 WHERE id=true;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
