-- Fixture PostgreSQL local. Datos sintéticos; no ejecutar en Supabase remoto.
BEGIN;
CREATE FUNCTION pg_temp.check151(ok boolean,msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '151: %',msg; END IF; END $$;
DO $$
DECLARE actor uuid; op uuid:=gen_random_uuid(); otra uuid:=gen_random_uuid();
 r jsonb; antes jsonb; despues jsonb; denegado boolean:=false;
BEGIN
 SELECT auth_id INTO actor FROM public.usuarios WHERE activo AND 'admin'=ANY(coalesce(roles,ARRAY[rol])) LIMIT 1;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 INSERT INTO public.masiva_operaciones(id,nombre,cliente,creado_por)
 VALUES(op,'Avance151','Ficticio',actor),(otra,'Otra151','Ficticio',actor);
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op,'A'),(op,'B'),(op,'VACIA'),(otra,'A');
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre,estado,armado)
 VALUES(op,'A',1,'151-1','Uno','validado',NULL),
 (op,'A',2,'151-2','Dos','parcial',now()),
 (op,'A',3,'151-3','Tres','pendiente',NULL),
 (op,'A',4,'151-4','Cuatro','validado',NULL),
 (op,'B',1,'151-B','Otra lista','validado',now()),
 (otra,'A',1,'151-O','Otra operacion','validado',now());
 SELECT jsonb_agg(to_jsonb(k) ORDER BY id) INTO antes FROM public.masiva_kits k;
 r:=public.masiva_empaque_consultar(op,' A ');
 PERFORM pg_temp.check151(r->>'total'='4' AND r->>'validados'='2','solo kits validados de esta lista y operacion');
 PERFORM pg_temp.check151(r->>'terminados'='1' AND r->>'pendientes'='3','conserva conteos fisicos, distintos de validacion');
 PERFORM pg_temp.check151(jsonb_array_length(r->'kits')=4,'conserva todas las posiciones');
 PERFORM pg_temp.check151(r->'kits'->0->>'estado'='validado' AND r->'kits'->1->>'estado'='parcial','estado del actual en el mismo resultado');
 PERFORM pg_temp.check151((r->'kits'->0) ?& ARRAY['id','numero_persona','nombre','armado','empacador_id','empacador','asignacion_id'],'conserva campos anteriores');
 PERFORM pg_temp.check151(public.masiva_empaque_consultar(op,'VACIA')->>'validados'='0','lista vacia sin avance inventado');
 SELECT jsonb_agg(to_jsonb(k) ORDER BY id) INTO despues FROM public.masiva_kits k;
 PERFORM pg_temp.check151(antes=despues,'la consulta no modifica kits');
 PERFORM pg_temp.check151(has_function_privilege('authenticated','public.masiva_empaque_consultar(uuid,text)','EXECUTE'),'conserva permiso autenticado');
 PERFORM pg_temp.check151(NOT has_function_privilege('anon','public.masiva_empaque_consultar(uuid,text)','EXECUTE'),'no concede acceso anonimo');
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.masiva_empaque_consultar(op,'A');
 EXCEPTION WHEN insufficient_privilege THEN denegado:=true;
 END;
 PERFORM pg_temp.check151(denegado,'conserva control de acceso de Masiva');
END $$;
ROLLBACK;
SELECT '151: avance por lista, compatibilidad, permisos y solo lectura correctos' AS resultado;
