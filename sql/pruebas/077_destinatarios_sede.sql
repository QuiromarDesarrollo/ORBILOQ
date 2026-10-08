-- SOLO ORBILOQ-DEV. Requiere 073. Ejecutar completo. No modifica despachos antiguos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
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

COMMIT;
