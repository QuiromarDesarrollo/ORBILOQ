-- Solo PostgreSQL LOCAL con fixture y migraciones 129 a 132. Sin datos reales.
BEGIN;
INSERT INTO auth.users(id) VALUES('13200000-0000-0000-0000-000000000001'),('13200000-0000-0000-0000-000000000002'),
 ('13200000-0000-0000-0000-000000000003'),('13200000-0000-0000-0000-000000000004');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('13200000-0000-0000-0000-000000000001','MAESTRO-ADMIN','Administrador ficticio','admin',ARRAY['admin'],true),
 ('13200000-0000-0000-0000-000000000002','MAESTRO-MASIVA','Validador ficticio','masiva',ARRAY['masiva'],true),
 ('13200000-0000-0000-0000-000000000003','MAESTRO-INACTIVO','Inactivo ficticio','masiva',ARRAY['masiva'],false),
 ('13200000-0000-0000-0000-000000000004','MAESTRO-OTRO','Otro ficticio','produccion',ARRAY['produccion'],true);
SELECT set_config('request.jwt.claim.sub','13200000-0000-0000-0000-000000000001',true);
DO $$ DECLARE op uuid; imp uuid; op_mala uuid; imp_mala uuid; filas jsonb; f jsonb; r jsonb; r2 jsonb;
 caja uuid; bolsa uuid; caja_vacia uuid; empaque uuid; personal uuid; inv uuid; art uuid; kit uuid;
 n integer; previo integer; error boolean; original jsonb; huella text; posterior text;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Maestro ficticio","cliente":"Cliente ficticio"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal',
  'archivo','maestro-ficticio.xlsx','total_filas',58,'total_lotes',1))->>'importacion_id')::uuid;
 filas:='[
  {"lista":"L1","numero_persona":1,"cedula":"P1","nombre":"Persona Uno","sku":"X","descripcion":"Prenda X","cantidad":2,"ciudad":"Bogotá","sede":"Sede A","sector":"Sector A","unidad":"Unidad A","direccion":"Dirección A","lider":"Líder A"},
  {"lista":"L1","numero_persona":1,"cedula":"P1","nombre":"Persona Uno","sku":"Y","descripcion":"Prenda Y","cantidad":1,"ciudad":"Bogotá","sede":"Sede A","sector":"Sector A","unidad":"Unidad A","direccion":"Dirección A","lider":"Líder A"},
  {"lista":"L1","numero_persona":2,"cedula":"P2","nombre":"Persona Dos","sku":"X","descripcion":"Prenda X","cantidad":2,"ciudad":"Cali","sede":"Sede B","sector":"Sector B","unidad":"Unidad B","direccion":"Dirección B","lider":"Líder B"},
  {"lista":"L1","numero_persona":3,"cedula":"P3","nombre":"Persona Tres","sku":"Z","descripcion":"Prenda Z","cantidad":1},
  {"lista":"L2","numero_persona":1,"cedula":"P4","nombre":"Persona Cuatro","sku":"Y","descripcion":"Prenda Y","cantidad":1},
  {"lista":"L3","numero_persona":1,"cedula":"P5","nombre":"Persona Cinco","sku":"Y","descripcion":"Prenda Y","cantidad":2}
 ]';
 SELECT filas||jsonb_agg(jsonb_build_object('lista','Z'||lpad(g.n::text,3,'0'),'numero_persona',1,
  'cedula','PX'||g.n,'nombre','Persona extra '||g.n,'sku','EXTRA','descripcion','Prenda extra','cantidad',1,
  'ciudad',CASE WHEN g.n%2=0 THEN 'Cali' ELSE 'Bogotá' END,'sede','Sede extra '||g.n,
  'fuente',jsonb_build_object('cargo','Cargo extra '||g.n,'items_kit',1,'fecha_empaque_programada','2099-01-01'),
  'fila_origen',g.n+10,'hoja_origen','BASE')) INTO filas FROM generate_series(1,52) g(n);
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas',filas));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 IF(SELECT count(*) FROM public.masiva_base_fuente WHERE operacion_id=op)<>58 THEN RAISE EXCEPTION 'Trigger no conservó todas las filas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_base_fuente WHERE operacion_id=op AND datos->>'cargo'='Cargo extra 52'
  AND datos->>'fecha_empaque_programada'='2099-01-01' AND hoja_origen='BASE' AND fila_origen=62)
 THEN RAISE EXCEPTION 'El origen completo no se conservó'; END IF;

 INSERT INTO public.masiva_personal(nombre,creado_por) VALUES('Empacador ficticio',auth.uid()) RETURNING id INTO personal;
 UPDATE public.masiva_kits SET empacador_id=personal WHERE operacion_id=op;
 INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por)
 VALUES('Caja ficticia',1,10,40,30,20,'caja',auth.uid()) RETURNING id INTO empaque;
 INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por)
 VALUES(op,'L1',1,empaque,'{"nombre":"Caja ficticia","tipo":"caja","peso_lleno":10,"largo":40,"ancho":30,"alto":20}',auth.uid()) RETURNING id INTO caja;
 INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por)
 VALUES(op,'L1',2,empaque,'{"nombre":"Bolsa ficticia","tipo":"bolsa","peso_lleno":2,"largo":10,"ancho":10,"alto":10}',auth.uid()) RETURNING id INTO bolsa;
 INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por)
 VALUES(op,'L3',1,empaque,'{"nombre":"Caja vacía","tipo":"caja","peso_lleno":10,"largo":40,"ancho":30,"alto":20}',auth.uid()) RETURNING id INTO caja_vacia;
 UPDATE public.masiva_kits SET caja_id=CASE WHEN cedula='P3' THEN bolsa ELSE caja END WHERE operacion_id=op AND lista='L1';
 UPDATE public.masiva_kits SET caja_id=caja_vacia WHERE operacion_id=op AND lista='L3';
 UPDATE public.masiva_articulos a SET validado=CASE WHEN k.cedula='P2' THEN 1 ELSE a.cantidad END
 FROM public.masiva_kits k WHERE k.id=a.kit_id AND k.operacion_id=op AND k.lista IN('L1','L2');
 INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,esperado,recibido,validado)
 VALUES(op,'Proveedor ficticio','Orden ficticia','X','Prenda X',100,100,6) RETURNING id INTO inv;
 INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,actor_id,creado)
 SELECT op,inv,a.id,'validacion',-a.validado,'13200000-0000-0000-0000-000000000002',
 CASE WHEN a.sku='X' THEN '2026-10-27 04:00:00+00'::timestamptz ELSE '2026-10-27 06:00:00+00'::timestamptz END
 FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=op AND a.validado>0;
 SELECT a.id,k.id INTO art,kit FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id
 WHERE k.operacion_id=op AND k.cedula='P1' AND a.sku='X';
 INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos,creado) VALUES
 (op,kit,'reabrir',auth.uid(),'Ficticio','{"entrada":{"motivo":"Motivo anterior del kit"}}','2026-10-25'),
 (op,kit,'corregir',auth.uid(),'Ficticio',jsonb_build_object('entrada',jsonb_build_object('motivo','Motivo de X','articulo_id',art)),'2026-10-26');

 r:=public.masiva_maestro_consultar(op,'listado','',jsonb_build_object('lista',jsonb_build_array('L1')));
 f:=r->'filas'->0;
 IF r->>'total'<>'1' OR f->>'kits_totales'<>'3' OR f->>'kits_validados'<>'2' OR f->>'kits_empacados'<>'3'
 OR f->>'total_piezas'<>'2' OR f->>'cajas'<>'1' OR f->>'bolsas'<>'1' OR(f->>'peso_total')::numeric<>12
 OR(f->>'volumen')::numeric<>0.025 OR f->>'estado'<>'EMPAQUE PARCIAL' OR f->>'prendas_requeridas'<>'6'
 OR f->>'prendas_validadas'<>'5' THEN RAISE EXCEPTION 'Agregación por lista incorrecta: %',f; END IF;
 IF f->>'fecha_despacho' IS NOT NULL OR f->>'fecha_recepcion' IS NOT NULL OR f->>'placa_guia' IS NOT NULL
 OR f->>'transportadora' IS NOT NULL OR f->>'novedades' IS NOT NULL THEN RAISE EXCEPTION 'Se inventaron datos logísticos'; END IF;
 r:=public.masiva_maestro_consultar(op,'listado','P1');
 IF r->>'total'<>'1' OR r->'filas'->0->>'kits_totales'<>'3' THEN RAISE EXCEPTION 'Buscar persona truncó la lista'; END IF;
 r:=public.masiva_maestro_consultar(op,'listado','', '{"lista":["L2"]}');
 IF r->'filas'->0->>'estado'<>'EMPAQUE PARCIAL' OR r->'filas'->0->>'kits_empacados'<>'0'
 OR r->'filas'->0->>'total_piezas'<>'0' THEN RAISE EXCEPTION 'Kit completo sin caja incorrecto'; END IF;
 r:=public.masiva_maestro_consultar(op,'listado','', '{"lista":["L3"]}');
 IF r->'filas'->0->>'estado'<>'POR EMPACAR' OR r->'filas'->0->>'total_piezas'<>'0' THEN RAISE EXCEPTION 'Caja vacía contó como ocupada'; END IF;

 r:=public.masiva_maestro_consultar(op,'base','', '{"cedula":["P1"],"sku":["X"]}'); f:=r->'filas'->0;
 IF r->>'total'<>'1' OR f->>'sector'<>'Sector A' OR f->>'responsable'<>'Líder A'
 OR f->>'ciudad'<>'Bogotá' OR f->>'motivo_modificacion'<>'Motivo de X'
 OR f->>'validador'<>'Validador ficticio' OR f->>'empacador'<>'Empacador ficticio'
 THEN RAISE EXCEPTION 'Se perdió el renglón original, validador o motivo: %',f; END IF;
 IF r->'opciones'->'sku'<>'["X","Y"]'::jsonb THEN RAISE EXCEPTION 'Faceta no excluye su propio filtro'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','', '{"cedula":["P1"],"sku":["Y"]}');
 IF r->'filas'->0->>'motivo_modificacion'<>'Motivo anterior del kit' THEN RAISE EXCEPTION 'La corrección de X contaminó Y'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','', '{"cedula":["P1"]}',1,30,'fecha_validacion','2026-10-26','2026-10-26');
 IF r->>'total'<>'1' OR r->'filas'->0->>'sku'<>'X' THEN RAISE EXCEPTION 'Rango de fecha real no usa Colombia'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','', '{}',1,30,'fecha_validacion','2099-01-01','2099-01-01');
 IF r->>'total'<>'0' THEN RAISE EXCEPTION 'Fecha programada afectó la consulta'; END IF;
 r:=public.masiva_maestro_consultar(op,'base'); r2:=public.masiva_maestro_consultar(op,'base','', '{}',2,30);
 IF r->>'total'<>'58' OR jsonb_array_length(r->'filas')<>30 OR jsonb_array_length(r2->'filas')<>28
 OR NOT(r->'opciones'->'sede' ? 'Sede extra 52') THEN RAISE EXCEPTION 'Paginación o facetas limitadas a la página'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'filas') x JOIN jsonb_array_elements(r2->'filas') y ON x->>'articulo_id'=y->>'articulo_id')
 THEN RAISE EXCEPTION 'Páginas repiten artículos'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','Cargo extra 52','{}',1,1000,'',NULL,NULL,false);
 IF r->>'total'<>'1' OR r->'filas'->0->>'cargo'<>'Cargo extra 52' OR r->'opciones'<>'{}'::jsonb
 OR(r->'filas'->0 ? 'fecha_empaque_programada') THEN RAISE EXCEPTION 'Exportación o fuente oculta incorrecta'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','', '{}',1,1000,'',NULL,NULL,false);
 IF jsonb_array_length(r->'filas')<>58 OR r->'metricas'->>'kits'<>'57' THEN RAISE EXCEPTION 'Exportación incompleta'; END IF;

 -- Enriquecer solo metadatos: comparación íntegra, replay sin auditoría duplicada.
 original:=filas->0;
 f:=original||jsonb_build_object('fuente',public.masiva_base_original(original)||jsonb_build_object('logistica','Operador ficticio','cargo','Cargo recuperado',
  'prenda','Blusa','items_kit',3,'items_lista',6,'fecha_entrega_programada','2099-02-03'),'fila_origen',2,'hoja_origen','BASE');
 SELECT count(*) INTO previo FROM public.masiva_auditoria WHERE operacion_id=op;
 r:=public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(f));
 r2:=public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(f));
 IF r->>'actualizadas'<>'1' OR r2->>'actualizadas'<>'0' OR(SELECT count(*) FROM public.masiva_auditoria WHERE operacion_id=op)<>previo+1
 THEN RAISE EXCEPTION 'Enriquecimiento no idempotente'; END IF;
 IF EXISTS(SELECT 1 FROM public.masiva_auditoria WHERE operacion_id=op AND accion='enriquecer_base' AND datos::text LIKE '%Persona%')
 THEN RAISE EXCEPTION 'Auditoría contiene datos personales de la fuente'; END IF;
 r:=public.masiva_maestro_consultar(op,'base','', '{"cargo":["Cargo recuperado"]}');
 IF r->>'total'<>'1' OR r->'filas'->0->>'prenda'<>'Blusa' THEN RAISE EXCEPTION 'Fuente enriquecida no visible'; END IF;
 FOR n IN 1..4 LOOP
  error:=false;
  BEGIN
   IF n=1 THEN PERFORM public.masiva_enriquecer_base(op,'otro.xlsx',jsonb_build_array(f));
   ELSIF n=2 THEN PERFORM public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(jsonb_set(f,'{nombre}','"Nombre distinto"')));
   ELSIF n=3 THEN PERFORM public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(jsonb_set(f,'{fuente,cargo}','"Cargo diferente"')));
   ELSE PERFORM public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(f,f)); END IF;
  EXCEPTION WHEN OTHERS THEN error:=true; END;
  IF NOT error THEN RAISE EXCEPTION 'Enriquecimiento inválido aceptado: %',n; END IF;
 END LOOP;
 -- Una fila válida seguida de otra incompatible revierte el lote completo.
 f:=(filas->1)||jsonb_build_object('fuente',jsonb_build_object('cargo','No debe persistir'));
 error:=false;
 BEGIN PERFORM public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(f,jsonb_set(f,'{sku}','"INEXISTENTE"')));
 EXCEPTION WHEN OTHERS THEN error:=true; END;
 IF NOT error OR EXISTS(SELECT 1 FROM public.masiva_base_fuente WHERE operacion_id=op AND datos->>'cargo'='No debe persistir')
 THEN RAISE EXCEPTION 'Enriquecimiento parcial no se revirtió'; END IF;

 -- Una fuente manipulada no puede confirmar la importación operativa.
 op_mala:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Fuente incorrecta","cliente":"Ficticio"}')->>'id')::uuid;
 imp_mala:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op_mala,'tipo','personal','archivo','mala.xlsx','total_filas',1,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp_mala,'indice',0,
  'filas',jsonb_build_array(original||jsonb_build_object('fuente',jsonb_build_object('cantidad',999)))));
 error:=false; BEGIN PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp_mala));
 EXCEPTION WHEN OTHERS THEN error:=true; END;
 IF NOT error OR EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=op_mala)
 OR(SELECT estado FROM public.masiva_importaciones WHERE id=imp_mala)<>'cargando' THEN RAISE EXCEPTION 'Importación inválida dejó cambios'; END IF;

 FOR n IN 1..5 LOOP
  error:=false; BEGIN
   IF n=1 THEN PERFORM public.masiva_maestro_consultar(op,'base','', '{"NO_EXISTE":["a"]}');
   ELSIF n=2 THEN PERFORM public.masiva_maestro_consultar(op,'base','', '{"ciudad":[7]}');
   ELSIF n=3 THEN PERFORM public.masiva_maestro_consultar(op,'base','', '{}',1,300);
   ELSIF n=4 THEN PERFORM public.masiva_maestro_consultar(op,'base','', '{}',1,30,'fecha_empaque_programada');
   ELSE PERFORM public.masiva_maestro_consultar(op,'base','', '{}',1,30,'fecha_carga','2026-10-28','2026-10-27'); END IF;
  EXCEPTION WHEN OTHERS THEN error:=true; END;
  IF NOT error THEN RAISE EXCEPTION 'Consulta inválida aceptada: %',n; END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub','13200000-0000-0000-0000-000000000002',true);
 r:=public.masiva_maestro_consultar(op,'base');
 error:=false; BEGIN PERFORM public.masiva_enriquecer_base(op,'maestro-ficticio.xlsx',jsonb_build_array(f));
 EXCEPTION WHEN insufficient_privilege THEN error:=true; END;
 IF NOT error THEN RAISE EXCEPTION 'Masiva no administrador pudo enriquecer'; END IF;
 FOR n IN 3..5 LOOP
  PERFORM set_config('request.jwt.claim.sub',CASE WHEN n=5 THEN '' ELSE '13200000-0000-0000-0000-00000000000'||n END,true);
  error:=false; BEGIN PERFORM public.masiva_maestro_consultar(op,'base'); EXCEPTION WHEN insufficient_privilege THEN error:=true; END;
  IF NOT error THEN RAISE EXCEPTION 'Acceso no autorizado al maestro: %',n; END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub','13200000-0000-0000-0000-000000000001',true);
 UPDATE public.masiva_operaciones SET estado='cerrada' WHERE id=op;
 r:=public.masiva_maestro_consultar(op,'base');
 IF r->>'total'<>'58' THEN RAISE EXCEPTION 'Operación archivada no consultable'; END IF;
 IF has_table_privilege('authenticated','public.masiva_base_fuente','UPDATE') OR has_table_privilege('authenticated','public.masiva_base_fuente','SELECT')
 OR has_function_privilege('authenticated','public.masiva_base_conservar(uuid)','EXECUTE')
 OR has_function_privilege('anon','public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)','EXECUTE')
 THEN RAISE EXCEPTION 'Permisos directos incorrectos'; END IF;
 SELECT md5(jsonb_agg(to_jsonb(a) ORDER BY a.id)::text) INTO huella FROM public.masiva_articulos a;
 PERFORM public.masiva_maestro_consultar(op,'base'); PERFORM public.masiva_maestro_consultar(op,'listado');
 SELECT md5(jsonb_agg(to_jsonb(a) ORDER BY a.id)::text) INTO posterior FROM public.masiva_articulos a;
 IF huella<>posterior THEN RAISE EXCEPTION 'La consulta cambió cantidades'; END IF;
 RAISE NOTICE '132: agregados, fuente original, filtros globales, exportación, fechas, atomicidad, auditoría y permisos verificados';
END $$;
ROLLBACK;
