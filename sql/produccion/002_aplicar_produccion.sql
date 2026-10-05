-- ORBILOQ: migración incremental. Proyecto destino cxrflhgnxvomcvxzugda. Aplicar SOLO en ventana sin escrituras y con respaldo actualizado. No usar archivos de pruebas.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=public,extensions,pg_catalog;
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base destino inesperada.'; END IF;
 IF to_regclass('public.clientes') IS NULL OR to_regclass('public.devoluciones_cliente') IS NULL THEN RAISE EXCEPTION 'Esquema ERP inesperado.'; END IF;
 IF to_regclass('public.admin_correcciones') IS NOT NULL THEN RAISE EXCEPTION 'Migración ya instalada; no repetir.'; END IF;
END $$;
DO $baseline$ BEGIN
IF replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_aliado(text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.agregar_personal_aliado(p_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_nombre text; v_id uuid;
begin
  v_nombre := nullif(trim(p_nombre), '');
  if v_nombre is null then raise exception 'El nombre no puede estar vacío.'; end if;
  insert into personal_aliados (nombre) values (v_nombre)
  on conflict (nombre) do update set activo = true returning id into v_id;
  return jsonb_build_object('id', v_id, 'nombre', v_nombre);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.agregar_personal_aliado(text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_logistica(text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.agregar_personal_logistica(p_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_nombre text;
  v_id uuid;
begin
  v_nombre := nullif(trim(p_nombre), '');
  if v_nombre is null then
    raise exception 'El nombre no puede estar vacío.';
  end if;

  insert into personal_logistica (nombre) values (v_nombre)
  on conflict (nombre) do update set activo = true
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'nombre', v_nombre);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.agregar_personal_logistica(text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_produccion(text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.agregar_personal_produccion(p_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_nombre text;
  v_id uuid;
begin
  v_nombre := nullif(trim(p_nombre), '');
  if v_nombre is null then
    raise exception 'El nombre no puede estar vacío.';
  end if;

  insert into personal_produccion (nombre) values (v_nombre)
  on conflict (nombre) do update set activo = true
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'nombre', v_nombre);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.agregar_personal_produccion(text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.cerrar_lote_item_con_faltante(uuid, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.cerrar_lote_item_con_faltante(p_lote_item_id uuid, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_li lote_items%rowtype;
  v_recibido integer;
  v_faltante integer;
  v_novedad text;
begin
  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then raise exception 'La línea del lote no existe.'; end if;
  if v_li.estado <> 'en_transito' then raise exception 'Esta línea ya fue cerrada.'; end if;

  v_recibido := coalesce(v_li.cantidad_recibida, 0);
  v_faltante := v_li.cantidad_enviada - v_recibido;
  if v_faltante <= 0 then
    raise exception 'Esta línea ya está completa, no hay faltante que cerrar.';
  end if;

  v_novedad := format('FALTANTE DEFINITIVO: se recibieron %s de %s Uds (nunca llegaron %s).',
                       v_recibido, v_li.cantidad_enviada, v_faltante);
  if coalesce(trim(p_nota), '') <> '' then
    v_novedad := v_novedad || ' Obs: ' || p_nota;
  end if;

  update lote_items set estado = 'recibido_con_novedad', novedad = v_novedad
  where id = p_lote_item_id;

  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, lote_item_id, nota)
  values ('ajuste_faltante_entrega', v_li.item_orden_id, v_faltante, v_li.lote_id, p_lote_item_id, v_novedad);

  return jsonb_build_object('lote_item_id', p_lote_item_id, 'faltante_definitivo', v_faltante);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.cerrar_lote_item_con_faltante(uuid, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.crear_lote(jsonb, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.crear_lote(p_items jsonb, p_operario_nombre text, p_numero_lote text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_lote_id uuid;
  v_numero text;
  v_usuario_id uuid;
  v_item jsonb;
  v_item_id uuid;
  v_cantidad integer;
  v_producido integer;
  v_pedida integer;
  v_pendiente integer;
  v_items_creados jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'El lote no tiene productos.';
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  v_numero := nullif(trim(upper(coalesce(p_numero_lote, ''))), '');
  if v_numero is null then
    v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  elsif exists (select 1 from lotes where numero = v_numero) then
    raise exception 'El lote % ya existe.', v_numero;
  end if;

  -- Validar TODAS las líneas antes de crear nada (todo o nada).
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_item_id := (v_item->>'item_orden_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;

    if v_cantidad is null or v_cantidad <= 0 then
      raise exception 'Cantidad inválida en uno de los productos del lote.';
    end if;

    select io.cantidad_pedida,
           coalesce(sum(case when m.tipo = 'entrega_produccion' then m.cantidad else 0 end), 0)
      into v_pedida, v_producido
      from items_orden io
      left join movimientos m on m.item_orden_id = io.id
     where io.id = v_item_id
     group by io.cantidad_pedida;

    if v_pedida is null then
      raise exception 'Uno de los productos del lote no existe en el kardex.';
    end if;

    v_pendiente := greatest(v_pedida - v_producido, 0);
    if v_cantidad > v_pendiente then
      raise exception 'LÍMITE EXCEDIDO en uno de los productos: solo faltan % Uds por producir.', v_pendiente;
    end if;
  end loop;

  insert into lotes (numero, operario_id, operario_nombre)
  values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_item_id := (v_item->>'item_orden_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;

    insert into lote_items (lote_id, item_orden_id, cantidad_enviada)
    values (v_lote_id, v_item_id, v_cantidad);

    insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id)
    values ('entrega_produccion', v_item_id, v_cantidad, v_lote_id, v_usuario_id);

    v_items_creados := v_items_creados || jsonb_build_object('item_orden_id', v_item_id, 'cantidad', v_cantidad);
  end loop;

  return jsonb_build_object('id', v_lote_id, 'numero', v_numero, 'items', v_items_creados);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.crear_lote(jsonb, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.despachar(uuid, integer, uuid)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.despachar(p_item_orden_id uuid, p_cantidad integer, p_ubicacion_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_stock integer;
  v_pendiente integer;
begin
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select coalesce(cantidad, 0) into v_stock
    from vista_stock_ubicacion
   where item_orden_id = p_item_orden_id and ubicacion_id = p_ubicacion_id;
  v_stock := coalesce(v_stock, 0);

  if p_cantidad > v_stock then
    raise exception 'Stock insuficiente en la ubicación (disponible: %).', v_stock;
  end if;

  select greatest(io.cantidad_pedida - coalesce(s.despachado, 0), 0)
    into v_pendiente
    from items_orden io
    left join vista_saldos_item s on s.item_orden_id = io.id
   where io.id = p_item_orden_id;

  if p_cantidad > v_pendiente then
    raise exception 'LÍMITE EXCEDIDO: solo faltan % Uds por despachar según la orden.', v_pendiente;
  end if;

  insert into movimientos (tipo, item_orden_id, cantidad, ubicacion_id)
  values ('despacho', p_item_orden_id, p_cantidad, p_ubicacion_id);

  return jsonb_build_object('ok', true);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.despachar(uuid, integer, uuid) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.enviar_no_conforme_aliado(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_persona_aliado_entrega text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_usuario_id uuid;
  v_id uuid;
  v_persona text;
begin
  v_persona := nullif(trim(p_persona_aliado_entrega), '');
  if v_persona is null then
    raise exception 'Debes indicar a quién de Aliados se le entrega esta prenda.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  insert into no_conformes_aliados
    (item_orden_id, causal_id, cantidad_solicitada, usuario_produccion_solicitud_id,
     usuario_produccion_solicitud_nombre, persona_aliado_entrega, nota_solicitud)
  values
    (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, v_persona, p_nota)
  returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.importar_fechas_esperadas(jsonb)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.importar_fechas_esperadas(p_filas jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_fila jsonb;
  v_numero_op text;
  v_fecha_prod date;
  v_fecha_log date;
  v_actualizadas integer := 0;
  v_no_encontradas text[] := array[]::text[];
begin
  if p_filas is null or jsonb_array_length(p_filas) = 0 then
    raise exception 'El archivo no tiene filas para procesar.';
  end if;

  for v_fila in select * from jsonb_array_elements(p_filas)
  loop
    v_numero_op := nullif(trim(v_fila->>'numero_op'), '');
    if v_numero_op is null then
      continue;
    end if;

    v_fecha_prod := nullif(v_fila->>'fecha_esperada_produccion', '')::date;
    v_fecha_log := nullif(v_fila->>'fecha_esperada_logistica', '')::date;

    if v_fecha_prod is null and v_fecha_log is null then
      continue;
    end if;

    update ordenes_produccion op set
      fecha_esperada_produccion = coalesce(v_fecha_prod, op.fecha_esperada_produccion),
      fecha_esperada_logistica = coalesce(v_fecha_log, op.fecha_esperada_logistica)
    where op.numero_op = v_numero_op;

    if found then
      v_actualizadas := v_actualizadas + 1;
    else
      v_no_encontradas := array_append(v_no_encontradas, v_numero_op);
    end if;
  end loop;

  return jsonb_build_object(
    'actualizadas', v_actualizadas,
    'no_encontradas', to_jsonb(v_no_encontradas)
  );
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.importar_fechas_esperadas(jsonb) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_importacion_id uuid;
  v_usuario_id uuid;
  v_ops_creadas integer;
  v_ops_omitidas integer;
  v_filas_invalidas integer;
  v_lineas_tallas integer;
  v_advertencias jsonb;
begin
  select id into v_usuario_id from usuarios where nombre = p_usuario_nombre limit 1;

  insert into importaciones (nombre_archivo, tipo, storage_path, usuario_id, estado)
  values (p_nombre_archivo, 'ordenes_produccion', p_storage_path, v_usuario_id, 'procesando')
  returning id into v_importacion_id;

  -- --------------------------------------------------------- 1) Órdenes nuevas
  with filas as (
    select
      trim(o->>'identificador') as numero_op,
      nullif(trim(o->>'tipo_orden'), '') as tipo_orden,
      nullif(trim(o->>'estado'), '') as estado,
      coalesce(nullif(trim(o->>'cliente'), ''), 'SIN CLIENTE') as cliente,
      nullif(trim(o->>'oc_cabecera'), '') as oc_cabecera,
      nullif(o->>'oc_id_erp', '')::bigint as oc_id_erp,
      nullif(trim(o->>'nombre_ficha_tecnica'), '') as nombre_ficha_tecnica,
      nullif(trim(o->>'nombre_prenda_resumen'), '') as nombre_prenda_resumen,
      nullif(o->>'cantidad_total_erp', '')::integer as cantidad_total_erp,
      nullif(o->>'fecha_solicitud', '')::date as fecha_solicitud,
      nullif(o->>'fecha_inicio', '')::date as fecha_inicio,
      nullif(o->>'fecha_comprometida', '')::date as fecha_comprometida,
      nullif(o->>'fecha_acordada', '')::date as fecha_acordada,
      nullif(o->>'fecha_entrega', '')::date as fecha_entrega,
      nullif(o->>'fecha_planeacion', '')::date as fecha_planeacion,
      nullif(trim(o->>'observaciones'), '') as observaciones,
      nullif(trim(o->>'etapa_movimiento'), '') as etapa_movimiento,
      nullif(trim(o->>'estado_movimiento_erp'), '') as estado_movimiento_erp,
      nullif(o->>'fecha_inicio_movimiento', '')::date as fecha_inicio_movimiento,
      nullif(o->>'fecha_planeada_movimiento', '')::date as fecha_planeada_movimiento
    from jsonb_array_elements(p_ordenes) as o
    where trim(o->>'identificador') <> ''
  )
  insert into ordenes_produccion (
    numero_op, tipo_orden, estado, cliente, oc_cabecera, oc_id_erp,
    nombre_ficha_tecnica, nombre_prenda_resumen, cantidad_total_erp,
    fecha_solicitud, fecha_inicio, fecha_comprometida, fecha_acordada,
    fecha_entrega, fecha_planeacion, observaciones,
    etapa_movimiento, estado_movimiento_erp,
    fecha_inicio_movimiento, fecha_planeada_movimiento, importacion_id
  )
  select
    numero_op, tipo_orden, estado, cliente, oc_cabecera, oc_id_erp,
    nombre_ficha_tecnica, nombre_prenda_resumen, cantidad_total_erp,
    fecha_solicitud, fecha_inicio, fecha_comprometida, fecha_acordada,
    fecha_entrega, fecha_planeacion, observaciones,
    etapa_movimiento, estado_movimiento_erp,
    fecha_inicio_movimiento, fecha_planeada_movimiento, v_importacion_id
  from filas
  on conflict (numero_op) do nothing;

  get diagnostics v_ops_creadas = row_count;

  select count(*) into v_ops_omitidas
  from jsonb_array_elements(p_ordenes) as o
  where trim(o->>'identificador') <> ''
    and exists (
      select 1 from ordenes_produccion op
      where op.numero_op = trim(o->>'identificador') and op.importacion_id is distinct from v_importacion_id
    );

  select count(*) into v_filas_invalidas
  from jsonb_array_elements(p_ordenes) as o
  where trim(coalesce(o->>'identificador', '')) = '';

  -- ------------------------------------------------------ 2) Tallas de las OP
  -- El join por importacion_id garantiza que solo se insertan tallas de las
  -- OP recién creadas en ESTA carga (las que ya existían quedan intactas).
  --
  -- El "No. OC" que se guarda (oc) viene de la hoja "Orden" (op.oc_cabecera),
  -- no de la hoja "Tallas" (antes se usaba ft.oc, que a veces viene vacío).
  with filas_tallas as (
    select
      trim(t->>'identificador_orden') as numero_op,
      trim(t->>'codigo') as codigo,
      trim(t->>'descripcion') as descripcion,
      trim(t->>'talla') as talla,
      nullif(trim(t->>'cantidad'), '')::integer as cantidad,
      nullif(trim(t->>'oc'), '') as oc,
      nullif(t->>'oc_id_erp', '')::bigint as oc_id_erp,
      nullif(trim(t->>'observacion'), '') as observacion
    from jsonb_array_elements(p_tallas) as t
  )
  insert into items_orden (orden_id, codigo, descripcion, talla, cantidad_pedida, oc, oc_id_erp, observacion)
  select op.id, ft.codigo, ft.descripcion, ft.talla, ft.cantidad, op.oc_cabecera, ft.oc_id_erp, ft.observacion
  from filas_tallas ft
  join ordenes_produccion op
    on op.numero_op = ft.numero_op and op.importacion_id = v_importacion_id
  where coalesce(ft.cantidad, 0) > 0
    and coalesce(ft.codigo, '') <> ''
    and coalesce(ft.talla, '') <> ''
  on conflict (orden_id, codigo, talla) do nothing;

  get diagnostics v_lineas_tallas = row_count;

  -- ---------------------------------------------- 3) Advertencias de cantidad
  -- OP nuevas donde el total declarado en el ERP no coincide con la suma real
  -- de sus tallas importadas (por ejemplo, si el Excel trae una OP sin líneas).
  select coalesce(jsonb_agg(
    format('OP %s: declara %s Uds pero sus tallas suman %s Uds',
           op.numero_op, op.cantidad_total_erp, coalesce(s.total, 0))
  ), '[]'::jsonb)
  into v_advertencias
  from ordenes_produccion op
  left join (
    select orden_id, sum(cantidad_pedida) as total from items_orden group by orden_id
  ) s on s.orden_id = op.id
  where op.importacion_id = v_importacion_id
    and op.cantidad_total_erp is not null
    and op.cantidad_total_erp <> coalesce(s.total, 0);

  update importaciones set
    ops_creadas = v_ops_creadas,
    ops_omitidas = v_ops_omitidas,
    filas_con_advertencia = jsonb_array_length(v_advertencias),
    filas_con_error = v_filas_invalidas,
    detalle_errores = v_advertencias,
    estado = 'completado'
  where id = v_importacion_id;

  return jsonb_build_object(
    'importacion_id', v_importacion_id,
    'ops_creadas', v_ops_creadas,
    'ops_omitidas', v_ops_omitidas,
    'filas_invalidas', v_filas_invalidas,
    'lineas_tallas_creadas', v_lineas_tallas,
    'advertencias', v_advertencias
  );
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.importar_ordenes_produccion(jsonb, jsonb, text, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_usuario_id uuid;
  v_pendiente_reproceso integer;
  v_liberacion_id uuid;
  v_lote_id uuid;
  v_numero text;
begin
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select coalesce(sum(case
           when tipo = 'devolucion_produccion' then cantidad
           when tipo = 'liberacion_no_conforme' then -cantidad
           else 0
         end), 0)
    into v_pendiente_reproceso
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_pendiente_reproceso then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds pendientes por reprocesar para este producto.', v_pendiente_reproceso;
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  insert into liberaciones_no_conforme (item_orden_id, cantidad, operario_id, operario_nombre, nota)
  values (p_item_orden_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota)
  returning id into v_liberacion_id;

  v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  insert into lotes (numero, operario_id, operario_nombre)
  values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;

  insert into lote_items (lote_id, item_orden_id, cantidad_enviada, origen)
  values (v_lote_id, p_item_orden_id, p_cantidad, 'reproceso');

  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id, nota)
  values ('liberacion_no_conforme', p_item_orden_id, p_cantidad, v_lote_id, v_usuario_id, p_nota);

  return jsonb_build_object(
    'id', v_liberacion_id, 'item_orden_id', p_item_orden_id,
    'cantidad', p_cantidad, 'lote_numero', v_numero
  );
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.liberar_no_conforme(uuid, integer, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text, p_recibido_por_logistica text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_usuario_id uuid;
  v_pendiente_reproceso integer;
  v_liberacion_id uuid;
  v_lote_id uuid;
  v_numero text;
  v_recibido_por text;
begin
  v_recibido_por := nullif(trim(p_recibido_por_logistica), '');
  if v_recibido_por is null then
    raise exception 'Debes indicar quién de Logística recibió esta prenda.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select coalesce(sum(case
           when tipo = 'devolucion_produccion' then cantidad
           when tipo = 'liberacion_no_conforme' then -cantidad
           else 0
         end), 0)
    into v_pendiente_reproceso
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_pendiente_reproceso then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds pendientes por reprocesar para este producto.', v_pendiente_reproceso;
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  insert into liberaciones_no_conforme
    (item_orden_id, cantidad, operario_id, operario_nombre, nota, recibido_por_logistica)
  values
    (p_item_orden_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota, v_recibido_por)
  returning id into v_liberacion_id;

  v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  insert into lotes (numero, operario_id, operario_nombre)
  values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;

  insert into lote_items (lote_id, item_orden_id, cantidad_enviada, origen)
  values (v_lote_id, p_item_orden_id, p_cantidad, 'reproceso');

  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id, nota)
  values ('liberacion_no_conforme', p_item_orden_id, p_cantidad, v_lote_id, v_usuario_id, p_nota);

  return jsonb_build_object(
    'id', v_liberacion_id, 'item_orden_id', p_item_orden_id,
    'cantidad', p_cantidad, 'lote_numero', v_numero
  );
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.liberar_no_conforme(uuid, integer, text, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme_aliado(uuid, integer, text, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.liberar_no_conforme_aliado(p_solicitud_id uuid, p_cantidad integer, p_operario_nombre text, p_persona_aliado_libera text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_solicitud no_conformes_aliados%rowtype;
  v_persona text;
  v_liberado_previo integer;
  v_pendiente integer;
  v_completa boolean;
begin
  v_persona := nullif(trim(p_persona_aliado_libera), '');
  if v_persona is null then
    raise exception 'Debes indicar quién de Aliados realizó la liberación.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select * into v_solicitud from no_conformes_aliados where id = p_solicitud_id for update;
  if not found then raise exception 'La solicitud no existe.'; end if;
  if v_solicitud.estado <> 'pendiente' then
    raise exception 'Esta solicitud ya fue liberada por completo.';
  end if;

  select coalesce(sum(cantidad), 0) into v_liberado_previo
    from liberaciones_aliados where solicitud_id = p_solicitud_id;

  v_pendiente := v_solicitud.cantidad_solicitada - v_liberado_previo;
  if p_cantidad > v_pendiente then
    raise exception 'LÍMITE EXCEDIDO: solo quedan % Uds pendientes por liberar.', v_pendiente;
  end if;

  v_completa := (v_liberado_previo + p_cantidad) >= v_solicitud.cantidad_solicitada;

  insert into liberaciones_aliados
    (solicitud_id, cantidad, usuario_produccion_nombre, persona_aliado_libera, nota, es_entrega_completa)
  values
    (p_solicitud_id, p_cantidad, p_operario_nombre, v_persona, p_nota, v_completa);

  if v_completa then
    update no_conformes_aliados set estado = 'liberado' where id = p_solicitud_id;
  end if;

  return jsonb_build_object(
    'id', p_solicitud_id, 'completa', v_completa, 'liberado_total', v_liberado_previo + p_cantidad
  );
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.liberar_no_conforme_aliado(uuid, integer, text, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid, integer, uuid, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_li lote_items%rowtype;
  v_diff integer;
  v_novedad text := '';
  v_estado_linea text;
  v_pendientes_en_lote integer;
begin
  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then
    raise exception 'La línea del lote no existe.';
  end if;
  if v_li.estado <> 'en_transito' then
    raise exception 'Esta línea ya fue recibida.';
  end if;

  -- CORREGIDO: antes decía "p_cantidad < 0", lo que dejaba pasar el 0.
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  if not exists (select 1 from ubicaciones where id = p_ubicacion_id and activa) then
    raise exception 'Ubicación no válida.';
  end if;

  -- A partir de aquí es exactamente igual que antes: nada de esto se
  -- ejecuta si la cantidad no pasó la validación de arriba.
  v_diff := p_cantidad - v_li.cantidad_enviada;
  if v_diff < 0 then
    v_novedad := format('FALTANTE: Se recibieron %s de %s Uds (faltaron %s).',
                         p_cantidad, v_li.cantidad_enviada, abs(v_diff));
  elsif v_diff > 0 then
    v_novedad := format('SOBRANTE: Se recibieron %s de %s Uds (+%s).',
                         p_cantidad, v_li.cantidad_enviada, v_diff);
  end if;
  if coalesce(trim(p_nota), '') <> '' then
    v_novedad := trim(coalesce(v_novedad || ' ', '') || 'Obs: ' || p_nota);
  end if;

  v_estado_linea := case when v_novedad = '' then 'recibido_conforme' else 'recibido_con_novedad' end;

  update lote_items set
    estado = v_estado_linea,
    cantidad_recibida = p_cantidad,
    ubicacion_destino_id = p_ubicacion_id,
    novedad = v_novedad,
    fecha_recepcion = now()
  where id = p_lote_item_id;

  insert into movimientos (tipo, item_orden_id, cantidad, ubicacion_id, lote_id, lote_item_id, nota)
  values ('recepcion', v_li.item_orden_id, p_cantidad, p_ubicacion_id, v_li.lote_id, p_lote_item_id, v_novedad);

  select count(*) into v_pendientes_en_lote
  from lote_items where lote_id = v_li.lote_id and estado = 'en_transito';

  update lotes set
    estado = case when v_pendientes_en_lote = 0 then 'recibido_completo' else 'recibido_parcial' end
  where id = v_li.lote_id;

  return jsonb_build_object('lote_item_id', p_lote_item_id, 'estado', v_estado_linea, 'novedad', v_novedad);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.recibir_lote_item(uuid, integer, uuid, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_usuario_id uuid;
  v_producido integer;
  v_devolucion_id uuid;
begin
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  select coalesce(sum(case
           when tipo = 'entrega_produccion' then cantidad
           when tipo = 'devolucion_produccion' then -cantidad
           else 0
         end), 0)
    into v_producido
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_producido then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds entregadas por Producción para este producto.', v_producido;
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  insert into devoluciones_produccion (item_orden_id, causal_id, cantidad, operario_id, operario_nombre, nota)
  values (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota)
  returning id into v_devolucion_id;

  insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)
  values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);

  return jsonb_build_object('id', v_devolucion_id, 'item_orden_id', p_item_orden_id, 'cantidad', p_cantidad);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.registrar_no_conforme(uuid, integer, uuid, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text DEFAULT ''::text, p_recibido_de_produccion text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_usuario_id uuid;
  v_producido integer;
  v_devolucion_id uuid;
  v_recibido_de text;
begin
  v_recibido_de := nullif(trim(p_recibido_de_produccion), '');
  if v_recibido_de is null then
    raise exception 'Debes indicar quién de Producción entregó esta prenda.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  select coalesce(sum(case
           when tipo = 'entrega_produccion' then cantidad
           when tipo = 'devolucion_produccion' then -cantidad
           when tipo = 'liberacion_no_conforme' then cantidad
           else 0
         end), 0)
    into v_producido
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_producido then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds entregadas por Producción para este producto.', v_producido;
  end if;

  select id into v_usuario_id from usuarios where nombre = p_operario_nombre limit 1;

  insert into devoluciones_produccion
    (item_orden_id, causal_id, cantidad, operario_id, operario_nombre, nota, recibido_de_produccion)
  values
    (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota, v_recibido_de)
  returning id into v_devolucion_id;

  insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)
  values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);

  return jsonb_build_object('id', v_devolucion_id, 'item_orden_id', p_item_orden_id, 'cantidad', p_cantidad);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.registrar_no_conforme(uuid, integer, uuid, text, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.registrar_sobrante(uuid, uuid, integer, text, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.registrar_sobrante(p_item_orden_id uuid, p_lote_item_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_id uuid;
begin
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  insert into sobrantes_bodega (item_orden_id, lote_item_id, cantidad, operario_nombre, nota)
  values (p_item_orden_id, p_lote_item_id, p_cantidad, p_operario_nombre, p_nota)
  returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.registrar_sobrante(uuid, uuid, integer, text, text) cambió desde el inventario; detener y revisar.'; END IF;
IF replace(pg_get_functiondef(to_regprocedure('public.resolver_sobrante(uuid, text)')), E'\r\n', E'\n') IS DISTINCT FROM replace($expected$CREATE OR REPLACE FUNCTION public.resolver_sobrante(p_id uuid, p_resolucion text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_resolucion text;
begin
  v_resolucion := nullif(trim(p_resolucion), '');
  if v_resolucion is null then
    raise exception 'Debes indicar qué se decidió hacer con este sobrante.';
  end if;

  update sobrantes_bodega set
    estado = 'resuelto',
    resolucion = v_resolucion,
    fecha_resolucion = now()
  where id = p_id and estado = 'pendiente';

  if not found then
    raise exception 'El sobrante no existe o ya fue resuelto.';
  end if;

  return jsonb_build_object('id', p_id);
end;
$function$
$expected$, E'\r\n', E'\n') THEN RAISE EXCEPTION 'La función public.resolver_sobrante(uuid, text) cambió desde el inventario; detener y revisar.'; END IF;
END $baseline$;
CREATE TEMP TABLE preservacion(tabla text PRIMARY KEY,columnas text[],filas jsonb) ON COMMIT DROP;
DO $$ DECLARE t record; cols text[]; contenido jsonb; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
  EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE',t.tablename);
  SELECT array_agg(attname::text ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=format('public.%I',t.tablename)::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),''[]''::jsonb) FROM public.%I x',t.tablename) INTO contenido;
  INSERT INTO preservacion VALUES(t.tablename,cols,contenido);
 END LOOP;
END $$;
-- RPC operativas vigentes; el importador ERP y la recepción antigua conservan su base de producción.
CREATE OR REPLACE FUNCTION public.cerrar_lote_item_con_faltante(p_lote_item_id uuid, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_li lote_items%rowtype;
  v_recibido integer;
  v_faltante integer;
  v_novedad text;
BEGIN
 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then raise exception 'La línea del lote no existe.'; end if;
  if v_li.estado <> 'en_transito' then raise exception 'Esta línea ya fue cerrada.'; end if;

  v_recibido := coalesce(v_li.cantidad_recibida, 0);
  v_faltante := v_li.cantidad_enviada - v_recibido;
  if v_faltante <= 0 then
    raise exception 'Esta línea ya está completa, no hay faltante que cerrar.';
  end if;

  v_novedad := format('FALTANTE DEFINITIVO: se recibieron %s de %s Uds (nunca llegaron %s).',
                       v_recibido, v_li.cantidad_enviada, v_faltante);
  if coalesce(trim(p_nota), '') <> '' then
    v_novedad := v_novedad || ' Obs: ' || p_nota;
  end if;

  update lote_items set estado = 'recibido_con_novedad', novedad = v_novedad
  where id = p_lote_item_id;

  -- Las unidades que nunca llegaron vuelven a estar "pendientes por
  -- entregar" en Producción (bajan de "producido"). No tocan "recibido":
  -- nunca se contaron ahí.
  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, lote_item_id, nota)
  values ('ajuste_faltante_entrega', v_li.item_orden_id, v_faltante, v_li.lote_id, p_lote_item_id, v_novedad);

  return jsonb_build_object('lote_item_id', p_lote_item_id, 'faltante_definitivo', v_faltante);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.crear_lote(p_items jsonb, p_operario_nombre text, p_numero_lote text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_lote_id uuid;
  v_numero text;
  v_usuario_id uuid;
  v_item jsonb;
  v_item_id uuid;
  v_cantidad integer;
  v_producido integer;
  v_pedida integer;
  v_pendiente integer;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion')) THEN RAISE EXCEPTION 'Esta operacion requiere Produccion o Administrador.' USING ERRCODE='42501'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'El lote no tiene productos.';
  end if;

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  v_numero := nullif(trim(upper(coalesce(p_numero_lote, ''))), '');
  if v_numero is null then
    v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  elsif exists (select 1 from lotes where numero = v_numero) then
    raise exception 'El lote % ya existe.', v_numero;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_item_id := (v_item->>'item_orden_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;
    if v_cantidad is null or v_cantidad <= 0 then
      raise exception 'Cantidad inválida en uno de los productos del lote.';
    end if;

    select io.cantidad_pedida,
           coalesce(sum(case when m.tipo = 'entrega_produccion' then m.cantidad
                              when m.tipo = 'devolucion_produccion' then -m.cantidad
                              when m.tipo = 'liberacion_no_conforme' then m.cantidad
                              else 0 end), 0)
      into v_pedida, v_producido
      from items_orden io left join movimientos m on m.item_orden_id = io.id
     where io.id = v_item_id
     group by io.cantidad_pedida;

    if v_pedida is null then raise exception 'Uno de los productos del lote no existe.'; end if;

    v_pendiente := greatest(v_pedida - v_producido, 0);
    if v_cantidad > v_pendiente then
      raise exception 'LÍMITE EXCEDIDO en uno de los productos: solo faltan % Uds por producir.', v_pendiente;
    end if;
  end loop;

  insert into lotes (numero, operario_id, operario_nombre) values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_item_id := (v_item->>'item_orden_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;
    insert into lote_items (lote_id, item_orden_id, cantidad_enviada) values (v_lote_id, v_item_id, v_cantidad);
    insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id)
    values ('entrega_produccion', v_item_id, v_cantidad, v_lote_id, v_usuario_id);
  end loop;

  return jsonb_build_object('id', v_lote_id, 'numero', v_numero);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.enviar_no_conforme_aliado(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_persona_aliado_entrega text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_usuario_id uuid;
  v_id uuid;
  v_persona text;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion')) THEN RAISE EXCEPTION 'Esta operacion requiere Produccion o Administrador.' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_entrega)) AND NOT activo) THEN RAISE EXCEPTION 'Nombre de personal inactivo. Selecciona uno activo.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_persona := nullif(trim(p_persona_aliado_entrega), '');
  if v_persona is null then
    raise exception 'Debes indicar a quién de Aliados se le entrega esta prenda.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  -- Ya NO se valida contra "producido": es un registro informativo aparte,
  -- no afecta ni depende del inventario.

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into no_conformes_aliados
    (item_orden_id, causal_id, cantidad_solicitada, usuario_produccion_solicitud_id,
     usuario_produccion_solicitud_nombre, persona_aliado_entrega, nota_solicitud)
  values
    (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, v_persona, p_nota)
  returning id into v_id;

  -- Ya NO se inserta ningún movimiento: no debe tocar "Entregado por
  -- Producción" ni ningún otro número del kardex.

  return jsonb_build_object('id', v_id);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.importar_fechas_esperadas(p_filas jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_fila jsonb;
  v_numero_op text;
  v_fecha_prod date;
  v_fecha_log date;
  v_actualizadas integer := 0;
  v_no_encontradas text[] := array[]::text[];
BEGIN
 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  if p_filas is null or jsonb_array_length(p_filas) = 0 then
    raise exception 'El archivo no tiene filas para procesar.';
  end if;

  for v_fila in select * from jsonb_array_elements(p_filas)
  loop
    v_numero_op := nullif(trim(v_fila->>'numero_op'), '');
    if v_numero_op is null then continue; end if;

    v_fecha_prod := nullif(v_fila->>'fecha_esperada_produccion', '')::date;
    v_fecha_log := nullif(v_fila->>'fecha_esperada_logistica', '')::date;
    if v_fecha_prod is null and v_fecha_log is null then continue; end if;

    update ordenes_produccion op set
      fecha_esperada_produccion = coalesce(v_fecha_prod, op.fecha_esperada_produccion),
      fecha_esperada_logistica = coalesce(v_fecha_log, op.fecha_esperada_logistica)
    where op.numero_op = v_numero_op;

    if found then
      v_actualizadas := v_actualizadas + 1;
    else
      v_no_encontradas := array_append(v_no_encontradas, v_numero_op);
    end if;
  end loop;

  return jsonb_build_object('actualizadas', v_actualizadas, 'no_encontradas', to_jsonb(v_no_encontradas));
end;
$function$
;
CREATE OR REPLACE FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text, p_recibido_por_logistica text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_usuario_id uuid;
  v_pendiente_reproceso integer;
  v_liberacion_id uuid;
  v_lote_id uuid;
  v_numero text;
  v_recibido_por text;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion')) THEN RAISE EXCEPTION 'Esta operacion requiere Produccion o Administrador.' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por_logistica)) AND NOT activo) THEN RAISE EXCEPTION 'Nombre de personal inactivo. Selecciona uno activo.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_recibido_por := nullif(trim(p_recibido_por_logistica), '');
  if v_recibido_por is null then raise exception 'Debes indicar quién de Logística recibió esta prenda.'; end if;
  if p_cantidad is null or p_cantidad <= 0 then raise exception 'La cantidad debe ser mayor a 0.'; end if;

  select coalesce(sum(case when tipo = 'devolucion_produccion' then cantidad
                           when tipo = 'liberacion_no_conforme' then -cantidad else 0 end), 0)
    into v_pendiente_reproceso from movimientos where item_orden_id = p_item_orden_id;
  if p_cantidad > v_pendiente_reproceso then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds pendientes por reprocesar.', v_pendiente_reproceso;
  end if;

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into liberaciones_no_conforme (item_orden_id, cantidad, operario_id, operario_nombre, nota, recibido_por_logistica)
  values (p_item_orden_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota, v_recibido_por)
  returning id into v_liberacion_id;

  v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  insert into lotes (numero, operario_id, operario_nombre) values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;
  insert into lote_items (lote_id, item_orden_id, cantidad_enviada, origen)
  values (v_lote_id, p_item_orden_id, p_cantidad, 'reproceso');
  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id, nota)
  values ('liberacion_no_conforme', p_item_orden_id, p_cantidad, v_lote_id, v_usuario_id, p_nota);

  return jsonb_build_object('id', v_liberacion_id, 'item_orden_id', p_item_orden_id, 'cantidad', p_cantidad, 'lote_numero', v_numero);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.liberar_no_conforme_aliado(p_solicitud_id uuid, p_cantidad integer, p_operario_nombre text, p_persona_aliado_libera text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_solicitud no_conformes_aliados%rowtype;
  v_persona text;
  v_liberado_previo integer;
  v_pendiente integer;
  v_completa boolean;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion')) THEN RAISE EXCEPTION 'Esta operacion requiere Produccion o Administrador.' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_libera)) AND NOT activo) THEN RAISE EXCEPTION 'Nombre de personal inactivo. Selecciona uno activo.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_persona := nullif(trim(p_persona_aliado_libera), '');
  if v_persona is null then
    raise exception 'Debes indicar quién de Aliados realizó la liberación.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select * into v_solicitud from no_conformes_aliados where id = p_solicitud_id for update;
  if not found then raise exception 'La solicitud no existe.'; end if;
  if v_solicitud.estado <> 'pendiente' then
    raise exception 'Esta solicitud ya fue liberada por completo.';
  end if;

  select coalesce(sum(cantidad), 0) into v_liberado_previo
    from liberaciones_aliados where solicitud_id = p_solicitud_id;

  v_pendiente := v_solicitud.cantidad_solicitada - v_liberado_previo;
  if p_cantidad > v_pendiente then
    raise exception 'LÍMITE EXCEDIDO: solo quedan % Uds pendientes por liberar.', v_pendiente;
  end if;

  v_completa := (v_liberado_previo + p_cantidad) >= v_solicitud.cantidad_solicitada;

  insert into liberaciones_aliados
    (solicitud_id, cantidad, usuario_produccion_nombre, persona_aliado_libera, nota, es_entrega_completa)
  values
    (p_solicitud_id, p_cantidad, p_operario_nombre, v_persona, p_nota, v_completa);

  if v_completa then
    update no_conformes_aliados set estado = 'liberado' where id = p_solicitud_id;
  end if;

  -- Ya NO se inserta ningún movimiento al liberar.

  return jsonb_build_object(
    'id', p_solicitud_id, 'completa', v_completa, 'liberado_total', v_liberado_previo + p_cantidad
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text DEFAULT ''::text, p_recibido_de_produccion text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_usuario_id uuid;
  v_recibido integer;
  v_devolucion_id uuid;
  v_recibido_de text;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.personal_produccion WHERE lower(trim(nombre))=lower(trim(p_recibido_de_produccion)) AND NOT activo) THEN RAISE EXCEPTION 'Nombre de personal inactivo. Selecciona uno activo.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_recibido_de := nullif(trim(p_recibido_de_produccion), '');
  if v_recibido_de is null then
    raise exception 'Debes indicar quién de Producción entregó esta prenda.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  -- CORREGIDO: se valida contra lo que YA está recibido en Bodega, no
  -- contra lo entregado por Producción (que puede incluir cosas en tránsito).
  select coalesce(sum(case
           when tipo = 'recepcion' then cantidad
           when tipo = 'devolucion_produccion' then -cantidad
           else 0
         end), 0)
    into v_recibido
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_recibido then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds recibidas en Bodega para este producto.', v_recibido;
  end if;

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into devoluciones_produccion
    (item_orden_id, causal_id, cantidad, operario_id, operario_nombre, nota, recibido_de_produccion)
  values
    (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota, v_recibido_de)
  returning id into v_devolucion_id;

  insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)
  values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);

  return jsonb_build_object('id', v_devolucion_id, 'item_orden_id', p_item_orden_id, 'cantidad', p_cantidad);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.registrar_sobrante(p_item_orden_id uuid, p_lote_item_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_id uuid;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;

  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  insert into sobrantes_bodega (item_orden_id, lote_item_id, cantidad, operario_nombre, nota)
  values (p_item_orden_id, p_lote_item_id, p_cantidad, p_operario_nombre, p_nota)
  returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.resolver_sobrante(p_id uuid, p_resolucion text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
  v_resolucion text;
BEGIN
 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;

  v_resolucion := nullif(trim(p_resolucion), '');
  if v_resolucion is null then
    raise exception 'Debes indicar qué se decidió hacer con este sobrante.';
  end if;

  update sobrantes_bodega set
    estado = 'resuelto',
    resolucion = v_resolucion,
    fecha_resolucion = now()
  where id = p_id and estado = 'pendiente';

  if not found then
    raise exception 'El sobrante no existe o ya fue resuelto.';
  end if;

  return jsonb_build_object('id', p_id);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_li lote_items%rowtype;
  v_recibido_previo integer;
  v_pendiente integer;
  v_completa boolean;
  v_recibido_por text;
  v_pendientes_en_lote integer;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_recibido_por := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN RAISE EXCEPTION 'Estante inactivo o inexistente.'; END IF;


  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_recibido_por := nullif(trim(p_recibido_por), '');
  if v_recibido_por is null then
    raise exception 'Debes indicar quién de Logística recibió esta prenda.';
  end if;

  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then raise exception 'La línea del lote no existe.'; end if;
  if v_li.estado <> 'en_transito' then raise exception 'Esta línea ya fue cerrada.'; end if;
  if p_cantidad is null or p_cantidad <= 0 then raise exception 'La cantidad debe ser mayor a 0.'; end if;
  if not exists (select 1 from ubicaciones where id = p_ubicacion_id and activa) then
    raise exception 'Ubicación no válida.';
  end if;

  v_recibido_previo := coalesce(v_li.cantidad_recibida, 0);
  v_pendiente := v_li.cantidad_enviada - v_recibido_previo;

  if p_cantidad > v_pendiente then
    raise exception
      'LÍMITE EXCEDIDO: solo faltan % Uds por recibir en esta línea. Si llegó más de lo declarado, usa la Bandeja de Sobrantes para el exceso.',
      v_pendiente;
  end if;

  v_completa := (v_recibido_previo + p_cantidad) >= v_li.cantidad_enviada;

  update lote_items set
    cantidad_recibida = v_recibido_previo + p_cantidad,
    ubicacion_destino_id = p_ubicacion_id,
    recibido_por = v_recibido_por,
    fecha_recepcion = now(),
    estado = case when v_completa then 'recibido_conforme' else 'en_transito' end
  where id = p_lote_item_id;

  insert into movimientos (tipo, item_orden_id, cantidad, ubicacion_id, lote_id, lote_item_id, nota)
  values ('recepcion', v_li.item_orden_id, p_cantidad, p_ubicacion_id, v_li.lote_id, p_lote_item_id, p_nota);

  select count(*) into v_pendientes_en_lote from lote_items where lote_id = v_li.lote_id and estado = 'en_transito';
  update lotes set estado = case when v_pendientes_en_lote = 0 then 'recibido_completo' else 'recibido_parcial' end
  where id = v_li.lote_id;

  return jsonb_build_object(
    'lote_item_id', p_lote_item_id, 'completa', v_completa,
    'recibido_total', v_recibido_previo + p_cantidad, 'pendiente', v_li.cantidad_enviada - (v_recibido_previo + p_cantidad)
  );
end;
$function$
;
-- Adaptación funcionalidad 055

-- Basado en el informe (15), PostgreSQL 17.6, esquema public.
-- No copia, elimina ni reinicia datos. Cambios incrementales, transaccionales.
-- Las correcciones se agregan al ledger con signo y referencia de auditoria.
-- Se conservan movimientos originales y se sincronizan los totales de lotes.


SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $$ BEGIN
  
  IF to_regprocedure('public.recibir_lote_item(uuid,integer,uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Falta la recepcion de cinco parametros esperada en PRUEBAS.';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_correcciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.items_orden(id),
  orden_id uuid NOT NULL REFERENCES public.ordenes_produccion(id),
  actor_id uuid NOT NULL,
  actor text NOT NULL,
  fecha timestamptz NOT NULL DEFAULT now(),
  campo text NOT NULL,
  anterior jsonb, nuevo jsonb,
  motivo text NOT NULL CHECK (length(trim(motivo)) > 0),
  antes jsonb NOT NULL, despues jsonb NOT NULL,
  lote_item_id uuid REFERENCES public.lote_items(id),
  ubicacion_id uuid REFERENCES public.ubicaciones(id),
  lote_antes jsonb, lote_despues jsonb
);
CREATE INDEX IF NOT EXISTS admin_correcciones_item_fecha ON public.admin_correcciones(item_id, fecha DESC);
ALTER TABLE public.admin_correcciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_fecha_entrega date;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_fecha_entrega_activa boolean NOT NULL DEFAULT false;
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS admin_correccion_id uuid REFERENCES public.admin_correcciones(id);
CREATE INDEX IF NOT EXISTS movimientos_admin_correccion_idx ON public.movimientos(admin_correccion_id)
  WHERE admin_correccion_id IS NOT NULL;

-- NOT VALID mantiene datos historicos, pero valida TODOS los nuevos cambios.
-- No permite cantidades negativas ordinarias: solo correcciones auditadas.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.movimientos'::regclass
                 AND conname = 'movimientos_cantidad_admin_check') THEN
    ALTER TABLE public.movimientos ADD CONSTRAINT movimientos_cantidad_admin_check
      CHECK (cantidad > 0 OR (cantidad < 0 AND admin_correccion_id IS NOT NULL)) NOT VALID;
  END IF;
END $$;

DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.movimientos'::regclass AND conname='movimientos_cantidad_check' AND pg_get_constraintdef(oid)='CHECK ((cantidad > 0))') THEN RAISE EXCEPTION 'Restricción de cantidad inesperada.'; END IF;
 ALTER TABLE public.movimientos DROP CONSTRAINT movimientos_cantidad_check;
END $$;
CREATE OR REPLACE FUNCTION public.admin_es_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT auth.uid() IS NOT NULL AND EXISTS (
  SELECT 1 FROM public.usuarios WHERE auth_id = auth.uid() AND rol = 'admin' AND activo
); $$;
REVOKE ALL ON FUNCTION public.admin_es_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_es_admin() TO authenticated;

-- Impide elevar el propio rol usando la politica historica solo_autenticados.
DROP POLICY IF EXISTS admin_proteger_usuarios_insert ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_insert ON public.usuarios AS RESTRICTIVE
  FOR INSERT TO authenticated WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_usuarios_update ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_update ON public.usuarios AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_usuarios_delete ON public.usuarios;
CREATE POLICY admin_proteger_usuarios_delete ON public.usuarios AS RESTRICTIVE
  FOR DELETE TO authenticated USING (public.admin_es_admin());

-- Las correcciones solo pueden escribirse dentro de la RPC SECURITY DEFINER.
REVOKE ALL ON public.admin_correcciones FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_correcciones TO authenticated;
DROP POLICY IF EXISTS admin_leer_auditoria ON public.admin_correcciones;
CREATE POLICY admin_leer_auditoria ON public.admin_correcciones FOR SELECT
  TO authenticated USING (public.admin_es_admin());
DROP POLICY IF EXISTS admin_proteger_movimientos ON public.movimientos;
CREATE POLICY admin_proteger_movimientos ON public.movimientos AS RESTRICTIVE
  FOR ALL TO authenticated USING (true) WITH CHECK (admin_correccion_id IS NULL);
DROP POLICY IF EXISTS admin_no_borrar_ajustes ON public.movimientos;
CREATE POLICY admin_no_borrar_ajustes ON public.movimientos AS RESTRICTIVE
  FOR DELETE TO authenticated USING (admin_correccion_id IS NULL);
DROP POLICY IF EXISTS admin_no_modificar_ajustes ON public.movimientos;
CREATE POLICY admin_no_modificar_ajustes ON public.movimientos AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (admin_correccion_id IS NULL);

DROP POLICY IF EXISTS admin_editar_items ON public.items_orden;
CREATE POLICY admin_editar_items ON public.items_orden AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());
DROP POLICY IF EXISTS admin_editar_ordenes ON public.ordenes_produccion;
CREATE POLICY admin_editar_ordenes ON public.ordenes_produccion AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (public.admin_es_admin()) WITH CHECK (public.admin_es_admin());

-- Aliados conserva el comportamiento historico de esta vista: no se migra
-- ese flujo como efecto secundario de la edicion del administrador.
CREATE OR REPLACE VIEW public.vista_kardex AS
SELECT io.id AS item_orden_id, op.numero_op, op.cliente, io.oc, io.codigo,
  io.descripcion, io.talla, io.cantidad_pedida, io.observacion AS observacion_op,
  op.fecha_esperada_produccion, op.fecha_esperada_logistica,
  coalesce(sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad
    WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad
    WHEN 'envio_aliado' THEN -m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad
    WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END),0)::bigint AS producido,
  coalesce(sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0)::bigint AS recibido,
  coalesce(sum(CASE WHEN m.tipo = 'despacho' THEN m.cantidad ELSE 0 END),0)::bigint AS despachado,
  CASE WHEN io.admin_fecha_entrega_activa THEN io.admin_fecha_entrega::timestamp AT TIME ZONE 'America/Bogota'
    ELSE max(CASE WHEN m.tipo = 'entrega_produccion' AND m.admin_correccion_id IS NULL THEN m.fecha END) END AS fecha_ultima_entrega,
  max(CASE WHEN m.tipo = 'recepcion' AND m.admin_correccion_id IS NULL THEN m.fecha END) AS fecha_ultima_recepcion,
  coalesce(sum(CASE m.tipo WHEN 'devolucion_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_reproceso,
  coalesce(sum(CASE m.tipo WHEN 'envio_aliado' THEN m.cantidad WHEN 'liberacion_aliado' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_aliados
FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id = io.orden_id
LEFT JOIN public.movimientos m ON m.item_orden_id = io.id
GROUP BY io.id, op.numero_op, op.cliente, op.fecha_esperada_produccion, op.fecha_esperada_logistica;

-- Las correcciones de PNC nuevas SI identifican la ubicacion afectada.
-- Los PNC antiguos sin ubicacion no se asignan automaticamente a un estante.
CREATE OR REPLACE VIEW public.vista_stock_ubicacion_detalle AS
SELECT m.item_orden_id, u.codigo AS ubicacion_codigo,
  sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad
    WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) AS cantidad
FROM public.movimientos m JOIN public.ubicaciones u ON u.id = m.ubicacion_id
WHERE m.tipo IN ('recepcion','despacho','devolucion_produccion')
GROUP BY m.item_orden_id, u.codigo
HAVING sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad
  WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) > 0;

CREATE OR REPLACE FUNCTION public.admin_contexto_edicion(p_item_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE v jsonb; k jsonb; o uuid; v_version text;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  SELECT orden_id INTO o FROM public.items_orden WHERE id = p_item_id;
  IF o IS NULL THEN RAISE EXCEPTION 'La fila no existe.'; END IF;
  SELECT to_jsonb(t) INTO k FROM public.vista_kardex t WHERE item_orden_id = p_item_id;
  k := jsonb_set(k, '{fecha_ultima_entrega}', coalesce(to_jsonb(
    ((k->>'fecha_ultima_entrega')::timestamptz AT TIME ZONE 'America/Bogota')::date), 'null'::jsonb));
  -- El token incluye operaciones, metadatos, ubicaciones y lineas de la OP.
  SELECT md5(jsonb_build_array(
    (SELECT to_jsonb(t) FROM public.ordenes_produccion t WHERE id = o),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.items_orden t WHERE orden_id = o),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.movimientos t WHERE item_orden_id = p_item_id),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.lote_items t WHERE item_orden_id = p_item_id),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ubicaciones t),
    (SELECT count(*) FROM public.admin_correcciones WHERE orden_id = o)
  )::text) INTO v_version;
  v := jsonb_build_object('version', v_version, 'valores', k,
    'filas_orden', (SELECT count(*) FROM public.items_orden WHERE orden_id = o),
    'lotes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', li.id, 'numero', l.numero,
      'enviada', li.cantidad_enviada, 'recibida', coalesce(li.cantidad_recibida,0),
      'origen', li.origen) ORDER BY l.fecha_envio DESC,li.id)
      FROM public.lote_items li JOIN public.lotes l ON l.id = li.lote_id WHERE li.item_orden_id = p_item_id),'[]'::jsonb),
    'ubicaciones', coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'codigo',codigo) ORDER BY codigo)
      FROM public.ubicaciones WHERE activa),'[]'::jsonb),
    'historial', coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.fecha DESC) FROM (
      SELECT campo, anterior, nuevo, motivo, actor, fecha FROM public.admin_correcciones
      WHERE item_id = p_item_id OR (orden_id = o AND campo IN ('numero_op','cliente','fecha_esperada_produccion','fecha_esperada_logistica'))
      ORDER BY fecha DESC, id DESC LIMIT 20) h),'[]'::jsonb));
  RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.admin_contexto_edicion(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_contexto_edicion(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_editar_kardex(
  p_item_id uuid, p_campo text, p_valor jsonb, p_motivo text, p_version text,
  p_lote_item_id uuid DEFAULT NULL, p_ubicacion_id uuid DEFAULT NULL, p_confirmar boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE
  ctx jsonb; a jsonb; d jsonb; v jsonb; li public.lote_items%rowtype;
  io public.items_orden%rowtype; v_actor public.usuarios%rowtype;
  v_id uuid; v_tipo text; v_col text; v_num integer; v_delta integer;
  v_stock bigint; v_registrado bigint; v_p bigint; v_r bigint; v_d bigint; v_q bigint;
  v_text text; v_fecha date; v_lote_antes jsonb; v_lote_despues jsonb;
  v_nuevo_lote boolean := false;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF p_confirmar IS NULL THEN RAISE EXCEPTION 'Falta confirmar la operación.'; END IF;
  IF coalesce(length(trim(p_motivo)),0) = 0 THEN RAISE EXCEPTION 'Indica el motivo de la corrección.'; END IF;
  IF p_campo IS NULL OR p_campo NOT IN ('numero_op','cliente','oc','codigo','descripcion','talla','observacion_op',
    'cantidad_pedida','producido','recibido','despachado','pendiente_reproceso',
    'fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    RAISE EXCEPTION 'Campo no editable; selecciona el dato de origen del cálculo.';
  END IF;
  -- Bloqueo breve para validar y guardar una correccion como una unidad.
  -- Todas las correcciones adquieren tablas en el mismo orden.
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'La cuenta ya no es administradora.'; END IF;
  SELECT * INTO v_actor FROM public.usuarios WHERE auth_id = auth.uid() AND rol = 'admin' AND activo;
  SELECT * INTO io FROM public.items_orden WHERE id = p_item_id;
  ctx := public.admin_contexto_edicion(p_item_id);
  IF p_version IS DISTINCT FROM ctx->>'version' THEN
    RAISE EXCEPTION 'La fila cambió. Cierra y vuelve a abrir la edición antes de guardar.';
  END IF;
  a := ctx->'valores'; d := a; v := coalesce(p_valor, 'null'::jsonb);
  IF a->p_campo IS NOT DISTINCT FROM v THEN RAISE EXCEPTION 'El valor no cambió.'; END IF;

  IF p_campo IN ('cantidad_pedida','producido','recibido','despachado','pendiente_reproceso') THEN
    IF jsonb_typeof(v) <> 'number' OR (v #>> '{}') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'Ingresa una cantidad entera no negativa.';
    END IF;
    v_num := (v #>> '{}')::integer;
    IF p_campo = 'cantidad_pedida' AND v_num = 0 THEN RAISE EXCEPTION 'La cantidad pedida debe ser mayor a cero.'; END IF;
    v_delta := v_num - (a->>p_campo)::integer;
    d := jsonb_set(d, ARRAY[p_campo], v);
    IF p_campo = 'pendiente_reproceso' THEN
      d := jsonb_set(d, '{producido}', to_jsonb((a->>'producido')::bigint-v_delta));
      d := jsonb_set(d, '{recibido}', to_jsonb((a->>'recibido')::bigint-v_delta));
    END IF;
    v_q := (d->>'cantidad_pedida')::bigint; v_p := (d->>'producido')::bigint;
    v_r := (d->>'recibido')::bigint; v_d := (d->>'despachado')::bigint;
    IF v_p < 0 OR v_r < 0 OR v_d < 0 OR v_p > v_q OR v_d > v_q OR v_d > v_r OR v_r > v_p THEN
      RAISE EXCEPTION 'La corrección dejaría cantidades incompatibles. Revisa las operaciones relacionadas.';
    END IF;
    IF p_campo IN ('producido','recibido') THEN
      IF p_campo = 'producido' AND p_lote_item_id IS NULL AND v_delta > 0 THEN
        v_nuevo_lote := true;
        li.cantidad_enviada := 0; li.cantidad_recibida := 0; li.origen := 'entrega';
      ELSE
      SELECT * INTO li FROM public.lote_items WHERE id = p_lote_item_id AND item_orden_id = p_item_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona el lote afectado de esta fila.'; END IF;
      v_lote_antes := to_jsonb(li);
      END IF;
      IF EXISTS (SELECT 1 FROM public.movimientos WHERE lote_item_id = li.id AND tipo = 'ajuste_faltante_entrega') THEN
        RAISE EXCEPTION 'El lote está cerrado con faltante. Revisa esa corrección antes de cambiar su entrega o recepción.';
      END IF;
      IF p_campo = 'producido' THEN
        IF li.origen <> 'entrega' THEN RAISE EXCEPTION 'Selecciona un lote de entrega, no de reproceso.'; END IF;
        IF li.cantidad_enviada + v_delta <= 0 OR li.cantidad_enviada + v_delta < coalesce(li.cantidad_recibida,0) THEN
          RAISE EXCEPTION 'La entrega del lote debe ser positiva y cubrir lo recibido.';
        END IF;
      ELSIF coalesce(li.cantidad_recibida,0)+v_delta < 0 OR coalesce(li.cantidad_recibida,0)+v_delta > li.cantidad_enviada THEN
        RAISE EXCEPTION 'La recepción corregida debe estar entre cero y lo enviado en el lote.';
      END IF;
    END IF;
    IF p_campo IN ('recibido','despachado','pendiente_reproceso') THEN
      IF NOT EXISTS (SELECT 1 FROM public.ubicaciones WHERE id = p_ubicacion_id AND activa) THEN
        RAISE EXCEPTION 'Selecciona una ubicación válida.';
      END IF;
      SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
        WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO v_stock
      FROM public.movimientos WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id;
      IF v_stock + (CASE WHEN p_campo = 'recibido' THEN v_delta ELSE -v_delta END) < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente en la ubicación.';
      END IF;
      IF v_delta < 0 THEN
        v_tipo := CASE p_campo WHEN 'recibido' THEN 'recepcion' WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
        SELECT coalesce(sum(cantidad),0) INTO v_registrado FROM public.movimientos
        WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id AND tipo = v_tipo
          AND (p_campo <> 'recibido' OR lote_item_id = p_lote_item_id);
        IF v_registrado + v_delta < 0 THEN
          RAISE EXCEPTION 'No hay suficiente cantidad registrada en esa ubicación/lote para reducirla. Los registros históricos sin ubicación requieren conciliación explícita.';
        END IF;
      END IF;
    END IF;
  ELSIF p_campo IN ('fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    IF v <> 'null'::jsonb THEN
      IF jsonb_typeof(v) <> 'string' OR (v #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha inválida; usa AAAA-MM-DD.'; END IF;
      v_fecha := (v #>> '{}')::date;
    END IF;
    d := jsonb_set(d, ARRAY[p_campo], v);
  ELSE
    IF jsonb_typeof(v) <> 'string' THEN RAISE EXCEPTION 'El campo requiere texto.'; END IF;
    v_text := trim(v #>> '{}');
    IF p_campo IN ('numero_op','cliente','codigo','descripcion') AND v_text = '' THEN RAISE EXCEPTION 'Completa el valor del campo.'; END IF;
    IF p_campo = 'numero_op' AND EXISTS (SELECT 1 FROM public.ordenes_produccion WHERE numero_op = v_text AND id <> io.orden_id) THEN
      RAISE EXCEPTION 'Ya existe otra orden con ese número.';
    END IF;
    IF p_campo IN ('codigo','talla') AND EXISTS (SELECT 1 FROM public.items_orden WHERE orden_id = io.orden_id AND id <> io.id
      AND codigo = CASE WHEN p_campo = 'codigo' THEN v_text ELSE io.codigo END
      AND talla = CASE WHEN p_campo = 'talla' THEN v_text ELSE io.talla END) THEN
      RAISE EXCEPTION 'Ya existe el código y talla en esta OP.';
    END IF;
    v := to_jsonb(v_text); d := jsonb_set(d, ARRAY[p_campo],v);
  END IF;
  IF NOT p_confirmar THEN RETURN jsonb_build_object('antes',a,'despues',d,'guardado',false); END IF;
  INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues,lote_item_id,ubicacion_id,lote_antes)
  VALUES(io.id,io.orden_id,auth.uid(),v_actor.nombre,p_campo,a->p_campo,v,trim(p_motivo),a,d,
    CASE WHEN p_campo IN ('producido','recibido') THEN p_lote_item_id END,
    CASE WHEN p_campo IN ('recibido','despachado','pendiente_reproceso') THEN p_ubicacion_id END,v_lote_antes)
  RETURNING id INTO v_id;
  IF p_campo IN ('producido','recibido','despachado','pendiente_reproceso') THEN
    IF v_nuevo_lote THEN
      INSERT INTO public.lotes(numero,operario_id,operario_nombre)
      VALUES('AJUSTE-'||v_id::text,v_actor.id,v_actor.nombre) RETURNING id INTO li.lote_id;
      INSERT INTO public.lote_items(lote_id,item_orden_id,cantidad_enviada,origen)
      VALUES(li.lote_id,io.id,v_delta,'entrega') RETURNING id INTO li.id;
      UPDATE public.admin_correcciones SET lote_item_id=li.id WHERE id=v_id;
    END IF;
    v_tipo := CASE p_campo WHEN 'producido' THEN 'entrega_produccion' WHEN 'recibido' THEN 'recepcion'
      WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
    INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,lote_id,lote_item_id,usuario_id,nota,admin_correccion_id)
    VALUES(v_tipo,p_item_id,v_delta,CASE WHEN p_campo <> 'producido' THEN p_ubicacion_id END,
      li.lote_id,li.id,v_actor.id,'Corrección administrativa: '||trim(p_motivo),v_id);
    IF p_campo IN ('producido','recibido') THEN
      UPDATE public.lote_items SET
        cantidad_enviada = cantidad_enviada + CASE WHEN p_campo = 'producido' AND NOT v_nuevo_lote THEN v_delta ELSE 0 END,
        cantidad_recibida = CASE WHEN p_campo = 'recibido' THEN coalesce(cantidad_recibida,0)+v_delta ELSE cantidad_recibida END
      WHERE id = li.id;
      UPDATE public.lote_items SET estado = CASE WHEN coalesce(cantidad_recibida,0) >= cantidad_enviada
        THEN 'recibido_conforme' ELSE 'en_transito' END WHERE id = li.id;
      UPDATE public.lotes SET estado = CASE
        WHEN NOT EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND estado = 'en_transito') THEN 'recibido_completo'
        WHEN EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND coalesce(cantidad_recibida,0)>0) THEN 'recibido_parcial'
        ELSE 'en_transito' END WHERE id = li.lote_id;
      SELECT to_jsonb(t) INTO v_lote_despues FROM public.lote_items t WHERE id = li.id;
      UPDATE public.admin_correcciones SET lote_despues = v_lote_despues WHERE id = v_id;
    END IF;
  ELSIF p_campo = 'cantidad_pedida' THEN
    UPDATE public.items_orden SET cantidad_pedida = v_num WHERE id = io.id;
  ELSIF p_campo = 'fecha_ultima_entrega' THEN
    UPDATE public.items_orden SET admin_fecha_entrega = v_fecha, admin_fecha_entrega_activa = true WHERE id = io.id;
  ELSIF p_campo IN ('fecha_esperada_produccion','fecha_esperada_logistica') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_fecha, io.orden_id;
  ELSIF p_campo IN ('numero_op','cliente') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_text, io.orden_id;
  ELSE
    v_col := CASE WHEN p_campo = 'observacion_op' THEN 'observacion' ELSE p_campo END;
    EXECUTE format('UPDATE public.items_orden SET %I = $1 WHERE id = $2', v_col) USING v_text, io.id;
  END IF;
  RETURN jsonb_build_object('antes',a,'despues',d,'guardado',true,'auditoria_id',v_id);
END $$;
REVOKE ALL ON FUNCTION public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean) TO authenticated;

-- Despacho debe descontar el PNC ubicado que ahora puede registrar el admin.
-- Misma firma: no se agrega una sobrecarga ni se modifica el contrato Flutter.
CREATE OR REPLACE FUNCTION public.despachar(p_item_orden_id uuid, p_cantidad integer, p_ubicacion_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE v_stock bigint; v_recibido bigint; v_despachado bigint; v_pedida integer;
BEGIN
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN RAISE EXCEPTION 'La cantidad debe ser mayor a cero.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN
    RAISE EXCEPTION 'Ubicación no válida.';
  END IF;
  SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
    WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO v_stock
  FROM public.movimientos WHERE item_orden_id=p_item_orden_id AND ubicacion_id=p_ubicacion_id;
  SELECT recibido,despachado,cantidad_pedida INTO v_recibido,v_despachado,v_pedida
  FROM public.vista_kardex WHERE item_orden_id=p_item_orden_id;
  IF v_pedida IS NULL THEN RAISE EXCEPTION 'El producto no existe.'; END IF;
  IF p_cantidad > v_stock OR p_cantidad > v_recibido-v_despachado THEN
    RAISE EXCEPTION 'Stock insuficiente para despachar.';
  END IF;
  IF p_cantidad > v_pedida-v_despachado THEN RAISE EXCEPTION 'La cantidad supera el pendiente por despachar.'; END IF;
  INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id)
  VALUES('despacho',p_item_orden_id,p_cantidad,p_ubicacion_id);
  RETURN jsonb_build_object('item_orden_id',p_item_orden_id,'cantidad',p_cantidad);
END $$;

-- Las RPC operativas deben tomar el mismo bloqueo ANTES de leer saldos.
-- Evita que una entrega calcule un limite viejo mientras el admin corrige.
-- Solo agrega un prefijo al cuerpo; conserva firmas, defaults y ACL actuales.
DO $locks$
DECLARE f record; ddl text;
BEGIN
  FOR f IN SELECT p.oid, p.oid::regprocedure AS firma FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prokind='f' AND p.proname IN (
      'crear_lote','recibir_lote_item','cerrar_lote_item_con_faltante',
      'registrar_no_conforme','liberar_no_conforme','enviar_no_conforme_aliado',
      'liberar_no_conforme_aliado','importar_ordenes_produccion','importar_fechas_esperadas')
  LOOP
    ddl := pg_get_functiondef(f.oid);
    IF strpos(ddl,'ORBILOQ_ADMIN_LOCK_V55')=0 THEN
      IF ddl !~* E'\\mbegin\\M' THEN RAISE EXCEPTION 'No se reconoce el cuerpo de %',f.firma; END IF;
      ddl := regexp_replace(ddl, '^begin[ \t]*\r?$',
        E'begin\n  -- ORBILOQ_ADMIN_LOCK_V55\n  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;', 'im');
      IF strpos(ddl,'ORBILOQ_ADMIN_LOCK_V55')=0 THEN RAISE EXCEPTION 'No se pudo proteger %',f.firma; END IF;
      EXECUTE ddl;
    END IF;
    EXECUTE format('ALTER FUNCTION %s SET lock_timeout = %L',f.firma,'5s');
  END LOOP;
END $locks$;

-- Publicar metadatos para que otras sesiones refresquen al editar una OP.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='items_orden') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.items_orden;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='ordenes_produccion') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.ordenes_produccion;
    END IF;
  END IF;
END $$;
NOTIFY pgrst, 'reload schema';

-- Adaptación funcionalidad 057

-- No reduce recepciones, despachos ni stock. Conserva movimientos y auditoria.
-- Recalcula pendientes. Las recepciones y los lotes historicos se conservan.
-- Sustituye la RPC de 055/056; aplicar este archivo completo, no requiere repetir 056.

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  
  IF to_regprocedure('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero 055_edicion_admin.sql en PRUEBAS.';
  END IF;
END $$;
CREATE OR REPLACE FUNCTION public.admin_editar_kardex(
  p_item_id uuid, p_campo text, p_valor jsonb, p_motivo text, p_version text,
  p_lote_item_id uuid DEFAULT NULL, p_ubicacion_id uuid DEFAULT NULL, p_confirmar boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE
  ctx jsonb; a jsonb; d jsonb; v jsonb; li public.lote_items%rowtype;
  io public.items_orden%rowtype; v_actor public.usuarios%rowtype;
  v_id uuid; v_tipo text; v_col text; v_num integer; v_delta integer;
  v_stock bigint; v_registrado bigint; v_p bigint; v_r bigint; v_d bigint; v_q bigint;
  v_text text; v_fecha date; v_lote_antes jsonb; v_lote_despues jsonb;

BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF p_confirmar IS NULL THEN RAISE EXCEPTION 'Falta confirmar la operación.'; END IF;
  IF coalesce(length(trim(p_motivo)),0) = 0 THEN RAISE EXCEPTION 'Indica el motivo de la corrección.'; END IF;
  IF p_campo IS NULL OR p_campo NOT IN ('numero_op','cliente','oc','codigo','descripcion','talla','observacion_op',
    'cantidad_pedida','producido','recibido','despachado','pendiente_reproceso',
    'fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    RAISE EXCEPTION 'Campo no editable; selecciona el dato de origen del cálculo.';
  END IF;
  -- Bloqueo breve para validar y guardar una correccion como una unidad.
  -- Todas las correcciones adquieren tablas en el mismo orden.
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'La cuenta ya no es administradora.'; END IF;
  SELECT * INTO v_actor FROM public.usuarios WHERE auth_id = auth.uid() AND rol = 'admin' AND activo;
  SELECT * INTO io FROM public.items_orden WHERE id = p_item_id;
  ctx := public.admin_contexto_edicion(p_item_id);
  IF p_version IS DISTINCT FROM ctx->>'version' THEN
    RAISE EXCEPTION 'La fila cambió. Cierra y vuelve a abrir la edición antes de guardar.';
  END IF;
  a := ctx->'valores'; d := a; v := coalesce(p_valor, 'null'::jsonb);
  IF a->p_campo IS NOT DISTINCT FROM v THEN RAISE EXCEPTION 'El valor no cambió.'; END IF;

  IF p_campo IN ('cantidad_pedida','producido','recibido','despachado','pendiente_reproceso') THEN
    IF jsonb_typeof(v) <> 'number' OR (v #>> '{}') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'Ingresa una cantidad entera no negativa.';
    END IF;
    v_num := (v #>> '{}')::integer;
    IF p_campo = 'cantidad_pedida' AND v_num = 0 THEN RAISE EXCEPTION 'La cantidad pedida debe ser mayor a cero.'; END IF;
    v_delta := v_num - (a->>p_campo)::integer;
    d := jsonb_set(d, ARRAY[p_campo], v);
    IF p_campo = 'pendiente_reproceso' THEN
      d := jsonb_set(d, '{producido}', to_jsonb((a->>'producido')::bigint-v_delta));
      d := jsonb_set(d, '{recibido}', to_jsonb((a->>'recibido')::bigint-v_delta));
    END IF;
    v_q := (d->>'cantidad_pedida')::bigint; v_p := (d->>'producido')::bigint;
    v_r := (d->>'recibido')::bigint; v_d := (d->>'despachado')::bigint;
    IF v_p < 0 OR v_r < 0 OR v_d < 0 OR v_p > v_q OR v_d > v_q OR v_d > v_r OR (p_campo <> 'producido' AND v_r > v_p AND v_r-v_p > greatest((a->>'recibido')::bigint-(a->>'producido')::bigint,0)) THEN
      RAISE EXCEPTION 'La corrección dejaría cantidades incompatibles. Revisa las operaciones relacionadas.';
    END IF;
    IF p_campo = 'recibido' THEN
      SELECT * INTO li FROM public.lote_items WHERE id = p_lote_item_id AND item_orden_id = p_item_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona el lote afectado de esta recepción.'; END IF;
      v_lote_antes := to_jsonb(li);
      IF EXISTS (SELECT 1 FROM public.movimientos WHERE lote_item_id = li.id AND tipo = 'ajuste_faltante_entrega') THEN
        RAISE EXCEPTION 'La recepción está cerrada con faltante; requiere conciliación.';
      END IF;
      IF coalesce(li.cantidad_recibida,0)+v_delta < 0 OR coalesce(li.cantidad_recibida,0)+v_delta > li.cantidad_enviada THEN
        RAISE EXCEPTION 'La recepción corregida debe estar entre cero y lo enviado en el lote.';
      END IF;
    END IF;
    IF p_campo IN ('recibido','despachado','pendiente_reproceso') THEN
      IF NOT EXISTS (SELECT 1 FROM public.ubicaciones WHERE id = p_ubicacion_id AND activa) THEN
        RAISE EXCEPTION 'Selecciona una ubicación válida.';
      END IF;
      SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad
        WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0) INTO v_stock
      FROM public.movimientos WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id;
      IF v_stock + (CASE WHEN p_campo = 'recibido' THEN v_delta ELSE -v_delta END) < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente en la ubicación.';
      END IF;
      IF v_delta < 0 THEN
        v_tipo := CASE p_campo WHEN 'recibido' THEN 'recepcion' WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
        SELECT coalesce(sum(cantidad),0) INTO v_registrado FROM public.movimientos
        WHERE item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id AND tipo = v_tipo
          AND (p_campo <> 'recibido' OR lote_item_id = p_lote_item_id);
        IF v_registrado + v_delta < 0 THEN
          RAISE EXCEPTION 'No hay suficiente cantidad registrada en esa ubicación/lote para reducirla. Los registros históricos sin ubicación requieren conciliación explícita.';
        END IF;
      END IF;
    END IF;
  ELSIF p_campo IN ('fecha_ultima_entrega','fecha_esperada_produccion','fecha_esperada_logistica') THEN
    IF v <> 'null'::jsonb THEN
      IF jsonb_typeof(v) <> 'string' OR (v #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha inválida; usa AAAA-MM-DD.'; END IF;
      v_fecha := (v #>> '{}')::date;
    END IF;
    d := jsonb_set(d, ARRAY[p_campo], v);
  ELSE
    IF jsonb_typeof(v) <> 'string' THEN RAISE EXCEPTION 'El campo requiere texto.'; END IF;
    v_text := trim(v #>> '{}');
    IF p_campo IN ('numero_op','cliente','codigo','descripcion') AND v_text = '' THEN RAISE EXCEPTION 'Completa el valor del campo.'; END IF;
    IF p_campo = 'numero_op' AND EXISTS (SELECT 1 FROM public.ordenes_produccion WHERE numero_op = v_text AND id <> io.orden_id) THEN
      RAISE EXCEPTION 'Ya existe otra orden con ese número.';
    END IF;
    IF p_campo IN ('codigo','talla') AND EXISTS (SELECT 1 FROM public.items_orden WHERE orden_id = io.orden_id AND id <> io.id
      AND codigo = CASE WHEN p_campo = 'codigo' THEN v_text ELSE io.codigo END
      AND talla = CASE WHEN p_campo = 'talla' THEN v_text ELSE io.talla END) THEN
      RAISE EXCEPTION 'Ya existe el código y talla en esta OP.';
    END IF;
    v := to_jsonb(v_text); d := jsonb_set(d, ARRAY[p_campo],v);
  END IF;
  IF NOT p_confirmar THEN RETURN jsonb_build_object('antes',a,'despues',d,'guardado',false); END IF;
  INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues,lote_item_id,ubicacion_id,lote_antes)
  VALUES(io.id,io.orden_id,auth.uid(),v_actor.nombre,p_campo,a->p_campo,v,trim(p_motivo),a,d,
    CASE WHEN p_campo = 'recibido' THEN p_lote_item_id END,
    CASE WHEN p_campo IN ('recibido','despachado','pendiente_reproceso') THEN p_ubicacion_id END,v_lote_antes)
  RETURNING id INTO v_id;
  IF p_campo IN ('producido','recibido','despachado','pendiente_reproceso') THEN
    v_tipo := CASE p_campo WHEN 'producido' THEN 'entrega_produccion' WHEN 'recibido' THEN 'recepcion'
      WHEN 'despachado' THEN 'despacho' ELSE 'devolucion_produccion' END;
    INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,lote_id,lote_item_id,usuario_id,nota,admin_correccion_id)
    VALUES(v_tipo,p_item_id,v_delta,CASE WHEN p_campo <> 'producido' THEN p_ubicacion_id END,
      li.lote_id,li.id,v_actor.id,'Corrección administrativa: '||trim(p_motivo),v_id);
    IF p_campo = 'recibido' THEN
      UPDATE public.lote_items SET
        cantidad_recibida = CASE WHEN p_campo = 'recibido' THEN coalesce(cantidad_recibida,0)+v_delta ELSE cantidad_recibida END
      WHERE id = li.id;
      UPDATE public.lote_items SET estado = CASE WHEN coalesce(cantidad_recibida,0) > cantidad_enviada THEN 'recibido_con_novedad' WHEN coalesce(cantidad_recibida,0) = cantidad_enviada
        THEN 'recibido_conforme' ELSE 'en_transito' END WHERE id = li.id;
      UPDATE public.lotes SET estado = CASE
        WHEN NOT EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND estado = 'en_transito') THEN 'recibido_completo'
        WHEN EXISTS (SELECT 1 FROM public.lote_items WHERE lote_id = li.lote_id AND coalesce(cantidad_recibida,0)>0) THEN 'recibido_parcial'
        ELSE 'en_transito' END WHERE id = li.lote_id;
      SELECT to_jsonb(t) INTO v_lote_despues FROM public.lote_items t WHERE id = li.id;
      UPDATE public.admin_correcciones SET lote_despues = v_lote_despues WHERE id = v_id;
    END IF;
  ELSIF p_campo = 'cantidad_pedida' THEN
    UPDATE public.items_orden SET cantidad_pedida = v_num WHERE id = io.id;
  ELSIF p_campo = 'fecha_ultima_entrega' THEN
    UPDATE public.items_orden SET admin_fecha_entrega = v_fecha, admin_fecha_entrega_activa = true WHERE id = io.id;
  ELSIF p_campo IN ('fecha_esperada_produccion','fecha_esperada_logistica') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_fecha, io.orden_id;
  ELSIF p_campo IN ('numero_op','cliente') THEN
    EXECUTE format('UPDATE public.ordenes_produccion SET %I = $1 WHERE id = $2', p_campo) USING v_text, io.orden_id;
  ELSE
    v_col := CASE WHEN p_campo = 'observacion_op' THEN 'observacion' ELSE p_campo END;
    EXECUTE format('UPDATE public.items_orden SET %I = $1 WHERE id = $2', v_col) USING v_text, io.id;
  END IF;
  RETURN jsonb_build_object('antes',a,'despues',d,'guardado',true,'auditoria_id',v_id);
END $$;

NOTIFY pgrst, 'reload schema';

-- Adaptación funcionalidad 058

-- Borrado logico: conserva items, OP, lotes, movimientos, stock y auditoria.
-- No ejecutar en PRODUCCION: preparar migracion especifica al desplegar.

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  
  IF to_regprocedure('public.admin_contexto_edicion(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero 055 y 057 en PRUEBAS.';
  END IF;
END $$;
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS admin_eliminado_en timestamptz;
-- La vista conserva todas las filas: las tablas de la app filtran la marca.
CREATE OR REPLACE VIEW public.vista_kardex AS
SELECT io.id AS item_orden_id, op.numero_op, op.cliente, io.oc, io.codigo,
  io.descripcion, io.talla, io.cantidad_pedida, io.observacion AS observacion_op,
  op.fecha_esperada_produccion, op.fecha_esperada_logistica,
  coalesce(sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad
    WHEN 'devolucion_produccion' THEN -m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad
    WHEN 'envio_aliado' THEN -m.cantidad WHEN 'liberacion_aliado' THEN m.cantidad
    WHEN 'ajuste_faltante_entrega' THEN -m.cantidad ELSE 0 END),0)::bigint AS producido,
  coalesce(sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0)::bigint AS recibido,
  coalesce(sum(CASE WHEN m.tipo = 'despacho' THEN m.cantidad ELSE 0 END),0)::bigint AS despachado,
  CASE WHEN io.admin_fecha_entrega_activa THEN io.admin_fecha_entrega::timestamp AT TIME ZONE 'America/Bogota'
    ELSE max(CASE WHEN m.tipo = 'entrega_produccion' AND m.admin_correccion_id IS NULL THEN m.fecha END) END AS fecha_ultima_entrega,
  max(CASE WHEN m.tipo = 'recepcion' AND m.admin_correccion_id IS NULL THEN m.fecha END) AS fecha_ultima_recepcion,
  coalesce(sum(CASE m.tipo WHEN 'devolucion_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_reproceso,
  coalesce(sum(CASE m.tipo WHEN 'envio_aliado' THEN m.cantidad WHEN 'liberacion_aliado' THEN -m.cantidad ELSE 0 END),0)::bigint AS pendiente_aliados, io.admin_eliminado_en
FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id = io.orden_id
LEFT JOIN public.movimientos m ON m.item_orden_id = io.id
GROUP BY io.id, op.numero_op, op.cliente, op.fecha_esperada_produccion, op.fecha_esperada_logistica;

CREATE OR REPLACE FUNCTION public.admin_eliminar_linea(p_item_id uuid, p_version text, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public SET lock_timeout = '5s'
AS $$
DECLARE ctx jsonb; io public.items_orden%rowtype; actor_nombre text; marca timestamptz;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF coalesce(length(trim(p_motivo)),0) = 0 THEN RAISE EXCEPTION 'Indica el motivo del borrado.'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones
    IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  ctx := public.admin_contexto_edicion(p_item_id);
  IF p_version IS DISTINCT FROM ctx->>'version' THEN
    RAISE EXCEPTION 'La fila cambio. Cierra y vuelve a abrir la confirmacion.';
  END IF;
  SELECT * INTO io FROM public.items_orden WHERE id = p_item_id;
  IF io.admin_eliminado_en IS NOT NULL THEN RAISE EXCEPTION 'La fila ya esta borrada.'; END IF;
  SELECT nombre INTO actor_nombre FROM public.usuarios WHERE auth_id = auth.uid() AND activo AND rol = 'admin';
  marca := clock_timestamp();
  UPDATE public.items_orden SET admin_eliminado_en = marca WHERE id = p_item_id;
  INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues)
  VALUES(io.id,io.orden_id,auth.uid(),actor_nombre,'admin_eliminado_en','null'::jsonb,to_jsonb(marca),trim(p_motivo),
    ctx->'valores',jsonb_set(ctx->'valores','{admin_eliminado_en}',to_jsonb(marca)));
END $$;
REVOKE ALL ON FUNCTION public.admin_eliminar_linea(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_eliminar_linea(uuid,text,text) TO authenticated;
NOTIFY pgrst, 'reload schema';

-- Adaptación funcionalidad 059

-- Importacion atomica y auditada. No elimina items, lotes ni movimientos.

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  
  IF to_regprocedure('public.admin_eliminar_linea(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Aplicar primero 055, 057 y 058 en PRUEBAS.';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_importaciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid NOT NULL, fecha timestamptz NOT NULL DEFAULT now(),
  vista text NOT NULL, motivo text NOT NULL, version_origen text NOT NULL,
  archivo jsonb NOT NULL, resumen jsonb NOT NULL
);
ALTER TABLE public.admin_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_importaciones FROM anon, authenticated;
GRANT SELECT ON public.admin_importaciones TO authenticated;
DROP POLICY IF EXISTS admin_lectura ON public.admin_importaciones;
CREATE POLICY admin_lectura ON public.admin_importaciones FOR SELECT TO authenticated USING (public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.admin_version_kardex() RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
  SELECT md5(jsonb_build_array(
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.items_orden t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ordenes_produccion t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.movimientos t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.lote_items t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ubicaciones t)
  )::text);
$$;
REVOKE ALL ON FUNCTION public.admin_version_kardex() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_exportar_kardex() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public SET lock_timeout = '5s' AS $$
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  RETURN jsonb_build_object('version',public.admin_version_kardex(),'filas',coalesce((
    SELECT jsonb_agg(to_jsonb(k) || jsonb_build_object('fecha_ultima_entrega',
      (k.fecha_ultima_entrega AT TIME ZONE 'America/Bogota')::date) ORDER BY numero_op,codigo,talla,item_orden_id)
    FROM public.vista_kardex k WHERE admin_eliminado_en IS NULL),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.admin_exportar_kardex() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_exportar_kardex() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_importar_kardex(
  p_vista text, p_version text, p_filas jsonb, p_motivo text, p_confirmar boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
SET lock_timeout = '5s' SET statement_timeout = '60s' AS $$
DECLARE
  f jsonb; a jsonb; d jsonb; cambios jsonb := '[]'; resultado jsonb;
  io public.items_orden%rowtype; actor public.usuarios%rowtype;
  ident uuid; orden uuid; ubic uuid; audit uuid; lote_importacion uuid := gen_random_uuid();
  q integer; pr integer; re integer; de integer; nc integer; dp integer; dr integer; dd integer; dn integer;
  numero_fila integer := 1; nuevas integer := 0; modificadas integer := 0; ausentes integer;
  key text; fecha date; stock bigint; ids uuid[] := '{}'; nueva boolean;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF p_vista IS NULL OR p_vista NOT IN ('produccion','logistica') OR p_confirmar IS NULL THEN RAISE EXCEPTION 'Vista o confirmacion invalida.'; END IF;
  IF coalesce(length(trim(p_motivo)),0)=0 THEN RAISE EXCEPTION 'Indica el motivo de la importacion.'; END IF;
  IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo invalido.'; END IF;
  IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 5000 THEN RAISE EXCEPTION 'Se requieren entre 1 y 5000 filas. No se admite un archivo vacio.'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  IF p_version IS DISTINCT FROM public.admin_version_kardex() THEN
    RAISE EXCEPTION 'Los datos cambiaron desde la exportacion. Exporta nuevamente y revisa tus cambios.';
  END IF;
  SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol='admin';

  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x GROUP BY x->>'numero_op',x->>'codigo',x->>'talla' HAVING count(*)>1) THEN
    RAISE EXCEPTION 'OP, codigo y talla duplicados en el archivo.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x GROUP BY x->>'numero_op'
      HAVING count(DISTINCT jsonb_build_array(x->'cliente',x->(CASE p_vista WHEN 'produccion' THEN 'fecha_esperada_produccion' ELSE 'fecha_esperada_logistica' END)))>1) THEN
    RAISE EXCEPTION 'Todas las filas de una OP deben tener el mismo cliente y fecha esperada.';
  END IF;
  -- La subtransaccion ejecuta las mismas validaciones y calculos en vista previa.
  -- Al finalizar la vista previa se revierte TODO; solo retorna el resumen.
  BEGIN
    FOR f IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
      numero_fila := numero_fila+1;
      IF jsonb_typeof(f) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Fila % invalida.',numero_fila; END IF;
      IF EXISTS (SELECT 1 FROM jsonb_object_keys(f) k WHERE NOT k=ANY(
        ARRAY['item_orden_id','numero_op','descripcion','codigo','talla','cliente','oc','observacion_op',
        'ubicacion_ajuste','cantidad_pedida','producido','pendiente_reproceso','fecha_ultima_entrega'] ||
        CASE p_vista WHEN 'produccion' THEN ARRAY['fecha_esperada_produccion'] ELSE ARRAY['recibido','despachado','fecha_esperada_logistica'] END)) THEN
        RAISE EXCEPTION 'Fila %: columna no permitida para esta vista.',numero_fila;
      END IF;
      IF jsonb_typeof(f->'item_orden_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'Fila %: falta ID FILA (dejar texto vacio solo para filas nuevas).',numero_fila; END IF;
      FOREACH key IN ARRAY ARRAY['numero_op','descripcion','codigo','talla','cliente','oc','observacion_op','ubicacion_ajuste'] LOOP
        IF jsonb_typeof(f->key) IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'Fila %: falta texto en %.',numero_fila,key; END IF;
        IF key IN ('numero_op','descripcion','codigo','talla','cliente') AND length(trim(f->>key))=0 THEN RAISE EXCEPTION 'Fila %: % obligatorio.',numero_fila,key; END IF;
      END LOOP;
      FOREACH key IN ARRAY ARRAY['cantidad_pedida','producido','pendiente_reproceso'] || CASE p_vista WHEN 'logistica' THEN ARRAY['recibido','despachado'] ELSE ARRAY[]::text[] END LOOP
        IF jsonb_typeof(f->key) IS DISTINCT FROM 'number' OR (f->>key) !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Fila %: % debe ser entero no negativo.',numero_fila,key; END IF;
      END LOOP;
      FOREACH key IN ARRAY ARRAY['fecha_ultima_entrega', CASE p_vista WHEN 'produccion' THEN 'fecha_esperada_produccion' ELSE 'fecha_esperada_logistica' END] LOOP
        IF NOT f ? key THEN RAISE EXCEPTION 'Fila %: falta %.',numero_fila,key; END IF;
        IF f->key <> 'null'::jsonb THEN
          IF jsonb_typeof(f->key)<>'string' OR (f->>key) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Fila %: fecha invalida.',numero_fila; END IF;
          fecha := (f->>key)::date;
        END IF;
      END LOOP;
      ident := nullif(f->>'item_orden_id','')::uuid;
      nueva := ident IS NULL;
      IF nueva THEN
        SELECT id INTO orden FROM public.ordenes_produccion WHERE numero_op=f->>'numero_op';
        IF orden IS NULL THEN
          INSERT INTO public.ordenes_produccion(numero_op,cliente) VALUES(f->>'numero_op',f->>'cliente') RETURNING id INTO orden;
        END IF;
        IF EXISTS (SELECT 1 FROM public.items_orden WHERE orden_id=orden AND codigo=f->>'codigo' AND talla=f->>'talla') THEN
          RAISE EXCEPTION 'Fila %: el producto ya existe. Conserva su ID original; no crees un duplicado.',numero_fila;
        END IF;
        INSERT INTO public.items_orden(orden_id,codigo,descripcion,talla,cantidad_pedida,oc,observacion)
        VALUES(orden,f->>'codigo',f->>'descripcion',f->>'talla',(f->>'cantidad_pedida')::integer,f->>'oc',f->>'observacion_op') RETURNING id INTO ident;
      END IF;
      SELECT * INTO io FROM public.items_orden WHERE id=ident;
      IF NOT FOUND OR io.admin_eliminado_en IS NOT NULL THEN RAISE EXCEPTION 'Fila %: ID inexistente o archivado.',numero_fila; END IF;
      IF ident=ANY(ids) THEN RAISE EXCEPTION 'ID repetido en fila %.',numero_fila; END IF;
      ids := array_append(ids,ident);
      orden := io.orden_id;
      -- No dividir accidentalmente una OP al modificar su numero en una sola talla.
      IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x JOIN public.items_orden i ON i.id=nullif(x->>'item_orden_id','')::uuid
        WHERE i.orden_id=orden AND x->>'numero_op' IS DISTINCT FROM f->>'numero_op') THEN
        RAISE EXCEPTION 'Todas las tallas de la misma OP deben conservar el mismo numero de OP.';
      END IF;
      SELECT to_jsonb(k) || jsonb_build_object('fecha_ultima_entrega',(k.fecha_ultima_entrega AT TIME ZONE 'America/Bogota')::date) INTO a
        FROM public.vista_kardex k WHERE item_orden_id=ident;
      q := (f->>'cantidad_pedida')::integer; pr := (f->>'producido')::integer; nc := (f->>'pendiente_reproceso')::integer;
      re := CASE p_vista WHEN 'logistica' THEN (f->>'recibido')::integer ELSE (a->>'recibido')::integer END;
      de := CASE p_vista WHEN 'logistica' THEN (f->>'despachado')::integer ELSE (a->>'despachado')::integer END;
      IF q<=0 OR pr>q OR de>q OR de>re OR re<0 OR de<0 THEN RAISE EXCEPTION 'Fila %: cantidades incompatibles (entregado/despachado no puede superar pedido; despacho no puede superar recibido).',numero_fila; END IF;
      dn := nc-(a->>'pendiente_reproceso')::integer;
      dp := pr-(a->>'producido')::integer+dn;
      dr := re-(a->>'recibido')::integer+dn;
      dd := de-(a->>'despachado')::integer;
      ubic := NULL;
      IF dn<>0 OR dr<>0 OR dd<>0 THEN
        SELECT id INTO ubic FROM public.ubicaciones WHERE codigo=f->>'ubicacion_ajuste' AND activa;
        IF ubic IS NULL THEN RAISE EXCEPTION 'Fila %: indica una UBICACION DEL AJUSTE activa para corregir recibido, despachado o no conforme.',numero_fila; END IF;
        SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
          INTO stock FROM public.movimientos WHERE item_orden_id=ident AND ubicacion_id=ubic;
        IF stock+dr-dd-dn<0 THEN RAISE EXCEPTION 'Fila %: el ajuste dejaria stock negativo en el estante. Distribuye previamente la correccion por ubicaciones.',numero_fila; END IF;
      END IF;
      d := a || (f-'ubicacion_ajuste'-'item_orden_id');
      IF nueva OR a IS DISTINCT FROM d THEN
        IF nueva THEN nuevas:=nuevas+1; ELSE modificadas:=modificadas+1; END IF;
        INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues,ubicacion_id)
        VALUES(ident,orden,auth.uid(),actor.nombre,'importacion_excel',CASE WHEN nueva THEN 'null'::jsonb ELSE a END,d,
          trim(p_motivo)||' [importacion '||lote_importacion||']',CASE WHEN nueva THEN '{}'::jsonb ELSE a END,d,ubic) RETURNING id INTO audit;
        INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,nota,admin_correccion_id)
        SELECT tipo,ident,cantidad,CASE WHEN tipo<>'entrega_produccion' THEN ubic END,actor.id,'Importacion Excel: '||trim(p_motivo),audit
          FROM (VALUES ('entrega_produccion',dp),('recepcion',dr),('despacho',dd),('devolucion_produccion',dn)) ajustes(tipo,cantidad) WHERE cantidad<>0;
        UPDATE public.items_orden SET codigo=f->>'codigo',descripcion=f->>'descripcion',talla=f->>'talla',
          oc=f->>'oc',observacion=f->>'observacion_op',cantidad_pedida=q,
          admin_fecha_entrega=CASE WHEN nueva OR a->'fecha_ultima_entrega' IS DISTINCT FROM f->'fecha_ultima_entrega' THEN (f->>'fecha_ultima_entrega')::date ELSE admin_fecha_entrega END,
          admin_fecha_entrega_activa=admin_fecha_entrega_activa OR nueva OR a->'fecha_ultima_entrega' IS DISTINCT FROM f->'fecha_ultima_entrega'
          WHERE id=ident;
        UPDATE public.ordenes_produccion SET numero_op=f->>'numero_op',cliente=f->>'cliente',
          fecha_esperada_produccion=CASE p_vista WHEN 'produccion' THEN (f->>'fecha_esperada_produccion')::date ELSE fecha_esperada_produccion END,
          fecha_esperada_logistica=CASE p_vista WHEN 'logistica' THEN (f->>'fecha_esperada_logistica')::date ELSE fecha_esperada_logistica END WHERE id=orden;
        cambios := cambios || jsonb_build_array(jsonb_build_object('fila',numero_fila,'op',f->>'numero_op','codigo',f->>'codigo','talla',f->>'talla','nueva',nueva,'antes',CASE WHEN nueva THEN '{}'::jsonb ELSE a END,'despues',d));
      END IF;
    END LOOP;
    SELECT count(*) INTO ausentes FROM public.items_orden WHERE admin_eliminado_en IS NULL AND NOT id=ANY(ids);
    IF ausentes>0 THEN RAISE EXCEPTION 'Faltan % filas activas en el archivo. Exporta toda la tabla antes de importar.',ausentes; END IF;
    resultado := jsonb_build_object('nuevas',nuevas,'modificadas',modificadas,'total',jsonb_array_length(p_filas),'cambios',cambios,'guardado',p_confirmar);
    IF NOT p_confirmar THEN RAISE SQLSTATE 'P0590'; END IF;
    INSERT INTO public.admin_importaciones(id,actor_id,vista,motivo,version_origen,archivo,resumen)
      VALUES(lote_importacion,auth.uid(),p_vista,trim(p_motivo),p_version,p_filas,resultado);
  EXCEPTION WHEN SQLSTATE 'P0590' THEN NULL;
  END;
  RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_importar_kardex(text,text,jsonb,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_importar_kardex(text,text,jsonb,text,boolean) TO authenticated;
NOTIFY pgrst,'reload schema';

-- Adaptación funcionalidad 060

-- Conserva IDs, relaciones e historial. No elimina registros existentes.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 IF to_regprocedure('public.admin_exportar_kardex()') IS NULL THEN RAISE EXCEPTION 'Aplicar primero hasta 059 en DEV.'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_catalogos_historial (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid NOT NULL,
 fecha timestamptz NOT NULL DEFAULT now(), catalogo text NOT NULL, registro_id uuid NOT NULL,
 antes jsonb, despues jsonb NOT NULL
);
ALTER TABLE public.admin_catalogos_historial ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_catalogos_historial FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_catalogos_historial TO authenticated;
DROP POLICY IF EXISTS admin_lectura ON public.admin_catalogos_historial;
CREATE POLICY admin_lectura ON public.admin_catalogos_historial FOR SELECT TO authenticated USING(public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.wms_cuenta_activa() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo);
$$;
REVOKE ALL ON FUNCTION public.wms_cuenta_activa() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_cuenta_activa() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_catalogos_listar(p_tipo text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN ('usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados') THEN RAISE EXCEPTION 'Catalogo no permitido.'; END IF;
 EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object(''version'',md5(to_jsonb(t)::text)) ORDER BY %I,id),''[]''::jsonb) FROM public.%I t',CASE p_tipo WHEN 'ubicaciones' THEN 'codigo' ELSE 'nombre' END,p_tipo) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.admin_catalogos_guardar(p_tipo text,p_id uuid,p_nombre text,p_activo boolean,p_version text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; nombre_col text; activo_col text; ident uuid; nombre text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN ('ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados') THEN RAISE EXCEPTION 'Catalogo no permitido.'; END IF;
 nombre:=trim(p_nombre);
 IF coalesce(length(nombre),0) NOT BETWEEN 1 AND 150 OR p_activo IS NULL THEN RAISE EXCEPTION 'Indica un nombre de 1 a 150 caracteres y el estado.'; END IF;
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
 IF p_tipo='ubicaciones' THEN
   LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos,public.admin_correcciones,public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
 ELSE EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE',p_tipo); END IF;
 nombre_col:=CASE p_tipo WHEN 'ubicaciones' THEN 'codigo' ELSE 'nombre' END;
 activo_col:=CASE WHEN p_tipo IN ('ubicaciones','causales_devolucion') THEN 'activa' ELSE 'activo' END;
 IF p_id IS NOT NULL THEN
   EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_tipo) INTO anterior USING p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El registro cambio. Actualiza la lista y vuelve a editar.'; END IF;
 END IF;
 EXECUTE format('SELECT id FROM public.%I WHERE lower(trim(%I))=lower($1) AND id IS DISTINCT FROM $2 LIMIT 1',p_tipo,nombre_col) INTO ident USING nombre,p_id;
 IF ident IS NOT NULL AND (p_id IS NULL OR nombre IS DISTINCT FROM anterior->>nombre_col OR (p_activo AND NOT (anterior->>activo_col)::boolean)) THEN
   RAISE EXCEPTION 'Ya existe ese nombre, incluso si esta inactivo. Edita o reactiva el registro existente.';
 END IF;
 IF p_tipo='ubicaciones' AND NOT p_activo AND p_id IS NOT NULL THEN
   IF EXISTS(SELECT 1 FROM public.movimientos WHERE ubicacion_id=p_id GROUP BY item_orden_id
     HAVING sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END)<>0)
     OR EXISTS(SELECT 1 FROM public.lote_items WHERE ubicacion_destino_id=p_id AND estado='en_transito') THEN
     RAISE EXCEPTION 'El estante tiene existencias o recepciones pendientes. Concilialas antes de desactivarlo.';
   END IF;
 END IF;
 IF p_id IS NULL THEN
   EXECUTE format('INSERT INTO public.%I(%I,%I) VALUES($1,$2) RETURNING to_jsonb(%I.*)',p_tipo,nombre_col,activo_col,p_tipo) INTO nuevo USING nombre,p_activo;
 ELSE
   EXECUTE format('UPDATE public.%I SET %I=$1,%I=$2 WHERE id=$3 RETURNING to_jsonb(%I.*)',p_tipo,nombre_col,activo_col,p_tipo) INTO nuevo USING nombre,p_activo,p_id;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),p_tipo,(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_guardar(p_id uuid,p_nombre text,p_rol text,p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
 SELECT to_jsonb(u) INTO anterior FROM public.usuarios u WHERE id=p_id;
 IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'La cuenta cambio. Actualiza la lista antes de guardar.'; END IF;
 IF p_rol IS NULL OR p_rol NOT IN ('admin','produccion','logistica') OR p_activo IS NULL OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Nombre, rol o estado invalido.'; END IF;
 IF (anterior->>'auth_id')::uuid=auth.uid() AND NOT p_activo THEN RAISE EXCEPTION 'No puedes desactivar tu propia cuenta.'; END IF;
 IF (anterior->>'activo')::boolean AND anterior->>'rol'='admin' AND (NOT p_activo OR p_rol<>'admin')
    AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE id<>p_id AND rol='admin' AND activo AND auth_id IS NOT NULL) THEN RAISE EXCEPTION 'Debe permanecer al menos un administrador activo con acceso.'; END IF;
 UPDATE public.usuarios SET nombre=trim(p_nombre),rol=p_rol,activo=p_activo WHERE id=p_id RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),'usuarios',p_id,anterior,nuevo);
 RETURN nuevo;
END $$;

-- Solo la funcion de servidor puede vincular un alta de Auth; nunca el navegador.
CREATE OR REPLACE FUNCTION public.admin_usuario_registrar(p_actor uuid,p_auth_id uuid,p_numero text,p_nombre text,p_rol text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE nuevo jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_actor AND rol='admin' AND activo) THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_auth_id IS NULL OR p_numero IS NULL OR p_numero !~ '^[0-9]{1,30}$' OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 OR p_rol IS NULL OR p_rol NOT IN ('admin','produccion','logistica') THEN RAISE EXCEPTION 'Datos del usuario invalidos.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_auth_id AND email=p_numero||'@orbiloq.local') THEN RAISE EXCEPTION 'La cuenta de acceso no corresponde al numero de usuario.'; END IF;
 SELECT to_jsonb(u) INTO nuevo FROM public.usuarios u WHERE auth_id=p_auth_id AND numero_usuario=p_numero;
 IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_auth_id OR numero_usuario=p_numero) THEN RAISE EXCEPTION 'La cuenta o numero de usuario ya existe.'; END IF;
 INSERT INTO public.usuarios(numero_usuario,nombre,rol,auth_id,email,activo) VALUES(p_numero,trim(p_nombre),p_rol,p_auth_id,p_numero||'@orbiloq.local',true) RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(p_actor,'usuarios',(nuevo->>'id')::uuid,NULL,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_registrar(uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_registrar(uuid,uuid,text,text,text) TO service_role;

-- Reintentar un alta interrumpida solo recupera cuentas creadas por esta funcion.
CREATE OR REPLACE FUNCTION public.admin_usuario_alta_pendiente(p_numero text) RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT id FROM auth.users WHERE email=p_numero||'@orbiloq.local'
 AND raw_app_meta_data->>'orbiloq_alta_catalogo'='true'
 AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.users.id);
$$;
REVOKE ALL ON FUNCTION public.admin_usuario_alta_pendiente(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_alta_pendiente(text) TO service_role;

REVOKE ALL ON FUNCTION public.admin_catalogos_listar(text),public.admin_catalogos_guardar(text,uuid,text,boolean,text),public.admin_usuario_guardar(uuid,text,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_catalogos_listar(text),public.admin_catalogos_guardar(text,uuid,text,boolean,text),public.admin_usuario_guardar(uuid,text,text,boolean,text) TO authenticated;

-- Evitar saltarse las validaciones con escrituras directas.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.usuarios,public.ubicaciones,public.causales_devolucion,public.personal_logistica,public.personal_produccion,public.personal_aliados FROM authenticated,anon;

-- Una cuenta desactivada no puede leer ni escribir datos con un JWT aun vigente.
DO $politicas$ DECLARE t record; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('admin_catalogos_historial','admin_correcciones','admin_importaciones','causales_devolucion','despachos_oc','devoluciones_produccion','documentos','importaciones','items_orden','liberaciones_aliados','liberaciones_no_conforme','lote_items','lotes','movimientos','no_conformes_aliados','ordenes_produccion','personal_aliados','personal_logistica','personal_produccion','sobrantes_bodega','ubicaciones','usuarios') LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
   EXECUTE format('DROP POLICY IF EXISTS wms_requiere_cuenta_activa ON public.%I',t.tablename);
   EXECUTE format('CREATE POLICY wms_requiere_cuenta_activa ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.wms_cuenta_activa()) WITH CHECK (public.wms_cuenta_activa())',t.tablename);
 END LOOP;
 FOR t IN SELECT viewname FROM pg_views WHERE schemaname='public' AND viewname IN ('admin_reporte_auditoria_interno','admin_reporte_movimientos_interno','admin_reporte_nc_interno','vista_devoluciones','vista_kardex','vista_liberaciones','vista_liberaciones_aliados','vista_lote_items_detalle','vista_no_conformes_aliados','vista_sobrantes_bodega','vista_stock_ubicacion_detalle') LOOP
   EXECUTE format('ALTER VIEW public.%I SET (security_invoker=true)',t.viewname);
 END LOOP;
END $politicas$;

-- Altas rapidas conservan su uso operativo, pero nunca reactivan duplicados.
DO $personal$ DECLARE tabla text; funcion text; BEGIN
 FOREACH tabla IN ARRAY ARRAY['personal_logistica','personal_produccion','personal_aliados'] LOOP
   funcion:=CASE tabla WHEN 'personal_aliados' THEN 'agregar_personal_aliado' ELSE 'agregar_'||tabla END;
   EXECUTE format($ddl$
   CREATE OR REPLACE FUNCTION public.%I(p_nombre text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $body$
   DECLARE n text:=trim(p_nombre); v jsonb; BEGIN
     IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
     IF coalesce(length(n),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Indica un nombre de 1 a 150 caracteres.'; END IF;
     LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE;
     SELECT to_jsonb(t) INTO v FROM public.%I t WHERE lower(trim(nombre))=lower(n) ORDER BY activo DESC,id LIMIT 1;
     IF v IS NOT NULL THEN
       IF NOT (v->>'activo')::boolean THEN RAISE EXCEPTION 'Ese nombre esta inactivo. Solicita su revision al administrador.'; END IF;
       RETURN v;
     END IF;
     INSERT INTO public.%I(nombre) VALUES(n) RETURNING to_jsonb(%I.*) INTO v;
     INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),%L,(v->>'id')::uuid,NULL,v);
     RETURN v;
   END $body$;
   $ddl$,funcion,tabla,tabla,tabla,tabla,tabla);
   EXECUTE format('REVOKE ALL ON FUNCTION public.%I(text) FROM PUBLIC,anon',funcion);
   EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(text) TO authenticated',funcion);
 END LOOP;
END $personal$;

-- Las RPC antiguas tambien verifican la cuenta en el servidor, no solo la UI.
DO $rpc$ DECLARE f record; ddl text; guardia text; BEGIN
 FOR f IN SELECT p.oid,p.proname, p.oid::regprocedure firma,pg_get_function_arguments(p.oid) args
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN ('crear_lote','recibir_lote_item','cerrar_lote_item_con_faltante','despachar','registrar_no_conforme','liberar_no_conforme','enviar_no_conforme_aliado','liberar_no_conforme_aliado','registrar_sobrante','resolver_sobrante','importar_ordenes_produccion','importar_fechas_esperadas') LOOP
   ddl:=pg_get_functiondef(f.oid);
   IF strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN
     guardia:=E'BEGIN\n -- ORBILOQ_CUENTA_V60\n IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION ''Cuenta inactiva o sin acceso.'' USING ERRCODE=''42501''; END IF;\n';
     IF f.proname IN ('crear_lote','liberar_no_conforme','enviar_no_conforme_aliado','liberar_no_conforme_aliado') THEN
       guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN (''admin'',''produccion'')) THEN RAISE EXCEPTION ''Esta operacion requiere Produccion o Administrador.'' USING ERRCODE=''42501''; END IF;\n';
     ELSIF f.proname NOT LIKE 'importar_%' THEN
       guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN (''admin'',''logistica'')) THEN RAISE EXCEPTION ''Esta operacion requiere Logistica o Administrador.'' USING ERRCODE=''42501''; END IF;\n';
     END IF;
     IF f.proname LIKE 'importar_%' THEN guardia:=guardia||E' IF NOT public.admin_es_admin() THEN RAISE EXCEPTION ''Acceso exclusivo del administrador.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_ubicacion_id %' THEN guardia:=guardia||E' IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN RAISE EXCEPTION ''Estante inactivo o inexistente.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_por %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_por_logistica %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por_logistica)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_recibido_de_produccion %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_produccion WHERE lower(trim(nombre))=lower(trim(p_recibido_de_produccion)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_persona_aliado_entrega %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_entrega)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     IF f.args LIKE '%p_persona_aliado_libera %' THEN guardia:=guardia||E' IF EXISTS(SELECT 1 FROM public.personal_aliados WHERE lower(trim(nombre))=lower(trim(p_persona_aliado_libera)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;\n'; END IF;
     ddl:=regexp_replace(ddl,E'\\mbegin\\M',guardia,'i');
     IF strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN RAISE EXCEPTION 'No se pudo proteger %.',f.firma; END IF;
     EXECUTE ddl;
   END IF;
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.firma);
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.firma);
 END LOOP;
END $rpc$;
DO $$ DECLARE tabla text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
   FOREACH tabla IN ARRAY ARRAY['usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados'] LOOP
     IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=tabla) THEN
       EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',tabla);
     END IF;
   END LOOP;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';

-- Adaptación funcionalidad 061

-- Cambia exclusivamente funciones para operaciones futuras; no modifica historial.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 IF to_regprocedure('public.wms_cuenta_activa()') IS NULL THEN
   RAISE EXCEPTION 'Aplicar primero 060 en PRUEBAS.';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.wms_nombre_actor() RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE nombre_actor text;
BEGIN
 SELECT nullif(trim(nombre),'') INTO nombre_actor FROM public.usuarios
 WHERE auth_id=auth.uid() AND activo;
 IF nombre_actor IS NULL THEN
   RAISE EXCEPTION 'Se requiere una cuenta activa con nombre para registrar la operación.' USING ERRCODE='42501';
 END IF;
 RETURN nombre_actor;
END $$;
REVOKE ALL ON FUNCTION public.wms_nombre_actor() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_nombre_actor() TO authenticated;

DO $rpc$
DECLARE f record; ddl text; guardia text; parametro text;
BEGIN
 FOR f IN SELECT p.oid,p.proname,p.oid::regprocedure firma,p.proargnames nombres,
   l.lanname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   JOIN pg_language l ON l.oid=p.prolang
   WHERE n.nspname='public' AND p.proname IN
   ('crear_lote','recibir_lote_item','registrar_no_conforme','liberar_no_conforme',
    'enviar_no_conforme_aliado','liberar_no_conforme_aliado','registrar_sobrante','importar_ordenes_produccion')
 LOOP
   ddl:=pg_get_functiondef(f.oid);
   IF strpos(ddl,'ORBILOQ_ACTOR_V61')>0 THEN CONTINUE; END IF;
   IF f.lanname<>'plpgsql' OR strpos(ddl,'ORBILOQ_CUENTA_V60')=0 THEN
     RAISE EXCEPTION 'Definición inesperada en %. Revisar antes de continuar.',f.firma;
   END IF;
   guardia:=E'BEGIN\n -- ORBILOQ_ACTOR_V61\n PERFORM public.wms_nombre_actor();\n';
   FOREACH parametro IN ARRAY ARRAY['p_operario_nombre','p_usuario_nombre','p_recibido_por'] LOOP
     IF parametro=ANY(f.nombres) THEN
       guardia:=guardia||format(E' %I := public.wms_nombre_actor();\n',parametro);
     END IF;
   END LOOP;
   -- La FK del responsable se resuelve por Auth, nunca por un nombre duplicado.
   ddl:=regexp_replace(ddl,'where nombre = p_operario_nombre limit 1',
     'where auth_id = auth.uid() and activo limit 1','gi');
   -- El actor ahora pertenece a usuarios, no al catálogo ampliable de terceros.
   ddl:=replace(ddl,
     ' IF EXISTS(SELECT 1 FROM public.personal_logistica WHERE lower(trim(nombre))=lower(trim(p_recibido_por)) AND NOT activo) THEN RAISE EXCEPTION ''Nombre de personal inactivo. Selecciona uno activo.''; END IF;', '');
   ddl:=regexp_replace(ddl,E'\\mbegin\\M',guardia,'i');
   IF strpos(ddl,'ORBILOQ_ACTOR_V61')=0 THEN RAISE EXCEPTION 'No se pudo actualizar %.',f.firma; END IF;
   EXECUTE ddl;
 END LOOP;
END $rpc$;
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.importar_ordenes_produccion(jsonb,jsonb,text,text,text)'::regprocedure);
 IF strpos(ddl,'where nombre = p_usuario_nombre limit 1')=0 THEN RAISE EXCEPTION 'Importador ERP inesperado.'; END IF;
 ddl:=replace(ddl,'where nombre = p_usuario_nombre limit 1','where auth_id = auth.uid() and activo limit 1');
 EXECUTE ddl;
END $$;
NOTIFY pgrst,'reload schema';

-- Adaptación funcionalidad 062


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 IF to_regprocedure('public.wms_nombre_actor()') IS NULL THEN RAISE EXCEPTION 'Aplicar primero 061 en PRUEBAS.'; END IF;
END $$;
CREATE OR REPLACE VIEW public.admin_reporte_movimientos_interno AS
SELECT 'Movimientos:'||movimientos.id::text AS registro, movimientos.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(u.nombre,''),'Sin registrar') AS persona, 'Movimientos'::text AS origen, movimientos.tipo AS tipo, movimientos.cantidad::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, movimientos.nota::text AS detalle, to_jsonb(movimientos) AS datos_crudos FROM public.movimientos LEFT JOIN public.usuarios u ON u.id=movimientos.usuario_id LEFT JOIN public.items_orden io ON io.id=movimientos.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id;
REVOKE ALL ON public.admin_reporte_movimientos_interno FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE VIEW public.admin_reporte_nc_interno AS
SELECT 'Logística:'||devoluciones_produccion.id::text AS registro, devoluciones_produccion.creado_en AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(devoluciones_produccion.operario_nombre,''),'Sin registrar') AS persona, 'Logística'::text AS origen, 'Reporte no conforme' AS tipo, devoluciones_produccion.cantidad::bigint AS cantidad, c.nombre::text AS causal, devoluciones_produccion.recibido_de_produccion::text AS contraparte, devoluciones_produccion.nota::text AS detalle, to_jsonb(devoluciones_produccion) AS datos_crudos FROM public.devoluciones_produccion LEFT JOIN public.causales_devolucion c ON c.id=devoluciones_produccion.causal_id LEFT JOIN public.items_orden io ON io.id=devoluciones_produccion.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Aliados:'||no_conformes_aliados.id::text AS registro, no_conformes_aliados.fecha_solicitud AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(no_conformes_aliados.usuario_produccion_solicitud_nombre,''),'Sin registrar') AS persona, 'Aliados'::text AS origen, 'Envío no conforme a Aliado' AS tipo, no_conformes_aliados.cantidad_solicitada::bigint AS cantidad, c.nombre::text AS causal, no_conformes_aliados.persona_aliado_entrega::text AS contraparte, no_conformes_aliados.nota_solicitud::text AS detalle, to_jsonb(no_conformes_aliados) AS datos_crudos FROM public.no_conformes_aliados LEFT JOIN public.causales_devolucion c ON c.id=no_conformes_aliados.causal_id LEFT JOIN public.items_orden io ON io.id=no_conformes_aliados.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id;
REVOKE ALL ON public.admin_reporte_nc_interno FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE VIEW public.admin_reporte_auditoria_interno AS
SELECT 'Movimientos:'||movimientos.id::text AS registro, movimientos.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(u.nombre,''),'Sin registrar') AS persona, 'Movimientos'::text AS origen, movimientos.tipo AS tipo, movimientos.cantidad::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, movimientos.nota::text AS detalle, to_jsonb(movimientos) AS datos_crudos FROM public.movimientos LEFT JOIN public.usuarios u ON u.id=movimientos.usuario_id LEFT JOIN public.items_orden io ON io.id=movimientos.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Logística:'||devoluciones_produccion.id::text AS registro, devoluciones_produccion.creado_en AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(devoluciones_produccion.operario_nombre,''),'Sin registrar') AS persona, 'Logística'::text AS origen, 'Reporte no conforme' AS tipo, devoluciones_produccion.cantidad::bigint AS cantidad, c.nombre::text AS causal, devoluciones_produccion.recibido_de_produccion::text AS contraparte, devoluciones_produccion.nota::text AS detalle, to_jsonb(devoluciones_produccion) AS datos_crudos FROM public.devoluciones_produccion LEFT JOIN public.causales_devolucion c ON c.id=devoluciones_produccion.causal_id LEFT JOIN public.items_orden io ON io.id=devoluciones_produccion.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Aliados:'||no_conformes_aliados.id::text AS registro, no_conformes_aliados.fecha_solicitud AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(no_conformes_aliados.usuario_produccion_solicitud_nombre,''),'Sin registrar') AS persona, 'Aliados'::text AS origen, 'Envío no conforme a Aliado' AS tipo, no_conformes_aliados.cantidad_solicitada::bigint AS cantidad, c.nombre::text AS causal, no_conformes_aliados.persona_aliado_entrega::text AS contraparte, no_conformes_aliados.nota_solicitud::text AS detalle, to_jsonb(no_conformes_aliados) AS datos_crudos FROM public.no_conformes_aliados LEFT JOIN public.causales_devolucion c ON c.id=no_conformes_aliados.causal_id LEFT JOIN public.items_orden io ON io.id=no_conformes_aliados.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Producción:'||lote_items.id::text AS registro, l.fecha_envio AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(l.operario_nombre,''),'Sin registrar') AS persona, 'Producción'::text AS origen, 'Entrega de lote' AS tipo, lote_items.cantidad_enviada::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, l.numero::text AS detalle, to_jsonb(lote_items) AS datos_crudos FROM public.lote_items JOIN public.lotes l ON l.id=lote_items.lote_id LEFT JOIN public.items_orden io ON io.id=lote_items.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Recepción:'||lote_items.id::text AS registro, lote_items.fecha_recepcion AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(lote_items.recibido_por,''),'Sin registrar') AS persona, 'Recepción'::text AS origen, 'Última recepción acumulada' AS tipo, lote_items.cantidad_recibida::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, coalesce(lote_items.novedad,'')::text AS detalle, to_jsonb(lote_items) AS datos_crudos FROM public.lote_items  LEFT JOIN public.items_orden io ON io.id=lote_items.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE lote_items.fecha_recepcion IS NOT NULL
UNION ALL
SELECT 'Liberaciones:'||liberaciones_no_conforme.id::text AS registro, liberaciones_no_conforme.creado_en AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(liberaciones_no_conforme.operario_nombre,''),'Sin registrar') AS persona, 'Liberaciones'::text AS origen, 'Liberación no conforme' AS tipo, liberaciones_no_conforme.cantidad::bigint AS cantidad, ''::text AS causal, liberaciones_no_conforme.recibido_por_logistica::text AS contraparte, liberaciones_no_conforme.nota::text AS detalle, to_jsonb(liberaciones_no_conforme) AS datos_crudos FROM public.liberaciones_no_conforme  LEFT JOIN public.items_orden io ON io.id=liberaciones_no_conforme.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Liberaciones Aliados:'||liberaciones_aliados.id::text AS registro, liberaciones_aliados.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(liberaciones_aliados.usuario_produccion_nombre,''),'Sin registrar') AS persona, 'Liberaciones Aliados'::text AS origen, 'Liberación Aliado' AS tipo, liberaciones_aliados.cantidad::bigint AS cantidad, ''::text AS causal, liberaciones_aliados.persona_aliado_libera::text AS contraparte, liberaciones_aliados.nota::text AS detalle, to_jsonb(liberaciones_aliados) AS datos_crudos FROM public.liberaciones_aliados LEFT JOIN public.no_conformes_aliados s ON s.id=liberaciones_aliados.solicitud_id LEFT JOIN public.items_orden io ON io.id=s.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Sobrantes:'||sobrantes_bodega.id::text AS registro, sobrantes_bodega.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(sobrantes_bodega.operario_nombre,''),'Sin registrar') AS persona, 'Sobrantes'::text AS origen, 'Registro sobrante' AS tipo, sobrantes_bodega.cantidad::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, sobrantes_bodega.nota::text AS detalle, to_jsonb(sobrantes_bodega) AS datos_crudos FROM public.sobrantes_bodega  LEFT JOIN public.items_orden io ON io.id=sobrantes_bodega.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Resoluciones:'||sobrantes_bodega.id::text AS registro, sobrantes_bodega.fecha_resolucion AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif('Sin registrar',''),'Sin registrar') AS persona, 'Resoluciones'::text AS origen, 'Resolución sobrante' AS tipo, NULL::bigint::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, coalesce(sobrantes_bodega.resolucion,'')::text AS detalle, to_jsonb(sobrantes_bodega) AS datos_crudos FROM public.sobrantes_bodega  LEFT JOIN public.items_orden io ON io.id=sobrantes_bodega.item_orden_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE sobrantes_bodega.fecha_resolucion IS NOT NULL
UNION ALL
SELECT 'Correcciones:'||admin_correcciones.id::text AS registro, admin_correcciones.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(admin_correcciones.actor,''),'Sin registrar') AS persona, 'Correcciones'::text AS origen, 'Corrección: '||admin_correcciones.campo AS tipo, NULL::bigint::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, admin_correcciones.motivo::text AS detalle, to_jsonb(admin_correcciones) AS datos_crudos FROM public.admin_correcciones  LEFT JOIN public.items_orden io ON io.id=admin_correcciones.item_id LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Catálogos:'||admin_catalogos_historial.id::text AS registro, admin_catalogos_historial.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(u.nombre,''),'Sin registrar') AS persona, 'Catálogos'::text AS origen, 'Cambio catálogo: '||admin_catalogos_historial.catalogo AS tipo, NULL::bigint::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, admin_catalogos_historial.registro_id::text::text AS detalle, to_jsonb(admin_catalogos_historial) AS datos_crudos FROM public.admin_catalogos_historial LEFT JOIN public.usuarios u ON u.auth_id=admin_catalogos_historial.actor_id LEFT JOIN public.items_orden io ON io.id=NULL::uuid LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Importación Excel:'||admin_importaciones.id::text AS registro, admin_importaciones.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce(nullif(u.nombre,''),'Sin registrar') AS persona, 'Importación Excel'::text AS origen, 'Importar tabla: '||admin_importaciones.vista AS tipo, NULL::bigint::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, admin_importaciones.motivo::text AS detalle, to_jsonb(admin_importaciones)-'archivo' AS datos_crudos FROM public.admin_importaciones LEFT JOIN public.usuarios u ON u.auth_id=admin_importaciones.actor_id LEFT JOIN public.items_orden io ON io.id=NULL::uuid LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id
UNION ALL
SELECT 'Importación ERP:'||importaciones.id::text AS registro, importaciones.fecha AS fecha, coalesce(op.numero_op,'') AS op, coalesce(io.codigo,'') AS codigo, coalesce(io.descripcion,'') AS producto, coalesce(io.talla,'') AS talla, coalesce(op.cliente,'') AS cliente, coalesce((SELECT nullif(ui.nombre,'') FROM public.usuarios ui WHERE ui.id=importaciones.usuario_id),'Sin registrar') AS persona, 'Importación ERP'::text AS origen, 'Importar ERP' AS tipo, NULL::bigint::bigint AS cantidad, ''::text AS causal, ''::text AS contraparte, importaciones.nombre_archivo::text AS detalle, to_jsonb(importaciones) AS datos_crudos FROM public.importaciones  LEFT JOIN public.items_orden io ON io.id=NULL::uuid LEFT JOIN public.ordenes_produccion op ON op.id=io.orden_id;
REVOKE ALL ON public.admin_reporte_auditoria_interno FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.admin_reporte_pagina(p_tipo text, p_despues text DEFAULT '', p_corte timestamptz DEFAULT now())
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE tabla text; resultado jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_corte IS NULL OR p_despues IS NULL THEN RAISE EXCEPTION 'Paginación inválida.'; END IF;
 tabla:=CASE p_tipo WHEN 'movimientos' THEN 'admin_reporte_movimientos_interno' WHEN 'nc' THEN 'admin_reporte_nc_interno' WHEN 'auditoria' THEN 'admin_reporte_auditoria_interno' END;
 IF tabla IS NULL THEN RAISE EXCEPTION 'Reporte inválido.'; END IF;
 EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY registro),''[]''::jsonb) FROM (SELECT * FROM public.%I WHERE registro > $1 AND fecha <= $2 ORDER BY registro LIMIT 1000) t',tabla)
 INTO resultado USING p_despues,p_corte;
 RETURN resultado;
END $$;
CREATE OR REPLACE FUNCTION public.admin_reporte_resumen() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE resultado jsonb; hoy date:=(now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object(
  'op_activas', count(DISTINCT numero_op) FILTER (WHERE cantidad_pedida>despachado OR pendiente_reproceso>0 OR pendiente_aliados>0),
  'op_atrasadas',count(DISTINCT numero_op) FILTER (WHERE (fecha_esperada_produccion<hoy AND cantidad_pedida>producido) OR (fecha_esperada_logistica<hoy AND cantidad_pedida>despachado)),
  'op_no_conforme',count(DISTINCT numero_op) FILTER (WHERE pendiente_reproceso>0 OR pendiente_aliados>0),
  'sobrantes_pendientes',(SELECT count(*) FROM public.sobrantes_bodega WHERE estado='pendiente'),
  'unidades_sobrantes',(SELECT coalesce(sum(cantidad),0) FROM public.sobrantes_bodega WHERE estado='pendiente'),
  'actualizado_en',now()) INTO resultado FROM public.vista_kardex WHERE admin_eliminado_en IS NULL;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_reporte_pagina(text,text,timestamptz),public.admin_reporte_resumen() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_reporte_pagina(text,text,timestamptz),public.admin_reporte_resumen() TO authenticated;
NOTIFY pgrst,'reload schema';

-- Adaptación funcionalidad 063


  SET LOCAL lock_timeout='5s';
  DO $$ BEGIN
   
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
  DO $import$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.importar_ordenes_produccion(jsonb,jsonb,text,text,text)'::regprocedure);
 IF strpos(ddl,'update importaciones set')=0 THEN RAISE EXCEPTION 'Importador ERP inesperado.'; END IF;
 ddl:=replace(ddl,'update importaciones set',E'-- ORBILOQ_OC_PROD\n UPDATE public.items_orden io SET oc=op.oc_cabecera FROM public.ordenes_produccion op WHERE op.id=io.orden_id AND coalesce(trim(io.oc),'''')='''' AND coalesce(trim(op.oc_cabecera),'''')<>'''' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_ordenes) o WHERE trim(o->>''identificador'')=op.numero_op);\n update importaciones set');
 EXECUTE ddl;
END $import$;
  NOTIFY pgrst,'reload schema';

-- Adaptación funcionalidad 064


SET LOCAL lock_timeout='5s';
DO $migracion$
DECLARE definicion text;
BEGIN
 
 IF to_regprocedure('public.despachar_oc(text,text,text,jsonb)') IS NULL THEN
   RAISE EXCEPTION 'Aplicar primero 063.';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='vista_kardex' AND column_name='fecha_ultimo_despacho') THEN
   definicion := rtrim(pg_get_viewdef('public.vista_kardex'::regclass,true), E';\n ');
   EXECUTE 'CREATE OR REPLACE VIEW public.vista_kardex AS SELECT k.*, '
     || '(SELECT max(m.fecha) FROM public.movimientos m WHERE m.item_orden_id=k.item_orden_id AND m.tipo=''despacho'' AND m.cantidad>0) AS fecha_ultimo_despacho '
     || 'FROM (' || definicion || ') k';
 END IF;
END $migracion$;
NOTIFY pgrst,'reload schema';

DO $$ DECLARE t record; actual jsonb; BEGIN
 FOR t IN SELECT * FROM preservacion LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(j ORDER BY j::text),''[]''::jsonb) FROM (SELECT (SELECT jsonb_object_agg(key,value) FROM jsonb_each(to_jsonb(x)) WHERE key=ANY($1)) j FROM public.%I x) s',t.tabla) INTO actual USING t.columnas;
  IF actual IS DISTINCT FROM t.filas THEN RAISE EXCEPTION 'Datos originales alterados en %. Cancelar.',t.tabla; END IF;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;