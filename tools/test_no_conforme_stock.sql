BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
INSERT INTO public.causales_devolucion(nombre,activa) VALUES('PRUEBA NC88',true);
INSERT INTO public.items_orden(id,orden_id,codigo,descripcion,talla,cantidad_pedida,oc)
VALUES('0701856a-7771-4536-9762-658a58af8888','20000000-0000-0000-0000-000000000001','NC88','TEST','L',10,'TEST-OC');
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id) VALUES
('entrega_produccion','0701856a-7771-4536-9762-658a58af8888',10,NULL),
('recepcion','0701856a-7771-4536-9762-658a58af8888',10,'40000000-0000-0000-0000-000000000001'),
('despacho','0701856a-7771-4536-9762-658a58af8888',8,'40000000-0000-0000-0000-000000000001');
ALTER FUNCTION public.registrar_no_conforme(uuid,integer,uuid,text,text) RENAME TO registrar_no_conforme_cinco_prueba;
DO $$ DECLARE i uuid:='0701856a-7771-4536-9762-658a58af8888'; c uuid; antes bigint; rechazado boolean; BEGIN
 SELECT id INTO c FROM public.causales_devolucion WHERE activa LIMIT 1;
 SELECT count(*) INTO antes FROM public.movimientos;
 rechazado:=false;
 BEGIN PERFORM public.registrar_no_conforme(i,5,c,'TEST','Prueba','TEST'); EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE 'LÍMITE EXCEDIDO: quedan 2%' THEN RAISE; END IF; rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permitió 5 devoluciones con 2 disponibles'; END IF;
 rechazado:=false;
 BEGIN PERFORM public.registrar_no_conforme_cinco_prueba(i,5,c,'TEST'::text,'Prueba'::text); EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE 'LÍMITE EXCEDIDO: quedan 2%' THEN RAISE; END IF; rechazado:=true; END;
 IF NOT rechazado OR (SELECT count(*) FROM public.movimientos)<>antes THEN RAISE EXCEPTION 'Firma antigua permite saldo negativo o dejó movimientos'; END IF;
 INSERT INTO public.reservas_despacho(despacho_id,item_id,ubicacion_id,cantidad)
 SELECT id,i,'40000000-0000-0000-0000-000000000001',1 FROM public.despachos_oc LIMIT 1;
 rechazado:=false;
 BEGIN PERFORM public.registrar_no_conforme(i,2,c,'TEST','Prueba','TEST'); EXCEPTION WHEN raise_exception THEN
 IF SQLERRM NOT LIKE 'LÍMITE EXCEDIDO: quedan 1%' THEN RAISE; END IF; rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permitió devolver prendas reservadas'; END IF;
 DELETE FROM public.reservas_despacho WHERE item_id=i;
 PERFORM public.registrar_no_conforme(i,2,c,'TEST','Prueba','TEST');
 IF (SELECT recibido-despachado FROM public.vista_kardex WHERE item_orden_id=i)<>0 THEN RAISE EXCEPTION 'Saldo final incorrecto'; END IF;
 IF EXISTS(SELECT 1 FROM public.vista_stock_ubicacion_detalle WHERE item_orden_id=i AND cantidad>0) THEN RAISE EXCEPTION 'La devolución dejó unidades despachables en el estante'; END IF;
END $$;
ROLLBACK;
