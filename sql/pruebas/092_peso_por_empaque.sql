-- SOLO ORBILOQ-DEV. Requiere 090; compatible con 091. No modifica documentos históricos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere 090'; END IF;
END $$;
-- peso_neto_kg del catálogo conserva el significado de tara por compatibilidad.
-- En cada despacho se guardan explícitamente tara, bruto real y neto (bruto - tara).
ALTER TABLE public.empaques ALTER COLUMN peso_bruto_kg DROP NOT NULL;
CREATE OR REPLACE FUNCTION public.admin_empaque_guardar_v92(p_id uuid,p_version text,p_datos jsonb) RETURNS jsonb
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
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['largo_cm','ancho_cm','alto_cm','peso_neto_kg']) k
   WHERE jsonb_typeof(p_datos->k) IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Medidas y pesos deben ser numeros.'; END IF;
 IF p_id IS NOT NULL THEN
   SELECT to_jsonb(e) INTO anterior FROM public.empaques e WHERE id=p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza la lista.'; END IF;
   UPDATE public.empaques SET nombre=trim(p_datos->>'nombre'),categoria=p_datos->>'categoria',
     largo_cm=(p_datos->>'largo_cm')::numeric,ancho_cm=(p_datos->>'ancho_cm')::numeric,alto_cm=(p_datos->>'alto_cm')::numeric,
     peso_neto_kg=(p_datos->>'peso_neto_kg')::numeric,peso_bruto_kg=NULL,activo=(p_datos->>'activo')::boolean
   WHERE id=p_id RETURNING to_jsonb(empaques.*) INTO nuevo;
 ELSE
   INSERT INTO public.empaques(nombre,categoria,largo_cm,ancho_cm,alto_cm,peso_neto_kg,peso_bruto_kg,activo)
   VALUES(trim(p_datos->>'nombre'),p_datos->>'categoria',(p_datos->>'largo_cm')::numeric,(p_datos->>'ancho_cm')::numeric,
     (p_datos->>'alto_cm')::numeric,(p_datos->>'peso_neto_kg')::numeric,NULL,(p_datos->>'activo')::boolean)
   RETURNING to_jsonb(empaques.*) INTO nuevo;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues)
 VALUES(auth.uid(),'empaques',(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.guardar_empaque_destinatario_v92(
 p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb,p_destinatario uuid,p_destinatario_version text,
 p_id uuid DEFAULT NULL,p_version text DEFAULT NULL,p_motivo text DEFAULT NULL,p_oc_documento text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE a public.usuarios%rowtype; previo public.empaque_solicitudes%rowtype; destino jsonb; r jsonb; copia jsonb;
 pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques,
 'destinatario',p_destinatario,'destinatario_version',p_destinatario_version,'id',p_id,'version',p_version,'motivo',p_motivo,'oc_documento',nullif(btrim(p_oc_documento),''));
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 IF length(btrim(p_oc_documento))>150 THEN RAISE EXCEPTION 'La OC del despacho permite máximo 150 caracteres'; END IF;
 SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.empaque_solicitudes WHERE solicitud=p_solicitud;
 IF FOUND THEN
  IF previo.actor<>a.id OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada para otro empaque'; END IF;
  RETURN previo.resultado;
 END IF;
 -- Cada número es una pieza física; sus OP/tallas comparten un único peso.
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Empaques inválidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e
   WHERE jsonb_typeof(e->'peso_bruto_kg') IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Indica el peso bruto de cada caja o paquete'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e
   WHERE (e->>'peso_bruto_kg')::numeric<=0 OR (e->>'peso_bruto_kg')::numeric>100000) THEN RAISE EXCEPTION 'Peso bruto fuera de rango'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e GROUP BY e->>'numero'
   HAVING count(DISTINCT (e->>'peso_bruto_kg')::numeric)>1) THEN RAISE EXCEPTION 'Todas las prendas del mismo empaque deben compartir su peso bruto'; END IF;
 LOCK TABLE public.empaques IN SHARE MODE;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x JOIN public.empaques e ON e.id=(x->>'empaque_id')::uuid
   WHERE (x->>'peso_bruto_kg')::numeric<e.peso_neto_kg) THEN RAISE EXCEPTION 'El peso bruto no puede ser menor que la tara'; END IF;
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
 UPDATE public.despachos_oc SET oc_documento=nullif(btrim(p_oc_documento),''),destinatario_id=p_destinatario,destinatario_empaque=destino,empacado_por=a.nombre WHERE id=(r->>'id')::uuid;
 SELECT jsonb_agg(e.value||jsonb_build_object(
   'peso_tara_kg',(e.value->>'peso_neto_kg')::numeric,
   'peso_bruto_kg',(p_empaques->(e.ordinality::integer-1)->>'peso_bruto_kg')::numeric,
   'peso_neto_kg',(p_empaques->(e.ordinality::integer-1)->>'peso_bruto_kg')::numeric-(e.value->>'peso_neto_kg')::numeric
 ) ORDER BY e.ordinality) INTO copia
 FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.empaques) WITH ORDINALITY e WHERE d.id=(r->>'id')::uuid;
 UPDATE public.despachos_oc SET empaques=copia WHERE id=(r->>'id')::uuid;
 r:=r||jsonb_build_object('empaques',copia);
 INSERT INTO public.empaque_solicitudes(solicitud,actor,pedido,resultado) VALUES(p_solicitud,a.id,pedido,r);
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb),public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb),public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) TO authenticated;
-- Impide que un cliente antiguo omita el peso obligatorio.
REVOKE ALL ON FUNCTION public.admin_empaque_guardar(uuid,text,jsonb),public.guardar_empaque_destinatario(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text),public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
