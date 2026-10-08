BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000078','envios@local');
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email,activo)
VALUES('ADMIN ENVIO','admin','00000000-0000-0000-0000-000000000078','978','envios@local',true);
UPDATE public.items_orden SET cantidad_pedida=90 WHERE id='0701856a-7771-4536-9762-658a58af8803';
INSERT INTO public.lotes(id,numero,operario_nombre) VALUES('50000000-0000-0000-0000-000000000078','9978','TEST');
INSERT INTO public.lote_items(id,lote_id,item_orden_id,cantidad_enviada,cantidad_recibida)
VALUES('60000000-0000-0000-0000-000000000078','50000000-0000-0000-0000-000000000078','0701856a-7771-4536-9762-658a58af8803',37,0);
INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,lote_id,lote_item_id)
VALUES('entrega_produccion','0701856a-7771-4536-9762-658a58af8803',37,'50000000-0000-0000-0000-000000000078','60000000-0000-0000-0000-000000000078');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000078',true);
DO $$ DECLARE ctx jsonb; r jsonb; item uuid:='0701856a-7771-4536-9762-658a58af8803'; BEGIN
 ctx:=public.admin_contexto_edicion(item);
 PERFORM public.admin_editar_kardex(item,'producido','0','Digitación',ctx->>'version',NULL,NULL,false);
 IF (SELECT cantidad_enviada FROM public.lote_items WHERE id='60000000-0000-0000-0000-000000000078')<>37 THEN RAISE EXCEPTION 'Preview mutó'; END IF;
 -- Corrección parcial, seguida de anulación completa.
 PERFORM public.admin_editar_kardex(item,'producido','12','Digitación',ctx->>'version',NULL,NULL,true);
 IF (SELECT cantidad_enviada FROM public.lote_items WHERE id='60000000-0000-0000-0000-000000000078')<>12 THEN RAISE EXCEPTION 'Pendiente parcial incorrecto'; END IF;
 ctx:=public.admin_contexto_edicion(item);
 r:=public.admin_editar_kardex(item,'producido','0','Digitación',ctx->>'version',NULL,NULL,true);
 IF EXISTS(SELECT 1 FROM public.lote_items WHERE id='60000000-0000-0000-0000-000000000078' AND (cantidad_enviada<>0 OR estado='en_transito')) THEN RAISE EXCEPTION 'Pendiente fantasma'; END IF;
 IF (SELECT producido FROM public.vista_kardex WHERE item_orden_id=item)<>0 THEN RAISE EXCEPTION 'Total incorrecto'; END IF;
 IF (SELECT jsonb_array_length(lote_antes) FROM public.admin_correcciones WHERE id=(r->>'auditoria_id')::uuid)<>1 THEN RAISE EXCEPTION 'Falta auditoría'; END IF;
END $$;
ROLLBACK;

