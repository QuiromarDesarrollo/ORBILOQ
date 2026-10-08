DO $$ BEGIN
IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF;
IF EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE cliente='TEST' AND (fecha_esperada_produccion >= '2026-08-01' AND fecha_esperada_produccion < '2026-09-01' OR fecha_esperada_logistica >= '2026-08-01' AND fecha_esperada_logistica < '2026-09-01')) THEN RAISE EXCEPTION 'Quedaron fechas'; END IF;
IF NOT EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE numero_op='25812' AND fecha_esperada_produccion IS NULL AND fecha_esperada_logistica='2026-09-01') THEN RAISE EXCEPTION 'Cambio septiembre'; END IF;
IF NOT EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE numero_op='25813' AND fecha_esperada_produccion='2026-07-31' AND fecha_esperada_logistica IS NULL) THEN RAISE EXCEPTION 'Cambio julio'; END IF;
IF NOT EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE numero_op='25815' AND fecha_esperada_produccion='2025-08-15') THEN RAISE EXCEPTION 'Cambio año'; END IF;
IF (SELECT count(*) FROM respaldo_mantenimiento.fechas_agosto_2026)<>3 THEN RAISE EXCEPTION 'Respaldo incorrecto'; END IF;
IF (SELECT count(*) FROM public.ordenes_produccion WHERE cliente='TEST')<>4 THEN RAISE EXCEPTION 'Faltan órdenes'; END IF;
IF (SELECT count(*) FROM public.ordenes_produccion WHERE cliente='FUERA' AND fecha_esperada_produccion='2026-08-10' AND fecha_esperada_logistica='2026-08-20')<>10 THEN RAISE EXCEPTION 'Se modificaron OP fuera de la lista'; END IF;
END $$;
