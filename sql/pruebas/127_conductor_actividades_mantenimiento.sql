-- SOLO PRUEBAS. Aplicar después de 126. Actividades de mantenimiento asignadas.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;


ALTER TABLE public.conductor_tareas ALTER COLUMN registro_id DROP NOT NULL;
ALTER TABLE public.conductor_revision_eventos ALTER COLUMN registro_id DROP NOT NULL;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS vehiculo_id uuid REFERENCES public.conductor_vehiculos(id);
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_tipo text CHECK(mantenimiento_tipo IN('Mantenimiento preventivo','Mantenimiento correctivo'));
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_trabajo text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS servicio_id text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_datos jsonb;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_registro_id uuid REFERENCES public.conductor_registros(id);
ALTER TABLE public.conductor_revision_eventos ADD COLUMN IF NOT EXISTS vehiculo_id uuid REFERENCES public.conductor_vehiculos(id);
UPDATE public.conductor_tareas t SET vehiculo_id=r.vehiculo_id FROM public.conductor_registros r WHERE t.registro_id=r.id AND t.vehiculo_id IS NULL;
CREATE INDEX IF NOT EXISTS conductor_tareas_vehiculo_idx ON public.conductor_tareas(vehiculo_id,estado);
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('version',2,'estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND (t.estado<>'Cerrada' OR (p_detalle AND public.admin_es_admin()))),'[]'::jsonb));
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
CREATE OR REPLACE FUNCTION public.conductor_flota_resumen() RETURNS SETOF jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object(
 'conductor_nombre',coalesce(u.nombre,'Sin asignar'),'conductor_numero',u.numero_usuario,
 'inicio',s.id IS NOT NULL,'fin',EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=hoy),
 'autorizacion',CASE WHEN s.id IS NULL THEN 'Sin checklist' ELSE coalesce(a.estado,'Pendiente de aprobación') END,
 'pendientes',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Pendiente'),
 'por_verificar',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Por verificar'),
 'vencidas',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Pendiente' AND t.fecha_limite<hoy::date))
 FROM public.conductor_vehiculos v LEFT JOIN public.usuarios u ON u.auth_id=v.conductor_id
 LEFT JOIN public.conductor_registros s ON s.vehiculo_id=v.id AND s.tipo='Inicio de jornada' AND s.datos->>'fecha'=hoy
 LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=s.id ORDER BY v.placa;
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_mantenimiento_crear(
 p_vehiculo uuid,p_registro uuid,p_motivos text[],p_descripcion text,p_fecha date,
 p_tipo text,p_trabajo text,p_servicio text DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; r public.conductor_registros; nueva uuid; trabajo text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL THEN RAISE EXCEPTION 'Vehículo inexistente'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN('Mantenimiento preventivo','Mantenimiento correctivo') THEN RAISE EXCEPTION 'Selecciona el tipo de mantenimiento'; END IF;
 IF p_tipo='Mantenimiento preventivo' THEN
  trabajo:=CASE p_servicio
   WHEN 'limpieza' THEN 'Limpieza general del vehículo'
   WHEN 'limpiabrisas' THEN 'Llenado de tanque de agua para limpiabrisas'
   WHEN 'combustible' THEN 'Llenado de tanque de combustible'
   WHEN 'aceite' THEN 'Cambio de aceite'
   WHEN 'refrigerante' THEN 'Llenado de líquido refrigerante'
   WHEN 'neumaticos' THEN 'Cambio de neumáticos'
   WHEN 'discos' THEN 'Cambio de disco de frenos'
   WHEN 'calibracion' THEN 'Calibración de aire en los neumáticos'
   WHEN 'revision_preventiva' THEN 'Revisión preventiva' END;
  IF trabajo IS NULL OR trabajo IS DISTINCT FROM p_trabajo THEN RAISE EXCEPTION 'Mantenimiento preventivo inválido'; END IF;
 ELSE
  trabajo:=trim(p_trabajo);
  IF trabajo IS NULL OR length(trabajo) NOT BETWEEN 1 AND 1000 OR p_servicio IS NOT NULL THEN RAISE EXCEPTION 'Describe el mantenimiento correctivo'; END IF;
 END IF;
 IF p_registro IS NOT NULL THEN
  SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
  IF r.vehiculo_id IS DISTINCT FROM p_vehiculo THEN RAISE EXCEPTION 'El checklist no corresponde al vehículo'; END IF;
  nueva:=public.conductor_actividad_crear(p_registro,p_motivos,p_descripcion,p_fecha);
 ELSE
  IF coalesce(cardinality(p_motivos),0)<>0 THEN RAISE EXCEPTION 'La actividad independiente no tiene motivos del checklist'; END IF;
  IF p_fecha IS NULL OR p_fecha<(now() AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'Fecha límite inválida'; END IF;
  IF p_descripcion IS NULL OR length(trim(p_descripcion)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la actividad'; END IF;
  INSERT INTO public.conductor_tareas(vehiculo_id,punto,motivos,descripcion,fecha_limite,creador)
   VALUES(v.id,gen_random_uuid()::text,'[]',trim(p_descripcion),p_fecha,auth.uid()) RETURNING id INTO nueva;
 END IF;
 UPDATE public.conductor_tareas SET vehiculo_id=v.id,mantenimiento_tipo=p_tipo,mantenimiento_trabajo=trabajo,servicio_id=p_servicio WHERE id=nueva;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos)
  VALUES(p_registro,v.id,auth.uid(),'Asignar mantenimiento',jsonb_build_object('tarea',nueva,'tipo',p_tipo,'trabajo',trabajo,'servicio_id',p_servicio));
 RETURN nueva;
END $$;

-- La entrega y el mantenimiento se guardan en una misma transacción.
CREATE OR REPLACE FUNCTION public.conductor_vincular_mantenimiento() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 IF NEW.datos->>'actividad_id' IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=NEW.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=(NEW.datos->>'actividad_id')::uuid FOR UPDATE;
 IF t.id IS NULL OR t.vehiculo_id IS DISTINCT FROM NEW.vehiculo_id OR t.estado<>'Pendiente' THEN RAISE EXCEPTION 'Actividad inexistente o no pendiente'; END IF;
 IF t.mantenimiento_tipo IS NULL OR t.mantenimiento_tipo IS DISTINCT FROM NEW.tipo
  OR t.mantenimiento_trabajo IS DISTINCT FROM NEW.datos->>'servicio'
  OR (NEW.tipo='Mantenimiento preventivo' AND t.servicio_id IS DISTINCT FROM NEW.datos->>'servicio_id') THEN
  RAISE EXCEPTION 'El mantenimiento no coincide con lo asignado por el administrador';
 END IF;
 IF NOT (NEW.datos ?& ARRAY['fecha_inicio','hora_inicio','fecha_fin','hora_fin']) THEN RAISE EXCEPTION 'Completa las fechas y horas del mantenimiento'; END IF;
 IF coalesce(NEW.datos->>'enlace','') !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta evidencia del mantenimiento'; END IF;
 IF NEW.tipo='Mantenimiento preventivo' AND t.servicio_id='combustible' THEN
  IF coalesce(NEW.datos->>'galones','') !~ '^[0-9]+([.][0-9]+)?$' OR (NEW.datos->>'galones')::numeric<=0 THEN RAISE EXCEPTION 'Ingresa los galones del tanqueo'; END IF;
 END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=NEW.datos->>'servicio',
  evidencia=NEW.datos->>'enlace',entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now(),mantenimiento_registro_id=NEW.id,mantenimiento_datos=NEW.datos WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos)
  VALUES(t.registro_id,v.id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'mantenimiento_registro_id',NEW.id));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS conductor_vincular_mantenimiento ON public.conductor_registros;
CREATE TRIGGER conductor_vincular_mantenimiento AFTER INSERT ON public.conductor_registros FOR EACH ROW EXECUTE FUNCTION public.conductor_vincular_mantenimiento();
CREATE OR REPLACE FUNCTION public.conductor_revision_accion(p_registro uuid,p_accion text,p_texto text,p_punto text DEFAULT NULL,p_tarea uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; t public.conductor_tareas; es_admin boolean:=public.admin_es_admin(); valor jsonb;
BEGIN
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 IF p_tarea IS NOT NULL THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea;
  IF t.registro_id IS DISTINCT FROM p_registro THEN RAISE EXCEPTION 'Actividad incorrecta'; END IF;
 END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=coalesce(t.vehiculo_id,r.vehiculo_id) FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Escribe una observación de hasta 1000 caracteres'; END IF;
 IF p_accion IN('Autorizado','No autorizado') THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.id IS NULL OR r.tipo<>'Inicio de jornada' OR r.datos->>'fecha'<>to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD') THEN RAISE EXCEPTION 'Solo se autoriza la salida de hoy'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion IN('Crear actividad','Por verificar') THEN
  RAISE EXCEPTION 'Actualiza la aplicación para asignar actividades con fecha y foto';
 ELSIF p_accion IN('Por verificar','Cerrada','Pendiente') THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea AND registro_id IS NOT DISTINCT FROM p_registro FOR UPDATE;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Actividad inexistente'; END IF;
  IF p_accion='Por verificar' THEN
   IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya fue reportada'; END IF;
  ELSE
   IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
   IF t.estado<>'Por verificar' THEN RAISE EXCEPTION 'La actividad no está pendiente de verificación'; END IF;
  END IF;
  UPDATE public.conductor_tareas SET estado=p_accion,respuesta=trim(p_texto),actualizado=now() WHERE id=t.id;
 ELSE RAISE EXCEPTION 'Acción inválida'; END IF;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos) VALUES(r.id,v.id,auth.uid(),p_accion,jsonb_build_object('texto',trim(p_texto),'punto',p_punto,'tarea',p_tarea));
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_entregar(p_tarea uuid,p_texto text,p_evidencia text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 SELECT v1.* INTO v FROM public.conductor_vehiculos v1 JOIN public.conductor_registros r ON r.vehiculo_id=v1.id JOIN public.conductor_tareas t1 ON t1.registro_id=r.id WHERE t1.id=p_tarea FOR UPDATE OF v1;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea FOR UPDATE;
 IF t.mantenimiento_tipo IS NOT NULL THEN RAISE EXCEPTION 'Completa el formulario de mantenimiento asignado'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la solución'; END IF;
 IF p_evidencia IS NULL OR p_evidencia !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta la foto de la actividad realizada'; END IF;
 IF t.estado='Por verificar' AND t.evidencia=p_evidencia AND t.solucion=trim(p_texto) AND t.entregado_por=auth.uid() THEN RETURN; END IF;
 IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya no está pendiente'; END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=trim(p_texto),evidencia=p_evidencia,entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now() WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(t.registro_id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'solucion',trim(p_texto),'evidencia',p_evidencia));
END $$;

REVOKE ALL ON FUNCTION public.conductor_actividad_mantenimiento_crear(uuid,uuid,text[],text,date,text,text,text),public.conductor_vincular_mantenimiento() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_actividad_mantenimiento_crear(uuid,uuid,text[],text,date,text,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
