-- SOLO copia local. Las cuentas temporales se revierten al terminar.
\ir test_permisos_seguimiento.sql
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
DO $$ BEGIN
 IF (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename IN ('items_orden','ordenes_produccion','movimientos','lotes','lote_items','reservas_despacho'))<>6 THEN RAISE EXCEPTION 'Faltan tablas Realtime'; END IF;
 IF (SELECT siguiente FROM public.lista_empaque_config WHERE id=true) IS DISTINCT FROM 3000::bigint THEN RAISE EXCEPTION 'Consecutivo incorrecto'; END IF;
 IF EXISTS(SELECT 1 FROM public.empaques) OR EXISTS(SELECT 1 FROM public.destinatarios_empaque) THEN RAISE EXCEPTION 'Catálogos inesperados'; END IF;
 PERFORM set_config('request.jwt.claim.sub',(SELECT auth_id::text FROM public.usuarios WHERE activo AND rol='admin' AND auth_id IS NOT NULL LIMIT 1),true);
END $$;
SET LOCAL ROLE authenticated;
SELECT jsonb_typeof(public.admin_trazabilidad_op()) AS tipo_trazabilidad;
SELECT jsonb_typeof(public.admin_reporte_resumen()) AS tipo_resumen;
SELECT jsonb_typeof(public.admin_reporte_pagina('movimientos')) AS tipo_movimientos;
SELECT jsonb_typeof(public.historial_despachos_empaques()) AS tipo_historial;
SELECT jsonb_typeof(public.destinatarios_para_empaque()) AS tipo_destinatarios;
DO $flujo$
DECLARE r jsonb; item uuid; lote uuid; li uuid; ubic uuid; codigo_ubic text;
 e jsonb; destino jsonb; lineas jsonb; paquetes jsonb; despacho uuid; doc jsonb; v integer;
BEGIN
 r:=public.importar_ordenes_produccion(
 '[{"identificador":"99999999009","cliente":"CLIENTE ENSAYO OCTUBRE","oc_cabecera":"ENSAYO-OCT","cantidad_total_erp":"10","nombre_ficha_tecnica":"FICHA ENSAYO","tipo_orden":"ENSAYO"}]',
 '[{"identificador_orden":"99999999009","codigo":"ENSAYO-OCT","descripcion":"PRUEBA LOCAL","talla":"M","cantidad":"10","oc":"ENSAYO-OCT"}]',
 'ensayo-oct.xlsx',NULL,'ENSAYO');
 IF (r->>'ops_creadas')::integer IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Importación falló'; END IF;
 SELECT id INTO STRICT item FROM public.items_orden WHERE codigo='ENSAYO-OCT';
 SELECT id,codigo INTO ubic,codigo_ubic FROM public.ubicaciones WHERE activa ORDER BY codigo LIMIT 1;
 r:=public.crear_lote(jsonb_build_array(jsonb_build_object('item_orden_id',item,'cantidad',10)),'ENSAYO','ENSAYO-OCT');
 lote:=(r->>'id')::uuid;
 SELECT id INTO STRICT li FROM public.lote_items WHERE lote_id=lote;
 PERFORM public.recibir_lote_item(li,10,ubic,'Ensayo local','ENSAYO');
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja ensayo","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 PERFORM public.le_importar_clientes('[{"nombre":"DESTINO ENSAYO","direccion":"DIRECCION ENSAYO","ciudad":"Bogotá"}]');
 destino:=public.destinatarios_para_empaque()->0;
 lineas:=jsonb_build_array(jsonb_build_object('item_id',item,'ubicacion',codigo_ubic,'cantidad',6));
 paquetes:=jsonb_build_array(jsonb_build_object('numero',1,'item_id',item,'empaque_id',e->>'id','cantidad',6,'version',md5(e::text)));
 r:=public.guardar_empaque_destinatario('ensayo-octubre','CLIENTE ENSAYO OCTUBRE','ENSAYO-OCT',lineas,paquetes,(destino->>'id')::uuid,destino->>'version');
 despacho:=(r->>'id')::uuid;
 IF public.guardar_empaque_destinatario('ensayo-octubre','CLIENTE ENSAYO OCTUBRE','ENSAYO-OCT',lineas,paquetes,(destino->>'id')::uuid,destino->>'version') IS DISTINCT FROM r THEN RAISE EXCEPTION 'Empaque no idempotente'; END IF;
 doc:=public.le_documento('ensayo-octubre');
 IF doc->'destinatario_empaque' IS DISTINCT FROM destino->'datos' THEN RAISE EXCEPTION 'Se perdió destinatario'; END IF;
 IF EXISTS(SELECT 1 FROM public.movimientos WHERE despacho_oc_id=despacho AND tipo='despacho') THEN RAISE EXCEPTION 'Empacar descontó inventario'; END IF;
 doc:=public.seguimiento_confirmar(despacho,0,(destino->>'id')::uuid);
 IF (SELECT sum(cantidad) FROM public.movimientos WHERE despacho_oc_id=despacho AND tipo='despacho') IS DISTINCT FROM 6::bigint THEN RAISE EXCEPTION 'Salida incorrecta'; END IF;
 v:=public.seguimiento_entregas_guardar_v87(despacho,0,0,'{"transportadora":"ENSAYO","numero_guia":"GUIA-ENSAYO","placa":"PLACA-ENSAYO","estado":"en_transito"}');
 IF v<>1 THEN RAISE EXCEPTION 'Versión seguimiento incorrecta'; END IF;
 SELECT x INTO r FROM jsonb_array_elements(public.seguimiento_entregas_listar()) x WHERE x->>'id'=despacho::text;
 IF r->>'numero_guia' IS DISTINCT FROM 'GUIA-ENSAYO' OR r->>'placa' IS DISTINCT FROM 'PLACA-ENSAYO' THEN RAISE EXCEPTION 'Guía o placa no conservada'; END IF;
 IF jsonb_array_length(public.admin_trazabilidad_op('99999999009'))<>1 THEN RAISE EXCEPTION 'Trazabilidad incompleta'; END IF;
 RAISE NOTICE 'Flujo importación/producción/recepción/empaque/salida/seguimiento/trazabilidad: correcto; se revierte.';
END $flujo$;
RESET ROLE;
ROLLBACK;
\ir ../sql/produccion/006_verificar_actualizacion_20261009.sql
