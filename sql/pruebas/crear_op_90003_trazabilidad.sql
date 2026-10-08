  -- SOLO ORBILOQ-DEV (igfuafcekcpugpmsoqbe). Ejecutar completo.
  -- Crea una OP y una linea nuevas, sin lotes ni movimientos.
  -- No cambia estructura, usuarios, existencias ni registros anteriores.
  BEGIN;
  SET LOCAL lock_timeout = '5s';

  DO $prueba$
  DECLARE
    v_orden uuid;
    v_ref text := nullif(current_setting('app.settings.project_ref', true), '');
  BEGIN
    IF v_ref IS NOT NULL AND v_ref <> 'igfuafcekcpugpmsoqbe' THEN
      RAISE EXCEPTION 'Proyecto distinto de ORBILOQ-DEV. No se agrego ninguna OP.';
    END IF;
    -- Supabase no siempre expone project_ref en SQL. Comprobar ademas
    -- dos identificadores del inventario de pruebas, no solo nombres de OP.
    IF NOT EXISTS (
      SELECT 1 FROM public.items_orden i
      JOIN public.ordenes_produccion o ON o.id = i.orden_id
      WHERE i.id = '0701856a-7771-4536-9762-658a58af8803'::uuid
        AND o.numero_op = '90001' AND i.codigo = 'DEMO-001'
    ) OR NOT EXISTS (
      SELECT 1 FROM public.items_orden i
      JOIN public.ordenes_produccion o ON o.id = i.orden_id
      WHERE i.id = 'd50fb131-6f55-4768-a5d5-1efccf3549e8'::uuid
        AND o.numero_op = '90002' AND i.codigo = 'DEMO-003'
    ) THEN
      RAISE EXCEPTION 'No coincide con el inventario de pruebas. Detener y revisar el proyecto.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.ordenes_produccion WHERE numero_op = '90003') THEN
      RAISE EXCEPTION 'La OP 90003 ya existe. No se reemplaza ni se reinicia; revisar la OP existente.';
    END IF;

    INSERT INTO public.ordenes_produccion (
      numero_op, cliente, oc_cabecera, observaciones,
      fecha_esperada_produccion, fecha_esperada_logistica
    ) VALUES (
      '90003', 'CLIENTE PRUEBA TRAZABILIDAD', 'OC-TEST-90003',
      'PRUEBA CONTROLADA: 20 unidades. Sin correcciones administrativas durante el recorrido.',
      current_date + 7, current_date + 10
    ) RETURNING id INTO v_orden;

    INSERT INTO public.items_orden (
      orden_id, codigo, descripcion, talla, cantidad_pedida, oc, observacion
    ) VALUES (
      v_orden, 'TEST-TRAZ-001', 'CAMISETA PRUEBA TRAZABILIDAD', 'M', 20,
      'OC-TEST-90003', 'Prueba aislada de entrega, recepcion parcial, faltante y despacho.'
    );
  END
  $prueba$;
  COMMIT;

  SELECT numero_op, codigo, talla, cliente, oc, cantidad_pedida,
    producido, recibido, despachado,
    greatest(0, recibido - despachado) AS disponible_para_despachar
  FROM public.vista_kardex
  WHERE numero_op = '90003';
