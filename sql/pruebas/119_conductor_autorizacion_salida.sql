-- SOLO PRUEBAS. Aplicar después de 118. No modifica checklists existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.conductor_autorizaciones (
 registro_id uuid PRIMARY KEY REFERENCES public.conductor_registros(id),
 estado text NOT NULL CHECK(estado IN('Autorizado','No autorizado')),
 observacion text NOT NULL CHECK(length(observacion) BETWEEN 1 AND 1000),
 administrador uuid NOT NULL REFERENCES auth.users(id), actualizado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.conductor_tareas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), registro_id uuid NOT NULL REFERENCES public.conductor_registros(id),
 punto text NOT NULL, descripcion text NOT NULL CHECK(length(descripcion) BETWEEN 1 AND 1000),
 estado text NOT NULL DEFAULT 'Pendiente' CHECK(estado IN('Pendiente','Por verificar','Cerrada')),
 respuesta text, creador uuid NOT NULL REFERENCES auth.users(id), creado timestamptz NOT NULL DEFAULT now(),
 actualizado timestamptz NOT NULL DEFAULT now(), UNIQUE(registro_id,punto)
);
CREATE TABLE IF NOT EXISTS public.conductor_revision_eventos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), registro_id uuid NOT NULL REFERENCES public.conductor_registros(id),
 actor uuid NOT NULL REFERENCES auth.users(id), creado timestamptz NOT NULL DEFAULT now(), accion text NOT NULL, datos jsonb NOT NULL
);
ALTER TABLE public.conductor_autorizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_tareas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_revision_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.conductor_autorizaciones,public.conductor_tareas,public.conductor_revision_eventos FROM anon,authenticated;
-- Solo RPC: el conductor recibe estado y tareas, nunca las respuestas completas del checklist.
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado<>'Cerrada'),'[]'::jsonb));
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
  IF p_accion='Autorizado' AND EXISTS(SELECT 1 FROM public.conductor_tareas x JOIN public.conductor_registros y ON y.id=x.registro_id WHERE y.vehiculo_id=v.id AND x.estado<>'Cerrada') THEN RAISE EXCEPTION 'Verifica y cierra las actividades pendientes antes de autorizar'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion='Crear actividad' THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.tipo NOT IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera') THEN RAISE EXCEPTION 'No es un checklist'; END IF;
  valor:=r.datos->'respuestas'->p_punto;
  IF valor IS DISTINCT FROM '"Con novedad"'::jsonb AND valor->>'estado' IS DISTINCT FROM 'Con novedad' THEN RAISE EXCEPTION 'El punto no tiene novedad'; END IF;
  INSERT INTO public.conductor_tareas(registro_id,punto,descripcion,creador) VALUES(r.id,p_punto,trim(p_texto),auth.uid());
  -- Una actividad nueva retira cualquier autorización de hoy hasta verificarla.
  UPDATE public.conductor_autorizaciones a SET estado='No autorizado',observacion='Actividad correctiva pendiente: '||p_punto,administrador=auth.uid(),actualizado=now() FROM public.conductor_registros x WHERE x.id=a.registro_id AND x.vehiculo_id=v.id AND x.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
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
REVOKE ALL ON FUNCTION public.conductor_revision_resumen(uuid,boolean),public.conductor_revision_accion(uuid,text,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_revision_resumen(uuid,boolean),public.conductor_revision_accion(uuid,text,text,text,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
