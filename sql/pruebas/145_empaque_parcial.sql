-- Registro físico independiente de validación e inventario.
CREATE OR REPLACE FUNCTION public.masiva_empaque_consultar(p_operacion uuid,p_lista text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=p_operacion AND lista=trim(p_lista)) THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
 RETURN jsonb_build_object('lista',trim(p_lista),
 'total',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=p_operacion AND lista=trim(p_lista)),
 'terminados',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=p_operacion AND lista=trim(p_lista) AND armado IS NOT NULL),
 'pendientes',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=p_operacion AND lista=trim(p_lista) AND armado IS NULL),
 'kits',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',k.id,'numero_persona',k.numero_persona,'nombre',k.nombre,'armado',k.armado,'empacador_id',k.empacador_id,'empacador',p.nombre,'asignacion_id',k.asignacion_id) ORDER BY k.numero_persona),'[]') FROM public.masiva_kits k LEFT JOIN public.masiva_personal p ON p.id=k.empacador_id WHERE k.operacion_id=p_operacion AND k.lista=trim(p_lista)),
 'asignaciones',(SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.creado),'[]') FROM public.masiva_asignaciones a WHERE a.operacion_id=p_operacion AND a.lista=trim(p_lista)));
END $$;
REVOKE ALL ON FUNCTION public.masiva_empaque_consultar(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_empaque_consultar(uuid,text) TO authenticated;

-- Invocada sólo por masiva_ejecutar, que comprueba acceso, operación activa,
-- serializa por operación y conserva solicitud idempotente y auditoría.
CREATE OR REPLACE FUNCTION public.masiva_empaque_registrar_interno(d jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE op uuid:=(d->>'operacion_id')::uuid; persona uuid:=(d->>'empacador_id')::uuid;
 lista_ text:=trim(d->>'lista'); accion text:=d->>'accion'; alcance text:=d->>'alcance';
 ids uuid[]; aid uuid; a public.masiva_asignaciones; v_desde integer; v_hasta integer;
 instante timestamptz:=clock_timestamp(); evidencia jsonb; n integer;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.masiva_personal WHERE id=persona AND activo FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un empacador activo'; END IF;
 instante:=clock_timestamp();
 IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=op AND lista=lista_) THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
 IF accion IN('pausar','continuar') THEN
  SELECT * INTO a FROM public.masiva_asignaciones WHERE id=(d->>'asignacion_id')::uuid AND operacion_id=op AND lista=lista_ AND empacador_id=persona FOR UPDATE;
  IF a.id IS NULL THEN RAISE EXCEPTION 'Selecciona la asignación del empacador'; END IF;
  IF accion='pausar' THEN
   IF a.estado<>'en_curso' THEN RAISE EXCEPTION 'La asignación no está en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='pausado',segundos=segundos+extract(epoch FROM instante-ultimo_inicio),ultimo_inicio=NULL WHERE id=a.id;
  ELSE
   IF a.estado NOT IN('pausado','pendiente') THEN RAISE EXCEPTION 'La asignación no se puede continuar'; END IF;
   IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=persona AND estado='en_curso') THEN RAISE EXCEPTION 'El empacador tiene otra asignación en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='en_curso',inicio=coalesce(inicio,instante),ultimo_inicio=instante WHERE id=a.id;
  END IF;
  RETURN jsonb_build_object('asignacion_id',a.id,'accion',accion,'fecha',instante,'kits',0);
 END IF;
 IF accion IS NULL OR accion NOT IN('registrar','iniciar') OR alcance IS NULL OR alcance NOT IN('todos','rango','pendientes') THEN RAISE EXCEPTION 'Acción o alcance inválido'; END IF;
 IF alcance='rango' THEN
  IF coalesce(d->>'desde','') !~ '^[0-9]{1,7}$' OR coalesce(d->>'hasta','') !~ '^[0-9]{1,7}$' THEN RAISE EXCEPTION 'Indica ambos extremos enteros del rango'; END IF;
  v_desde:=(d->>'desde')::integer; v_hasta:=(d->>'hasta')::integer;
  IF v_desde<1 OR v_hasta<v_desde OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=op AND lista=lista_ AND numero_persona=v_desde) OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=op AND lista=lista_ AND numero_persona=v_hasta) THEN RAISE EXCEPTION 'Rango no válido para esta lista'; END IF;
 ELSE
  IF d ? 'desde' OR d ? 'hasta' THEN RAISE EXCEPTION 'El alcance completo o pendientes no admite rango'; END IF;
 END IF;
 SELECT array_agg(id ORDER BY numero_persona) INTO ids FROM public.masiva_kits
 WHERE operacion_id=op AND lista=lista_ AND
 (alcance='todos' OR (alcance='rango' AND numero_persona BETWEEN v_desde AND v_hasta) OR
 (alcance='pendientes' AND armado IS NULL AND (empacador_id IS NULL OR empacador_id=persona)));
 IF coalesce(cardinality(ids),0)=0 THEN RAISE EXCEPTION 'No hay kits disponibles para este registro'; END IF;
 PERFORM 1 FROM public.masiva_kits WHERE id=ANY(ids) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=ANY(ids) AND armado IS NOT NULL) THEN RAISE EXCEPTION 'Hay kits terminados: selecciona pendientes o un rango sin registrar'; END IF;
 IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=ANY(ids) AND empacador_id IS NOT NULL AND empacador_id<>persona) THEN RAISE EXCEPTION 'El rango contiene kits de otro empacador'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'numero_persona',numero_persona,'asignacion_id',asignacion_id) ORDER BY numero_persona),'[]') INTO evidencia FROM public.masiva_kits WHERE id=ANY(ids);
 IF accion='iniciar' THEN
  IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=persona AND estado='en_curso') THEN RAISE EXCEPTION 'El empacador tiene otra asignación en curso'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE id=ANY(ids) AND asignacion_id IS NOT NULL) THEN RAISE EXCEPTION 'Estos kits ya tienen asignación; usa Continuar'; END IF;
  SELECT min(numero_persona),max(numero_persona) INTO v_desde,v_hasta FROM public.masiva_kits WHERE id=ANY(ids);
  INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,estado,inicio,ultimo_inicio,creado_por)
  VALUES(op,lista_,persona,v_desde,v_hasta,'en_curso',instante,instante,auth.uid()) RETURNING id INTO aid;
  UPDATE public.masiva_kits SET empacador_id=persona,asignacion_id=aid,estado=CASE WHEN validacion_inicio IS NULL THEN 'armando' ELSE estado END WHERE id=ANY(ids);
 ELSE
  UPDATE public.masiva_kits SET empacador_id=persona,armado=instante,estado=CASE WHEN validacion_inicio IS NULL THEN 'armado' ELSE estado END WHERE id=ANY(ids);
  -- Cerrar la jornada de las asignaciones afectadas: los kits restantes siguen pendientes.
  FOR a IN SELECT * FROM public.masiva_asignaciones WHERE id IN(SELECT asignacion_id FROM public.masiva_kits WHERE id=ANY(ids)) ORDER BY id FOR UPDATE LOOP
   IF a.estado='finalizado' THEN RAISE EXCEPTION 'Asignación finalizada con kits pendientes; requiere revisión'; END IF;
   SELECT count(*) INTO n FROM public.masiva_kits WHERE asignacion_id=a.id AND armado IS NULL;
   UPDATE public.masiva_asignaciones SET estado=CASE WHEN n=0 THEN 'finalizado' ELSE 'pausado' END,
    fin=CASE WHEN n=0 THEN instante ELSE NULL END,
    segundos=segundos+CASE WHEN a.estado='en_curso' THEN extract(epoch FROM instante-a.ultimo_inicio) ELSE 0 END,ultimo_inicio=NULL WHERE id=a.id;
  END LOOP;
 END IF;
 RETURN jsonb_build_object('accion',accion,'kits',cardinality(ids),'kit_ids',ids,'detalle',evidencia,'empacador_id',persona,'asignacion_id',aid,'fecha',instante,
 'pendientes_lista',(SELECT count(*) FROM public.masiva_kits WHERE operacion_id=op AND lista=lista_ AND armado IS NULL));
END $$;
REVOKE ALL ON FUNCTION public.masiva_empaque_registrar_interno(jsonb) FROM PUBLIC,anon,authenticated;

-- Parche mínimo sobre la función vigente: conserva todas las demás acciones.
DO $patch$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure) INTO s;
 IF position('WHEN ''registrar_empaque'' THEN' IN s)>0 THEN RAISE EXCEPTION '145 ya aplicada'; END IF;
 IF position('IF p_accion IN(''recibir'',''validar'',''corregir'',''reportar_error'',''reiniciar_validacion'') THEN' IN s)=0 THEN RAISE EXCEPTION 'Versión no reconocida'; END IF;
 s:=replace(s,'IF p_accion IN(''recibir'',''validar'',''corregir'',''reportar_error'',''reiniciar_validacion'') THEN',
 'IF p_accion IN(''recibir'',''validar'',''corregir'',''reportar_error'',''reiniciar_validacion'',''registrar_empaque'') THEN');
 s:=replace(s,'CASE p_accion','CASE p_accion WHEN ''registrar_empaque'' THEN resultado:=public.masiva_empaque_registrar_interno(p_datos);');
 -- Compatibilidad con clientes anteriores: finalizar no altera fechas ya registradas.
 s:=replace(s,'armado=ahora WHERE asignacion_id=asig.id','armado=coalesce(armado,ahora) WHERE asignacion_id=asig.id');
 EXECUTE s;
END $patch$;
NOTIFY pgrst,'reload schema';
