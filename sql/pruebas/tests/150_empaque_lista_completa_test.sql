-- SOLO DEV confirmado o base local aislada. Datos ficticios, reversión completa.
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.check150(ok boolean,msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '150: %',msg; END IF; END $$;
DO $$
DECLARE actor uuid; op uuid:=gen_random_uuid(); pa uuid:=gen_random_uuid(); pb uuid:=gen_random_uuid();
 d jsonb; r jsonb; antes jsonb; fecha timestamptz:=now()-interval '1 hour'; aid uuid; err text; eventos integer;
BEGIN
 SELECT auth_id INTO actor FROM public.usuarios WHERE activo AND auth_id IS NOT NULL AND coalesce(roles,ARRAY[rol]) @> ARRAY['admin'] LIMIT 1;
 IF actor IS NULL THEN RAISE EXCEPTION 'Falta administrador de pruebas'; END IF;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 INSERT INTO public.masiva_operaciones(id,nombre,cliente,creado_por) VALUES(op,'Prueba150','Ficticio',actor);
 INSERT INTO public.masiva_personal(id,nombre,creado_por) VALUES(pa,'Operario A150',actor),(pb,'Operario B150',actor);
 INSERT INTO public.masiva_listas(operacion_id,lista) VALUES(op,'COMPLETA'),(op,'OTRA');
 INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,estado,segundos,inicio,fin,creado_por)
 VALUES(op,'COMPLETA',pb,1,1,'finalizado',90,fecha-interval '90 seconds',fecha,actor) RETURNING id INTO aid;
 INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre,empacador_id,armado,estado,asignacion_id,validacion_inicio,validador_id)
 SELECT op,'COMPLETA',g,'FICTICIO'||g,'Persona'||g,CASE WHEN g=1 THEN pb ELSE pa END,
 CASE WHEN g=1 THEN fecha END,CASE WHEN g=1 THEN 'validado' ELSE 'pendiente' END,
 CASE WHEN g=1 THEN aid END,CASE WHEN g=1 THEN fecha END,CASE WHEN g=1 THEN actor END FROM generate_series(1,4)g;
 SELECT jsonb_agg(to_jsonb(k)-'armado'-'empacador_id'-'estado' ORDER BY id) INTO antes FROM public.masiva_kits k WHERE operacion_id=op;
 d:=jsonb_build_object('operacion_id',op,'lista','COMPLETA','empacador_id',pa,'accion','registrar','alcance','todos','request_id',gen_random_uuid());
 BEGIN PERFORM public.masiva_ejecutar('registrar_empaque',d); EXCEPTION WHEN OTHERS THEN err:=SQLERRM; END;
 PERFORM pg_temp.check150(err LIKE '%Confirma el responsable%','cliente sin confirmación no reasigna');
 d:=d||jsonb_build_object('confirmar_responsable',true,'kits_esperados',
 (SELECT jsonb_agg(jsonb_build_object('id',id,'empacador_id',empacador_id,'asignacion_id',asignacion_id,'armado',armado)) FROM public.masiva_kits WHERE operacion_id=op));
 err:=NULL;
 BEGIN PERFORM public.masiva_ejecutar('registrar_empaque',d||jsonb_build_object('kits_esperados','[]'::jsonb)); EXCEPTION WHEN OTHERS THEN err:=SQLERRM; END;
 PERFORM pg_temp.check150(err LIKE '%cambió en otra estación%','snapshot obsoleto rechazado');
 r:=public.masiva_ejecutar('registrar_empaque',d);
 PERFORM pg_temp.check150(r->>'kits'='4' AND r->>'total_lista'='4' AND r->>'nuevos'='3' AND r->>'reasignados'='1','conteos reales');
 PERFORM pg_temp.check150((SELECT bool_and(empacador_id=pa AND armado IS NOT NULL) FROM public.masiva_kits WHERE operacion_id=op),'todos al responsable');
 PERFORM pg_temp.check150((SELECT armado=fecha AND estado='validado' FROM public.masiva_kits WHERE operacion_id=op AND numero_persona=1),'fecha y validación conservadas');
 PERFORM pg_temp.check150(antes=(SELECT jsonb_agg(to_jsonb(k)-'armado'-'empacador_id'-'estado' ORDER BY id) FROM public.masiva_kits k WHERE operacion_id=op),'otros campos intactos');
 PERFORM pg_temp.check150((SELECT empacador_id=pa AND segundos=90 AND fin=fecha FROM public.masiva_asignaciones WHERE id=aid),'jornada conserva tiempos');
 SELECT count(*) INTO eventos FROM public.masiva_auditoria WHERE operacion_id=op;
 PERFORM pg_temp.check150(public.masiva_ejecutar('registrar_empaque',d)=r,'reintento idéntico');
 PERFORM pg_temp.check150(eventos=(SELECT count(*) FROM public.masiva_auditoria WHERE operacion_id=op),'sin auditoría duplicada');
 PERFORM pg_temp.check150((SELECT count(*)=1 FROM public.masiva_auditoria WHERE operacion_id=op AND accion='confirmar_responsable_lista_completa' AND jsonb_array_length(datos->'antes')=4),'historial antes/después');
END $$;
ROLLBACK;
SELECT '150: pruebas completas, datos ficticios revertidos' AS resultado;
