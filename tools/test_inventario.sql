-- Datos sintéticos: exclusivamente PostgreSQL local del ensayo.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) SELECT ('10100000-0000-0000-0000-00000000000'||n)::uuid,'inventario'||n||'@local' FROM generate_series(1,4)n;
INSERT INTO public.usuarios(id,nombre,rol,roles,auth_id,numero_usuario,email,activo)
 SELECT ('10110000-0000-0000-0000-00000000000'||n)::uuid,'INV '||n,r,ARRAY[r],('10100000-0000-0000-0000-00000000000'||n)::uuid,'101'||n,'inventario'||n||'@local',true
 FROM (VALUES(1,'admin'),(2,'logistica'),(3,'despacho'),(4,'produccion'))x(n,r);
INSERT INTO public.ordenes_produccion(id,numero_op,cliente,nombre_ficha_tecnica) VALUES
 ('10120000-0000-0000-0000-000000000001','INV-1','CLIENTE INVENTARIO','FICHA V0'),
 ('10120000-0000-0000-0000-000000000002','INV-2','OTRO CLIENTE','FICHA V0'),
 ('10120000-0000-0000-0000-000000000003','INV-3','CLIENTE INVENTARIO','FICHA V1');
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc) VALUES
 ('10130000-0000-0000-0000-000000000001','10120000-0000-0000-0000-000000000001','INV-1','CAMISA','M',100,'OC ORIGINAL'),
 ('10130000-0000-0000-0000-000000000002','10120000-0000-0000-0000-000000000002','INV-2','CAMISA','M',100,'OC ORIGINAL'),
 ('10130000-0000-0000-0000-000000000003','10120000-0000-0000-0000-000000000003','INV-3','CAMISA','M',100,'OC ORIGINAL');
INSERT INTO public.ubicaciones(id,codigo) VALUES('10140000-0000-0000-0000-000000000001','INV-ESTANTE');
INSERT INTO public.ubicaciones(id,codigo) VALUES('10140000-0000-0000-0000-000000000002','INV-DESTINO');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id)
 SELECT tipo,'10130000-0000-0000-0000-000000000001',100,'10140000-0000-0000-0000-000000000001' FROM (VALUES('entrega_produccion'),('recepcion'))t(tipo);
CREATE FUNCTION pg_temp.rechaza(q text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 BEGIN EXECUTE q; SET CONSTRAINTS ALL IMMEDIATE;
 EXCEPTION WHEN insufficient_privilege OR raise_exception OR check_violation THEN RETURN; END;
 RAISE EXCEPTION 'Operacion prohibida aceptada: %',q;
END $$;
SELECT set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
DO $$ BEGIN IF (public.inventario_listar('FICHA V',0)->>'total')::int<>0 THEN RAISE EXCEPTION 'Mostró prendas antes de ingresarlas'; END IF; END $$;
-- Una OP sin ficha debe ser visible; la transferencia sigue prohibida.
UPDATE public.ordenes_produccion SET nombre_ficha_tecnica=NULL WHERE numero_op='INV-1';
SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.inventario_origenes('INV-1',0);
 IF jsonb_array_length(r)<>1 OR (r->0->>'disponible')::int<>100 THEN RAISE EXCEPTION 'Ocultó stock sin ficha: %',r; END IF;
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_transferir('sin-ficha','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',1,'Prueba')$q$);
END $$;
RESET ROLE;
UPDATE public.ordenes_produccion SET nombre_ficha_tecnica='FICHA V0' WHERE numero_op='INV-1';
SET LOCAL ROLE authenticated;
DO $$ DECLARE t uuid; r uuid; resultado jsonb; e jsonb; dest jsonb; pedido jsonb; pack jsonb; d uuid; saldo jsonb; n bigint;
BEGIN
 t:=public.inventario_transferir_estante('inv-transfer-1','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',60,'Reserva libre del cliente','INV-DESTINO');
 IF t<>public.inventario_transferir_estante('inv-transfer-1','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',60,'Reserva libre del cliente','INV-DESTINO') THEN RAISE EXCEPTION 'Duplicó transferencia'; END IF;
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_transferir_estante('inv-transfer-1','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',61,'Reserva libre del cliente','INV-DESTINO')$q$);
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_transferir('inv-exceso','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',41,'Exceso')$q$);
 IF (SELECT cantidad FROM public.vista_stock_ubicacion_detalle WHERE item_orden_id='10130000-0000-0000-0000-000000000001' AND ubicacion_codigo='INV-ESTANTE')<>40 THEN RAISE EXCEPTION 'No descontó el estante de origen'; END IF;
 IF (SELECT cantidad FROM public.vista_stock_ubicacion_detalle WHERE item_orden_id='10130000-0000-0000-0000-000000000001' AND ubicacion_codigo='INV-DESTINO')<>60 THEN RAISE EXCEPTION 'No agregó el estante de destino'; END IF;
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_transferir_estante('inv-invalido','10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',1,'Prueba','NO EXISTE')$q$);
 resultado:=public.inventario_listar('FICHA V',0);
 IF (resultado->>'total')::integer<>1 OR resultado->'filas'->0->>'cliente'<>'CLIENTE INVENTARIO' OR resultado->'filas'->0->>'ficha'<>'FICHA V0' THEN RAISE EXCEPTION 'Incluyó fichas/clientes sin entradas: %',resultado; END IF;
 IF (public.inventario_listar('OTRO CLIENTE',0)->>'total')::int<>0 THEN RAISE EXCEPTION 'La búsqueda muestra prendas no ingresadas'; END IF;
 -- Bodega puede revertir; Producción no puede.
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000004',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_revertir(''no-permitido'',%L,1,''Error'')',t));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000002',true);
 r:=public.inventario_revertir('inv-reversa',t,10,'Corrección de cantidad');
 IF r<>public.inventario_revertir('inv-reversa',t,10,'Corrección de cantidad') THEN RAISE EXCEPTION 'Duplicó reversión'; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_revertir(''sin-motivo'',%L,1,'''')',t));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 PERFORM public.le_importar_clientes('[{"nombre":"CLIENTE INVENTARIO","nit":"101"}]');
 SELECT value INTO dest FROM jsonb_array_elements(public.destinatarios_para_empaque()) WHERE value->'datos'->>'nombre'='CLIENTE INVENTARIO';
 e:=public.admin_empaque_guardar_v92(NULL,NULL,'{"nombre":"Caja inventario","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.5,"activo":true}');
 pedido:=jsonb_build_array(jsonb_build_object('item_id','10130000-0000-0000-0000-000000000001','ubicacion','INV-ESTANTE','cantidad',51));
 pack:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','10130000-0000-0000-0000-000000000001','empaque_id',e->>'id','version',md5(e::text),'cantidad',51,'peso_bruto_kg',5));
 -- La OP solo tiene 50 libres; el despacho normal no puede consumir las otras 50.
 PERFORM pg_temp.rechaza(format('SELECT public.guardar_empaque_destinatario_v92(''inv-robo'',''CLIENTE INVENTARIO'',''OC ORIGINAL'',%L,%L,%L,%L)',pedido,pack,dest->>'id',dest->>'version'));
 PERFORM pg_temp.rechaza(format('SELECT public.guardar_empaque_destinatario_v92(''inv-otro-cliente'',''OTRO CLIENTE'',''OC ORIGINAL'',%L,%L,%L,%L)',pedido,pack,dest->>'id',dest->>'version'));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000003',true);
 resultado:=public.inventario_empacar('inv-empaque',t,20,'OC NUEVA',(dest->>'id')::uuid,dest->>'version',(e->>'id')::uuid,md5(e::text),5);
 d:=(resultado->>'id')::uuid;
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 IF (public.inventario_empacar('inv-empaque',t,20,'OC NUEVA',(dest->>'id')::uuid,dest->>'version',(e->>'id')::uuid,md5(e::text),5)->>'id')::uuid<>d THEN RAISE EXCEPTION 'Duplicó LE'; END IF;
 saldo:=public.inventario_detalle('CLIENTE INVENTARIO','FICHA V0',0)->0;
 IF (saldo->>'libre')::int<>30 OR (saldo->>'reservado')::int<>20 THEN RAISE EXCEPTION 'Saldo reservado incorrecto %',saldo; END IF;
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000002',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_revertir(''reservado'',%L,31,''Error'')',t));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000003',true);
 PERFORM public.inventario_cancelar(d,'Cambio de OC');
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.rechaza(format('SELECT public.seguimiento_confirmar(%L,0,%L)',d,dest->>'id'));
 -- El asistente habitual puede repartir una transferencia en varios empaques.
 pack:=jsonb_build_array(
 jsonb_build_object('numero',1,'item_id','10130000-0000-0000-0000-000000000001','empaque_id',e->>'id','version',md5(e::text),'cantidad',10,'peso_bruto_kg',5),
 jsonb_build_object('numero',2,'item_id','10130000-0000-0000-0000-000000000001','empaque_id',e->>'id','version',md5(e::text),'cantidad',10,'peso_bruto_kg',5));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000004',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_flujo(''sin-rol'',%L,''OC NUEVA 2'',%L,%L,%L)',t,dest->>'id',dest->>'version',pack));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000003',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_flujo(''otra-prenda'',%L,''OC NUEVA 2'',%L,%L,%L)',t,dest->>'id',dest->>'version',jsonb_set(pack,'{0,item_id}','"10130000-0000-0000-0000-000000000002"')));
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_flujo(''exceso-flujo'',%L,''OC NUEVA 2'',%L,%L,%L)',t,dest->>'id',dest->>'version',jsonb_set(pack,'{0,cantidad}','999')));
 resultado:=public.inventario_empacar_flujo('inv-empaque-2',t,'OC NUEVA 2',(dest->>'id')::uuid,dest->>'version',pack);
 IF (public.inventario_empacar_flujo('inv-empaque-2',t,'OC NUEVA 2',(dest->>'id')::uuid,dest->>'version',pack)->>'id') IS DISTINCT FROM resultado->>'id' THEN RAISE EXCEPTION 'Duplicó la LE del asistente'; END IF;
 d:=(resultado->>'id')::uuid;
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 PERFORM public.seguimiento_confirmar(d,0,(dest->>'id')::uuid);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 saldo:=public.inventario_detalle('CLIENTE INVENTARIO','FICHA V0',0)->0;
 IF (saldo->>'libre')::int<>30 OR (saldo->>'reservado')::int<>0 OR (saldo->>'despachado')::int<>20 THEN RAISE EXCEPTION 'Saldo despachado incorrecto %',saldo; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_cancelar(%L,''Ya salió'')',d));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000002',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_revertir(''despachado'',%L,31,''Error'')',t));
 PERFORM public.inventario_revertir('inv-final',t,30,'Volver saldo libre a OP');
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT sum(cantidad) FROM public.movimientos WHERE tipo='recepcion' AND item_orden_id='10130000-0000-0000-0000-000000000001')<>100 THEN RAISE EXCEPTION 'Duplicó recepción'; END IF;
 IF public.inventario_disponible_op('10130000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001')<>80 THEN RAISE EXCEPTION 'No devolvió saldo al origen'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.inventario_listar('FICHA V0',0)->'filas') f WHERE (f->>'libre')::int=0 AND (f->>'despachado')::int=20) THEN RAISE EXCEPTION 'Ocultó inventario ya despachado sin saldo libre'; END IF;
END $$;
-- Recepción con reparto: todo o nada entre lotes, sin duplicar al reintentar.
INSERT INTO public.lotes(id,numero,operario_nombre) VALUES('10150000-0000-0000-0000-000000000001','INV-LOTE','TEST');
INSERT INTO public.lote_items(id,lote_id,item_orden_id,cantidad_enviada) VALUES
 ('10160000-0000-0000-0000-000000000001','10150000-0000-0000-0000-000000000001','10130000-0000-0000-0000-000000000002',20),
 ('10160000-0000-0000-0000-000000000002','10150000-0000-0000-0000-000000000001','10130000-0000-0000-0000-000000000003',20);
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,lote_id,lote_item_id)
 SELECT 'entrega_produccion',item_orden_id,20,lote_id,id FROM public.lote_items WHERE lote_id='10150000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT public.inventario_recibir('inv-recepcion','[{"linea":"10160000-0000-0000-0000-000000000001","cantidad":10}]','INV-ESTANTE','Bodega','',6);
SELECT public.inventario_recibir('inv-recepcion','[{"linea":"10160000-0000-0000-0000-000000000001","cantidad":10}]','INV-ESTANTE','Bodega','',6);
SELECT pg_temp.rechaza($q$SELECT public.inventario_recibir('inv-recepcion-fallida','[{"linea":"10160000-0000-0000-0000-000000000001","cantidad":3},{"linea":"10160000-0000-0000-0000-000000000099","cantidad":1}]','INV-ESTANTE','Bodega','',3)$q$);
RESET ROLE;
DO $$ BEGIN
 IF (SELECT cantidad_recibida FROM public.lote_items WHERE id='10160000-0000-0000-0000-000000000001')<>10 THEN RAISE EXCEPTION 'Recepción duplicada o parcial al fallar'; END IF;
 IF public.inventario_disponible_op('10130000-0000-0000-0000-000000000002','10140000-0000-0000-0000-000000000001')<>4 THEN RAISE EXCEPTION 'Reparto de recepción incorrecto'; END IF;
END $$;
UPDATE public.ordenes_produccion SET nombre_ficha_tecnica=NULL WHERE id='10120000-0000-0000-0000-000000000003';
SET LOCAL ROLE authenticated;
SELECT pg_temp.rechaza($q$SELECT public.inventario_recibir('inv-sin-ficha','[{"linea":"10160000-0000-0000-0000-000000000002","cantidad":10}]','INV-ESTANTE','Bodega','',5)$q$);
SELECT public.inventario_recibir('inv-normal','[{"linea":"10160000-0000-0000-0000-000000000002","cantidad":10}]','INV-ESTANTE','Bodega','',0);
RESET ROLE;
DO $$ BEGIN
 IF (SELECT cantidad_recibida FROM public.lote_items WHERE id='10160000-0000-0000-0000-000000000002')<>10 THEN RAISE EXCEPTION 'Recepción fallida dejó movimientos'; END IF;
 IF (SELECT sum(cantidad) FROM public.movimientos WHERE tipo='recepcion' AND item_orden_id='10130000-0000-0000-0000-000000000003')<>10 THEN RAISE EXCEPTION 'Recepción normal duplicada'; END IF;
END $$;

-- Entrada externa sin OP: agrupación, idempotencia y despacho completo.
SELECT set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE filas jsonb; r jsonb; t uuid; iid uuid; dest jsonb; e jsonb; pack jsonb; d uuid; antes bigint; BEGIN
 SELECT count(*) INTO antes FROM public.ordenes_produccion;
 filas:='[{"ficha":" ficha  v0 ","cliente":"CLIENTE INVENTARIO","codigo":"000123","descripcion":"CAMISA MANUAL","talla":"30","cantidad":14,"estante":"INV-ESTANTE"},{"ficha":"FICHA V0","cliente":"CLIENTE INVENTARIO","codigo":"000123","descripcion":"CAMISA MANUAL","talla":"30","cantidad":6,"estante":"INV-ESTANTE"}]';
 r:=public.inventario_importar_excel('excel-1','entrada.xlsx',filas,false);
 IF (r->>'unidades')::int<>20 OR jsonb_array_length(r->'filas')<>1 THEN RAISE EXCEPTION 'Preview incorrecto %',r; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_importar_excel(''bad-estante'',''bad.xlsx'',%L,true)',jsonb_set(filas,'{0,estante}','"NO EXISTE"')));
 PERFORM public.inventario_importar_excel('excel-1','entrada.xlsx',filas,true);
 r:=public.inventario_importar_excel('excel-otro','renombrado.xlsx',filas,true);
 IF (r->>'repetido')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'Duplicó archivo renombrado'; END IF;
 IF (SELECT count(*) FROM public.ordenes_produccion)<>antes THEN RAISE EXCEPTION 'Creó OP de producción'; END IF;
 r:=public.inventario_detalle('CLIENTE INVENTARIO','FICHA V0');
 SELECT (value->>'id')::uuid,(value->>'item_id')::uuid INTO t,iid FROM jsonb_array_elements(r) WHERE (value->>'entrada_excel')::boolean;
 IF t IS NULL THEN RAISE EXCEPTION 'Falta detalle Excel'; END IF;
 IF EXISTS(SELECT 1 FROM public.vista_kardex WHERE item_orden_id=iid) THEN RAISE EXCEPTION 'Mezcló entrada Excel con producción'; END IF;
 r:=public.inventario_listar('FICHA V0');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas') WHERE value->>'cliente'='CLIENTE INVENTARIO' AND (value->>'libre')::int=20) THEN RAISE EXCEPTION 'No agrupó el stock %',r; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_revertir(''manual-no-op'',%L,1,''Error'')',t));
 SELECT value INTO dest FROM jsonb_array_elements(public.destinatarios_para_empaque()) WHERE value->'datos'->>'nombre'='CLIENTE INVENTARIO';
 -- El catálogo se consulta por RPC autorizado.
 SELECT value INTO e FROM jsonb_array_elements(public.empaques_listar(false)) WHERE value->>'nombre'='Caja inventario';
 -- Se recupera el formato JSON del catálogo debajo si es un agregado.
 IF e IS NULL THEN RAISE EXCEPTION 'Falta empaque de prueba'; END IF;
 pack:=jsonb_build_array(jsonb_build_object('numero',1,'item_id',iid,'empaque_id',e->>'id','version',e->>'version','cantidad',20,'peso_bruto_kg',5));
 r:=public.inventario_empacar_flujo('manual-despacho',t,'OC MANUAL',(dest->>'id')::uuid,dest->>'version',pack);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_eliminar_excel(''reservada'',%L,''error'')',t));
 d:=(r->>'id')::uuid;
 PERFORM public.seguimiento_confirmar(d,0,(dest->>'id')::uuid);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 r:=public.inventario_detalle('CLIENTE INVENTARIO','FICHA V0');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r) WHERE value->>'id'=t::text AND (value->>'libre')::int=0 AND (value->>'despachado')::int=20) THEN RAISE EXCEPTION 'Saldo manual despachado incorrecto %',r; END IF;
END $$;
-- Misma ficha y cliente: las tallas no mezclan cantidades ni detalles.
DO $$ DECLARE r jsonb; BEGIN
 PERFORM public.inventario_importar_excel('excel-talla-32','talla32.xlsx','[{"ficha":"FICHA V0","cliente":"CLIENTE INVENTARIO","codigo":"000124","descripcion":"CAMISA MANUAL","talla":"32","cantidad":7,"estante":"INV-ESTANTE"}]',true);
 r:=public.inventario_listar('FICHA V0');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas') WHERE value->>'cliente'='CLIENTE INVENTARIO' AND value->>'talla'='32' AND (value->>'libre')::int=7 AND (value->>'despachado')::int=0) THEN RAISE EXCEPTION 'No separó stock talla 32 %',r; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas') WHERE value->>'cliente'='CLIENTE INVENTARIO' AND value->>'talla'='30' AND (value->>'libre')::int=0 AND (value->>'despachado')::int=20) THEN RAISE EXCEPTION 'Mezcló despachos talla 30 %',r; END IF;
 r:=public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','32',0);
 IF jsonb_array_length(r)<>1 OR r->0->>'talla'<>'32' OR (r->0->>'libre')::int<>7 THEN RAISE EXCEPTION 'Detalle mezcló tallas %',r; END IF;
 IF public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','NO EXISTE',0)<>'[]'::jsonb THEN RAISE EXCEPTION 'Detalle filtró incorrectamente'; END IF;
END $$;
DO $$ DECLARE h jsonb; BEGIN
 h:=public.inventario_historial_transferencias();
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(h) e WHERE e->>'numero_op'='INV-1' AND e->>'estante_origen'='INV-ESTANTE' AND e->>'estante_destino'='INV-DESTINO' AND (e->>'cantidad')::int=60 AND e->>'responsable'='INV 1') THEN RAISE EXCEPTION 'Falta trazabilidad del traslado %',h; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(h) e WHERE (e->>'reversion')::boolean AND e->>'estante_origen'='INV-DESTINO' AND e->>'estante_destino'='INV-ESTANTE') THEN RAISE EXCEPTION 'Falta trazabilidad de reversión'; END IF;
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000004',true);
 PERFORM pg_temp.rechaza('SELECT public.inventario_historial_transferencias()');
END $$;
-- Eliminación administrativa: roles, idempotencia y aislamiento por entrada.
DO $$ DECLARE r jsonb; t uuid; usado uuid; BEGIN
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 r:=public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','32',0); t:=(r->0->>'id')::uuid;
 usado:=(public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','30',0)->0->>'id')::uuid;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_eliminar_excel(''con-despacho'',%L,''error'')',usado));
 FOR n IN 2..4 LOOP
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-00000000000'||n,true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_eliminar_excel(''sin-permiso'',%L,''error'')',t));
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_eliminar_excel(''sin-motivo'',%L,%L)',t,''));
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_eliminar_excel(''op-original'',%L,''error'')',(public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','M',0)->0->>'id')::uuid));
 PERFORM public.inventario_eliminar_excel('eliminar-excel',t,'Carga equivocada');
 PERFORM public.inventario_eliminar_excel('eliminar-excel',t,'Carga equivocada');
 IF public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','32',0)<>'[]'::jsonb THEN RAISE EXCEPTION 'Entrada eliminada sigue visible'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(public.inventario_listar('FICHA V0')->'filas') f WHERE f->>'talla'='32') THEN RAISE EXCEPTION 'Entrada sigue en resumen'; END IF;
 IF jsonb_array_length(public.inventario_detalle_talla('CLIENTE INVENTARIO','FICHA V0','30',0))<>1 THEN RAISE EXCEPTION 'Eliminó otra talla'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE e record; BEGIN
 SELECT * INTO STRICT e FROM public.inventario_excel_eliminaciones WHERE solicitud='eliminar-excel';
 IF jsonb_array_length(e.movimientos)<>1 OR e.actor<>'10110000-0000-0000-0000-000000000001'::uuid THEN RAISE EXCEPTION 'Auditoría incompleta'; END IF;
 IF EXISTS(SELECT 1 FROM public.movimientos WHERE item_orden_id=(e.entrada->>'item_id')::uuid) THEN RAISE EXCEPTION 'Stock físico no retirado'; END IF;
 PERFORM pg_temp.rechaza('DELETE FROM public.inventario_excel_eliminaciones');
END $$;
-- Regresión: OP con cliente sin normalizar + Excel, nueva OC y una única LE.
INSERT INTO public.ordenes_produccion(id,numero_op,cliente,nombre_ficha_tecnica) VALUES
 ('11220000-0000-0000-0000-000000000001','MIX-OP',' Cliente  Inventario ','MULTI A');
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc) VALUES
 ('11230000-0000-0000-0000-000000000001','11220000-0000-0000-0000-000000000001','MULTIA','CAMISA MULTI','M',3,'OC ORIGINAL MIXTA');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id)
 SELECT tipo,'11230000-0000-0000-0000-000000000001',3,'10140000-0000-0000-0000-000000000001' FROM (VALUES('entrega_produccion'),('recepcion'))t(tipo);
-- Varias fichas/tallas/orígenes comparten una única LE.
SELECT set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE fuentes jsonb; asignaciones jsonb; pack jsonb; e jsonb; dest jsonb; r jsonb; d uuid; malo uuid; BEGIN
 PERFORM public.inventario_transferir_estante('multi-a','11230000-0000-0000-0000-000000000001','10140000-0000-0000-0000-000000000001',3,'Prueba mixta','INV-ESTANTE');
 PERFORM public.inventario_importar_excel('multi-b','b.xlsx','[{"ficha":"MULTI A","cliente":"CLIENTE INVENTARIO","codigo":"MULTIA","descripcion":"CAMISA MULTI","talla":"M","cantidad":6,"estante":"INV-DESTINO"},{"ficha":"MULTI B","cliente":"CLIENTE INVENTARIO","codigo":"MULTIB","descripcion":"PANTALON MULTI","talla":"32","cantidad":2,"estante":"INV-ESTANTE"}]',true);
 PERFORM public.inventario_importar_excel('multi-otro','otro.xlsx','[{"ficha":"MULTI C","cliente":"OTRO CLIENTE","codigo":"MULTIC","descripcion":"OTRO","talla":"S","cantidad":2,"estante":"INV-ESTANTE"}]',true);
 malo:=(public.inventario_detalle_talla('OTRO CLIENTE','MULTI C','S',0)->0->>'id')::uuid;
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_preparar_despacho('[{"cliente":"CLIENTE INVENTARIO","ficha":"MULTI A","talla":"M","cantidad":10}]')$q$);
 PERFORM pg_temp.rechaza($q$SELECT public.inventario_preparar_despacho('[{"cliente":"CLIENTE INVENTARIO","ficha":"MULTI A","talla":"M","cantidad":1},{"cliente":"OTRO CLIENTE","ficha":"MULTI C","talla":"S","cantidad":1}]')$q$);
 fuentes:=public.inventario_preparar_despacho('[{"cliente":"CLIENTE INVENTARIO","ficha":"MULTI A","talla":"M","cantidad":7},{"cliente":"CLIENTE INVENTARIO","ficha":"MULTI B","talla":"32","cantidad":2}]');
 IF jsonb_array_length(fuentes)<>3 OR (SELECT sum((f->>'libre')::int) FROM jsonb_array_elements(fuentes) f)<>9 THEN RAISE EXCEPTION 'No repartió cantidades entre orígenes'; END IF;
 SELECT value INTO e FROM jsonb_array_elements(public.empaques_listar(false)) WHERE value->>'nombre'='Caja inventario';
 dest:=public.destinatarios_para_empaque()->0;
 SELECT jsonb_agg(jsonb_build_object('transferencia',f->>'id','cantidad',(f->>'libre')::int)),
 jsonb_agg(jsonb_build_object('numero',1,'item_id',f->>'item_id','empaque_id',e->>'id','version',e->>'version','cantidad',(f->>'libre')::int,'peso_bruto_kg',5)) INTO asignaciones,pack FROM jsonb_array_elements(fuentes) f;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_multiple(''multi-mezcla'',%L,''OC MULTIPLE'',%L,%L,%L)',asignaciones||jsonb_build_array(jsonb_build_object('transferencia',malo,'cantidad',1)),dest->>'id',dest->>'version',pack));
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_multiple(''multi-desigual'',%L,''OC MULTIPLE'',%L,%L,%L)',asignaciones,dest->>'id',dest->>'version',jsonb_set(pack,'{0,cantidad}','999')));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000002',true);
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_multiple(''multi-sin-rol'',%L,''OC MULTIPLE'',%L,%L,%L)',asignaciones,dest->>'id',dest->>'version',pack));
 PERFORM set_config('request.jwt.claim.sub','10100000-0000-0000-0000-000000000001',true);
 r:=public.inventario_empacar_multiple('multi-le',asignaciones,'OC MULTIPLE',(dest->>'id')::uuid,dest->>'version',pack); d:=(r->>'id')::uuid;
 IF (public.inventario_empacar_multiple('multi-le',asignaciones,'OC MULTIPLE',(dest->>'id')::uuid,dest->>'version',pack)->>'id')::uuid<>d THEN RAISE EXCEPTION 'Duplicó LE'; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_multiple(''multi-exceso'',%L,''OC MULTIPLE'',%L,%L,%L)',asignaciones,dest->>'id',dest->>'version',pack));
 IF (SELECT sum((f->>'reservado')::int) FROM jsonb_array_elements(public.inventario_listar('MULTI')->'filas') f)<>9 THEN RAISE EXCEPTION 'Reserva múltiple incorrecta'; END IF;
 PERFORM public.inventario_cancelar(d,'Prueba de liberación total');
 IF (SELECT sum((f->>'reservado')::int) FROM jsonb_array_elements(public.inventario_listar('MULTI')->'filas') f)<>0 THEN RAISE EXCEPTION 'Cancelación dejó reservas'; END IF;
 -- Cambiar el orden obliga a tomar el cliente normalizado de Excel primero.
 SELECT jsonb_agg(value ORDER BY ordinal DESC) INTO asignaciones FROM jsonb_array_elements(asignaciones) WITH ORDINALITY a(value,ordinal);
 -- Fallo tardío en empaques: todas las asignaciones deben revertirse.
 PERFORM pg_temp.rechaza(format('SELECT public.inventario_empacar_multiple(''multi-version-invalida'',%L,''OC MULTIPLE'',%L,%L,%L)',asignaciones,dest->>'id',dest->>'version',jsonb_set(pack,'{0,version}','"desactualizada"')));
 r:=public.inventario_empacar_multiple('multi-salida',asignaciones,'OC MULTIPLE',(dest->>'id')::uuid,dest->>'version',pack); d:=(r->>'id')::uuid;
 PERFORM public.seguimiento_confirmar(d,0,(dest->>'id')::uuid);
 IF (SELECT sum((f->>'despachado')::int) FROM jsonb_array_elements(public.inventario_listar('MULTI')->'filas') f)<>9 THEN RAISE EXCEPTION 'Salida múltiple incorrecta'; END IF;
 PERFORM public.seguimiento_entregas_guardar(d,0,0,jsonb_build_object('estado','entregado','recibido',current_date,'transportadora','Transportadora prueba','observaciones','Entrega completa'));
 PERFORM public.facturacion_le_guardar(d,0,0,1,'REM-113','OC-ERP-113');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.historial_despachos_empaques('')) h CROSS JOIN LATERAL jsonb_array_elements(h->'eventos') ev WHERE h->>'despacho_oc_id'=d::text AND ev->>'accion'='Facturación actualizada') THEN RAISE EXCEPTION 'RPC omitió evento de facturación'; END IF;
 PERFORM pg_temp.rechaza('SELECT * FROM public.despacho_eventos');

END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT oc FROM public.items_orden WHERE id='11230000-0000-0000-0000-000000000001')<>'OC ORIGINAL MIXTA' THEN RAISE EXCEPTION 'Cambió OC original'; END IF;
 IF (SELECT count(DISTINCT despacho_id) FROM public.inventario_despachos WHERE solicitud='multi-salida')<>1 OR (SELECT count(*) FROM public.inventario_despachos WHERE solicitud='multi-salida')<>3 THEN RAISE EXCEPTION 'Trazabilidad no comparte LE'; END IF;
 IF EXISTS(SELECT 1 FROM public.inventario_despachos WHERE solicitud IN ('multi-mezcla','multi-desigual','multi-exceso','multi-sin-rol','multi-version-invalida')) THEN RAISE EXCEPTION 'Error dejó una reserva parcial'; END IF;
 IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud='multi-version-invalida') THEN RAISE EXCEPTION 'Error dejó despacho parcial'; END IF;
END $$;
DO $$ DECLARE tipo text; BEGIN
 FOREACH tipo IN ARRAY ARRAY['Empaque confirmado','Reserva cancelada','Salida confirmada','Documento LE generado o actualizado','Seguimiento actualizado','Facturación actualizada'] LOOP
 IF NOT EXISTS(SELECT 1 FROM public.despacho_eventos WHERE accion=tipo AND actor='INV 1') THEN RAISE EXCEPTION 'Falta evento % o responsable',tipo; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.despacho_eventos e JOIN public.despachos_oc d ON d.id=e.despacho_id WHERE d.solicitud='multi-version-invalida') THEN RAISE EXCEPTION 'Fallo dejó eventos'; END IF;
 PERFORM pg_temp.rechaza('DELETE FROM public.despacho_eventos');
END $$;
-- Despacho normal posterior al parche: mantiene cliente/OC exactos.
SET LOCAL ROLE authenticated;
DO $$ DECLARE lineas jsonb; pack jsonb; e jsonb; dest jsonb; r jsonb; ctx jsonb; BEGIN
 SELECT value INTO e FROM jsonb_array_elements(public.empaques_listar(false)) WHERE value->>'nombre'='Caja inventario';
 dest:=public.destinatarios_para_empaque()->0;
 lineas:='[{"item_id":"10130000-0000-0000-0000-000000000001","ubicacion":"INV-ESTANTE","cantidad":1}]';
 pack:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','10130000-0000-0000-0000-000000000001','empaque_id',e->>'id','version',e->>'version','cantidad',1,'peso_bruto_kg',5));
 PERFORM pg_temp.rechaza(format('SELECT public.guardar_empaque_destinatario_v92(''normal-oc-ajena'',''CLIENTE INVENTARIO'',''OC NUEVA'',%L,%L,%L,%L)',lineas,pack,dest->>'id',dest->>'version'));
 PERFORM pg_temp.rechaza(format('SELECT public.guardar_empaque_destinatario_v92(''normal-cliente-ajeno'',''OTRO CLIENTE'',''OC ORIGINAL'',%L,%L,%L,%L)',lineas,pack,dest->>'id',dest->>'version'));
 r:=public.guardar_empaque_destinatario_v92('normal-valido','CLIENTE INVENTARIO','OC ORIGINAL',lineas,pack,(dest->>'id')::uuid,dest->>'version');
 IF r->>'id' IS NULL THEN RAISE EXCEPTION 'Despacho normal no creó LE'; END IF;
 PERFORM public.admin_confirmar_le((r->>'id')::uuid,0,(dest->>'id')::uuid,'{}',99999,current_date);
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 r:=public.guardar_empaque_destinatario_v92('normal-corregido','CLIENTE INVENTARIO','OC ORIGINAL',lineas,jsonb_set(pack,'{0,peso_bruto_kg}','6'),(dest->>'id')::uuid,dest->>'version',(r->>'id')::uuid,ctx->>'version','Corrección de peso auditada');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.historial_despachos_empaques('')) h CROSS JOIN LATERAL jsonb_array_elements(h->'eventos') ev WHERE h->>'despacho_oc_id'=r->>'id' AND ev->>'accion'='Despacho corregido' AND ev->>'detalle'='Corrección de peso auditada') THEN RAISE EXCEPTION 'No auditó corrección'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.historial_despachos_empaques('')) h CROSS JOIN LATERAL jsonb_array_elements(h->'eventos') ev WHERE h->>'despacho_oc_id'=r->>'id' AND ev->>'accion'='LE ajustada por administrador') THEN RAISE EXCEPTION 'No auditó ajuste administrativo'; END IF;

END $$;
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
