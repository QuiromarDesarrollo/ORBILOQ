-- Ensayo local. Todos los datos de prueba se revierten.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000001','admin@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email,activo)
VALUES('10000000-0000-0000-0000-000000000001','ADMIN TEST','admin','00000000-0000-0000-0000-000000000001','900','admin@local',true);
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES
('entrega_produccion','0701856a-7771-4536-9762-658a58af8803',15,NULL),
('recepcion','0701856a-7771-4536-9762-658a58af8803',10,'40000000-0000-0000-0000-000000000001');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
GRANT USAGE ON SCHEMA auth TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE ctx jsonb; rechazo boolean; confirmar boolean; resultado jsonb;
BEGIN
 ctx:=public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803');
 FOREACH confirmar IN ARRAY ARRAY[false,true] LOOP
   rechazo:=false;
   BEGIN
     PERFORM public.admin_editar_kardex('0701856a-7771-4536-9762-658a58af8803','producido','5','ensayo',ctx->>'version',NULL,NULL,confirmar);
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM NOT LIKE '%Logistica ya tiene 10 recibidas%' THEN RAISE; END IF;
     rechazo:=true;
   END;
   IF NOT rechazo THEN RAISE EXCEPTION 'Acepto reducir por debajo de recibido'; END IF;
   IF public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803') IS DISTINCT FROM ctx THEN
     RAISE EXCEPTION 'Cambio datos al rechazar';
   END IF;
 END LOOP;
 resultado:=public.admin_editar_kardex('0701856a-7771-4536-9762-658a58af8803','producido','10','ensayo valido',ctx->>'version',NULL,NULL,true);
 ctx:=public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803');
 IF (ctx->'valores'->>'producido')::int<>10 OR (ctx->'valores'->>'recibido')::int<>10 THEN
   RAISE EXCEPTION 'No conserva la correccion valida';
 END IF;
END $$;
ROLLBACK;
