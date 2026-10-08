DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
CREATE TABLE public.control_ajeno AS SELECT to_jsonb(i) fila FROM public.items_orden i;
INSERT INTO public.ordenes_produccion(id,numero_op,cliente,oc_cabecera)
VALUES('75b814c7-e6c0-4526-ba4d-cf5ac8d5e649','90003','CLIENTE PRUEBA TRAZABILIDAD','OC-TEST-90003');
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc)
VALUES('3bf42515-968d-4505-aae4-8fd62408bec2','75b814c7-e6c0-4526-ba4d-cf5ac8d5e649','TEST-TRAZ-001','CAMISETA PRUEBA TRAZABILIDAD','M',25,'OC-TEST-90003');
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');
INSERT INTO public.lotes(id,numero,operario_nombre) VALUES('30000000-0000-0000-0000-000000000001','TEST-LOTE','TEST');
INSERT INTO public.lote_items(lote_id,item_orden_id,cantidad_enviada,cantidad_recibida)
VALUES('30000000-0000-0000-0000-000000000001','3bf42515-968d-4505-aae4-8fd62408bec2',30,30);
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,lote_id) VALUES
('entrega_produccion','3bf42515-968d-4505-aae4-8fd62408bec2',25,NULL,'30000000-0000-0000-0000-000000000001'),
('recepcion','3bf42515-968d-4505-aae4-8fd62408bec2',30,'40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
('despacho','3bf42515-968d-4505-aae4-8fd62408bec2',10,'40000000-0000-0000-0000-000000000001',NULL);
