-- SOLO ORBILOQ-DEV. Cola transaccional; no envía correos por sí sola.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.entrega_correos(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), revision integer NOT NULL,
 destinatario text NOT NULL, datos jsonb NOT NULL,
 estado text NOT NULL DEFAULT 'pendiente' CHECK(estado IN ('pendiente','enviando','enviado','error','revision_manual')),
 creado_en timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL,
 primer_intento timestamptz, intento_en timestamptz, enviado_en timestamptz,
 proveedor_id text, error text, intentos integer NOT NULL DEFAULT 0,
 envio_iniciado boolean NOT NULL DEFAULT false,
 UNIQUE(despacho_id,revision)
);
ALTER TABLE public.entrega_correos ADD COLUMN IF NOT EXISTS envio_iniciado boolean NOT NULL DEFAULT false;
ALTER TABLE public.entrega_correos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entrega_correos FROM PUBLIC,anon,authenticated;
GRANT SELECT,UPDATE ON public.entrega_correos TO service_role;

CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar_v117(p_id uuid,p_revision integer,p_version integer,p_datos jsonb,p_correo text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v integer; c public.entrega_correos%rowtype; s public.seguimiento_entregas%rowtype; snapshot jsonb; email text:=lower(btrim(coalesce(p_correo,'')));
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 IF email<>'' AND (length(email)>254 OR email !~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$') THEN RAISE EXCEPTION 'Correo de la comercial inválido'; END IF;
 v:=public.seguimiento_entregas_guardar_v87(p_id,p_revision,p_version,p_datos);
 SELECT * INTO s FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision;
 SELECT * INTO c FROM public.entrega_correos WHERE despacho_id=p_id AND revision=p_revision;
 IF email<>'' AND c.id IS NOT NULL AND c.destinatario<>email THEN RAISE EXCEPTION 'Esta entrega ya tiene una notificación registrada para otro correo'; END IF;
 IF email<>'' AND c.id IS NULL THEN
  IF s.estado<>'entregado' OR s.recibido IS NULL THEN RAISE EXCEPTION 'Para notificar, selecciona Entregado e indica la fecha de recibido'; END IF;
  SELECT jsonb_build_object('le',l.numero,'cliente',d.cliente,'oc',d.oc,'destinatario',l.datos->'destinatario',
   'recibido',s.recibido,'numero_guia',s.numero_guia,
   'ops',coalesce((SELECT jsonb_agg(x.op ORDER BY x.op) FROM (
     SELECT DISTINCT o.numero_op op FROM jsonb_array_elements(d.detalle) item
     JOIN public.items_orden i ON i.id=(item->>'item_id')::uuid
     JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE nullif(o.numero_op,'') IS NOT NULL) x),'[]'::jsonb),
   'adjuntos',(SELECT coalesce(jsonb_agg(a),'[]'::jsonb) FROM (VALUES(s.evidencia_le),(s.evidencia_guia)) files(a) WHERE a IS NOT NULL AND a<>'null'::jsonb))
  INTO snapshot FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id WHERE d.id=p_id;
  IF snapshot IS NULL THEN RAISE EXCEPTION 'No se encontró la LE'; END IF;
  INSERT INTO public.entrega_correos(despacho_id,revision,destinatario,datos,creado_por)
  VALUES(p_id,p_revision,email,snapshot,auth.uid()) RETURNING * INTO c;
 END IF;
 RETURN jsonb_build_object('version',v,'correo',CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id',c.id,'destinatario',c.destinatario,'estado',c.estado) END);
END $$;

CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar_v117(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.seguimiento_entregas_listar(p_antes);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('correo',CASE WHEN c.id IS NULL THEN NULL ELSE
 jsonb_build_object('id',c.id,'destinatario',c.destinatario,'estado',c.estado,'error',c.error,'enviado_en',c.enviado_en) END) ORDER BY (f.value->>'le')::bigint DESC)
 FROM jsonb_array_elements(filas) f LEFT JOIN public.entrega_correos c ON c.despacho_id=(f.value->>'id')::uuid AND c.revision=(f.value->>'revision')::integer),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.entrega_correo_consultar(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN (SELECT jsonb_build_object('id',id,'estado',estado,'destinatario',destinatario,'error',error) FROM public.entrega_correos WHERE id=p_id);
END $$;

-- Solo el servidor puede reservar el envío. El bloqueo evita dobles clics concurrentes.
CREATE OR REPLACE FUNCTION public.entrega_correo_reclamar(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE c public.entrega_correos%rowtype;
BEGIN
 SELECT * INTO c FROM public.entrega_correos WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF c.estado IN ('enviado','revision_manual') OR (c.estado='enviando' AND c.intento_en>now()-interval '5 minutes') THEN RETURN NULL; END IF;
 -- Gmail no ofrece clave idempotente: un envío iniciado sin confirmación requiere revisión.
 IF c.envio_iniciado THEN
  UPDATE public.entrega_correos SET estado='revision_manual',error='Comprueba Enviados en Gmail antes de volver a enviar' WHERE id=p_id;
  RETURN NULL;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.despachos_oc d JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 WHERE d.id=c.despacho_id AND d.ediciones=c.revision AND d.fase='despachado' AND s.estado='entregado' AND s.recibido IS NOT NULL) THEN
  UPDATE public.entrega_correos SET estado='revision_manual',error='La entrega cambió; revisa el seguimiento' WHERE id=p_id;
  RETURN NULL;
 END IF;
 UPDATE public.entrega_correos SET estado='enviando',primer_intento=coalesce(primer_intento,now()),intento_en=now(),intentos=intentos+1,error=NULL WHERE id=p_id RETURNING * INTO c;
 RETURN to_jsonb(c);
END $$;
REVOKE ALL ON FUNCTION public.entrega_correo_reclamar(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.entrega_correo_reclamar(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar_v117(uuid,integer,integer,jsonb,text),public.seguimiento_entregas_listar_v117(bigint),public.entrega_correo_consultar(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar_v117(uuid,integer,integer,jsonb,text),public.seguimiento_entregas_listar_v117(bigint),public.entrega_correo_consultar(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
