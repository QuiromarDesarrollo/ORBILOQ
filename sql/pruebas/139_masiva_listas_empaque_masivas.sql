-- ORBILOQ-DEV. Fecha de impresión por lista y generación masiva de listas.
-- Aplica después de 138; cada documento continúa registrado por lista y versión.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
   AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN
  RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden
   WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
 IF position('masiva138_logo_update_where' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Aplica primero 138';
 END IF;
END $$;

ALTER TABLE public.masiva_listas
 ADD COLUMN IF NOT EXISTS fecha_generado timestamptz;
UPDATE public.masiva_listas l
 SET fecha_generado=d.ultima_impresion
FROM (
 SELECT operacion_id,lista,max(creado) AS ultima_impresion
 FROM public.masiva_documentos WHERE tipo='lista' GROUP BY operacion_id,lista
) d
WHERE l.operacion_id=d.operacion_id AND l.lista=d.lista
 AND l.fecha_generado IS NULL;

CREATE OR REPLACE FUNCTION pg_temp.masiva139_reemplazar(fuente text,patron text,nuevo text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
 fuente:=replace(fuente,chr(13),'');
 patron:=replace(patron,chr(13),'');
 nuevo:=replace(nuevo,chr(13),'');
 IF position(patron IN fuente)=0 THEN
  RAISE EXCEPTION 'Definición inesperada en generación masiva de listas';
 END IF;
 RETURN replace(fuente,patron,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)'::regprocedure);
 IF position('masiva139_fecha_generado' IN f)=0 THEN
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$campo_fecha NOT IN('ultima_validacion','fecha_carga','fecha_despacho','fecha_recepcion')$pattern$,
   $new$campo_fecha NOT IN('ultima_validacion','fecha_carga','fecha_despacho','fecha_recepcion','fecha_generado') /* masiva139_fecha_generado */$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$'kits_totales','kits_validados','kits_empacados','ultima_validacion','fecha_despacho','fecha_recepcion','transportadora'$pattern$,
   $new$'kits_totales','kits_validados','kits_empacados','ultima_validacion','fecha_despacho','fecha_recepcion','fecha_generado','transportadora'$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$'fecha_carga',fecha_carga,'fecha_despacho',NULL,'fecha_recepcion',NULL,'transportadora',NULL,'placa_guia',NULL,'novedades',NULL$pattern$,
   $new$'fecha_carga',fecha_carga,'fecha_despacho',NULL,'fecha_recepcion',NULL,'fecha_generado',l.fecha_generado,'transportadora',NULL,'placa_guia',NULL,'novedades',NULL$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva139_registrar_impresion' IN f)=0 THEN
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;$pattern$,
   $new$IF op.estado<>'activa' AND p_accion<>'registrar_impresion' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF; -- masiva139_registrar_impresion$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);$pattern$,
   $new$INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  IF p_datos->>'tipo'='lista' THEN
   UPDATE public.masiva_listas SET fecha_generado=ahora
    WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  END IF;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot); -- masiva139_registrar_impresion$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$ WHEN 'cerrar_operacion' THEN$pattern$,
   $new$ WHEN 'registrar_impresion' THEN
  IF NOT EXISTS(SELECT 1 FROM public.masiva_documentos d
   WHERE d.id=(p_datos->>'documento_id')::uuid AND d.operacion_id=operacion
    AND d.lista=p_datos->>'lista' AND d.tipo='lista') THEN
   RAISE EXCEPTION 'No se encontró la versión de la lista para reimprimir';
  END IF;
  UPDATE public.masiva_listas SET fecha_generado=ahora
   WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  resultado:=jsonb_build_object('registrada',true,'fecha_generado',ahora);
 WHEN 'cerrar_operacion' THEN$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $$ DECLARE maestro text; ejecutar text;
BEGIN
 maestro:=pg_get_functiondef('public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)'::regprocedure);
 ejecutar:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva139_fecha_generado' IN maestro)=0
   OR position('l.fecha_generado' IN maestro)=0
   OR position('masiva139_registrar_impresion' IN ejecutar)=0
   OR position('UPDATE public.masiva_listas SET fecha_generado=ahora' IN ejecutar)=0 THEN
  RAISE EXCEPTION 'La fecha de impresión de listas no quedó configurada';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
