-- SOLO ORBILOQ-DEV. Requiere 070. Ejecutar completo. No modifica despachos antiguos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
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
COMMIT;
