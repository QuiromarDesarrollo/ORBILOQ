-- Requiere 065. Cantidades de prendas por referencia/talla y empaque. Conserva despachos anteriores.
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
COMMIT;