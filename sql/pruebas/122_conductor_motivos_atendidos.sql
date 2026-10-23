-- SOLO PRUEBAS. Después de 121. Un motivo se atiende una sola vez por checklist.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ DECLARE f text; ancla text:=$a$registro_id=r.id AND estado<>'Cerrada' AND motivos ? v_punto$a$; BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 SELECT pg_get_functiondef('public.conductor_actividad_crear(uuid,text[],text,date)'::regprocedure) INTO f;
 IF position('MOTIVO_ATENDIDO_V122' IN f)=0 THEN
  IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Aplicar primero migración 121'; END IF;
  f:=replace(f,ancla,'registro_id=r.id AND motivos ? v_punto /* MOTIVO_ATENDIDO_V122 */');
  f:=replace(f,'Ya existe una actividad abierta para %','Este motivo ya tiene una actividad asignada en el checklist: %');
  EXECUTE f;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
