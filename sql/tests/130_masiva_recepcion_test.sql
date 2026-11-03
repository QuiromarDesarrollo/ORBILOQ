-- Ejecutar después de 129 y 130 en PostgreSQL local aislado. Todos los datos se revierten.
BEGIN;
CREATE FUNCTION pg_temp.verificar(condicion boolean,mensaje text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',mensaje; END IF; END $$;
CREATE FUNCTION pg_temp.rechazar(accion text,datos jsonb,fragmento text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE fallo text;
BEGIN
 BEGIN PERFORM public.masiva_ejecutar(accion,datos); EXCEPTION WHEN OTHERS THEN fallo:=SQLERRM; END;
 IF fallo IS NULL OR position(fragmento IN fallo)=0 THEN RAISE EXCEPTION 'FALLO: % esperaba %, recibió %',accion,fragmento,fallo; END IF;
END $$;
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000201'),('00000000-0000-0000-0000-000000000202');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('00000000-0000-0000-0000-000000000201','TEST130-ADMIN','Admin prueba 130','admin',ARRAY['admin'],true),
 ('00000000-0000-0000-0000-000000000202','TEST130-MASIVA','Usuario prueba 130','masiva',ARRAY['masiva'],true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
DO $$ DECLARE op uuid; op_pagina uuid; op_conflicto uuid; imp uuid; inv1 uuid; inv2 uuid; inv3 uuid; r jsonb; original jsonb;
 payload jsonb; filas jsonb; i integer; cantidad bigint; solicitud uuid; fallo text;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Recepción 130","cliente":"Ficticio"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','recepcion','archivo','plan.xlsx','total_filas',3,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
  {"proveedor":"Proveedor Z","pedido":"PO-Z","sku":"COMPARTIDO","descripcion":"Prenda compartida","unidad":"UN","cantidad":5,"horario":"8 a 10","novedad":"HISTÓRICA IGNORADA"},
  {"proveedor":"Proveedor A","pedido":"PO-A","sku":"COMPARTIDO","descripcion":"Prenda compartida","unidad":"UN","cantidad":7,"horario":"14 a 16"},
  {"proveedor":"Proveedor A","pedido":"PO-A","sku":"SOLO","descripcion":"Prenda única","unidad":"UN","cantidad":4,"horario":"14 a 16"}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 r:=public.masiva_recepcion_consultar(op);
 PERFORM pg_temp.verificar((r->>'total')::integer=2 AND r->'filas'->0->>'pedido'='PO-Z','Agrupa por OC y conserva el orden de carga, no el alfabético');
 PERFORM pg_temp.verificar(r->'filas'->0->>'novedad'='' AND r->'filas'->0->>'horario'='8 a 10','Importa horario pero no novedad histórica');
 PERFORM pg_temp.verificar(r->'metricas'->>'saldo' IS NULL AND r->'filas'->0->>'saldo' IS NULL,'Saldo sin base personal no es cero ficticio');
 PERFORM pg_temp.verificar(r->'opciones'->'saldo'='[""]','Faceta saldo ofrece Por cruzar como cadena vacía');
 r:=public.masiva_recepcion_consultar(op,'','{"saldo":[""]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=2 AND r->'filas'->0->>'saldo' IS NULL,'Filtro Por cruzar encuentra saldos nulos');
 SELECT id INTO inv1 FROM public.masiva_inventario WHERE operacion_id=op AND pedido='PO-Z';
 SELECT id INTO inv2 FROM public.masiva_inventario WHERE operacion_id=op AND pedido='PO-A' AND sku='COMPARTIDO';
 SELECT id INTO inv3 FROM public.masiva_inventario WHERE operacion_id=op AND sku='SOLO';
 solicitud:=gen_random_uuid();
 payload:=jsonb_build_object('operacion_id',op,'inventario_id',inv1,'cantidad',5,'soporte','REM-130','novedad','Entrega revisada','request_id',solicitud);
 original:=public.masiva_ejecutar('recibir',payload);
 PERFORM pg_temp.verificar(public.masiva_ejecutar('recibir',payload)=original,'Recepción con novedad mantiene idempotencia');
 PERFORM pg_temp.rechazar('recibir',payload||'{"novedad":"otra"}','Identificador ya utilizado');
 PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv2,'cantidad',3,'soporte','REM-131','request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv3,'cantidad',2,'soporte','REM-132','request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('configurar_recepcion',jsonb_build_object('operacion_id',op,'proveedor','Proveedor A','pedido','PO-A','novedad','Pendiente confirmación'));
 PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv3,'cantidad',1,'soporte','REM-133','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT novedad='Pendiente confirmación' AND horario='14 a 16' FROM public.masiva_pedidos WHERE operacion_id=op AND pedido='PO-A'),'Recepción sin novedad conserva nota, edición parcial conserva horario');
 PERFORM pg_temp.verificar(EXISTS(SELECT 1 FROM public.masiva_auditoria WHERE operacion_id=op AND accion='configurar_recepcion' AND datos->'resultado'->'anterior'->>'horario'='14 a 16'),'Configurar conserva auditoría anterior');
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','personal.xlsx','total_filas',3,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
  {"lista":"L1","numero_persona":1,"cedula":"001","nombre":"Persona prueba","sku":"COMPARTIDO","descripcion":"Prenda compartida","cantidad":9},
  {"lista":"L1","numero_persona":1,"cedula":"001","nombre":"Persona prueba","sku":"SOLO","descripcion":"Prenda única","cantidad":2},
  {"lista":"L1","numero_persona":1,"cedula":"001","nombre":"Persona prueba","sku":"SIN-OC","descripcion":"Demanda sin pedido","cantidad":3}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 r:=public.masiva_recepcion_consultar(op);
 PERFORM pg_temp.verificar((r->'metricas'->>'recibido')::integer=11 AND (r->'metricas'->>'requerido')::integer=14,'Demanda de SKU compartido cuenta una vez');
 PERFORM pg_temp.verificar((r->'metricas'->>'saldo')::integer=-3 AND (r->'metricas'->>'saldo_sin_pedido')::integer=-3,'Incluye demanda sin inventario en saldo global');
 PERFORM pg_temp.verificar((r->'filas'->0->>'saldo')::integer=0 AND (r->'filas'->1->>'saldo')::integer=0,'Primer pedido saldo cero; último acumula residuo compartido -1 y saldo solo +1');
 PERFORM pg_temp.verificar((r->'filas'->1->>'esperado')::integer=11 AND (r->'filas'->1->>'recibido')::integer=6 AND (r->'filas'->1->>'pendiente')::integer=5,'Totales exactos por orden');
 r:=public.masiva_recepcion_consultar(op,'cOmPaRtIdO');
 PERFORM pg_temp.verificar((r->>'total')::integer=2 AND (r->'filas'->1->>'esperado')::integer=11
  AND (r->'filas'->1->>'recibido')::integer=6,'Buscar SKU compartido devuelve ambas OC sin reducir sus cantidades completas');
 r:=public.masiva_recepcion_consultar(op,'Prenda única');
 PERFORM pg_temp.verificar((r->>'total')::integer=1 AND r->'filas'->0->>'pedido'='PO-A'
  AND (r->'filas'->0->>'esperado')::integer=11,'Buscar descripción encuentra OC y conserva todos sus SKU');
 r:=public.masiva_recepcion_consultar(op,'','{"saldo":[""]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=0 AND r->'opciones'->'saldo'='["0"]','Por cruzar excluye operaciones con base personal y faceta permite cambiar filtro');
 r:=public.masiva_recepcion_consultar(op,'','{}',1,'Proveedor A','PO-A');
 PERFORM pg_temp.verificar((r->'filas'->0->>'global_recibido_sku')::integer=8 AND (r->'filas'->0->>'requerido_sku')::integer=9
  AND (r->'filas'->0->>'saldo_sku')::integer=-1 AND (r->'filas'->0->>'saldo_oc_sku')::integer=-1,'Detalle conserva saldo global SKU y residual asignado al último pedido');
 r:=public.masiva_recepcion_consultar(op,'','{}',1,'Proveedor Z','PO-Z');
 PERFORM pg_temp.verificar((r->'filas'->0->>'saldo_sku')::integer=-1 AND (r->'filas'->0->>'saldo_oc_sku')::integer=0,'Primer pedido no repite saldo compartido');
 PERFORM pg_temp.rechazar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv1,'cantidad',1,'soporte','EXCESO','request_id',gen_random_uuid()),'supera el límite');

 op_pagina:=(public.masiva_ejecutar('crear_operacion','{"nombre":"55 pedidos","cliente":"Ficticio"}')->>'id')::uuid;
 SELECT jsonb_agg(jsonb_build_object('proveedor',CASE WHEN n%2=0 THEN 'Proveedor par' ELSE 'Proveedor impar' END,
  'pedido','OC-'||lpad(n::text,2,'0'),'sku','SKU-'||n,'descripcion','Prenda '||n,'unidad','UN','cantidad',n) ORDER BY n)
 INTO filas FROM generate_series(1,55) n;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op_pagina,'tipo','recepcion','archivo','55.xlsx','total_filas',55,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas',filas));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 r:=public.masiva_recepcion_consultar(op_pagina);
 PERFORM pg_temp.verificar((r->>'total')::integer=55 AND jsonb_array_length(r->'filas')=50 AND jsonb_array_length(r->'opciones'->'pedido')=55,'Facetas abarcan todas las páginas');
 r:=public.masiva_recepcion_consultar(op_pagina,'','{}',2);
 PERFORM pg_temp.verificar((r->>'total')::integer=55 AND jsonb_array_length(r->'filas')=5,'Paginación posterior a filtros');
 r:=public.masiva_recepcion_consultar(op_pagina,'','{"esperado":["54","55"]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=2 AND r->'filas'->1->>'pedido'='OC-55','Filtro OR alcanza registros fuera de página inicial');
 r:=public.masiva_recepcion_consultar(op_pagina,'','{"esperado":["54","55"],"pedido":["OC-55"]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=1 AND r->'opciones'->'esperado'='["55"]' AND r->'opciones'->'pedido'='["OC-54","OC-55"]','Facetas ignoran filtro propio y conservan los demás');
 r:=public.masiva_recepcion_consultar(op_pagina,'PrOvEeDoR ImPaR','{"esperado":["54","55"]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=1 AND r->'filas'->0->>'pedido'='OC-55','Búsqueda y filtros se combinan sin distinguir mayúsculas');
 r:=public.masiva_recepcion_consultar(op_pagina,'','{"horario":[""]}');
 PERFORM pg_temp.verificar((r->>'total')::integer=55 AND r->'opciones'->'horario'='[""]','Filtro vacío conserva valor raw');
 r:=public.masiva_recepcion_consultar(op_pagina,'','{}',3);
 PERFORM pg_temp.verificar((r->>'total')::integer=55 AND r->'filas'='[]','Página vacía mantiene total correcto');
 BEGIN PERFORM public.masiva_recepcion_consultar(op_pagina,'','{"pedido": "OC-55"}'); RAISE EXCEPTION 'FALLO filtro inválido';
 EXCEPTION WHEN raise_exception THEN IF position('filtro de recepción inválido' IN SQLERRM)=0 THEN RAISE; END IF; END;

 op_conflicto:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Conflicto horario","cliente":"Ficticio"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op_conflicto,'tipo','recepcion','archivo','conflicto.xlsx','total_filas',2,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
  {"proveedor":"P","pedido":"OC","sku":"1","descripcion":"Prenda1","unidad":"UN","cantidad":1,"horario":"8 a 10"},
  {"proveedor":"P","pedido":"OC","sku":"2","descripcion":"Prenda2","unidad":"UN","cantidad":1,"horario":"14 a 16"}]'::jsonb));
 PERFORM pg_temp.rechazar('confirmar_importacion',jsonb_build_object('importacion_id',imp),'horarios distintos');
 PERFORM pg_temp.verificar(NOT EXISTS(SELECT 1 FROM public.masiva_pedidos WHERE operacion_id=op_conflicto) AND NOT EXISTS(SELECT 1 FROM public.masiva_inventario WHERE operacion_id=op_conflicto),'Conflicto de horario revierte todo el plan');

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 PERFORM pg_temp.rechazar('configurar_recepcion',jsonb_build_object('operacion_id',op,'proveedor','Proveedor Z','pedido','PO-Z','horario','Nuevo'),'requiere administrador');
 r:=public.masiva_recepcion_consultar(op);
 PERFORM pg_temp.verificar((r->>'total')::integer=2,'Perfil Masiva sí puede consultar');
 PERFORM pg_temp.verificar(NOT has_table_privilege('authenticated','public.masiva_pedidos','UPDATE') AND NOT has_table_privilege('anon','public.masiva_pedidos','SELECT'),'Metadatos sin acceso directo');
 PERFORM pg_temp.verificar(NOT has_function_privilege('anon','public.masiva_recepcion_consultar(uuid,text,jsonb,integer,text,text)','EXECUTE'),'RPC no anónima');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
 PERFORM public.masiva_ejecutar('cerrar_operacion',jsonb_build_object('operacion_id',op,'motivo','Cierre prueba'));
 PERFORM pg_temp.rechazar('configurar_recepcion',jsonb_build_object('operacion_id',op,'proveedor','Proveedor Z','pedido','PO-Z','horario','Nuevo'),'cerrada');
 PERFORM pg_temp.verificar((public.masiva_recepcion_consultar(op)->>'total')::integer=2,'Archivo conserva consulta');
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN PERFORM public.masiva_recepcion_consultar(op); RAISE EXCEPTION 'FALLO acceso anónimo';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'MASIVA 130: agrupación, filtros globales, facetas, saldos sin duplicar, metadatos, idempotencia y permisos PASARON';
END $$;
ROLLBACK;
