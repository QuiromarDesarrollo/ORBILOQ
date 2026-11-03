-- Solo base LOCAL con fixture y migraciones 129-133. Todo se revierte.
BEGIN;
INSERT INTO auth.users(id) VALUES('13300000-0000-0000-0000-000000000001');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo)
VALUES('13300000-0000-0000-0000-000000000001','CONCILIA-ADMIN','Administrador ficticio','admin',ARRAY['admin'],true);
SELECT set_config('request.jwt.claim.sub','13300000-0000-0000-0000-000000000001',true);
DO $$ DECLARE op uuid; imp uuid; inv uuid; req uuid:=gen_random_uuid(); r jsonb; x jsonb; n integer; rejected boolean;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Conciliación ficticia","cliente":"Cliente ficticio"}')->>'id')::uuid;
 INSERT INTO public.masiva_pedidos(operacion_id,proveedor,pedido,orden_carga) VALUES(op,'A','OC1',1),(op,'B','OC2',2);
 INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,esperado,recibido,validado)
 VALUES(op,'A','OC1','001','Camisa',10,5,2) RETURNING id INTO inv;
 INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,esperado,recibido,validado)
 VALUES(op,'B','OC2','001','Camisa',8,2,1),(op,'A','OC1','003','Prenda extra',3,2,0);
 r:=public.masiva_conciliacion_consultar(op);
 IF r#>>'{metricas,base_personal_cargada}'<>'false' OR r#>'{filas,0,proyeccion}'<>'null'::jsonb THEN RAISE EXCEPTION 'Sin base no debe inventar sobrantes'; END IF;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','ficticio.xlsx','total_filas',2,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[
 {"lista":"1","numero_persona":1,"cedula":"P1","nombre":"Persona","sku":"001","descripcion":"Camisa","cantidad":10},
 {"lista":"1","numero_persona":1,"cedula":"P1","nombre":"Persona","sku":"002","descripcion":"Sin pedido","cantidad":4}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 r:=public.masiva_conciliacion_consultar(op);
 IF (r->>'total')::int<>3 THEN RAISE EXCEPTION 'Debe agrupar SKU e incluir demanda sin pedido'; END IF;
 x:=r#>'{filas,0}';
 IF x->>'sku'<>'001' OR (x->>'requerido')::int<>10 OR (x->>'esperado')::int<>18
 OR (x->>'recibido')::int<>7 OR (x->>'pendiente')::int<>11 OR (x->>'disponible')::int<>4
 OR (x->>'saldo')::int<>-3 OR (x->>'proyeccion')::int<>8 THEN RAISE EXCEPTION 'Cruce incorrecto: %',x; END IF;
 IF (r#>>'{metricas,sobrante_previsto}')::int<>11 OR (r#>>'{metricas,faltante_previsto}')::int<>4 THEN RAISE EXCEPTION 'No compensar faltantes con sobrantes'; END IF;
 IF (public.masiva_conciliacion_consultar(op,'','sin_pedido')->>'total')::int<>1
 OR (public.masiva_conciliacion_consultar(op,'','faltante')->>'total')::int<>1
 OR (public.masiva_conciliacion_consultar(op,'','sobrante')->>'total')::int<>2
 OR (public.masiva_conciliacion_consultar(op,'Camisa')->>'total')::int<>1 THEN RAISE EXCEPTION 'Filtros incorrectos'; END IF;
 IF jsonb_array_length(public.masiva_recepcion_puesto(op)->'pedidos')<>2 THEN RAISE EXCEPTION 'Órdenes por proveedor incorrectas'; END IF;
 x:=jsonb_build_object('operacion_id',op,'inventario_id',inv,'cantidad',1,'soporte','Remisión ficticia','request_id',req);
 PERFORM public.masiva_ejecutar('recibir',x); PERFORM public.masiva_ejecutar('recibir',x);
 IF (SELECT recibido FROM public.masiva_inventario WHERE id=inv)<>6 THEN RAISE EXCEPTION 'Reintento duplicó recepción'; END IF;
 IF (SELECT count(*) FROM public.masiva_movimientos WHERE inventario_id=inv AND tipo='recepcion')<>1 THEN RAISE EXCEPTION 'Auditoría duplicada'; END IF;
 rejected:=false;
 BEGIN PERFORM public.masiva_ejecutar('recibir',x||jsonb_build_object('cantidad',100,'request_id',gen_random_uuid()));
 EXCEPTION WHEN raise_exception THEN rejected:=true; END;
 IF NOT rejected OR (SELECT recibido FROM public.masiva_inventario WHERE id=inv)<>6 THEN RAISE EXCEPTION 'No bloquea exceso'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 rejected:=false;
 BEGIN PERFORM public.masiva_conciliacion_consultar(op); EXCEPTION WHEN insufficient_privilege THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Consulta expuesta sin autorización'; END IF;
 RAISE NOTICE '133 OK: cruce, faltantes, saldos, soporte, límites, idempotencia y acceso';
END $$;
ROLLBACK;
