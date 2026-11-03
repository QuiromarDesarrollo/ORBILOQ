-- PostgreSQL local/DEV con migraciones 129 a 139. Solo datos ficticios.
BEGIN;
INSERT INTO auth.users(id) VALUES('13900000-0000-0000-0000-000000000001');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo)
VALUES('13900000-0000-0000-0000-000000000001','MASIVA-139','Usuario ficticio','admin',ARRAY['admin','masiva'],true);
SELECT set_config('request.jwt.claim.sub','13900000-0000-0000-0000-000000000001',true);
DO $$
DECLARE op uuid; empaque uuid; doc uuid; docs integer; maestro jsonb; fecha timestamptz;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion',
  '{"nombre":"Impresiones ficticias","cliente":"Cliente ficticio"}') ->> 'id')::uuid;
 INSERT INTO public.masiva_listas(operacion_id,lista,ciudad,sede)
 VALUES(op,'L1','Bogotá','Sede ficticia'),(op,'L2','Cali','Otra sede ficticia');
 INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,creado_por)
 VALUES('Caja ficticia',0.5,10,40,30,20,auth.uid()) RETURNING id INTO empaque;
 INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por)
 VALUES(op,'L1',1,empaque,'{"nombre":"Caja ficticia","tipo":"caja","peso_lleno":10}',auth.uid()),
       (op,'L2',1,empaque,'{"nombre":"Caja ficticia","tipo":"caja","peso_lleno":10}',auth.uid());
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre,estado,caja_id)
 SELECT op,l.lista,1,'DOC-'||l.lista,'Persona ficticia','validado',c.id
 FROM public.masiva_listas l JOIN public.masiva_cajas c USING(operacion_id,lista)
 WHERE l.operacion_id=op;
 INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad,validado)
 SELECT k.id,'SKU-'||k.lista,'Prenda ficticia',1,1 FROM public.masiva_kits k WHERE k.operacion_id=op;

 doc:=(public.masiva_ejecutar('documento',jsonb_build_object(
  'operacion_id',op,'lista','L1','tipo','lista'))->>'id')::uuid;
 SELECT fecha_generado INTO fecha FROM public.masiva_listas WHERE operacion_id=op AND lista='L1';
 IF fecha IS NULL THEN RAISE EXCEPTION 'Generar lista no actualizó fecha_generado'; END IF;

 PERFORM public.masiva_ejecutar('registrar_impresion',jsonb_build_object(
  'operacion_id',op,'documento_id',doc,'lista','L1'));
 SELECT fecha_generado INTO fecha FROM public.masiva_listas WHERE operacion_id=op AND lista='L1';
 SELECT count(*) INTO docs FROM public.masiva_documentos WHERE operacion_id=op AND lista='L1' AND tipo='lista';
 IF fecha IS NULL OR docs<>1 THEN RAISE EXCEPTION 'Reimpresión cambió la fecha o duplicó el documento'; END IF;

 PERFORM public.masiva_ejecutar('documento',jsonb_build_object(
  'operacion_id',op,'lista','L2','tipo','lista'));
 maestro:=public.masiva_maestro_consultar(op,'listado');
 IF maestro->'filas'->0->>'fecha_generado' IS NULL
  OR maestro->'filas'->1->>'fecha_generado' IS NULL THEN
  RAISE EXCEPTION 'Listado maestro no expuso fecha_generado para cada lista';
 END IF;

 PERFORM public.masiva_ejecutar('cerrar_operacion',jsonb_build_object(
  'operacion_id',op,'motivo','Cierre de prueba'));
 PERFORM public.masiva_ejecutar('registrar_impresion',jsonb_build_object(
  'operacion_id',op,'documento_id',doc,'lista','L1'));
 RAISE NOTICE '139: fecha por lista, historial individual, reimpresión sin nueva versión y reimpresión de operación cerrada verificados';
END $$;
ROLLBACK;
