-- SOLO PRUEBAS. Aplicar después de 122. Panel administrativo de flota y reasignación.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo pruebas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;


ALTER TABLE public.conductor_vehiculos ALTER COLUMN conductor_id DROP NOT NULL;
CREATE OR REPLACE FUNCTION public.conductor_flota_resumen() RETURNS SETOF jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object(
 'conductor_nombre',coalesce(u.nombre,'Sin asignar'),'conductor_numero',u.numero_usuario,
 'inicio',s.id IS NOT NULL,'fin',EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=hoy),
 'autorizacion',CASE WHEN s.id IS NULL THEN 'Sin checklist' ELSE coalesce(a.estado,'Pendiente de aprobación') END,
 'pendientes',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Pendiente'),
 'por_verificar',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Por verificar'),
 'vencidas',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Pendiente' AND t.fecha_limite<hoy::date))
 FROM public.conductor_vehiculos v LEFT JOIN public.usuarios u ON u.auth_id=v.conductor_id
 LEFT JOIN public.conductor_registros s ON s.vehiculo_id=v.id AND s.tipo='Inicio de jornada' AND s.datos->>'fecha'=hoy
 LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=s.id ORDER BY v.placa;
END $$;
REVOKE ALL ON FUNCTION public.conductor_flota_resumen() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_flota_resumen() TO authenticated;
CREATE OR REPLACE FUNCTION public.conductor_asignar_vehiculo(p_placa text,p_descripcion text,p_km integer,p_numero text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE conductor uuid; vehiculo uuid; anterior jsonb; actor text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT auth_id INTO conductor FROM public.usuarios WHERE numero_usuario=p_numero AND activo
 AND 'conductor'=ANY(coalesce(roles,ARRAY[rol]));
 IF conductor IS NULL THEN RAISE EXCEPTION 'Conductor inexistente o inactivo'; END IF;
 IF p_km IS NULL OR p_km<0 THEN RAISE EXCEPTION 'Kilometraje invalido'; END IF;
 -- Serializa reasignaciones y conserva los registros con su actor original.
 PERFORM pg_advisory_xact_lock(123,1);
 PERFORM 1 FROM public.conductor_vehiculos WHERE conductor_id=conductor OR placa=upper(trim(p_placa)) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.conductor_vehiculos v WHERE (v.conductor_id=conductor OR v.placa=upper(trim(p_placa)))
  AND (v.placa<>upper(trim(p_placa)) OR v.conductor_id IS DISTINCT FROM conductor)
  AND EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Inicio de jornada' AND r.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD'))
  AND NOT EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD')))
 THEN RAISE EXCEPTION 'Finaliza la jornada abierta antes de cambiar la asignación'; END IF;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 SELECT id,auth.uid(),actor,'Asignación',km,jsonb_build_object('conductor_anterior',conductor_id,'conductor_nuevo',NULL,'motivo','Cambio de vehículo entre jornadas')
 FROM public.conductor_vehiculos WHERE conductor_id=conductor AND placa<>upper(trim(p_placa));
 UPDATE public.conductor_vehiculos SET conductor_id=NULL,datos=datos-'Licencia de conducción',actualizado=now() WHERE conductor_id=conductor AND placa<>upper(trim(p_placa));

 SELECT to_jsonb(v) INTO anterior FROM public.conductor_vehiculos v WHERE placa=upper(trim(p_placa)) FOR UPDATE;
 IF anterior IS NOT NULL AND p_km<(anterior->>'km')::integer THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 INSERT INTO public.conductor_vehiculos(placa,descripcion,conductor_id,km)
 VALUES(upper(trim(p_placa)),trim(p_descripcion),conductor,p_km)
 ON CONFLICT(placa) DO UPDATE SET conductor_id=excluded.conductor_id,descripcion=excluded.descripcion,
 km=greatest(conductor_vehiculos.km,excluded.km),
 datos=CASE WHEN conductor_vehiculos.conductor_id IS DISTINCT FROM excluded.conductor_id
 THEN conductor_vehiculos.datos-'Licencia de conducción' ELSE conductor_vehiculos.datos END,actualizado=now()
 RETURNING id INTO vehiculo;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(vehiculo,auth.uid(),actor,'Asignación',p_km,
 jsonb_build_object('conductor_anterior',anterior->>'conductor_id','conductor_nuevo',conductor));
 RETURN vehiculo;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
