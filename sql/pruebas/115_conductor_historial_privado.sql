-- SOLO ORBILOQ-DEV (igfuafcekcpugpmsoqbe). Requiere 114.
-- Aplicar antes de publicar el cliente que consulta conductor_historial.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe'
 THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.conductor_fecha_registro(p_datos jsonb, p_creado timestamptz)
RETURNS date LANGUAGE plpgsql STABLE SET search_path=pg_catalog,public AS $$
BEGIN
 IF p_datos->>'fecha' ~ '^\d{4}-\d{2}-\d{2}$' THEN
   BEGIN RETURN (p_datos->>'fecha')::date;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN NULL;
   END;
 END IF;
 RETURN (p_creado AT TIME ZONE 'America/Bogota')::date;
END $$;
REVOKE ALL ON FUNCTION public.conductor_fecha_registro(jsonb,timestamptz) FROM PUBLIC,anon,authenticated;

-- El SELECT directo deja de revelar documentos, respuestas y observaciones al conductor.
DROP POLICY IF EXISTS conductor_registro_lectura ON public.conductor_registros;
CREATE POLICY conductor_registro_lectura ON public.conductor_registros
 FOR SELECT TO authenticated USING(public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.conductor_historial(
 p_vehiculo uuid, p_desde date DEFAULT NULL, p_hasta date DEFAULT NULL,
 p_offset integer DEFAULT 0, p_limite integer DEFAULT 200
) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
DECLARE administrador boolean := public.admin_es_admin();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.conductor_vehiculos v
   WHERE v.id=p_vehiculo AND public.conductor_acceso(v.conductor_id))
 THEN RAISE EXCEPTION 'Sin acceso al vehiculo' USING ERRCODE='42501'; END IF;
 IF p_offset IS NULL OR p_offset<0 OR p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 500
 OR (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta)
 THEN RAISE EXCEPTION 'Filtro de historial invalido'; END IF;
 RETURN QUERY
 SELECT CASE WHEN administrador THEN to_jsonb(r)
   ELSE jsonb_build_object('id',r.id,'tipo',r.tipo,
     'datos',jsonb_build_object('fecha',public.conductor_fecha_registro(r.datos,r.creado)))
     -- Solo el estado operativo de hoy: conserva avisos sin exponer su detalle.
     || CASE WHEN public.conductor_fecha_registro(r.datos,r.creado)=(now() AT TIME ZONE 'America/Bogota')::date
       THEN jsonb_build_object('revision_pendiente',coalesce(r.datos->>'resultado'='Requiere revisión',false),
         'evidencia_registrada',EXISTS(SELECT 1 FROM jsonb_each_text(r.datos) e
           WHERE e.key IN('enlace','foto_frontal','foto_lateral','foto_trasera','foto_tablero')
           AND e.value ~ '^https://(drive[.]google[.]com|docs[.]google[.]com)/'))
       ELSE '{}'::jsonb END END
 FROM public.conductor_registros r
 WHERE r.vehiculo_id=p_vehiculo
   AND (p_desde IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)>=p_desde)
   AND (p_hasta IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)<=p_hasta)
 ORDER BY r.creado DESC,r.id DESC OFFSET p_offset LIMIT p_limite;
END $$;
REVOKE ALL ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) TO authenticated;
COMMIT;
