-- SOLO ORBILOQ-DEV. Aplicar después de 127. No modifica registros anteriores.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.conductor_historial(uuid,date,date,integer,integer)') IS NULL THEN RAISE EXCEPTION 'Requiere historial privado 115'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_registrar_kit(p_vehiculo uuid,p_datos jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; actor text; registro uuid; p jsonb; r jsonb; nombre text; estado text;
 fecha date; vencimiento date; hoy date:=(now() AT TIME ZONE 'America/Bogota')::date;
 catalogo jsonb:=$catalogo$[{"nombre": "Gato para elevar el vehículo", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Manivela o mecanismo de accionamiento", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Cruceta para las tuercas de las ruedas", "categoria": "Cruceta", "vencimiento": false, "opcional": false}, {"nombre": "Triángulo reflectivo N.º 1", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Triángulo reflectivo N.º 2", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Soportes de los triángulos", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Lámparas amarillas intermitentes", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Guantes desechables de nitrilo", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Mascarilla de barrera para RCP", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Gasas estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Vendas de gasa", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Venda elástica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Esparadrapo o cinta médica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos adhesivos", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Solución salina estéril", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Toallitas antisépticas", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Compresa estéril para quemaduras", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Tijeras de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Pinzas de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Manta térmica de emergencia", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Bolsas para material contaminado", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Estuche del botiquín", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Extintor adecuado para el vehículo", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Carga y mantenimiento del extintor", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Manómetro, seguro y sello", "categoria": "Extintor", "vencimiento": false, "opcional": true}, {"nombre": "Soporte de fijación del extintor", "categoria": "Extintor", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 1", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 2", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Alicate", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de pala", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de estrella", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llave de expansión", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Juego de llaves fijas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Caja o bolso de herramientas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llanta de repuesto compatible", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Presión y estado de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Fijación de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Linterna funcional", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Pilas o batería con carga", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Chaleco reflectivo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cables de arranque o arrancador portátil", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Compresor o medidor de presión", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Sellador de pinchazos", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Guantes de trabajo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Agua potable", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Impermeable", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cargador portátil para celular", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cuerda de remolque compatible", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Contactos de emergencia", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Kit antiderrames", "categoria": "Kit antiderrames", "vencimiento": false, "opcional": false}]$catalogo$::jsonb;
 novedades integer:=0;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo el administrador puede revisar el kit de carretera' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso al vehículo' USING ERRCODE='42501'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR octet_length(p_datos::text)>16000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF length(trim(coalesce(p_datos->>'inspector',''))) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Inspector requerido'; END IF;
 IF length(coalesce(p_datos->>'lugar',''))>160 OR length(coalesce(p_datos->>'notas',''))>1000 THEN RAISE EXCEPTION 'Texto demasiado largo'; END IF;
 IF coalesce(p_datos->>'fecha','') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha requerida'; END IF;
 fecha:=(p_datos->>'fecha')::date;
 IF fecha<date_trunc('week',hoy::timestamp)::date OR fecha>hoy THEN RAISE EXCEPTION 'La inspección debe corresponder a esta semana y no ser futura'; END IF;
 IF jsonb_typeof(p_datos->'respuestas') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Checklist requerido'; END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(p_datos->'respuestas'))<>jsonb_array_length(catalogo) THEN RAISE EXCEPTION 'Completa todos los puntos del kit de carretera'; END IF;
 FOR p IN SELECT value FROM jsonb_array_elements(catalogo) LOOP
   nombre:=p->>'nombre'; r:=p_datos->'respuestas'->nombre; estado:=r->>'estado';
   IF r IS NULL OR jsonb_typeof(r)<>'object' OR coalesce(estado,'') NOT IN('Buen estado','Con novedad','No aplica') THEN RAISE EXCEPTION 'Punto pendiente: %',nombre; END IF;
   IF estado='No aplica' AND NOT (p->>'opcional')::boolean THEN RAISE EXCEPTION 'No aplica no permitido: %',nombre; END IF;
   IF length(coalesce(r->>'detalle',''))>120 THEN RAISE EXCEPTION 'Detalle demasiado largo: %',nombre; END IF;
   IF estado='Con novedad' THEN
     IF length(trim(coalesce(r->>'detalle','')))=0 THEN RAISE EXCEPTION 'Describe la novedad: %',nombre; END IF;
     novedades:=novedades+1;
   END IF;
   IF coalesce(r->>'vencimiento','')<>'' THEN
     IF NOT (p->>'vencimiento')::boolean OR estado='No aplica' OR (r->>'vencimiento') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Vencimiento inválido: %',nombre; END IF;
     vencimiento:=(r->>'vencimiento')::date;
     IF vencimiento<fecha AND estado='Buen estado' THEN RAISE EXCEPTION 'Elemento vencido: %',nombre; END IF;
   END IF;
 END LOOP;
 IF (p_datos->'respuestas'->'Lámparas amarillas intermitentes'->>'estado')='No aplica' AND EXISTS(
 SELECT 1 FROM unnest(ARRAY['Triángulo reflectivo N.º 1','Triángulo reflectivo N.º 2','Soportes de los triángulos']) n
 WHERE (p_datos->'respuestas'->n->>'estado')='No aplica') THEN RAISE EXCEPTION 'Revisa ambos triángulos y soportes o las lámparas alternativas'; END IF;
 SELECT u.nombre INTO actor FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo;
 -- Lista blanca de datos: el cliente no puede sustituir el resultado calculado.
 p_datos:=jsonb_build_object('inspector',trim(p_datos->>'inspector'),'fecha',to_char(fecha,'YYYY-MM-DD'),
 'lugar',trim(coalesce(p_datos->>'lugar','')),'notas',trim(coalesce(p_datos->>'notas','')),
 'respuestas',p_datos->'respuestas','resultado',CASE WHEN novedades>0 THEN 'Requiere revisión' ELSE 'Sin novedades' END);
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(p_vehiculo,auth.uid(),actor,'Checklist semanal de carretera',v.km,p_datos) RETURNING id INTO registro;
 RETURN registro;
END $$;
REVOKE ALL ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) TO authenticated;
-- Se calcula desde registros inmutables, no desde los documentos editables del vehículo.

-- Conserva los cambios de las migraciones anteriores y los registros históricos.
DO $actualizar$
DECLARE definicion text;
BEGIN
 SELECT pg_get_functiondef('public.conductor_registrar(uuid,text,integer,jsonb)'::regprocedure) INTO definicion;
 IF position('Botas de lluvia' in definicion)=0 THEN
   IF position('''Kit de derrames'',''Extintor'']' in definicion)=0 THEN
     RAISE EXCEPTION 'No se reconoce el catálogo diario; revisar la versión de conductor_registrar';
   END IF;
   definicion:=replace(definicion,'''Kit de derrames'',''Extintor'']','''Kit de derrames'',''Extintor'',''Botas de lluvia'',''Impermeable'',''Guantes de trabajo'',''Chaleco reflectivo'']');
   EXECUTE definicion;
 END IF;
END $actualizar$;
NOTIFY pgrst,'reload schema';
COMMIT;
