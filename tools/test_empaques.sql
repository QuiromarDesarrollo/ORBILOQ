-- Solo servidor local del ensayo; no ejecutar en Supabase.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000001','admin@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email,activo)
 VALUES('10000000-0000-0000-0000-000000000001','ADMIN TEST','admin','00000000-0000-0000-0000-000000000001','900','admin@local',true);
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES
 ('recepcion','0701856a-7771-4536-9762-658a58af8803',20,'40000000-0000-0000-0000-000000000001');
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE e jsonb; b jsonb; empaques jsonb; lineas jsonb; r jsonb; antes jsonb; rechazada boolean;
BEGIN
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja test","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 b:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Bolsa test","categoria":"BOLSA","largo_cm":25,"ancho_cm":15,"alto_cm":5,"peso_neto_kg":0.05,"peso_bruto_kg":1,"activo":true}');
 empaques:=jsonb_build_array(jsonb_build_object('empaque_id',e->>'id','cantidad',2,'version',md5(e::text)),
   jsonb_build_object('empaque_id',b->>'id','cantidad',1,'version',md5(b::text)));
 lineas:=jsonb_build_array(jsonb_build_object('item_id','0701856a-7771-4536-9762-658a58af8803','ubicacion','TEST-A','cantidad',5));
 rechazada:=false;
 BEGIN PERFORM public.despachar_oc_empaques('sin-empaque','TEST','TEST-OC',lineas,'[]');
 EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepto despacho sin empaque'; END IF;
 r:=public.despachar_oc_empaques('test-1','TEST','TEST-OC',lineas,empaques);
 antes:=public.historial_despachos_empaques();
 IF jsonb_array_length(antes)<>1 OR jsonb_array_length(antes->0->'empaques')<>2 THEN RAISE EXCEPTION 'No guardo empaques'; END IF;
 PERFORM public.admin_empaque_guardar((e->>'id')::uuid,md5(e::text),e||'{"activo":false,"nombre":"Caja modificada","largo_cm":50}');
 r:=public.despachar_oc_empaques('test-1','TEST','TEST-OC',lineas,empaques);
 IF r->>'repetido'<>'true' OR public.historial_despachos_empaques()<>antes THEN RAISE EXCEPTION 'Reintento o edicion altero el historico'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.despachar_oc_empaques('test-1','TEST','TEST-OC',lineas,jsonb_set(empaques,'{0,cantidad}','3'));
 EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepto cambiar reintento'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.despachar_oc_empaques('test-2','TEST','TEST-OC',lineas,empaques);
 EXCEPTION WHEN raise_exception THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Acepto empaque inactivo'; END IF;
 IF jsonb_array_length(public.historial_despachos_empaques())<>1 THEN RAISE EXCEPTION 'Fallo atomicidad'; END IF;
 -- Acceso sin identidad debe fallar incluso al invocar directamente las RPC.
 PERFORM set_config('request.jwt.claim.sub','',true);
 rechazada:=false;
 BEGIN PERFORM public.empaques_listar(); EXCEPTION WHEN insufficient_privilege THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Lectura sin cuenta'; END IF;
 rechazada:=false;
 BEGIN PERFORM public.admin_empaque_guardar(NULL,NULL,e); EXCEPTION WHEN insufficient_privilege THEN rechazada:=true; END;
 IF NOT rechazada THEN RAISE EXCEPTION 'Escritura sin cuenta'; END IF;
END $$;
ROLLBACK;
