-- Solo ensayo local. Todos los datos creados se revierten.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) SELECT ('94000000-0000-0000-0000-00000000000'||n)::uuid,('940'||n)||'@orbiloq.local' FROM generate_series(1,4)n;
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email)
 SELECT 'MULTI '||n,r,('94000000-0000-0000-0000-00000000000'||n)::uuid,'940'||n,'940'||n||'@orbiloq.local'
 FROM (VALUES(1,'admin'),(2,'despacho'),(3,'logistica'))x(n,r);
GRANT USAGE ON SCHEMA auth TO authenticated;
CREATE FUNCTION pg_temp.rechaza(q text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE q; EXCEPTION WHEN insufficient_privilege OR raise_exception OR check_violation THEN RETURN; END;
 RAISE EXCEPTION 'Operacion prohibida aceptada: %',q;
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE fila jsonb; actualizado jsonb; usuario uuid;
BEGIN
 SELECT to_jsonb(u) INTO fila FROM public.usuarios u WHERE numero_usuario='9402'; usuario:=(fila->>'id')::uuid;
 actualizado:=public.admin_usuario_guardar_roles(usuario,'MULTI 2',ARRAY['despacho','seguimiento'],true,md5(fila::text));
 IF actualizado->'roles'<>'["seguimiento","despacho"]'::jsonb THEN RAISE EXCEPTION 'No guardo ambos perfiles'; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.admin_usuario_guardar_roles(%L,%L,ARRAY[''admin''],true,%L)',usuario,'Viejo',md5(fila::text)));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_usuario_guardar_roles(%L,%L,ARRAY[]::text[],true,%L)',usuario,'Vacio',md5(actualizado::text)));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_usuario_guardar_roles(%L,%L,ARRAY[''root''],true,%L)',usuario,'Invalido',md5(actualizado::text)));
 -- Endpoint antiguo conserva todos los perfiles al cambiar nombre.
 actualizado:=public.admin_usuario_guardar(usuario,'MULTI DOS','seguimiento',true,md5(actualizado::text));
 IF jsonb_array_length(actualizado->'roles')<>2 THEN RAISE EXCEPTION 'Cliente antiguo perdio perfiles'; END IF;
 SELECT to_jsonb(u) INTO fila FROM public.usuarios u WHERE numero_usuario='9403';
 PERFORM public.admin_usuario_guardar_roles((fila->>'id')::uuid,'DOS AREAS',ARRAY['produccion','logistica','gerencia'],true,md5(fila::text));
END $$;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 IF NOT public.le_acceso() OR NOT public.seguimiento_acceso() OR public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso incorrecto Despacho + Seguimiento'; END IF;
 PERFORM pg_temp.rechaza('SELECT public.admin_usuario_guardar_roles(NULL,''Escalada'',ARRAY[''admin''],true,NULL)');
 PERFORM pg_temp.rechaza('UPDATE public.usuarios SET roles=ARRAY[''admin''],rol=''admin''');
 PERFORM pg_temp.rechaza('SELECT public.crear_lote(''[]'',''TEST'')');
 PERFORM pg_temp.rechaza('SELECT public.recibir_lote_item(NULL,1,NULL,'''')');
 PERFORM pg_temp.rechaza('SELECT public.admin_usuario_registrar_roles(NULL,NULL,''1'',''TEST'',ARRAY[''admin''])');
END $$;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000003',true);
DO $$ DECLARE li uuid; estante uuid; BEGIN
 IF NOT public.wms_cuenta_operativa() OR NOT public.puede_ver_dashboards() OR public.le_acceso() THEN RAISE EXCEPTION 'Acceso incorrecto Produccion + Bodega + Gerencia'; END IF;
 PERFORM public.crear_lote('[{"item_orden_id":"0701856a-7771-4536-9762-658a58af8803","cantidad":1}]','MULTIPERFIL','TEST-094');
 SELECT l.id INTO STRICT li FROM public.lote_items l JOIN public.lotes p ON p.id=l.lote_id WHERE p.numero='TEST-094';
 SELECT id INTO estante FROM public.ubicaciones WHERE activa LIMIT 1;
 PERFORM public.recibir_lote_item(li,1,estante,'','MULTIPERFIL');
END $$;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE fila jsonb; BEGIN
 SELECT to_jsonb(u) INTO fila FROM public.usuarios u WHERE numero_usuario='9402';
 PERFORM public.admin_usuario_guardar_roles((fila->>'id')::uuid,'MULTI 2',ARRAY['despacho'],true,md5(fila::text));
END $$;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN IF public.seguimiento_acceso() OR NOT public.le_acceso() THEN RAISE EXCEPTION 'Revocacion de Seguimiento no efectiva'; END IF; END $$;
RESET ROLE;
-- Alta service_role, reintento idempotente y auditable.
SET LOCAL ROLE service_role;
SELECT public.admin_usuario_registrar_roles('94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000004','9404','Nueva',ARRAY['despacho','seguimiento']);
SELECT public.admin_usuario_registrar_roles('94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000004','9404','Nueva',ARRAY['despacho','seguimiento']);
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM public.usuarios WHERE numero_usuario='9404')<>1 THEN RAISE EXCEPTION 'Alta duplicada'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.admin_catalogos_historial WHERE despues->>'numero_usuario'='9402' AND despues->'roles'='["seguimiento","despacho"]'::jsonb) THEN RAISE EXCEPTION 'Falta auditoria de perfiles'; END IF;
END $$;
UPDATE public.usuarios SET activo=false WHERE numero_usuario='9404';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000004',true);
DO $$ BEGIN IF public.le_acceso() OR public.seguimiento_acceso() THEN RAISE EXCEPTION 'Inactivo conserva acceso'; END IF; END $$;
RESET ROLE;
-- Protección del último administrador, incluso al editar una lista de perfiles.
UPDATE public.usuarios SET activo=false WHERE rol='admin' AND numero_usuario<>'9401';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE fila jsonb; BEGIN
 SELECT to_jsonb(u) INTO fila FROM public.usuarios u WHERE numero_usuario='9401';
 PERFORM pg_temp.rechaza(format('SELECT public.admin_usuario_guardar_roles(%L,''Admin'',ARRAY[''despacho''],true,%L)',fila->>'id',md5(fila::text)));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_usuario_guardar_roles(%L,''Admin'',ARRAY[''admin''],false,%L)',fila->>'id',md5(fila::text)));
END $$;
RESET ROLE;
ROLLBACK;