-- ORBILOQ / Masiva. EXCLUSIVO DEV. No ejecutar en producción.
-- Aplicar después de 128. No importa las hojas de ejemplo ni modifica inventario de Bodega.
-- Importaciones por lotes con confirmación atómica; inventario recibido comienza en cero.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
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
COMMIT;
