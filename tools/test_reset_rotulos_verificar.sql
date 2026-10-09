DO $$ DECLARE t text; actual jsonb; anterior jsonb; BEGIN
 IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF;
 FOREACH t IN ARRAY ARRAY['ordenes_produccion','usuarios','destinatarios_empaque','lista_empaque_config','empaques'] LOOP
  EXECUTE format('SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.%I x',t) INTO actual;
  SELECT jsonb_agg(datos ORDER BY datos::text) INTO anterior FROM public.test_reset_preservados WHERE tabla=t;
  IF actual IS DISTINCT FROM anterior THEN RAISE EXCEPTION 'Cambió %',t; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.reservas_despacho) OR EXISTS(SELECT 1 FROM public.despacho_revisiones) OR EXISTS(SELECT 1 FROM public.empaque_solicitudes) THEN RAISE EXCEPTION 'Quedaron reservas o revisiones'; END IF;
 IF EXISTS(SELECT 1 FROM public.movimientos) OR EXISTS(SELECT 1 FROM public.despachos_oc) OR EXISTS(SELECT 1 FROM public.listas_empaque) THEN RAISE EXCEPTION 'Quedaron operaciones'; END IF;
 IF EXISTS(SELECT 1 FROM public.items_orden WHERE admin_fecha_entrega IS NOT NULL OR admin_fecha_entrega_activa) THEN RAISE EXCEPTION 'Quedó fecha real'; END IF;
 IF NOT EXISTS(SELECT 1 FROM respaldo_pruebas.reinicios WHERE clave='reinicio-operacional-rotulos-20261008-01' AND jsonb_array_length(datos->'movimientos')>0 AND jsonb_array_length(datos->'listas_empaque')>0) THEN RAISE EXCEPTION 'Respaldo incompleto'; END IF;
END $$;
