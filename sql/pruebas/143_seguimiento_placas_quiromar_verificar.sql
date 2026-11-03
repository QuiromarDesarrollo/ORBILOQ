-- Verificación de solo lectura. Ejecutar en ORBILOQ-DEV después de 143.
BEGIN;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.seguimiento_placas_quiromar();
  RAISE EXCEPTION 'Acceso sin sesión aceptado';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SELECT set_config('request.jwt.claim.sub',(
 SELECT auth_id::text FROM public.usuarios WHERE activo AND auth_id IS NOT NULL
 AND 'admin'=ANY(coalesce(roles,ARRAY[rol])) LIMIT 1),true) IS NOT NULL AS sesion_prueba;
SELECT (SELECT count(*) FROM public.seguimiento_placas_quiromar()) AS placas_disponibles,
 (SELECT count(*) FROM public.conductor_vehiculos) AS vehiculos_transporte,
 NOT has_function_privilege('anon','public.seguimiento_placas_quiromar()','EXECUTE') AS anon_bloqueado;
ROLLBACK;
