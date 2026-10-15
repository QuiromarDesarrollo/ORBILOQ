-- SOLO ORBILOQ-DEV. Requiere 094. No modifica destinatarios ni LE existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
END $$;
-- Requiere 094. Conserva UUID e instantáneas de despachos ya registrados.
CREATE OR REPLACE FUNCTION public.admin_destinatario_editar(p_id uuid, p_original jsonb, p_datos jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE anterior jsonb; k text; campo text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 SELECT datos INTO anterior FROM public.destinatarios_empaque WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El destinatario ya no existe. Actualiza el catálogo.'; END IF;
 IF anterior IS DISTINCT FROM p_original THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo antes de editar.'; END IF;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR length(p_datos::text)>10000 OR coalesce(length(btrim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'Datos del destinatario inválidos';
 END IF;
 FOR campo IN SELECT jsonb_object_keys(p_datos) LOOP
  IF jsonb_typeof(p_datos->campo) IS DISTINCT FROM 'string' OR length(p_datos->>campo)>500 THEN RAISE EXCEPTION 'Campo inválido: %',campo; END IF;
 END LOOP;
 IF coalesce(p_datos->>'tipo_destinatario','nacional') NOT IN ('nacional','internacional') THEN RAISE EXCEPTION 'Tipo de destinatario inválido'; END IF;
 IF p_datos->>'tipo_destinatario'='internacional' THEN
  FOREACH campo IN ARRAY ARRAY['email','via','tipo_carga','embalaje','puerto_embarque','pais_origen','puerto_destino','pais_destino','termino_negociacion'] LOOP
   IF coalesce(length(btrim(p_datos->>campo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Completa el campo internacional: %',campo; END IF;
  END LOOP;
  k:=md5(jsonb_build_array('internacional',p_datos->>'nombre',p_datos->>'nit',p_datos->>'direccion',p_datos->>'ciudad',p_datos->>'contacto',p_datos->>'telefono',p_datos->>'celular',coalesce(nullif(btrim(p_datos->>'sede'),''),''))::text);
 ELSE
  k:=md5(jsonb_build_array(p_datos->>'nombre',p_datos->>'nit',p_datos->>'direccion',p_datos->>'ciudad',p_datos->>'contacto',p_datos->>'telefono',p_datos->>'celular')::text);
  IF nullif(btrim(p_datos->>'sede'),'') IS NOT NULL THEN k:=md5(jsonb_build_array(k,btrim(p_datos->>'sede'))::text); END IF;
 END IF;
 UPDATE public.destinatarios_empaque SET datos=p_datos,clave=k WHERE id=p_id;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Ya existe un destinatario con esos mismos datos. No se combinaron los registros.';
END $$;
CREATE OR REPLACE FUNCTION public.admin_destinatario_eliminar(p_id uuid, p_original jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE anterior jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 SELECT datos INTO anterior FROM public.destinatarios_empaque WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El destinatario ya no existe. Actualiza el catálogo.'; END IF;
 IF anterior IS DISTINCT FROM p_original THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo antes de eliminar.'; END IF;
 DELETE FROM public.destinatarios_empaque WHERE id=p_id;
EXCEPTION WHEN foreign_key_violation THEN
 RAISE EXCEPTION 'No se puede eliminar: tiene despachos vinculados. Puedes editarlo; los documentos existentes conservarán sus datos.';
END $$;
REVOKE ALL ON FUNCTION public.admin_destinatario_editar(uuid,jsonb,jsonb),public.admin_destinatario_eliminar(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_destinatario_editar(uuid,jsonb,jsonb),public.admin_destinatario_eliminar(uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
