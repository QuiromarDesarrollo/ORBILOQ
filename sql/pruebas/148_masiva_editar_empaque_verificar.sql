-- Prueba funcional aislada. Todo dato creado aqui se revierte con ROLLBACK.
-- No usa kits ni inventario operativos: crea una operacion temporal y dos kits.
BEGIN;
SET LOCAL statement_timeout='60s';
DO $test$
DECLARE actor uuid; op_id uuid:=gen_random_uuid(); persona_id uuid:=gen_random_uuid();
 kit1 uuid:=gen_random_uuid(); kit2 uuid:=gen_random_uuid(); art1 uuid:=gen_random_uuid(); art2 uuid:=gen_random_uuid();
 inv_id uuid:=gen_random_uuid(); tipo1 uuid; tipo2 uuid; caja1 uuid; caja2 uuid; salida jsonb;
 antes jsonb; despues jsonb; rechazos integer:=0;
BEGIN
 IF position('masiva148_editar_empaque' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Falta migracion 148'; END IF;
 SELECT auth_id INTO STRICT actor FROM public.usuarios WHERE activo AND auth_id IS NOT NULL
 AND coalesce(roles,ARRAY[rol]) && ARRAY['masiva','admin'] ORDER BY ('masiva'=ANY(coalesce(roles,ARRAY[rol]))) DESC LIMIT 1;
 SELECT id INTO STRICT tipo1 FROM public.masiva_catalogo_empaques WHERE activo AND peso_lleno IS NOT NULL ORDER BY id LIMIT 1;
 SELECT id INTO STRICT tipo2 FROM public.masiva_catalogo_empaques WHERE activo AND peso_lleno IS NOT NULL AND id<>tipo1 ORDER BY id LIMIT 1;
 INSERT INTO public.masiva_operaciones(id,nombre,cliente,creado_por) VALUES(op_id,'PRUEBA TRANSACCIONAL 148','PRUEBA AISLADA',actor);
 INSERT INTO public.masiva_personal(id,nombre,creado_por) VALUES(persona_id,'PRUEBA TRANSACCIONAL 148',actor);
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op_id,'148');
 INSERT INTO public.masiva_kits(id,operacion_id,lista,numero_persona,cedula,nombre,estado,empacador_id,armado,validacion_inicio,revision_abierta)
 VALUES(kit1,op_id,'148',1,'PRUEBA148-1','PRUEBA AISLADA 1','parcial',persona_id,now(),now(),true),
       (kit2,op_id,'148',2,'PRUEBA148-2','PRUEBA AISLADA 2','parcial',persona_id,now(),now(),true);
 INSERT INTO public.masiva_articulos(id,kit_id,sku,descripcion,cantidad,validado)
 VALUES(art1,kit1,'PRUEBA148','ARTICULO AISLADO',2,1),(art2,kit2,'PRUEBA148','ARTICULO AISLADO',2,1);
 INSERT INTO public.masiva_inventario(id,operacion_id,proveedor,pedido,sku,descripcion,esperado,recibido,validado)
 VALUES(inv_id,op_id,'PRUEBA','148','PRUEBA148','ARTICULO AISLADO',4,4,2);
 INSERT INTO public.masiva_consumos(articulo_id,inventario_id,cantidad) VALUES(art1,inv_id,1),(art2,inv_id,1);
 INSERT INTO public.masiva_validacion_creditos(articulo_id,actor_id,cantidad) VALUES(art1,actor,1),(art2,actor,1);
 SELECT jsonb_build_object('recibido',recibido,'validado',validado,
  'credito',(SELECT sum(cantidad) FROM public.masiva_validacion_creditos WHERE articulo_id IN(art1,art2)),
  'consumo',(SELECT sum(cantidad) FROM public.masiva_consumos WHERE articulo_id IN(art1,art2)),
  'armado',(SELECT armado FROM public.masiva_kits WHERE id=kit1)) INTO antes FROM public.masiva_inventario WHERE id=inv_id;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 salida:=public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',1,'empaque_id',tipo1));
 BEGIN
  PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',1,'empaque_id',tipo2));
  RAISE EXCEPTION 'ERROR PRUEBA: modifico un kit cerrado';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Reabre el kit%' THEN RAISE; END IF; rechazos:=rechazos+1;
 END;
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'motivo','Prueba de edicion aislada'));
 salida:=public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',1,'empaque_id',tipo2));
 IF salida->'empaque_anterior'->>'empaque_catalogo_id' IS DISTINCT FROM tipo1::text
 OR salida->'empaque_actual'->>'empaque_catalogo_id' IS DISTINCT FROM tipo2::text THEN RAISE EXCEPTION 'Falta snapshot antes/despues'; END IF;
 caja1:=(salida->'empaque_actual'->>'id')::uuid;
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'motivo','Prueba renumerar'));
 salida:=public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',5,'empaque_id',tipo2));
 IF salida->'empaque_actual'->>'id' IS DISTINCT FROM caja1::text OR (salida->>'caja')::integer<>5 THEN RAISE EXCEPTION 'Renumeracion no conservo la caja'; END IF;
 -- Compartir caja con otro kit y comprobar que su tipo no cambia indirectamente.
 PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit2,'caja',5,'empaque_id',tipo2));
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'motivo','Prueba caja compartida'));
 BEGIN
  PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',5,'empaque_id',tipo1));
  RAISE EXCEPTION 'ERROR PRUEBA: modifico caja compartida';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Este contenedor utiliza otro tipo%' THEN RAISE; END IF; rechazos:=rechazos+1;
 END;
 salida:=public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',6,'empaque_id',tipo1));
 caja2:=(salida->'empaque_actual'->>'id')::uuid;
 IF caja2=caja1 THEN RAISE EXCEPTION 'No separo el kit del contenedor compartido'; END IF;
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'motivo','Prueba no dejar vacios'));
 BEGIN
  PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',5,'empaque_id',tipo2));
  RAISE EXCEPTION 'ERROR PRUEBA: dejo contenedor vacio';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Ese numero ya existe%' THEN RAISE; END IF; rechazos:=rechazos+1;
 END;
 EXECUTE 'RESET ROLE';
 SELECT jsonb_build_object('recibido',recibido,'validado',validado,
  'credito',(SELECT sum(cantidad) FROM public.masiva_validacion_creditos WHERE articulo_id IN(art1,art2)),
  'consumo',(SELECT sum(cantidad) FROM public.masiva_consumos WHERE articulo_id IN(art1,art2)),
  'armado',(SELECT armado FROM public.masiva_kits WHERE id=kit1)) INTO despues FROM public.masiva_inventario WHERE id=inv_id;
 IF antes IS DISTINCT FROM despues THEN RAISE EXCEPTION 'Empaque/reapertura alteraron inventario, creditos o armado'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=kit2 AND caja_id=caja1)
 OR NOT EXISTS(SELECT 1 FROM public.masiva_cajas WHERE id=caja1 AND empaque_catalogo_id=tipo2) THEN RAISE EXCEPTION 'Se afecto el segundo kit'; END IF;
 IF EXISTS(SELECT 1 FROM public.masiva_cajas c WHERE operacion_id=op_id AND NOT EXISTS(SELECT 1 FROM public.masiva_kits k WHERE k.caja_id=c.id)) THEN RAISE EXCEPTION 'Quedaron cajas vacias'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_auditoria WHERE operacion_id=op_id AND kit_id=kit1 AND accion='embalar' AND datos->'resultado' ? 'empaque_anterior' AND datos->'resultado' ? 'empaque_actual') THEN RAISE EXCEPTION 'Falta auditoria de empaque'; END IF;
 -- Completar la validacion debe mantener abierta la edicion hasta guardar empaque.
 EXECUTE 'SET LOCAL ROLE authenticated';
 PERFORM public.masiva_ejecutar('validar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'sku','PRUEBA148','request_id',gen_random_uuid()));
 EXECUTE 'RESET ROLE';
 IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=kit1 AND revision_abierta AND estado='validado') THEN RAISE EXCEPTION 'Completar lecturas cerro la edicion'; END IF;
 EXECUTE 'SET LOCAL ROLE authenticated';
 PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op_id,'kit_id',kit1,'caja',6,'empaque_id',tipo2));
 EXECUTE 'RESET ROLE';
 IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=kit1 AND revision_abierta) THEN RAISE EXCEPTION 'Guardar no cerro la edicion'; END IF;
 IF rechazos<>3 THEN RAISE EXCEPTION 'Conteo de rechazos inesperado'; END IF;
END $test$;
ROLLBACK;
SELECT 'OK: editar y renumerar caja exclusiva; separar kit de caja compartida; 3 rechazos seguros; conservar stock/creditos al reabrir/embalar; guardar cierra edicion; fixtures revertidos' AS resultado;
