-- CANDIDATO 2026-10-30. No aplicar sin respaldo y ensayo actualizado.
-- Solo producción cxrflhgnxvomcvxzugda. Mantiene todos los datos existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No aplicar en DEV'; END IF;
 IF to_regclass('public.masiva_operaciones') IS NOT NULL OR to_regclass('public.despacho_borradores') IS NOT NULL THEN RAISE EXCEPTION 'Hay cambios ya instalados: diagnosticar, no repetir'; END IF;
 IF to_regclass('public.conductor_vehiculos') IS NULL OR to_regclass('public.entrega_correos') IS NULL OR to_regprocedure('public.admin_empaque_guardar_v92(uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Falta despliegue previo'; END IF;
END $$;
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY,columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text,fila jsonb) ON COMMIT DROP;
CREATE TEMP TABLE previo_secuencias ON COMMIT DROP AS SELECT to_jsonb(s) fila FROM pg_sequences s WHERE schemaname='public';
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth','storage') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  IF t.nspname IN ('public','respaldo_mantenimiento') THEN EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname); END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;

-- Fuente revisada: 129_masiva.sql
-- Aplicar después de 128. No importa las hojas de ejemplo ni modifica inventario de Bodega.
-- Importaciones por lotes con confirmación atómica; inventario recibido comienza en cero.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.usuario_roles_normalizar(text[])') IS NULL THEN RAISE EXCEPTION 'Faltan los perfiles de ORBILOQ'; END IF;
END $$;

ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
 CHECK(rol IN('admin','seguimiento','produccion','logistica','despacho','gerencia','conductor','masiva'));
CREATE OR REPLACE FUNCTION public.usuario_roles_normalizar(p_roles text[]) RETURNS text[]
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE resultado text[];
BEGIN
 IF p_roles IS NULL OR cardinality(p_roles) NOT BETWEEN 1 AND 8 OR array_ndims(p_roles)<>1
 OR array_position(p_roles,NULL) IS NOT NULL
 OR NOT p_roles <@ ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor','masiva']::text[]
 THEN RAISE EXCEPTION 'Selecciona al menos un perfil válido.'; END IF;
 SELECT array_agg(r ORDER BY n) INTO resultado FROM unnest(ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor','masiva'])
 WITH ORDINALITY AS t(r,n) WHERE r=ANY(p_roles);
 RETURN resultado;
END $$;

CREATE TABLE public.masiva_operaciones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), nombre text NOT NULL CHECK(length(trim(nombre)) BETWEEN 1 AND 160),
 cliente text NOT NULL CHECK(length(trim(cliente)) BETWEEN 1 AND 160), estado text NOT NULL DEFAULT 'activa' CHECK(estado IN('activa','cerrada')),
 logo_cliente text NOT NULL DEFAULT '', logo_empresa text NOT NULL DEFAULT '',
 puntos_kit integer NOT NULL DEFAULT 1 CHECK(puntos_kit BETWEEN 0 AND 100),
 puntos_prenda integer NOT NULL DEFAULT 1 CHECK(puntos_prenda BETWEEN 0 AND 100),
 penalizacion_error integer NOT NULL DEFAULT 2 CHECK(penalizacion_error BETWEEN 0 AND 100),
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id),
 cerrado timestamptz, cerrado_por uuid REFERENCES auth.users(id), motivo_cierre text
);
CREATE TABLE public.masiva_personal (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), nombre text NOT NULL CHECK(length(trim(nombre)) BETWEEN 1 AND 160),
 usuario_numero text UNIQUE, activo boolean NOT NULL DEFAULT true,
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id)
);
CREATE TABLE public.masiva_empaques (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), nombre text NOT NULL CHECK(length(trim(nombre)) BETWEEN 1 AND 120),
 peso_vacio numeric(10,3) NOT NULL CHECK(peso_vacio>=0), peso_lleno numeric(10,3) NOT NULL CHECK(peso_lleno>=peso_vacio),
 largo numeric(10,2) NOT NULL CHECK(largo>0), ancho numeric(10,2) NOT NULL CHECK(ancho>0), alto numeric(10,2) NOT NULL CHECK(alto>0),
 tipo text NOT NULL DEFAULT 'caja' CHECK(tipo IN('caja','bolsa')), activo boolean NOT NULL DEFAULT true,
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id)
);
CREATE TABLE public.masiva_importaciones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 tipo text NOT NULL CHECK(tipo IN('recepcion','personal')), archivo text NOT NULL CHECK(length(archivo) BETWEEN 1 AND 240),
 estado text NOT NULL DEFAULT 'cargando' CHECK(estado IN('cargando','confirmada','cancelada')),
 total_filas integer NOT NULL CHECK(total_filas BETWEEN 1 AND 100000), total_lotes integer NOT NULL CHECK(total_lotes BETWEEN 1 AND 1000),
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id), confirmado timestamptz
);
CREATE UNIQUE INDEX masiva_importacion_confirmada ON public.masiva_importaciones(operacion_id,tipo) WHERE estado='confirmada';
CREATE UNIQUE INDEX masiva_importacion_cargando ON public.masiva_importaciones(operacion_id,tipo) WHERE estado='cargando';
CREATE TABLE public.masiva_importacion_lotes (
 importacion_id uuid NOT NULL REFERENCES public.masiva_importaciones(id), indice integer NOT NULL CHECK(indice>=0),
 filas jsonb NOT NULL CHECK(jsonb_typeof(filas)='array' AND jsonb_array_length(filas) BETWEEN 1 AND 1000),
 PRIMARY KEY(importacion_id,indice)
);
CREATE TABLE public.masiva_inventario (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 proveedor text NOT NULL, pedido text NOT NULL, sku text NOT NULL, descripcion text NOT NULL,
 unidad text NOT NULL DEFAULT 'UNIDAD', esperado integer NOT NULL CHECK(esperado>0), recibido integer NOT NULL DEFAULT 0,
 validado integer NOT NULL DEFAULT 0, CHECK(recibido BETWEEN 0 AND esperado), CHECK(validado BETWEEN 0 AND recibido),
 UNIQUE(operacion_id,proveedor,pedido,sku)
);
CREATE INDEX masiva_inventario_sku ON public.masiva_inventario(operacion_id,sku);
CREATE TABLE public.masiva_listas (
 operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id), lista text NOT NULL,
 sede text NOT NULL DEFAULT '', ciudad text NOT NULL DEFAULT '', direccion text NOT NULL DEFAULT '',
 unidad text NOT NULL DEFAULT '', sector text NOT NULL DEFAULT '', responsable text NOT NULL DEFAULT '',
 responsables jsonb NOT NULL DEFAULT '[]', PRIMARY KEY(operacion_id,lista)
);
CREATE TABLE public.masiva_asignaciones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 lista text NOT NULL, empacador_id uuid NOT NULL REFERENCES public.masiva_personal(id), desde integer NOT NULL, hasta integer NOT NULL,
 estado text NOT NULL DEFAULT 'pendiente' CHECK(estado IN('pendiente','en_curso','pausado','finalizado')),
 segundos numeric NOT NULL DEFAULT 0 CHECK(segundos>=0), inicio timestamptz, ultimo_inicio timestamptz, fin timestamptz,
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id),
 CHECK(desde>0 AND hasta>=desde), FOREIGN KEY(operacion_id,lista) REFERENCES public.masiva_listas(operacion_id,lista),
 UNIQUE(operacion_id,lista,empacador_id,desde,hasta)
);
CREATE TABLE public.masiva_cajas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id), lista text NOT NULL,
 numero integer NOT NULL CHECK(numero>0), empaque_id uuid NOT NULL REFERENCES public.masiva_empaques(id),
 empaque_snapshot jsonb NOT NULL, creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id),
 UNIQUE(operacion_id,lista,numero), FOREIGN KEY(operacion_id,lista) REFERENCES public.masiva_listas(operacion_id,lista)
);
CREATE TABLE public.masiva_kits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id), lista text NOT NULL,
 numero_persona integer NOT NULL CHECK(numero_persona>0), cedula text NOT NULL, nombre text NOT NULL,
 estado text NOT NULL DEFAULT 'pendiente' CHECK(estado IN('pendiente','armando','armado','parcial','validado')),
 empacador_id uuid REFERENCES public.masiva_personal(id), asignacion_id uuid REFERENCES public.masiva_asignaciones(id),
 armado timestamptz, validacion_inicio timestamptz, validacion_fin timestamptz, validador_id uuid REFERENCES auth.users(id),
 revision_abierta boolean NOT NULL DEFAULT true, caja_id uuid REFERENCES public.masiva_cajas(id),
 FOREIGN KEY(operacion_id,lista) REFERENCES public.masiva_listas(operacion_id,lista),
 UNIQUE(operacion_id,lista,cedula), UNIQUE(operacion_id,lista,numero_persona)
);
CREATE INDEX masiva_kits_operacion ON public.masiva_kits(operacion_id,lista,numero_persona);
CREATE TABLE public.masiva_articulos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kit_id uuid NOT NULL REFERENCES public.masiva_kits(id), sku text NOT NULL,
 descripcion text NOT NULL, cantidad integer NOT NULL CHECK(cantidad>0), validado integer NOT NULL DEFAULT 0 CHECK(validado>=0 AND validado<=cantidad),
 UNIQUE(kit_id,sku)
);
CREATE INDEX masiva_articulos_sku ON public.masiva_articulos(sku,kit_id);
CREATE TABLE public.masiva_consumos (
 articulo_id uuid NOT NULL REFERENCES public.masiva_articulos(id), inventario_id uuid NOT NULL REFERENCES public.masiva_inventario(id),
 cantidad integer NOT NULL CHECK(cantidad>=0), PRIMARY KEY(articulo_id,inventario_id)
);
-- Crédito neto de prendas: una corrección revierte el crédito original antes de
-- permitir revalidar. Reabrir y volver a escanear nunca infla los indicadores.
CREATE TABLE public.masiva_validacion_creditos (
 articulo_id uuid NOT NULL REFERENCES public.masiva_articulos(id), actor_id uuid NOT NULL REFERENCES auth.users(id),
 cantidad integer NOT NULL CHECK(cantidad>=0), actualizado timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(articulo_id,actor_id)
);
CREATE TABLE public.masiva_movimientos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 inventario_id uuid NOT NULL REFERENCES public.masiva_inventario(id), articulo_id uuid REFERENCES public.masiva_articulos(id),
 tipo text NOT NULL CHECK(tipo IN('recepcion','validacion','correccion')), cantidad integer NOT NULL CHECK(cantidad<>0),
 soporte text NOT NULL DEFAULT '', actor_id uuid NOT NULL REFERENCES auth.users(id), creado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.masiva_auditoria (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid REFERENCES public.masiva_operaciones(id),
 kit_id uuid REFERENCES public.masiva_kits(id), accion text NOT NULL, actor_id uuid NOT NULL REFERENCES auth.users(id),
 actor_nombre text NOT NULL, datos jsonb NOT NULL DEFAULT '{}', creado timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX masiva_auditoria_fecha ON public.masiva_auditoria(operacion_id,creado DESC);
CREATE TABLE public.masiva_solicitudes (
 request_id uuid PRIMARY KEY, actor_id uuid NOT NULL REFERENCES auth.users(id), accion text NOT NULL,
 huella text NOT NULL, respuesta jsonb NOT NULL, creado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.masiva_documentos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id), lista text NOT NULL,
 tipo text NOT NULL CHECK(tipo IN('lista','rotulo')), version integer NOT NULL CHECK(version>0), snapshot jsonb NOT NULL,
 creado timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL REFERENCES auth.users(id),
 FOREIGN KEY(operacion_id,lista) REFERENCES public.masiva_listas(operacion_id,lista), UNIQUE(operacion_id,lista,tipo,version)
);

CREATE FUNCTION public.masiva_acceso() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo
 AND coalesce(u.roles,ARRAY[u.rol]) && ARRAY['admin','masiva']::text[])
$$;
CREATE FUNCTION public.masiva_inmutable() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN RAISE EXCEPTION 'El historial de Masiva es inmutable'; END $$;
DO $$ DECLARE tabla text; BEGIN
 FOREACH tabla IN ARRAY ARRAY['masiva_operaciones','masiva_personal','masiva_empaques','masiva_importaciones','masiva_importacion_lotes',
 'masiva_inventario','masiva_listas','masiva_asignaciones','masiva_cajas','masiva_kits','masiva_articulos','masiva_consumos',
 'masiva_validacion_creditos','masiva_movimientos','masiva_auditoria','masiva_solicitudes','masiva_documentos'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',tabla);
  EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC,anon,authenticated',tabla);
 END LOOP;
 FOREACH tabla IN ARRAY ARRAY['masiva_movimientos','masiva_auditoria','masiva_documentos'] LOOP
  EXECUTE format('CREATE TRIGGER masiva_no_editar BEFORE UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.masiva_inmutable()',tabla);
 END LOOP;
END $$;

-- Las consultas no permiten SQL libre ni exponen staging o usuarios de otros módulos.
CREATE FUNCTION public.masiva_consultar(p_operacion uuid DEFAULT NULL,p_vista text DEFAULT 'resumen',p_buscar text DEFAULT '',p_pagina integer DEFAULT 1,p_lista text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE op public.masiva_operaciones; filas jsonb:='[]'; metricas jsonb; total bigint:=0; desplazamiento integer;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200 THEN RAISE EXCEPTION 'Consulta inválida'; END IF;
 desplazamiento:=(p_pagina-1)*50; p_buscar:=trim(coalesce(p_buscar,'')); p_lista:=trim(coalesce(p_lista,''));
 IF p_operacion IS NULL THEN
  RETURN jsonb_build_object('operaciones',coalesce((SELECT jsonb_agg(to_jsonb(o) - 'logo_cliente' - 'logo_empresa' ORDER BY o.creado DESC) FROM public.masiva_operaciones o),'[]'::jsonb));
 END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion;
 IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 SELECT jsonb_build_object('kits',count(*),'armados',count(*) FILTER(WHERE armado IS NOT NULL),
 'validados',count(*) FILTER(WHERE estado='validado'),'parciales',count(*) FILTER(WHERE estado='parcial')) INTO metricas FROM public.masiva_kits WHERE operacion_id=p_operacion;
 metricas:=metricas||jsonb_build_object(
 'importaciones',coalesce((SELECT jsonb_object_agg(i.tipo,jsonb_build_object('id',i.id,'estado',i.estado,'filas',i.total_filas,'archivo',i.archivo))
 FROM public.masiva_importaciones i WHERE i.operacion_id=p_operacion AND i.estado<>'cancelada'),'{}'::jsonb),
 'unidades',(SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion),
 'unidades_validadas',(SELECT coalesce(sum(validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'esperado',(SELECT coalesce(sum(esperado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'recibido',(SELECT coalesce(sum(recibido),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'disponible',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'segundos_empaque',(SELECT coalesce(sum(segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM now()-ultimo_inicio) ELSE 0 END),0) FROM public.masiva_asignaciones WHERE operacion_id=p_operacion),
 'promedio_segundos_kit',(SELECT coalesce(round(sum(s.segundos)/nullif(sum((SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)),0),2),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.estado='finalizado'),
 'cajas',(SELECT count(*) FROM public.masiva_cajas c WHERE c.operacion_id=p_operacion),
 'primera_recepcion',(SELECT min(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'ultima_recepcion',(SELECT max(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'duracion_recepcion_segundos',(SELECT coalesce(extract(epoch FROM max(creado)-min(creado)),0) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'inicio_validacion',(SELECT min(validacion_inicio) FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'fin_validacion',(SELECT CASE WHEN count(*)>0 AND count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE NULL END FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_validacion_segundos',(SELECT coalesce(extract(epoch FROM
  (CASE WHEN count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE coalesce(op.cerrado,now()) END)-min(validacion_inicio)),0)
  FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_operacion_segundos',extract(epoch FROM coalesce(op.cerrado,now())-op.creado));
 IF p_vista='inventario' THEN
  WITH datos AS (SELECT i.*,i.recibido-i.validado AS disponible,i.esperado-i.recibido AS pendiente,
  (SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion AND a.sku=i.sku) AS requerido
  FROM public.masiva_inventario i WHERE i.operacion_id=p_operacion AND (p_buscar='' OR i.sku ILIKE '%'||p_buscar||'%' OR i.descripcion ILIKE '%'||p_buscar||'%' OR i.proveedor ILIKE '%'||p_buscar||'%')),
  pagina AS(SELECT * FROM datos ORDER BY proveedor,pedido,sku LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='listas' THEN
  WITH datos AS(SELECT l.*,count(k.id) AS kits,count(k.id) FILTER(WHERE k.armado IS NOT NULL) AS armados,
  count(k.id) FILTER(WHERE k.estado='validado') AS validados FROM public.masiva_listas l LEFT JOIN public.masiva_kits k ON k.operacion_id=l.operacion_id AND k.lista=l.lista
  WHERE l.operacion_id=p_operacion AND (p_lista='' OR l.lista=p_lista) AND (p_buscar='' OR l.lista ILIKE '%'||p_buscar||'%' OR l.sede ILIKE '%'||p_buscar||'%') GROUP BY l.operacion_id,l.lista),
  pagina AS(SELECT * FROM datos ORDER BY lista LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='kits' THEN
  WITH datos AS(SELECT k.*,c.numero AS caja,c.empaque_id,p.nombre AS empacador FROM public.masiva_kits k
  LEFT JOIN public.masiva_cajas c ON c.id=k.caja_id LEFT JOIN public.masiva_personal p ON p.id=k.empacador_id
  WHERE k.operacion_id=p_operacion AND (p_lista='' OR k.lista=p_lista)
  AND(p_buscar='' OR k.id::text=p_buscar OR k.numero_persona::text=p_buscar OR k.cedula ILIKE '%'||p_buscar||'%' OR k.nombre ILIKE '%'||p_buscar||'%')),
  pagina AS(SELECT * FROM datos ORDER BY lista,numero_persona LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)||jsonb_build_object('articulos',
  (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.sku) FROM public.masiva_articulos a WHERE a.kit_id=pagina.id))),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='auditoria' THEN
  WITH datos AS(SELECT a.* FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND(p_buscar='' OR a.accion ILIKE '%'||p_buscar||'%' OR a.actor_nombre ILIKE '%'||p_buscar||'%' OR a.kit_id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='personal' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.nombre),'[]') INTO total,filas FROM public.masiva_personal p WHERE p.activo;
 ELSIF p_vista='empaques' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.nombre),'[]') INTO total,filas FROM public.masiva_empaques e WHERE e.activo;
 ELSIF p_vista='asignaciones' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('empacador',p.nombre,'kits',(SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)) ORDER BY s.lista,s.desde),'[]')
  INTO total,filas FROM public.masiva_asignaciones s JOIN public.masiva_personal p ON p.id=s.empacador_id WHERE s.operacion_id=p_operacion AND(p_lista='' OR s.lista=p_lista);
 ELSIF p_vista='documentos' THEN
  WITH datos AS(SELECT d.* FROM public.masiva_documentos d WHERE d.operacion_id=p_operacion AND(p_lista='' OR d.lista=p_lista) AND(p_buscar='' OR d.id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg((CASE WHEN p_buscar<>'' THEN to_jsonb(pagina) ELSE to_jsonb(pagina)-'snapshot' END)||jsonb_build_object('created_at',pagina.creado)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='indicadores' THEN
  WITH datos AS(SELECT p.id,p.nombre,
  (SELECT count(*) FROM public.masiva_kits k WHERE k.operacion_id=p_operacion AND k.empacador_id=p.id AND k.armado IS NOT NULL) AS kits,
  (SELECT coalesce(sum(s.segundos),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.empacador_id=p.id AND s.estado='finalizado') AS segundos,
  (SELECT count(*) FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND a.accion='reportar_error' AND a.datos->>'empacador_id'=p.id::text) AS errores
  FROM public.masiva_personal p WHERE EXISTS(SELECT 1 FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.empacador_id=p.id))
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(datos)||jsonb_build_object('puntos',kits*op.puntos_kit-errores*op.penalizacion_error,'promedio_segundos',round(segundos/nullif(kits,0),2)) ORDER BY kits DESC,nombre),'[]') INTO total,filas FROM datos;
  metricas:=metricas||jsonb_build_object('validadores',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
  SELECT c.actor_id,u.nombre AS actor_nombre,sum(c.cantidad) AS prendas,sum(c.cantidad)*op.puntos_prenda AS puntos
  FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id
  JOIN public.masiva_kits k ON k.id=a.kit_id JOIN public.usuarios u ON u.auth_id=c.actor_id
  WHERE k.operacion_id=p_operacion GROUP BY c.actor_id,u.nombre ORDER BY prendas DESC) x),'[]'::jsonb));
 ELSIF p_vista NOT IN('resumen','configuracion') THEN RAISE EXCEPTION 'Vista no reconocida'; END IF;
 RETURN jsonb_build_object('operacion',to_jsonb(op),'metricas',metricas,'filas',filas,'total',total,'pagina',p_pagina);
END $$;

-- Una transacción por acción. Bloquear la operación serializa cinco puestos y elimina
-- carreras entre recepciones, escaneos, cierre, importaciones y documentos de esa masiva.
CREATE FUNCTION public.masiva_ejecutar(p_accion text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='10s' SET statement_timeout='180s' AS $$
DECLARE actor uuid:=auth.uid(); v_actor_nombre text; es_admin boolean; op public.masiva_operaciones; operacion uuid;
 imp public.masiva_importaciones; k public.masiva_kits; art public.masiva_articulos; inv public.masiva_inventario;
 asig public.masiva_asignaciones; persona public.masiva_personal; empaque public.masiva_empaques; caja public.masiva_cajas;
 solicitud public.masiva_solicitudes; req uuid; huella text; resultado jsonb; id_nuevo uuid; v_filas jsonb; fila jsonb;
 n integer; n_desde integer; n_hasta integer; v_cantidad integer; cambio integer; restante integer; tomar integer;
 version_documento integer; consumo record; credito record; anterior jsonb; snapshot jsonb; evento_kit uuid; ahora timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 SELECT u.nombre,coalesce(u.roles,ARRAY[u.rol]) @> ARRAY['admin'] INTO v_actor_nombre,es_admin FROM public.usuarios u WHERE u.auth_id=actor AND u.activo;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>5000000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF p_accion IN('crear_operacion','iniciar_importacion','cargar_lote','confirmar_importacion','cancelar_importacion','guardar_personal','guardar_empaque','cerrar_operacion','configurar') AND NOT es_admin
 THEN RAISE EXCEPTION 'Esta acción requiere administrador' USING ERRCODE='42501'; END IF;
 IF p_accion IN('recibir','validar','corregir','reportar_error') THEN
  req:=nullif(p_datos->>'request_id','')::uuid; IF req IS NULL THEN RAISE EXCEPTION 'Falta el identificador de la solicitud'; END IF;
  huella:=md5((p_datos-'request_id')::text);
  SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
  IF FOUND THEN
   IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
   RETURN solicitud.respuesta;
  END IF;
 END IF;
 operacion:=nullif(p_datos->>'operacion_id','')::uuid;
 IF p_accion IN('cargar_lote','confirmar_importacion','cancelar_importacion') THEN
  SELECT * INTO imp FROM public.masiva_importaciones WHERE id=(p_datos->>'importacion_id')::uuid;
  IF imp.id IS NULL THEN RAISE EXCEPTION 'Importación no encontrada'; END IF;
  operacion:=imp.operacion_id;
 END IF;
 IF p_accion NOT IN('crear_operacion','guardar_personal','guardar_empaque') THEN
  SELECT * INTO op FROM public.masiva_operaciones WHERE id=operacion FOR UPDATE;
  IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
  IF imp.id IS NOT NULL THEN
   -- La carga pudo cancelarse o confirmarse mientras esperábamos el bloqueo.
   SELECT * INTO imp FROM public.masiva_importaciones WHERE id=imp.id FOR UPDATE;
  END IF;
  IF req IS NOT NULL THEN
   SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
   IF FOUND THEN
    IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
    RETURN solicitud.respuesta;
   END IF;
  END IF;
  IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;
 END IF;

 CASE p_accion
 WHEN 'crear_operacion' THEN
  INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;
  resultado:=jsonb_build_object('id',operacion);
 WHEN 'guardar_personal' THEN
  IF nullif(trim(p_datos->>'usuario_numero'),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE numero_usuario=trim(p_datos->>'usuario_numero') AND activo)
  THEN RAISE EXCEPTION 'Usuario asociado no encontrado o inactivo'; END IF;
  INSERT INTO public.masiva_personal(nombre,usuario_numero,creado_por) VALUES(trim(p_datos->>'nombre'),nullif(trim(p_datos->>'usuario_numero'),''),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'guardar_empaque' THEN
  INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por)
  VALUES(trim(p_datos->>'nombre'),(p_datos->>'peso_vacio')::numeric,(p_datos->>'peso_lleno')::numeric,(p_datos->>'largo')::numeric,
  (p_datos->>'ancho')::numeric,(p_datos->>'alto')::numeric,coalesce(p_datos->>'tipo','caja'),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'iniciar_importacion' THEN
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND tipo=p_datos->>'tipo' AND estado<>'cancelada') THEN RAISE EXCEPTION 'Ya existe una carga de este tipo; finaliza o cancela la carga pendiente'; END IF;
  INSERT INTO public.masiva_importaciones(operacion_id,tipo,archivo,total_filas,total_lotes,creado_por)
  VALUES(operacion,p_datos->>'tipo',p_datos->>'archivo',(p_datos->>'total_filas')::integer,(p_datos->>'total_lotes')::integer,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('importacion_id',id_nuevo);
 WHEN 'cargar_lote' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La importación ya no admite lotes'; END IF;
  n:=(p_datos->>'indice')::integer; v_filas:=p_datos->'filas';
  IF n IS NULL OR n<0 OR n>=imp.total_lotes OR jsonb_typeof(v_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(v_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Lote inválido'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id AND indice=n AND masiva_importacion_lotes.filas<>v_filas) THEN RAISE EXCEPTION 'El lote ya existe con contenido diferente'; END IF;
  INSERT INTO public.masiva_importacion_lotes(importacion_id,indice,filas) VALUES(imp.id,n,v_filas) ON CONFLICT DO NOTHING;
  resultado:=jsonb_build_object('importacion_id',imp.id,'indice',n,'filas',jsonb_array_length(v_filas));
 WHEN 'cancelar_importacion' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'Solo puede cancelarse una carga sin confirmar'; END IF;
  UPDATE public.masiva_importaciones SET estado='cancelada' WHERE id=imp.id;
  resultado:=jsonb_build_object('cancelada',true);
 WHEN 'confirmar_importacion' THEN
  IF imp.estado='confirmada' THEN RETURN jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas); END IF;
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La carga fue cancelada'; END IF;
  IF (SELECT count(*) FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id)<>imp.total_lotes
  OR (SELECT coalesce(sum(jsonb_array_length(l.filas)),0) FROM public.masiva_importacion_lotes l WHERE importacion_id=imp.id)<>imp.total_filas THEN RAISE EXCEPTION 'La carga está incompleta; vuelve a enviar los lotes pendientes'; END IF;
  SELECT jsonb_agg(x.value ORDER BY l.indice,x.ordinality) INTO v_filas FROM public.masiva_importacion_lotes l CROSS JOIN LATERAL jsonb_array_elements(l.filas) WITH ORDINALITY x(value,ordinality) WHERE l.importacion_id=imp.id;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE jsonb_typeof(f)<>'object' OR length(trim(coalesce(f->>'sku',''))) NOT BETWEEN 1 AND 100
  OR length(trim(coalesce(f->>'descripcion',''))) NOT BETWEEN 1 AND 500 OR coalesce(f->>'cantidad','') !~ '^[0-9]{1,7}$' OR (f->>'cantidad')::integer<1)
  THEN RAISE EXCEPTION 'Hay referencias, descripciones o cantidades inválidas en el archivo'; END IF;
  IF imp.tipo='recepcion' THEN
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'proveedor',''))) NOT BETWEEN 1 AND 160 OR length(trim(coalesce(f->>'pedido',''))) NOT BETWEEN 1 AND 100
    OR upper(trim(coalesce(f->>'unidad','UNIDAD'))) NOT IN('UNIDAD','UN','UND','PAR','PARES')) THEN RAISE EXCEPTION 'Proveedor, pedido o unidad inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1) THEN RAISE EXCEPTION 'Hay referencias repetidas dentro del mismo pedido y proveedor'; END IF;
   INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,unidad,esperado)
   SELECT operacion,trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku'),trim(f->>'descripcion'),CASE WHEN upper(trim(f->>'unidad')) IN('PAR','PARES') THEN 'PAR' ELSE 'UNIDAD' END,(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f;
  ELSE
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'lista',''))) NOT BETWEEN 1 AND 100
    OR length(trim(coalesce(f->>'cedula',''))) NOT BETWEEN 1 AND 100 OR length(trim(coalesce(f->>'nombre',''))) NOT BETWEEN 1 AND 200
    OR coalesce(f->>'numero_persona','') !~ '^[0-9]{1,7}$' OR (f->>'numero_persona')::integer<1) THEN RAISE EXCEPTION 'Lista, documento, nombre o consecutivo de persona inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT (f->>'numero_persona')::integer)>1 OR count(DISTINCT trim(f->>'nombre'))>1)
   OR EXISTS(SELECT trim(f->>'lista'),(f->>'numero_persona')::integer FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT trim(f->>'cedula'))>1)
   THEN RAISE EXCEPTION 'Una persona tiene datos distintos o un consecutivo está asignado a varias personas'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1)
   THEN RAISE EXCEPTION 'Referencia repetida en un kit; unifica su cantidad antes de confirmar'; END IF;
   INSERT INTO public.masiva_listas(operacion_id,lista,sede,ciudad,direccion,unidad,sector,responsable,responsables)
   SELECT operacion,trim(f->>'lista'),max(coalesce(f->>'sede','')),max(coalesce(f->>'ciudad','')),max(coalesce(f->>'direccion','')),
   max(coalesce(f->>'unidad','')),max(coalesce(f->>'sector','')),coalesce(min(nullif(trim(f->>'lider'),'')),''),
   coalesce(jsonb_agg(DISTINCT trim(f->>'lider')) FILTER(WHERE nullif(trim(f->>'lider'),'') IS NOT NULL),'[]') FROM jsonb_array_elements(v_filas) f GROUP BY trim(f->>'lista');
   INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
   SELECT operacion,trim(f->>'lista'),(f->>'numero_persona')::integer,trim(f->>'cedula'),trim(f->>'nombre') FROM jsonb_array_elements(v_filas) f GROUP BY 2,3,4,5;
   INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad)
   SELECT kit_fila.id,trim(f->>'sku'),trim(f->>'descripcion'),(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f
   JOIN public.masiva_kits kit_fila ON kit_fila.operacion_id=operacion AND kit_fila.lista=trim(f->>'lista') AND kit_fila.cedula=trim(f->>'cedula');
  END IF;
  UPDATE public.masiva_importaciones SET estado='confirmada',confirmado=ahora WHERE id=imp.id;
  resultado:=jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas);
 WHEN 'recibir' THEN
  SELECT * INTO inv FROM public.masiva_inventario WHERE id=(p_datos->>'inventario_id')::uuid AND operacion_id=operacion FOR UPDATE;
  v_cantidad:=(p_datos->>'cantidad')::integer;
  IF inv.id IS NULL OR v_cantidad IS NULL OR v_cantidad<1 THEN RAISE EXCEPTION 'Referencia o cantidad no válida'; END IF;
  IF inv.recibido+v_cantidad>inv.esperado THEN RAISE EXCEPTION 'La recepción supera el límite del pedido (% pendientes)',inv.esperado-inv.recibido; END IF;
  IF length(trim(coalesce(p_datos->>'soporte',''))) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'Registra la remisión o soporte de recepción'; END IF;
  UPDATE public.masiva_inventario SET recibido=recibido+v_cantidad WHERE id=inv.id;
  INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,'recepcion',v_cantidad,trim(p_datos->>'soporte'),actor);
  resultado:=jsonb_build_object('id',inv.id,'recibido',inv.recibido+v_cantidad,'disponible',inv.recibido+v_cantidad-inv.validado);
 WHEN 'asignar' THEN
  SELECT * INTO persona FROM public.masiva_personal WHERE id=(p_datos->>'empacador_id')::uuid AND activo;
  IF persona.id IS NULL THEN RAISE EXCEPTION 'Selecciona una persona activa'; END IF;
  SELECT min(numero_persona),max(numero_persona) INTO n_desde,n_hasta FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  n_desde:=coalesce(nullif(p_datos->>'desde','')::integer,n_desde); n_hasta:=coalesce(nullif(p_datos->>'hasta','')::integer,n_hasta);
  IF n_desde IS NULL OR n_hasta IS NULL OR n_desde<1 OR n_hasta<n_desde THEN RAISE EXCEPTION 'Lista o rango inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_desde)
  OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_hasta) THEN RAISE EXCEPTION 'El rango debe iniciar y terminar en personas de la lista'; END IF;
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=persona.id AND desde=n_desde AND hasta=n_hasta;
  IF asig.id IS NOT NULL THEN RETURN jsonb_build_object('id',asig.id,'desde',n_desde,'hasta',n_hasta); END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta AND empacador_id IS NOT NULL)
  THEN RAISE EXCEPTION 'El rango se cruza con kits ya asignados'; END IF;
  INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,creado_por) VALUES(operacion,p_datos->>'lista',persona.id,n_desde,n_hasta,actor) RETURNING id INTO id_nuevo;
  UPDATE public.masiva_kits SET empacador_id=persona.id,asignacion_id=id_nuevo WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta;
  GET DIAGNOSTICS n=ROW_COUNT;
  resultado:=jsonb_build_object('id',id_nuevo,'kits',n,'desde',n_desde,'hasta',n_hasta);
 WHEN 'tiempo' THEN
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion
  AND ((nullif(p_datos->>'asignacion_id','') IS NOT NULL AND id=(p_datos->>'asignacion_id')::uuid)
   OR (nullif(p_datos->>'asignacion_id','') IS NULL AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid
   AND (nullif(p_datos->>'desde','') IS NULL OR desde=(p_datos->>'desde')::integer) AND(nullif(p_datos->>'hasta','') IS NULL OR hasta=(p_datos->>'hasta')::integer))) ORDER BY creado LIMIT 1 FOR UPDATE;
  IF asig.id IS NULL THEN RAISE EXCEPTION 'Selecciona una asignación de empaque'; END IF;
  -- Evita que dos operaciones inicien simultáneamente el tiempo de la misma persona.
  PERFORM 1 FROM public.masiva_personal WHERE id=asig.empacador_id FOR UPDATE;
  IF nullif(p_datos->>'asignacion_id','') IS NULL AND nullif(p_datos->>'desde','') IS NULL AND (SELECT count(*) FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid)>1
  THEN RAISE EXCEPTION 'Selecciona el rango de empaque para registrar su tiempo'; END IF;
  IF p_datos->>'accion'='iniciar' THEN
   IF asig.estado NOT IN('pendiente','pausado') THEN RAISE EXCEPTION 'El empaque ya está iniciado o finalizado'; END IF;
   IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=asig.empacador_id AND estado='en_curso' AND id<>asig.id) THEN RAISE EXCEPTION 'Esta persona ya tiene otro empaque en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='en_curso',inicio=coalesce(inicio,ahora),ultimo_inicio=ahora WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armando' WHERE asignacion_id=asig.id;
  ELSIF p_datos->>'accion'='pausar' THEN
   IF asig.estado<>'en_curso' THEN RAISE EXCEPTION 'El empaque no está en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='pausado',segundos=segundos+extract(epoch FROM ahora-ultimo_inicio),ultimo_inicio=NULL WHERE id=asig.id;
  ELSIF p_datos->>'accion'='finalizar' THEN
   IF asig.estado NOT IN('en_curso','pausado') THEN RAISE EXCEPTION 'Inicia el empaque antes de finalizarlo'; END IF;
   UPDATE public.masiva_asignaciones SET estado='finalizado',fin=ahora,segundos=segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM ahora-ultimo_inicio) ELSE 0 END,ultimo_inicio=NULL WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armado',armado=ahora WHERE asignacion_id=asig.id;
  ELSE RAISE EXCEPTION 'Acción de tiempo inválida'; END IF;
  SELECT to_jsonb(s) INTO resultado FROM public.masiva_asignaciones s WHERE id=asig.id;
 WHEN 'validar','corregir','reabrir','embalar','reportar_error' THEN
  SELECT * INTO k FROM public.masiva_kits WHERE id=(p_datos->>'kit_id')::uuid AND operacion_id=operacion FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'Kit no encontrado en esta operación'; END IF;
  evento_kit:=k.id;
  IF k.armado IS NULL THEN RAISE EXCEPTION 'Finaliza el armado del kit antes de validarlo'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo armó'; END IF;
  IF p_accion IN('reabrir','corregir','reportar_error') AND length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de la revisión'; END IF;
  IF p_accion='reabrir' THEN
   IF k.validacion_inicio IS NULL THEN RAISE EXCEPTION 'El kit todavía no tiene validaciones'; END IF;
   UPDATE public.masiva_kits SET revision_abierta=true WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'revision_abierta',true);
  ELSIF p_accion='reportar_error' THEN
   resultado:=jsonb_build_object('id',k.id,'empacador_id',k.empacador_id,'penalizacion',op.penalizacion_error);
  ELSIF p_accion='embalar' THEN
   IF NOT EXISTS(SELECT 1 FROM public.masiva_articulos WHERE kit_id=k.id AND validado>0) THEN RAISE EXCEPTION 'Valida al menos una prenda antes de asignar el empaque'; END IF;
   n:=(p_datos->>'caja')::integer; IF n IS NULL OR n<1 THEN RAISE EXCEPTION 'Número de caja inválido'; END IF;
   SELECT * INTO empaque FROM public.masiva_empaques WHERE id=(p_datos->>'empaque_id')::uuid AND activo;
   IF empaque.id IS NULL THEN RAISE EXCEPTION 'Selecciona el tipo de empaque'; END IF;
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL AND caja.empaque_id<>empaque.id THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   IF caja.id IS NULL THEN
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por) VALUES(operacion,k.lista,n,empaque.id,to_jsonb(empaque),actor) RETURNING * INTO caja;
   END IF;
   UPDATE public.masiva_kits SET caja_id=caja.id WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'caja',n);
  ELSE
   IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
   IF p_accion='validar' THEN
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND sku=trim(p_datos->>'sku') FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'El código no pertenece a este kit'; END IF;
    v_cantidad:=art.validado+1;
   ELSE
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND id=(p_datos->>'articulo_id')::uuid FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'Prenda no encontrada en el kit'; END IF;
    v_cantidad:=(p_datos->>'cantidad')::integer;
   END IF;
   IF v_cantidad IS NULL OR v_cantidad<0 OR v_cantidad>art.cantidad THEN RAISE EXCEPTION 'La cantidad excede lo solicitado para esta persona'; END IF;
   cambio:=v_cantidad-art.validado; restante:=abs(cambio); anterior:=to_jsonb(art);
   IF cambio>0 THEN
    FOR inv IN SELECT * FROM public.masiva_inventario WHERE operacion_id=operacion AND sku=art.sku AND recibido>validado ORDER BY proveedor,pedido,id FOR UPDATE LOOP
     tomar:=least(restante,inv.recibido-inv.validado);
     UPDATE public.masiva_inventario SET validado=validado+tomar WHERE id=inv.id;
     INSERT INTO public.masiva_consumos(articulo_id,inventario_id,cantidad) VALUES(art.id,inv.id,tomar)
     ON CONFLICT(articulo_id,inventario_id) DO UPDATE SET cantidad=masiva_consumos.cantidad+excluded.cantidad;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,art.id,CASE WHEN p_accion='validar' THEN 'validacion' ELSE 'correccion' END,-tomar,coalesce(p_datos->>'motivo',''),actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'No hay inventario recibido suficiente para este SKU'; END IF;
   ELSIF cambio<0 THEN
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     tomar:=least(restante,consumo.cantidad);
     UPDATE public.masiva_inventario SET validado=validado-tomar WHERE id=consumo.inventario_id;
     UPDATE public.masiva_consumos SET cantidad=masiva_consumos.cantidad-tomar WHERE articulo_id=art.id AND inventario_id=consumo.inventario_id;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,consumo.inventario_id,art.id,'correccion',tomar,p_datos->>'motivo',actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
   END IF;
   IF cambio>0 THEN
    INSERT INTO public.masiva_validacion_creditos(articulo_id,actor_id,cantidad,actualizado) VALUES(art.id,actor,cambio,ahora)
    ON CONFLICT(articulo_id,actor_id) DO UPDATE SET cantidad=masiva_validacion_creditos.cantidad+excluded.cantidad,actualizado=excluded.actualizado;
   ELSIF cambio<0 THEN
    restante:=-cambio;
    FOR credito IN SELECT * FROM public.masiva_validacion_creditos WHERE articulo_id=art.id AND cantidad>0 ORDER BY actualizado DESC,actor_id FOR UPDATE LOOP
     tomar:=least(restante,credito.cantidad);
     UPDATE public.masiva_validacion_creditos SET cantidad=masiva_validacion_creditos.cantidad-tomar,actualizado=ahora WHERE articulo_id=art.id AND actor_id=credito.actor_id;
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
   END IF;
   UPDATE public.masiva_articulos SET validado=v_cantidad WHERE id=art.id;
   SELECT count(*) INTO n FROM public.masiva_articulos WHERE kit_id=k.id AND validado<masiva_articulos.cantidad;
   UPDATE public.masiva_kits SET estado=CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,
   validacion_inicio=coalesce(validacion_inicio,ahora),validacion_fin=CASE WHEN n=0 THEN ahora ELSE NULL END,
   validador_id=actor,revision_abierta=n<>0 WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'articulo_id',art.id,'sku',art.sku,'validado',v_cantidad,'cantidad',art.cantidad,'estado',CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,'anterior',anterior,'diferencia',cambio);
  END IF;
 WHEN 'configurar' THEN
  IF p_datos ? 'lista' THEN
   IF length(trim(coalesce(p_datos->>'responsable',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Registra el responsable principal'; END IF;
   UPDATE public.masiva_listas SET responsable=trim(p_datos->>'responsable') WHERE operacion_id=operacion AND lista=p_datos->>'lista';
   IF NOT FOUND THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  END IF;
  FOREACH v_actor_nombre IN ARRAY ARRAY['logo_cliente','logo_empresa'] LOOP
   IF p_datos ? v_actor_nombre AND (length(p_datos->>v_actor_nombre)>2000000 OR (p_datos->>v_actor_nombre<>'' AND p_datos->>v_actor_nombre !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/=\r\n]+$')) THEN RAISE EXCEPTION 'Usa un logo PNG o JPEG de máximo 1,5 MB'; END IF;
  END LOOP;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;
  UPDATE public.masiva_operaciones SET logo_cliente=coalesce(p_datos->>'logo_cliente',logo_cliente),logo_empresa=coalesce(p_datos->>'logo_empresa',logo_empresa),
  puntos_kit=coalesce((p_datos->>'puntos_kit')::integer,puntos_kit),puntos_prenda=coalesce((p_datos->>'puntos_prenda')::integer,puntos_prenda),
  penalizacion_error=coalesce((p_datos->>'penalizacion_error')::integer,penalizacion_error) WHERE id=operacion;
  resultado:=jsonb_build_object('guardado',true);
 WHEN 'documento' THEN
  IF coalesce(p_datos->>'tipo','') NOT IN('lista','rotulo') THEN RAISE EXCEPTION 'Tipo de documento inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=operacion AND lista=p_datos->>'lista') THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista'
   AND kit_fila.caja_id IS NULL AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Asigna un empaque a todos los kits con prendas validadas antes de emitir documentos'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista' AND kit_fila.caja_id IS NOT NULL
   AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Valida prendas y asígnalas a una caja antes de emitir documentos'; END IF;
  SELECT coalesce(max(version),0)+1 INTO version_documento FROM public.masiva_documentos WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND tipo=p_datos->>'tipo';
  SELECT jsonb_build_object('formato_version',1,'operacion',to_jsonb(op),'lista',to_jsonb(l),'responsable',l.responsable,'fecha',ahora,'version',version_documento,
  'kits',coalesce((SELECT jsonb_agg(to_jsonb(kit_fila)||jsonb_build_object('caja',c.numero,'empacador',p.nombre,'articulos',
   (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.sku) FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id)) ORDER BY kit_fila.numero_persona)
   FROM public.masiva_kits kit_fila LEFT JOIN public.masiva_cajas c ON c.id=kit_fila.caja_id LEFT JOIN public.masiva_personal p ON p.id=kit_fila.empacador_id
   WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=l.lista AND kit_fila.caja_id IS NOT NULL
    AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0)),'[]'),
  'empaques',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.numero) FROM public.masiva_cajas c WHERE c.operacion_id=operacion AND c.lista=l.lista),'[]'))
  INTO snapshot FROM public.masiva_listas l WHERE l.operacion_id=operacion AND l.lista=p_datos->>'lista';
  INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);
 WHEN 'cerrar_operacion' THEN
  IF length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de cierre'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE operacion_id=operacion AND estado IN('en_curso','pausado')) THEN RAISE EXCEPTION 'Finaliza los tiempos de empaque antes de cerrar'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND estado='cargando') THEN RAISE EXCEPTION 'Confirma o cancela las cargas pendientes antes de cerrar'; END IF;
  UPDATE public.masiva_operaciones SET estado='cerrada',cerrado=ahora,cerrado_por=actor,motivo_cierre=trim(p_datos->>'motivo') WHERE id=operacion;
  resultado:=jsonb_build_object('id',operacion,'estado','cerrada','sobrante',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=operacion));
 ELSE RAISE EXCEPTION 'Acción de Masiva no reconocida'; END CASE;
 IF p_accion<>'cargar_lote' THEN
  INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos)
  VALUES(operacion,evento_kit,p_accion,actor,v_actor_nombre,
   jsonb_build_object('entrada',p_datos-'filas'-'logo_cliente'-'logo_empresa','resultado',resultado-'snapshot',
    'empacador_id',CASE WHEN p_accion='reportar_error' THEN k.empacador_id ELSE NULL END));
 END IF;
 IF req IS NOT NULL THEN INSERT INTO public.masiva_solicitudes(request_id,actor_id,accion,huella,respuesta) VALUES(req,actor,p_accion,huella,resultado); END IF;
 RETURN resultado;
END $$;

REVOKE ALL ON FUNCTION public.masiva_acceso(),public.masiva_inmutable(),public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_acceso(),public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) TO authenticated;
COMMENT ON TABLE public.masiva_operaciones IS 'Operaciones independientes: cierre conserva inventario sobrante, historial y documentos; nunca alimenta la siguiente operación.';
COMMENT ON TABLE public.masiva_documentos IS 'Snapshot inmutable por versión, incluidos logos y datos de caja. Reimpresión desde snapshot, nunca desde datos actuales.';
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 130_masiva_recepcion.sql
-- Aplicar después de 129. Conserva inventario, movimientos, auditoría y documentos.
-- No importa recepciones históricas, fechas ni novedades del Excel de ejemplo.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.masiva_ejecutar(text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Aplica primero la migración 129'; END IF;
END $$;

CREATE TABLE public.masiva_pedidos (
 operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 proveedor text NOT NULL CHECK(length(trim(proveedor)) BETWEEN 1 AND 160),
 pedido text NOT NULL CHECK(length(trim(pedido)) BETWEEN 1 AND 100),
 horario text NOT NULL DEFAULT '' CHECK(length(horario)<=240),
 novedad text NOT NULL DEFAULT '' CHECK(length(novedad)<=1000),
 orden_carga integer NOT NULL CHECK(orden_carga>0),
 PRIMARY KEY(operacion_id,proveedor,pedido),UNIQUE(operacion_id,orden_carga)
);
ALTER TABLE public.masiva_pedidos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.masiva_pedidos FROM PUBLIC,anon,authenticated;
-- Recuperar el orden original del plan confirmado; si no existe staging, usar orden estable.
WITH origen AS(
 SELECT imp.operacion_id,trim(f.value->>'proveedor') AS proveedor,trim(f.value->>'pedido') AS pedido,
  min(l.indice::bigint*1000+f.ordinality) AS primera_fila
 FROM public.masiva_importaciones imp JOIN public.masiva_importacion_lotes l ON l.importacion_id=imp.id
 CROSS JOIN LATERAL jsonb_array_elements(l.filas) WITH ORDINALITY f(value,ordinality)
 WHERE imp.tipo='recepcion' AND imp.estado='confirmada' GROUP BY 1,2,3
), claves AS(SELECT DISTINCT operacion_id,proveedor,pedido FROM public.masiva_inventario)
INSERT INTO public.masiva_pedidos(operacion_id,proveedor,pedido,orden_carga)
 SELECT i.operacion_id,i.proveedor,i.pedido,
  row_number() OVER(PARTITION BY i.operacion_id ORDER BY o.primera_fila NULLS LAST,i.proveedor,i.pedido)::integer
 FROM claves i LEFT JOIN origen o USING(operacion_id,proveedor,pedido);
COMMENT ON TABLE public.masiva_pedidos IS 'Metadatos por operación, proveedor y pedido. Cantidades calculadas desde inventario real; cambios auditados por RPC.';

CREATE OR REPLACE FUNCTION public.masiva_ejecutar(p_accion text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='10s' SET statement_timeout='180s' AS $$
DECLARE actor uuid:=auth.uid(); v_actor_nombre text; es_admin boolean; op public.masiva_operaciones; operacion uuid;
 imp public.masiva_importaciones; k public.masiva_kits; art public.masiva_articulos; inv public.masiva_inventario;
 asig public.masiva_asignaciones; persona public.masiva_personal; empaque public.masiva_empaques; caja public.masiva_cajas;
 solicitud public.masiva_solicitudes; req uuid; huella text; resultado jsonb; id_nuevo uuid; v_filas jsonb; fila jsonb;
 n integer; n_desde integer; n_hasta integer; v_cantidad integer; cambio integer; restante integer; tomar integer;
 version_documento integer; consumo record; credito record; anterior jsonb; snapshot jsonb; evento_kit uuid; ahora timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 SELECT u.nombre,coalesce(u.roles,ARRAY[u.rol]) @> ARRAY['admin'] INTO v_actor_nombre,es_admin FROM public.usuarios u WHERE u.auth_id=actor AND u.activo;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>5000000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF p_accion IN('crear_operacion','iniciar_importacion','cargar_lote','confirmar_importacion','cancelar_importacion','guardar_personal','guardar_empaque','cerrar_operacion','configurar','configurar_recepcion') AND NOT es_admin
 THEN RAISE EXCEPTION 'Esta acción requiere administrador' USING ERRCODE='42501'; END IF;
 IF p_accion IN('recibir','validar','corregir','reportar_error') THEN
  req:=nullif(p_datos->>'request_id','')::uuid; IF req IS NULL THEN RAISE EXCEPTION 'Falta el identificador de la solicitud'; END IF;
  huella:=md5((p_datos-'request_id')::text);
  SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
  IF FOUND THEN
   IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
   RETURN solicitud.respuesta;
  END IF;
 END IF;
 operacion:=nullif(p_datos->>'operacion_id','')::uuid;
 IF p_accion IN('cargar_lote','confirmar_importacion','cancelar_importacion') THEN
  SELECT * INTO imp FROM public.masiva_importaciones WHERE id=(p_datos->>'importacion_id')::uuid;
  IF imp.id IS NULL THEN RAISE EXCEPTION 'Importación no encontrada'; END IF;
  operacion:=imp.operacion_id;
 END IF;
 IF p_accion NOT IN('crear_operacion','guardar_personal','guardar_empaque') THEN
  SELECT * INTO op FROM public.masiva_operaciones WHERE id=operacion FOR UPDATE;
  IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
  IF imp.id IS NOT NULL THEN
   -- La carga pudo cancelarse o confirmarse mientras esperábamos el bloqueo.
   SELECT * INTO imp FROM public.masiva_importaciones WHERE id=imp.id FOR UPDATE;
  END IF;
  IF req IS NOT NULL THEN
   SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
   IF FOUND THEN
    IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
    RETURN solicitud.respuesta;
   END IF;
  END IF;
  IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;
 END IF;

 CASE p_accion
 WHEN 'crear_operacion' THEN
  INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;
  resultado:=jsonb_build_object('id',operacion);
 WHEN 'guardar_personal' THEN
  IF nullif(trim(p_datos->>'usuario_numero'),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE numero_usuario=trim(p_datos->>'usuario_numero') AND activo)
  THEN RAISE EXCEPTION 'Usuario asociado no encontrado o inactivo'; END IF;
  INSERT INTO public.masiva_personal(nombre,usuario_numero,creado_por) VALUES(trim(p_datos->>'nombre'),nullif(trim(p_datos->>'usuario_numero'),''),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'guardar_empaque' THEN
  INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por)
  VALUES(trim(p_datos->>'nombre'),(p_datos->>'peso_vacio')::numeric,(p_datos->>'peso_lleno')::numeric,(p_datos->>'largo')::numeric,
  (p_datos->>'ancho')::numeric,(p_datos->>'alto')::numeric,coalesce(p_datos->>'tipo','caja'),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'iniciar_importacion' THEN
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND tipo=p_datos->>'tipo' AND estado<>'cancelada') THEN RAISE EXCEPTION 'Ya existe una carga de este tipo; finaliza o cancela la carga pendiente'; END IF;
  INSERT INTO public.masiva_importaciones(operacion_id,tipo,archivo,total_filas,total_lotes,creado_por)
  VALUES(operacion,p_datos->>'tipo',p_datos->>'archivo',(p_datos->>'total_filas')::integer,(p_datos->>'total_lotes')::integer,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('importacion_id',id_nuevo);
 WHEN 'cargar_lote' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La importación ya no admite lotes'; END IF;
  n:=(p_datos->>'indice')::integer; v_filas:=p_datos->'filas';
  IF n IS NULL OR n<0 OR n>=imp.total_lotes OR jsonb_typeof(v_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(v_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Lote inválido'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id AND indice=n AND masiva_importacion_lotes.filas<>v_filas) THEN RAISE EXCEPTION 'El lote ya existe con contenido diferente'; END IF;
  INSERT INTO public.masiva_importacion_lotes(importacion_id,indice,filas) VALUES(imp.id,n,v_filas) ON CONFLICT DO NOTHING;
  resultado:=jsonb_build_object('importacion_id',imp.id,'indice',n,'filas',jsonb_array_length(v_filas));
 WHEN 'cancelar_importacion' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'Solo puede cancelarse una carga sin confirmar'; END IF;
  UPDATE public.masiva_importaciones SET estado='cancelada' WHERE id=imp.id;
  resultado:=jsonb_build_object('cancelada',true);
 WHEN 'confirmar_importacion' THEN
  IF imp.estado='confirmada' THEN RETURN jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas); END IF;
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La carga fue cancelada'; END IF;
  IF (SELECT count(*) FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id)<>imp.total_lotes
  OR (SELECT coalesce(sum(jsonb_array_length(l.filas)),0) FROM public.masiva_importacion_lotes l WHERE importacion_id=imp.id)<>imp.total_filas THEN RAISE EXCEPTION 'La carga está incompleta; vuelve a enviar los lotes pendientes'; END IF;
  SELECT jsonb_agg(x.value ORDER BY l.indice,x.ordinality) INTO v_filas FROM public.masiva_importacion_lotes l CROSS JOIN LATERAL jsonb_array_elements(l.filas) WITH ORDINALITY x(value,ordinality) WHERE l.importacion_id=imp.id;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE jsonb_typeof(f)<>'object' OR length(trim(coalesce(f->>'sku',''))) NOT BETWEEN 1 AND 100
  OR length(trim(coalesce(f->>'descripcion',''))) NOT BETWEEN 1 AND 500 OR coalesce(f->>'cantidad','') !~ '^[0-9]{1,7}$' OR (f->>'cantidad')::integer<1)
  THEN RAISE EXCEPTION 'Hay referencias, descripciones o cantidades inválidas en el archivo'; END IF;
  IF imp.tipo='recepcion' THEN
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'proveedor',''))) NOT BETWEEN 1 AND 160 OR length(trim(coalesce(f->>'pedido',''))) NOT BETWEEN 1 AND 100
    OR upper(trim(coalesce(f->>'unidad','UNIDAD'))) NOT IN('UNIDAD','UN','UND','PAR','PARES')) THEN RAISE EXCEPTION 'Proveedor, pedido o unidad inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1) THEN RAISE EXCEPTION 'Hay referencias repetidas dentro del mismo pedido y proveedor'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(coalesce(f->>'horario',''))>240)
   THEN RAISE EXCEPTION 'El horario de recepción admite máximo 240 caracteres'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido') FROM jsonb_array_elements(v_filas) f
    GROUP BY 1,2 HAVING count(DISTINCT nullif(trim(f->>'horario'),''))>1)
   THEN RAISE EXCEPTION 'Hay horarios distintos para una misma orden de compra'; END IF;
   INSERT INTO public.masiva_pedidos(operacion_id,proveedor,pedido,horario,orden_carga)
   SELECT operacion,proveedor,pedido,horario,row_number() OVER(ORDER BY primera_fila)::integer
   FROM (SELECT trim(f.value->>'proveedor') AS proveedor,trim(f.value->>'pedido') AS pedido,
    coalesce(max(nullif(trim(f.value->>'horario'),'')),'') AS horario,min(f.ordinality) AS primera_fila
    FROM jsonb_array_elements(v_filas) WITH ORDINALITY f(value,ordinality) GROUP BY 1,2) q;
   INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,unidad,esperado)
   SELECT operacion,trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku'),trim(f->>'descripcion'),CASE WHEN upper(trim(f->>'unidad')) IN('PAR','PARES') THEN 'PAR' ELSE 'UNIDAD' END,(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f;
  ELSE
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'lista',''))) NOT BETWEEN 1 AND 100
    OR length(trim(coalesce(f->>'cedula',''))) NOT BETWEEN 1 AND 100 OR length(trim(coalesce(f->>'nombre',''))) NOT BETWEEN 1 AND 200
    OR coalesce(f->>'numero_persona','') !~ '^[0-9]{1,7}$' OR (f->>'numero_persona')::integer<1) THEN RAISE EXCEPTION 'Lista, documento, nombre o consecutivo de persona inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT (f->>'numero_persona')::integer)>1 OR count(DISTINCT trim(f->>'nombre'))>1)
   OR EXISTS(SELECT trim(f->>'lista'),(f->>'numero_persona')::integer FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT trim(f->>'cedula'))>1)
   THEN RAISE EXCEPTION 'Una persona tiene datos distintos o un consecutivo está asignado a varias personas'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1)
   THEN RAISE EXCEPTION 'Referencia repetida en un kit; unifica su cantidad antes de confirmar'; END IF;
   INSERT INTO public.masiva_listas(operacion_id,lista,sede,ciudad,direccion,unidad,sector,responsable,responsables)
   SELECT operacion,trim(f->>'lista'),max(coalesce(f->>'sede','')),max(coalesce(f->>'ciudad','')),max(coalesce(f->>'direccion','')),
   max(coalesce(f->>'unidad','')),max(coalesce(f->>'sector','')),coalesce(min(nullif(trim(f->>'lider'),'')),''),
   coalesce(jsonb_agg(DISTINCT trim(f->>'lider')) FILTER(WHERE nullif(trim(f->>'lider'),'') IS NOT NULL),'[]') FROM jsonb_array_elements(v_filas) f GROUP BY trim(f->>'lista');
   INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
   SELECT operacion,trim(f->>'lista'),(f->>'numero_persona')::integer,trim(f->>'cedula'),trim(f->>'nombre') FROM jsonb_array_elements(v_filas) f GROUP BY 2,3,4,5;
   INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad)
   SELECT kit_fila.id,trim(f->>'sku'),trim(f->>'descripcion'),(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f
   JOIN public.masiva_kits kit_fila ON kit_fila.operacion_id=operacion AND kit_fila.lista=trim(f->>'lista') AND kit_fila.cedula=trim(f->>'cedula');
  END IF;
  UPDATE public.masiva_importaciones SET estado='confirmada',confirmado=ahora WHERE id=imp.id;
  resultado:=jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas);
 WHEN 'recibir' THEN
  SELECT * INTO inv FROM public.masiva_inventario WHERE id=(p_datos->>'inventario_id')::uuid AND operacion_id=operacion FOR UPDATE;
  v_cantidad:=(p_datos->>'cantidad')::integer;
  IF inv.id IS NULL OR v_cantidad IS NULL OR v_cantidad<1 THEN RAISE EXCEPTION 'Referencia o cantidad no válida'; END IF;
  IF inv.recibido+v_cantidad>inv.esperado THEN RAISE EXCEPTION 'La recepción supera el límite del pedido (% pendientes)',inv.esperado-inv.recibido; END IF;
  IF length(trim(coalesce(p_datos->>'soporte',''))) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'Registra la remisión o soporte de recepción'; END IF;
  IF p_datos ? 'novedad' THEN
   IF jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
   UPDATE public.masiva_pedidos SET novedad=trim(p_datos->>'novedad')
   WHERE operacion_id=operacion AND proveedor=inv.proveedor AND pedido=inv.pedido;
  END IF;
  UPDATE public.masiva_inventario SET recibido=recibido+v_cantidad WHERE id=inv.id;
  INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,'recepcion',v_cantidad,trim(p_datos->>'soporte'),actor);
  resultado:=jsonb_build_object('id',inv.id,'recibido',inv.recibido+v_cantidad,'disponible',inv.recibido+v_cantidad-inv.validado);
 WHEN 'asignar' THEN
  SELECT * INTO persona FROM public.masiva_personal WHERE id=(p_datos->>'empacador_id')::uuid AND activo;
  IF persona.id IS NULL THEN RAISE EXCEPTION 'Selecciona una persona activa'; END IF;
  SELECT min(numero_persona),max(numero_persona) INTO n_desde,n_hasta FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  n_desde:=coalesce(nullif(p_datos->>'desde','')::integer,n_desde); n_hasta:=coalesce(nullif(p_datos->>'hasta','')::integer,n_hasta);
  IF n_desde IS NULL OR n_hasta IS NULL OR n_desde<1 OR n_hasta<n_desde THEN RAISE EXCEPTION 'Lista o rango inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_desde)
  OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_hasta) THEN RAISE EXCEPTION 'El rango debe iniciar y terminar en personas de la lista'; END IF;
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=persona.id AND desde=n_desde AND hasta=n_hasta;
  IF asig.id IS NOT NULL THEN RETURN jsonb_build_object('id',asig.id,'desde',n_desde,'hasta',n_hasta); END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta AND empacador_id IS NOT NULL)
  THEN RAISE EXCEPTION 'El rango se cruza con kits ya asignados'; END IF;
  INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,creado_por) VALUES(operacion,p_datos->>'lista',persona.id,n_desde,n_hasta,actor) RETURNING id INTO id_nuevo;
  UPDATE public.masiva_kits SET empacador_id=persona.id,asignacion_id=id_nuevo WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta;
  GET DIAGNOSTICS n=ROW_COUNT;
  resultado:=jsonb_build_object('id',id_nuevo,'kits',n,'desde',n_desde,'hasta',n_hasta);
 WHEN 'tiempo' THEN
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion
  AND ((nullif(p_datos->>'asignacion_id','') IS NOT NULL AND id=(p_datos->>'asignacion_id')::uuid)
   OR (nullif(p_datos->>'asignacion_id','') IS NULL AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid
   AND (nullif(p_datos->>'desde','') IS NULL OR desde=(p_datos->>'desde')::integer) AND(nullif(p_datos->>'hasta','') IS NULL OR hasta=(p_datos->>'hasta')::integer))) ORDER BY creado LIMIT 1 FOR UPDATE;
  IF asig.id IS NULL THEN RAISE EXCEPTION 'Selecciona una asignación de empaque'; END IF;
  -- Evita que dos operaciones inicien simultáneamente el tiempo de la misma persona.
  PERFORM 1 FROM public.masiva_personal WHERE id=asig.empacador_id FOR UPDATE;
  IF nullif(p_datos->>'asignacion_id','') IS NULL AND nullif(p_datos->>'desde','') IS NULL AND (SELECT count(*) FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid)>1
  THEN RAISE EXCEPTION 'Selecciona el rango de empaque para registrar su tiempo'; END IF;
  IF p_datos->>'accion'='iniciar' THEN
   IF asig.estado NOT IN('pendiente','pausado') THEN RAISE EXCEPTION 'El empaque ya está iniciado o finalizado'; END IF;
   IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=asig.empacador_id AND estado='en_curso' AND id<>asig.id) THEN RAISE EXCEPTION 'Esta persona ya tiene otro empaque en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='en_curso',inicio=coalesce(inicio,ahora),ultimo_inicio=ahora WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armando' WHERE asignacion_id=asig.id;
  ELSIF p_datos->>'accion'='pausar' THEN
   IF asig.estado<>'en_curso' THEN RAISE EXCEPTION 'El empaque no está en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='pausado',segundos=segundos+extract(epoch FROM ahora-ultimo_inicio),ultimo_inicio=NULL WHERE id=asig.id;
  ELSIF p_datos->>'accion'='finalizar' THEN
   IF asig.estado NOT IN('en_curso','pausado') THEN RAISE EXCEPTION 'Inicia el empaque antes de finalizarlo'; END IF;
   UPDATE public.masiva_asignaciones SET estado='finalizado',fin=ahora,segundos=segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM ahora-ultimo_inicio) ELSE 0 END,ultimo_inicio=NULL WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armado',armado=ahora WHERE asignacion_id=asig.id;
  ELSE RAISE EXCEPTION 'Acción de tiempo inválida'; END IF;
  SELECT to_jsonb(s) INTO resultado FROM public.masiva_asignaciones s WHERE id=asig.id;
 WHEN 'validar','corregir','reabrir','embalar','reportar_error' THEN
  SELECT * INTO k FROM public.masiva_kits WHERE id=(p_datos->>'kit_id')::uuid AND operacion_id=operacion FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'Kit no encontrado en esta operación'; END IF;
  evento_kit:=k.id;
  IF k.armado IS NULL THEN RAISE EXCEPTION 'Finaliza el armado del kit antes de validarlo'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo armó'; END IF;
  IF p_accion IN('reabrir','corregir','reportar_error') AND length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de la revisión'; END IF;
  IF p_accion='reabrir' THEN
   IF k.validacion_inicio IS NULL THEN RAISE EXCEPTION 'El kit todavía no tiene validaciones'; END IF;
   UPDATE public.masiva_kits SET revision_abierta=true WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'revision_abierta',true);
  ELSIF p_accion='reportar_error' THEN
   resultado:=jsonb_build_object('id',k.id,'empacador_id',k.empacador_id,'penalizacion',op.penalizacion_error);
  ELSIF p_accion='embalar' THEN
   IF NOT EXISTS(SELECT 1 FROM public.masiva_articulos WHERE kit_id=k.id AND validado>0) THEN RAISE EXCEPTION 'Valida al menos una prenda antes de asignar el empaque'; END IF;
   n:=(p_datos->>'caja')::integer; IF n IS NULL OR n<1 THEN RAISE EXCEPTION 'Número de caja inválido'; END IF;
   SELECT * INTO empaque FROM public.masiva_empaques WHERE id=(p_datos->>'empaque_id')::uuid AND activo;
   IF empaque.id IS NULL THEN RAISE EXCEPTION 'Selecciona el tipo de empaque'; END IF;
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL AND caja.empaque_id<>empaque.id THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   IF caja.id IS NULL THEN
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por) VALUES(operacion,k.lista,n,empaque.id,to_jsonb(empaque),actor) RETURNING * INTO caja;
   END IF;
   UPDATE public.masiva_kits SET caja_id=caja.id WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'caja',n);
  ELSE
   IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
   IF p_accion='validar' THEN
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND sku=trim(p_datos->>'sku') FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'El código no pertenece a este kit'; END IF;
    v_cantidad:=art.validado+1;
   ELSE
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND id=(p_datos->>'articulo_id')::uuid FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'Prenda no encontrada en el kit'; END IF;
    v_cantidad:=(p_datos->>'cantidad')::integer;
   END IF;
   IF v_cantidad IS NULL OR v_cantidad<0 OR v_cantidad>art.cantidad THEN RAISE EXCEPTION 'La cantidad excede lo solicitado para esta persona'; END IF;
   cambio:=v_cantidad-art.validado; restante:=abs(cambio); anterior:=to_jsonb(art);
   IF cambio>0 THEN
    FOR inv IN SELECT * FROM public.masiva_inventario WHERE operacion_id=operacion AND sku=art.sku AND recibido>validado ORDER BY proveedor,pedido,id FOR UPDATE LOOP
     tomar:=least(restante,inv.recibido-inv.validado);
     UPDATE public.masiva_inventario SET validado=validado+tomar WHERE id=inv.id;
     INSERT INTO public.masiva_consumos(articulo_id,inventario_id,cantidad) VALUES(art.id,inv.id,tomar)
     ON CONFLICT(articulo_id,inventario_id) DO UPDATE SET cantidad=masiva_consumos.cantidad+excluded.cantidad;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,art.id,CASE WHEN p_accion='validar' THEN 'validacion' ELSE 'correccion' END,-tomar,coalesce(p_datos->>'motivo',''),actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'No hay inventario recibido suficiente para este SKU'; END IF;
   ELSIF cambio<0 THEN
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     tomar:=least(restante,consumo.cantidad);
     UPDATE public.masiva_inventario SET validado=validado-tomar WHERE id=consumo.inventario_id;
     UPDATE public.masiva_consumos SET cantidad=masiva_consumos.cantidad-tomar WHERE articulo_id=art.id AND inventario_id=consumo.inventario_id;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,consumo.inventario_id,art.id,'correccion',tomar,p_datos->>'motivo',actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
   END IF;
   IF cambio>0 THEN
    INSERT INTO public.masiva_validacion_creditos(articulo_id,actor_id,cantidad,actualizado) VALUES(art.id,actor,cambio,ahora)
    ON CONFLICT(articulo_id,actor_id) DO UPDATE SET cantidad=masiva_validacion_creditos.cantidad+excluded.cantidad,actualizado=excluded.actualizado;
   ELSIF cambio<0 THEN
    restante:=-cambio;
    FOR credito IN SELECT * FROM public.masiva_validacion_creditos WHERE articulo_id=art.id AND cantidad>0 ORDER BY actualizado DESC,actor_id FOR UPDATE LOOP
     tomar:=least(restante,credito.cantidad);
     UPDATE public.masiva_validacion_creditos SET cantidad=masiva_validacion_creditos.cantidad-tomar,actualizado=ahora WHERE articulo_id=art.id AND actor_id=credito.actor_id;
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
   END IF;
   UPDATE public.masiva_articulos SET validado=v_cantidad WHERE id=art.id;
   SELECT count(*) INTO n FROM public.masiva_articulos WHERE kit_id=k.id AND validado<masiva_articulos.cantidad;
   UPDATE public.masiva_kits SET estado=CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,
   validacion_inicio=coalesce(validacion_inicio,ahora),validacion_fin=CASE WHEN n=0 THEN ahora ELSE NULL END,
   validador_id=actor,revision_abierta=n<>0 WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'articulo_id',art.id,'sku',art.sku,'validado',v_cantidad,'cantidad',art.cantidad,'estado',CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,'anterior',anterior,'diferencia',cambio);
  END IF;
 WHEN 'configurar_recepcion' THEN
  IF length(trim(coalesce(p_datos->>'proveedor',''))) NOT BETWEEN 1 AND 160
   OR length(trim(coalesce(p_datos->>'pedido',''))) NOT BETWEEN 1 AND 100
   OR NOT (p_datos ? 'horario' OR p_datos ? 'novedad') THEN RAISE EXCEPTION 'Selecciona una orden de compra y los datos a editar'; END IF;
  IF p_datos ? 'horario' AND (jsonb_typeof(p_datos->'horario') IS DISTINCT FROM 'string' OR length(p_datos->>'horario')>240)
   THEN RAISE EXCEPTION 'El horario admite máximo 240 caracteres'; END IF;
  IF p_datos ? 'novedad' AND (jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000)
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
  SELECT to_jsonb(p) INTO anterior FROM public.masiva_pedidos p
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido') FOR UPDATE;
  IF anterior IS NULL THEN RAISE EXCEPTION 'Orden de compra no encontrada'; END IF;
  UPDATE public.masiva_pedidos p SET
   horario=CASE WHEN p_datos ? 'horario' THEN trim(p_datos->>'horario') ELSE p.horario END,
   novedad=CASE WHEN p_datos ? 'novedad' THEN trim(p_datos->>'novedad') ELSE p.novedad END
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido');
  resultado:=jsonb_build_object('guardado',true,'anterior',anterior);
 WHEN 'configurar' THEN
  IF p_datos ? 'lista' THEN
   IF length(trim(coalesce(p_datos->>'responsable',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Registra el responsable principal'; END IF;
   UPDATE public.masiva_listas SET responsable=trim(p_datos->>'responsable') WHERE operacion_id=operacion AND lista=p_datos->>'lista';
   IF NOT FOUND THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  END IF;
  FOREACH v_actor_nombre IN ARRAY ARRAY['logo_cliente','logo_empresa'] LOOP
   IF p_datos ? v_actor_nombre AND (length(p_datos->>v_actor_nombre)>2000000 OR (p_datos->>v_actor_nombre<>'' AND p_datos->>v_actor_nombre !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/=\r\n]+$')) THEN RAISE EXCEPTION 'Usa un logo PNG o JPEG de máximo 1,5 MB'; END IF;
  END LOOP;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;
  UPDATE public.masiva_operaciones SET logo_cliente=coalesce(p_datos->>'logo_cliente',logo_cliente),logo_empresa=coalesce(p_datos->>'logo_empresa',logo_empresa),
  puntos_kit=coalesce((p_datos->>'puntos_kit')::integer,puntos_kit),puntos_prenda=coalesce((p_datos->>'puntos_prenda')::integer,puntos_prenda),
  penalizacion_error=coalesce((p_datos->>'penalizacion_error')::integer,penalizacion_error) WHERE id=operacion;
  resultado:=jsonb_build_object('guardado',true);
 WHEN 'documento' THEN
  IF coalesce(p_datos->>'tipo','') NOT IN('lista','rotulo') THEN RAISE EXCEPTION 'Tipo de documento inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=operacion AND lista=p_datos->>'lista') THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista'
   AND kit_fila.caja_id IS NULL AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Asigna un empaque a todos los kits con prendas validadas antes de emitir documentos'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista' AND kit_fila.caja_id IS NOT NULL
   AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Valida prendas y asígnalas a una caja antes de emitir documentos'; END IF;
  SELECT coalesce(max(version),0)+1 INTO version_documento FROM public.masiva_documentos WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND tipo=p_datos->>'tipo';
  SELECT jsonb_build_object('formato_version',1,'operacion',to_jsonb(op),'lista',to_jsonb(l),'responsable',l.responsable,'fecha',ahora,'version',version_documento,
  'kits',coalesce((SELECT jsonb_agg(to_jsonb(kit_fila)||jsonb_build_object('caja',c.numero,'empacador',p.nombre,'articulos',
   (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.sku) FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id)) ORDER BY kit_fila.numero_persona)
   FROM public.masiva_kits kit_fila LEFT JOIN public.masiva_cajas c ON c.id=kit_fila.caja_id LEFT JOIN public.masiva_personal p ON p.id=kit_fila.empacador_id
   WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=l.lista AND kit_fila.caja_id IS NOT NULL
    AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0)),'[]'),
  'empaques',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.numero) FROM public.masiva_cajas c WHERE c.operacion_id=operacion AND c.lista=l.lista),'[]'))
  INTO snapshot FROM public.masiva_listas l WHERE l.operacion_id=operacion AND l.lista=p_datos->>'lista';
  INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);
 WHEN 'cerrar_operacion' THEN
  IF length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de cierre'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE operacion_id=operacion AND estado IN('en_curso','pausado')) THEN RAISE EXCEPTION 'Finaliza los tiempos de empaque antes de cerrar'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND estado='cargando') THEN RAISE EXCEPTION 'Confirma o cancela las cargas pendientes antes de cerrar'; END IF;
  UPDATE public.masiva_operaciones SET estado='cerrada',cerrado=ahora,cerrado_por=actor,motivo_cierre=trim(p_datos->>'motivo') WHERE id=operacion;
  resultado:=jsonb_build_object('id',operacion,'estado','cerrada','sobrante',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=operacion));
 ELSE RAISE EXCEPTION 'Acción de Masiva no reconocida'; END CASE;
 IF p_accion<>'cargar_lote' THEN
  INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos)
  VALUES(operacion,evento_kit,p_accion,actor,v_actor_nombre,
   jsonb_build_object('entrada',p_datos-'filas'-'logo_cliente'-'logo_empresa','resultado',resultado-'snapshot',
    'empacador_id',CASE WHEN p_accion='reportar_error' THEN k.empacador_id ELSE NULL END));
 END IF;
 IF req IS NOT NULL THEN INSERT INTO public.masiva_solicitudes(request_id,actor_id,accion,huella,respuesta) VALUES(req,actor,p_accion,huella,resultado); END IF;
 RETURN resultado;
END $$;

-- Los filtros exactos se combinan con AND entre columnas y OR dentro de cada columna.
-- Cada faceta usa todo el conjunto filtrado salvo el filtro de su propia columna.
CREATE FUNCTION public.masiva_recepcion_consultar(
 p_operacion uuid,p_buscar text DEFAULT '',p_filtros jsonb DEFAULT '{}',p_pagina integer DEFAULT 1,
 p_proveedor text DEFAULT NULL,p_pedido text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE op public.masiva_operaciones; campos text[]; opciones jsonb; filas jsonb; metricas jsonb; pedido_datos jsonb;
 total bigint; recibido_total bigint; requerido_total bigint; sin_pedido bigint; personal_cargado boolean; detalle boolean;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200
 OR jsonb_typeof(p_filtros) IS DISTINCT FROM 'object' OR octet_length(p_filtros::text)>200000
 OR (p_proveedor IS NULL)<>(p_pedido IS NULL) OR length(coalesce(p_proveedor,''))>160 OR length(coalesce(p_pedido,''))>100
 THEN RAISE EXCEPTION 'Consulta de recepción inválida'; END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion;
 IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 detalle:=p_proveedor IS NOT NULL;
 IF detalle THEN SELECT to_jsonb(p) INTO pedido_datos FROM public.masiva_pedidos p
  WHERE p.operacion_id=p_operacion AND p.proveedor=p_proveedor AND p.pedido=p_pedido; END IF;
 p_buscar:=trim(coalesce(p_buscar,''));
 campos:=CASE WHEN detalle THEN ARRAY['proveedor','pedido','sku','descripcion','pendiente','esperado','recibido','disponible','global_recibido_sku','requerido_sku','saldo_sku','saldo_oc_sku']
 ELSE ARRAY['proveedor','pedido','pendiente','esperado','recibido','horario','novedad','saldo'] END;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f WHERE NOT f.key=ANY(campos) OR jsonb_typeof(f.value) IS DISTINCT FROM 'array')
 THEN RAISE EXCEPTION 'Columna o filtro de recepción inválido'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f WHERE jsonb_array_length(f.value)>2000)
 OR EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f CROSS JOIN LATERAL jsonb_array_elements(f.value) v
 WHERE jsonb_typeof(v.value) IS DISTINCT FROM 'string' OR length(v.value#>>'{}')>1000)
 THEN RAISE EXCEPTION 'Valores de filtro inválidos'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=p_operacion AND tipo='personal' AND estado='confirmada') INTO personal_cargado;
 SELECT coalesce(sum(recibido),0) INTO recibido_total FROM public.masiva_inventario WHERE operacion_id=p_operacion;
 SELECT coalesce(sum(a.cantidad),0) INTO requerido_total FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion;
 SELECT -coalesce(sum(a.cantidad),0) INTO sin_pedido FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id
 WHERE k.operacion_id=p_operacion AND NOT EXISTS(SELECT 1 FROM public.masiva_inventario i WHERE i.operacion_id=p_operacion AND i.sku=a.sku);
 metricas:=jsonb_build_object('recibido',recibido_total,'requerido',requerido_total,
  'saldo',CASE WHEN personal_cargado THEN recibido_total-requerido_total ELSE NULL END,
  'saldo_sin_pedido',CASE WHEN personal_cargado THEN sin_pedido ELSE NULL END,'base_personal_cargada',personal_cargado);

 WITH demanda AS MATERIALIZED(
  SELECT a.sku,sum(a.cantidad) AS requerido FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id
  WHERE k.operacion_id=p_operacion GROUP BY a.sku
 ), inventario AS MATERIALIZED(
  SELECT i.*,p.orden_carga FROM public.masiva_inventario i JOIN public.masiva_pedidos p USING(operacion_id,proveedor,pedido) WHERE i.operacion_id=p_operacion
 ), global_sku AS MATERIALIZED(
  SELECT i.sku,sum(i.recibido) AS recibido,count(*) AS pedidos,max(i.orden_carga) AS ultimo_orden FROM inventario i GROUP BY i.sku
 ), pedidos AS MATERIALIZED(
  SELECT i.proveedor,i.pedido,sum(i.esperado) AS esperado,sum(i.recibido) AS recibido,
   sum(i.esperado-i.recibido) AS pendiente,coalesce(p.horario,'') AS horario,coalesce(p.novedad,'') AS novedad,
   CASE WHEN personal_cargado THEN sum(CASE WHEN i.orden_carga=g.ultimo_orden THEN g.recibido-coalesce(d.requerido,0) ELSE 0 END) ELSE NULL END AS saldo,
   bool_or(g.pedidos>1 AND coalesce(d.requerido,0)>0) AS compartido,p.orden_carga
  FROM inventario i JOIN global_sku g ON g.sku=i.sku LEFT JOIN demanda d ON d.sku=i.sku
  LEFT JOIN public.masiva_pedidos p ON p.operacion_id=p_operacion AND p.proveedor=i.proveedor AND p.pedido=i.pedido
  GROUP BY i.proveedor,i.pedido,p.horario,p.novedad,p.orden_carga
 ), datos AS MATERIALIZED(
  SELECT to_jsonb(p) AS fila,lpad(p.orden_carga::text,10,'0') AS orden FROM pedidos p WHERE NOT detalle
   AND (p_buscar='' OR position(lower(p_buscar) IN lower(p.proveedor||' '||p.pedido||' '||p.horario||' '||p.novedad))>0
    OR EXISTS(SELECT 1 FROM inventario i WHERE i.proveedor=p.proveedor AND i.pedido=p.pedido
     AND position(lower(p_buscar) IN lower(i.sku||' '||i.descripcion))>0))
  UNION ALL
  SELECT to_jsonb(i)||jsonb_build_object('pendiente',i.esperado-i.recibido,'disponible',i.recibido-i.validado,
   'global_recibido_sku',g.recibido,'requerido_sku',coalesce(d.requerido,0),
   'saldo_sku',CASE WHEN personal_cargado THEN g.recibido-coalesce(d.requerido,0) ELSE NULL END,
   'saldo_oc_sku',CASE WHEN NOT personal_cargado THEN NULL WHEN i.orden_carga=g.ultimo_orden THEN g.recibido-coalesce(d.requerido,0) ELSE 0 END,
   'ultima_oc_sku',i.orden_carga=g.ultimo_orden,
   'compartido',g.pedidos>1 AND coalesce(d.requerido,0)>0),i.sku
  FROM inventario i JOIN global_sku g ON g.sku=i.sku LEFT JOIN demanda d ON d.sku=i.sku
  WHERE detalle AND i.proveedor=p_proveedor AND i.pedido=p_pedido
   AND (p_buscar='' OR position(lower(p_buscar) IN lower(i.sku||' '||i.descripcion||' '||i.proveedor||' '||i.pedido))>0)
 ), filtrados AS MATERIALIZED(
  SELECT d.* FROM datos d WHERE NOT EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f
   WHERE jsonb_array_length(f.value)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(f.value) v WHERE v.value=coalesce(d.fila->>f.key,'')))
 ), pagina AS(
  SELECT * FROM filtrados ORDER BY orden LIMIT 50 OFFSET (p_pagina-1)*50
 ), facetas AS(
  SELECT c.campo,coalesce((SELECT jsonb_agg(v.valor ORDER BY v.valor) FROM (
   SELECT DISTINCT coalesce(d.fila->>c.campo,'') AS valor FROM datos d WHERE (d.fila->>c.campo IS NOT NULL OR c.campo='saldo')
   AND NOT EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f WHERE f.key<>c.campo AND jsonb_array_length(f.value)>0
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(f.value) v WHERE v.value=coalesce(d.fila->>f.key,'')))
  ) v),'[]') AS valores FROM unnest(campos) c(campo)
 )
 SELECT (SELECT count(*) FROM filtrados),coalesce((SELECT jsonb_agg(p.fila ORDER BY p.orden) FROM pagina p),'[]'),
  coalesce((SELECT jsonb_object_agg(campo,valores) FROM facetas),'{}') INTO total,filas,opciones;
 RETURN jsonb_build_object('filas',filas,'total',total,'pagina',p_pagina,'opciones',opciones,'metricas',metricas,'pedido',pedido_datos);
END $$;

REVOKE ALL ON FUNCTION public.masiva_recepcion_consultar(uuid,text,jsonb,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_recepcion_consultar(uuid,text,jsonb,integer,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.masiva_ejecutar(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_ejecutar(text,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 131_masiva_validacion.sql
-- Aplicar después de 130. No reimporta datos ni modifica filas existentes.
-- Rechazos de escaneo identifican la prenda; reinicios reintegran inventario y quedan auditados.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.masiva_recepcion_consultar(uuid,text,jsonb,integer,text,text)') IS NULL
 THEN RAISE EXCEPTION 'Aplica primero la migración 130'; END IF;
END $$;
CREATE INDEX IF NOT EXISTS masiva_movimientos_articulo_fecha
 ON public.masiva_movimientos(articulo_id,creado DESC) WHERE articulo_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.masiva_consultar(p_operacion uuid DEFAULT NULL,p_vista text DEFAULT 'resumen',p_buscar text DEFAULT '',p_pagina integer DEFAULT 1,p_lista text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE op public.masiva_operaciones; filas jsonb:='[]'; metricas jsonb; total bigint:=0; desplazamiento integer;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200 THEN RAISE EXCEPTION 'Consulta inválida'; END IF;
 desplazamiento:=(p_pagina-1)*50; p_buscar:=trim(coalesce(p_buscar,'')); p_lista:=trim(coalesce(p_lista,''));
 IF p_operacion IS NULL THEN
  RETURN jsonb_build_object('operaciones',coalesce((SELECT jsonb_agg(to_jsonb(o) - 'logo_cliente' - 'logo_empresa' ORDER BY o.creado DESC) FROM public.masiva_operaciones o),'[]'::jsonb));
 END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion;
 IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 SELECT jsonb_build_object('kits',count(*),'armados',count(*) FILTER(WHERE armado IS NOT NULL),
 'validados',count(*) FILTER(WHERE estado='validado'),'parciales',count(*) FILTER(WHERE estado='parcial')) INTO metricas FROM public.masiva_kits WHERE operacion_id=p_operacion;
 metricas:=metricas||jsonb_build_object(
 'importaciones',coalesce((SELECT jsonb_object_agg(i.tipo,jsonb_build_object('id',i.id,'estado',i.estado,'filas',i.total_filas,'archivo',i.archivo))
 FROM public.masiva_importaciones i WHERE i.operacion_id=p_operacion AND i.estado<>'cancelada'),'{}'::jsonb),
 'unidades',(SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion),
 'unidades_validadas',(SELECT coalesce(sum(validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'esperado',(SELECT coalesce(sum(esperado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'recibido',(SELECT coalesce(sum(recibido),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'disponible',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'segundos_empaque',(SELECT coalesce(sum(segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM now()-ultimo_inicio) ELSE 0 END),0) FROM public.masiva_asignaciones WHERE operacion_id=p_operacion),
 'promedio_segundos_kit',(SELECT coalesce(round(sum(s.segundos)/nullif(sum((SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)),0),2),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.estado='finalizado'),
 'cajas',(SELECT count(*) FROM public.masiva_cajas c WHERE c.operacion_id=p_operacion),
 'primera_recepcion',(SELECT min(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'ultima_recepcion',(SELECT max(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'duracion_recepcion_segundos',(SELECT coalesce(extract(epoch FROM max(creado)-min(creado)),0) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'inicio_validacion',(SELECT min(validacion_inicio) FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'fin_validacion',(SELECT CASE WHEN count(*)>0 AND count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE NULL END FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_validacion_segundos',(SELECT coalesce(extract(epoch FROM
  (CASE WHEN count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE coalesce(op.cerrado,now()) END)-min(validacion_inicio)),0)
  FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_operacion_segundos',extract(epoch FROM coalesce(op.cerrado,now())-op.creado));
 IF p_vista='inventario' THEN
  WITH datos AS (SELECT i.*,i.recibido-i.validado AS disponible,i.esperado-i.recibido AS pendiente,
  (SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion AND a.sku=i.sku) AS requerido
  FROM public.masiva_inventario i WHERE i.operacion_id=p_operacion AND (p_buscar='' OR i.sku ILIKE '%'||p_buscar||'%' OR i.descripcion ILIKE '%'||p_buscar||'%' OR i.proveedor ILIKE '%'||p_buscar||'%')),
  pagina AS(SELECT * FROM datos ORDER BY proveedor,pedido,sku LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='listas' THEN
  WITH datos AS(SELECT l.*,count(k.id) AS kits,count(k.id) FILTER(WHERE k.armado IS NOT NULL) AS armados,
  count(k.id) FILTER(WHERE k.estado='validado') AS validados FROM public.masiva_listas l LEFT JOIN public.masiva_kits k ON k.operacion_id=l.operacion_id AND k.lista=l.lista
  WHERE l.operacion_id=p_operacion AND (p_lista='' OR l.lista=p_lista) AND (p_buscar='' OR l.lista ILIKE '%'||p_buscar||'%' OR l.sede ILIKE '%'||p_buscar||'%') GROUP BY l.operacion_id,l.lista),
  pagina AS(SELECT * FROM datos ORDER BY lista LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='kits' THEN
  WITH datos AS(SELECT k.*,c.numero AS caja,c.empaque_id,c.empaque_snapshot->>'tipo' AS caja_tipo,
  c.empaque_snapshot->>'nombre' AS caja_nombre,p.nombre AS empacador,l.sede,l.sector,l.ciudad,l.unidad
  FROM public.masiva_kits k JOIN public.masiva_listas l ON l.operacion_id=k.operacion_id AND l.lista=k.lista
  LEFT JOIN public.masiva_cajas c ON c.id=k.caja_id LEFT JOIN public.masiva_personal p ON p.id=k.empacador_id
  WHERE k.operacion_id=p_operacion AND (p_lista='' OR k.lista=p_lista)
  AND(p_buscar='' OR k.id::text=p_buscar OR k.numero_persona::text=p_buscar OR k.cedula ILIKE '%'||p_buscar||'%' OR k.nombre ILIKE '%'||p_buscar||'%')),
  pagina AS(SELECT * FROM datos ORDER BY lista,numero_persona LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)||jsonb_build_object('articulos',
  (SELECT jsonb_agg(to_jsonb(a)||jsonb_build_object('fecha_hora_validado',CASE WHEN a.validado>0 THEN
   (SELECT m.creado FROM public.masiva_movimientos m WHERE m.articulo_id=a.id ORDER BY m.creado DESC LIMIT 1) ELSE NULL END) ORDER BY a.sku)
   FROM public.masiva_articulos a WHERE a.kit_id=pagina.id))),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='auditoria' THEN
  WITH datos AS(SELECT a.* FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND(p_buscar='' OR a.accion ILIKE '%'||p_buscar||'%' OR a.actor_nombre ILIKE '%'||p_buscar||'%' OR a.kit_id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='personal' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.nombre),'[]') INTO total,filas FROM public.masiva_personal p WHERE p.activo;
 ELSIF p_vista='empaques' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.nombre),'[]') INTO total,filas FROM public.masiva_empaques e WHERE e.activo;
 ELSIF p_vista='asignaciones' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('empacador',p.nombre,'kits',(SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)) ORDER BY s.lista,s.desde),'[]')
  INTO total,filas FROM public.masiva_asignaciones s JOIN public.masiva_personal p ON p.id=s.empacador_id WHERE s.operacion_id=p_operacion AND(p_lista='' OR s.lista=p_lista);
 ELSIF p_vista='documentos' THEN
  WITH datos AS(SELECT d.* FROM public.masiva_documentos d WHERE d.operacion_id=p_operacion AND(p_lista='' OR d.lista=p_lista) AND(p_buscar='' OR d.id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg((CASE WHEN p_buscar<>'' THEN to_jsonb(pagina) ELSE to_jsonb(pagina)-'snapshot' END)||jsonb_build_object('created_at',pagina.creado)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='indicadores' THEN
  WITH datos AS(SELECT p.id,p.nombre,
  (SELECT count(*) FROM public.masiva_kits k WHERE k.operacion_id=p_operacion AND k.empacador_id=p.id AND k.armado IS NOT NULL) AS kits,
  (SELECT coalesce(sum(s.segundos),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.empacador_id=p.id AND s.estado='finalizado') AS segundos,
  (SELECT count(*) FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND a.accion='reportar_error' AND a.datos->>'empacador_id'=p.id::text) AS errores
  FROM public.masiva_personal p WHERE EXISTS(SELECT 1 FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.empacador_id=p.id))
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(datos)||jsonb_build_object('puntos',kits*op.puntos_kit-errores*op.penalizacion_error,'promedio_segundos',round(segundos/nullif(kits,0),2)) ORDER BY kits DESC,nombre),'[]') INTO total,filas FROM datos;
  metricas:=metricas||jsonb_build_object('validadores',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
  SELECT c.actor_id,u.nombre AS actor_nombre,sum(c.cantidad) AS prendas,sum(c.cantidad)*op.puntos_prenda AS puntos
  FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id
  JOIN public.masiva_kits k ON k.id=a.kit_id JOIN public.usuarios u ON u.auth_id=c.actor_id
  WHERE k.operacion_id=p_operacion GROUP BY c.actor_id,u.nombre ORDER BY prendas DESC) x),'[]'::jsonb));
 ELSIF p_vista NOT IN('resumen','configuracion') THEN RAISE EXCEPTION 'Vista no reconocida'; END IF;
 RETURN jsonb_build_object('operacion',to_jsonb(op),'metricas',metricas,'filas',filas,'total',total,'pagina',p_pagina);
END $$;

CREATE OR REPLACE FUNCTION public.masiva_ejecutar(p_accion text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='10s' SET statement_timeout='180s' AS $$
DECLARE actor uuid:=auth.uid(); v_actor_nombre text; es_admin boolean; op public.masiva_operaciones; operacion uuid;
 imp public.masiva_importaciones; k public.masiva_kits; art public.masiva_articulos; inv public.masiva_inventario;
 asig public.masiva_asignaciones; persona public.masiva_personal; empaque public.masiva_empaques; caja public.masiva_cajas;
 solicitud public.masiva_solicitudes; req uuid; huella text; resultado jsonb; id_nuevo uuid; v_filas jsonb; fila jsonb;
 n integer; n_desde integer; n_hasta integer; v_cantidad integer; cambio integer; restante integer; tomar integer;
 version_documento integer; consumo record; credito record; anterior jsonb; snapshot jsonb; evento_kit uuid; ahora timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 SELECT u.nombre,coalesce(u.roles,ARRAY[u.rol]) @> ARRAY['admin'] INTO v_actor_nombre,es_admin FROM public.usuarios u WHERE u.auth_id=actor AND u.activo;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>5000000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF p_accion IN('crear_operacion','iniciar_importacion','cargar_lote','confirmar_importacion','cancelar_importacion','guardar_personal','guardar_empaque','cerrar_operacion','configurar','configurar_recepcion') AND NOT es_admin
 THEN RAISE EXCEPTION 'Esta acción requiere administrador' USING ERRCODE='42501'; END IF;
 IF p_accion IN('recibir','validar','corregir','reportar_error','reiniciar_validacion') THEN
  req:=nullif(p_datos->>'request_id','')::uuid; IF req IS NULL THEN RAISE EXCEPTION 'Falta el identificador de la solicitud'; END IF;
  huella:=md5((p_datos-'request_id')::text);
  SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
  IF FOUND THEN
   IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
   RETURN solicitud.respuesta;
  END IF;
 END IF;
 operacion:=nullif(p_datos->>'operacion_id','')::uuid;
 IF p_accion IN('cargar_lote','confirmar_importacion','cancelar_importacion') THEN
  SELECT * INTO imp FROM public.masiva_importaciones WHERE id=(p_datos->>'importacion_id')::uuid;
  IF imp.id IS NULL THEN RAISE EXCEPTION 'Importación no encontrada'; END IF;
  operacion:=imp.operacion_id;
 END IF;
 IF p_accion NOT IN('crear_operacion','guardar_personal','guardar_empaque') THEN
  SELECT * INTO op FROM public.masiva_operaciones WHERE id=operacion FOR UPDATE;
  IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
  IF imp.id IS NOT NULL THEN
   -- La carga pudo cancelarse o confirmarse mientras esperábamos el bloqueo.
   SELECT * INTO imp FROM public.masiva_importaciones WHERE id=imp.id FOR UPDATE;
  END IF;
  IF req IS NOT NULL THEN
   SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
   IF FOUND THEN
    IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
    RETURN solicitud.respuesta;
   END IF;
  END IF;
  IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;
 END IF;

 CASE p_accion
 WHEN 'crear_operacion' THEN
  INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;
  resultado:=jsonb_build_object('id',operacion);
 WHEN 'guardar_personal' THEN
  IF nullif(trim(p_datos->>'usuario_numero'),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE numero_usuario=trim(p_datos->>'usuario_numero') AND activo)
  THEN RAISE EXCEPTION 'Usuario asociado no encontrado o inactivo'; END IF;
  INSERT INTO public.masiva_personal(nombre,usuario_numero,creado_por) VALUES(trim(p_datos->>'nombre'),nullif(trim(p_datos->>'usuario_numero'),''),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'guardar_empaque' THEN
  INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por)
  VALUES(trim(p_datos->>'nombre'),(p_datos->>'peso_vacio')::numeric,(p_datos->>'peso_lleno')::numeric,(p_datos->>'largo')::numeric,
  (p_datos->>'ancho')::numeric,(p_datos->>'alto')::numeric,coalesce(p_datos->>'tipo','caja'),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'iniciar_importacion' THEN
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND tipo=p_datos->>'tipo' AND estado<>'cancelada') THEN RAISE EXCEPTION 'Ya existe una carga de este tipo; finaliza o cancela la carga pendiente'; END IF;
  INSERT INTO public.masiva_importaciones(operacion_id,tipo,archivo,total_filas,total_lotes,creado_por)
  VALUES(operacion,p_datos->>'tipo',p_datos->>'archivo',(p_datos->>'total_filas')::integer,(p_datos->>'total_lotes')::integer,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('importacion_id',id_nuevo);
 WHEN 'cargar_lote' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La importación ya no admite lotes'; END IF;
  n:=(p_datos->>'indice')::integer; v_filas:=p_datos->'filas';
  IF n IS NULL OR n<0 OR n>=imp.total_lotes OR jsonb_typeof(v_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(v_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Lote inválido'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id AND indice=n AND masiva_importacion_lotes.filas<>v_filas) THEN RAISE EXCEPTION 'El lote ya existe con contenido diferente'; END IF;
  INSERT INTO public.masiva_importacion_lotes(importacion_id,indice,filas) VALUES(imp.id,n,v_filas) ON CONFLICT DO NOTHING;
  resultado:=jsonb_build_object('importacion_id',imp.id,'indice',n,'filas',jsonb_array_length(v_filas));
 WHEN 'cancelar_importacion' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'Solo puede cancelarse una carga sin confirmar'; END IF;
  UPDATE public.masiva_importaciones SET estado='cancelada' WHERE id=imp.id;
  resultado:=jsonb_build_object('cancelada',true);
 WHEN 'confirmar_importacion' THEN
  IF imp.estado='confirmada' THEN RETURN jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas); END IF;
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La carga fue cancelada'; END IF;
  IF (SELECT count(*) FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id)<>imp.total_lotes
  OR (SELECT coalesce(sum(jsonb_array_length(l.filas)),0) FROM public.masiva_importacion_lotes l WHERE importacion_id=imp.id)<>imp.total_filas THEN RAISE EXCEPTION 'La carga está incompleta; vuelve a enviar los lotes pendientes'; END IF;
  SELECT jsonb_agg(x.value ORDER BY l.indice,x.ordinality) INTO v_filas FROM public.masiva_importacion_lotes l CROSS JOIN LATERAL jsonb_array_elements(l.filas) WITH ORDINALITY x(value,ordinality) WHERE l.importacion_id=imp.id;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE jsonb_typeof(f)<>'object' OR length(trim(coalesce(f->>'sku',''))) NOT BETWEEN 1 AND 100
  OR length(trim(coalesce(f->>'descripcion',''))) NOT BETWEEN 1 AND 500 OR coalesce(f->>'cantidad','') !~ '^[0-9]{1,7}$' OR (f->>'cantidad')::integer<1)
  THEN RAISE EXCEPTION 'Hay referencias, descripciones o cantidades inválidas en el archivo'; END IF;
  IF imp.tipo='recepcion' THEN
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'proveedor',''))) NOT BETWEEN 1 AND 160 OR length(trim(coalesce(f->>'pedido',''))) NOT BETWEEN 1 AND 100
    OR upper(trim(coalesce(f->>'unidad','UNIDAD'))) NOT IN('UNIDAD','UN','UND','PAR','PARES')) THEN RAISE EXCEPTION 'Proveedor, pedido o unidad inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1) THEN RAISE EXCEPTION 'Hay referencias repetidas dentro del mismo pedido y proveedor'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(coalesce(f->>'horario',''))>240)
   THEN RAISE EXCEPTION 'El horario de recepción admite máximo 240 caracteres'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido') FROM jsonb_array_elements(v_filas) f
    GROUP BY 1,2 HAVING count(DISTINCT nullif(trim(f->>'horario'),''))>1)
   THEN RAISE EXCEPTION 'Hay horarios distintos para una misma orden de compra'; END IF;
   INSERT INTO public.masiva_pedidos(operacion_id,proveedor,pedido,horario,orden_carga)
   SELECT operacion,proveedor,pedido,horario,row_number() OVER(ORDER BY primera_fila)::integer
   FROM (SELECT trim(f.value->>'proveedor') AS proveedor,trim(f.value->>'pedido') AS pedido,
    coalesce(max(nullif(trim(f.value->>'horario'),'')),'') AS horario,min(f.ordinality) AS primera_fila
    FROM jsonb_array_elements(v_filas) WITH ORDINALITY f(value,ordinality) GROUP BY 1,2) q;
   INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,unidad,esperado)
   SELECT operacion,trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku'),trim(f->>'descripcion'),CASE WHEN upper(trim(f->>'unidad')) IN('PAR','PARES') THEN 'PAR' ELSE 'UNIDAD' END,(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f;
  ELSE
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'lista',''))) NOT BETWEEN 1 AND 100
    OR length(trim(coalesce(f->>'cedula',''))) NOT BETWEEN 1 AND 100 OR length(trim(coalesce(f->>'nombre',''))) NOT BETWEEN 1 AND 200
    OR coalesce(f->>'numero_persona','') !~ '^[0-9]{1,7}$' OR (f->>'numero_persona')::integer<1) THEN RAISE EXCEPTION 'Lista, documento, nombre o consecutivo de persona inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT (f->>'numero_persona')::integer)>1 OR count(DISTINCT trim(f->>'nombre'))>1)
   OR EXISTS(SELECT trim(f->>'lista'),(f->>'numero_persona')::integer FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT trim(f->>'cedula'))>1)
   THEN RAISE EXCEPTION 'Una persona tiene datos distintos o un consecutivo está asignado a varias personas'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1)
   THEN RAISE EXCEPTION 'Referencia repetida en un kit; unifica su cantidad antes de confirmar'; END IF;
   INSERT INTO public.masiva_listas(operacion_id,lista,sede,ciudad,direccion,unidad,sector,responsable,responsables)
   SELECT operacion,trim(f->>'lista'),max(coalesce(f->>'sede','')),max(coalesce(f->>'ciudad','')),max(coalesce(f->>'direccion','')),
   max(coalesce(f->>'unidad','')),max(coalesce(f->>'sector','')),coalesce(min(nullif(trim(f->>'lider'),'')),''),
   coalesce(jsonb_agg(DISTINCT trim(f->>'lider')) FILTER(WHERE nullif(trim(f->>'lider'),'') IS NOT NULL),'[]') FROM jsonb_array_elements(v_filas) f GROUP BY trim(f->>'lista');
   INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
   SELECT operacion,trim(f->>'lista'),(f->>'numero_persona')::integer,trim(f->>'cedula'),trim(f->>'nombre') FROM jsonb_array_elements(v_filas) f GROUP BY 2,3,4,5;
   INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad)
   SELECT kit_fila.id,trim(f->>'sku'),trim(f->>'descripcion'),(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f
   JOIN public.masiva_kits kit_fila ON kit_fila.operacion_id=operacion AND kit_fila.lista=trim(f->>'lista') AND kit_fila.cedula=trim(f->>'cedula');
  END IF;
  UPDATE public.masiva_importaciones SET estado='confirmada',confirmado=ahora WHERE id=imp.id;
  resultado:=jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas);
 WHEN 'recibir' THEN
  SELECT * INTO inv FROM public.masiva_inventario WHERE id=(p_datos->>'inventario_id')::uuid AND operacion_id=operacion FOR UPDATE;
  v_cantidad:=(p_datos->>'cantidad')::integer;
  IF inv.id IS NULL OR v_cantidad IS NULL OR v_cantidad<1 THEN RAISE EXCEPTION 'Referencia o cantidad no válida'; END IF;
  IF inv.recibido+v_cantidad>inv.esperado THEN RAISE EXCEPTION 'La recepción supera el límite del pedido (% pendientes)',inv.esperado-inv.recibido; END IF;
  IF length(trim(coalesce(p_datos->>'soporte',''))) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'Registra la remisión o soporte de recepción'; END IF;
  IF p_datos ? 'novedad' THEN
   IF jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
   UPDATE public.masiva_pedidos SET novedad=trim(p_datos->>'novedad')
   WHERE operacion_id=operacion AND proveedor=inv.proveedor AND pedido=inv.pedido;
  END IF;
  UPDATE public.masiva_inventario SET recibido=recibido+v_cantidad WHERE id=inv.id;
  INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,'recepcion',v_cantidad,trim(p_datos->>'soporte'),actor);
  resultado:=jsonb_build_object('id',inv.id,'recibido',inv.recibido+v_cantidad,'disponible',inv.recibido+v_cantidad-inv.validado);
 WHEN 'asignar' THEN
  SELECT * INTO persona FROM public.masiva_personal WHERE id=(p_datos->>'empacador_id')::uuid AND activo;
  IF persona.id IS NULL THEN RAISE EXCEPTION 'Selecciona una persona activa'; END IF;
  SELECT min(numero_persona),max(numero_persona) INTO n_desde,n_hasta FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  n_desde:=coalesce(nullif(p_datos->>'desde','')::integer,n_desde); n_hasta:=coalesce(nullif(p_datos->>'hasta','')::integer,n_hasta);
  IF n_desde IS NULL OR n_hasta IS NULL OR n_desde<1 OR n_hasta<n_desde THEN RAISE EXCEPTION 'Lista o rango inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_desde)
  OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_hasta) THEN RAISE EXCEPTION 'El rango debe iniciar y terminar en personas de la lista'; END IF;
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=persona.id AND desde=n_desde AND hasta=n_hasta;
  IF asig.id IS NOT NULL THEN RETURN jsonb_build_object('id',asig.id,'desde',n_desde,'hasta',n_hasta); END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta AND empacador_id IS NOT NULL)
  THEN RAISE EXCEPTION 'El rango se cruza con kits ya asignados'; END IF;
  INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,creado_por) VALUES(operacion,p_datos->>'lista',persona.id,n_desde,n_hasta,actor) RETURNING id INTO id_nuevo;
  UPDATE public.masiva_kits SET empacador_id=persona.id,asignacion_id=id_nuevo WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta;
  GET DIAGNOSTICS n=ROW_COUNT;
  resultado:=jsonb_build_object('id',id_nuevo,'kits',n,'desde',n_desde,'hasta',n_hasta);
 WHEN 'tiempo' THEN
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion
  AND ((nullif(p_datos->>'asignacion_id','') IS NOT NULL AND id=(p_datos->>'asignacion_id')::uuid)
   OR (nullif(p_datos->>'asignacion_id','') IS NULL AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid
   AND (nullif(p_datos->>'desde','') IS NULL OR desde=(p_datos->>'desde')::integer) AND(nullif(p_datos->>'hasta','') IS NULL OR hasta=(p_datos->>'hasta')::integer))) ORDER BY creado LIMIT 1 FOR UPDATE;
  IF asig.id IS NULL THEN RAISE EXCEPTION 'Selecciona una asignación de empaque'; END IF;
  -- Evita que dos operaciones inicien simultáneamente el tiempo de la misma persona.
  PERFORM 1 FROM public.masiva_personal WHERE id=asig.empacador_id FOR UPDATE;
  IF nullif(p_datos->>'asignacion_id','') IS NULL AND nullif(p_datos->>'desde','') IS NULL AND (SELECT count(*) FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid)>1
  THEN RAISE EXCEPTION 'Selecciona el rango de empaque para registrar su tiempo'; END IF;
  IF p_datos->>'accion'='iniciar' THEN
   IF asig.estado NOT IN('pendiente','pausado') THEN RAISE EXCEPTION 'El empaque ya está iniciado o finalizado'; END IF;
   IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=asig.empacador_id AND estado='en_curso' AND id<>asig.id) THEN RAISE EXCEPTION 'Esta persona ya tiene otro empaque en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='en_curso',inicio=coalesce(inicio,ahora),ultimo_inicio=ahora WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armando' WHERE asignacion_id=asig.id;
  ELSIF p_datos->>'accion'='pausar' THEN
   IF asig.estado<>'en_curso' THEN RAISE EXCEPTION 'El empaque no está en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='pausado',segundos=segundos+extract(epoch FROM ahora-ultimo_inicio),ultimo_inicio=NULL WHERE id=asig.id;
  ELSIF p_datos->>'accion'='finalizar' THEN
   IF asig.estado NOT IN('en_curso','pausado') THEN RAISE EXCEPTION 'Inicia el empaque antes de finalizarlo'; END IF;
   UPDATE public.masiva_asignaciones SET estado='finalizado',fin=ahora,segundos=segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM ahora-ultimo_inicio) ELSE 0 END,ultimo_inicio=NULL WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armado',armado=ahora WHERE asignacion_id=asig.id;
  ELSE RAISE EXCEPTION 'Acción de tiempo inválida'; END IF;
  SELECT to_jsonb(s) INTO resultado FROM public.masiva_asignaciones s WHERE id=asig.id;
 WHEN 'validar','corregir','reabrir','embalar','reportar_error','reiniciar_validacion' THEN
  SELECT * INTO k FROM public.masiva_kits WHERE id=(p_datos->>'kit_id')::uuid AND operacion_id=operacion FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'Kit no encontrado en esta operación'; END IF;
  evento_kit:=k.id;
  IF k.armado IS NULL THEN RAISE EXCEPTION 'Finaliza el armado del kit antes de validarlo'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo armó'; END IF;
  IF p_accion IN('reabrir','corregir','reportar_error','reiniciar_validacion') AND length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de la revisión'; END IF;
  IF p_accion='reabrir' THEN
   IF k.validacion_inicio IS NULL THEN RAISE EXCEPTION 'El kit todavía no tiene validaciones'; END IF;
   UPDATE public.masiva_kits SET revision_abierta=true WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'revision_abierta',true);
  ELSIF p_accion='reportar_error' THEN
   resultado:=jsonb_build_object('id',k.id,'empacador_id',k.empacador_id,'penalizacion',op.penalizacion_error);
  ELSIF p_accion='reiniciar_validacion' THEN
   -- Exigir el conteo visto por el operador impide borrar lecturas de otra estación.
   IF jsonb_typeof(p_datos->'cantidades') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Actualiza el kit antes de reiniciar su validación'; END IF;
   SELECT jsonb_agg(jsonb_build_object('articulo_id',(f->>'articulo_id')::uuid,'validado',(f->>'validado')::integer)
    ORDER BY (f->>'articulo_id')::uuid) INTO v_filas FROM jsonb_array_elements(p_datos->'cantidades') f;
   IF v_filas IS DISTINCT FROM (SELECT jsonb_agg(jsonb_build_object('articulo_id',a.id,'validado',a.validado) ORDER BY a.id)
    FROM public.masiva_articulos a WHERE a.kit_id=k.id) THEN
    RAISE EXCEPTION 'El kit cambió en otra estación. Actualiza y revisa las cantidades antes de reiniciar'; END IF;
   SELECT coalesce(sum(a.validado),0),jsonb_agg(to_jsonb(a) ORDER BY a.sku) INTO v_cantidad,anterior
    FROM public.masiva_articulos a WHERE a.kit_id=k.id;
   IF v_cantidad=0 THEN RAISE EXCEPTION 'El kit no tiene prendas validadas para reiniciar'; END IF;
   FOR art IN SELECT * FROM public.masiva_articulos WHERE kit_id=k.id ORDER BY id FOR UPDATE LOOP
    IF (SELECT coalesce(sum(c.cantidad),0) FROM public.masiva_consumos c WHERE c.articulo_id=art.id)<>art.validado
     OR (SELECT coalesce(sum(c.cantidad),0) FROM public.masiva_validacion_creditos c WHERE c.articulo_id=art.id)<>art.validado THEN
     RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     UPDATE public.masiva_inventario SET validado=validado-consumo.cantidad
      WHERE id=consumo.inventario_id AND validado>=consumo.cantidad;
     IF NOT FOUND THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id)
      VALUES(operacion,consumo.inventario_id,art.id,'correccion',consumo.cantidad,trim(p_datos->>'motivo'),actor);
    END LOOP;
    UPDATE public.masiva_consumos SET cantidad=0 WHERE articulo_id=art.id AND cantidad>0;
    UPDATE public.masiva_validacion_creditos SET cantidad=0,actualizado=ahora WHERE articulo_id=art.id AND cantidad>0;
    UPDATE public.masiva_articulos SET validado=0 WHERE id=art.id;
   END LOOP;
   -- Se conservan autoría, armado, caja, inicio histórico y documentos emitidos.
   UPDATE public.masiva_kits SET estado='armado',revision_abierta=true,validacion_fin=NULL WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'estado','armado','revision_abierta',true,
    'unidades_reintegradas',v_cantidad,'anterior',anterior);
  ELSIF p_accion='embalar' THEN
   IF NOT EXISTS(SELECT 1 FROM public.masiva_articulos WHERE kit_id=k.id AND validado>0) THEN RAISE EXCEPTION 'Valida al menos una prenda antes de asignar el empaque'; END IF;
   n:=(p_datos->>'caja')::integer; IF n IS NULL OR n<1 THEN RAISE EXCEPTION 'Número de caja inválido'; END IF;
   SELECT * INTO empaque FROM public.masiva_empaques WHERE id=(p_datos->>'empaque_id')::uuid AND activo;
   IF empaque.id IS NULL THEN RAISE EXCEPTION 'Selecciona el tipo de empaque'; END IF;
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL AND caja.empaque_id<>empaque.id THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   IF caja.id IS NULL THEN
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por) VALUES(operacion,k.lista,n,empaque.id,to_jsonb(empaque),actor) RETURNING * INTO caja;
   END IF;
   UPDATE public.masiva_kits SET caja_id=caja.id WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'caja',n,'estado',k.estado,
    'requerido',(SELECT sum(a.cantidad) FROM public.masiva_articulos a WHERE a.kit_id=k.id),
    'validado',(SELECT sum(a.validado) FROM public.masiva_articulos a WHERE a.kit_id=k.id));
  ELSE
   IF p_accion='validar' THEN
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND sku=trim(p_datos->>'sku') FOR UPDATE;
    IF art.id IS NULL THEN
     RAISE EXCEPTION 'El código % no pertenece a este kit. Revisa el empaque y retira la prenda incorrecta.',trim(coalesce(p_datos->>'sku',''))
      USING DETAIL=jsonb_build_object('tipo','sku_incorrecto','sku',trim(coalesce(p_datos->>'sku','')),
       'descripcion',coalesce((SELECT i.descripcion FROM public.masiva_inventario i WHERE i.operacion_id=operacion AND i.sku=trim(p_datos->>'sku') ORDER BY i.id LIMIT 1),''),
       'cantidad',0,'validado',0)::text;
    END IF;
    IF art.validado>=art.cantidad THEN
     RAISE EXCEPTION 'El código % ya tiene % de % unidades requeridas. Retira la prenda adicional y revisa el empaque.',art.sku,art.validado,art.cantidad
      USING DETAIL=jsonb_build_object('tipo','unidad_excedente','sku',art.sku,'descripcion',art.descripcion,'cantidad',art.cantidad,'validado',art.validado)::text;
    END IF;
    IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
    v_cantidad:=art.validado+1;
   ELSE
    IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND id=(p_datos->>'articulo_id')::uuid FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'Prenda no encontrada en el kit'; END IF;
    v_cantidad:=(p_datos->>'cantidad')::integer;
   END IF;
   IF v_cantidad IS NULL OR v_cantidad<0 OR v_cantidad>art.cantidad THEN RAISE EXCEPTION 'La cantidad excede lo solicitado para esta persona'; END IF;
   cambio:=v_cantidad-art.validado; restante:=abs(cambio); anterior:=to_jsonb(art);
   IF cambio>0 THEN
    FOR inv IN SELECT * FROM public.masiva_inventario WHERE operacion_id=operacion AND sku=art.sku AND recibido>validado ORDER BY proveedor,pedido,id FOR UPDATE LOOP
     tomar:=least(restante,inv.recibido-inv.validado);
     UPDATE public.masiva_inventario SET validado=validado+tomar WHERE id=inv.id;
     INSERT INTO public.masiva_consumos(articulo_id,inventario_id,cantidad) VALUES(art.id,inv.id,tomar)
     ON CONFLICT(articulo_id,inventario_id) DO UPDATE SET cantidad=masiva_consumos.cantidad+excluded.cantidad;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,art.id,CASE WHEN p_accion='validar' THEN 'validacion' ELSE 'correccion' END,-tomar,coalesce(p_datos->>'motivo',''),actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'No hay inventario recibido suficiente para este SKU'; END IF;
   ELSIF cambio<0 THEN
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     tomar:=least(restante,consumo.cantidad);
     UPDATE public.masiva_inventario SET validado=validado-tomar WHERE id=consumo.inventario_id;
     UPDATE public.masiva_consumos SET cantidad=masiva_consumos.cantidad-tomar WHERE articulo_id=art.id AND inventario_id=consumo.inventario_id;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,consumo.inventario_id,art.id,'correccion',tomar,p_datos->>'motivo',actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
   END IF;
   IF cambio>0 THEN
    INSERT INTO public.masiva_validacion_creditos(articulo_id,actor_id,cantidad,actualizado) VALUES(art.id,actor,cambio,ahora)
    ON CONFLICT(articulo_id,actor_id) DO UPDATE SET cantidad=masiva_validacion_creditos.cantidad+excluded.cantidad,actualizado=excluded.actualizado;
   ELSIF cambio<0 THEN
    restante:=-cambio;
    FOR credito IN SELECT * FROM public.masiva_validacion_creditos WHERE articulo_id=art.id AND cantidad>0 ORDER BY actualizado DESC,actor_id FOR UPDATE LOOP
     tomar:=least(restante,credito.cantidad);
     UPDATE public.masiva_validacion_creditos SET cantidad=masiva_validacion_creditos.cantidad-tomar,actualizado=ahora WHERE articulo_id=art.id AND actor_id=credito.actor_id;
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
   END IF;
   UPDATE public.masiva_articulos SET validado=v_cantidad WHERE id=art.id;
   SELECT count(*) INTO n FROM public.masiva_articulos WHERE kit_id=k.id AND validado<masiva_articulos.cantidad;
   UPDATE public.masiva_kits SET estado=CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,
   validacion_inicio=coalesce(validacion_inicio,ahora),validacion_fin=CASE WHEN n=0 THEN ahora ELSE NULL END,
   validador_id=actor,revision_abierta=n<>0 WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'articulo_id',art.id,'sku',art.sku,'validado',v_cantidad,'cantidad',art.cantidad,'estado',CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,'anterior',anterior,'diferencia',cambio);
  END IF;
 WHEN 'configurar_recepcion' THEN
  IF length(trim(coalesce(p_datos->>'proveedor',''))) NOT BETWEEN 1 AND 160
   OR length(trim(coalesce(p_datos->>'pedido',''))) NOT BETWEEN 1 AND 100
   OR NOT (p_datos ? 'horario' OR p_datos ? 'novedad') THEN RAISE EXCEPTION 'Selecciona una orden de compra y los datos a editar'; END IF;
  IF p_datos ? 'horario' AND (jsonb_typeof(p_datos->'horario') IS DISTINCT FROM 'string' OR length(p_datos->>'horario')>240)
   THEN RAISE EXCEPTION 'El horario admite máximo 240 caracteres'; END IF;
  IF p_datos ? 'novedad' AND (jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000)
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
  SELECT to_jsonb(p) INTO anterior FROM public.masiva_pedidos p
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido') FOR UPDATE;
  IF anterior IS NULL THEN RAISE EXCEPTION 'Orden de compra no encontrada'; END IF;
  UPDATE public.masiva_pedidos p SET
   horario=CASE WHEN p_datos ? 'horario' THEN trim(p_datos->>'horario') ELSE p.horario END,
   novedad=CASE WHEN p_datos ? 'novedad' THEN trim(p_datos->>'novedad') ELSE p.novedad END
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido');
  resultado:=jsonb_build_object('guardado',true,'anterior',anterior);
 WHEN 'configurar' THEN
  IF p_datos ? 'lista' THEN
   IF length(trim(coalesce(p_datos->>'responsable',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Registra el responsable principal'; END IF;
   UPDATE public.masiva_listas SET responsable=trim(p_datos->>'responsable') WHERE operacion_id=operacion AND lista=p_datos->>'lista';
   IF NOT FOUND THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  END IF;
  FOREACH v_actor_nombre IN ARRAY ARRAY['logo_cliente','logo_empresa'] LOOP
   IF p_datos ? v_actor_nombre AND (length(p_datos->>v_actor_nombre)>2000000 OR (p_datos->>v_actor_nombre<>'' AND p_datos->>v_actor_nombre !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/=\r\n]+$')) THEN RAISE EXCEPTION 'Usa un logo PNG o JPEG de máximo 1,5 MB'; END IF;
  END LOOP;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;
  UPDATE public.masiva_operaciones SET logo_cliente=coalesce(p_datos->>'logo_cliente',logo_cliente),logo_empresa=coalesce(p_datos->>'logo_empresa',logo_empresa),
  puntos_kit=coalesce((p_datos->>'puntos_kit')::integer,puntos_kit),puntos_prenda=coalesce((p_datos->>'puntos_prenda')::integer,puntos_prenda),
  penalizacion_error=coalesce((p_datos->>'penalizacion_error')::integer,penalizacion_error) WHERE id=operacion;
  resultado:=jsonb_build_object('guardado',true);
 WHEN 'documento' THEN
  IF coalesce(p_datos->>'tipo','') NOT IN('lista','rotulo') THEN RAISE EXCEPTION 'Tipo de documento inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=operacion AND lista=p_datos->>'lista') THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista'
   AND kit_fila.caja_id IS NULL AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Asigna un empaque a todos los kits con prendas validadas antes de emitir documentos'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista' AND kit_fila.caja_id IS NOT NULL
   AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Valida prendas y asígnalas a una caja antes de emitir documentos'; END IF;
  SELECT coalesce(max(version),0)+1 INTO version_documento FROM public.masiva_documentos WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND tipo=p_datos->>'tipo';
  SELECT jsonb_build_object('formato_version',1,'operacion',to_jsonb(op),'lista',to_jsonb(l),'responsable',l.responsable,'fecha',ahora,'version',version_documento,
  'kits',coalesce((SELECT jsonb_agg(to_jsonb(kit_fila)||jsonb_build_object('caja',c.numero,'empacador',p.nombre,'articulos',
   (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.sku) FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id)) ORDER BY kit_fila.numero_persona)
   FROM public.masiva_kits kit_fila LEFT JOIN public.masiva_cajas c ON c.id=kit_fila.caja_id LEFT JOIN public.masiva_personal p ON p.id=kit_fila.empacador_id
   WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=l.lista AND kit_fila.caja_id IS NOT NULL
    AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0)),'[]'),
  'empaques',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.numero) FROM public.masiva_cajas c WHERE c.operacion_id=operacion AND c.lista=l.lista),'[]'))
  INTO snapshot FROM public.masiva_listas l WHERE l.operacion_id=operacion AND l.lista=p_datos->>'lista';
  INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);
 WHEN 'cerrar_operacion' THEN
  IF length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de cierre'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE operacion_id=operacion AND estado IN('en_curso','pausado')) THEN RAISE EXCEPTION 'Finaliza los tiempos de empaque antes de cerrar'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND estado='cargando') THEN RAISE EXCEPTION 'Confirma o cancela las cargas pendientes antes de cerrar'; END IF;
  UPDATE public.masiva_operaciones SET estado='cerrada',cerrado=ahora,cerrado_por=actor,motivo_cierre=trim(p_datos->>'motivo') WHERE id=operacion;
  resultado:=jsonb_build_object('id',operacion,'estado','cerrada','sobrante',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=operacion));
 ELSE RAISE EXCEPTION 'Acción de Masiva no reconocida'; END CASE;
 IF p_accion<>'cargar_lote' THEN
  INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos)
  VALUES(operacion,evento_kit,p_accion,actor,v_actor_nombre,
   jsonb_build_object('entrada',p_datos-'filas'-'logo_cliente'-'logo_empresa','resultado',resultado-'snapshot',
    'empacador_id',CASE WHEN p_accion='reportar_error' THEN k.empacador_id ELSE NULL END));
 END IF;
 IF req IS NOT NULL THEN INSERT INTO public.masiva_solicitudes(request_id,actor_id,accion,huella,respuesta) VALUES(req,actor,p_accion,huella,resultado); END IF;
 RETURN resultado;
END $$;

REVOKE ALL ON FUNCTION public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 132_masiva_listado_maestro.sql
-- Después de 131. Conserva la fuente por artículo y añade consultas del maestro.
-- La carga inicial solo escribe la nueva tabla; no cambia registros operativos existentes.
-- Despacho y entrega continúan aplazados; sus columnas no inventan información.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF to_regclass('public.masiva_movimientos_articulo_fecha') IS NULL
 THEN RAISE EXCEPTION 'Aplica primero la migración 131'; END IF;
END $$;

CREATE TABLE public.masiva_base_fuente (
 articulo_id uuid PRIMARY KEY REFERENCES public.masiva_articulos(id),
 operacion_id uuid NOT NULL REFERENCES public.masiva_operaciones(id),
 importacion_id uuid NOT NULL REFERENCES public.masiva_importaciones(id),
 datos jsonb NOT NULL CHECK(jsonb_typeof(datos)='object'),
 hoja_origen text CHECK(length(hoja_origen) BETWEEN 1 AND 160),
 fila_origen integer CHECK(fila_origen>0)
);
CREATE INDEX masiva_base_fuente_operacion ON public.masiva_base_fuente(operacion_id,articulo_id);
ALTER TABLE public.masiva_base_fuente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.masiva_base_fuente FROM PUBLIC,anon,authenticated;

-- Las 13 columnas confirmadas son la identidad verificable de cada renglón.
CREATE FUNCTION public.masiva_base_original(p_fila jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('lista',trim(p_fila->>'lista'),'numero_persona',(p_fila->>'numero_persona')::integer,
  'cedula',trim(p_fila->>'cedula'),'nombre',trim(p_fila->>'nombre'),'sku',trim(p_fila->>'sku'),
  'descripcion',trim(p_fila->>'descripcion'),'cantidad',(p_fila->>'cantidad')::integer,
  'sede',coalesce(p_fila->>'sede',''),'ciudad',coalesce(p_fila->>'ciudad',''),
  'direccion',coalesce(p_fila->>'direccion',''),'unidad',coalesce(p_fila->>'unidad',''),
  'sector',coalesce(p_fila->>'sector',''),'lider',coalesce(p_fila->>'lider',''))
$$;
CREATE FUNCTION public.masiva_base_datos(p_fila jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE original jsonb:=public.masiva_base_original(p_fila); fuente jsonb:=coalesce(p_fila->'fuente','{}');
BEGIN
 IF jsonb_typeof(p_fila) IS DISTINCT FROM 'object' OR jsonb_typeof(fuente) IS DISTINCT FROM 'object'
 OR octet_length(fuente::text)>64000 OR (SELECT count(*) FROM jsonb_object_keys(fuente))>100
 THEN RAISE EXCEPTION 'Datos de origen inválidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(fuente) f WHERE length(f.key) NOT BETWEEN 1 AND 120
  OR jsonb_typeof(f.value) NOT IN('string','number','boolean','null') OR length(f.value::text)>8000
  OR (original ? f.key AND f.value IS DISTINCT FROM original->f.key))
 THEN RAISE EXCEPTION 'La fuente no coincide con sus columnas operativas'; END IF;
 IF (p_fila ? 'fila_origen' AND(coalesce(p_fila->>'fila_origen','') !~ '^[0-9]{1,8}$' OR (p_fila->>'fila_origen')::integer<1))
 OR(p_fila ? 'hoja_origen' AND(jsonb_typeof(p_fila->'hoja_origen') IS DISTINCT FROM 'string' OR length(p_fila->>'hoja_origen') NOT BETWEEN 1 AND 160))
 THEN RAISE EXCEPTION 'Hoja o fila de origen inválida'; END IF;
 RETURN fuente||original;
END $$;

CREATE FUNCTION public.masiva_base_conservar(p_importacion uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE imp public.masiva_importaciones; cantidad integer;
BEGIN
 SELECT * INTO imp FROM public.masiva_importaciones WHERE id=p_importacion;
 IF imp.tipo IS DISTINCT FROM 'personal' OR imp.estado IS DISTINCT FROM 'confirmada' THEN RETURN 0; END IF;
 INSERT INTO public.masiva_base_fuente(articulo_id,operacion_id,importacion_id,datos,hoja_origen,fila_origen)
 SELECT a.id,imp.operacion_id,imp.id,public.masiva_base_datos(f.value),f.value->>'hoja_origen',(f.value->>'fila_origen')::integer
 FROM public.masiva_importacion_lotes lot CROSS JOIN LATERAL jsonb_array_elements(lot.filas) f(value)
 JOIN public.masiva_kits k ON k.operacion_id=imp.operacion_id AND k.lista=trim(f.value->>'lista') AND k.cedula=trim(f.value->>'cedula')
 JOIN public.masiva_articulos a ON a.kit_id=k.id AND a.sku=trim(f.value->>'sku')
 WHERE lot.importacion_id=imp.id ON CONFLICT(articulo_id) DO NOTHING;
 GET DIAGNOSTICS cantidad=ROW_COUNT;
 IF(SELECT count(*) FROM public.masiva_base_fuente WHERE importacion_id=imp.id)<>imp.total_filas
 THEN RAISE EXCEPTION 'La fuente no coincide con el total de artículos importados'; END IF;
 RETURN cantidad;
END $$;
CREATE FUNCTION public.masiva_base_confirmada() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NEW.tipo='personal' AND NEW.estado='confirmada' AND OLD.estado IS DISTINCT FROM NEW.estado
 THEN PERFORM public.masiva_base_conservar(NEW.id); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER masiva_conservar_base AFTER UPDATE OF estado ON public.masiva_importaciones
 FOR EACH ROW EXECUTE FUNCTION public.masiva_base_confirmada();
DO $$ DECLARE imp uuid; BEGIN
 FOR imp IN SELECT id FROM public.masiva_importaciones WHERE tipo='personal' AND estado='confirmada'
 LOOP PERFORM public.masiva_base_conservar(imp); END LOOP;
END $$;

CREATE FUNCTION public.masiva_enriquecer_base(p_operacion uuid,p_archivo text,p_filas jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE actor public.usuarios; op public.masiva_operaciones; imp public.masiva_importaciones;
 f jsonb; origen public.masiva_base_fuente; datos_nuevos jsonb; actualizadas integer:=0; cambios integer;
BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo
  AND 'admin'=ANY(coalesce(roles,ARRAY[rol]));
 IF actor.auth_id IS NULL THEN RAISE EXCEPTION 'Solo el administrador puede verificar la fuente' USING ERRCODE='42501'; END IF;
 IF p_archivo IS NULL OR length(p_archivo) NOT BETWEEN 1 AND 240 OR jsonb_typeof(p_filas) IS DISTINCT FROM 'array'
 OR jsonb_array_length(p_filas) NOT BETWEEN 1 AND 1000 OR octet_length(p_filas::text)>20000000
 THEN RAISE EXCEPTION 'Lote de enriquecimiento inválido'; END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion FOR UPDATE;
 IF op.id IS NULL OR op.estado<>'activa' THEN RAISE EXCEPTION 'La operación debe estar activa'; END IF;
 SELECT * INTO imp FROM public.masiva_importaciones WHERE operacion_id=op.id AND tipo='personal' AND estado='confirmada';
 IF imp.id IS NULL OR imp.archivo IS DISTINCT FROM p_archivo THEN RAISE EXCEPTION 'El archivo no coincide con la base confirmada'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) x GROUP BY x->>'lista',x->>'cedula',x->>'sku' HAVING count(*)>1)
 THEN RAISE EXCEPTION 'Hay artículos repetidos en el lote'; END IF;
 FOR f IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
  IF NOT(f ? 'fuente') THEN RAISE EXCEPTION 'Faltan las columnas de origen'; END IF;
  datos_nuevos:=public.masiva_base_datos(f);
  SELECT b.* INTO origen FROM public.masiva_base_fuente b JOIN public.masiva_articulos a ON a.id=b.articulo_id
   JOIN public.masiva_kits k ON k.id=a.kit_id WHERE b.operacion_id=op.id AND b.importacion_id=imp.id
   AND k.lista=f->>'lista' AND k.cedula=f->>'cedula' AND a.sku=f->>'sku' FOR UPDATE OF b;
  IF origen.articulo_id IS NULL OR public.masiva_base_original(origen.datos) IS DISTINCT FROM public.masiva_base_original(f)
  THEN RAISE EXCEPTION 'La fila de origen no coincide con las 13 columnas importadas'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_each(datos_nuevos) x WHERE origen.datos ? x.key AND origen.datos->x.key IS DISTINCT FROM x.value)
   OR(origen.hoja_origen IS NOT NULL AND f ? 'hoja_origen' AND origen.hoja_origen IS DISTINCT FROM f->>'hoja_origen')
   OR(origen.fila_origen IS NOT NULL AND f ? 'fila_origen' AND origen.fila_origen IS DISTINCT FROM (f->>'fila_origen')::integer)
  THEN RAISE EXCEPTION 'Los datos de origen ya conservados no pueden reemplazarse'; END IF;
  UPDATE public.masiva_base_fuente SET datos=origen.datos||datos_nuevos,
   hoja_origen=coalesce(origen.hoja_origen,f->>'hoja_origen'),fila_origen=coalesce(origen.fila_origen,(f->>'fila_origen')::integer)
  WHERE articulo_id=origen.articulo_id AND(datos IS DISTINCT FROM origen.datos||datos_nuevos
   OR hoja_origen IS DISTINCT FROM coalesce(origen.hoja_origen,f->>'hoja_origen')
   OR fila_origen IS DISTINCT FROM coalesce(origen.fila_origen,(f->>'fila_origen')::integer));
  GET DIAGNOSTICS cambios=ROW_COUNT; actualizadas:=actualizadas+cambios;
 END LOOP;
 IF actualizadas>0 THEN
  INSERT INTO public.masiva_auditoria(operacion_id,accion,actor_id,actor_nombre,datos)
  VALUES(op.id,'enriquecer_base',actor.auth_id,actor.nombre,jsonb_build_object('archivo',p_archivo,
   'filas_verificadas',jsonb_array_length(p_filas),'filas_actualizadas',actualizadas));
 END IF;
 RETURN jsonb_build_object('verificadas',jsonb_array_length(p_filas),'actualizadas',actualizadas);
END $$;
REVOKE ALL ON FUNCTION public.masiva_base_original(jsonb),public.masiva_base_datos(jsonb),
 public.masiva_base_conservar(uuid),public.masiva_base_confirmada(),public.masiva_enriquecer_base(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.masiva_enriquecer_base(uuid,text,jsonb) TO authenticated;

CREATE INDEX IF NOT EXISTS masiva_auditoria_kit_revision_fecha
 ON public.masiva_auditoria(kit_id,creado DESC,id DESC)
 WHERE kit_id IS NOT NULL AND accion IN('corregir','reabrir','reiniciar_validacion');

CREATE OR REPLACE FUNCTION public.masiva_maestro_consultar(
 p_operacion uuid,p_vista text DEFAULT 'listado',p_buscar text DEFAULT '',p_filtros jsonb DEFAULT '{}',
 p_pagina integer DEFAULT 1,p_tamano integer DEFAULT 30,p_fecha_tipo text DEFAULT '',p_desde date DEFAULT NULL,p_hasta date DEFAULT NULL,
 p_incluir_opciones boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE op public.masiva_operaciones; campos text[]; fecha_carga timestamptz; campo_fecha text; respuesta jsonb;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF p_vista IS NULL OR p_vista NOT IN('listado','base') OR p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 100000
 OR p_tamano IS NULL OR p_tamano NOT IN(30,50,100,1000) OR p_incluir_opciones IS NULL OR length(coalesce(p_buscar,''))>200
 OR jsonb_typeof(p_filtros) IS DISTINCT FROM 'object' OR octet_length(p_filtros::text)>2000000
 OR (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta)
 THEN RAISE EXCEPTION 'Consulta del listado maestro inválida'; END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion;
 IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 p_buscar:=trim(coalesce(p_buscar,''));
 campo_fecha:=coalesce(nullif(p_fecha_tipo,''),CASE WHEN p_vista='base' THEN 'fecha_validacion' ELSE 'ultima_validacion' END);
 IF (p_vista='listado' AND campo_fecha NOT IN('ultima_validacion','fecha_carga','fecha_despacho','fecha_recepcion'))
 OR (p_vista='base' AND campo_fecha NOT IN('fecha_validacion','fecha_carga'))
 THEN RAISE EXCEPTION 'Criterio de fecha inválido'; END IF;
 campos:=CASE WHEN p_vista='listado' THEN ARRAY[
  'estado','lista','cliente','ciudad','sede','direccion','responsable','total_piezas','cajas','bolsas','peso_total','volumen',
  'kits_totales','kits_validados','kits_empacados','ultima_validacion','fecha_despacho','fecha_recepcion','transportadora','placa_guia','novedades']
 ELSE ARRAY['fecha_carga','cliente','lista','numero_persona','ciudad','sede','sector','unidad','direccion','responsable',
  'cedula','nombre','sku','descripcion','empaque','numero_contenedor','cantidad','validado','estado','validador','empacador',
  'fecha_validacion','transportadora','placa_guia','motivo_modificacion',
  'logistica','entrega','unidad_directiva','gerencia','cargo','prenda','regional','departamento','items_kit','items_lista','items_direccion'] END;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f WHERE NOT f.key=ANY(campos) OR jsonb_typeof(f.value) IS DISTINCT FROM 'array')
 THEN RAISE EXCEPTION 'Columna o filtro del listado maestro inválido'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f WHERE jsonb_array_length(f.value)>100000)
 OR EXISTS(SELECT 1 FROM jsonb_each(p_filtros) f CROSS JOIN LATERAL jsonb_array_elements(f.value) v
  WHERE jsonb_typeof(v.value) IS DISTINCT FROM 'string' OR length(v.value#>>'{}')>1000)
 THEN RAISE EXCEPTION 'Valores de filtro inválidos'; END IF;
 SELECT coalesce(i.confirmado,i.creado) INTO fecha_carga FROM public.masiva_importaciones i
  WHERE i.operacion_id=p_operacion AND i.tipo='personal' AND i.estado='confirmada';

 WITH kits AS MATERIALIZED(
  SELECT k.* FROM public.masiva_kits k WHERE k.operacion_id=p_operacion
 ), articulos AS MATERIALIZED(
  SELECT a.*,m.creado AS fecha_validacion,u.nombre AS validador,
   coalesce(revision.motivo,'') AS motivo_modificacion
  FROM public.masiva_articulos a JOIN kits k ON k.id=a.kit_id
  LEFT JOIN LATERAL(SELECT x.creado,x.actor_id FROM public.masiva_movimientos x
   WHERE a.validado>0 AND x.articulo_id=a.id ORDER BY x.creado DESC LIMIT 1) m ON true
  LEFT JOIN public.usuarios u ON u.auth_id=m.actor_id
  LEFT JOIN LATERAL(SELECT x.datos->'entrada'->>'motivo' AS motivo FROM public.masiva_auditoria x
   WHERE p_vista='base' AND x.kit_id=a.kit_id AND x.accion IN('corregir','reabrir','reiniciar_validacion')
    AND (x.accion<>'corregir' OR x.datos->'entrada'->>'articulo_id'=a.id::text)
   ORDER BY x.creado DESC,x.id DESC LIMIT 1) revision ON true
 ), por_kit AS MATERIALIZED(
  SELECT a.kit_id,sum(a.cantidad) AS requerido,sum(a.validado) AS validado,bool_and(a.cantidad=a.validado) AS completo,
   max(a.fecha_validacion) AS ultima_validacion,
   bool_or(p_buscar<>'' AND position(lower(p_buscar) IN lower(a.sku||' '||a.descripcion))>0) AS coincidencia_prenda
  FROM articulos a GROUP BY a.kit_id
 ), por_lista AS MATERIALIZED(
  SELECT k.lista,count(*) AS kits_totales,count(*) FILTER(WHERE a.completo) AS kits_validados,
   count(*) FILTER(WHERE k.caja_id IS NOT NULL AND a.validado>0) AS kits_empacados,
   sum(a.requerido) AS prendas_requeridas,sum(a.validado) AS prendas_validadas,max(a.ultima_validacion) AS ultima_validacion,
   bool_or(a.coincidencia_prenda OR (p_buscar<>'' AND position(lower(p_buscar) IN lower(k.nombre||' '||k.cedula||' '||k.numero_persona))>0)) AS coincidencia_kit
  FROM kits k JOIN por_kit a ON a.kit_id=k.id GROUP BY k.lista
 ), ocupados AS MATERIALIZED(
  -- Cada caja o bolsa ocupada cuenta una vez, aunque contenga muchas personas/prendas.
  SELECT DISTINCT c.id,c.lista,c.empaque_snapshot FROM kits k JOIN por_kit a ON a.kit_id=k.id
  JOIN public.masiva_cajas c ON c.id=k.caja_id WHERE a.validado>0
 ), paquetes AS MATERIALIZED(
  SELECT c.lista,count(*) AS total_piezas,count(*) FILTER(WHERE c.empaque_snapshot->>'tipo'='caja') AS cajas,
   count(*) FILTER(WHERE c.empaque_snapshot->>'tipo'='bolsa') AS bolsas,
   round(sum((c.empaque_snapshot->>'peso_lleno')::numeric),3) AS peso_total,
   round(sum((c.empaque_snapshot->>'largo')::numeric*(c.empaque_snapshot->>'ancho')::numeric*(c.empaque_snapshot->>'alto')::numeric/1000000),6) AS volumen
  FROM ocupados c GROUP BY c.lista
 ), datos AS MATERIALIZED(
  SELECT jsonb_build_object(
   'estado',CASE WHEN lr.kits_validados=lr.kits_totales AND lr.kits_empacados=lr.kits_totales AND lr.kits_totales>0 THEN 'COMPLETO' WHEN lr.prendas_validadas>0 THEN 'EMPAQUE PARCIAL' ELSE 'POR EMPACAR' END,
   'lista',l.lista,'cliente',op.cliente,'ciudad',l.ciudad,'sede',l.sede,'direccion',l.direccion,'responsable',l.responsable,
   'total_piezas',coalesce(p.total_piezas,0),'cajas',coalesce(p.cajas,0),'bolsas',coalesce(p.bolsas,0),
   'peso_total',coalesce(p.peso_total,0),'volumen',coalesce(p.volumen,0),'kits_totales',coalesce(lr.kits_totales,0),
   'kits_validados',coalesce(lr.kits_validados,0),'kits_empacados',coalesce(lr.kits_empacados,0),'ultima_validacion',lr.ultima_validacion,
   'fecha_carga',fecha_carga,'fecha_despacho',NULL,'fecha_recepcion',NULL,'transportadora',NULL,'placa_guia',NULL,'novedades',NULL,
   'prendas_requeridas',coalesce(lr.prendas_requeridas,0),'prendas_validadas',coalesce(lr.prendas_validadas,0)) AS fila,
   l.lista AS orden_lista,0 AS orden_persona,''::text AS orden_sku
  FROM public.masiva_listas l LEFT JOIN por_lista lr ON lr.lista=l.lista LEFT JOIN paquetes p ON p.lista=l.lista
  WHERE p_vista='listado' AND l.operacion_id=p_operacion AND(p_buscar='' OR lr.coincidencia_kit
   OR position(lower(p_buscar) IN lower(concat_ws(' ',l.lista,op.cliente,l.ciudad,l.sede,l.direccion,l.responsable)))>0)
  UNION ALL
  SELECT jsonb_build_object('kit_id',k.id,'articulo_id',a.id,'fecha_carga',fecha_carga,'cliente',op.cliente,'lista',k.lista,
   'numero_persona',k.numero_persona,'ciudad',coalesce(b.datos->>'ciudad',l.ciudad),'sede',coalesce(b.datos->>'sede',l.sede),
   'sector',coalesce(b.datos->>'sector',l.sector),'unidad',coalesce(b.datos->>'unidad',l.unidad),'direccion',coalesce(b.datos->>'direccion',l.direccion),
   'responsable',coalesce(b.datos->>'lider',l.responsable),'cedula',k.cedula,'nombre',k.nombre,'sku',a.sku,'descripcion',a.descripcion,
   'empaque',c.empaque_snapshot->>'nombre','numero_contenedor',c.numero,'cantidad',a.cantidad,'validado',a.validado,
   'estado',CASE WHEN a.validado=a.cantidad THEN 'VALIDADO' WHEN a.validado>0 THEN 'PARCIAL' ELSE 'PENDIENTE' END,
   'validador',a.validador,'empacador',p.nombre,'fecha_validacion',a.fecha_validacion,'transportadora',NULL,'placa_guia',NULL,
   'motivo_modificacion',a.motivo_modificacion,
   'logistica',b.datos->>'logistica','entrega',b.datos->>'entrega','unidad_directiva',b.datos->>'unidad_directiva',
   'gerencia',b.datos->>'gerencia','cargo',b.datos->>'cargo','prenda',b.datos->>'prenda','regional',b.datos->>'regional',
   'departamento',b.datos->>'departamento','items_kit',b.datos->'items_kit','items_lista',b.datos->'items_lista','items_direccion',b.datos->'items_direccion'),k.lista,k.numero_persona,a.sku
  FROM kits k JOIN articulos a ON a.kit_id=k.id JOIN public.masiva_listas l ON l.operacion_id=k.operacion_id AND l.lista=k.lista
  LEFT JOIN public.masiva_personal p ON p.id=k.empacador_id LEFT JOIN public.masiva_cajas c ON c.id=k.caja_id
  LEFT JOIN public.masiva_base_fuente b ON b.articulo_id=a.id
  WHERE p_vista='base' AND(p_buscar='' OR position(lower(p_buscar) IN lower(concat_ws(' ',op.cliente,k.lista,k.numero_persona,
   coalesce(b.datos->>'ciudad',l.ciudad),coalesce(b.datos->>'sede',l.sede),coalesce(b.datos->>'sector',l.sector),
   coalesce(b.datos->>'unidad',l.unidad),coalesce(b.datos->>'direccion',l.direccion),coalesce(b.datos->>'lider',l.responsable),
   k.cedula,k.nombre,a.sku,a.descripcion,p.nombre,a.validador,c.empaque_snapshot->>'nombre',
   b.datos->>'logistica',b.datos->>'entrega',b.datos->>'unidad_directiva',b.datos->>'gerencia',b.datos->>'cargo',
   b.datos->>'prenda',b.datos->>'regional',b.datos->>'departamento')))>0)
 ), por_fecha AS MATERIALIZED(
  SELECT d.* FROM datos d WHERE
   (p_desde IS NULL OR ((d.fila->>campo_fecha)::timestamptz AT TIME ZONE 'America/Bogota')::date>=p_desde)
   AND(p_hasta IS NULL OR ((d.fila->>campo_fecha)::timestamptz AT TIME ZONE 'America/Bogota')::date<=p_hasta)
 ), filtros AS MATERIALIZED(
  SELECT f.key,f.value FROM jsonb_each(p_filtros) f WHERE jsonb_array_length(f.value)>0
 ), evaluados AS MATERIALIZED(
  SELECT d.*,ARRAY(SELECT f.key FROM filtros f WHERE NOT f.value ? coalesce(d.fila->>f.key,'')) AS fallas FROM por_fecha d
 ), filtrados AS MATERIALIZED(
  SELECT * FROM evaluados WHERE cardinality(fallas)=0
 ), pagina AS(
  SELECT * FROM filtrados ORDER BY CASE WHEN orden_lista~'^[0-9]+$' THEN orden_lista::numeric END NULLS LAST,
   orden_lista,orden_persona,orden_sku LIMIT p_tamano OFFSET (p_pagina-1)*p_tamano
 ), facetas AS(
  SELECT c.campo,coalesce((SELECT jsonb_agg(v.valor ORDER BY v.valor) FROM(
   SELECT DISTINCT coalesce(d.fila->>c.campo,'') AS valor FROM evaluados d
   WHERE cardinality(d.fallas)=0 OR d.fallas=ARRAY[c.campo]
  ) v),'[]') AS valores FROM unnest(campos) c(campo) WHERE p_incluir_opciones
 )
 SELECT jsonb_build_object('filas',coalesce((SELECT jsonb_agg(p.fila ORDER BY CASE WHEN p.orden_lista~'^[0-9]+$' THEN p.orden_lista::numeric END NULLS LAST,
   p.orden_lista,p.orden_persona,p.orden_sku) FROM pagina p),'[]'),
  'total',(SELECT count(*) FROM filtrados),'pagina',p_pagina,'tamano',p_tamano,'vista',p_vista,'fecha_tipo',campo_fecha,
  'opciones',coalesce((SELECT jsonb_object_agg(campo,valores) FROM facetas),'{}'),
  'metricas',jsonb_build_object('registros',(SELECT count(*) FROM filtrados),
   'listas',(SELECT count(DISTINCT fila->>'lista') FROM filtrados),
   'kits',CASE WHEN p_vista='listado' THEN (SELECT coalesce(sum((fila->>'kits_totales')::bigint),0) FROM filtrados)
    ELSE (SELECT count(DISTINCT fila->>'kit_id') FROM filtrados) END,
   'prendas_requeridas',(SELECT coalesce(sum((fila->>CASE WHEN p_vista='listado' THEN 'prendas_requeridas' ELSE 'cantidad' END)::bigint),0) FROM filtrados),
   'prendas_validadas',(SELECT coalesce(sum((fila->>CASE WHEN p_vista='listado' THEN 'prendas_validadas' ELSE 'validado' END)::bigint),0) FROM filtrados)))
 INTO respuesta;
 RETURN respuesta;
END $$;

REVOKE ALL ON FUNCTION public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean) TO authenticated;
COMMENT ON FUNCTION public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)
 IS 'Lectura del maestro por lista o artículo. Filtros globales, rangos reales en Colombia y pesos promedio por contenedor ocupado. No registra despacho.';
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 133_masiva_conciliacion.sql

CREATE FUNCTION public.masiva_recepcion_puesto(p_operacion uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 RETURN jsonb_build_object('pedidos',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.proveedor,x.orden_carga) FROM (
  SELECT p.proveedor,p.pedido,p.orden_carga,sum(i.esperado) AS esperado,sum(i.recibido) AS recibido,
   count(*) AS referencias,count(*) FILTER(WHERE i.recibido=i.esperado) AS completas
  FROM public.masiva_pedidos p JOIN public.masiva_inventario i USING(operacion_id,proveedor,pedido)
  WHERE p.operacion_id=p_operacion GROUP BY p.proveedor,p.pedido,p.orden_carga
 ) x),'[]'));
END $$;

CREATE FUNCTION public.masiva_conciliacion_consultar(p_operacion uuid,p_buscar text DEFAULT '',p_estado text DEFAULT '',p_pagina integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE resultado jsonb; base boolean;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200
 OR p_estado IS NULL OR p_estado NOT IN('','faltante','sobrante','equilibrado','pendiente','sin_pedido') THEN RAISE EXCEPTION 'Filtro de conciliación inválido'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=p_operacion AND tipo='personal' AND estado='confirmada') INTO base;
 WITH inventario AS MATERIALIZED (
  SELECT sku,min(descripcion) descripcion,string_agg(DISTINCT proveedor,', ' ORDER BY proveedor) proveedores,
   sum(esperado) esperado,sum(recibido) recibido,sum(validado) validado,count(*) pedidos
  FROM public.masiva_inventario WHERE operacion_id=p_operacion GROUP BY sku
 ), demanda AS MATERIALIZED (
  SELECT a.sku,min(a.descripcion) descripcion,sum(a.cantidad) requerido
  FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion GROUP BY a.sku
 ), datos AS MATERIALIZED (
  SELECT coalesce(i.sku,d.sku) sku,coalesce(i.descripcion,d.descripcion) descripcion,coalesce(i.proveedores,'Sin pedido') proveedores,
   coalesce(i.esperado,0) esperado,coalesce(i.recibido,0) recibido,coalesce(i.esperado,0)-coalesce(i.recibido,0) pendiente,
   CASE WHEN base THEN coalesce(d.requerido,0) END requerido,coalesce(i.validado,0) validado,
   coalesce(i.recibido,0)-coalesce(i.validado,0) disponible,
   CASE WHEN base THEN coalesce(i.recibido,0)-coalesce(d.requerido,0) END saldo,
   CASE WHEN base THEN coalesce(i.esperado,0)-coalesce(d.requerido,0) END proyeccion,
   coalesce(i.pedidos,0) pedidos
  FROM inventario i FULL JOIN demanda d USING(sku)
 ), filtrados AS MATERIALIZED (
  SELECT * FROM datos WHERE (coalesce(p_buscar,'')='' OR position(lower(trim(p_buscar)) IN lower(sku||' '||descripcion||' '||proveedores))>0)
   AND CASE p_estado WHEN 'faltante' THEN proyeccion<0 WHEN 'sobrante' THEN proyeccion>0 WHEN 'equilibrado' THEN proyeccion=0
    WHEN 'pendiente' THEN pendiente>0 WHEN 'sin_pedido' THEN pedidos=0 ELSE true END
 ), pagina AS (SELECT * FROM filtrados ORDER BY sku LIMIT 50 OFFSET (p_pagina-1)*50)
 SELECT jsonb_build_object('filas',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.sku) FROM pagina p),'[]'),
  'total',(SELECT count(*) FROM filtrados),'pagina',p_pagina,'metricas',
  (SELECT jsonb_build_object('base_personal_cargada',base,'esperado',coalesce(sum(esperado),0),'recibido',coalesce(sum(recibido),0),
   'pendiente',coalesce(sum(pendiente),0),'requerido',CASE WHEN base THEN coalesce(sum(requerido),0) END,
   'validado',coalesce(sum(validado),0),'disponible',coalesce(sum(disponible),0),
   'sobrante_previsto',CASE WHEN base THEN coalesce(sum(greatest(proyeccion,0)),0) END,
   'faltante_previsto',CASE WHEN base THEN coalesce(sum(greatest(-proyeccion,0)),0) END,
   'referencias_faltantes',count(*) FILTER(WHERE proyeccion<0),'sin_pedido',count(*) FILTER(WHERE pedidos=0)) FROM datos)) INTO resultado;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.masiva_recepcion_puesto(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.masiva_conciliacion_consultar(uuid,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_recepcion_puesto(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.masiva_conciliacion_consultar(uuid,text,text,integer) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 134_masiva_validacion_directa.sql
-- Después de 133. Conserva datos, movimientos, documentos e historial existentes.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.masiva_recepcion_puesto(uuid)') IS NULL
 THEN RAISE EXCEPTION 'Aplica primero la migración 133'; END IF;
END $$;
-- La marca única respalda la regla de una omisión por kit, incluso con reintentos.
CREATE UNIQUE INDEX IF NOT EXISTS masiva_omision_empaque_unica
 ON public.masiva_auditoria(kit_id)
 WHERE accion='reportar_error' AND datos->>'origen'='asignacion_tardia';

CREATE OR REPLACE FUNCTION public.masiva_consultar(p_operacion uuid DEFAULT NULL,p_vista text DEFAULT 'resumen',p_buscar text DEFAULT '',p_pagina integer DEFAULT 1,p_lista text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE op public.masiva_operaciones; filas jsonb:='[]'; metricas jsonb; total bigint:=0; desplazamiento integer;
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000 OR length(coalesce(p_buscar,''))>200 THEN RAISE EXCEPTION 'Consulta inválida'; END IF;
 desplazamiento:=(p_pagina-1)*50; p_buscar:=trim(coalesce(p_buscar,'')); p_lista:=trim(coalesce(p_lista,''));
 IF p_operacion IS NULL THEN
  RETURN jsonb_build_object('operaciones',coalesce((SELECT jsonb_agg(to_jsonb(o) - 'logo_cliente' - 'logo_empresa' ORDER BY o.creado DESC) FROM public.masiva_operaciones o),'[]'::jsonb));
 END IF;
 SELECT * INTO op FROM public.masiva_operaciones WHERE id=p_operacion;
 IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
 SELECT jsonb_build_object('kits',count(*),'armados',count(*) FILTER(WHERE armado IS NOT NULL),
 'validados',count(*) FILTER(WHERE estado='validado'),'parciales',count(*) FILTER(WHERE estado='parcial')) INTO metricas FROM public.masiva_kits WHERE operacion_id=p_operacion;
 metricas:=metricas||jsonb_build_object(
 'importaciones',coalesce((SELECT jsonb_object_agg(i.tipo,jsonb_build_object('id',i.id,'estado',i.estado,'filas',i.total_filas,'archivo',i.archivo))
 FROM public.masiva_importaciones i WHERE i.operacion_id=p_operacion AND i.estado<>'cancelada'),'{}'::jsonb),
 'unidades',(SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion),
 'unidades_validadas',(SELECT coalesce(sum(validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'esperado',(SELECT coalesce(sum(esperado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'recibido',(SELECT coalesce(sum(recibido),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'disponible',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=p_operacion),
 'segundos_empaque',(SELECT coalesce(sum(segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM now()-ultimo_inicio) ELSE 0 END),0) FROM public.masiva_asignaciones WHERE operacion_id=p_operacion),
 'promedio_segundos_kit',(SELECT coalesce(round(sum(s.segundos)/nullif(sum((SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)),0),2),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.estado='finalizado'),
 'cajas',(SELECT count(*) FROM public.masiva_cajas c WHERE c.operacion_id=p_operacion),
 'primera_recepcion',(SELECT min(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'ultima_recepcion',(SELECT max(creado) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'duracion_recepcion_segundos',(SELECT coalesce(extract(epoch FROM max(creado)-min(creado)),0) FROM public.masiva_movimientos WHERE operacion_id=p_operacion AND tipo='recepcion'),
 'inicio_validacion',(SELECT min(validacion_inicio) FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'fin_validacion',(SELECT CASE WHEN count(*)>0 AND count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE NULL END FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_validacion_segundos',(SELECT coalesce(extract(epoch FROM
  (CASE WHEN count(*) FILTER(WHERE estado='validado')=count(*) THEN max(validacion_fin) ELSE coalesce(op.cerrado,now()) END)-min(validacion_inicio)),0)
  FROM public.masiva_kits WHERE operacion_id=p_operacion),
 'duracion_operacion_segundos',extract(epoch FROM coalesce(op.cerrado,now())-op.creado));
 IF p_vista='inventario' THEN
  WITH datos AS (SELECT i.*,i.recibido-i.validado AS disponible,i.esperado-i.recibido AS pendiente,
  (SELECT coalesce(sum(a.cantidad),0) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=p_operacion AND a.sku=i.sku) AS requerido
  FROM public.masiva_inventario i WHERE i.operacion_id=p_operacion AND (p_buscar='' OR i.sku ILIKE '%'||p_buscar||'%' OR i.descripcion ILIKE '%'||p_buscar||'%' OR i.proveedor ILIKE '%'||p_buscar||'%')),
  pagina AS(SELECT * FROM datos ORDER BY proveedor,pedido,sku LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='listas' THEN
  WITH datos AS(SELECT l.*,count(k.id) AS kits,count(k.id) FILTER(WHERE k.armado IS NOT NULL) AS armados,
  count(k.id) FILTER(WHERE k.estado='validado') AS validados FROM public.masiva_listas l LEFT JOIN public.masiva_kits k ON k.operacion_id=l.operacion_id AND k.lista=l.lista
  WHERE l.operacion_id=p_operacion AND (p_lista='' OR l.lista=p_lista) AND (p_buscar='' OR l.lista ILIKE '%'||p_buscar||'%' OR l.sede ILIKE '%'||p_buscar||'%') GROUP BY l.operacion_id,l.lista),
  pagina AS(SELECT * FROM datos ORDER BY lista LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista IN('kits','validacion_documento') THEN
  WITH datos AS(SELECT k.*,c.numero AS caja,c.empaque_id,c.empaque_snapshot->>'tipo' AS caja_tipo,
  c.empaque_snapshot->>'nombre' AS caja_nombre,p.nombre AS empacador,l.sede,l.sector,l.ciudad,l.unidad
  FROM public.masiva_kits k JOIN public.masiva_listas l ON l.operacion_id=k.operacion_id AND l.lista=k.lista
  LEFT JOIN public.masiva_cajas c ON c.id=k.caja_id LEFT JOIN public.masiva_personal p ON p.id=k.empacador_id
  WHERE k.operacion_id=p_operacion AND (p_lista='' OR k.lista=p_lista)
  AND ((p_vista='validacion_documento' AND p_buscar<>'' AND k.cedula=p_buscar) OR (p_vista='kits' AND (p_buscar='' OR k.id::text=p_buscar OR k.numero_persona::text=p_buscar OR k.cedula ILIKE '%'||p_buscar||'%' OR k.nombre ILIKE '%'||p_buscar||'%')))),
  pagina AS(SELECT * FROM datos ORDER BY lista,numero_persona LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)||jsonb_build_object('articulos',
  (SELECT jsonb_agg(to_jsonb(a)||jsonb_build_object('fecha_hora_validado',CASE WHEN a.validado>0 THEN
   (SELECT m.creado FROM public.masiva_movimientos m WHERE m.articulo_id=a.id ORDER BY m.creado DESC LIMIT 1) ELSE NULL END) ORDER BY a.sku)
   FROM public.masiva_articulos a WHERE a.kit_id=pagina.id))),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='auditoria' THEN
  WITH datos AS(SELECT a.* FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND(p_buscar='' OR a.accion ILIKE '%'||p_buscar||'%' OR a.actor_nombre ILIKE '%'||p_buscar||'%' OR a.kit_id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg(to_jsonb(pagina)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='personal' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.nombre),'[]') INTO total,filas FROM public.masiva_personal p WHERE p.activo;
 ELSIF p_vista='empaques' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.nombre),'[]') INTO total,filas FROM public.masiva_empaques e WHERE e.activo;
 ELSIF p_vista='asignaciones' THEN
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('empacador',p.nombre,'kits',(SELECT count(*) FROM public.masiva_kits k WHERE k.asignacion_id=s.id)) ORDER BY s.lista,s.desde),'[]')
  INTO total,filas FROM public.masiva_asignaciones s JOIN public.masiva_personal p ON p.id=s.empacador_id WHERE s.operacion_id=p_operacion AND(p_lista='' OR s.lista=p_lista);
 ELSIF p_vista='documentos' THEN
  WITH datos AS(SELECT d.* FROM public.masiva_documentos d WHERE d.operacion_id=p_operacion AND(p_lista='' OR d.lista=p_lista) AND(p_buscar='' OR d.id::text=p_buscar)),
  pagina AS(SELECT * FROM datos ORDER BY creado DESC,id LIMIT 50 OFFSET desplazamiento)
  SELECT (SELECT count(*) FROM datos),coalesce(jsonb_agg((CASE WHEN p_buscar<>'' THEN to_jsonb(pagina) ELSE to_jsonb(pagina)-'snapshot' END)||jsonb_build_object('created_at',pagina.creado)),'[]') INTO total,filas FROM pagina;
 ELSIF p_vista='indicadores' THEN
  WITH datos AS(SELECT p.id,p.nombre,
  (SELECT count(*) FROM public.masiva_kits k WHERE k.operacion_id=p_operacion AND k.empacador_id=p.id AND (k.armado IS NOT NULL OR k.validacion_inicio IS NOT NULL)) AS kits,
  (SELECT coalesce(sum(s.segundos),0) FROM public.masiva_asignaciones s WHERE s.operacion_id=p_operacion AND s.empacador_id=p.id AND s.estado='finalizado') AS segundos,
  (SELECT count(*) FROM public.masiva_auditoria a WHERE a.operacion_id=p_operacion AND a.accion='reportar_error' AND a.datos->>'empacador_id'=p.id::text) AS errores
  FROM public.masiva_personal p WHERE EXISTS(SELECT 1 FROM public.masiva_kits k WHERE k.operacion_id=p_operacion AND k.empacador_id=p.id))
  SELECT count(*),coalesce(jsonb_agg(to_jsonb(datos)||jsonb_build_object('puntos',kits*op.puntos_kit-errores*op.penalizacion_error,'promedio_segundos',(SELECT round(datos.segundos/nullif(count(*),0),2) FROM public.masiva_kits k JOIN public.masiva_asignaciones s ON s.id=k.asignacion_id WHERE k.operacion_id=p_operacion AND k.empacador_id=datos.id AND s.estado='finalizado')) ORDER BY kits*op.puntos_kit-errores*op.penalizacion_error DESC,kits DESC,nombre),'[]') INTO total,filas FROM datos;
  metricas:=metricas||jsonb_build_object('validadores',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
  SELECT c.actor_id,u.nombre AS actor_nombre,sum(c.cantidad) AS prendas,sum(c.cantidad)*op.puntos_prenda AS puntos
  FROM public.masiva_validacion_creditos c JOIN public.masiva_articulos a ON a.id=c.articulo_id
  JOIN public.masiva_kits k ON k.id=a.kit_id JOIN public.usuarios u ON u.auth_id=c.actor_id
  WHERE k.operacion_id=p_operacion GROUP BY c.actor_id,u.nombre ORDER BY prendas DESC) x),'[]'::jsonb));
 ELSIF p_vista NOT IN('resumen','configuracion') THEN RAISE EXCEPTION 'Vista no reconocida'; END IF;
 RETURN jsonb_build_object('operacion',to_jsonb(op),'metricas',metricas,'filas',filas,'total',total,'pagina',p_pagina);
END $$;

CREATE OR REPLACE FUNCTION public.masiva_ejecutar(p_accion text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='10s' SET statement_timeout='180s' AS $$
DECLARE actor uuid:=auth.uid(); v_actor_nombre text; es_admin boolean; op public.masiva_operaciones; operacion uuid;
 imp public.masiva_importaciones; k public.masiva_kits; art public.masiva_articulos; inv public.masiva_inventario;
 asig public.masiva_asignaciones; persona public.masiva_personal; empaque public.masiva_empaques; caja public.masiva_cajas;
 solicitud public.masiva_solicitudes; req uuid; huella text; resultado jsonb; id_nuevo uuid; v_filas jsonb; fila jsonb;
 n integer; n_desde integer; n_hasta integer; v_cantidad integer; cambio integer; restante integer; tomar integer;
 version_documento integer; consumo record; credito record; anterior jsonb; snapshot jsonb; evento_kit uuid; ahora timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.masiva_acceso() THEN RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501'; END IF;
 SELECT u.nombre,coalesce(u.roles,ARRAY[u.rol]) @> ARRAY['admin'] INTO v_actor_nombre,es_admin FROM public.usuarios u WHERE u.auth_id=actor AND u.activo;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>5000000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF p_accion IN('crear_operacion','iniciar_importacion','cargar_lote','confirmar_importacion','cancelar_importacion','guardar_personal','guardar_empaque','cerrar_operacion','configurar','configurar_recepcion') AND NOT es_admin
 THEN RAISE EXCEPTION 'Esta acción requiere administrador' USING ERRCODE='42501'; END IF;
 IF p_accion IN('recibir','validar','corregir','reportar_error','reiniciar_validacion') THEN
  req:=nullif(p_datos->>'request_id','')::uuid; IF req IS NULL THEN RAISE EXCEPTION 'Falta el identificador de la solicitud'; END IF;
  huella:=md5((p_datos-'request_id')::text);
  SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
  IF FOUND THEN
   IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
   RETURN solicitud.respuesta;
  END IF;
 END IF;
 operacion:=nullif(p_datos->>'operacion_id','')::uuid;
 IF p_accion IN('cargar_lote','confirmar_importacion','cancelar_importacion') THEN
  SELECT * INTO imp FROM public.masiva_importaciones WHERE id=(p_datos->>'importacion_id')::uuid;
  IF imp.id IS NULL THEN RAISE EXCEPTION 'Importación no encontrada'; END IF;
  operacion:=imp.operacion_id;
 END IF;
 IF p_accion NOT IN('crear_operacion','guardar_personal','guardar_empaque') THEN
  SELECT * INTO op FROM public.masiva_operaciones WHERE id=operacion FOR UPDATE;
  IF op.id IS NULL THEN RAISE EXCEPTION 'Operación no encontrada'; END IF;
  IF imp.id IS NOT NULL THEN
   -- La carga pudo cancelarse o confirmarse mientras esperábamos el bloqueo.
   SELECT * INTO imp FROM public.masiva_importaciones WHERE id=imp.id FOR UPDATE;
  END IF;
  IF req IS NOT NULL THEN
   SELECT * INTO solicitud FROM public.masiva_solicitudes WHERE request_id=req;
   IF FOUND THEN
    IF solicitud.actor_id<>actor OR solicitud.accion<>p_accion OR solicitud.huella<>huella THEN RAISE EXCEPTION 'Identificador ya utilizado por otra solicitud'; END IF;
    RETURN solicitud.respuesta;
   END IF;
  END IF;
  IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;
 END IF;

 CASE p_accion
 WHEN 'crear_operacion' THEN
  INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;
  resultado:=jsonb_build_object('id',operacion);
 WHEN 'guardar_personal' THEN
  IF nullif(trim(p_datos->>'usuario_numero'),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE numero_usuario=trim(p_datos->>'usuario_numero') AND activo)
  THEN RAISE EXCEPTION 'Usuario asociado no encontrado o inactivo'; END IF;
  INSERT INTO public.masiva_personal(nombre,usuario_numero,creado_por) VALUES(trim(p_datos->>'nombre'),nullif(trim(p_datos->>'usuario_numero'),''),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'guardar_empaque' THEN
  INSERT INTO public.masiva_empaques(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por)
  VALUES(trim(p_datos->>'nombre'),(p_datos->>'peso_vacio')::numeric,(p_datos->>'peso_lleno')::numeric,(p_datos->>'largo')::numeric,
  (p_datos->>'ancho')::numeric,(p_datos->>'alto')::numeric,coalesce(p_datos->>'tipo','caja'),actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo);
 WHEN 'iniciar_importacion' THEN
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND tipo=p_datos->>'tipo' AND estado<>'cancelada') THEN RAISE EXCEPTION 'Ya existe una carga de este tipo; finaliza o cancela la carga pendiente'; END IF;
  INSERT INTO public.masiva_importaciones(operacion_id,tipo,archivo,total_filas,total_lotes,creado_por)
  VALUES(operacion,p_datos->>'tipo',p_datos->>'archivo',(p_datos->>'total_filas')::integer,(p_datos->>'total_lotes')::integer,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('importacion_id',id_nuevo);
 WHEN 'cargar_lote' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La importación ya no admite lotes'; END IF;
  n:=(p_datos->>'indice')::integer; v_filas:=p_datos->'filas';
  IF n IS NULL OR n<0 OR n>=imp.total_lotes OR jsonb_typeof(v_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(v_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Lote inválido'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id AND indice=n AND masiva_importacion_lotes.filas<>v_filas) THEN RAISE EXCEPTION 'El lote ya existe con contenido diferente'; END IF;
  INSERT INTO public.masiva_importacion_lotes(importacion_id,indice,filas) VALUES(imp.id,n,v_filas) ON CONFLICT DO NOTHING;
  resultado:=jsonb_build_object('importacion_id',imp.id,'indice',n,'filas',jsonb_array_length(v_filas));
 WHEN 'cancelar_importacion' THEN
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'Solo puede cancelarse una carga sin confirmar'; END IF;
  UPDATE public.masiva_importaciones SET estado='cancelada' WHERE id=imp.id;
  resultado:=jsonb_build_object('cancelada',true);
 WHEN 'confirmar_importacion' THEN
  IF imp.estado='confirmada' THEN RETURN jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas); END IF;
  IF imp.estado<>'cargando' THEN RAISE EXCEPTION 'La carga fue cancelada'; END IF;
  IF (SELECT count(*) FROM public.masiva_importacion_lotes WHERE importacion_id=imp.id)<>imp.total_lotes
  OR (SELECT coalesce(sum(jsonb_array_length(l.filas)),0) FROM public.masiva_importacion_lotes l WHERE importacion_id=imp.id)<>imp.total_filas THEN RAISE EXCEPTION 'La carga está incompleta; vuelve a enviar los lotes pendientes'; END IF;
  SELECT jsonb_agg(x.value ORDER BY l.indice,x.ordinality) INTO v_filas FROM public.masiva_importacion_lotes l CROSS JOIN LATERAL jsonb_array_elements(l.filas) WITH ORDINALITY x(value,ordinality) WHERE l.importacion_id=imp.id;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE jsonb_typeof(f)<>'object' OR length(trim(coalesce(f->>'sku',''))) NOT BETWEEN 1 AND 100
  OR length(trim(coalesce(f->>'descripcion',''))) NOT BETWEEN 1 AND 500 OR coalesce(f->>'cantidad','') !~ '^[0-9]{1,7}$' OR (f->>'cantidad')::integer<1)
  THEN RAISE EXCEPTION 'Hay referencias, descripciones o cantidades inválidas en el archivo'; END IF;
  IF imp.tipo='recepcion' THEN
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'proveedor',''))) NOT BETWEEN 1 AND 160 OR length(trim(coalesce(f->>'pedido',''))) NOT BETWEEN 1 AND 100
    OR upper(trim(coalesce(f->>'unidad','UNIDAD'))) NOT IN('UNIDAD','UN','UND','PAR','PARES')) THEN RAISE EXCEPTION 'Proveedor, pedido o unidad inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1) THEN RAISE EXCEPTION 'Hay referencias repetidas dentro del mismo pedido y proveedor'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(coalesce(f->>'horario',''))>240)
   THEN RAISE EXCEPTION 'El horario de recepción admite máximo 240 caracteres'; END IF;
   IF EXISTS(SELECT trim(f->>'proveedor'),trim(f->>'pedido') FROM jsonb_array_elements(v_filas) f
    GROUP BY 1,2 HAVING count(DISTINCT nullif(trim(f->>'horario'),''))>1)
   THEN RAISE EXCEPTION 'Hay horarios distintos para una misma orden de compra'; END IF;
   INSERT INTO public.masiva_pedidos(operacion_id,proveedor,pedido,horario,orden_carga)
   SELECT operacion,proveedor,pedido,horario,row_number() OVER(ORDER BY primera_fila)::integer
   FROM (SELECT trim(f.value->>'proveedor') AS proveedor,trim(f.value->>'pedido') AS pedido,
    coalesce(max(nullif(trim(f.value->>'horario'),'')),'') AS horario,min(f.ordinality) AS primera_fila
    FROM jsonb_array_elements(v_filas) WITH ORDINALITY f(value,ordinality) GROUP BY 1,2) q;
   INSERT INTO public.masiva_inventario(operacion_id,proveedor,pedido,sku,descripcion,unidad,esperado)
   SELECT operacion,trim(f->>'proveedor'),trim(f->>'pedido'),trim(f->>'sku'),trim(f->>'descripcion'),CASE WHEN upper(trim(f->>'unidad')) IN('PAR','PARES') THEN 'PAR' ELSE 'UNIDAD' END,(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f;
  ELSE
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_filas) f WHERE length(trim(coalesce(f->>'lista',''))) NOT BETWEEN 1 AND 100
    OR length(trim(coalesce(f->>'cedula',''))) NOT BETWEEN 1 AND 100 OR length(trim(coalesce(f->>'nombre',''))) NOT BETWEEN 1 AND 200
    OR coalesce(f->>'numero_persona','') !~ '^[0-9]{1,7}$' OR (f->>'numero_persona')::integer<1) THEN RAISE EXCEPTION 'Lista, documento, nombre o consecutivo de persona inválidos'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT (f->>'numero_persona')::integer)>1 OR count(DISTINCT trim(f->>'nombre'))>1)
   OR EXISTS(SELECT trim(f->>'lista'),(f->>'numero_persona')::integer FROM jsonb_array_elements(v_filas) f GROUP BY 1,2 HAVING count(DISTINCT trim(f->>'cedula'))>1)
   THEN RAISE EXCEPTION 'Una persona tiene datos distintos o un consecutivo está asignado a varias personas'; END IF;
   IF EXISTS(SELECT trim(f->>'lista'),trim(f->>'cedula'),trim(f->>'sku') FROM jsonb_array_elements(v_filas) f GROUP BY 1,2,3 HAVING count(*)>1)
   THEN RAISE EXCEPTION 'Referencia repetida en un kit; unifica su cantidad antes de confirmar'; END IF;
   INSERT INTO public.masiva_listas(operacion_id,lista,sede,ciudad,direccion,unidad,sector,responsable,responsables)
   SELECT operacion,trim(f->>'lista'),max(coalesce(f->>'sede','')),max(coalesce(f->>'ciudad','')),max(coalesce(f->>'direccion','')),
   max(coalesce(f->>'unidad','')),max(coalesce(f->>'sector','')),coalesce(min(nullif(trim(f->>'lider'),'')),''),
   coalesce(jsonb_agg(DISTINCT trim(f->>'lider')) FILTER(WHERE nullif(trim(f->>'lider'),'') IS NOT NULL),'[]') FROM jsonb_array_elements(v_filas) f GROUP BY trim(f->>'lista');
   INSERT INTO public.masiva_kits(operacion_id,lista,numero_persona,cedula,nombre)
   SELECT operacion,trim(f->>'lista'),(f->>'numero_persona')::integer,trim(f->>'cedula'),trim(f->>'nombre') FROM jsonb_array_elements(v_filas) f GROUP BY 2,3,4,5;
   INSERT INTO public.masiva_articulos(kit_id,sku,descripcion,cantidad)
   SELECT kit_fila.id,trim(f->>'sku'),trim(f->>'descripcion'),(f->>'cantidad')::integer FROM jsonb_array_elements(v_filas) f
   JOIN public.masiva_kits kit_fila ON kit_fila.operacion_id=operacion AND kit_fila.lista=trim(f->>'lista') AND kit_fila.cedula=trim(f->>'cedula');
  END IF;
  UPDATE public.masiva_importaciones SET estado='confirmada',confirmado=ahora WHERE id=imp.id;
  resultado:=jsonb_build_object('importacion_id',imp.id,'confirmada',true,'filas',imp.total_filas);
 WHEN 'recibir' THEN
  SELECT * INTO inv FROM public.masiva_inventario WHERE id=(p_datos->>'inventario_id')::uuid AND operacion_id=operacion FOR UPDATE;
  v_cantidad:=(p_datos->>'cantidad')::integer;
  IF inv.id IS NULL OR v_cantidad IS NULL OR v_cantidad<1 THEN RAISE EXCEPTION 'Referencia o cantidad no válida'; END IF;
  IF inv.recibido+v_cantidad>inv.esperado THEN RAISE EXCEPTION 'La recepción supera el límite del pedido (% pendientes)',inv.esperado-inv.recibido; END IF;
  IF length(trim(coalesce(p_datos->>'soporte',''))) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'Registra la remisión o soporte de recepción'; END IF;
  IF p_datos ? 'novedad' THEN
   IF jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
   UPDATE public.masiva_pedidos SET novedad=trim(p_datos->>'novedad')
   WHERE operacion_id=operacion AND proveedor=inv.proveedor AND pedido=inv.pedido;
  END IF;
  UPDATE public.masiva_inventario SET recibido=recibido+v_cantidad WHERE id=inv.id;
  INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,'recepcion',v_cantidad,trim(p_datos->>'soporte'),actor);
  resultado:=jsonb_build_object('id',inv.id,'recibido',inv.recibido+v_cantidad,'disponible',inv.recibido+v_cantidad-inv.validado);
 WHEN 'asignar' THEN
  SELECT * INTO persona FROM public.masiva_personal WHERE id=(p_datos->>'empacador_id')::uuid AND activo;
  IF persona.id IS NULL THEN RAISE EXCEPTION 'Selecciona una persona activa'; END IF;
  SELECT min(numero_persona),max(numero_persona) INTO n_desde,n_hasta FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  n_desde:=coalesce(nullif(p_datos->>'desde','')::integer,n_desde); n_hasta:=coalesce(nullif(p_datos->>'hasta','')::integer,n_hasta);
  IF n_desde IS NULL OR n_hasta IS NULL OR n_desde<1 OR n_hasta<n_desde THEN RAISE EXCEPTION 'Lista o rango inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_desde)
  OR NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona=n_hasta) THEN RAISE EXCEPTION 'El rango debe iniciar y terminar en personas de la lista'; END IF;
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=persona.id AND desde=n_desde AND hasta=n_hasta;
  IF asig.id IS NOT NULL THEN RETURN jsonb_build_object('id',asig.id,'desde',n_desde,'hasta',n_hasta); END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta AND (empacador_id IS NOT NULL AND (empacador_id<>persona.id OR asignacion_id IS NOT NULL)))
  THEN RAISE EXCEPTION 'El rango se cruza con kits ya asignados'; END IF;
  INSERT INTO public.masiva_asignaciones(operacion_id,lista,empacador_id,desde,hasta,creado_por) VALUES(operacion,p_datos->>'lista',persona.id,n_desde,n_hasta,actor) RETURNING id INTO id_nuevo;
  UPDATE public.masiva_kits SET empacador_id=persona.id,asignacion_id=id_nuevo WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND numero_persona BETWEEN n_desde AND n_hasta;
  GET DIAGNOSTICS n=ROW_COUNT;
  resultado:=jsonb_build_object('id',id_nuevo,'kits',n,'desde',n_desde,'hasta',n_hasta);
 WHEN 'tiempo' THEN
  SELECT * INTO asig FROM public.masiva_asignaciones WHERE operacion_id=operacion
  AND ((nullif(p_datos->>'asignacion_id','') IS NOT NULL AND id=(p_datos->>'asignacion_id')::uuid)
   OR (nullif(p_datos->>'asignacion_id','') IS NULL AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid
   AND (nullif(p_datos->>'desde','') IS NULL OR desde=(p_datos->>'desde')::integer) AND(nullif(p_datos->>'hasta','') IS NULL OR hasta=(p_datos->>'hasta')::integer))) ORDER BY creado LIMIT 1 FOR UPDATE;
  IF asig.id IS NULL AND p_datos->>'accion'='iniciar' AND nullif(p_datos->>'asignacion_id','') IS NULL THEN
   -- Registrar empaque es un único formulario; la asignación queda en esta transacción.
   resultado:=public.masiva_ejecutar('asignar',p_datos);
   SELECT * INTO asig FROM public.masiva_asignaciones WHERE id=(resultado->>'id')::uuid FOR UPDATE;
  END IF;
  IF asig.id IS NULL THEN RAISE EXCEPTION 'Selecciona una asignación de empaque'; END IF;
  -- Evita que dos operaciones inicien simultáneamente el tiempo de la misma persona.
  PERFORM 1 FROM public.masiva_personal WHERE id=asig.empacador_id FOR UPDATE;
  IF nullif(p_datos->>'asignacion_id','') IS NULL AND nullif(p_datos->>'desde','') IS NULL AND (SELECT count(*) FROM public.masiva_asignaciones WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND empacador_id=(p_datos->>'empacador_id')::uuid)>1
  THEN RAISE EXCEPTION 'Selecciona el rango de empaque para registrar su tiempo'; END IF;
  IF p_datos->>'accion'='iniciar' THEN
   IF asig.estado NOT IN('pendiente','pausado') THEN RAISE EXCEPTION 'El empaque ya está iniciado o finalizado'; END IF;
   IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE empacador_id=asig.empacador_id AND estado='en_curso' AND id<>asig.id) THEN RAISE EXCEPTION 'Esta persona ya tiene otro empaque en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='en_curso',inicio=coalesce(inicio,ahora),ultimo_inicio=ahora WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado='armando' WHERE asignacion_id=asig.id AND validacion_inicio IS NULL;
  ELSIF p_datos->>'accion'='pausar' THEN
   IF asig.estado<>'en_curso' THEN RAISE EXCEPTION 'El empaque no está en curso'; END IF;
   UPDATE public.masiva_asignaciones SET estado='pausado',segundos=segundos+extract(epoch FROM ahora-ultimo_inicio),ultimo_inicio=NULL WHERE id=asig.id;
  ELSIF p_datos->>'accion'='finalizar' THEN
   IF asig.estado NOT IN('en_curso','pausado') THEN RAISE EXCEPTION 'Inicia el empaque antes de finalizarlo'; END IF;
   UPDATE public.masiva_asignaciones SET estado='finalizado',fin=ahora,segundos=segundos+CASE WHEN estado='en_curso' THEN extract(epoch FROM ahora-ultimo_inicio) ELSE 0 END,ultimo_inicio=NULL WHERE id=asig.id;
   UPDATE public.masiva_kits SET estado=CASE WHEN validacion_inicio IS NULL THEN 'armado' ELSE estado END,armado=ahora WHERE asignacion_id=asig.id;
  ELSE RAISE EXCEPTION 'Acción de tiempo inválida'; END IF;
  SELECT to_jsonb(s) INTO resultado FROM public.masiva_asignaciones s WHERE id=asig.id;
 WHEN 'validar','corregir','reabrir','embalar','reportar_error','reiniciar_validacion' THEN
  SELECT * INTO k FROM public.masiva_kits WHERE id=(p_datos->>'kit_id')::uuid AND operacion_id=operacion FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'Kit no encontrado en esta operación'; END IF;
  evento_kit:=k.id;
  -- El registro del empaque transcurre en paralelo: no se exige finalizar tiempos.
  IF nullif(p_datos->>'validador_id','') IS NOT NULL AND (p_datos->>'validador_id')::uuid<>actor
  THEN RAISE EXCEPTION 'El validador corresponde al usuario de la sesión' USING ERRCODE='42501'; END IF;
  IF k.empacador_id IS NULL AND p_accion='validar' THEN
   SELECT * INTO persona FROM public.masiva_personal WHERE id=nullif(p_datos->>'empacador_id','')::uuid AND activo;
   IF persona.id IS NULL THEN RAISE EXCEPTION 'Selecciona el empacador responsable antes de validar'; END IF;
   UPDATE public.masiva_kits SET empacador_id=persona.id WHERE id=k.id;
   k.empacador_id:=persona.id;
   INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos)
   VALUES(operacion,k.id,'reportar_error',actor,v_actor_nombre,jsonb_build_object(
    'empacador_id',persona.id,'origen','asignacion_tardia','categoria','MAL EMPAQUE',
    'entrada',jsonb_build_object('motivo','MAL EMPAQUE','detalle','Empacador registrado al iniciar la validación'),
    'resultado',jsonb_build_object('penalizacion',op.penalizacion_error)));
  ELSIF k.empacador_id IS NULL THEN
   RAISE EXCEPTION 'Selecciona el empacador responsable al validar la primera prenda';
  ELSIF p_accion='validar' AND nullif(p_datos->>'empacador_id','') IS NOT NULL
   AND (p_datos->>'empacador_id')::uuid<>k.empacador_id THEN
   RAISE EXCEPTION 'El kit ya tiene otro empacador asignado. Actualiza antes de continuar';
  END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo empacó'; END IF;
  IF p_accion IN('reabrir','corregir','reportar_error','reiniciar_validacion') AND length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de la revisión'; END IF;
  IF p_accion='reabrir' THEN
   IF k.validacion_inicio IS NULL THEN RAISE EXCEPTION 'El kit todavía no tiene validaciones'; END IF;
   UPDATE public.masiva_kits SET revision_abierta=true WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'revision_abierta',true);
  ELSIF p_accion='reportar_error' THEN
   resultado:=jsonb_build_object('id',k.id,'empacador_id',k.empacador_id,'penalizacion',op.penalizacion_error);
  ELSIF p_accion='reiniciar_validacion' THEN
   -- Exigir el conteo visto por el operador impide borrar lecturas de otra estación.
   IF jsonb_typeof(p_datos->'cantidades') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Actualiza el kit antes de reiniciar su validación'; END IF;
   SELECT jsonb_agg(jsonb_build_object('articulo_id',(f->>'articulo_id')::uuid,'validado',(f->>'validado')::integer)
    ORDER BY (f->>'articulo_id')::uuid) INTO v_filas FROM jsonb_array_elements(p_datos->'cantidades') f;
   IF v_filas IS DISTINCT FROM (SELECT jsonb_agg(jsonb_build_object('articulo_id',a.id,'validado',a.validado) ORDER BY a.id)
    FROM public.masiva_articulos a WHERE a.kit_id=k.id) THEN
    RAISE EXCEPTION 'El kit cambió en otra estación. Actualiza y revisa las cantidades antes de reiniciar'; END IF;
   SELECT coalesce(sum(a.validado),0),jsonb_agg(to_jsonb(a) ORDER BY a.sku) INTO v_cantidad,anterior
    FROM public.masiva_articulos a WHERE a.kit_id=k.id;
   IF v_cantidad=0 THEN RAISE EXCEPTION 'El kit no tiene prendas validadas para reiniciar'; END IF;
   FOR art IN SELECT * FROM public.masiva_articulos WHERE kit_id=k.id ORDER BY id FOR UPDATE LOOP
    IF (SELECT coalesce(sum(c.cantidad),0) FROM public.masiva_consumos c WHERE c.articulo_id=art.id)<>art.validado
     OR (SELECT coalesce(sum(c.cantidad),0) FROM public.masiva_validacion_creditos c WHERE c.articulo_id=art.id)<>art.validado THEN
     RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     UPDATE public.masiva_inventario SET validado=validado-consumo.cantidad
      WHERE id=consumo.inventario_id AND validado>=consumo.cantidad;
     IF NOT FOUND THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id)
      VALUES(operacion,consumo.inventario_id,art.id,'correccion',consumo.cantidad,trim(p_datos->>'motivo'),actor);
    END LOOP;
    UPDATE public.masiva_consumos SET cantidad=0 WHERE articulo_id=art.id AND cantidad>0;
    UPDATE public.masiva_validacion_creditos SET cantidad=0,actualizado=ahora WHERE articulo_id=art.id AND cantidad>0;
    UPDATE public.masiva_articulos SET validado=0 WHERE id=art.id;
   END LOOP;
   -- Se conservan autoría, armado, caja, inicio histórico y documentos emitidos.
   UPDATE public.masiva_kits SET estado=CASE WHEN armado IS NULL THEN 'pendiente' ELSE 'armado' END,revision_abierta=true,validacion_fin=NULL WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'estado',CASE WHEN k.armado IS NULL THEN 'pendiente' ELSE 'armado' END,'revision_abierta',true,
    'unidades_reintegradas',v_cantidad,'anterior',anterior);
  ELSIF p_accion='embalar' THEN
   IF NOT EXISTS(SELECT 1 FROM public.masiva_articulos WHERE kit_id=k.id AND validado>0) THEN RAISE EXCEPTION 'Valida al menos una prenda antes de asignar el empaque'; END IF;
   n:=(p_datos->>'caja')::integer; IF n IS NULL OR n<1 THEN RAISE EXCEPTION 'Número de caja inválido'; END IF;
   SELECT * INTO empaque FROM public.masiva_empaques WHERE id=(p_datos->>'empaque_id')::uuid AND activo;
   IF empaque.id IS NULL THEN RAISE EXCEPTION 'Selecciona el tipo de empaque'; END IF;
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL AND caja.empaque_id<>empaque.id THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   IF caja.id IS NULL THEN
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por) VALUES(operacion,k.lista,n,empaque.id,to_jsonb(empaque),actor) RETURNING * INTO caja;
   END IF;
   UPDATE public.masiva_kits SET caja_id=caja.id WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'caja',n,'estado',k.estado,
    'requerido',(SELECT sum(a.cantidad) FROM public.masiva_articulos a WHERE a.kit_id=k.id),
    'validado',(SELECT sum(a.validado) FROM public.masiva_articulos a WHERE a.kit_id=k.id));
  ELSE
   IF p_accion='validar' THEN
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND sku=trim(p_datos->>'sku') FOR UPDATE;
    IF art.id IS NULL THEN
     RAISE EXCEPTION 'El código % no pertenece a este kit. Revisa el empaque y retira la prenda incorrecta.',trim(coalesce(p_datos->>'sku',''))
      USING DETAIL=jsonb_build_object('tipo','sku_incorrecto','sku',trim(coalesce(p_datos->>'sku','')),
       'descripcion',coalesce((SELECT i.descripcion FROM public.masiva_inventario i WHERE i.operacion_id=operacion AND i.sku=trim(p_datos->>'sku') ORDER BY i.id LIMIT 1),''),
       'cantidad',0,'validado',0)::text;
    END IF;
    IF art.validado>=art.cantidad THEN
     RAISE EXCEPTION 'El código % ya tiene % de % unidades requeridas. Retira la prenda adicional y revisa el empaque.',art.sku,art.validado,art.cantidad
      USING DETAIL=jsonb_build_object('tipo','unidad_excedente','sku',art.sku,'descripcion',art.descripcion,'cantidad',art.cantidad,'validado',art.validado)::text;
    END IF;
    IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
    v_cantidad:=art.validado+1;
   ELSE
    IF NOT k.revision_abierta THEN RAISE EXCEPTION 'Reabre el kit con un motivo antes de modificar su validación'; END IF;
    SELECT * INTO art FROM public.masiva_articulos WHERE kit_id=k.id AND id=(p_datos->>'articulo_id')::uuid FOR UPDATE;
    IF art.id IS NULL THEN RAISE EXCEPTION 'Prenda no encontrada en el kit'; END IF;
    v_cantidad:=(p_datos->>'cantidad')::integer;
   END IF;
   IF v_cantidad IS NULL OR v_cantidad<0 OR v_cantidad>art.cantidad THEN RAISE EXCEPTION 'La cantidad excede lo solicitado para esta persona'; END IF;
   cambio:=v_cantidad-art.validado; restante:=abs(cambio); anterior:=to_jsonb(art);
   IF cambio>0 THEN
    FOR inv IN SELECT * FROM public.masiva_inventario WHERE operacion_id=operacion AND sku=art.sku AND recibido>validado ORDER BY proveedor,pedido,id FOR UPDATE LOOP
     tomar:=least(restante,inv.recibido-inv.validado);
     UPDATE public.masiva_inventario SET validado=validado+tomar WHERE id=inv.id;
     INSERT INTO public.masiva_consumos(articulo_id,inventario_id,cantidad) VALUES(art.id,inv.id,tomar)
     ON CONFLICT(articulo_id,inventario_id) DO UPDATE SET cantidad=masiva_consumos.cantidad+excluded.cantidad;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,inv.id,art.id,CASE WHEN p_accion='validar' THEN 'validacion' ELSE 'correccion' END,-tomar,coalesce(p_datos->>'motivo',''),actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'No hay inventario recibido suficiente para este SKU'; END IF;
   ELSIF cambio<0 THEN
    FOR consumo IN SELECT c.* FROM public.masiva_consumos c WHERE c.articulo_id=art.id AND c.cantidad>0 ORDER BY inventario_id FOR UPDATE LOOP
     tomar:=least(restante,consumo.cantidad);
     UPDATE public.masiva_inventario SET validado=validado-tomar WHERE id=consumo.inventario_id;
     UPDATE public.masiva_consumos SET cantidad=masiva_consumos.cantidad-tomar WHERE articulo_id=art.id AND inventario_id=consumo.inventario_id;
     INSERT INTO public.masiva_movimientos(operacion_id,inventario_id,articulo_id,tipo,cantidad,soporte,actor_id) VALUES(operacion,consumo.inventario_id,art.id,'correccion',tomar,p_datos->>'motivo',actor);
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de consumo; no se modificó el inventario'; END IF;
   END IF;
   IF cambio>0 THEN
    INSERT INTO public.masiva_validacion_creditos(articulo_id,actor_id,cantidad,actualizado) VALUES(art.id,actor,cambio,ahora)
    ON CONFLICT(articulo_id,actor_id) DO UPDATE SET cantidad=masiva_validacion_creditos.cantidad+excluded.cantidad,actualizado=excluded.actualizado;
   ELSIF cambio<0 THEN
    restante:=-cambio;
    FOR credito IN SELECT * FROM public.masiva_validacion_creditos WHERE articulo_id=art.id AND cantidad>0 ORDER BY actualizado DESC,actor_id FOR UPDATE LOOP
     tomar:=least(restante,credito.cantidad);
     UPDATE public.masiva_validacion_creditos SET cantidad=masiva_validacion_creditos.cantidad-tomar,actualizado=ahora WHERE articulo_id=art.id AND actor_id=credito.actor_id;
     restante:=restante-tomar; EXIT WHEN restante=0;
    END LOOP;
    IF restante>0 THEN RAISE EXCEPTION 'Inconsistencia de validación; no se modificó el inventario'; END IF;
   END IF;
   UPDATE public.masiva_articulos SET validado=v_cantidad WHERE id=art.id;
   SELECT count(*) INTO n FROM public.masiva_articulos WHERE kit_id=k.id AND validado<masiva_articulos.cantidad;
   UPDATE public.masiva_kits SET estado=CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,
   validacion_inicio=coalesce(validacion_inicio,ahora),validacion_fin=CASE WHEN n=0 THEN ahora ELSE NULL END,
   validador_id=actor,revision_abierta=n<>0 WHERE id=k.id;
   resultado:=jsonb_build_object('id',k.id,'articulo_id',art.id,'sku',art.sku,'validado',v_cantidad,'cantidad',art.cantidad,'estado',CASE WHEN n=0 THEN 'validado' ELSE 'parcial' END,'anterior',anterior,'diferencia',cambio);
  END IF;
 WHEN 'configurar_recepcion' THEN
  IF length(trim(coalesce(p_datos->>'proveedor',''))) NOT BETWEEN 1 AND 160
   OR length(trim(coalesce(p_datos->>'pedido',''))) NOT BETWEEN 1 AND 100
   OR NOT (p_datos ? 'horario' OR p_datos ? 'novedad') THEN RAISE EXCEPTION 'Selecciona una orden de compra y los datos a editar'; END IF;
  IF p_datos ? 'horario' AND (jsonb_typeof(p_datos->'horario') IS DISTINCT FROM 'string' OR length(p_datos->>'horario')>240)
   THEN RAISE EXCEPTION 'El horario admite máximo 240 caracteres'; END IF;
  IF p_datos ? 'novedad' AND (jsonb_typeof(p_datos->'novedad') IS DISTINCT FROM 'string' OR length(p_datos->>'novedad')>1000)
   THEN RAISE EXCEPTION 'La novedad admite máximo 1.000 caracteres'; END IF;
  SELECT to_jsonb(p) INTO anterior FROM public.masiva_pedidos p
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido') FOR UPDATE;
  IF anterior IS NULL THEN RAISE EXCEPTION 'Orden de compra no encontrada'; END IF;
  UPDATE public.masiva_pedidos p SET
   horario=CASE WHEN p_datos ? 'horario' THEN trim(p_datos->>'horario') ELSE p.horario END,
   novedad=CASE WHEN p_datos ? 'novedad' THEN trim(p_datos->>'novedad') ELSE p.novedad END
   WHERE p.operacion_id=operacion AND p.proveedor=trim(p_datos->>'proveedor') AND p.pedido=trim(p_datos->>'pedido');
  resultado:=jsonb_build_object('guardado',true,'anterior',anterior);
 WHEN 'configurar' THEN
  IF p_datos ? 'lista' THEN
   IF length(trim(coalesce(p_datos->>'responsable',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Registra el responsable principal'; END IF;
   UPDATE public.masiva_listas SET responsable=trim(p_datos->>'responsable') WHERE operacion_id=operacion AND lista=p_datos->>'lista';
   IF NOT FOUND THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  END IF;
  FOREACH v_actor_nombre IN ARRAY ARRAY['logo_cliente','logo_empresa'] LOOP
   IF p_datos ? v_actor_nombre AND (length(p_datos->>v_actor_nombre)>2000000 OR (p_datos->>v_actor_nombre<>'' AND p_datos->>v_actor_nombre !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/=\r\n]+$')) THEN RAISE EXCEPTION 'Usa un logo PNG o JPEG de máximo 1,5 MB'; END IF;
  END LOOP;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;
  UPDATE public.masiva_operaciones SET logo_cliente=coalesce(p_datos->>'logo_cliente',logo_cliente),logo_empresa=coalesce(p_datos->>'logo_empresa',logo_empresa),
  puntos_kit=coalesce((p_datos->>'puntos_kit')::integer,puntos_kit),puntos_prenda=coalesce((p_datos->>'puntos_prenda')::integer,puntos_prenda),
  penalizacion_error=coalesce((p_datos->>'penalizacion_error')::integer,penalizacion_error) WHERE id=operacion;
  resultado:=jsonb_build_object('guardado',true);
 WHEN 'documento' THEN
  IF coalesce(p_datos->>'tipo','') NOT IN('lista','rotulo') THEN RAISE EXCEPTION 'Tipo de documento inválido'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_listas WHERE operacion_id=operacion AND lista=p_datos->>'lista') THEN RAISE EXCEPTION 'Lista no encontrada'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista'
   AND kit_fila.caja_id IS NULL AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Asigna un empaque a todos los kits con prendas validadas antes de emitir documentos'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.masiva_kits kit_fila WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=p_datos->>'lista' AND kit_fila.caja_id IS NOT NULL
   AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0))
  THEN RAISE EXCEPTION 'Valida prendas y asígnalas a una caja antes de emitir documentos'; END IF;
  SELECT coalesce(max(version),0)+1 INTO version_documento FROM public.masiva_documentos WHERE operacion_id=operacion AND lista=p_datos->>'lista' AND tipo=p_datos->>'tipo';
  SELECT jsonb_build_object('formato_version',1,'operacion',to_jsonb(op),'lista',to_jsonb(l),'responsable',l.responsable,'fecha',ahora,'version',version_documento,
  'kits',coalesce((SELECT jsonb_agg(to_jsonb(kit_fila)||jsonb_build_object('caja',c.numero,'empacador',p.nombre,'articulos',
   (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.sku) FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id)) ORDER BY kit_fila.numero_persona)
   FROM public.masiva_kits kit_fila LEFT JOIN public.masiva_cajas c ON c.id=kit_fila.caja_id LEFT JOIN public.masiva_personal p ON p.id=kit_fila.empacador_id
   WHERE kit_fila.operacion_id=operacion AND kit_fila.lista=l.lista AND kit_fila.caja_id IS NOT NULL
    AND EXISTS(SELECT 1 FROM public.masiva_articulos a WHERE a.kit_id=kit_fila.id AND a.validado>0)),'[]'),
  'empaques',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.numero) FROM public.masiva_cajas c WHERE c.operacion_id=operacion AND c.lista=l.lista),'[]'))
  INTO snapshot FROM public.masiva_listas l WHERE l.operacion_id=operacion AND l.lista=p_datos->>'lista';
  INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);
 WHEN 'cerrar_operacion' THEN
  IF length(trim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Registra el motivo de cierre'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_asignaciones WHERE operacion_id=operacion AND estado IN('en_curso','pausado')) THEN RAISE EXCEPTION 'Finaliza los tiempos de empaque antes de cerrar'; END IF;
  IF EXISTS(SELECT 1 FROM public.masiva_importaciones WHERE operacion_id=operacion AND estado='cargando') THEN RAISE EXCEPTION 'Confirma o cancela las cargas pendientes antes de cerrar'; END IF;
  UPDATE public.masiva_operaciones SET estado='cerrada',cerrado=ahora,cerrado_por=actor,motivo_cierre=trim(p_datos->>'motivo') WHERE id=operacion;
  resultado:=jsonb_build_object('id',operacion,'estado','cerrada','sobrante',(SELECT coalesce(sum(recibido-validado),0) FROM public.masiva_inventario WHERE operacion_id=operacion));
 ELSE RAISE EXCEPTION 'Acción de Masiva no reconocida'; END CASE;
 IF p_accion<>'cargar_lote' THEN
  INSERT INTO public.masiva_auditoria(operacion_id,kit_id,accion,actor_id,actor_nombre,datos)
  VALUES(operacion,evento_kit,p_accion,actor,v_actor_nombre,
   jsonb_build_object('entrada',p_datos-'filas'-'logo_cliente'-'logo_empresa','resultado',resultado-'snapshot',
    'empacador_id',CASE WHEN p_accion='reportar_error' THEN k.empacador_id ELSE NULL END));
 END IF;
 IF req IS NOT NULL THEN INSERT INTO public.masiva_solicitudes(request_id,actor_id,accion,huella,respuesta) VALUES(req,actor,p_accion,huella,resultado); END IF;
 RETURN resultado;
END $$;

REVOKE ALL ON FUNCTION public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_consultar(uuid,text,text,integer,text),public.masiva_ejecutar(text,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';



-- Fuente revisada: 135_masiva_validador_empacador.sql
-- Conserva permisos, identidad autenticada, inventario y penalización MAL EMPAQUE.

SET LOCAL lock_timeout='10s';
DO $migration$
DECLARE definicion text; actual text; bloqueo text := $block$IF EXISTS(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios u ON u.numero_usuario=p.usuario_numero WHERE p.id=k.empacador_id AND u.auth_id=actor)
  THEN RAISE EXCEPTION 'El kit debe validarlo una persona distinta de quien lo empacó'; END IF;$block$;
BEGIN
 
 
 SELECT replace(pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure),chr(13),'') INTO definicion;
 IF position('masiva_135_roles_compatibles' IN definicion)>0 THEN RETURN; END IF;
 actual:=substring(definicion from 'IF EXISTS\(SELECT 1 FROM public.masiva_personal p JOIN public.usuarios[^;]+; END IF;');
 IF actual IS NULL OR regexp_replace(actual,'\s+',' ','g')<>regexp_replace(bloqueo,'\s+',' ','g') OR position('asignacion_tardia' IN definicion)=0
 THEN RAISE EXCEPTION 'Definición inesperada: se requiere la versión 134'; END IF;
 EXECUTE replace(definicion,actual,'/* masiva_135_roles_compatibles: el empacador también puede validar su kit. */');
END $migration$;


-- Fuente revisada: 136_masiva_catalogo_compartido.sql
-- No copia ni elimina catálogos. Contenedores antiguos conservan FK y snapshot.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF position('masiva_135_roles_compatibles' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 135'; END IF;
 IF to_regprocedure('public.admin_empaque_guardar_v92(uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Se requiere el catálogo compartido v92'; END IF;
END $$;
ALTER TABLE public.empaques ADD COLUMN IF NOT EXISTS peso_promedio_masiva_kg numeric;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.empaques'::regclass AND conname='empaques_promedio_masiva_valido') THEN
  ALTER TABLE public.empaques ADD CONSTRAINT empaques_promedio_masiva_valido CHECK(peso_promedio_masiva_kg IS NULL OR (peso_promedio_masiva_kg>0 AND peso_promedio_masiva_kg<=100000 AND peso_promedio_masiva_kg>=peso_neto_kg));
 END IF;
END $$;
ALTER TABLE public.masiva_cajas ALTER COLUMN empaque_id DROP NOT NULL;
ALTER TABLE public.masiva_cajas ADD COLUMN IF NOT EXISTS empaque_catalogo_id uuid REFERENCES public.empaques(id);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.masiva_cajas'::regclass AND conname='masiva_cajas_un_catalogo') THEN
  ALTER TABLE public.masiva_cajas ADD CONSTRAINT masiva_cajas_un_catalogo CHECK((empaque_id IS NULL)<>(empaque_catalogo_id IS NULL));
 END IF;
END $$;
CREATE OR REPLACE VIEW public.masiva_catalogo_empaques AS
 SELECT e.*,lower(e.categoria) AS tipo,e.largo_cm AS largo,e.ancho_cm AS ancho,e.alto_cm AS alto,
 e.peso_neto_kg AS peso_vacio,e.peso_promedio_masiva_kg AS peso_lleno,md5(to_jsonb(e)::text) AS version
 FROM public.empaques e;
REVOKE ALL ON public.masiva_catalogo_empaques FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_empaque_guardar_v92(p_id uuid,p_version text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; promedio numeric;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.empaques IN SHARE ROW EXCLUSIVE MODE;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object'
 OR p_datos->>'categoria' IS NULL OR p_datos->>'categoria' NOT IN ('CAJA','BOLSA')
 OR coalesce(length(trim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 150
 OR jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Datos del empaque invalidos.'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['largo_cm','ancho_cm','alto_cm','peso_neto_kg']) k
   WHERE jsonb_typeof(p_datos->k) IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Medidas y pesos deben ser numeros.'; END IF;
 IF p_datos ? 'peso_promedio_masiva_kg' AND p_datos->'peso_promedio_masiva_kg'<>'null'::jsonb THEN
  IF jsonb_typeof(p_datos->'peso_promedio_masiva_kg') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'El promedio de Masiva debe ser numérico'; END IF;
  promedio:=(p_datos->>'peso_promedio_masiva_kg')::numeric;
  IF promedio<=0 OR promedio>100000 OR promedio<(p_datos->>'peso_neto_kg')::numeric THEN RAISE EXCEPTION 'El promedio de Masiva debe ser mayor que cero e igual o mayor que la tara'; END IF;
 END IF;
 IF p_id IS NOT NULL THEN
   SELECT to_jsonb(e) INTO anterior FROM public.empaques e WHERE id=p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza la lista.'; END IF;
   UPDATE public.empaques SET nombre=trim(p_datos->>'nombre'),categoria=p_datos->>'categoria',
     largo_cm=(p_datos->>'largo_cm')::numeric,ancho_cm=(p_datos->>'ancho_cm')::numeric,alto_cm=(p_datos->>'alto_cm')::numeric,
     peso_promedio_masiva_kg=CASE WHEN p_datos ? 'peso_promedio_masiva_kg' THEN promedio ELSE peso_promedio_masiva_kg END,
     peso_neto_kg=(p_datos->>'peso_neto_kg')::numeric,peso_bruto_kg=NULL,activo=(p_datos->>'activo')::boolean
   WHERE id=p_id RETURNING to_jsonb(empaques.*) INTO nuevo;
 ELSE
   INSERT INTO public.empaques(nombre,categoria,largo_cm,ancho_cm,alto_cm,peso_neto_kg,peso_bruto_kg,activo,peso_promedio_masiva_kg)
   VALUES(trim(p_datos->>'nombre'),p_datos->>'categoria',(p_datos->>'largo_cm')::numeric,(p_datos->>'ancho_cm')::numeric,
     (p_datos->>'alto_cm')::numeric,(p_datos->>'peso_neto_kg')::numeric,NULL,(p_datos->>'activo')::boolean,promedio)
   RETURNING to_jsonb(empaques.*) INTO nuevo;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues)
 VALUES(auth.uid(),'empaques',(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

REVOKE ALL ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION pg_temp.masiva136_reemplazar(fuente text,patron text,nuevo text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE encontrado text;
BEGIN
 encontrado:=substring(fuente from patron);
 IF encontrado IS NULL THEN RAISE EXCEPTION 'Definición inesperada en integración del catálogo compartido'; END IF;
 RETURN replace(fuente,encontrado,nuevo);
END $$;
DO $migration$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.masiva_consultar(uuid,text,text,integer,text)'::regprocedure);
 IF position('masiva_catalogo_empaques' IN f)=0 THEN
 f:=pg_temp.masiva136_reemplazar(f,$pattern$FROM[[:space:]]+public\.masiva_empaques[[:space:]]+e[[:space:]]+WHERE[[:space:]]+e\.activo$pattern$,$new$FROM public.masiva_catalogo_empaques e WHERE e.activo$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$c\.numero[[:space:]]+AS[[:space:]]+caja,c\.empaque_id,c\.empaque_snapshot\->>'tipo'$pattern$,$new$c.numero AS caja,coalesce(c.empaque_catalogo_id,c.empaque_id) AS empaque_id,c.empaque_snapshot,c.empaque_snapshot->>'tipo'$new$);
 EXECUTE f; END IF;
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva136_catalogo_compartido' IN f)=0 THEN
 f:=pg_temp.masiva136_reemplazar(f,$pattern$asig[[:space:]]+public\.masiva_asignaciones;$pattern$,$new$v_catalogo_empaque jsonb; asig public.masiva_asignaciones;$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$WHEN[[:space:]]+'guardar_empaque'[[:space:]]+THEN[[:space:]]+INSERT[[:space:]]+INTO[[:space:]]+public\.masiva_empaques\(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por\)[[:space:]]+VALUES\(trim\(p_datos\->>'nombre'\),\(p_datos\->>'peso_vacio'\)::numeric,\(p_datos\->>'peso_lleno'\)::numeric,\(p_datos\->>'largo'\)::numeric,[[:space:]]+\(p_datos\->>'ancho'\)::numeric,\(p_datos\->>'alto'\)::numeric,coalesce\(p_datos\->>'tipo','caja'\),actor\)[[:space:]]+RETURNING[[:space:]]+id[[:space:]]+INTO[[:space:]]+id_nuevo;[[:space:]]+resultado:=jsonb_build_object\('id',id_nuevo\);$pattern$,$new$WHEN 'guardar_empaque' THEN RAISE EXCEPTION 'Usa el catálogo compartido de empaques de Administración o Configuración de Masiva';$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$SELECT[[:space:]]+\*[[:space:]]+INTO[[:space:]]+empaque[[:space:]]+FROM[[:space:]]+public\.masiva_empaques[[:space:]]+WHERE[[:space:]]+id=\(p_datos\->>'empaque_id'\)::uuid[[:space:]]+AND[[:space:]]+activo;[[:space:]]+IF[[:space:]]+empaque\.id[[:space:]]+IS[[:space:]]+NULL[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'Selecciona[[:space:]]+el[[:space:]]+tipo[[:space:]]+de[[:space:]]+empaque';[[:space:]]+END[[:space:]]+IF;[[:space:]]+SELECT[[:space:]]+\*[[:space:]]+INTO[[:space:]]+caja[[:space:]]+FROM[[:space:]]+public\.masiva_cajas[[:space:]]+WHERE[[:space:]]+operacion_id=operacion[[:space:]]+AND[[:space:]]+lista=k\.lista[[:space:]]+AND[[:space:]]+numero=n;[[:space:]]+IF[[:space:]]+k\.caja_id[[:space:]]+IS[[:space:]]+NOT[[:space:]]+NULL[[:space:]]+AND[[:space:]]+k\.caja_id[[:space:]]+IS[[:space:]]+DISTINCT[[:space:]]+FROM[[:space:]]+caja\.id[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'El[[:space:]]+kit[[:space:]]+ya[[:space:]]+pertenece[[:space:]]+a[[:space:]]+otro[[:space:]]+empaque;[[:space:]]+conserva[[:space:]]+allí[[:space:]]+sus[[:space:]]+prendas[[:space:]]+faltantes';[[:space:]]+END[[:space:]]+IF;[[:space:]]+IF[[:space:]]+caja\.id[[:space:]]+IS[[:space:]]+NOT[[:space:]]+NULL[[:space:]]+AND[[:space:]]+caja\.empaque_id<>empaque\.id[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'Ese[[:space:]]+número[[:space:]]+ya[[:space:]]+utiliza[[:space:]]+otro[[:space:]]+tipo[[:space:]]+de[[:space:]]+empaque';[[:space:]]+END[[:space:]]+IF;[[:space:]]+IF[[:space:]]+caja\.id[[:space:]]+IS[[:space:]]+NULL[[:space:]]+THEN[[:space:]]+INSERT[[:space:]]+INTO[[:space:]]+public\.masiva_cajas\(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por\)[[:space:]]+VALUES\(operacion,k\.lista,n,empaque\.id,to_jsonb\(empaque\),actor\)[[:space:]]+RETURNING[[:space:]]+\*[[:space:]]+INTO[[:space:]]+caja;[[:space:]]+END[[:space:]]+IF;$pattern$,$new$/* masiva136_catalogo_compartido: activos nuevos; históricos desde snapshot. */
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n FOR UPDATE;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL THEN
    IF coalesce(caja.empaque_catalogo_id,caja.empaque_id) IS DISTINCT FROM nullif(p_datos->>'empaque_id','')::uuid THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   ELSE
    SELECT to_jsonb(e) INTO v_catalogo_empaque FROM public.masiva_catalogo_empaques e WHERE e.id=nullif(p_datos->>'empaque_id','')::uuid AND e.activo FOR SHARE;
    IF v_catalogo_empaque IS NULL THEN RAISE EXCEPTION 'Selecciona un empaque activo del catálogo compartido'; END IF;
    IF v_catalogo_empaque->>'peso_lleno' IS NULL THEN RAISE EXCEPTION 'Configura el peso promedio de Masiva para este empaque antes de utilizarlo'; END IF;
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_catalogo_id,empaque_snapshot,creado_por)
    VALUES(operacion,k.lista,n,(v_catalogo_empaque->>'id')::uuid,v_catalogo_empaque,actor) RETURNING * INTO caja;
   END IF;
$new$);
 EXECUTE f; END IF;
END $migration$;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 137_masiva_logo_empresa_predeterminado.sql
-- entre operaciones; los snapshots de documentos ya emitidos no se tocan.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 
 
 IF position('masiva136_catalogo_compartido' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 136'; END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.masiva137_reemplazar(fuente text,patron text,nuevo text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE encontrado text;
BEGIN
 encontrado:=CASE WHEN position(patron IN fuente)>0 THEN patron END;
 IF encontrado IS NULL THEN RAISE EXCEPTION 'Definición inesperada en logo predeterminado de Masiva'; END IF;
 RETURN replace(fuente,encontrado,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva137_logo_empresa_predeterminado' IN f)=0 THEN
  f:=pg_temp.masiva137_reemplazar(
   f,
   $pattern$INSERT INTO public.masiva_operaciones(nombre,cliente,creado_por) VALUES(trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),actor) RETURNING id INTO operacion;$pattern$,
   $new$INSERT INTO public.masiva_operaciones(nombre,cliente,logo_empresa,creado_por)
  SELECT trim(p_datos->>'nombre'),trim(p_datos->>'cliente'),
   coalesce((SELECT o.logo_empresa FROM public.masiva_operaciones o WHERE o.logo_empresa<>'' ORDER BY o.creado DESC LIMIT 1),''),actor
  RETURNING id INTO operacion; -- masiva137_logo_empresa_predeterminado$new$);
  f:=pg_temp.masiva137_reemplazar(
   f,
   $pattern$SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;$pattern$,
   $new$/* masiva137_logo_empresa_predeterminado: conservar en todas las operaciones. */
  IF p_datos ? 'logo_empresa' AND coalesce(p_datos->>'logo_empresa','')<>'' THEN
   UPDATE public.masiva_operaciones SET logo_empresa=p_datos->>'logo_empresa';
  END IF;
  SELECT u.nombre INTO v_actor_nombre FROM public.usuarios u WHERE u.auth_id=actor;$new$);
  EXECUTE f;
 END IF;
END $migration$;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 138_masiva_logo_empresa_update_seguro.sql
-- cumpliendo la política del entorno, que exige una cláusula WHERE en UPDATE.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 
 
 IF position('masiva137_logo_empresa_predeterminado' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Aplica primero 137';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.masiva138_reemplazar(fuente text,patron text,nuevo text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
 IF position(patron IN fuente)=0 THEN
  RAISE EXCEPTION 'Definición inesperada al corregir actualización del logo';
 END IF;
 RETURN replace(fuente,patron,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva138_logo_update_where' IN f)=0 THEN
  f:=pg_temp.masiva138_reemplazar(
   f,
   $pattern$UPDATE public.masiva_operaciones SET logo_empresa=p_datos->>'logo_empresa';$pattern$,
   $new$UPDATE public.masiva_operaciones
   SET logo_empresa=p_datos->>'logo_empresa'
   WHERE logo_empresa IS DISTINCT FROM p_datos->>'logo_empresa'; -- masiva138_logo_update_where$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $$ DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva138_logo_update_where' IN f)=0
   OR position('WHERE logo_empresa IS DISTINCT FROM p_datos->>' IN f)=0 THEN
  RAISE EXCEPTION 'No quedó instalada la corrección del logo global';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';


-- Fuente revisada: 139_masiva_listas_empaque_masivas.sql
-- Aplica después de 138; cada documento continúa registrado por lista y versión.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 
 
 IF position('masiva138_logo_update_where' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Aplica primero 138';
 END IF;
END $$;

ALTER TABLE public.masiva_listas
 ADD COLUMN IF NOT EXISTS fecha_generado timestamptz;
UPDATE public.masiva_listas l
 SET fecha_generado=d.ultima_impresion
FROM (
 SELECT operacion_id,lista,max(creado) AS ultima_impresion
 FROM public.masiva_documentos WHERE tipo='lista' GROUP BY operacion_id,lista
) d
WHERE l.operacion_id=d.operacion_id AND l.lista=d.lista
 AND l.fecha_generado IS NULL;

CREATE OR REPLACE FUNCTION pg_temp.masiva139_reemplazar(fuente text,patron text,nuevo text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
 fuente:=replace(fuente,chr(13),'');
 patron:=replace(patron,chr(13),'');
 nuevo:=replace(nuevo,chr(13),'');
 IF position(patron IN fuente)=0 THEN
  RAISE EXCEPTION 'Definición inesperada en generación masiva de listas';
 END IF;
 RETURN replace(fuente,patron,nuevo);
END $$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)'::regprocedure);
 IF position('masiva139_fecha_generado' IN f)=0 THEN
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$campo_fecha NOT IN('ultima_validacion','fecha_carga','fecha_despacho','fecha_recepcion')$pattern$,
   $new$campo_fecha NOT IN('ultima_validacion','fecha_carga','fecha_despacho','fecha_recepcion','fecha_generado') /* masiva139_fecha_generado */$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$'kits_totales','kits_validados','kits_empacados','ultima_validacion','fecha_despacho','fecha_recepcion','transportadora'$pattern$,
   $new$'kits_totales','kits_validados','kits_empacados','ultima_validacion','fecha_despacho','fecha_recepcion','fecha_generado','transportadora'$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$'fecha_carga',fecha_carga,'fecha_despacho',NULL,'fecha_recepcion',NULL,'transportadora',NULL,'placa_guia',NULL,'novedades',NULL$pattern$,
   $new$'fecha_carga',fecha_carga,'fecha_despacho',NULL,'fecha_recepcion',NULL,'fecha_generado',l.fecha_generado,'transportadora',NULL,'placa_guia',NULL,'novedades',NULL$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $migration$
DECLARE f text;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva139_registrar_impresion' IN f)=0 THEN
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$IF op.estado<>'activa' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF;$pattern$,
   $new$IF op.estado<>'activa' AND p_accion<>'registrar_impresion' THEN RAISE EXCEPTION 'La operación está cerrada; conserva su historial sin admitir nuevos movimientos'; END IF; -- masiva139_registrar_impresion$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot);$pattern$,
   $new$INSERT INTO public.masiva_documentos(operacion_id,lista,tipo,version,snapshot,creado_por) VALUES(operacion,p_datos->>'lista',p_datos->>'tipo',version_documento,snapshot,actor) RETURNING id INTO id_nuevo;
  IF p_datos->>'tipo'='lista' THEN
   UPDATE public.masiva_listas SET fecha_generado=ahora
    WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  END IF;
  resultado:=jsonb_build_object('id',id_nuevo,'version',version_documento,'snapshot',snapshot); -- masiva139_registrar_impresion$new$);
  f:=pg_temp.masiva139_reemplazar(
   f,
   $pattern$ WHEN 'cerrar_operacion' THEN$pattern$,
   $new$ WHEN 'registrar_impresion' THEN
  IF NOT EXISTS(SELECT 1 FROM public.masiva_documentos d
   WHERE d.id=(p_datos->>'documento_id')::uuid AND d.operacion_id=operacion
    AND d.lista=p_datos->>'lista' AND d.tipo='lista') THEN
   RAISE EXCEPTION 'No se encontró la versión de la lista para reimprimir';
  END IF;
  UPDATE public.masiva_listas SET fecha_generado=ahora
   WHERE operacion_id=operacion AND lista=p_datos->>'lista';
  resultado:=jsonb_build_object('registrada',true,'fecha_generado',ahora);
 WHEN 'cerrar_operacion' THEN$new$);
  EXECUTE f;
 END IF;
END $migration$;

DO $$ DECLARE maestro text; ejecutar text;
BEGIN
 maestro:=pg_get_functiondef('public.masiva_maestro_consultar(uuid,text,text,jsonb,integer,integer,text,date,date,boolean)'::regprocedure);
 ejecutar:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva139_fecha_generado' IN maestro)=0
   OR position('l.fecha_generado' IN maestro)=0
   OR position('masiva139_registrar_impresion' IN ejecutar)=0
   OR position('UPDATE public.masiva_listas SET fecha_generado=ahora' IN ejecutar)=0 THEN
  RAISE EXCEPTION 'La fecha de impresión de listas no quedó configurada';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';


-- Fuente revisada: 140_masiva_recepcion_historial.sql
-- Aplica después de 139. Solo consulta movimientos existentes.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 
 
END $$;

CREATE INDEX IF NOT EXISTS masiva_movimientos_recepcion_historial
 ON public.masiva_movimientos(operacion_id,creado DESC,id DESC)
 WHERE tipo='recepcion';

CREATE OR REPLACE FUNCTION public.masiva_recepcion_historial(
 p_operacion uuid,p_buscar text DEFAULT '',p_pagina integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public SET statement_timeout='30s' AS $$
DECLARE v_total bigint; v_filas jsonb;
BEGIN
 IF NOT public.masiva_acceso() THEN
  RAISE EXCEPTION 'Acceso exclusivo de Masiva o Administrador' USING ERRCODE='42501';
 END IF;
 IF p_operacion IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.masiva_operaciones WHERE id=p_operacion) THEN
  RAISE EXCEPTION 'Operación no encontrada';
 END IF;
 IF p_pagina IS NULL OR p_pagina NOT BETWEEN 1 AND 10000
   OR length(coalesce(p_buscar,''))>200 THEN
  RAISE EXCEPTION 'Consulta inválida';
 END IF;
 p_buscar:=trim(coalesce(p_buscar,''));
 WITH datos AS (
  SELECT m.id,m.creado,m.cantidad,m.soporte,i.sku,i.descripcion,
   i.proveedor,i.pedido,coalesce(u.nombre,'Operario') AS operario
  FROM public.masiva_movimientos m
  JOIN public.masiva_inventario i ON i.id=m.inventario_id
  LEFT JOIN public.usuarios u ON u.auth_id=m.actor_id
  WHERE m.operacion_id=p_operacion AND m.tipo='recepcion'
   AND (p_buscar='' OR i.sku ILIKE '%'||p_buscar||'%'
    OR i.descripcion ILIKE '%'||p_buscar||'%'
    OR i.proveedor ILIKE '%'||p_buscar||'%'
    OR i.pedido ILIKE '%'||p_buscar||'%'
    OR m.soporte ILIKE '%'||p_buscar||'%')
 ), pagina AS (
  SELECT * FROM datos ORDER BY creado DESC,id DESC
  LIMIT 50 OFFSET (p_pagina-1)*50
 )
 SELECT (SELECT count(*) FROM datos),
  coalesce(jsonb_agg(to_jsonb(pagina) ORDER BY pagina.creado DESC,pagina.id DESC),'[]'::jsonb)
 INTO v_total,v_filas FROM pagina;
 RETURN jsonb_build_object('filas',v_filas,'total',v_total,'pagina',p_pagina);
END $$;

REVOKE ALL ON FUNCTION public.masiva_recepcion_historial(uuid,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.masiva_recepcion_historial(uuid,text,integer) TO authenticated;


-- Fuente revisada: 141_despacho_fecha_salida_libre.sql
-- Conserva el resto de la función, incluidos permisos, idempotencia y auditoría.

SET LOCAL lock_timeout='5s';

DO $$
DECLARE
 f text;
 limite text := 'IF p_fecha IS NOT NULL AND (p_fecha<''2000-01-01''::date OR p_fecha>(now() AT TIME ZONE ''America/Bogota'')::date) THEN RAISE EXCEPTION ''Fecha de salida invalida''; END IF;';
BEGIN
 
 

 SELECT pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure) INTO f;
 IF position('LE_DISPONIBLE_V120' IN f)=0 THEN
  RAISE EXCEPTION 'Requiere el ajuste de consecutivos de 120';
 END IF;
 IF position('DESPACHO_FECHA_LIBRE_V141' IN f)=0 THEN
  IF position(limite IN f)=0 THEN
   RAISE EXCEPTION 'No se encontró el límite de fechas esperado en admin_confirmar_le';
  END IF;
  f:=replace(f,limite,'-- DESPACHO_FECHA_LIBRE_V141: fecha administrativa libre.');
  EXECUTE f;
 END IF;
END $$;

DO $$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure) INTO f;
 IF position('DESPACHO_FECHA_LIBRE_V141' IN f)=0 OR position('Fecha de salida invalida' IN f)>0 THEN
  RAISE EXCEPTION 'La fecha libre de salida no quedó instalada';
 END IF;
END $$;

NOTIFY pgrst,'reload schema';


-- Fuente revisada: 142_despacho_borradores.sql
-- No modifica reservas, inventario, movimientos ni despachos confirmados.

SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';

DO $$ BEGIN
 
 
END $$;

CREATE TABLE IF NOT EXISTS public.despacho_borradores (
 usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 clave text NOT NULL CHECK (clave IN ('nuevo','inventario') OR clave ~ '^(correccion|inventario):[0-9a-fA-F-]{36}$'),
 datos jsonb NOT NULL CHECK (jsonb_typeof(datos)='object' AND octet_length(datos::text)<=2000000),
 version bigint NOT NULL DEFAULT 1 CHECK (version>0),
 actualizado timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(usuario_id,clave)
);
ALTER TABLE public.despacho_borradores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.despacho_borradores DROP CONSTRAINT IF EXISTS despacho_borradores_clave_check;
ALTER TABLE public.despacho_borradores ADD CONSTRAINT despacho_borradores_clave_check
 CHECK (clave IN ('nuevo','inventario') OR clave ~ '^(correccion|inventario):[0-9a-fA-F-]{36}$');
DROP POLICY IF EXISTS despacho_borradores_propios ON public.despacho_borradores;
CREATE POLICY despacho_borradores_propios ON public.despacho_borradores
 FOR SELECT TO authenticated USING (usuario_id=(SELECT auth.uid()));
REVOKE ALL ON public.despacho_borradores FROM anon,authenticated;
GRANT SELECT ON public.despacho_borradores TO authenticated;

CREATE OR REPLACE FUNCTION public.despacho_borrador_cargar(p_clave text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=pg_catalog,public AS $$
DECLARE v_resultado jsonb;
BEGIN
 IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 SELECT jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
 INTO v_resultado FROM public.despacho_borradores
 WHERE usuario_id=auth.uid() AND clave=p_clave;
 RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.despacho_borrador_guardar(
 p_clave text,p_datos jsonb,p_version bigint DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
DECLARE v_usuario uuid:=auth.uid(); v_resultado jsonb;
BEGIN
 IF v_usuario IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 IF p_version IS NULL OR p_version<0 THEN
  RAISE EXCEPTION 'Versión de borrador inválida';
 END IF;
 IF p_version=0 THEN
  INSERT INTO public.despacho_borradores(usuario_id,clave,datos)
  VALUES(v_usuario,p_clave,p_datos)
  ON CONFLICT(usuario_id,clave) DO NOTHING
  RETURNING jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
  INTO v_resultado;
 ELSE
  UPDATE public.despacho_borradores SET datos=p_datos,
   version=version+1,actualizado=clock_timestamp()
  WHERE usuario_id=v_usuario AND clave=p_clave AND version=p_version
  RETURNING jsonb_build_object('datos',datos,'version',version,'actualizado',actualizado)
  INTO v_resultado;
 END IF;
 IF v_resultado IS NULL THEN
  RAISE EXCEPTION 'El borrador cambió en otro equipo. Vuelve a cargarlo antes de guardar.'
   USING ERRCODE='40001';
 END IF;
 RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.despacho_borrador_eliminar(p_clave text,p_version bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF auth.uid() IS NULL THEN
  RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE='42501';
 END IF;
 DELETE FROM public.despacho_borradores
 WHERE usuario_id=auth.uid() AND clave=p_clave AND version=p_version;
 IF NOT FOUND AND EXISTS(SELECT 1 FROM public.despacho_borradores
   WHERE usuario_id=auth.uid() AND clave=p_clave) THEN
  RAISE EXCEPTION 'El borrador cambió en otro equipo. Vuelve a cargarlo antes de descartarlo.'
   USING ERRCODE='40001';
 END IF;
END $$;

REVOKE ALL ON FUNCTION public.despacho_borrador_cargar(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.despacho_borrador_guardar(text,jsonb,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.despacho_borrador_eliminar(text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_cargar(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_guardar(text,jsonb,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.despacho_borrador_eliminar(text,bigint) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Fuente revisada: 143_seguimiento_placas_quiromar.sql

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.seguimiento_placas_quiromar()
RETURNS TABLE(placa text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN
  RAISE EXCEPTION 'Sin acceso a seguimiento' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT v.placa FROM public.conductor_vehiculos v ORDER BY v.placa;
END $$;
REVOKE ALL ON FUNCTION public.seguimiento_placas_quiromar() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_placas_quiromar() TO authenticated;
NOTIFY pgrst, 'reload schema';

-- Ninguna fila ni columna original puede cambiar; incluye documentos emitidos y Auth.
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
 IF EXISTS(SELECT fila FROM previo_secuencias EXCEPT ALL SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public') THEN RAISE EXCEPTION 'Cambió un consecutivo: rollback'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
