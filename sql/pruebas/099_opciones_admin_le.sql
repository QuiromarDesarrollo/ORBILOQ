-- Solo desarrollo. Requiere 092. Opciones administrativas por LE.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.le_ajustes_admin(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id),revision integer NOT NULL,
 numero_anterior bigint,numero_solicitado bigint,fecha_solicitada date,
 fecha_registro timestamptz NOT NULL DEFAULT now(),actor uuid NOT NULL,
 resultado jsonb NOT NULL,PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.le_ajustes_admin ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.le_ajustes_admin FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_confirmar_le(p_id uuid,p_revision integer,p_destinatario uuid,p_datos jsonb DEFAULT '{}',p_numero bigint DEFAULT NULL,p_fecha date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; previo public.le_ajustes_admin%rowtype; r jsonb; anterior bigint; fecha_operativa timestamptz;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF p_numero IS NOT NULL AND (p_numero<1 OR p_numero>9007199254740991) THEN RAISE EXCEPTION 'Numero LE invalido'; END IF;
 IF p_fecha IS NOT NULL AND (p_fecha<'2000-01-01'::date OR p_fecha>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'Fecha de salida invalida'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambio. Actualiza antes de confirmar'; END IF;
 SELECT * INTO previo FROM public.le_ajustes_admin WHERE despacho_id=p_id AND revision=p_revision;
 IF FOUND THEN
  IF previo.numero_solicitado IS DISTINCT FROM p_numero OR previo.fecha_solicitada IS DISTINCT FROM p_fecha THEN RAISE EXCEPTION 'Salida ya confirmada con otros datos'; END IF;
  RETURN previo.resultado;
 END IF;
 IF d.fase<>'empacado' THEN RAISE EXCEPTION 'Solo se pueden ajustar LE por liberar'; END IF;
 PERFORM 1 FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
 SELECT numero INTO anterior FROM public.listas_empaque WHERE despacho_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Falta la LE reservada'; END IF;
 IF p_numero IS NOT NULL THEN
  IF EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=p_numero AND despacho_id<>p_id) THEN RAISE EXCEPTION 'El numero LE ya existe'; END IF;
  UPDATE public.listas_empaque SET numero=p_numero WHERE despacho_id=p_id;
 END IF;
 r:=public.seguimiento_confirmar(p_id,p_revision,p_destinatario,p_datos);
 IF p_fecha IS NOT NULL THEN
  fecha_operativa:=(p_fecha+time '12:00') AT TIME ZONE 'America/Bogota';
  UPDATE public.despachos_oc SET fecha=fecha_operativa WHERE id=p_id;
  -- Solo la salida generada en esta transaccion; no toca correcciones previas.
  UPDATE public.movimientos SET fecha=fecha_operativa WHERE despacho_oc_id=p_id AND tipo='despacho' AND cantidad>0 AND fecha=transaction_timestamp();
  UPDATE public.listas_empaque SET datos=jsonb_set(datos,'{fecha}',to_jsonb(fecha_operativa)) WHERE despacho_id=p_id;
  r:=jsonb_set(r,'{fecha}',to_jsonb(fecha_operativa));
 END IF;
 INSERT INTO public.le_ajustes_admin(despacho_id,revision,numero_anterior,numero_solicitado,fecha_solicitada,actor,resultado)
 VALUES(p_id,p_revision,anterior,p_numero,p_fecha,auth.uid(),r);
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date) TO authenticated;
-- Mantiene el siguiente global. Si un numero manual ya lo ocupa, el automatico
-- avanza solo hasta el primer numero libre cuando le corresponda asignar.
DO $$ DECLARE firma text; f text; ancla text:='INSERT INTO public.listas_empaque(despacho_id,numero,datos)'; BEGIN
 FOREACH firma IN ARRAY ARRAY['public.reservar_empaque_interno(uuid,boolean)','public.le_documento(text,uuid,jsonb,boolean)'] LOOP
  SELECT pg_get_functiondef(firma::regprocedure) INTO f;
  IF position('LE_LIBRE_V99' IN f)=0 THEN
   IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Revisar asignacion de numero en %',firma; END IF;
   f:=replace(f,ancla,$x$-- LE_LIBRE_V99
   WHILE EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n) LOOP n:=n+1; END LOOP;
   INSERT INTO public.listas_empaque(despacho_id,numero,datos)$x$);
   IF firma='public.le_documento(text,uuid,jsonb,boolean)' THEN
    f:=replace(f,'WHILE EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n)', 'WHILE doc.numero IS NULL AND EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n)');
   END IF;
   EXECUTE f;
  END IF;
 END LOOP;
END $$;
DO $$ DECLARE f text; ancla text:='LOCK TABLE public.usuarios IN SHARE MODE;'; BEGIN
 SELECT pg_get_functiondef('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)'::regprocedure) INTO f;
 IF position('MASIVO_ADMIN_V99' IN f)=0 THEN
  IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Revisar guardado de empaques'; END IF;
  EXECUTE replace(f,ancla,ancla||$x$
  -- MASIVO_ADMIN_V99
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e WHERE e->>'admin_masivo'='true') AND NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Empaque masivo exclusivo de Administrador' USING ERRCODE='42501'; END IF;
  $x$);
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
