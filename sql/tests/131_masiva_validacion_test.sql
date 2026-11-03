-- PostgreSQL local aislado, después de 129, 130 y 131. Revierte todos los datos.
BEGIN;
CREATE FUNCTION pg_temp.verificar(condicion boolean,mensaje text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',mensaje; END IF; END $$;
CREATE FUNCTION pg_temp.rechazar(accion text,datos jsonb,fragmento text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE fallo text;
BEGIN
 BEGIN PERFORM public.masiva_ejecutar(accion,datos); EXCEPTION WHEN OTHERS THEN fallo:=SQLERRM; END;
 IF fallo IS NULL OR position(fragmento IN fallo)=0 THEN RAISE EXCEPTION 'FALLO: % esperaba %, recibió %',accion,fragmento,fallo; END IF;
END $$;
CREATE FUNCTION pg_temp.huella() RETURNS text LANGUAGE plpgsql AS $$
DECLARE t text; v text; acumulado text:='';
BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'masiva_%' ORDER BY tablename LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(f) ORDER BY to_jsonb(f)::text),''[]'')::text FROM public.%I f',t) INTO v;
  acumulado:=acumulado||t||md5(v);
 END LOOP;
 RETURN md5(acumulado);
END $$;
CREATE FUNCTION pg_temp.rechazar_escaneo(datos jsonb,tipo text,sku text,requerido integer,validado integer) RETURNS void LANGUAGE plpgsql AS $$
DECLARE detalle text; mensaje text; codigo text; antes text:=pg_temp.huella();
BEGIN
 BEGIN PERFORM public.masiva_ejecutar('validar',datos);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS detalle=PG_EXCEPTION_DETAIL,mensaje=MESSAGE_TEXT,codigo=RETURNED_SQLSTATE; END;
 PERFORM pg_temp.verificar(codigo='P0001' AND detalle::jsonb->>'tipo'=tipo AND detalle::jsonb->>'sku'=sku
  AND (detalle::jsonb->>'cantidad')::integer=requerido AND (detalle::jsonb->>'validado')::integer=validado,'Error de escaneo estructurado');
 PERFORM pg_temp.verificar(position(sku IN mensaje)>0 AND position('retira' IN lower(mensaje))>0,'Error identifica el SKU y pide retirar la prenda');
 PERFORM pg_temp.verificar(antes=pg_temp.huella(),'Escaneo rechazado no cambia ninguna tabla de Masiva');
END $$;
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000301'),('00000000-0000-0000-0000-000000000302'),
 ('00000000-0000-0000-0000-000000000303'),('00000000-0000-0000-0000-000000000304');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('00000000-0000-0000-0000-000000000301','T131-ADMIN','Admin 131','admin',ARRAY['admin'],true),
 ('00000000-0000-0000-0000-000000000302','T131-ARMADOR','Armador 131','masiva',ARRAY['masiva'],true),
 ('00000000-0000-0000-0000-000000000303','T131-VALIDADOR1','Validador 131 A','masiva',ARRAY['masiva'],true),
 ('00000000-0000-0000-0000-000000000304','T131-VALIDADOR2','Validador 131 B','masiva',ARRAY['masiva'],true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
DO $$ DECLARE op uuid; imp uuid; persona uuid; empaque uuid; asignacion uuid; kit uuid; articulo_a uuid; articulo_b uuid;
 inv record; r jsonb; datos jsonb; reset_datos jsonb; cantidades jsonb; documento jsonb; anterior jsonb; antes text; inicio timestamptz;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Validación 131","cliente":"Ficticio"}')->>'id')::uuid;
 persona:=(public.masiva_ejecutar('guardar_personal','{"nombre":"Armador 131","usuario_numero":"T131-ARMADOR"}')->>'id')::uuid;
 empaque:=(public.masiva_ejecutar('guardar_empaque','{"nombre":"Bolsa 131","tipo":"bolsa","peso_vacio":0.1,"peso_lleno":3,"largo":30,"ancho":20,"alto":15}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','recepcion','archivo','131.xlsx','total_filas',3,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
  {"proveedor":"A","pedido":"1","sku":"001-A","descripcion":"Camisa","unidad":"UN","cantidad":1},
  {"proveedor":"B","pedido":"2","sku":"001-A","descripcion":"Camisa","unidad":"UN","cantidad":1},
  {"proveedor":"A","pedido":"1","sku":"002-B","descripcion":"Calzado","unidad":"PAR","cantidad":1}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 FOR inv IN SELECT * FROM public.masiva_inventario WHERE operacion_id=op LOOP
  PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv.id,'cantidad',1,'soporte','REM-131','request_id',gen_random_uuid()));
 END LOOP;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','personal131.xlsx','total_filas',2,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
  {"lista":"88","numero_persona":1,"cedula":"000131","nombre":"Persona de prueba","sku":"001-A","descripcion":"Camisa","cantidad":2,"sede":"Sede prueba","sector":"Sector prueba","ciudad":"Ciudad prueba","unidad":"Unidad prueba"},
  {"lista":"88","numero_persona":1,"cedula":"000131","nombre":"Persona de prueba","sku":"002-B","descripcion":"Calzado","cantidad":1,"sede":"Sede prueba","sector":"Sector prueba","ciudad":"Ciudad prueba","unidad":"Unidad prueba"}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 SELECT id INTO kit FROM public.masiva_kits WHERE operacion_id=op;
 SELECT id INTO articulo_a FROM public.masiva_articulos WHERE kit_id=kit AND sku='001-A';
 SELECT id INTO articulo_b FROM public.masiva_articulos WHERE kit_id=kit AND sku='002-B';
 asignacion:=(public.masiva_ejecutar('asignar',jsonb_build_object('operacion_id',op,'lista','88','empacador_id',persona))->>'id')::uuid;
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asignacion,'accion','iniciar'));
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asignacion,'accion','finalizar'));
 datos:=jsonb_build_object('operacion_id',op,'kit_id',kit,'sku','001-A','request_id',gen_random_uuid());
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('sku','SKU-ERRADO'),'sku_incorrecto','SKU-ERRADO',0,0);
 r:=public.masiva_ejecutar('validar',datos);
 PERFORM pg_temp.verificar(public.masiva_ejecutar('validar',datos)=r,'Escanear una misma solicitud es idempotente');
 r:=public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op,'kit_id',kit,'empaque_id',empaque,'caja',1));
 PERFORM pg_temp.verificar(r->>'estado'='parcial' AND r->>'requerido'='3' AND r->>'validado'='1','Empaque parcial devuelve cantidades confirmadas');
 documento:=public.masiva_ejecutar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','lista'));
 SELECT jsonb_agg(jsonb_build_object('articulo_id',a.id,'validado',a.validado)) INTO cantidades FROM public.masiva_articulos a WHERE kit_id=kit;
 reset_datos:=jsonb_build_object('operacion_id',op,'kit_id',kit,'motivo','Revisión completa','cantidades',cantidades,'request_id',gen_random_uuid());
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000304',true);
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('request_id',gen_random_uuid()));
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('request_id',gen_random_uuid()),'unidad_excedente','001-A',2,2);
 antes:=pg_temp.huella();
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos,'cambió en otra estación');
 PERFORM pg_temp.verificar(antes=pg_temp.huella(),'Reinicio con cantidades antiguas no modifica nada');
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('sku','002-B','request_id',gen_random_uuid()));
 -- El error de exceso tiene prioridad incluso con la revisión cerrada por kit completo.
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('request_id',gen_random_uuid()),'unidad_excedente','001-A',2,2);
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('sku','MAL-CERRADO','request_id',gen_random_uuid()),'sku_incorrecto','MAL-CERRADO',0,0);
 r:=public.masiva_consultar(op,'kits','000131');
 PERFORM pg_temp.verificar(r->'filas'->0->>'sede'='Sede prueba' AND r->'filas'->0->>'sector'='Sector prueba'
  AND r->'filas'->0->>'ciudad'='Ciudad prueba' AND r->'filas'->0->>'unidad'='Unidad prueba','Kit incluye destino');
 PERFORM pg_temp.verificar(r->'filas'->0->>'caja_tipo'='bolsa' AND r->'filas'->0->>'caja_nombre'='Bolsa 131','Kit incluye empaque del snapshot');
 PERFORM pg_temp.verificar(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas'->0->'articulos') a WHERE a->>'fecha_hora_validado' IS NULL),'Artículos validados incluyen fecha real');
 SELECT to_jsonb(k),validacion_inicio INTO anterior,inicio FROM public.masiva_kits k WHERE id=kit;
 SELECT jsonb_agg(jsonb_build_object('articulo_id',a.id,'validado',a.validado)) INTO cantidades FROM public.masiva_articulos a WHERE kit_id=kit;
 reset_datos:=reset_datos||jsonb_build_object('cantidades',cantidades);
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos-'request_id','identificador');
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos||'{"motivo":" "}','motivo');
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos-'cantidades','Actualiza');
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos||jsonb_build_object('cantidades',jsonb_build_array(cantidades->0)),'cambió');
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos||jsonb_build_object('cantidades',cantidades||jsonb_build_array(cantidades->0)),'cambió');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos,'distinta');
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos,'Acceso exclusivo');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 r:=public.masiva_ejecutar('reiniciar_validacion',reset_datos); antes:=pg_temp.huella();
 PERFORM pg_temp.verificar(r->>'unidades_reintegradas'='3' AND r->>'estado'='armado','Reinicio informa unidades reintegradas');
 PERFORM pg_temp.verificar(public.masiva_ejecutar('reiniciar_validacion',reset_datos)=r AND antes=pg_temp.huella(),'Reintento de reinicio no reintegra ni audita dos veces');
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos||'{"motivo":"Otro motivo"}','Identificador ya utilizado');
 PERFORM pg_temp.verificar((SELECT sum(validado)=0 AND sum(recibido)=3 FROM public.masiva_inventario WHERE operacion_id=op),'Reintegra stock a todos los pedidos originales');
 PERFORM pg_temp.verificar((SELECT sum(validado)=0 FROM public.masiva_articulos WHERE kit_id=kit),'Todos los artículos reiniciados');
 PERFORM pg_temp.verificar((SELECT sum(c.cantidad)=0 FROM public.masiva_consumos c JOIN public.masiva_articulos a ON a.id=c.articulo_id WHERE a.kit_id=kit),'Consumos quedan en cero');
 PERFORM pg_temp.verificar((SELECT sum(c.cantidad)=0 FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id WHERE a.kit_id=kit),'Revierte créditos de ambos validadores');
 PERFORM pg_temp.verificar((SELECT sum(cantidad)=3 FROM public.masiva_movimientos WHERE operacion_id=op AND tipo='correccion'),'Movimientos compensatorios conservan historial');
 PERFORM pg_temp.verificar((SELECT estado='armado' AND revision_abierta AND validacion_fin IS NULL AND validacion_inicio=inicio
  AND to_jsonb(k)-'estado'-'revision_abierta'-'validacion_fin'=anterior-'estado'-'revision_abierta'-'validacion_fin' FROM public.masiva_kits k WHERE id=kit),'Conserva caja, autoría, armado, validador e inicio histórico');
 PERFORM pg_temp.verificar((SELECT snapshot=documento->'snapshot' FROM public.masiva_documentos WHERE id=(documento->>'id')::uuid),'Documento previo inmutable');
 PERFORM pg_temp.verificar((SELECT count(*)=1 AND min((aud.datos->'resultado'->>'unidades_reintegradas')::integer)=3 FROM public.masiva_auditoria aud WHERE kit_id=kit AND accion='reiniciar_validacion'),'Reinicio auditado una sola vez con conteo anterior');
 r:=public.masiva_consultar(op,'kits','000131');
 PERFORM pg_temp.verificar(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas'->0->'articulos') a WHERE a->>'fecha_hora_validado' IS NOT NULL),'Reinicio deja fecha de validación actual vacía');
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('request_id',gen_random_uuid()));
 SELECT jsonb_agg(jsonb_build_object('articulo_id',a.id,'validado',a.validado)) INTO cantidades FROM public.masiva_articulos a WHERE kit_id=kit;
 reset_datos:=reset_datos||jsonb_build_object('request_id',gen_random_uuid(),'cantidades',cantidades);
 -- Una inconsistencia se rechaza atómicamente, sin devolver parte del stock.
 UPDATE public.masiva_validacion_creditos SET cantidad=0 WHERE articulo_id=articulo_a;
 antes:=pg_temp.huella();
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos,'Inconsistencia');
 PERFORM pg_temp.verificar(antes=pg_temp.huella(),'Reinicio inconsistente revierte íntegramente');
 UPDATE public.masiva_validacion_creditos SET cantidad=1 WHERE articulo_id=articulo_a AND actor_id='00000000-0000-0000-0000-000000000303';
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('sku','002-B','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT sum(c.cantidad)=3 FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id WHERE a.kit_id=kit),'Revalidar no infla créditos después de reinicio');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
 PERFORM public.masiva_ejecutar('cerrar_operacion',jsonb_build_object('operacion_id',op,'motivo','Prueba cerrada'));
 PERFORM pg_temp.rechazar('reiniciar_validacion',reset_datos||jsonb_build_object('request_id',gen_random_uuid()),'cerrada');
 PERFORM pg_temp.verificar(NOT has_function_privilege('anon','public.masiva_ejecutar(text,jsonb)','EXECUTE'),'Acción no accesible de forma anónima');
 RAISE NOTICE 'MASIVA 131: escaneo incorrecto/exceso, cero cambios en rechazo, reinicio atómico/idempotente, créditos, auditoría, destinos, empaques y fechas reales PASARON';
END $$;
ROLLBACK;
