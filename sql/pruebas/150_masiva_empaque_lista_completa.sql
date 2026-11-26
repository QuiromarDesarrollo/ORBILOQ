-- Aplicar primero en DEV. No modifica registros existentes al instalarse.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
CREATE OR REPLACE FUNCTION public.masiva_empaque_lista_completa_interno(d jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE op uuid:=(d->>'operacion_id')::uuid; persona uuid:=(d->>'empacador_id')::uuid;
 lista_ text:=trim(d->>'lista'); actual jsonb; esperado jsonb; antes jsonb; despues jsonb;
 ids uuid[]; instante timestamptz:=clock_timestamp(); nuevos integer; cambios integer;
 a public.masiva_asignaciones;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva' USING ERRCODE='42501'; END IF;
 IF d->>'accion' IS DISTINCT FROM 'registrar' OR d->>'alcance' IS DISTINCT FROM 'todos'
 OR d->>'confirmar_responsable' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Confirma el responsable de toda la lista'; END IF;
 IF d ? 'desde' OR d ? 'hasta' THEN RAISE EXCEPTION 'Toda la lista no admite rango'; END IF;
 PERFORM 1 FROM public.masiva_personal WHERE id=persona AND activo FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un empacador activo'; END IF;
 -- masiva_ejecutar ya bloquea la operación y comprueba estado y request_id.
 PERFORM 1 FROM public.masiva_kits WHERE operacion_id=op AND lista=lista_ ORDER BY id FOR UPDATE;
 SELECT array_agg(id ORDER BY numero_persona),
 jsonb_agg(jsonb_build_object('id',id,'empacador_id',empacador_id,'asignacion_id',asignacion_id,'armado',armado) ORDER BY id),
 jsonb_agg(to_jsonb(k) ORDER BY id),count(*) FILTER(WHERE armado IS NULL),
 count(*) FILTER(WHERE empacador_id IS NOT NULL AND empacador_id<>persona)
 INTO ids,actual,antes,nuevos,cambios FROM public.masiva_kits k WHERE operacion_id=op AND lista=lista_;
 IF coalesce(cardinality(ids),0)=0 THEN RAISE EXCEPTION 'Lista sin kits'; END IF;
 IF jsonb_typeof(d->'kits_esperados') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Actualiza la aplicación y consulta la lista antes de registrar'; END IF;
 SELECT jsonb_agg(jsonb_build_object('id',(f->>'id')::uuid,'empacador_id',(f->>'empacador_id')::uuid,
 'asignacion_id',(f->>'asignacion_id')::uuid,'armado',(f->>'armado')::timestamptz) ORDER BY (f->>'id')::uuid)
 INTO esperado FROM jsonb_array_elements(d->'kits_esperados') f;
 IF actual IS DISTINCT FROM esperado THEN RAISE EXCEPTION 'La lista cambió en otra estación. Consulta y confirma nuevamente antes de registrar'; END IF;
 -- Se conserva la jornada real y su historial, sin dejar vínculos a otro responsable.
 FOR a IN SELECT * FROM public.masiva_asignaciones WHERE id IN
 (SELECT asignacion_id FROM public.masiva_kits WHERE id=ANY(ids)) ORDER BY id FOR UPDATE LOOP
  IF a.operacion_id<>op OR a.lista<>lista_ OR EXISTS
  (SELECT 1 FROM public.masiva_kits WHERE asignacion_id=a.id AND NOT(id=ANY(ids)))
  THEN RAISE EXCEPTION 'Asignación compartida fuera de esta lista; requiere revisión'; END IF;
  UPDATE public.masiva_asignaciones SET empacador_id=persona,estado='finalizado',
   fin=coalesce(fin,instante),
   segundos=segundos+CASE WHEN a.estado='en_curso' THEN extract(epoch FROM instante-a.ultimo_inicio) ELSE 0 END,
   ultimo_inicio=NULL WHERE id=a.id;
  INSERT INTO public.masiva_auditoria(operacion_id,accion,actor_id,actor_nombre,datos)
  VALUES(op,'corregir_asignacion_lista_completa',auth.uid(),(SELECT nombre FROM public.usuarios WHERE auth_id=auth.uid()),jsonb_build_object('lista',lista_,'antes',to_jsonb(a),
   'despues',(SELECT to_jsonb(s) FROM public.masiva_asignaciones s WHERE id=a.id),'request_id',d->>'request_id'));
 END LOOP;
 UPDATE public.masiva_kits SET empacador_id=persona,armado=coalesce(armado,instante),
 estado=CASE WHEN armado IS NULL AND validacion_inicio IS NULL THEN 'armado' ELSE estado END WHERE id=ANY(ids);
 SELECT jsonb_agg(to_jsonb(k) ORDER BY id) INTO despues FROM public.masiva_kits k WHERE id=ANY(ids);
 INSERT INTO public.masiva_auditoria(operacion_id,accion,actor_id,actor_nombre,datos)
 VALUES(op,'confirmar_responsable_lista_completa',auth.uid(),(SELECT nombre FROM public.usuarios WHERE auth_id=auth.uid()),jsonb_build_object('lista',lista_,'antes',antes,
 'despues',despues,'request_id',d->>'request_id','empacador_id',persona));
 RETURN jsonb_build_object('accion','registrar','kits',cardinality(ids),'total_lista',cardinality(ids),
 'nuevos',nuevos,'reasignados',cambios,'kit_ids',ids,'empacador_id',persona,'fecha',instante,'pendientes_lista',0);
END $$;
REVOKE ALL ON FUNCTION public.masiva_empaque_lista_completa_interno(jsonb) FROM PUBLIC,anon,authenticated;
DO $patch$
DECLARE f text; patron text;
BEGIN
 f:=pg_get_functiondef('public.masiva_empaque_registrar_interno(jsonb)'::regprocedure);
 IF position('masiva150_lista_completa' IN f)>0 THEN RETURN; END IF;
 patron:='IF accion IS NULL OR accion NOT IN(''registrar'',''iniciar'')';
 IF position(patron IN f)=0 OR position('''kits'',cardinality(ids)' IN f)=0 THEN RAISE EXCEPTION 'Función de empaque no reconocida'; END IF;
 f:=replace(f,patron,$body$-- masiva150_lista_completa
 IF accion='registrar' AND alcance='todos' THEN
  RETURN public.masiva_empaque_lista_completa_interno(d);
 END IF;
 IF accion IS NULL OR accion NOT IN('registrar','iniciar')$body$);
 f:=replace(f,'''kits'',cardinality(ids)',
 '''kits'',cardinality(ids),''total_lista'',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=op AND lista=lista_)');
 EXECUTE f;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
