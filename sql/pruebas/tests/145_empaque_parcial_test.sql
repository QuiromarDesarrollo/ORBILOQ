-- SOLO base local aislada o DEV confirmado. Requiere migración145. Nunca producción.
-- Los datos se crean con UUID nuevos y toda la transacción se revierte.
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.check145(ok boolean,msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '145: %',msg; END IF; END $$;
CREATE FUNCTION pg_temp.reject145(d jsonb,fragment text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE err text;
BEGIN
 BEGIN PERFORM public.masiva_ejecutar('registrar_empaque',d); EXCEPTION WHEN OTHERS THEN err:=SQLERRM; END;
 IF err IS NULL OR position(fragment IN err)=0 THEN RAISE EXCEPTION '145: esperaba %, recibió %',fragment,err; END IF;
END $$;
DO $$
DECLARE actor uuid; op uuid:=gen_random_uuid(); pa uuid:=gen_random_uuid(); pb uuid:=gen_random_uuid();
 a uuid; r jsonb; d jsonb; original jsonb; segundos_antes numeric; old_armado timestamptz; n integer;
BEGIN
 SELECT auth_id INTO actor FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND coalesce(roles,ARRAY[rol]) @> ARRAY['admin'] LIMIT 1;
 IF actor IS NULL THEN RAISE EXCEPTION 'Falta administrador de pruebas'; END IF;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 INSERT INTO public.masiva_operaciones(id,nombre,cliente,creado_por) VALUES(op,'Prueba145','Ficticio',actor);
 INSERT INTO public.masiva_personal(id,nombre,creado_por) VALUES(pa,'Operario A145',actor),(pb,'Operario B145',actor);
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op,'JORNADA'),(op,'SIN-RELOJ'),(op,'HUECOS');
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
 SELECT op,'JORNADA',g,'J'||g,'Persona'||g FROM generate_series(1,10)g;
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
 SELECT op,'SIN-RELOJ',g,'S'||g,'Persona'||g FROM generate_series(1,3)g;
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
 SELECT op,'HUECOS',g,'H'||g,'Persona'||g FROM unnest(ARRAY[1,2,5])g;
 d:=jsonb_build_object('operacion_id',op,'lista','JORNADA','empacador_id',pa,'accion','iniciar','alcance','rango','desde',1,'hasta',8,'request_id',gen_random_uuid());
 r:=public.masiva_ejecutar('registrar_empaque',d); a:=(r->>'asignacion_id')::uuid;
 PERFORM pg_temp.check145((r->>'kits')::int=8,'iniciar asigna ocho kits');
 UPDATE public.masiva_kits SET empacador_id=pb WHERE operacion_id=op AND lista='JORNADA' AND numero_persona>8;
 -- La validación paralela debe conservarse intacta al registrar empaque físico.
 UPDATE public.masiva_kits SET estado='validado',validacion_inicio=now(),validacion_fin=now(),validador_id=actor
 WHERE operacion_id=op AND lista='JORNADA' AND numero_persona=1;
 SELECT to_jsonb(k)-'armado'-'empacador_id' INTO original FROM public.masiva_kits k WHERE operacion_id=op AND lista='JORNADA' AND numero_persona=1;
 UPDATE public.masiva_asignaciones SET ultimo_inicio=clock_timestamp()-interval '10 seconds' WHERE id=a;
 d:=d||jsonb_build_object('accion','registrar','hasta',3,'request_id',gen_random_uuid());
 r:=public.masiva_ejecutar('registrar_empaque',d);
 PERFORM pg_temp.check145((r->>'kits')::int=3 AND (r->>'pendientes_lista')::int=7,'cierre parcial deja siete pendientes globales');
 PERFORM pg_temp.check145((SELECT estado='pausado' AND fin IS NULL AND segundos>=10 AND ultimo_inicio IS NULL FROM public.masiva_asignaciones WHERE id=a),'jornada parcial pausa reloj');
 PERFORM pg_temp.check145(original=(SELECT to_jsonb(k)-'armado'-'empacador_id' FROM public.masiva_kits k WHERE operacion_id=op AND lista='JORNADA' AND numero_persona=1),'no altera validación');
 SELECT segundos INTO segundos_antes FROM public.masiva_asignaciones WHERE id=a;
 SELECT armado INTO old_armado FROM public.masiva_kits WHERE operacion_id=op AND lista='JORNADA' AND numero_persona=1;
 PERFORM pg_temp.check145(public.masiva_ejecutar('registrar_empaque',d)=r,'reintento devuelve respuesta idéntica');
 PERFORM pg_temp.check145((SELECT count(*)=1 FROM public.masiva_auditoria WHERE operacion_id=op AND accion='registrar_empaque' AND datos->'entrada'->>'request_id'=d->>'request_id'),'reintento no duplica auditoría');
 PERFORM pg_temp.reject145(d||jsonb_build_object('hasta',4),'Identificador');
 PERFORM pg_temp.reject145(d||jsonb_build_object('desde',7,'hasta',9,'request_id',gen_random_uuid()),'otro empacador');
 PERFORM pg_temp.check145((SELECT count(*)=3 FROM public.masiva_kits WHERE operacion_id=op AND lista='JORNADA' AND armado IS NOT NULL),'rango cruzado rechaza atomicamente');
 PERFORM pg_temp.reject145(d||jsonb_build_object('desde',5,'hasta',4,'request_id',gen_random_uuid()),'Rango');
 PERFORM pg_temp.reject145(d||jsonb_build_object('desde','1.5','request_id',gen_random_uuid()),'enteros');
 PERFORM pg_temp.reject145((d-'hasta')||jsonb_build_object('request_id',gen_random_uuid()),'extremos');
 PERFORM pg_temp.reject145((d-'desde'-'hasta')||jsonb_build_object('alcance','todos','request_id',gen_random_uuid()),'terminados');
 d:=(d-'desde'-'hasta')||jsonb_build_object('alcance','pendientes','request_id',gen_random_uuid());
 r:=public.masiva_ejecutar('registrar_empaque',d);
 PERFORM pg_temp.check145((r->>'kits')::int=5 AND (r->>'pendientes_lista')::int=2,'pendientes excluye los dos de otro operario');
 PERFORM pg_temp.check145((SELECT estado='finalizado' AND fin IS NOT NULL AND masiva_asignaciones.segundos=segundos_antes FROM public.masiva_asignaciones WHERE id=a),'completa sin añadir tiempo pausado');
 PERFORM pg_temp.check145((SELECT armado=old_armado FROM public.masiva_kits WHERE operacion_id=op AND lista='JORNADA' AND numero_persona=1),'no altera fecha terminados');
 PERFORM pg_temp.check145((SELECT bool_and(empacador_id=pb AND armado IS NULL) FROM public.masiva_kits WHERE operacion_id=op AND lista='JORNADA' AND numero_persona>8),'otro operario intacto');
 d:=d||jsonb_build_object('lista','SIN-RELOJ','alcance','todos','request_id',gen_random_uuid());
 r:=public.masiva_ejecutar('registrar_empaque',d);
 PERFORM pg_temp.check145((r->>'kits')::int=3 AND NOT EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE operacion_id=op AND lista='SIN-RELOJ'),'registro directo no inventa reloj');
 d:=d||jsonb_build_object('lista','HUECOS','alcance','rango','desde',1,'hasta',5,'request_id',gen_random_uuid());
 r:=public.masiva_ejecutar('registrar_empaque',d);
 PERFORM pg_temp.check145((r->>'kits')::int=3 AND jsonb_array_length(r->'detalle')=3,'rango con huecos cuenta kits reales y audita ids');
 UPDATE public.masiva_operaciones SET estado='cerrada' WHERE id=op;
 PERFORM pg_temp.reject145(d||jsonb_build_object('request_id',gen_random_uuid()),'cerrada');
END $$;
ROLLBACK;
