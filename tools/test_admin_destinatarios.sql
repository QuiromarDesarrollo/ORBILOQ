BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('95000000-0000-0000-0000-000000000001','admin95@local'),('95000000-0000-0000-0000-000000000002','desp95@local');
INSERT INTO public.usuarios(nombre,rol,roles,auth_id,numero_usuario,email,activo) VALUES
 ('Admin95','admin',ARRAY['admin','despacho'],'95000000-0000-0000-0000-000000000001','9501','admin95@local',true),
 ('Desp95','despacho',ARRAY['despacho'],'95000000-0000-0000-0000-000000000002','9502','desp95@local',true);
CREATE FUNCTION pg_temp.rechaza(q text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE q; EXCEPTION WHEN insufficient_privilege OR raise_exception THEN RETURN; END;
 RAISE EXCEPTION 'Operacion prohibida aceptada: %',q;
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE destino jsonb; nuevo jsonb; id uuid;
BEGIN
 PERFORM public.le_importar_clientes('[{"nombre":"Test95","nit":"123"}]');
 SELECT value INTO destino FROM jsonb_array_elements(public.le_clientes()) WHERE value->'datos'->>'nombre'='Test95';
 id:=(destino->>'id')::uuid;
 nuevo:=destino->'datos'||'{"sede":"Sur"}'::jsonb;
 PERFORM public.admin_destinatario_editar(id,destino->'datos',nuevo);
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.le_clientes()) WHERE value->>'id'=id::text AND value->'datos'=nuevo) THEN RAISE EXCEPTION 'No conserva ID y datos'; END IF;
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_editar(%L,%L,%L)',id,destino->'datos',nuevo));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_eliminar(%L,%L)',id,destino->'datos'));
 PERFORM public.le_importar_clientes('[{"nombre":"Otro95"}]');
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_editar(%L,%L,%L)',id,nuevo,'{"nombre":"Otro95"}'));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_editar(%L,%L,%L)',id,nuevo,'{"nombre":"Test95","tipo_destinatario":"internacional"}'));
 PERFORM set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000002',true);
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_editar(%L,%L,%L)',id,nuevo,nuevo));
 PERFORM pg_temp.rechaza(format('SELECT public.admin_destinatario_eliminar(%L,%L)',id,nuevo));
 PERFORM set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',true);
 PERFORM public.admin_destinatario_eliminar(id,nuevo);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(public.le_clientes()) WHERE value->>'id'=id::text) THEN RAISE EXCEPTION 'No elimino'; END IF;
END $$;
RESET ROLE;
INSERT INTO public.destinatarios_empaque(id,clave,datos) VALUES('95000000-0000-0000-0000-000000000095','test95-vinculado','{"nombre":"Historico95"}');
INSERT INTO public.despachos_oc(solicitud,actor_id,actor,cliente,oc,pedido,detalle,destinatario_id,destinatario_empaque)
VALUES('test95-historico','95000000-0000-0000-0000-000000000001','Admin95','Historico95','OC95','{}','[]','95000000-0000-0000-0000-000000000095','{"nombre":"Historico95"}');
SET LOCAL ROLE authenticated;
SELECT pg_temp.rechaza($q$SELECT public.admin_destinatario_eliminar('95000000-0000-0000-0000-000000000095','{"nombre":"Historico95"}')$q$);
SELECT public.admin_destinatario_editar('95000000-0000-0000-0000-000000000095','{"nombre":"Historico95"}','{"nombre":"Actualizado95"}');
RESET ROLE;
DO $$ BEGIN
 IF (SELECT destinatario_empaque->>'nombre' FROM public.despachos_oc WHERE solicitud='test95-historico')<>'Historico95' THEN RAISE EXCEPTION 'Cambio el documento historico'; END IF;
END $$;
ROLLBACK;
