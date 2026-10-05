-- SOLO ENSAYO LOCAL. Datos sintéticos dentro de una transacción revertida.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo copia local'; END IF; END $$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
CREATE FUNCTION pg_temp.comprobar(ok boolean,mensaje text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',mensaje; END IF; END $$;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='admin' AND auth_id IS NOT NULL LIMIT 1),true);
END $$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE r jsonb; item uuid; lote uuid; li uuid; ubic uuid; codigo_ubic text; ctx jsonb; rechazada boolean;
BEGIN
 PERFORM pg_temp.comprobar((SELECT recibido=29 FROM public.vista_kardex WHERE numero_op='25438' AND codigo='2026556528' AND talla='30'),'OP histórica debe recibir 29 netas');
 PERFORM public.admin_reporte_resumen();
 PERFORM public.admin_reporte_pagina('auditoria');
 PERFORM public.admin_reporte_pagina('movimientos');
 PERFORM public.admin_reporte_pagina('nc');
 PERFORM public.admin_exportar_kardex();
 r:=public.importar_ordenes_produccion(
 '[{"identificador":"99999999001","cliente":"CLIENTE ENSAYO","oc_cabecera":"ENSAYO-OC","cantidad_total_erp":"10","nombre_ficha_tecnica":"FICHA CONSERVADA","tipo_orden":"ENSAYO"}]'::jsonb,
 '[{"identificador_orden":"99999999001","codigo":"ENSAYO","descripcion":"PRUEBA LOCAL","talla":"M","cantidad":"10","oc":"ENSAYO-OC"}]'::jsonb,
 'ensayo.xlsx',NULL,'NOMBRE FALSO');
 PERFORM pg_temp.comprobar((r->>'ops_creadas')::integer=1,'Importación ERP');
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM public.ordenes_produccion WHERE numero_op='99999999001' AND nombre_ficha_tecnica='FICHA CONSERVADA' AND cantidad_total_erp=10),'Campos ERP');
 SELECT id INTO item FROM public.items_orden WHERE codigo='ENSAYO';
 SELECT id,codigo INTO ubic,codigo_ubic FROM public.ubicaciones WHERE activa ORDER BY codigo LIMIT 1;
 r:=public.crear_lote(jsonb_build_array(jsonb_build_object('item_orden_id',item,'cantidad',6)),'NOMBRE FALSO','ENSAYO-6');
 lote:=(r->>'id')::uuid;
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM public.lotes l JOIN public.usuarios u ON u.id=l.operario_id WHERE l.id=lote AND u.auth_id=auth.uid() AND l.operario_nombre=u.nombre),'Actor autenticado');
 SELECT id INTO li FROM public.lote_items WHERE lote_id=lote;
 r:=public.recibir_lote_item(li,2,ubic,'parcial','NOMBRE FALSO');
 PERFORM pg_temp.comprobar((r->>'pendiente')::integer=4,'Recepción parcial');
 r:=public.recibir_lote_item(li,4,ubic,'completa','NOMBRE FALSO');
 PERFORM pg_temp.comprobar((r->>'completa')::boolean,'Recepción completa');
 r:=public.crear_lote(jsonb_build_array(jsonb_build_object('item_orden_id',item,'cantidad',4)),'NOMBRE FALSO','ENSAYO-4');
 SELECT id INTO li FROM public.lote_items WHERE lote_id=(r->>'id')::uuid;
 r:=public.recibir_lote_item(li,4,ubic,'firma antigua');
 PERFORM pg_temp.comprobar((SELECT recibido=10 FROM public.vista_kardex WHERE item_orden_id=item),'Compatibilidad recepción antigua');
 ctx:=public.admin_contexto_edicion(item);
 r:=public.admin_editar_kardex(item,'producido','8'::jsonb,'Ensayo',(ctx->>'version'),NULL,NULL,true);
 PERFORM pg_temp.comprobar((SELECT producido=8 AND recibido=10 FROM public.vista_kardex WHERE item_orden_id=item),'Ajuste sin alterar recepciones');
 rechazada:=false;
 BEGIN
  PERFORM public.admin_editar_kardex(item,'producido','7'::jsonb,'Obsoleto',(ctx->>'version'),NULL,NULL,true);
 EXCEPTION WHEN OTHERS THEN rechazada:=true; END;
 PERFORM pg_temp.comprobar(rechazada,'Rechazar versión obsoleta');
 r:=public.despachar_oc('ensayo-idempotente','CLIENTE ENSAYO','ENSAYO-OC',jsonb_build_array(jsonb_build_object('item_id',item,'ubicacion',codigo_ubic,'cantidad',5)));
 r:=public.despachar_oc('ensayo-idempotente','CLIENTE ENSAYO','ENSAYO-OC',jsonb_build_array(jsonb_build_object('item_id',item,'ubicacion',codigo_ubic,'cantidad',5)));
 PERFORM pg_temp.comprobar((r->>'repetido')::boolean,'Reintento idempotente');
 PERFORM pg_temp.comprobar((SELECT despachado=5 FROM public.vista_kardex WHERE item_orden_id=item),'Sin doble despacho');
 rechazada:=false;
 BEGIN
  PERFORM public.despachar_oc('ensayo-invalido','CLIENTE ENSAYO','ENSAYO-OC',jsonb_build_array(jsonb_build_object('item_id',item,'ubicacion',codigo_ubic,'cantidad',100)));
 EXCEPTION WHEN OTHERS THEN rechazada:=true; END;
 PERFORM pg_temp.comprobar(rechazada,'Rechazar exceso despacho');
 r:=public.registrar_no_conforme(item,1,(SELECT id FROM public.causales_devolucion WHERE activa LIMIT 1),'NOMBRE FALSO','ensayo',(SELECT nombre FROM public.personal_produccion WHERE activo LIMIT 1));
 r:=public.liberar_no_conforme(item,1,'NOMBRE FALSO','ensayo',(SELECT nombre FROM public.personal_logistica WHERE activo LIMIT 1));
 SELECT l.id INTO lote FROM public.lotes l WHERE l.numero=r->>'lote_numero';
 SELECT id INTO li FROM public.lote_items WHERE lote_id=lote;
 r:=public.recibir_lote_item(li,1,ubic,'Regreso reproceso','NOMBRE FALSO');
 PERFORM pg_temp.comprobar((SELECT recibido=10 AND pendiente_reproceso=0 FROM public.vista_kardex WHERE item_orden_id=item),'NC liberado y recibido de nuevo, sin duplicar saldo');
 PERFORM public.historial_despachos_oc();
 RAISE NOTICE 'OK: fórmulas, reportes, ERP, actor, recepción nueva/antigua, correcciones, idempotencia, exceso.';
END $test$;
RESET ROLE;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='logistica' AND auth_id IS NOT NULL LIMIT 1),true);
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE bloqueada boolean:=false; BEGIN
 PERFORM pg_temp.comprobar(public.wms_cuenta_activa(),'Logística activa');
 PERFORM public.historial_despachos_oc();
 BEGIN PERFORM public.admin_reporte_resumen(); EXCEPTION WHEN insufficient_privilege THEN bloqueada:=true; END;
 PERFORM pg_temp.comprobar(bloqueada,'Logística sin permiso reportes admin');
 RAISE NOTICE 'OK: separación de roles.';
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ DECLARE bloqueada boolean:=false; BEGIN
 BEGIN PERFORM public.admin_reporte_resumen(); EXCEPTION WHEN insufficient_privilege THEN bloqueada:=true; END;
 PERFORM pg_temp.comprobar(bloqueada,'Anónimo sin reportes');
END $$;
RESET ROLE;
ROLLBACK;
