-- Solo DEV confirmado. Datos ficticios y rollback completo.
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.probar_empacador() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE actor uuid; op uuid; persona uuid; r jsonb; fila jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No es DEV'; END IF;
 SELECT auth_id INTO actor FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND coalesce(roles,ARRAY[rol]) @> ARRAY['admin'] LIMIT 1;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 op := (public.masiva_ejecutar('crear_operacion',jsonb_build_object('nombre','QA empacador sin usuario','cliente','Ficticio'))->>'id')::uuid;
 UPDATE public.masiva_operaciones SET puntos_kit=10,penalizacion_error=3 WHERE id=op;
 persona := (public.masiva_ejecutar('guardar_personal',jsonb_build_object('nombre','QA nombre sin cuenta'))->>'id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_personal WHERE id=persona AND usuario_numero IS NULL) THEN RAISE EXCEPTION 'No se creó persona independiente'; END IF;
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op,'QA');
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre) SELECT op,'QA',g,'QA'||g,'Persona ficticia' FROM generate_series(1,2)g;
 r:=public.masiva_ejecutar('registrar_empaque',jsonb_build_object('operacion_id',op,'lista','QA','empacador_id',persona,'accion','registrar','alcance','todos','request_id',gen_random_uuid()));
 IF (r->>'kits')::int<>2 THEN RAISE EXCEPTION 'No atribuyó los dos kits'; END IF;
 r:=public.masiva_consultar(p_operacion=>op,p_vista=>'indicadores');
 SELECT value INTO fila FROM jsonb_array_elements(r->'filas') WHERE value->>'id'=persona::text;
 IF (fila->>'puntos')::int IS DISTINCT FROM 20 THEN RAISE EXCEPTION 'Puntaje incorrecto %',fila; END IF;
 INSERT INTO public.masiva_auditoria(operacion_id,accion,actor_id,actor_nombre,datos) VALUES(op,'reportar_error',actor,'QA',jsonb_build_object('empacador_id',persona));
 r:=public.masiva_consultar(p_operacion=>op,p_vista=>'indicadores');
 SELECT value INTO fila FROM jsonb_array_elements(r->'filas') WHERE value->>'id'=persona::text;
 IF (fila->>'puntos')::int IS DISTINCT FROM 17 THEN RAISE EXCEPTION 'Penalización incorrecta %',fila; END IF;
 RETURN jsonb_build_object('resultado','OK','sin_usuario',true,'kits',2,'puntos_iniciales',20,'puntos_con_penalizacion',17,'persistencia','ROLLBACK');
END $$;
SELECT pg_temp.probar_empacador();
ROLLBACK;
