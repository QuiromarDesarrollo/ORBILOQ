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
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000002','seguimiento@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email,activo)
VALUES('10000000-0000-0000-0000-000000000002','SEGUIMIENTO','seguimiento','00000000-0000-0000-0000-000000000002','901','seguimiento@local',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE e jsonb; packs jsonb; lines jsonb; r jsonb; ctx jsonb; doc jsonb; destino uuid; rechazo boolean; corregido jsonb;
BEGIN
 PERFORM public.le_configurar(2971);
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja test","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 PERFORM public.le_importar_clientes('[{"nombre":"DESTINO TEST","nit":"123","direccion":"CALLE 1","sede":"CENTRO"}]');
 destino:=(public.le_clientes()->0->>'id')::uuid;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Seguimiento sin acceso'; END IF;
 IF NOT public.wms_cuenta_operativa() THEN RAISE EXCEPTION 'Seguimiento sin permisos operativos'; END IF;
 PERFORM public.empaques_listar(false);
 packs:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',6,'version',md5(e::text)));
 lines:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":6}]';
 r:=public.despachar_oc_bultos('seguimiento-test','TEST','TEST-OC',lines,packs);
 PERFORM public.despachar_oc_bultos('seguimiento-test','TEST','TEST-OC',lines,packs);
 IF (SELECT sum(cantidad) FROM public.reservas_despacho)<>6 THEN RAISE EXCEPTION 'Reserva incorrecta'; END IF;
 IF public.historial_despachos_empaques()->0->>'fase'<>'empacado' THEN RAISE EXCEPTION 'Historial sin fase'; END IF;
 IF public.historial_despachos_empaques()->0->>'le_numero'<>'2971' THEN RAISE EXCEPTION 'LE no asignada al empacar'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.despachar_oc_bultos('doble-reserva','TEST','TEST-OC',lines,packs); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Permitio doble reserva'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.le_documento('seguimiento-test',destino,'{}',true); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Emitio sin confirmar salida'; END IF;
 -- Corregir mientras solo está empacado, sin descontar inventario.
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 lines:=jsonb_set(lines,'{0,cantidad}','5'); packs:=jsonb_set(packs,'{0,cantidad}','5');
 corregido:=public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','edicion-1','Cantidad','TEST','TEST-OC',lines,packs);
 IF corregido->>'ediciones'<>'1' OR corregido->>'le_numero'<>'2971' THEN RAISE EXCEPTION 'Perdio LE o contador'; END IF;
 IF public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','edicion-1','Cantidad','TEST','TEST-OC',lines,packs)<>corregido THEN RAISE EXCEPTION 'Correccion no idempotente'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.seguimiento_confirmar((r->>'id')::uuid,0,destino); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Acepto revision obsoleta'; END IF;
 doc:=public.seguimiento_confirmar((r->>'id')::uuid,1,destino,'{"factura":"F-1"}');
 IF doc->>'numero'<>'2971' OR doc->>'factura'<>'F-1' THEN RAISE EXCEPTION 'Documento incorrecto'; END IF;
 IF public.seguimiento_confirmar((r->>'id')::uuid,1,destino)<>doc THEN RAISE EXCEPTION 'Confirmacion no idempotente'; END IF;
 IF EXISTS(SELECT 1 FROM public.reservas_despacho) THEN RAISE EXCEPTION 'Reserva retenida despues de salida'; END IF;
 IF public.historial_despachos_empaques()->0->>'fase'<>'despachado' THEN RAISE EXCEPTION 'No paso a historial'; END IF;
 -- Corregir uno finalizado debe regresar a Seguimiento y reservar el nuevo empaque.
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 rechazo:=false;
 BEGIN PERFORM public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','invalida','Cantidad','TEST','TEST-OC',jsonb_set(lines,'{0,cantidad}','99'),jsonb_set(packs,'{0,cantidad}','99')); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo OR ctx<>public.despacho_para_corregir((r->>'id')::uuid) THEN RAISE EXCEPTION 'Correccion fallida no atomica'; END IF;
 lines:=jsonb_set(lines,'{0,cantidad}','4'); packs:=jsonb_set(packs,'{0,cantidad}','4');
 PERFORM public.corregir_despacho_le((r->>'id')::uuid,ctx->>'version','edicion-2','Cantidad','TEST','TEST-OC',lines,packs);
 IF (SELECT sum(cantidad) FROM public.reservas_despacho)<>4 THEN RAISE EXCEPTION 'No reservo correccion'; END IF;
 IF public.le_documento('seguimiento-test')->>'fase'<>'empacado' THEN RAISE EXCEPTION 'No volvio a Seguimiento'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 rechazo:=false;
 BEGIN PERFORM public.seguimiento_confirmar((r->>'id')::uuid,2,destino); EXCEPTION WHEN insufficient_privilege THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Confirmacion sin identidad'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
END $$;
RESET ROLE;
DO $$ DECLARE rechazo boolean:=false; BEGIN
 IF (SELECT coalesce(sum(cantidad),0) FROM public.movimientos WHERE tipo='despacho')<>0 THEN RAISE EXCEPTION 'Empacado desconto inventario'; END IF;
 IF (SELECT siguiente FROM public.lista_empaque_config WHERE id=true)<>2972 THEN RAISE EXCEPTION 'Consumio multiples LE'; END IF;
 BEGIN UPDATE public.movimientos SET cantidad=1 WHERE tipo='recepcion' AND item_orden_id='0701856a-7771-4536-9762-658a58af8803'; EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Ajuste consumio reserva'; END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE id uuid; destino uuid; BEGIN
 id:=(public.historial_despachos_empaques()->0->>'despacho_oc_id')::uuid;
 destino:=(public.le_clientes()->0->>'id')::uuid;
 PERFORM public.seguimiento_confirmar(id,2,destino);
 PERFORM public.seguimiento_confirmar(id,2,destino);
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT sum(cantidad) FROM public.movimientos WHERE tipo='despacho')<>4 THEN RAISE EXCEPTION 'Doble descuento'; END IF;
 IF (SELECT count(*) FROM public.despacho_revisiones)<>2 THEN RAISE EXCEPTION 'Auditoria incorrecta'; END IF;
 IF EXISTS(SELECT 1 FROM public.reservas_despacho) THEN RAISE EXCEPTION 'Reserva sobrante'; END IF;
 IF has_function_privilege('authenticated','public.despachar_oc_bultos_base_v81(text,text,text,jsonb,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Bypass habilitado'; END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE ctx jsonb; id uuid; e jsonb; packs jsonb; lines jsonb; destino uuid; doc jsonb; BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 id:=(public.historial_despachos_empaques()->0->>'despacho_oc_id')::uuid;
 ctx:=public.despacho_para_corregir(id);
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Empaque nuevo","categoria":"BOLSA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 lines:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":4}]';
 packs:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',1,'version',md5(e::text)),jsonb_build_object('numero',2,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',3,'version',md5(e::text)));
 PERFORM public.corregir_despacho_le(id,ctx->>'version','redistribucion','Cambio de tipo y distribucion sin cambiar total','TEST','TEST-OC',lines,packs);
 IF public.historial_despachos_empaques()->0->>'ediciones'<>'3' THEN RAISE EXCEPTION 'No acepto cambio sin diferencia en total'; END IF;
 PERFORM public.le_importar_clientes('[{"nombre":"OTRO DESTINATARIO","direccion":"CALLE 2","sede":"NORTE"}]');
 SELECT (x->>'id')::uuid INTO destino FROM jsonb_array_elements(public.le_clientes()) x WHERE x->'datos'->>'nombre'='OTRO DESTINATARIO';
 doc:=public.seguimiento_confirmar(id,3,destino);
 IF doc->>'numero'<>'2971' THEN RAISE EXCEPTION 'Perdio LE al cambiar destinatario'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
