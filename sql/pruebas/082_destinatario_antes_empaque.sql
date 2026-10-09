-- SOLO ORBILOQ-DEV. Requiere 081. Ejecutar completo; no reinstalar las migraciones anteriores.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario DEV'; END IF;
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
COMMIT;
