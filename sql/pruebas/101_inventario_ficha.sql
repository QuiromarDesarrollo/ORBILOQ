-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
ALTER TABLE public.ordenes_produccion ADD COLUMN IF NOT EXISTS nombre_ficha_tecnica text;

CREATE TABLE IF NOT EXISTS public.inventario_transferencias (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), solicitud text UNIQUE NOT NULL,
 item_id uuid NOT NULL REFERENCES public.items_orden(id), ubicacion_id uuid NOT NULL REFERENCES public.ubicaciones(id),
 cliente text NOT NULL, ficha text NOT NULL CHECK(length(trim(ficha))>0),
 cantidad integer NOT NULL CHECK(cantidad>0), motivo text NOT NULL CHECK(length(trim(motivo))>0),
 actor uuid NOT NULL REFERENCES public.usuarios(id), fecha timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventario_reversiones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), solicitud text UNIQUE NOT NULL,
 transferencia uuid NOT NULL REFERENCES public.inventario_transferencias(id),
 cantidad integer NOT NULL CHECK(cantidad>0), motivo text NOT NULL CHECK(length(trim(motivo))>0),
 actor uuid NOT NULL REFERENCES public.usuarios(id), fecha timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventario_despachos (
 solicitud text PRIMARY KEY, transferencia uuid NOT NULL REFERENCES public.inventario_transferencias(id),
 cantidad integer NOT NULL CHECK(cantidad>0), actor uuid NOT NULL REFERENCES public.usuarios(id), pedido jsonb NOT NULL,
 despacho_id uuid UNIQUE REFERENCES public.despachos_oc(id), cancelado boolean NOT NULL DEFAULT false,
 motivo_cancelacion text, cancelado_por uuid REFERENCES public.usuarios(id), cancelado_en timestamptz
);
CREATE TABLE IF NOT EXISTS public.inventario_recepciones (
 solicitud text PRIMARY KEY, actor uuid NOT NULL REFERENCES public.usuarios(id), pedido jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS public.inventario_actualizacion(id boolean PRIMARY KEY DEFAULT true CHECK(id),version bigint NOT NULL DEFAULT 0);
INSERT INTO public.inventario_actualizacion(id) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE public.inventario_actualizacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_actualizacion FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.inventario_actualizacion TO authenticated;
DROP POLICY IF EXISTS inventario_actualizacion_lectura ON public.inventario_actualizacion;
CREATE POLICY inventario_actualizacion_lectura ON public.inventario_actualizacion FOR SELECT TO authenticated USING(public.wms_cuenta_activa());
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='inventario_actualizacion') THEN
 ALTER PUBLICATION supabase_realtime ADD TABLE public.inventario_actualizacion;
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS inventario_transferencia_item_idx ON public.inventario_transferencias(item_id,ubicacion_id);
CREATE INDEX IF NOT EXISTS inventario_reversion_transferencia_idx ON public.inventario_reversiones(transferencia);
CREATE INDEX IF NOT EXISTS inventario_despacho_transferencia_idx ON public.inventario_despachos(transferencia);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['inventario_transferencias','inventario_reversiones','inventario_despachos','inventario_recepciones'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_actor(p_roles text[] DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; BEGIN
 SELECT id INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo
 AND (p_roles IS NULL OR coalesce(nullif(roles,'{}'),ARRAY[rol]) && p_roles);
 IF a IS NULL THEN RAISE EXCEPTION 'Tu perfil no permite esta operación de inventario' USING ERRCODE='42501'; END IF;
 RETURN a;
END $$;

CREATE OR REPLACE VIEW public.inventario_saldos AS
SELECT t.*, t.cantidad-coalesce(r.cantidad,0)-coalesce(d.reservado,0)-coalesce(d.despachado,0) libre,
 coalesce(r.cantidad,0) revertido,coalesce(d.reservado,0) reservado,coalesce(d.despachado,0) despachado
FROM public.inventario_transferencias t
LEFT JOIN LATERAL (SELECT sum(cantidad) cantidad FROM public.inventario_reversiones WHERE transferencia=t.id) r ON true
LEFT JOIN LATERAL (SELECT sum(x.cantidad) FILTER(WHERE o.fase='empacado') reservado,
 sum(x.cantidad) FILTER(WHERE o.fase='despachado') despachado
 FROM public.inventario_despachos x JOIN public.despachos_oc o ON o.id=x.despacho_id WHERE x.transferencia=t.id AND NOT x.cancelado) d ON true;
REVOKE ALL ON public.inventario_saldos FROM PUBLIC,anon,authenticated;

-- El mismo orden de bloqueos que usa Despacho evita dobles consumos concurrentes.
CREATE OR REPLACE FUNCTION public.inventario_bloquear() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$ BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 LOCK TABLE public.inventario_transferencias,public.inventario_reversiones,public.inventario_despachos IN SHARE ROW EXCLUSIVE MODE;
END $$;

-- Disponible de la OP: físico menos inventario libre y TODAS las reservas.
CREATE OR REPLACE FUNCTION public.inventario_disponible_op(p_item uuid,p_ubicacion uuid) RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT coalesce((SELECT sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END)
 FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id=p_ubicacion),0)
 -coalesce((SELECT sum(libre) FROM public.inventario_saldos WHERE item_id=p_item AND ubicacion_id=p_ubicacion),0)
 -coalesce((SELECT sum(cantidad) FROM public.reservas_despacho WHERE item_id=p_item AND ubicacion_id=p_ubicacion),0);
$$;

CREATE OR REPLACE FUNCTION public.inventario_transferir(p_solicitud text,p_item uuid,p_ubicacion uuid,p_cantidad integer,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_transferencias%rowtype; f text; c text; nuevo uuid;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT * INTO previo FROM public.inventario_transferencias WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (previo.actor,previo.item_id,previo.ubicacion_id,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_item,p_ubicacion,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la transferencia'; END IF;
 SELECT trim(o.nombre_ficha_tecnica),o.cliente INTO f,c FROM public.items_orden i JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE i.id=p_item AND i.admin_eliminado_en IS NULL;
 IF nullif(f,'') IS NULL THEN RAISE EXCEPTION 'La OP no tiene ficha técnica. Importa NOMBRE FICHA TECNICA antes de transferir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion AND activa) THEN RAISE EXCEPTION 'Estante no disponible'; END IF;
 IF p_cantidad>public.inventario_disponible_op(p_item,p_ubicacion) THEN RAISE EXCEPTION 'Cantidad superior al stock libre de la OP en ese estante'; END IF;
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES(p_solicitud,p_item,p_ubicacion,c,f,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_revertir(p_solicitud text,p_transferencia uuid,p_cantidad integer,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_reversiones%rowtype; nuevo uuid; disponible bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT * INTO previo FROM public.inventario_reversiones WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (previo.actor,previo.transferencia,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_transferencia,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la reversión'; END IF;
 SELECT libre INTO disponible FROM public.inventario_saldos WHERE id=p_transferencia;
 IF disponible IS NULL OR p_cantidad>disponible THEN RAISE EXCEPTION 'Solo puedes devolver inventario libre. Libera primero sus reservas; las prendas despachadas no son reversibles'; END IF;
 INSERT INTO public.inventario_reversiones(solicitud,transferencia,cantidad,motivo,actor) VALUES(p_solicitud,p_transferencia,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;

-- Comprueba al cierre de la transacción: el empaque crea y retira movimientos
-- temporalmente, pero nunca puede confirmar un saldo utilizado dos veces.
CREATE OR REPLACE FUNCTION public.inventario_validar_stock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; afectados uuid[]; dato jsonb:=coalesce(to_jsonb(NEW),to_jsonb(OLD)); BEGIN
 IF TG_TABLE_NAME='movimientos' THEN afectados:=ARRAY[(dato->>'item_orden_id')::uuid];
 ELSIF TG_TABLE_NAME IN ('reservas_despacho','inventario_transferencias') THEN afectados:=ARRAY[(dato->>'item_id')::uuid];
 ELSIF TG_TABLE_NAME IN ('inventario_reversiones','inventario_despachos') THEN
 SELECT ARRAY[item_id] INTO afectados FROM public.inventario_transferencias WHERE id=(dato->>'transferencia')::uuid;
 ELSE
 SELECT array_agg(t.item_id) INTO afectados FROM public.inventario_despachos d JOIN public.inventario_transferencias t ON t.id=d.transferencia WHERE d.despacho_id=(dato->>'id')::uuid;
 END IF;
 IF TG_OP='UPDATE' AND TG_TABLE_NAME='movimientos' THEN afectados:=afectados||(to_jsonb(OLD)->>'item_orden_id')::uuid; END IF;
 IF TG_OP='UPDATE' AND TG_TABLE_NAME='reservas_despacho' THEN afectados:=afectados||(to_jsonb(OLD)->>'item_id')::uuid; END IF;
 FOR r IN SELECT DISTINCT item_id,ubicacion_id FROM public.inventario_saldos WHERE item_id=ANY(afectados) AND libre+reservado>0 LOOP
 IF public.inventario_disponible_op(r.item_id,r.ubicacion_id)<0 THEN RAISE EXCEPTION 'Stock asignado a inventario o reservado: revierte o libera primero la asignación'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.inventario_saldos WHERE item_id=ANY(afectados) AND libre<0) THEN RAISE EXCEPTION 'Inventario insuficiente'; END IF;
 RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_auditoria_inmutable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$ BEGIN
 RAISE EXCEPTION 'Las transferencias y reversiones son inmutables; registra una operación compensatoria';
END $$;
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_transferencias;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_transferencias FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_reversiones;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_reversiones FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['movimientos','reservas_despacho','inventario_transferencias','inventario_reversiones','inventario_despachos','despachos_oc'] LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS inventario_stock_guard ON public.%I',t);
 EXECUTE format('CREATE CONSTRAINT TRIGGER inventario_stock_guard AFTER INSERT OR UPDATE OR DELETE ON public.%I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.inventario_validar_stock()',t);
 END LOOP;
END $$;

-- Permite otra OC exclusivamente dentro de una solicitud privada de inventario.
-- Nadie puede insertar solicitudes directamente ni habilitarlo con una variable de sesión.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_V101')=0 THEN
 IF strpos(ddl,'item.oc IS DISTINCT FROM p_oc')=0 THEN RAISE EXCEPTION 'Base de despacho inesperada'; END IF;
 ddl:=replace(ddl,'item.oc IS DISTINCT FROM p_oc',E'(item.oc IS DISTINCT FROM p_oc AND NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv JOIN public.inventario_transferencias it ON it.id=inv.transferencia WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id AND it.item_id=item.id AND it.cliente=p_cliente AND NOT inv.cancelado)) /* INVENTARIO_V101 */');
 EXECUTE ddl;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_empacar(p_solicitud text,p_transferencia uuid,p_cantidad integer,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaque uuid,p_empaque_version text,p_peso numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t record; previo public.inventario_despachos%rowtype; r jsonb; pedido jsonb;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 pedido:=jsonb_build_array(p_transferencia,p_cantidad,trim(p_oc),p_destinatario,p_destinatario_version,p_empaque,p_empaque_version,p_peso);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(trim(p_oc)),0) NOT BETWEEN 1 AND 150 OR coalesce(p_cantidad,0)<=0 THEN RAISE EXCEPTION 'Indica OC y cantidad'; END IF;
 SELECT s.*,u.codigo ubicacion INTO t FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id WHERE s.id=p_transferencia;
 IF NOT FOUND OR p_cantidad>t.libre THEN RAISE EXCEPTION 'Inventario libre insuficiente'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,p_transferencia,p_cantidad,a,pedido);
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,t.cliente,trim(p_oc),
 jsonb_build_array(jsonb_build_object('item_id',t.item_id,'ubicacion',t.ubicacion,'cantidad',p_cantidad)),
 jsonb_build_array(jsonb_build_object('numero',1,'item_id',t.item_id,'empaque_id',p_empaque,'version',p_empaque_version,'cantidad',p_cantidad,'peso_bruto_kg',p_peso)),
 p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;

-- Una LE de inventario reservada se cancela para rehacer su empaque; nunca se
-- corrige por la ruta convencional, que podría cambiar el cliente/origen.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CORRECCION_V101')=0 THEN
 ddl:=replace(ddl,'IF p_id IS NULL THEN',E'-- INVENTARIO_CORRECCION_V101\n IF p_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.inventario_despachos WHERE despacho_id=p_id) THEN RAISE EXCEPTION ''Una LE de inventario no admite corrección convencional; cancela su reserva desde Inventario''; END IF;\n IF p_id IS NULL THEN');
 EXECUTE ddl; END IF;
END $$;

ALTER TABLE public.despachos_oc DROP CONSTRAINT IF EXISTS despachos_oc_fase_check;
ALTER TABLE public.despachos_oc ADD CONSTRAINT despachos_oc_fase_check CHECK(fase IN ('empacado','despachado','cancelado'));
CREATE OR REPLACE FUNCTION public.inventario_cancelar(p_despacho uuid,p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; f text; BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF NOT EXISTS(SELECT 1 FROM public.inventario_despachos WHERE despacho_id=p_despacho) THEN RAISE EXCEPTION 'No es una reserva de inventario'; END IF;
 SELECT fase INTO f FROM public.despachos_oc WHERE id=p_despacho;
 IF f='cancelado' THEN RETURN; END IF;
 IF f<>'empacado' THEN RAISE EXCEPTION 'La LE ya salió de bodega; no puede liberarse como reserva'; END IF;
 IF coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica el motivo'; END IF;
 DELETE FROM public.reservas_despacho WHERE despacho_id=p_despacho;
 UPDATE public.inventario_despachos SET cancelado=true,motivo_cancelacion=trim(p_motivo),cancelado_por=a,cancelado_en=now() WHERE despacho_id=p_despacho;
 UPDATE public.despachos_oc SET fase='cancelado' WHERE id=p_despacho;
END $$;
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.seguimiento_confirmar(uuid,integer,uuid,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CANCELADO_V101')=0 THEN
 ddl:=replace(ddl,'IF d.fase=''empacado'' THEN',E'-- INVENTARIO_CANCELADO_V101\n IF d.fase=''cancelado'' THEN RAISE EXCEPTION ''Reserva de inventario cancelada''; END IF;\n IF d.fase=''empacado'' THEN');
 EXECUTE ddl; END IF;
END $$;

DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_PDF_V101')=0 THEN
 ddl:=replace(ddl,'IF d.fase=''empacado'' THEN',E'-- INVENTARIO_PDF_V101\n IF d.fase=''cancelado'' THEN RAISE EXCEPTION ''LE cancelada: no se puede emitir ni reimprimir como salida''; END IF;\n IF d.fase=''empacado'' THEN');
 EXECUTE ddl; END IF;
 -- El ID ERP de la OP de origen no corresponde a la nueva OC de destino.
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NOT NULL THEN
 ddl:=pg_get_functiondef('public.facturacion_le_dato(uuid)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_FACTURA_V101')=0 THEN
 ddl:=replace(ddl,') ids ON true',E' WHERE NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv WHERE inv.despacho_id=d.id) /* INVENTARIO_FACTURA_V101 */\n ) ids ON true');
 EXECUTE ddl; END IF;
 END IF;
END $$;

-- Recepción y asignación en una sola transacción, incluso entre varios lotes.
CREATE OR REPLACE FUNCTION public.inventario_recibir(p_solicitud text,p_plan jsonb,p_ubicacion text,p_recibido_por text,p_nota text,p_inventario integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_recepciones%rowtype; pedido jsonb; u uuid; r record; i uuid; queda integer:=p_inventario; n integer; total integer;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 pedido:=jsonb_build_array(p_plan,p_ubicacion,p_recibido_por,p_nota,p_inventario);
 SELECT * INTO previo FROM public.inventario_recepciones WHERE solicitud=p_solicitud;
 IF FOUND THEN IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF; RETURN; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR jsonb_typeof(p_plan) IS DISTINCT FROM 'array' OR jsonb_array_length(p_plan) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Plan inválido'; END IF;
 SELECT sum((x->>'cantidad')::integer) INTO total FROM jsonb_array_elements(p_plan) x;
 IF p_inventario IS NULL OR p_inventario<0 OR p_inventario>total THEN RAISE EXCEPTION 'Cantidad a inventario fuera de rango'; END IF;
 SELECT id INTO u FROM public.ubicaciones WHERE codigo=p_ubicacion AND activa;
 IF u IS NULL THEN RAISE EXCEPTION 'Estante inválido'; END IF;
 FOR r IN SELECT x->>'linea' linea,(x->>'cantidad')::integer cantidad FROM jsonb_array_elements(p_plan) x LOOP
 IF r.cantidad<=0 THEN RAISE EXCEPTION 'Cantidad inválida'; END IF;
 PERFORM public.recibir_lote_item(r.linea::uuid,r.cantidad,u,p_nota,p_recibido_por);
 n:=least(queda,r.cantidad);
 IF n>0 THEN
 SELECT item_orden_id INTO i FROM public.lote_items WHERE id=r.linea::uuid;
 PERFORM public.inventario_transferir(p_solicitud||':'||r.linea,i,u,n,'Asignación desde recepción');
 queda:=queda-n;
 END IF;
 END LOOP;
 INSERT INTO public.inventario_recepciones VALUES(p_solicitud,a,pedido);
END $$;

CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,coalesce(s.despachado,0) inventario_despachado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN LATERAL (SELECT sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado FROM public.inventario_saldos WHERE item_id=i.id) s ON true
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM componentes WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_detalle(p_cliente text,p_ficha text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.talla,o.numero_op,u.codigo ubicacion,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE s.cliente=p_cliente AND s.ficha=p_ficha ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_origenes(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT i.id item_id,u.id ubicacion_id,o.numero_op,o.cliente,o.nombre_ficha_tecnica ficha,i.descripcion producto,i.talla,u.codigo ubicacion,
 s.cantidad en_bodega,u.activa estante_activo,
 public.inventario_disponible_op(i.id,u.id) disponible
 FROM public.vista_stock_ubicacion_detalle s JOIN public.items_orden i ON i.id=s.item_orden_id
 JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.codigo=s.ubicacion_codigo
 WHERE i.admin_eliminado_en IS NULL
 AND concat_ws(' ',o.numero_op,o.cliente,o.nombre_ficha_tecnica,i.descripcion) ILIKE '%'||trim(coalesce(p_buscar,''))||'%'
 ORDER BY o.numero_op,i.id,u.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN r;
END $$;

-- Lectura paginada para restar inventario de la disponibilidad del kardex normal.
CREATE OR REPLACE FUNCTION public.inventario_saldos_items(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT s.item_id,u.codigo ubicacion,sum(s.libre) libre,sum(s.reservado) reservado,
 s.item_id::text||':'||u.codigo clave
 FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE s.item_id::text||':'||u.codigo>p_despues GROUP BY s.item_id,u.codigo
 HAVING sum(s.libre+s.reservado)>0 ORDER BY s.item_id::text||':'||u.codigo LIMIT 500) t;
 RETURN r;
END $$;

DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure firma,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'inventario_%' LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.firma);
 IF f.proname IN ('inventario_transferir','inventario_revertir','inventario_empacar','inventario_cancelar','inventario_recibir','inventario_listar','inventario_detalle','inventario_origenes','inventario_saldos_items') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.firma); END IF;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
