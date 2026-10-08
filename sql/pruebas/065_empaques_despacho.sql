-- SOLO ORBILOQ-DEV. Ejecutar completo ANTES de usar el nuevo formulario.
-- No borra datos. Conserva RPC anteriores y despachos historicos.
-- Para produccion se preparara una migracion revisada al desplegar.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true) <> 'igfuafcekcpugpmsoqbe' THEN
   RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
   RAISE EXCEPTION 'No coincide el inventario de pruebas. Revisar el proyecto.';
 END IF;
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
-- NULL conserva la distincion: el despacho antiguo no registro empaques.
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

-- Nuevo nombre para evitar ambiguedad de sobrecargas con el cliente anterior.
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
COMMIT;
