-- ORBILOQ / Recepción Masiva por orden de compra. EXCLUSIVO DEV.
-- Aplicar después de 129. Conserva inventario, movimientos, auditoría y documentos.
-- No importa recepciones históricas, fechas ni novedades del Excel de ejemplo.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
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
COMMIT;
