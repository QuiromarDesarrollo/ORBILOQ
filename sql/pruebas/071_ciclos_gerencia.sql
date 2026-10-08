-- SOLO ORBILOQ-DEV. Requiere 070. Ejecutar completo.
-- No modifica cantidades, órdenes ni movimientos operativos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario DEV'; END IF;
 IF position('(''admin'',''despacho'')' in pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 070'; END IF;
END $$;
ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check CHECK(rol IN('admin','produccion','logistica','despacho','gerencia'));
CREATE OR REPLACE FUNCTION public.puede_ver_dashboards() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN('admin','gerencia'));
$$;
REVOKE ALL ON FUNCTION public.puede_ver_dashboards() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.puede_ver_dashboards() TO authenticated;
DO $$ DECLARE firma text; d text; BEGIN
 FOREACH firma IN ARRAY ARRAY['public.admin_usuario_guardar(uuid,text,text,boolean,text)','public.admin_usuario_registrar(uuid,uuid,text,text,text)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('''gerencia''' in d)>0 THEN CONTINUE; END IF;
   IF position('(''admin'',''produccion'',''logistica'',''despacho'')' in d)=0 THEN RAISE EXCEPTION 'Validacion de roles inesperada: %',firma; END IF;
   EXECUTE replace(d,'(''admin'',''produccion'',''logistica'',''despacho'')','(''admin'',''produccion'',''logistica'',''despacho'',''gerencia'')');
 END LOOP;
 -- Lectura de dashboards. Auditoría e importaciones siguen siendo solo Admin.
 FOREACH firma IN ARRAY ARRAY['public.admin_reporte_resumen()','public.admin_reporte_pagina(text,text,timestamp with time zone)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('public.puede_ver_dashboards()' in d)>0 THEN CONTINUE; END IF;
   IF position('IF NOT public.admin_es_admin() THEN' in d)=0 THEN RAISE EXCEPTION 'Reporte inesperado: %',firma; END IF;
   IF firma LIKE '%pagina%' THEN
     d:=replace(d,'IF NOT public.admin_es_admin() THEN','IF NOT public.puede_ver_dashboards() OR (p_tipo = ''auditoria'' AND NOT public.admin_es_admin()) THEN');
   ELSE d:=replace(d,'IF NOT public.admin_es_admin() THEN','IF NOT public.puede_ver_dashboards() THEN'); END IF;
   EXECUTE d;
 END LOOP;
 -- Estos tres RPC antiguos permitían agregar nombres con cualquier cuenta activa.
 FOREACH firma IN ARRAY ARRAY['public.agregar_personal_logistica(text)','public.agregar_personal_produccion(text)','public.agregar_personal_aliado(text)'] LOOP
   d:=pg_get_functiondef(to_regprocedure(firma));
   IF position('gerencia' in d)>0 THEN CONTINUE; END IF;
   IF position('IF NOT public.wms_cuenta_activa() THEN' in d)=0 THEN RAISE EXCEPTION 'RPC inesperado: %',firma; END IF;
   EXECUTE replace(d,'IF NOT public.wms_cuenta_activa() THEN',
    'IF NOT public.wms_cuenta_activa() OR EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND rol=''gerencia'') THEN');
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.wms_cuenta_operativa() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN('admin','produccion','logistica','despacho'));
$$;
REVOKE ALL ON FUNCTION public.wms_cuenta_operativa() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.wms_cuenta_operativa() TO authenticated;
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity LOOP
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_insert ON public.%I',t.relname);
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_update ON public.%I',t.relname);
   EXECUTE format('DROP POLICY IF EXISTS gerencia_sin_delete ON public.%I',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.wms_cuenta_operativa())',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.wms_cuenta_operativa()) WITH CHECK(public.wms_cuenta_operativa())',t.relname);
   EXECUTE format('CREATE POLICY gerencia_sin_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING(public.wms_cuenta_operativa())',t.relname);
 END LOOP;
END $$;

-- Mantener también el almacenamiento de archivos en modo lectura para Gerencia.
DO $$ BEGIN
 IF to_regclass('storage.objects') IS NOT NULL THEN
   CREATE POLICY gerencia_sin_insert ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.wms_cuenta_operativa());
   CREATE POLICY gerencia_sin_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.wms_cuenta_operativa()) WITH CHECK(public.wms_cuenta_operativa());
   CREATE POLICY gerencia_sin_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(public.wms_cuenta_operativa());
 END IF;
END $$;

CREATE TABLE public.ciclos_revision(id boolean PRIMARY KEY DEFAULT true CHECK(id), revision bigint NOT NULL DEFAULT 0);
INSERT INTO public.ciclos_revision DEFAULT VALUES;
CREATE TABLE public.ciclos_parametros(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), proceso text NOT NULL CHECK(proceso IN('compras','trazo','corte','separado','aliados','terminado','logistica')),
 vigente_desde date NOT NULL CHECK(vigente_desde BETWEEN '1900-01-01' AND '2200-12-31'), dias integer NOT NULL CHECK(dias BETWEEN 0 AND 3650),
 capacidad_diaria integer CHECK(capacidad_diaria>0), capacidad_semanal integer CHECK(capacidad_semanal>0), umbral_cola integer CHECK(umbral_cola>0),
 creado_en timestamptz NOT NULL DEFAULT now(), actor uuid NOT NULL, UNIQUE(proceso,vigente_desde));
CREATE TABLE public.ciclos_ordenes(
 op text PRIMARY KEY CHECK(length(trim(op)) BETWEEN 1 AND 100), cliente text NOT NULL CHECK(length(trim(cliente)) BETWEEN 1 AND 300),
 cantidad integer NOT NULL CHECK(cantidad>0), inicio date, fines jsonb NOT NULL, versiones jsonb NOT NULL DEFAULT '{}',
 actualizado_en timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.ciclos_importaciones(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), archivo text NOT NULL, actor uuid NOT NULL,
 creado_en timestamptz NOT NULL DEFAULT now(), antes jsonb NOT NULL, despues jsonb NOT NULL);
ALTER TABLE public.ciclos_revision ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_parametros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_ordenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ciclos_revision,public.ciclos_parametros,public.ciclos_ordenes,public.ciclos_importaciones FROM PUBLIC,anon,authenticated;
CREATE POLICY ciclos_auditoria_admin ON public.ciclos_importaciones FOR SELECT TO authenticated USING(public.admin_es_admin());
GRANT SELECT ON public.ciclos_importaciones TO authenticated;

-- Asigna versiones por inicio; conserva la anterior si no se corrigió ese inicio.
CREATE FUNCTION public.ciclos_versiones(p_inicio date,p_fines jsonb,p_anterior public.ciclos_ordenes) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE procesos text[]:=ARRAY['compras','trazo','corte','separado','aliados','terminado','logistica']; i int; f date; antigua date; v uuid; r jsonb:='{}';
BEGIN
 FOR i IN 1..7 LOOP
   f:=CASE WHEN i=1 THEN p_inicio ELSE (p_fines->>procesos[i-1])::date END;
   antigua:=CASE WHEN i=1 THEN p_anterior.inicio ELSE (p_anterior.fines->>procesos[i-1])::date END;
   v:=NULL;
   IF f IS NOT NULL THEN
     IF f IS NOT DISTINCT FROM antigua THEN v:=(p_anterior.versiones->>procesos[i])::uuid; END IF;
     IF v IS NULL THEN SELECT id INTO v FROM public.ciclos_parametros WHERE proceso=procesos[i] AND vigente_desde<=f ORDER BY vigente_desde DESC LIMIT 1; END IF;
   END IF;
   r:=r||jsonb_build_object(procesos[i],v);
 END LOOP;
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.ciclos_versiones(date,jsonb,public.ciclos_ordenes) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.ciclos_estado() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso a dashboards' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('revision',(SELECT revision::text FROM public.ciclos_revision),'hoy',(now() AT TIME ZONE 'America/Bogota')::date,
  'parametros',(SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY proceso,vigente_desde),'[]') FROM public.ciclos_parametros p));
END $$;
CREATE FUNCTION public.ciclos_pagina(p_despues text,p_revision text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso a dashboards' USING ERRCODE='42501'; END IF;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los datos cambiaron. Actualiza e intenta de nuevo.'; END IF;
 RETURN (SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY op),'[]') FROM (SELECT * FROM public.ciclos_ordenes WHERE op>p_despues ORDER BY op LIMIT 1000)o);
END $$;
CREATE FUNCTION public.ciclos_configurar(p_proceso text,p_desde date,p_dias integer,p_diaria integer,p_semanal integer,p_revision text,p_cola integer DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp SET lock_timeout='5s' AS $$
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.ciclos_revision FOR UPDATE;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los parámetros cambiaron. Actualiza antes de guardar.'; END IF;
 INSERT INTO public.ciclos_parametros(proceso,vigente_desde,dias,capacidad_diaria,capacidad_semanal,umbral_cola,actor) VALUES(p_proceso,p_desde,p_dias,p_diaria,p_semanal,p_cola,auth.uid());
 -- Solo completa asignaciones faltantes; jamás sustituye versiones ya asociadas.
 UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o) WHERE o.versiones IS DISTINCT FROM public.ciclos_versiones(o.inicio,o.fines,o);
 UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;
END $$;
CREATE FUNCTION public.ciclos_importar(p_filas jsonb,p_revision text,p_confirmar boolean,p_archivo text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp SET lock_timeout='5s' AS $$
DECLARE x jsonb; f date; anterior date; p text; cantidad numeric; old public.ciclos_ordenes; nuevo int:=0; cambios int:=0; borradas int:=0; antes jsonb; despues jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF p_confirmar IS NULL OR p_archivo IS NULL OR length(p_archivo)>300 OR jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo invalido'; END IF;
 IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Carga entre 1 y 10000 OP'; END IF;
 PERFORM 1 FROM public.ciclos_revision FOR UPDATE;
 IF p_revision IS DISTINCT FROM (SELECT revision::text FROM public.ciclos_revision) THEN RAISE EXCEPTION 'Los datos cambiaron. Revisa una nueva vista previa.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) AS fila(valor) GROUP BY trim(fila.valor->>'op') HAVING count(*)>1) THEN RAISE EXCEPTION 'OP repetida'; END IF;
 FOR x IN SELECT * FROM jsonb_array_elements(p_filas) LOOP
   IF jsonb_typeof(x->'op') IS DISTINCT FROM 'string' OR coalesce(length(trim(x->>'op')),0) NOT BETWEEN 1 AND 100
     OR jsonb_typeof(x->'cliente') IS DISTINCT FROM 'string' OR coalesce(length(trim(x->>'cliente')),0) NOT BETWEEN 1 AND 300 OR jsonb_typeof(x->'fines') IS DISTINCT FROM 'object'
     OR NOT (x ? 'inicio') THEN RAISE EXCEPTION 'Fila invalida'; END IF;
   cantidad:=(x->>'cantidad')::numeric;
   IF cantidad IS NULL OR cantidad<>trunc(cantidad) OR cantidad NOT BETWEEN 1 AND 2147483647 THEN RAISE EXCEPTION 'Cantidad invalida'; END IF;
   IF x->>'inicio' IS NOT NULL AND (x->>'inicio') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha inicial no ISO'; END IF;
   anterior:=(x->>'inicio')::date;
   IF anterior IS NOT NULL AND anterior NOT BETWEEN '1900-01-01' AND '2200-12-31' THEN RAISE EXCEPTION 'Fecha fuera de rango'; END IF;
   IF (SELECT count(*) FROM jsonb_object_keys(x->'fines'))<>7 THEN RAISE EXCEPTION 'Se requieren los siete procesos'; END IF;
   SELECT * INTO old FROM public.ciclos_ordenes WHERE op=trim(x->>'op');
   IF NOT FOUND THEN nuevo:=nuevo+1;
   ELSIF (to_jsonb(old)-'versiones'-'actualizado_en') IS DISTINCT FROM jsonb_build_object('op',trim(x->>'op'),'cliente',trim(x->>'cliente'),'cantidad',cantidad::int,'inicio',x->'inicio','fines',x->'fines') THEN cambios:=cambios+1; END IF;
   IF old.inicio IS NOT NULL AND x->>'inicio' IS NULL THEN borradas:=borradas+1; END IF;
   FOREACH p IN ARRAY ARRAY['compras','trazo','corte','separado','aliados','terminado','logistica'] LOOP
     IF NOT ((x->'fines') ? p) THEN RAISE EXCEPTION 'Falta proceso %',p; END IF;
     IF x->'fines'->>p IS NOT NULL AND (x->'fines'->>p) !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha no ISO'; END IF;
     f:=(x->'fines'->>p)::date;
     IF f IS NOT NULL AND (f NOT BETWEEN '1900-01-01' AND '2200-12-31' OR f<anterior) THEN RAISE EXCEPTION 'Fechas contradictorias en OP %, proceso %',x->>'op',p; END IF;
     anterior:=coalesce(f,anterior);
     IF old.fines->>p IS NOT NULL AND f IS NULL THEN borradas:=borradas+1; END IF;
   END LOOP;
 END LOOP;
 IF p_confirmar THEN
   SELECT coalesce(jsonb_agg(to_jsonb(o)),'[]') INTO antes FROM public.ciclos_ordenes o WHERE op IN(SELECT trim(fila.valor->>'op') FROM jsonb_array_elements(p_filas) AS fila(valor));
   FOR x IN SELECT * FROM jsonb_array_elements(p_filas) LOOP
     SELECT * INTO old FROM public.ciclos_ordenes WHERE op=trim(x->>'op');
     INSERT INTO public.ciclos_ordenes(op,cliente,cantidad,inicio,fines,versiones)
     VALUES(trim(x->>'op'),trim(x->>'cliente'),(x->>'cantidad')::integer,(x->>'inicio')::date,x->'fines',public.ciclos_versiones((x->>'inicio')::date,x->'fines',old))
     ON CONFLICT(op) DO UPDATE SET cliente=excluded.cliente,cantidad=excluded.cantidad,inicio=excluded.inicio,fines=excluded.fines,versiones=excluded.versiones,actualizado_en=now();
   END LOOP;
   SELECT jsonb_agg(to_jsonb(o)) INTO despues FROM public.ciclos_ordenes o WHERE op IN(SELECT trim(fila.valor->>'op') FROM jsonb_array_elements(p_filas) AS fila(valor));
   INSERT INTO public.ciclos_importaciones(archivo,actor,antes,despues) VALUES(p_archivo,auth.uid(),antes,despues);
   UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;
 END IF;
 RETURN jsonb_build_object('nuevas',nuevo,'actualizadas',cambios,'fechas_borradas',borradas,'total',jsonb_array_length(p_filas));
END $$;
REVOKE ALL ON FUNCTION public.ciclos_estado(),public.ciclos_pagina(text,text),public.ciclos_configurar(text,date,integer,integer,integer,text,integer),public.ciclos_importar(jsonb,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ciclos_estado(),public.ciclos_pagina(text,text),public.ciclos_configurar(text,date,integer,integer,integer,text,integer),public.ciclos_importar(jsonb,text,boolean,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
