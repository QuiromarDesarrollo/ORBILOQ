  -- SOLO DEV. Requiere 062. No ejecutar en producción.
  BEGIN;
  SET LOCAL lock_timeout='5s';
  DO $$ BEGIN
   IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS.'; END IF;
   IF to_regprocedure('public.admin_reporte_resumen()') IS NULL THEN RAISE EXCEPTION 'Aplicar primero 062.'; END IF;
  END $$;
  CREATE TABLE IF NOT EXISTS public.despachos_oc (
   id uuid PRIMARY KEY DEFAULT gen_random_uuid(), solicitud text UNIQUE NOT NULL,
   fecha timestamptz NOT NULL DEFAULT now(), actor_id uuid NOT NULL, actor text NOT NULL,
   cliente text NOT NULL, oc text NOT NULL, pedido jsonb NOT NULL, detalle jsonb NOT NULL
  );
  ALTER TABLE public.despachos_oc ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.despachos_oc FROM PUBLIC,anon,authenticated;
  ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS despacho_oc_id uuid REFERENCES public.despachos_oc(id);
  CREATE INDEX IF NOT EXISTS movimientos_despacho_oc_idx ON public.movimientos(despacho_oc_id);
  CREATE OR REPLACE FUNCTION public.despachar_oc(p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb)
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
  DECLARE actor public.usuarios%rowtype; previo public.despachos_oc%rowtype; solicitud_id uuid:=gen_random_uuid();
   r record; item public.items_orden%rowtype; cliente_actual text; stock bigint; pendiente bigint; ubic uuid;
   detalle jsonb:='[]'; pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas);
  BEGIN
   SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
   IF actor.id IS NULL THEN RAISE EXCEPTION 'Se requiere Logística o Administrador activo.' USING ERRCODE='42501'; END IF;
   IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR p_cliente IS NULL OR p_oc IS NULL OR jsonb_typeof(p_lineas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Solicitud inválida.'; END IF;
   IF jsonb_array_length(p_lineas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Selecciona de 1 a 1000 retiros.'; END IF;
   LOCK TABLE public.usuarios IN SHARE MODE;
   LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
   SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
   IF actor.id IS NULL THEN RAISE EXCEPTION 'Cuenta sin acceso.' USING ERRCODE='42501'; END IF;
   SELECT * INTO previo FROM public.despachos_oc WHERE solicitud=p_solicitud;
   IF FOUND THEN
     IF previo.actor_id<>actor.id OR previo.pedido<>pedido THEN RAISE EXCEPTION 'La solicitud ya se usó para otro despacho.'; END IF;
     RETURN jsonb_build_object('id',previo.id,'detalle',previo.detalle,'repetido',true);
   END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_lineas) x WHERE coalesce(x->>'cantidad','') !~ '^[1-9][0-9]*$' OR nullif(x->>'item_id','') IS NULL OR nullif(x->>'ubicacion','') IS NULL) THEN RAISE EXCEPTION 'Cada retiro requiere prenda, estante y cantidad positiva.'; END IF;
   FOR r IN SELECT (x->>'item_id')::uuid item_id,sum((x->>'cantidad')::bigint) cantidad FROM jsonb_array_elements(p_lineas) x GROUP BY 1 LOOP
     SELECT * INTO item FROM public.items_orden WHERE id=r.item_id AND admin_eliminado_en IS NULL;
     IF NOT FOUND THEN RAISE EXCEPTION 'Prenda inexistente u oculta.'; END IF;
     SELECT cliente INTO cliente_actual FROM public.ordenes_produccion WHERE id=item.orden_id;
     IF cliente_actual IS DISTINCT FROM p_cliente OR item.oc IS DISTINCT FROM p_oc THEN RAISE EXCEPTION 'Las prendas deben pertenecer al cliente y OC seleccionados.'; END IF;
     SELECT item.cantidad_pedida-coalesce(sum(cantidad),0) INTO pendiente FROM public.movimientos WHERE item_orden_id=item.id AND tipo='despacho';
     IF r.cantidad>pendiente THEN RAISE EXCEPTION 'La cantidad supera el pendiente de la OP (% Uds).',pendiente; END IF;
     SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
     INTO stock FROM public.movimientos WHERE item_orden_id=item.id;
     IF r.cantidad>stock THEN RAISE EXCEPTION 'Stock total insuficiente para la prenda. Disponible: %.',stock; END IF;
   END LOOP;
   FOR r IN SELECT (x->>'item_id')::uuid item_id,x->>'ubicacion' ubicacion,sum((x->>'cantidad')::bigint) cantidad FROM jsonb_array_elements(p_lineas) x GROUP BY 1,2 ORDER BY 1,2 LOOP
     SELECT id INTO ubic FROM public.ubicaciones WHERE codigo=r.ubicacion AND activa;
     IF ubic IS NULL THEN RAISE EXCEPTION 'Estante inactivo o inexistente.'; END IF;
     SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
     INTO stock FROM public.movimientos WHERE item_orden_id=r.item_id AND ubicacion_id=ubic;
     IF r.cantidad>stock THEN RAISE EXCEPTION 'Stock insuficiente en %. Disponible: %.',r.ubicacion,stock; END IF;
     SELECT * INTO item FROM public.items_orden WHERE id=r.item_id;
     detalle:=detalle||jsonb_build_array(jsonb_build_object('item_id',item.id,'op',(SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id),
       'codigo',item.codigo,'producto',item.descripcion,'talla',item.talla,'ubicacion',r.ubicacion,'ubicacion_id',ubic,'cantidad',r.cantidad));
   END LOOP;
   INSERT INTO public.despachos_oc(id,solicitud,actor_id,actor,cliente,oc,pedido,detalle) VALUES(solicitud_id,p_solicitud,actor.id,actor.nombre,p_cliente,p_oc,pedido,detalle);
   INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
   SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,actor.id,solicitud_id,'Despacho OC '||p_oc FROM jsonb_array_elements(detalle) x;
   RETURN jsonb_build_object('id',solicitud_id,'detalle',detalle,'repetido',false);
  END $$;
  CREATE OR REPLACE FUNCTION public.despachar(p_item_orden_id uuid,p_cantidad integer,p_ubicacion_id uuid) RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
  DECLARE c text; o text; u text;
  BEGIN
   SELECT op.cliente,io.oc INTO c,o FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE io.id=p_item_orden_id;
   SELECT codigo INTO u FROM public.ubicaciones WHERE id=p_ubicacion_id;
   RETURN public.despachar_oc(gen_random_uuid()::text,c,o,jsonb_build_array(jsonb_build_object('item_id',p_item_orden_id,'cantidad',p_cantidad,'ubicacion',u)));
  END $$;
  CREATE OR REPLACE FUNCTION public.historial_despachos_oc(p_despues text DEFAULT '') RETURNS jsonb
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
  DECLARE resultado jsonb;
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Acceso exclusivo de Logística o Administrador.' USING ERRCODE='42501'; END IF;
   SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY registro),'[]') INTO resultado FROM (
   SELECT m.id::text registro,m.fecha,m.cantidad,coalesce(d.cliente,op.cliente) cliente,coalesce(d.oc,io.oc) oc,coalesce(d.actor,u.nombre,'Sin registrar') persona,
   op.numero_op AS op,io.id item_id,io.codigo,io.descripcion producto,io.talla,ub.codigo ubicacion,m.nota,m.despacho_oc_id
   FROM public.movimientos m JOIN public.items_orden io ON io.id=m.item_orden_id JOIN public.ordenes_produccion op ON op.id=io.orden_id
   LEFT JOIN public.usuarios u ON u.id=m.usuario_id LEFT JOIN public.ubicaciones ub ON ub.id=m.ubicacion_id LEFT JOIN public.despachos_oc d ON d.id=m.despacho_oc_id
   WHERE m.tipo='despacho' AND m.id::text>p_despues ORDER BY m.id::text LIMIT 1000
   ) t;
   RETURN resultado;
  END $$;
  REVOKE ALL ON FUNCTION public.despachar_oc(text,text,text,jsonb),public.despachar(uuid,integer,uuid),public.historial_despachos_oc(text) FROM PUBLIC,anon;
  GRANT EXECUTE ON FUNCTION public.despachar_oc(text,text,text,jsonb),public.despachar(uuid,integer,uuid),public.historial_despachos_oc(text) TO authenticated;
  DO $import$ DECLARE f record; ddl text; BEGIN
   FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='importar_ordenes_produccion' LOOP
    ddl:=pg_get_functiondef(f.oid);
    IF strpos(ddl,'ORBILOQ_OC_V63')>0 THEN CONTINUE; END IF;
    IF strpos(ddl,'ORBILOQ_ACTOR_V61')=0 THEN RAISE EXCEPTION 'Importador inesperado. Aplicar primero 061.'; END IF;
    ddl:=replace(ddl,'  insert into importaciones',E'  -- ORBILOQ_OC_V63\n  UPDATE public.items_orden io SET oc=t->>''oc'' FROM jsonb_array_elements(p_tallas) t, public.ordenes_produccion op WHERE io.orden_id=op.id AND op.numero_op=t->>''identificador_orden'' AND io.codigo=t->>''codigo'' AND io.talla=t->>''talla'' AND trim(io.oc)='''' AND coalesce(trim(t->>''oc''),'''')<>'''';\n  insert into importaciones');
    IF strpos(ddl,'ORBILOQ_OC_V63')=0 THEN RAISE EXCEPTION 'No se pudo adaptar el importador.'; END IF;
    EXECUTE ddl;
   END LOOP;
  END $import$;
  NOTIFY pgrst,'reload schema';
  COMMIT;
