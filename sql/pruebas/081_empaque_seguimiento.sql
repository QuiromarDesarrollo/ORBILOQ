-- SOLO PRUEBAS. Requiere 080. No ejecutar migraciones anteriores después de esta.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
END $$;
ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check CHECK(rol IN('admin','produccion','logistica','despacho','seguimiento','gerencia'));
DO $$ DECLARE r record; f text; BEGIN
 FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN('despachar_oc','despachar_oc_empaques','despachar_oc_prendas_empaques','historial_despachos_oc','empaques_listar','le_acceso','wms_cuenta_operativa','admin_usuario_guardar','admin_usuario_registrar') LOOP
  f:=pg_get_functiondef(r.oid);
  IF position('''seguimiento''' in f)=0 THEN
   f:=replace(f,'(''admin'',''despacho'')','(''admin'',''despacho'',''seguimiento'')');
   f:=replace(f,'(''admin'',''produccion'',''logistica'',''despacho'')','(''admin'',''produccion'',''logistica'',''despacho'',''seguimiento'')');
   f:=replace(f,'(''admin'',''produccion'',''logistica'',''despacho'',''gerencia'')','(''admin'',''produccion'',''logistica'',''despacho'',''seguimiento'',''gerencia'')');
   EXECUTE f;
  END IF;
 END LOOP;
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS fase text NOT NULL DEFAULT 'despachado' CHECK(fase IN('empacado','despachado'));
CREATE TABLE IF NOT EXISTS public.reservas_despacho(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), item_id uuid NOT NULL REFERENCES public.items_orden(id),
 ubicacion_id uuid NOT NULL REFERENCES public.ubicaciones(id), cantidad integer NOT NULL CHECK(cantidad>0),
 PRIMARY KEY(despacho_id,item_id,ubicacion_id)
);
ALTER TABLE public.reservas_despacho ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reservas_despacho FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reservas_despacho TO authenticated;
DROP POLICY IF EXISTS leer_reservas ON public.reservas_despacho;
CREATE POLICY leer_reservas ON public.reservas_despacho FOR SELECT TO authenticated USING(public.wms_cuenta_activa());
DO $$ BEGIN
 IF to_regprocedure('public.despachar_oc_bultos_base_v81(text,text,text,jsonb,jsonb)') IS NULL THEN
  ALTER FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb) RENAME TO despachar_oc_bultos_base_v81;
  ALTER FUNCTION public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb) RENAME TO corregir_despacho_le_base_v81;
 END IF;
END $$;
-- El corrector interno sigue utilizando la validación de salida original.
DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.corregir_despacho_le_base_v81(uuid,text,text,text,text,text,jsonb,jsonb)'::regprocedure) INTO f;
 EXECUTE replace(f,'public.despachar_oc_bultos(','public.despachar_oc_bultos_base_v81(');
END $$;

CREATE OR REPLACE FUNCTION public.validar_reservas_item(p_item uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; stock bigint; pedido integer; salidas bigint;
BEGIN
 SELECT cantidad_pedida INTO pedido FROM public.items_orden WHERE id=p_item FOR UPDATE;
 FOR r IN SELECT ubicacion_id,sum(cantidad) cantidad FROM public.reservas_despacho WHERE item_id=p_item GROUP BY 1 LOOP
  SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
  INTO stock FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id=r.ubicacion_id;
  IF stock<r.cantidad THEN RAISE EXCEPTION 'Estas prendas están reservadas en una LE. Corrige su empaque antes de retirar o ajustar el stock.'; END IF;
 END LOOP;
 SELECT coalesce(sum(cantidad),0) INTO salidas FROM public.movimientos WHERE item_orden_id=p_item AND tipo='despacho';
 IF EXISTS(SELECT 1 FROM public.reservas_despacho WHERE item_id=p_item) AND
 salidas+(SELECT coalesce(sum(cantidad),0) FROM public.reservas_despacho WHERE item_id=p_item)>pedido THEN
  RAISE EXCEPTION 'Las prendas despachadas y reservadas superan lo pedido';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.proteger_reservas() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF TG_TABLE_NAME='movimientos' THEN
  IF TG_OP<>'INSERT' THEN PERFORM public.validar_reservas_item(OLD.item_orden_id); END IF;
  IF TG_OP<>'DELETE' THEN PERFORM public.validar_reservas_item(NEW.item_orden_id); END IF;
 ELSIF TG_TABLE_NAME='items_orden' THEN PERFORM public.validar_reservas_item(NEW.id);
 ELSE PERFORM public.validar_reservas_item(NEW.item_id); END IF;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS proteger_reservas ON public.movimientos;
CREATE TRIGGER proteger_reservas AFTER INSERT OR UPDATE OR DELETE ON public.movimientos FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();
DROP TRIGGER IF EXISTS proteger_reservas ON public.items_orden;
CREATE TRIGGER proteger_reservas AFTER UPDATE OF cantidad_pedida ON public.items_orden FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();
DROP TRIGGER IF EXISTS proteger_reservas ON public.reservas_despacho;
CREATE TRIGGER proteger_reservas AFTER INSERT OR UPDATE ON public.reservas_despacho FOR EACH ROW EXECUTE FUNCTION public.proteger_reservas();

CREATE OR REPLACE FUNCTION public.reservar_empaque_interno(p_id uuid,p_nuevo boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE d public.despachos_oc%rowtype; n bigint; rev uuid;
BEGIN
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF p_nuevo THEN
  DELETE FROM public.movimientos WHERE despacho_oc_id=p_id;
 ELSE
  SELECT id INTO rev FROM public.despacho_revisiones WHERE despacho_id=p_id ORDER BY edicion DESC LIMIT 1;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,despacho_revision_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,-(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,d.actor_id,p_id,rev,'Corrección reservada para Seguimiento'
  FROM jsonb_array_elements(d.detalle) x;
 END IF;
 INSERT INTO public.reservas_despacho(despacho_id,item_id,ubicacion_id,cantidad)
 SELECT p_id,(x->>'item_id')::uuid,(x->>'ubicacion_id')::uuid,sum((x->>'cantidad')::integer)
 FROM jsonb_array_elements(d.detalle) x GROUP BY 2,3;
 UPDATE public.despachos_oc SET fase='empacado' WHERE id=p_id;
 IF NOT EXISTS(SELECT 1 FROM public.listas_empaque WHERE despacho_id=p_id) THEN
  SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
  IF n IS NULL THEN RAISE EXCEPTION 'Configura el consecutivo LE antes de confirmar el empaque'; END IF;
  INSERT INTO public.listas_empaque(despacho_id,numero,datos) VALUES(p_id,n,'{"pendiente":true}');
  UPDATE public.lista_empaque_config SET siguiente=n+1 WHERE id=true;
 ELSE UPDATE public.listas_empaque SET datos='{"pendiente":true}' WHERE despacho_id=p_id;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.despachar_oc_bultos(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE r jsonb;
BEGIN
 r:=public.despachar_oc_bultos_base_v81(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 IF coalesce((r->>'repetido')::boolean,false)=false THEN PERFORM public.reservar_empaque_interno((r->>'id')::uuid,true); END IF;
 RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.corregir_despacho_le(p_id uuid,p_version text,p_solicitud text,p_motivo text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; r jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN
  RETURN public.corregir_despacho_le_base_v81(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF d.fase='empacado' THEN
  DELETE FROM public.reservas_despacho WHERE despacho_id=p_id;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,d.actor_id,p_id,'Revisión interna de empaque'
  FROM jsonb_array_elements(d.detalle) x;
 END IF;
 r:=public.corregir_despacho_le_base_v81(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 PERFORM public.reservar_empaque_interno(p_id,false);
 RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_confirmar(p_id uuid,p_revision integer,p_destinatario uuid,p_datos jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; a public.usuarios%rowtype;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Despacho' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambió. Actualiza Seguimiento antes de confirmar'; END IF;
 IF d.fase='empacado' THEN
  IF NOT EXISTS(SELECT 1 FROM public.destinatarios_empaque WHERE id=p_destinatario) THEN RAISE EXCEPTION 'Selecciona el destinatario'; END IF;
  SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
  DELETE FROM public.reservas_despacho WHERE despacho_id=p_id;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
  SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,a.id,p_id,'Salida confirmada en Seguimiento'
  FROM jsonb_array_elements(d.detalle) x;
  UPDATE public.despachos_oc SET fase='despachado',fecha=now(),actor_id=a.id,actor=a.nombre WHERE id=p_id;
 END IF;
 RETURN public.le_documento(p_id::text,p_destinatario,p_datos,true);
END $$;
-- No se permite emitir un PDF de prendas que siguen reservadas.
DO $$ DECLARE f text; ancla text:='IF NOT FOUND THEN RAISE EXCEPTION ''Despacho inexistente''; END IF;'; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('SEGUIMIENTO_V81' in f)=0 THEN
  IF position(ancla in f)=0 THEN RAISE EXCEPTION 'Revisar RPC de PDF'; END IF;
  EXECUTE replace(f,ancla,ancla||$x$
  -- SEGUIMIENTO_V81
  IF d.fase='empacado' THEN
   IF p_emitir THEN RAISE EXCEPTION 'Confirma la salida desde Seguimiento'; END IF;
   RETURN jsonb_build_object('pendiente',true,'fase',d.fase,'ediciones',d.ediciones,'cliente',d.cliente,'oc',d.oc);
  END IF;
  $x$);
 END IF;
END $$;
-- Enriquece historial para separar empacados de salidas, sin perder movimientos históricos.
DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.historial_despachos_empaques(text)'::regprocedure) INTO f;
 IF position('d.fase' in f)=0 THEN
  f:=replace(f,'le.numero le_numero,d.ediciones','le.numero le_numero,d.ediciones,d.fase');
  f:=replace(f,'le.numero,coalesce(d.ediciones,0)','le.numero,coalesce(d.ediciones,0),coalesce(d.fase,''despachado'')');
  EXECUTE f;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.despachar_oc_bultos_base_v81(text,text,text,jsonb,jsonb),public.corregir_despacho_le_base_v81(uuid,text,text,text,text,text,jsonb,jsonb),public.reservar_empaque_interno(uuid,boolean),public.validar_reservas_item(uuid),public.proteger_reservas() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.despachar_oc(text,text,text,jsonb),public.despachar_oc_empaques(text,text,text,jsonb,jsonb),public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb),public.despachar(uuid,integer,uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb),public.seguimiento_confirmar(uuid,integer,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despachar_oc_bultos(text,text,text,jsonb,jsonb),public.corregir_despacho_le(uuid,text,text,text,text,text,jsonb,jsonb),public.seguimiento_confirmar(uuid,integer,uuid,jsonb) TO authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='reservas_despacho') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.reservas_despacho;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
