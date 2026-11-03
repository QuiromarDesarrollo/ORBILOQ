-- PostgreSQL local aislado, después de 135. Revierte todos los datos.
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

 -- Validación sin armado: falla sin atribución y las solicitudes fallidas no penalizan.
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 datos:=jsonb_build_object('operacion_id',op,'kit_id',kit,'sku','001-A','request_id',gen_random_uuid());
 PERFORM pg_temp.rechazar('validar',datos,'Selecciona el empacador');
 datos:=datos||jsonb_build_object('empacador_id',persona);
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('sku','NO-EXISTE'),'sku_incorrecto','NO-EXISTE',0,0);
 PERFORM pg_temp.verificar((SELECT empacador_id IS NULL FROM public.masiva_kits WHERE id=kit),'Rechazo revierte asignación tardía');
 PERFORM pg_temp.rechazar('validar',datos||jsonb_build_object('validador_id','00000000-0000-0000-0000-000000000304'),'usuario de la sesión');
 UPDATE public.masiva_personal SET usuario_numero='T131-VALIDADOR1' WHERE id=persona;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 r:=public.masiva_ejecutar('validar',datos);
 PERFORM pg_temp.verificar(r->>'estado'='parcial','Valida sin finalizar empaque');
 PERFORM pg_temp.verificar(r=public.masiva_ejecutar('validar',datos),'Reintento idempotente');
 PERFORM pg_temp.verificar((SELECT count(*)=1 FROM public.masiva_auditoria WHERE kit_id=kit AND accion='reportar_error'
  AND masiva_auditoria.datos->>'categoria'='MAL EMPAQUE' AND masiva_auditoria.datos->>'empacador_id'=persona::text),'Una penalización atribuida al empacador');
 PERFORM pg_temp.verificar((SELECT armado IS NULL AND validador_id='00000000-0000-0000-0000-000000000303' FROM public.masiva_kits WHERE id=kit),'No inventa armado y conserva actor autenticado');
 r:=public.masiva_consultar(op,'indicadores');
 PERFORM pg_temp.verificar((r->'filas'->0->>'errores')::int=1 AND (r->'filas'->0->>'puntos')::int=-1,'Ranking incluye asignación tardía y resta MAL EMPAQUE');
 PERFORM pg_temp.verificar(r->'filas'->0->>'promedio_segundos' IS NULL,'Sin tiempos registrados no inventa promedio');
 r:=public.masiva_consultar(op,'validacion_documento','000131');
 PERFORM pg_temp.verificar((r->>'total')::int=1 AND r->'filas'->0->>'id'=kit::text,'Cédula exacta carga artículos');
 PERFORM pg_temp.verificar((public.masiva_consultar(op,'validacion_documento','131')->>'total')::int=0,'No admite coincidencia parcial de cédula');
 -- Registrar tiempo en paralelo crea la asignación automáticamente y preserva validaciones.
 r:=public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'lista','88','empacador_id',persona,'accion','iniciar'));
 asignacion:=(r->>'id')::uuid;
 PERFORM pg_temp.verificar((SELECT estado='parcial' AND asignacion_id=asignacion FROM public.masiva_kits WHERE id=kit),'Iniciar tiempo no degrada estado');
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asignacion,'accion','finalizar'));
 PERFORM pg_temp.verificar((SELECT estado='parcial' FROM public.masiva_kits WHERE id=kit),'Finalizar tiempo no degrada estado');
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('request_id',gen_random_uuid()));
 PERFORM pg_temp.rechazar_escaneo(datos||jsonb_build_object('request_id',gen_random_uuid()),'unidad_excedente','001-A',2,2);
 PERFORM public.masiva_ejecutar('validar',datos||jsonb_build_object('sku','002-B','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT count(*)=1 FROM public.masiva_auditoria WHERE kit_id=kit AND accion='reportar_error'),'Lecturas nuevas no repiten penalización');
 PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op,'kit_id',kit,'caja',1,'empaque_id',empaque));
 PERFORM pg_temp.verificar((SELECT estado='validado' AND caja_id IS NOT NULL FROM public.masiva_kits WHERE id=kit),'Empacar conserva validación completa');
 -- El registro normal antes de validar no genera penalización y tampoco exige finalizar.
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op,'89');
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre) VALUES(op,'89',1,'NORMAL134','Normal') RETURNING id INTO kit;
 INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad) VALUES(kit,'N134','Normal',2);
 INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,esperado,recibido) VALUES(op,'N','N','N134','Normal',2,2);
 r:=public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'lista','89','empacador_id',persona,'accion','iniciar'));
 PERFORM public.masiva_ejecutar('validar',jsonb_build_object('operacion_id',op,'kit_id',kit,'sku','N134','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar(NOT EXISTS(SELECT 1 FROM public.masiva_auditoria WHERE kit_id=kit AND accion='reportar_error'),'Registro previo no penaliza');
 SELECT jsonb_agg(jsonb_build_object('articulo_id',id,'validado',validado)) INTO cantidades FROM public.masiva_articulos WHERE kit_id=kit;
 PERFORM public.masiva_ejecutar('reiniciar_validacion',jsonb_build_object('operacion_id',op,'kit_id',kit,'cantidades',cantidades,'motivo','Revisión de prueba','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT estado='pendiente' AND armado IS NULL FROM public.masiva_kits WHERE id=kit),'Reinicio no inventa armado');
 PERFORM pg_temp.verificar((SELECT validado=0 FROM public.masiva_inventario WHERE operacion_id=op AND sku='N134'),'Reinicio devuelve inventario');
END $$;
ROLLBACK;
SELECT '135: mismo empacador y validador, validación directa, atribución, penalización, tiempos paralelos e inventario OK' AS resultado;


