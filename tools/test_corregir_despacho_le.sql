-- Solo servidor local del ensayo; no ejecutar en Supabase.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000001','admin@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email,activo)
 VALUES('10000000-0000-0000-0000-000000000001','ADMIN TEST','admin','00000000-0000-0000-0000-000000000001','900','admin@local',true);
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES
 ('recepcion','0701856a-7771-4536-9762-658a58af8803',10,'40000000-0000-0000-0000-000000000001');
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc) VALUES('0701856a-7771-4536-9762-658a58af8804','20000000-0000-0000-0000-000000000001','DEMO-001','TEST','L',20,'TEST-OC');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES('recepcion','0701856a-7771-4536-9762-658a58af8804',4,'40000000-0000-0000-0000-000000000001');
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE e jsonb; packs jsonb; lines jsonb; r jsonb; doc jsonb; destino uuid; rechazada boolean; ctx jsonb; corregido jsonb;
BEGIN
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja test","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 packs:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',2,'version',md5(e::text)),jsonb_build_object('numero',2,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',3,'version',md5(e::text)));
 lines:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":5}]';
 packs:=packs||jsonb_build_array(jsonb_set(jsonb_set(packs->0,'{item_id}','"0701856a-7771-4536-9762-658a58af8804"'),'{cantidad}','1'));
 lines:=lines||'[{"item_id":"0701856a-7771-4536-9762-658a58af8804","ubicacion":"TEST-A","cantidad":1}]';
 r:=public.despachar_oc_bultos('lista-test','TEST','TEST-OC',lines,packs);
 IF r->'empaques'->0->>'numero'<>'1' OR r->'empaques'->1->>'numero'<>'2' THEN RAISE EXCEPTION 'Numeracion ausente'; END IF;
 PERFORM public.despachar_oc_bultos('lista-test','TEST','TEST-OC',lines,packs);
 IF jsonb_array_length(public.historial_despachos_empaques())<>2 THEN RAISE EXCEPTION 'Duplico despacho'; END IF;
 PERFORM public.le_importar_clientes('[{"nombre":"CLIENTE TEST","nit":"123","direccion":"SEDE A","ciudad":"BOGOTA","contacto":"ANA","telefono":"","celular":""}]');
 destino:=(public.le_clientes()->0->>'id')::uuid;
 rechazada:=false;
 BEGIN PERFORM public.le_documento('lista-test',destino,'{}',true); EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Invento consecutivo'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.despachar_oc_bultos('exceso','TEST','TEST-OC',jsonb_set(lines,'{0,cantidad}','8'),jsonb_set(packs,'{0,cantidad}','5')); EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepto exceso de stock'; END IF;
 PERFORM public.le_configurar(2971);
 doc:=public.le_documento('lista-test',destino,'{}',true);
 IF doc->>'numero'<>'2971' OR doc->>'remision'<>'' OR doc->>'factura'<>'' OR doc->>'id_oc'<>'' THEN RAISE EXCEPTION 'Opcionales o consecutivo incorrectos'; END IF;
 PERFORM public.le_importar_clientes('[{"nombre":"CLIENTE TEST","nit":"123","direccion":"SEDE A","ciudad":"BOGOTA","contacto":"OTRO","telefono":"","celular":""}]');
 IF jsonb_array_length(public.le_clientes())<>2 THEN RAISE EXCEPTION 'Combino contactos distintos'; END IF;
 IF public.le_documento('lista-test',destino,'{"factura":"MODIFICAR"}',true)<>doc THEN RAISE EXCEPTION 'Alteracion de documento emitido'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.le_configurar(2971); EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Consecutivo repetido'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.despachar_oc_bultos('lista-duplicada','TEST','TEST-OC',lines,jsonb_set(packs,'{1,numero}','1')); EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepta duplicado talla por empaque'; END IF;
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 -- Abrir no cambia inventario ni documento.
 IF public.le_documento('lista-test')<>doc THEN RAISE EXCEPTION 'Abrir altero el PDF'; END IF;
 -- Una corrección inválida revierte también la devolución.
 rechazada:=false;
 BEGIN
  PERFORM public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','correccion-mala','Prueba','TEST','TEST-OC',jsonb_set(lines,'{0,cantidad}','99'),jsonb_set(packs,'{0,cantidad}','96'));
 EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada OR public.despacho_para_corregir((r->>'id')::uuid)<>ctx THEN RAISE EXCEPTION 'Fallo no atomico'; END IF;
 -- Reducir M de 5 a 4 y conservar L=1.
 lines:=jsonb_set(lines,'{0,cantidad}','4');
 packs:=jsonb_set(packs,'{0,cantidad}','1');
 corregido:=public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','correccion-1','Error digitacion','TEST','TEST-OC',lines,packs);
 IF corregido->>'ediciones'<>'1' OR corregido->>'le_numero'<>'2971' THEN RAISE EXCEPTION 'Revision o LE incorrecta'; END IF;
 IF public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','correccion-1','Error digitacion','TEST','TEST-OC',lines,packs)<>corregido THEN RAISE EXCEPTION 'Reintento no idempotente'; END IF;
 IF public.le_documento('lista-test')->>'pendiente'<>'true' THEN RAISE EXCEPTION 'PDF anterior sigue vigente'; END IF;
 doc:=public.le_documento('lista-test',destino,'{"factura":"NUEVA"}',true);
 IF doc->>'numero'<>'2971' OR doc->>'factura'<>'NUEVA' THEN RAISE EXCEPTION 'No reemitio LE'; END IF;
 IF jsonb_array_length(public.historial_despachos_empaques())<>2 OR public.historial_despachos_empaques()->0->>'ediciones'<>'1' THEN RAISE EXCEPTION 'Historial duplicado'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','obsoleta','Prueba','TEST','TEST-OC',lines,packs);
 EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepto version obsoleta'; END IF;
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 corregido:=public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','correccion-2','Segundo ajuste','TEST','TEST-OC',lines,packs);
 IF corregido->>'ediciones'<>'2' THEN RAISE EXCEPTION 'No incremento contador'; END IF;
 doc:=public.le_documento('lista-test',destino,'{}',true);
 IF doc->>'numero'<>'2971' THEN RAISE EXCEPTION 'Cambio LE'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 rechazada:=false;
 BEGIN PERFORM public.le_clientes(); EXCEPTION WHEN insufficient_privilege THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acceso sin identidad'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.despacho_para_corregir((r->>'id')::uuid); EXCEPTION WHEN insufficient_privilege THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Lectura de correccion sin identidad'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','sin-acceso','Prueba','TEST','TEST-OC',lines,packs); EXCEPTION WHEN insufficient_privilege THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Correccion sin identidad'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT siguiente FROM public.lista_empaque_config WHERE id=true)<>2972 THEN RAISE EXCEPTION 'Consumio consecutivo'; END IF;
 IF (SELECT count(*) FROM public.despacho_revisiones)<>2 THEN RAISE EXCEPTION 'Duplico correcciones'; END IF;
 IF (SELECT sum(cantidad) FROM public.movimientos WHERE tipo='despacho')<>5 THEN RAISE EXCEPTION 'Descuento incorrecto'; END IF;
 IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE documento_anterior IS NULL) THEN RAISE EXCEPTION 'Perdio historial PDF'; END IF;
 IF (SELECT count(*) FROM public.despachos_oc)<>1 THEN RAISE EXCEPTION 'Duplico despacho'; END IF;
END $$;
ROLLBACK;


