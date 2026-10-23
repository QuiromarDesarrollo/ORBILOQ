RESET ROLE;
SELECT set_config('test.registro',(SELECT registro_id::text FROM public.conductor_tareas WHERE estado='Cerrada' AND motivos ? 'Estado frenos' LIMIT 1),false);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN
  PERFORM public.conductor_actividad_crear(current_setting('test.registro')::uuid,ARRAY['Estado frenos'],'Repetida',(now() AT TIME ZONE 'America/Bogota')::date);
  RAISE EXCEPTION 'ERROR: permitió reasignar un motivo completado';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Este motivo ya tiene una actividad%' THEN RAISE; END IF;
 END;
END $$;
RESET ROLE;
