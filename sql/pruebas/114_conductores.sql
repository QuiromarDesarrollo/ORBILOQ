-- SOLO ORBILOQ-DEV. No aplicar en producción.
-- Después de 113. Actualizar admin-crear-usuario únicamente en DEV.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe'
 THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;

ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
 CHECK(rol IN('admin','seguimiento','produccion','logistica','despacho','gerencia','conductor'));
CREATE OR REPLACE FUNCTION public.usuario_roles_normalizar(p_roles text[]) RETURNS text[]
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE resultado text[];
BEGIN
 IF p_roles IS NULL OR cardinality(p_roles) NOT BETWEEN 1 AND 7 OR array_ndims(p_roles)<>1
 OR array_position(p_roles,NULL) IS NOT NULL
 OR NOT p_roles <@ ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor']::text[]
 THEN RAISE EXCEPTION 'Selecciona al menos un perfil valido.'; END IF;
 SELECT array_agg(r ORDER BY n) INTO resultado FROM
 unnest(ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor'])
 WITH ORDINALITY AS t(r,n) WHERE r=ANY(p_roles);
 RETURN resultado;
END $$;

CREATE TABLE public.conductor_vehiculos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 placa text UNIQUE NOT NULL CHECK(length(placa) BETWEEN 3 AND 20),
 descripcion text NOT NULL CHECK(length(descripcion) BETWEEN 1 AND 200),
 conductor_id uuid NOT NULL REFERENCES auth.users(id),
 km integer NOT NULL CHECK(km>=0),
 datos jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(datos)='object'),
 actualizado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.conductor_registros (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 vehiculo_id uuid NOT NULL REFERENCES public.conductor_vehiculos(id),
 actor_id uuid NOT NULL REFERENCES auth.users(id),
 actor_nombre text NOT NULL,
 tipo text NOT NULL CHECK(tipo IN('Inicio de jornada','Fin de jornada','Registro diario',
 'Tanqueo','Lavado','Reposición de fluidos','Mantenimiento preventivo','Mantenimiento correctivo',
 'Siniestro vial','Novedad','Documentos','Asignación')),
 km integer NOT NULL CHECK(km>=0),
 creado timestamptz NOT NULL DEFAULT now(),
 datos jsonb NOT NULL CHECK(jsonb_typeof(datos)='object' AND octet_length(datos::text)<=16000)
);
CREATE INDEX conductor_registros_vehiculo_fecha ON public.conductor_registros(vehiculo_id,creado DESC);
CREATE UNIQUE INDEX conductor_jornada_unica ON public.conductor_registros(vehiculo_id,tipo,(datos->>'fecha'))
 WHERE tipo IN('Inicio de jornada','Fin de jornada');
ALTER TABLE public.conductor_vehiculos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_registros ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION public.conductor_acceso(p_conductor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo
 AND ('admin'=ANY(coalesce(u.roles,ARRAY[u.rol])) OR
 (p_conductor=auth.uid() AND 'conductor'=ANY(coalesce(u.roles,ARRAY[u.rol])))));
$$;
REVOKE ALL ON FUNCTION public.conductor_acceso(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_acceso(uuid) TO authenticated;
CREATE POLICY conductor_vehiculo_lectura ON public.conductor_vehiculos FOR SELECT TO authenticated
 USING(public.conductor_acceso(conductor_id));
CREATE POLICY conductor_registro_lectura ON public.conductor_registros FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.conductor_vehiculos v WHERE v.id=vehiculo_id AND public.conductor_acceso(v.conductor_id)));
REVOKE ALL ON public.conductor_vehiculos,public.conductor_registros FROM anon,authenticated;
GRANT SELECT ON public.conductor_vehiculos,public.conductor_registros TO authenticated;

CREATE FUNCTION public.conductor_asignar_vehiculo(p_placa text,p_descripcion text,p_km integer,p_numero text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE conductor uuid; vehiculo uuid; anterior jsonb; actor text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT auth_id INTO conductor FROM public.usuarios WHERE numero_usuario=p_numero AND activo
 AND 'conductor'=ANY(coalesce(roles,ARRAY[rol]));
 IF conductor IS NULL THEN RAISE EXCEPTION 'Conductor inexistente o inactivo'; END IF;
 IF p_km IS NULL OR p_km<0 THEN RAISE EXCEPTION 'Kilometraje invalido'; END IF;
 SELECT to_jsonb(v) INTO anterior FROM public.conductor_vehiculos v WHERE placa=upper(trim(p_placa)) FOR UPDATE;
 IF anterior IS NOT NULL AND p_km<(anterior->>'km')::integer THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 INSERT INTO public.conductor_vehiculos(placa,descripcion,conductor_id,km)
 VALUES(upper(trim(p_placa)),trim(p_descripcion),conductor,p_km)
 ON CONFLICT(placa) DO UPDATE SET conductor_id=excluded.conductor_id,descripcion=excluded.descripcion,
 km=greatest(conductor_vehiculos.km,excluded.km),
 datos=CASE WHEN conductor_vehiculos.conductor_id<>excluded.conductor_id
 THEN conductor_vehiculos.datos-'Licencia de conducción' ELSE conductor_vehiculos.datos END,actualizado=now()
 RETURNING id INTO vehiculo;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(vehiculo,auth.uid(),actor,'Asignación',p_km,
 jsonb_build_object('conductor_anterior',anterior->>'conductor_id','conductor_nuevo',conductor));
 RETURN vehiculo;
END $$;

CREATE FUNCTION public.conductor_registrar(p_vehiculo uuid,p_tipo text,p_km integer,p_datos jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; actor text; registro uuid; punto text; link text;
 puntos text[]:=ARRAY['Estado frenos','Nivel de aceite','Nivel de refrigerante',
 'Direccionales delanteras','Direccionales traseras','Luces altas','Luces bajas','Luces stop','Luces de parqueo',
 'Llantas delanteras','Llantas traseras','Llanta de repuesto','Limpiabrisas','Espejo lateral izquierdo',
 'Espejo lateral derecho','Vidrio panorámico','Pito','Pito reversa','Cinturón de seguridad','Puertas seguras',
 'Área de cargue','Interior cabina','Techos libres','Botiquín','Herramientas','Kit de derrames','Extintor'];
 hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id)
 THEN RAISE EXCEPTION 'Sin acceso al vehiculo' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN('Inicio de jornada','Fin de jornada','Registro diario','Tanqueo',
 'Lavado','Reposición de fluidos','Mantenimiento preventivo','Mantenimiento correctivo','Siniestro vial','Novedad','Documentos')
 THEN RAISE EXCEPTION 'Tipo invalido'; END IF;
 IF p_km IS NULL OR p_km<v.km THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>16000
 THEN RAISE EXCEPTION 'Datos invalidos'; END IF;
 FOREACH punto IN ARRAY ARRAY['enlace','evidencia_siniestro'] LOOP
   link:=p_datos->>punto;
   IF coalesce(link,'')<>'' AND link !~ '^https://(drive[.]google[.]com|docs[.]google[.]com)/[^[:space:]]+$'
   THEN RAISE EXCEPTION 'Enlace Drive invalido'; END IF;
 END LOOP;
 IF p_tipo IN('Inicio de jornada','Fin de jornada') THEN
   p_datos:=jsonb_set(p_datos,'{fecha}',to_jsonb(hoy));
   IF jsonb_typeof(p_datos->'respuestas') IS DISTINCT FROM 'object'
   THEN RAISE EXCEPTION 'Checklist requerido'; END IF;
   FOREACH punto IN ARRAY puntos LOOP
     IF coalesce(p_datos->'respuestas'->>punto,'') NOT IN('Buen estado','Con novedad')
     THEN RAISE EXCEPTION 'Punto pendiente: %',punto; END IF;
   END LOOP;
   IF EXISTS(SELECT 1 FROM jsonb_each_text(p_datos->'respuestas') WHERE value='Con novedad') THEN
     IF length(trim(coalesce(p_datos->>'notas','')))=0 THEN RAISE EXCEPTION 'Describe la novedad'; END IF;
     p_datos:=jsonb_set(p_datos,'{resultado}','"Requiere revisión"');
   ELSE
     p_datos:=jsonb_set(p_datos,'{resultado}','"Sin novedades"');
   END IF;
   IF p_tipo='Fin de jornada' AND NOT EXISTS(SELECT 1 FROM public.conductor_registros
     WHERE vehiculo_id=p_vehiculo AND tipo='Inicio de jornada' AND datos->>'fecha'=hoy)
   THEN RAISE EXCEPTION 'Primero registra el inicio'; END IF;
   IF p_tipo='Fin de jornada' AND p_datos->>'siniestro'='true'
     AND (length(trim(coalesce(p_datos->>'hecho','')))=0 OR length(trim(coalesce(p_datos->>'evidencia_siniestro','')))=0)
   THEN RAISE EXCEPTION 'Describe el siniestro y adjunta su enlace'; END IF;
 END IF;
 IF p_tipo IN('Novedad','Siniestro vial') AND length(trim(coalesce(p_datos->>'notas','')))=0
 THEN RAISE EXCEPTION 'Descripcion requerida'; END IF;
 IF p_tipo='Documentos' THEN
   FOREACH punto IN ARRAY ARRAY['SOAT','Revisión tecnicomecánica','Licencia de conducción','Extintor'] LOOP
     IF coalesce(p_datos->>punto,'')<>'' THEN
       IF (p_datos->>punto) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Fecha invalida'; END IF;
       PERFORM (p_datos->>punto)::date;
     END IF;
   END LOOP;
   IF coalesce(p_datos->>'proximo_aceite','')<>'' AND (p_datos->>'proximo_aceite') !~ '^[0-9]+$'
   THEN RAISE EXCEPTION 'Proximo cambio invalido'; END IF;
 END IF;
 IF p_tipo IN('Tanqueo','Mantenimiento preventivo','Mantenimiento correctivo') THEN
   IF coalesce(p_datos->>'valor','') !~ '^[0-9]+([.][0-9]+)?$'
   THEN RAISE EXCEPTION 'Valor invalido'; END IF;
 END IF;
 IF p_tipo='Tanqueo' AND (coalesce(p_datos->>'cantidad','') !~ '^[0-9]+([.][0-9]+)?$'
 OR coalesce(p_datos->>'km_tanqueo','') !~ '^[0-9]+$') THEN RAISE EXCEPTION 'Tanqueo incompleto'; END IF;
 IF p_tipo LIKE 'Mantenimiento%' AND (length(trim(coalesce(p_datos->>'servicio','')))=0
 OR length(trim(coalesce(p_datos->>'taller','')))=0) THEN RAISE EXCEPTION 'Servicio y responsable requeridos'; END IF;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(p_vehiculo,auth.uid(),actor,p_tipo,p_km,p_datos) RETURNING id INTO registro;
 UPDATE public.conductor_vehiculos SET km=p_km,actualizado=now(),
 datos=CASE WHEN p_tipo='Documentos' THEN datos || p_datos ELSE datos END WHERE id=p_vehiculo;
 RETURN registro;
END $$;
REVOKE ALL ON FUNCTION public.conductor_asignar_vehiculo(text,text,integer,text),
 public.conductor_registrar(uuid,text,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_asignar_vehiculo(text,text,integer,text),
 public.conductor_registrar(uuid,text,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
