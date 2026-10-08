-- SOLO ORBILOQ-DEV. Requiere 073 y 079. No ejecutar en producción.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
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

-- Reemitir la LE reservada sin consumir otro consecutivo. Preserva el comportamiento de documentos emitidos.
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
COMMIT;

