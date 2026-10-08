-- Ensayo local. Todos los datos de prueba se revierten.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000001','admin@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email,activo)
VALUES('10000000-0000-0000-0000-000000000001','ADMIN TEST','admin','00000000-0000-0000-0000-000000000001','900','admin@local',true);
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');

UPDATE public.items_orden SET cantidad_pedida=30 WHERE id='0701856a-7771-4536-9762-658a58af8803';
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES
('entrega_produccion','0701856a-7771-4536-9762-658a58af8803',30,NULL),
('recepcion','0701856a-7771-4536-9762-658a58af8803',18,'40000000-0000-0000-0000-000000000001');
INSERT INTO public.lotes(id,numero,operario_nombre) VALUES('50000000-0000-0000-0000-000000000001','999','TEST'),('50000000-0000-0000-0000-000000000002','998','TEST'),('50000000-0000-0000-0000-000000000003','997','TEST');
INSERT INTO public.lote_items(id,lote_id,item_orden_id,cantidad_enviada,cantidad_recibida) VALUES
('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','0701856a-7771-4536-9762-658a58af8803',5,1),
('60000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002','0701856a-7771-4536-9762-658a58af8803',8,2),
('60000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','0701856a-7771-4536-9762-658a58af8803',8,5);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
GRANT USAGE ON SCHEMA auth TO authenticated;
CREATE FUNCTION public.test_fallo_multilote() RETURNS trigger LANGUAGE plpgsql AS $t$
BEGIN
 IF current_setting('test.fallar',true)='si' AND NEW.id='60000000-0000-0000-0000-000000000002' THEN RAISE EXCEPTION 'Fallo simulado en lote posterior'; END IF;
 RETURN NEW;
END $t$;
CREATE TRIGGER test_fallo BEFORE UPDATE ON public.lote_items FOR EACH ROW EXECUTE FUNCTION public.test_fallo_multilote();
SET LOCAL ROLE authenticated;
DO $$ DECLARE ctx jsonb; r jsonb; plan jsonb:='[{"id":"60000000-0000-0000-0000-000000000001","cantidad":5},{"id":"60000000-0000-0000-0000-000000000002","cantidad":8},{"id":"60000000-0000-0000-0000-000000000003","cantidad":7}]';
BEGIN
 ctx:=public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803');
 r:=public.admin_editar_recepciones('0701856a-7771-4536-9762-658a58af8803','recibido','30','TEST',ctx->>'version',plan,'40000000-0000-0000-0000-000000000001',false);
 IF (r->'despues'->>'recibido')::int<>30 OR public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803') IS DISTINCT FROM ctx THEN RAISE EXCEPTION 'Preview mutó datos'; END IF;
 PERFORM set_config('test.fallar','si',true);
 BEGIN
 PERFORM public.admin_editar_recepciones('0701856a-7771-4536-9762-658a58af8803','recibido','30','TEST',ctx->>'version',plan,'40000000-0000-0000-0000-000000000001',true);
 RAISE EXCEPTION 'No detecto fallo';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Fallo simulado en lote posterior' THEN RAISE; END IF; END;
 IF public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803') IS DISTINCT FROM ctx THEN RAISE EXCEPTION 'Dejo escritura parcial'; END IF;
 PERFORM set_config('test.fallar','no',true);
 r:=public.admin_editar_recepciones('0701856a-7771-4536-9762-658a58af8803','recibido','30','TEST',ctx->>'version',plan,'40000000-0000-0000-0000-000000000001',true);
 IF (public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803')->'valores'->>'recibido')::int<>30 THEN RAISE EXCEPTION 'Total incorrecto'; END IF;
 BEGIN
 PERFORM public.admin_editar_recepciones('0701856a-7771-4536-9762-658a58af8803','recibido','30','TEST',ctx->>'version',plan,'40000000-0000-0000-0000-000000000001',true);
 RAISE EXCEPTION 'Aceptó token viejo';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'La fila cambió%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES('despacho','0701856a-7771-4536-9762-658a58af8803',20,'40000000-0000-0000-0000-000000000001');
SET LOCAL ROLE authenticated;
DO $$ DECLARE ctx jsonb; confirmar boolean;
BEGIN
 ctx:=public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803');
 FOREACH confirmar IN ARRAY ARRAY[false,true] LOOP
 BEGIN
 PERFORM public.admin_editar_recepciones('0701856a-7771-4536-9762-658a58af8803','recibido','20','TEST',ctx->>'version',
 '[{"id":"60000000-0000-0000-0000-000000000001","cantidad":0},{"id":"60000000-0000-0000-0000-000000000002","cantidad":2},{"id":"60000000-0000-0000-0000-000000000003","cantidad":8}]',
 '40000000-0000-0000-0000-000000000001',confirmar);
 RAISE EXCEPTION 'Aceptó reducción superior al stock';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'La reducción supera%' THEN RAISE; END IF; END;
 IF public.admin_contexto_edicion('0701856a-7771-4536-9762-658a58af8803') IS DISTINCT FROM ctx THEN RAISE EXCEPTION 'Cambio datos al rechazar'; END IF;
 END LOOP;
END $$;
ROLLBACK;
