-- SOLO LOCAL: valores sinteticos, ninguna cuenta o contraseña real.
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo local'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES
 ('00000000-0000-0000-0000-000000000001','admin@local'),
 ('00000000-0000-0000-0000-000000000002','logistica@local');
INSERT INTO public.usuarios(id,nombre,rol,auth_id,numero_usuario,email) VALUES
 ('10000000-0000-0000-0000-000000000001','ADMIN LOCAL','admin','00000000-0000-0000-0000-000000000001','TEST1','admin@local'),
 ('10000000-0000-0000-0000-000000000002','LOGISTICA LOCAL','logistica','00000000-0000-0000-0000-000000000002','TEST2','logistica@local');
INSERT INTO public.ordenes_produccion(id,numero_op,cliente) VALUES
 ('20000000-0000-0000-0000-000000000001','25438','CLIENTE SINTETICO');
INSERT INTO public.items_orden(id,orden_id,codigo,talla,cantidad_pedida) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026556528','30',29);
INSERT INTO public.ubicaciones(id,codigo) VALUES ('40000000-0000-0000-0000-000000000001','LOCAL-A');
INSERT INTO public.causales_devolucion(id,nombre) VALUES ('50000000-0000-0000-0000-000000000001','CAUSAL LOCAL');
INSERT INTO public.personal_produccion(nombre) VALUES ('PRODUCCION LOCAL');
INSERT INTO public.personal_logistica(nombre) VALUES ('LOGISTICA LOCAL');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,fecha,nota) VALUES
 ('entrega_produccion','30000000-0000-0000-0000-000000000001',29,NULL,'2026-09-01 12:00:00+00','NOTA A CONSERVAR'),
 ('recepcion','30000000-0000-0000-0000-000000000001',29,'40000000-0000-0000-0000-000000000001','2026-09-02 12:00:00+00','HISTORICO A CONSERVAR');
INSERT INTO public.no_conformes_aliados(item_orden_id,cantidad_solicitada,causal_id,persona_aliado_entrega,usuario_produccion_solicitud_nombre)
 VALUES ('30000000-0000-0000-0000-000000000001',1,'50000000-0000-0000-0000-000000000001','ALIADO LOCAL','PRODUCCION LOCAL');
