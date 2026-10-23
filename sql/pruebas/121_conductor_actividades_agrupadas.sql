-- SOLO PRUEBAS. Aplicar después de 119. Autorización independiente de las actividades.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;

ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS motivos jsonb;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS fecha_limite date;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS evidencia text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS entregado_en timestamptz;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS entregado_por uuid REFERENCES auth.users(id);
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS solucion text;
UPDATE public.conductor_tareas SET motivos=jsonb_build_array(punto) WHERE motivos IS NULL;
ALTER TABLE public.conductor_tareas ALTER COLUMN motivos SET NOT NULL;
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('version',2,'estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND (t.estado<>'Cerrada' OR (p_detalle AND public.admin_es_admin()))),'[]'::jsonb));
 IF p_detalle AND public.admin_es_admin() THEN
  SELECT coalesce(jsonb_agg(q ORDER BY q.creado DESC),'[]'::jsonb) INTO revisiones FROM (
   SELECT r.id,r.tipo,r.creado,r.actor_nombre,r.datos,coalesce(a.estado,'Pendiente de aprobación') AS estado
   FROM public.conductor_registros r LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=r.id
   WHERE r.vehiculo_id=v.id AND r.tipo IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera')
   ORDER BY r.creado DESC LIMIT 100
  ) q;
  resultado:=resultado || jsonb_build_object('checklists',revisiones);
 END IF;
 RETURN resultado;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_revision_accion(p_registro uuid,p_accion text,p_texto text,p_punto text DEFAULT NULL,p_tarea uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; t public.conductor_tareas; es_admin boolean:=public.admin_es_admin(); valor jsonb;
BEGIN
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=r.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Escribe una observación de hasta 1000 caracteres'; END IF;
 IF p_accion IN('Autorizado','No autorizado') THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.tipo<>'Inicio de jornada' OR r.datos->>'fecha'<>to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD') THEN RAISE EXCEPTION 'Solo se autoriza la salida de hoy'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion IN('Crear actividad','Por verificar') THEN
  RAISE EXCEPTION 'Actualiza la aplicación para asignar actividades con fecha y foto';
 ELSIF p_accion IN('Por verificar','Cerrada','Pendiente') THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea AND registro_id=r.id FOR UPDATE;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Actividad inexistente'; END IF;
  IF p_accion='Por verificar' THEN
   IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya fue reportada'; END IF;
  ELSE
   IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
   IF t.estado<>'Por verificar' THEN RAISE EXCEPTION 'La actividad no está pendiente de verificación'; END IF;
  END IF;
  UPDATE public.conductor_tareas SET estado=p_accion,respuesta=trim(p_texto),actualizado=now() WHERE id=t.id;
 ELSE RAISE EXCEPTION 'Acción inválida'; END IF;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(r.id,auth.uid(),p_accion,jsonb_build_object('texto',trim(p_texto),'punto',p_punto,'tarea',p_tarea));
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_crear(p_registro uuid,p_motivos text[],p_descripcion text,p_fecha date) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; v_punto text; valor jsonb; nueva uuid;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=r.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR r.tipo NOT IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera') THEN RAISE EXCEPTION 'Checklist inexistente'; END IF;
 IF p_fecha IS NULL OR p_fecha<(now() AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'La fecha límite no puede estar en el pasado'; END IF;
 IF p_descripcion IS NULL OR length(trim(p_descripcion)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la actividad (máximo 1000 caracteres)'; END IF;
 IF p_motivos IS NULL OR cardinality(p_motivos) NOT BETWEEN 1 AND 50 OR array_ndims(p_motivos)<>1 OR array_position(p_motivos,NULL) IS NOT NULL THEN RAISE EXCEPTION 'Selecciona los motivos de corrección'; END IF;
 IF cardinality(p_motivos)<>(SELECT count(DISTINCT x) FROM unnest(p_motivos) x) THEN RAISE EXCEPTION 'Motivos duplicados'; END IF;
 FOREACH v_punto IN ARRAY p_motivos LOOP
  valor:=r.datos->'respuestas'->v_punto;
  IF valor IS DISTINCT FROM '"Con novedad"'::jsonb AND valor->>'estado' IS DISTINCT FROM 'Con novedad' THEN RAISE EXCEPTION 'Punto sin novedad: %',v_punto; END IF;
  IF EXISTS(SELECT 1 FROM public.conductor_tareas WHERE registro_id=r.id AND estado<>'Cerrada' AND motivos ? v_punto) THEN RAISE EXCEPTION 'Ya existe una actividad abierta para %',v_punto; END IF;
 END LOOP;
 INSERT INTO public.conductor_tareas(registro_id,punto,motivos,descripcion,fecha_limite,creador)
 VALUES(r.id,gen_random_uuid()::text,to_jsonb(p_motivos),trim(p_descripcion),p_fecha,auth.uid()) RETURNING id INTO nueva;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(r.id,auth.uid(),'Crear actividad',jsonb_build_object('tarea',nueva,'motivos',p_motivos,'descripcion',trim(p_descripcion),'fecha_limite',p_fecha));
 RETURN nueva;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_actividad_entregar(p_tarea uuid,p_texto text,p_evidencia text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 SELECT v1.* INTO v FROM public.conductor_vehiculos v1 JOIN public.conductor_registros r ON r.vehiculo_id=v1.id JOIN public.conductor_tareas t1 ON t1.registro_id=r.id WHERE t1.id=p_tarea FOR UPDATE OF v1;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea FOR UPDATE;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la solución'; END IF;
 IF p_evidencia IS NULL OR p_evidencia !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta la foto de la actividad realizada'; END IF;
 IF t.estado='Por verificar' AND t.evidencia=p_evidencia AND t.solucion=trim(p_texto) AND t.entregado_por=auth.uid() THEN RETURN; END IF;
 IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya no está pendiente'; END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=trim(p_texto),evidencia=p_evidencia,entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now() WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(t.registro_id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'solucion',trim(p_texto),'evidencia',p_evidencia));
END $$;
REVOKE ALL ON FUNCTION public.conductor_actividad_crear(uuid,text[],text,date),public.conductor_actividad_entregar(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_actividad_crear(uuid,text[],text,date),public.conductor_actividad_entregar(uuid,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
