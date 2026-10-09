BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
INSERT INTO public.ordenes_produccion(id,numero_op,cliente) VALUES('20000000-0000-0000-0000-000000000087','TRAZA87','TEST');
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc) VALUES
('0701856a-7771-4536-9762-658a58af8781','20000000-0000-0000-0000-000000000087','T87','TEST','M',10,'T87'),
('0701856a-7771-4536-9762-658a58af8782','20000000-0000-0000-0000-000000000087','T87','TEST','L',10,'T87');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,fecha) VALUES
('entrega_produccion','0701856a-7771-4536-9762-658a58af8781',10,'2026-10-01 12:00Z'),
('entrega_produccion','0701856a-7771-4536-9762-658a58af8782',5,'2026-10-02 12:00Z');
SET LOCAL ROLE authenticated;
DO $$ DECLARE f jsonb; BEGIN
 f:=public.admin_trazabilidad_op('TRAZA87')->0;
 IF (f->>'produccion_completa')::boolean THEN RAISE EXCEPTION 'Completo OP con talla parcial'; END IF;
END $$;
RESET ROLE;
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,fecha) VALUES
('entrega_produccion','0701856a-7771-4536-9762-658a58af8782',5,'2026-10-03 12:00Z');
SET LOCAL ROLE authenticated;
DO $$ DECLARE f jsonb; BEGIN
 FOR f IN SELECT value FROM jsonb_array_elements(public.admin_trazabilidad_op('TRAZA87')) LOOP
 IF NOT (f->>'produccion_completa')::boolean OR (f->>'fecha_produccion')::timestamptz<>'2026-10-03 12:00Z'::timestamptz THEN RAISE EXCEPTION 'Fecha completa incorrecta %',f; END IF;
 END LOOP;
END $$;
DO $$ DECLARE f jsonb; d jsonb; v integer; BEGIN
 f:=public.admin_trazabilidad_op();
 IF jsonb_array_length(f)=0 THEN RAISE EXCEPTION 'Reporte vacio'; END IF;
 d:=public.seguimiento_entregas_listar()->0;
 v:=public.seguimiento_entregas_guardar_v87((d->>'id')::uuid,(d->>'revision')::integer,(d->>'version')::integer,
 '{"numero_guia":"001234","placa":"ABC123","placa_guia":"LEGADO"}');
 d:=public.seguimiento_entregas_listar()->0;
 IF d->>'numero_guia'<>'001234' OR d->>'placa'<>'ABC123' THEN RAISE EXCEPTION 'Campos separados no guardados'; END IF;
 SELECT x INTO f FROM jsonb_array_elements(public.admin_trazabilidad_op()) x WHERE x->>'despacho_id'=d->>'id' LIMIT 1;
 IF f->>'numero_guia'<>'001234' OR f->>'placa'<>'ABC123' OR f->>'placa_guia_historica'<>'LEGADO' THEN RAISE EXCEPTION 'Exportacion transporte incorrecta %',f; END IF;
 IF f->>'fecha_despachado' IS NULL OR f->>'fecha_liberado' IS NULL THEN RAISE EXCEPTION 'Faltan fechas %',f; END IF;
 IF coalesce((f->>'piezas')::int,0)=0 THEN RAISE EXCEPTION 'Faltan piezas %',f; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN PERFORM public.admin_trazabilidad_op(); RAISE EXCEPTION 'Acceso anonimo permitido'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
