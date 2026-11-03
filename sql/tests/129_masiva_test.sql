-- Prueba transaccional sobre una base PostgreSQL local desechable, sin Supabase remoto.
-- Requiere 129_masiva.sql, auth.users y public.usuarios. No carga los Excel reales.
BEGIN;
CREATE FUNCTION pg_temp.verificar(condicion boolean,mensaje text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',mensaje; END IF; END $$;
CREATE FUNCTION pg_temp.rechazar(accion text,datos jsonb,fragmento text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE fallo text;
BEGIN
 BEGIN PERFORM public.masiva_ejecutar(accion,datos); EXCEPTION WHEN OTHERS THEN fallo:=SQLERRM; END;
 IF fallo IS NULL OR position(fragmento IN fallo)=0 THEN RAISE EXCEPTION 'FALLO: % esperaba %, recibió %',accion,fragmento,fallo; END IF;
END $$;

INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('00000000-0000-0000-0000-000000000001','TEST-ADMIN','Administrador de prueba','admin',ARRAY['admin'],true),
 ('00000000-0000-0000-0000-000000000002','TEST-ARMADOR','Armador de prueba','masiva',ARRAY['masiva'],true),
 ('00000000-0000-0000-0000-000000000003','TEST-VALIDADOR','Validador de prueba','masiva',ARRAY['masiva'],true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);

DO $$ DECLARE op uuid; op2 uuid; imp uuid; imp2 uuid; p uuid; p2 uuid; empaque uuid; k1 uuid; k2 uuid; i1 uuid; i2 uuid; a1 uuid; a2 uuid;
 asig uuid; req uuid; r jsonb; d jsonb; original jsonb; pagina jsonb; vist text; n integer;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Operación de prueba","cliente":"Cliente ficticio"}')->>'id')::uuid;
 op2:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Otra operación","cliente":"Cliente ficticio"}')->>'id')::uuid;
 p:=(public.masiva_ejecutar('guardar_personal','{"nombre":"Armador de prueba","usuario_numero":"TEST-ARMADOR"}')->>'id')::uuid;
 p2:=(public.masiva_ejecutar('guardar_personal','{"nombre":"Persona sin cuenta"}')->>'id')::uuid;
 empaque:=(public.masiva_ejecutar('guardar_empaque','{"nombre":"Caja estándar","peso_vacio":0.5,"peso_lleno":10,"largo":40,"ancho":30,"alto":20}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','recepcion','archivo','Proveedor original.xlsx','total_filas',2,'total_lotes',2))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[{"proveedor":"Proveedor A","pedido":"P1","sku":"001-A","descripcion":"Camisa","cantidad":3,"unidad":"UNIDAD","recibido":999}]'::jsonb));
 PERFORM pg_temp.rechazar('confirmar_importacion',jsonb_build_object('importacion_id',imp),'incompleta');
 PERFORM pg_temp.verificar((SELECT count(*)=0 FROM public.masiva_inventario WHERE operacion_id=op),'Una carga incompleta no debe crear inventario');
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',1,'filas','[{"proveedor":"Proveedor B","pedido":"P2","sku":"002-B","descripcion":"Calzado","cantidad":2,"unidad":"PAR"}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 PERFORM pg_temp.verificar((SELECT count(*)=2 AND sum(recibido)=0 FROM public.masiva_inventario WHERE operacion_id=op),'Importación idempotente y recibido inicial cero');
 SELECT id INTO i1 FROM public.masiva_inventario WHERE operacion_id=op AND sku='001-A';
 SELECT id INTO i2 FROM public.masiva_inventario WHERE operacion_id=op AND sku='002-B';
 req:=gen_random_uuid(); d:=jsonb_build_object('operacion_id',op,'inventario_id',i1,'cantidad',3,'soporte','REM-001','request_id',req);
 PERFORM public.masiva_ejecutar('recibir',d); PERFORM public.masiva_ejecutar('recibir',d);
 PERFORM pg_temp.verificar((SELECT recibido=3 FROM public.masiva_inventario WHERE id=i1),'Reintentar recepción no duplica stock');
 PERFORM pg_temp.rechazar('recibir',d||jsonb_build_object('cantidad',2),'Identificador');
 PERFORM pg_temp.rechazar('recibir',d||jsonb_build_object('cantidad',1,'request_id',gen_random_uuid()),'supera el límite');
 PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',i2,'cantidad',1,'soporte','REM-002','request_id',gen_random_uuid()));
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','Base sin cambiar nombre.xlsx','total_filas',3,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas',
 '[{"lista":"88","numero_persona":1,"cedula":"000123","nombre":"Persona Uno","sku":"001-A","descripcion":"Camisa","cantidad":2,"lider":"Líder A","fecha_empaque":"1999-01-01"},
 {"lista":"88","numero_persona":1,"cedula":"000123","nombre":"Persona Uno","sku":"002-B","descripcion":"Calzado","cantidad":1,"lider":"Líder B"},
 {"lista":"88","numero_persona":2,"cedula":"000456","nombre":"Persona Dos","sku":"001-A","descripcion":"Camisa","cantidad":1,"lider":"Líder A"}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 SELECT id INTO k1 FROM public.masiva_kits WHERE operacion_id=op AND numero_persona=1;
 SELECT id INTO k2 FROM public.masiva_kits WHERE operacion_id=op AND numero_persona=2;
 SELECT id INTO a1 FROM public.masiva_articulos WHERE kit_id=k1 AND sku='001-A';
 PERFORM pg_temp.verificar((SELECT count(*)=2 FROM public.masiva_kits WHERE operacion_id=op),'Varias prendas son un kit');
 PERFORM pg_temp.verificar((SELECT cedula='000123' FROM public.masiva_kits WHERE id=k1),'Conservar ceros del documento');
 PERFORM pg_temp.rechazar('validar',jsonb_build_object('operacion_id',op,'kit_id',k1,'sku','001-A','request_id',gen_random_uuid()),'Finaliza el armado');
 PERFORM pg_temp.rechazar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','lista'),'Valida prendas');
 asig:=(public.masiva_ejecutar('asignar',jsonb_build_object('operacion_id',op,'lista','88','empacador_id',p))->>'id')::uuid;
 PERFORM pg_temp.rechazar('asignar',jsonb_build_object('operacion_id',op,'lista','88','empacador_id',p2,'desde',1,'hasta',2),'se cruza');
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','iniciar'));
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','pausar'));
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','iniciar'));
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','finalizar'));
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 PERFORM pg_temp.rechazar('validar',jsonb_build_object('operacion_id',op,'kit_id',k1,'sku','001-A','request_id',gen_random_uuid()),'distinta');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
 PERFORM pg_temp.rechazar('crear_operacion','{"nombre":"No autorizado","cliente":"Cliente"}','administrador');
 req:=gen_random_uuid(); d:=jsonb_build_object('operacion_id',op,'kit_id',k1,'sku','001-A','request_id',req);
 PERFORM public.masiva_ejecutar('validar',d); PERFORM public.masiva_ejecutar('validar',d);
 PERFORM pg_temp.verificar((SELECT validado=1 FROM public.masiva_articulos WHERE id=a1),'Reintento de escaneo no duplica');
 PERFORM public.masiva_ejecutar('embalar',jsonb_build_object('operacion_id',op,'kit_id',k1,'caja',1,'empaque_id',empaque));
 PERFORM pg_temp.rechazar('embalar',jsonb_build_object('operacion_id',op,'kit_id',k1,'caja',2,'empaque_id',empaque),'otro empaque');
 PERFORM pg_temp.rechazar('validar',jsonb_build_object('operacion_id',op,'kit_id',k1,'sku','003-NO','request_id',gen_random_uuid()),'no pertenece');
 PERFORM public.masiva_ejecutar('validar',d||jsonb_build_object('request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('validar',jsonb_build_object('operacion_id',op,'kit_id',k1,'sku','002-B','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT validado=1 AND recibido=1 FROM public.masiva_inventario WHERE id=i2),'Calzado descuenta un par');
 PERFORM pg_temp.verificar((SELECT estado='validado' FROM public.masiva_kits WHERE id=k1),'Kit completo validado');
 PERFORM pg_temp.rechazar('corregir',jsonb_build_object('operacion_id',op,'kit_id',k1,'articulo_id',a1,'cantidad',1,'motivo','Corrección probada','request_id',gen_random_uuid()),'Reabre');
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op,'kit_id',k1,'motivo','Reconteo por auditoría'));
 PERFORM pg_temp.verificar((SELECT validado=2 FROM public.masiva_inventario WHERE id=i1),'Reabrir no descuenta de nuevo');
 PERFORM public.masiva_ejecutar('corregir',jsonb_build_object('operacion_id',op,'kit_id',k1,'articulo_id',a1,'cantidad',1,'motivo','Sobra una prenda en conteo','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT validado=1 FROM public.masiva_inventario WHERE id=i1),'Corregir devuelve solo diferencia');
 PERFORM public.masiva_ejecutar('validar',d||jsonb_build_object('request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('reportar_error',jsonb_build_object('operacion_id',op,'kit_id',k1,'motivo','Corrección de cantidad','request_id',gen_random_uuid()));
 PERFORM pg_temp.verificar((SELECT sum(c.cantidad)=3 FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id WHERE a.kit_id=k1),'Corregir y revalidar conserva solo el crédito neto');
 r:=public.masiva_ejecutar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','lista')); original:=r->'snapshot';
 PERFORM pg_temp.verificar(original->>'formato_version'='1','El documento conserva la versión de su formato');
 PERFORM pg_temp.verificar(jsonb_array_length(original->'kits')=1,'Documento solo incluye kits con prendas validadas y embaladas');
 -- No omitir silenciosamente otro kit validado que todavía no tiene empaque.
 PERFORM public.masiva_ejecutar('validar',jsonb_build_object('operacion_id',op,'kit_id',k2,'sku','001-A','request_id',gen_random_uuid()));
 PERFORM pg_temp.rechazar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','lista'),'Asigna un empaque');
 PERFORM pg_temp.rechazar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','rotulo'),'Asigna un empaque');
 PERFORM pg_temp.verificar((SELECT count(*)=1 FROM public.masiva_documentos WHERE operacion_id=op),'Rechazo de documento no crea una versión parcial');
 PERFORM public.masiva_ejecutar('reabrir',jsonb_build_object('operacion_id',op,'kit_id',k2,'motivo','Revertir recepción de prueba'));
 SELECT id INTO a2 FROM public.masiva_articulos WHERE kit_id=k2 AND sku='001-A';
 PERFORM public.masiva_ejecutar('corregir',jsonb_build_object('operacion_id',op,'kit_id',k2,'articulo_id',a2,'cantidad',0,'motivo','Reconteo sin unidades validadas','request_id',gen_random_uuid()));
 PERFORM public.masiva_ejecutar('documento',jsonb_build_object('operacion_id',op,'lista','88','tipo','rotulo'));
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 PERFORM public.masiva_ejecutar('configurar',jsonb_build_object('operacion_id',op,'lista','88','responsable','Responsable cambiado','logo_cliente','data:image/png;base64,YQ=='));
 PERFORM pg_temp.verificar((SELECT snapshot=original FROM public.masiva_documentos WHERE id=(r->>'id')::uuid),'Cambiar logo o responsable no cambia reimpresiones');
 FOREACH vist IN ARRAY ARRAY['resumen','inventario','listas','kits','auditoria','personal','empaques','asignaciones','documentos','indicadores','configuracion'] LOOP
  pagina:=public.masiva_consultar(op,vist,'',1,'');
  PERFORM pg_temp.verificar(pagina ? 'metricas' AND pagina ? 'filas','Consulta de '||vist);
 END LOOP;
 PERFORM pg_temp.verificar((public.masiva_consultar(op,'listas','',1,'no-existe')->>'total')::integer=0,'Filtrar una lista exacta');
 PERFORM pg_temp.verificar(public.masiva_consultar(op,'resumen')->'metricas'->'importaciones'->'recepcion'->>'estado'='confirmada','Estado de importación');
 -- Una base inválida no puede dejar listas ni kits parciales.
 imp2:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op2,'tipo','personal','archivo','Base errónea.xlsx','total_filas',2,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp2,'indice',0,'filas',
 '[{"lista":"L1","numero_persona":1,"cedula":"X","nombre":"Uno","sku":"A","descripcion":"Camisa","cantidad":1},
 {"lista":"L1","numero_persona":1,"cedula":"Y","nombre":"Dos","sku":"A","descripcion":"Camisa","cantidad":1}]'::jsonb));
 PERFORM pg_temp.rechazar('confirmar_importacion',jsonb_build_object('importacion_id',imp2),'consecutivo');
 PERFORM pg_temp.verificar((SELECT count(*)=0 FROM public.masiva_kits WHERE operacion_id=op2),'Atomicidad de importación inválida');
 -- Inmutabilidad no depende únicamente de la interfaz ni del rol cliente.
 BEGIN UPDATE public.masiva_documentos SET snapshot='{}' WHERE id=(r->>'id')::uuid;
  RAISE EXCEPTION 'FALLO: documento editable';
 EXCEPTION WHEN raise_exception THEN IF position('inmutable' IN SQLERRM)=0 THEN RAISE; END IF; END;
 BEGIN DELETE FROM public.masiva_auditoria WHERE operacion_id=op AND accion='reabrir';
  RAISE EXCEPTION 'FALLO: auditoría borrable';
 EXCEPTION WHEN raise_exception THEN IF position('inmutable' IN SQLERRM)=0 THEN RAISE; END IF; END;
 PERFORM public.masiva_ejecutar('cerrar_operacion',jsonb_build_object('operacion_id',op,'motivo','Operación de prueba terminada'));
 PERFORM pg_temp.verificar((SELECT recibido-validado=1 FROM public.masiva_inventario WHERE id=i1),'Sobrante se conserva al cerrar');
 PERFORM pg_temp.verificar((SELECT count(*)=0 FROM public.masiva_inventario WHERE operacion_id=op2),'Nunca transfiere sobrantes');
 PERFORM pg_temp.rechazar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',i2,'cantidad',1,'soporte','REM-003','request_id',gen_random_uuid()),'cerrada');
 PERFORM pg_temp.verificar((public.masiva_consultar(op,'documentos',(r->>'id'),1,'')->'filas'->0->'snapshot')=original,'Reimpresión disponible tras cierre');
 PERFORM pg_temp.verificar((SELECT count(*)>=3 FROM public.masiva_auditoria WHERE operacion_id=op AND accion IN('reabrir','corregir','reportar_error')),'Auditoría de revisiones');
 PERFORM pg_temp.verificar(NOT has_table_privilege('authenticated','public.masiva_inventario','UPDATE'),'Sin escritura directa de inventario');
 PERFORM pg_temp.verificar(NOT has_function_privilege('anon','public.masiva_ejecutar(text,jsonb)','EXECUTE'),'Sin RPC anónima');
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM pg_temp.rechazar('crear_operacion','{"nombre":"No autorizado","cliente":"Cliente"}','Acceso exclusivo');
 RAISE NOTICE 'MASIVA: pruebas de importación, recepción, armado, validación, auditoría, documentos, cierre y permisos PASARON';
END $$;
ROLLBACK;
