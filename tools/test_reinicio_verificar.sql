DO $$ BEGIN
 IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF;
 IF (SELECT count(*) FROM public.vista_kardex WHERE numero_op IN ('90003','90004','90005','90006'))<>7 THEN RAISE EXCEPTION 'Faltan lineas'; END IF;
 IF (SELECT cantidad_pedida FROM public.vista_kardex WHERE numero_op='90003')<>20 THEN RAISE EXCEPTION 'Cantidad incorrecta'; END IF;
 IF EXISTS(SELECT 1 FROM public.control_ajeno c LEFT JOIN public.items_orden i ON i.id=(c.fila->>'id')::uuid WHERE c.fila IS DISTINCT FROM to_jsonb(i)) THEN RAISE EXCEPTION 'Cambio otra OP'; END IF;
 IF (SELECT jsonb_array_length(datos->'movimientos') FROM respaldo_pruebas.reinicios WHERE clave='reinicio-90003-20261006')<>3 THEN RAISE EXCEPTION 'Respaldo incompleto'; END IF;
 IF EXISTS(SELECT 1 FROM public.movimientos WHERE item_orden_id='3bf42515-968d-4505-aae4-8fd62408bec2') THEN RAISE EXCEPTION 'Quedan movimientos'; END IF;
 IF has_schema_privilege('authenticated','respaldo_pruebas','USAGE') THEN RAISE EXCEPTION 'Respaldo expuesto'; END IF;
END $$;
