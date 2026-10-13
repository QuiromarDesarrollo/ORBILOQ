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
DO $$ DECLARE e jsonb; packs jsonb; lines jsonb; d jsonb; otro uuid; r jsonb; ctx jsonb; doc jsonb; rechazo boolean;
BEGIN
 PERFORM public.le_configurar(2971);
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja test","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 PERFORM public.le_importar_clientes('[{"nombre":"DESTINO A","direccion":"CALLE 1","ciudad":"Bogotá"},{"nombre":"DESTINO B","direccion":"CALLE 2"}]');
 d:=public.destinatarios_para_empaque()->0;
 otro:=(public.destinatarios_para_empaque()->1->>'id')::uuid;
 packs:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',6,'version',md5(e::text)));
 lines:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":6}]';
 rechazo:=false;
 BEGIN PERFORM public.guardar_empaque_destinatario_v90('nulo','TEST','TEST-OC',lines,packs,NULL,NULL); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Acepto sin destinatario'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.guardar_empaque_destinatario_v90('viejo','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,'viejo'); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Acepto version vieja'; END IF;
 r:=public.guardar_empaque_destinatario_v90('destino-test','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,d->>'version',NULL,NULL,NULL,' OC-DOCUMENTO ');
 IF public.guardar_empaque_destinatario_v90('destino-test','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,d->>'version',NULL,NULL,NULL,' OC-DOCUMENTO ')<>r THEN RAISE EXCEPTION 'No idempotente'; END IF;

 IF (SELECT oc FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803')<>'TEST-OC' THEN RAISE EXCEPTION 'Cambio OC del kardex'; END IF;
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 IF ctx->>'oc'<>'TEST-OC' OR ctx->>'oc_documento'<>'OC-DOCUMENTO' THEN RAISE EXCEPTION 'No separo las OC %',ctx; END IF;
 IF public.historial_despachos_empaques()->0->>'oc_documento'<>'OC-DOCUMENTO' THEN RAISE EXCEPTION 'Historial sin OC ajustada'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.admin_trazabilidad_op('')) x WHERE x->>'oc_documento'='OC-DOCUMENTO' AND x->>'oc'='TEST-OC') THEN RAISE EXCEPTION 'Excel sin OC separada'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.guardar_empaque_destinatario_v90('destino-test','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,d->>'version',NULL,NULL,NULL,'OTRA'); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Reintento cambio OC'; END IF;
 doc:=public.le_documento('destino-test');
 IF doc->>'oc'<>'OC-DOCUMENTO' THEN RAISE EXCEPTION 'Vista previa sin OC'; END IF;
 IF doc->'destinatario_empaque' IS DISTINCT FROM d->'datos' THEN RAISE EXCEPTION 'No guardo destinatario %',doc; END IF;
 rechazo:=false;
 BEGIN PERFORM public.seguimiento_confirmar((r->>'id')::uuid,0,otro); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo OR (SELECT sum(cantidad) FROM public.reservas_despacho)<>6 THEN RAISE EXCEPTION 'Cambio destino sin corregir'; END IF;
 doc:=public.seguimiento_confirmar((r->>'id')::uuid,0,(d->>'id')::uuid);
 IF doc->>'oc'<>'OC-DOCUMENTO' THEN RAISE EXCEPTION 'LE sin OC del despacho %',doc; END IF;
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 d:=public.destinatarios_para_empaque()->1;
 doc:=public.guardar_empaque_destinatario_v90('destino-edicion','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,d->>'version',(r->>'id')::uuid,ctx->>'version','Cambio destinatario');
 IF doc->>'ediciones'<>'1' OR doc->>'le_numero'<>'2971' THEN RAISE EXCEPTION 'No conservo LE/ediciones %',doc; END IF;
 IF public.le_documento('destino-test')->'destinatario_empaque' IS DISTINCT FROM d->'datos' THEN RAISE EXCEPTION 'No cambio destinatario'; END IF;
 IF public.guardar_empaque_destinatario_v90('destino-edicion','TEST','TEST-OC',lines,packs,(d->>'id')::uuid,d->>'version',(r->>'id')::uuid,ctx->>'version','Cambio destinatario')<>doc THEN RAISE EXCEPTION 'Correccion no idempotente'; END IF;
 IF public.le_documento('destino-test')->>'oc'<>'TEST-OC' THEN RAISE EXCEPTION 'No restauro OC original al dejar vacio'; END IF;
 IF (public.despacho_para_corregir((r->>'id')::uuid))->>'oc_documento' IS NOT NULL THEN RAISE EXCEPTION 'Override no borrado'; END IF;
 IF has_function_privilege('authenticated','public.despachar_oc_bultos(text,text,text,jsonb,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Bypass habilitado'; END IF;
END $$;
-- Simula dos días entre el empaque y la salida; solo dentro de este ensayo.
RESET ROLE;
UPDATE public.despachos_oc SET fecha=now()-interval '2 days' WHERE solicitud='destino-test';
SET LOCAL ROLE authenticated;
DO $$ DECLARE ctx jsonb; doc jsonb; destino uuid; BEGIN
 ctx:=public.despacho_para_corregir((public.historial_despachos_empaques()->0->>'despacho_oc_id')::uuid);
 destino:=(ctx->>'destinatario_id')::uuid;
 doc:=public.seguimiento_confirmar((ctx->>'id')::uuid,1,destino);
 IF (doc->>'fecha')::timestamptz IS DISTINCT FROM now() THEN RAISE EXCEPTION 'La fecha de despacho no es la de liberación'; END IF;
 IF doc->>'oc'<>'TEST-OC' THEN RAISE EXCEPTION 'LE no conserva OC original'; END IF;
 IF public.seguimiento_confirmar((ctx->>'id')::uuid,1,destino) IS DISTINCT FROM doc THEN RAISE EXCEPTION 'Reimpresión altera documento o fecha'; END IF;
 IF has_function_privilege('anon','public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)','EXECUTE') THEN RAISE EXCEPTION 'Permiso anónimo indebido'; END IF;
END $$;
ROLLBACK;
