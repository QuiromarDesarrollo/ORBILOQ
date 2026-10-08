-- SOLO ORBILOQ-DEV. Aplicar después de 074. No modifica cantidades existentes.
BEGIN;
DO $m$
DECLARE definicion text; ancla text := ' -- La revisión ejecuta las mismas validaciones que guardar y revierte todas sus escrituras.';
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'Revisar proyecto de pruebas'; END IF;
 SELECT pg_get_functiondef(to_regprocedure('public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean)')) INTO definicion;
 IF definicion IS NULL THEN RAISE EXCEPTION 'Instala primero 074'; END IF;
 IF position('proteccion_despachadas_075' in definicion)>0 THEN RETURN; END IF;
 IF position(ancla in definicion)=0 THEN RAISE EXCEPTION 'La función cambió. Revisar antes de instalar.'; END IF;
 definicion:=replace(definicion,ancla,$regla$
 -- proteccion_despachadas_075: no compensar una reducción de stock despachado con otra recepción.
 IF (SELECT coalesce(sum(greatest(coalesce(l.cantidad_recibida,0)-(x->>'cantidad')::integer,0)),0)
     FROM jsonb_array_elements(p_recepciones) x JOIN public.lote_items l ON l.id=(x->>'id')::uuid)
     > (antes->>'recibido')::integer-(antes->>'despachado')::integer THEN
   RAISE EXCEPTION 'La reducción supera las prendas que siguen en bodega. Las despachadas están protegidas.';
 END IF;
$regla$ || ancla);
 EXECUTE definicion;
END $m$;
NOTIFY pgrst,'reload schema';
COMMIT;
