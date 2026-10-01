-- SOLO PRUEBAS. Requiere 055, 057 y 058; no ejecutar en produccion.
-- Importacion atomica y auditada. No elimina items, lotes ni movimientos.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN
    RAISE EXCEPTION 'Archivo exclusivo de PRUEBAS.';
  END IF;
  IF to_regprocedure('public.admin_eliminar_linea(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Aplicar primero 055, 057 y 058 en PRUEBAS.';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_importaciones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid NOT NULL, fecha timestamptz NOT NULL DEFAULT now(),
  vista text NOT NULL, motivo text NOT NULL, version_origen text NOT NULL,
  archivo jsonb NOT NULL, resumen jsonb NOT NULL
);
ALTER TABLE public.admin_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_importaciones FROM anon, authenticated;
GRANT SELECT ON public.admin_importaciones TO authenticated;
DROP POLICY IF EXISTS admin_lectura ON public.admin_importaciones;
CREATE POLICY admin_lectura ON public.admin_importaciones FOR SELECT TO authenticated USING (public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.admin_version_kardex() RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
  SELECT md5(jsonb_build_array(
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.items_orden t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ordenes_produccion t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.movimientos t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.lote_items t),
    (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.ubicaciones t)
  )::text);
$$;
REVOKE ALL ON FUNCTION public.admin_version_kardex() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_exportar_kardex() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public SET lock_timeout = '5s' AS $$
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  RETURN jsonb_build_object('version',public.admin_version_kardex(),'filas',coalesce((
    SELECT jsonb_agg(to_jsonb(k) || jsonb_build_object('fecha_ultima_entrega',
      (k.fecha_ultima_entrega AT TIME ZONE 'America/Bogota')::date) ORDER BY numero_op,codigo,talla,item_orden_id)
    FROM public.vista_kardex k WHERE admin_eliminado_en IS NULL),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.admin_exportar_kardex() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_exportar_kardex() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_importar_kardex(
  p_vista text, p_version text, p_filas jsonb, p_motivo text, p_confirmar boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
SET lock_timeout = '5s' SET statement_timeout = '60s' AS $$
DECLARE
  f jsonb; a jsonb; d jsonb; cambios jsonb := '[]'; resultado jsonb;
  io public.items_orden%rowtype; actor public.usuarios%rowtype;
  ident uuid; orden uuid; ubic uuid; audit uuid; lote_importacion uuid := gen_random_uuid();
  q integer; pr integer; re integer; de integer; nc integer; dp integer; dr integer; dd integer; dn integer;
  numero_fila integer := 1; nuevas integer := 0; modificadas integer := 0; ausentes integer;
  key text; fecha date; stock bigint; ids uuid[] := '{}'; nueva boolean;
BEGIN
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE = '42501'; END IF;
  IF p_vista IS NULL OR p_vista NOT IN ('produccion','logistica') OR p_confirmar IS NULL THEN RAISE EXCEPTION 'Vista o confirmacion invalida.'; END IF;
  IF coalesce(length(trim(p_motivo)),0)=0 THEN RAISE EXCEPTION 'Indica el motivo de la importacion.'; END IF;
  IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo invalido.'; END IF;
  IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 5000 THEN RAISE EXCEPTION 'Se requieren entre 1 y 5000 filas. No se admite un archivo vacio.'; END IF;
  LOCK TABLE public.usuarios IN SHARE MODE;
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes,
    public.lote_items, public.movimientos, public.admin_correcciones, public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
  IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;
  IF p_version IS DISTINCT FROM public.admin_version_kardex() THEN
    RAISE EXCEPTION 'Los datos cambiaron desde la exportacion. Exporta nuevamente y revisa tus cambios.';
  END IF;
  SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol='admin';

  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x GROUP BY x->>'numero_op',x->>'codigo',x->>'talla' HAVING count(*)>1) THEN
    RAISE EXCEPTION 'OP, codigo y talla duplicados en el archivo.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x GROUP BY x->>'numero_op'
      HAVING count(DISTINCT jsonb_build_array(x->'cliente',x->(CASE p_vista WHEN 'produccion' THEN 'fecha_esperada_produccion' ELSE 'fecha_esperada_logistica' END)))>1) THEN
    RAISE EXCEPTION 'Todas las filas de una OP deben tener el mismo cliente y fecha esperada.';
  END IF;
  -- La subtransaccion ejecuta las mismas validaciones y calculos en vista previa.
  -- Al finalizar la vista previa se revierte TODO; solo retorna el resumen.
  BEGIN
    FOR f IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
      numero_fila := numero_fila+1;
      IF jsonb_typeof(f) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Fila % invalida.',numero_fila; END IF;
      IF EXISTS (SELECT 1 FROM jsonb_object_keys(f) k WHERE NOT k=ANY(
        ARRAY['item_orden_id','numero_op','descripcion','codigo','talla','cliente','oc','observacion_op',
        'ubicacion_ajuste','cantidad_pedida','producido','pendiente_reproceso','fecha_ultima_entrega'] ||
        CASE p_vista WHEN 'produccion' THEN ARRAY['fecha_esperada_produccion'] ELSE ARRAY['recibido','despachado','fecha_esperada_logistica'] END)) THEN
        RAISE EXCEPTION 'Fila %: columna no permitida para esta vista.',numero_fila;
      END IF;
      IF jsonb_typeof(f->'item_orden_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'Fila %: falta ID FILA (dejar texto vacio solo para filas nuevas).',numero_fila; END IF;
      FOREACH key IN ARRAY ARRAY['numero_op','descripcion','codigo','talla','cliente','oc','observacion_op','ubicacion_ajuste'] LOOP
        IF jsonb_typeof(f->key) IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'Fila %: falta texto en %.',numero_fila,key; END IF;
        IF key IN ('numero_op','descripcion','codigo','talla','cliente') AND length(trim(f->>key))=0 THEN RAISE EXCEPTION 'Fila %: % obligatorio.',numero_fila,key; END IF;
      END LOOP;
      FOREACH key IN ARRAY ARRAY['cantidad_pedida','producido','pendiente_reproceso'] || CASE p_vista WHEN 'logistica' THEN ARRAY['recibido','despachado'] ELSE ARRAY[]::text[] END LOOP
        IF jsonb_typeof(f->key) IS DISTINCT FROM 'number' OR (f->>key) !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Fila %: % debe ser entero no negativo.',numero_fila,key; END IF;
      END LOOP;
      FOREACH key IN ARRAY ARRAY['fecha_ultima_entrega', CASE p_vista WHEN 'produccion' THEN 'fecha_esperada_produccion' ELSE 'fecha_esperada_logistica' END] LOOP
        IF NOT f ? key THEN RAISE EXCEPTION 'Fila %: falta %.',numero_fila,key; END IF;
        IF f->key <> 'null'::jsonb THEN
          IF jsonb_typeof(f->key)<>'string' OR (f->>key) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Fila %: fecha invalida.',numero_fila; END IF;
          fecha := (f->>key)::date;
        END IF;
      END LOOP;
      ident := nullif(f->>'item_orden_id','')::uuid;
      nueva := ident IS NULL;
      IF nueva THEN
        SELECT id INTO orden FROM public.ordenes_produccion WHERE numero_op=f->>'numero_op';
        IF orden IS NULL THEN
          INSERT INTO public.ordenes_produccion(numero_op,cliente) VALUES(f->>'numero_op',f->>'cliente') RETURNING id INTO orden;
        END IF;
        IF EXISTS (SELECT 1 FROM public.items_orden WHERE orden_id=orden AND codigo=f->>'codigo' AND talla=f->>'talla') THEN
          RAISE EXCEPTION 'Fila %: el producto ya existe. Conserva su ID original; no crees un duplicado.',numero_fila;
        END IF;
        INSERT INTO public.items_orden(orden_id,codigo,descripcion,talla,cantidad_pedida,oc,observacion)
        VALUES(orden,f->>'codigo',f->>'descripcion',f->>'talla',(f->>'cantidad_pedida')::integer,f->>'oc',f->>'observacion_op') RETURNING id INTO ident;
      END IF;
      SELECT * INTO io FROM public.items_orden WHERE id=ident;
      IF NOT FOUND OR io.admin_eliminado_en IS NOT NULL THEN RAISE EXCEPTION 'Fila %: ID inexistente o archivado.',numero_fila; END IF;
      IF ident=ANY(ids) THEN RAISE EXCEPTION 'ID repetido en fila %.',numero_fila; END IF;
      ids := array_append(ids,ident);
      orden := io.orden_id;
      -- No dividir accidentalmente una OP al modificar su numero en una sola talla.
      IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_filas) x JOIN public.items_orden i ON i.id=nullif(x->>'item_orden_id','')::uuid
        WHERE i.orden_id=orden AND x->>'numero_op' IS DISTINCT FROM f->>'numero_op') THEN
        RAISE EXCEPTION 'Todas las tallas de la misma OP deben conservar el mismo numero de OP.';
      END IF;
      SELECT to_jsonb(k) || jsonb_build_object('fecha_ultima_entrega',(k.fecha_ultima_entrega AT TIME ZONE 'America/Bogota')::date) INTO a
        FROM public.vista_kardex k WHERE item_orden_id=ident;
      q := (f->>'cantidad_pedida')::integer; pr := (f->>'producido')::integer; nc := (f->>'pendiente_reproceso')::integer;
      re := CASE p_vista WHEN 'logistica' THEN (f->>'recibido')::integer ELSE (a->>'recibido')::integer END;
      de := CASE p_vista WHEN 'logistica' THEN (f->>'despachado')::integer ELSE (a->>'despachado')::integer END;
      IF q<=0 OR pr>q OR de>q OR de>re OR re<0 OR de<0 THEN RAISE EXCEPTION 'Fila %: cantidades incompatibles (entregado/despachado no puede superar pedido; despacho no puede superar recibido).',numero_fila; END IF;
      dn := nc-(a->>'pendiente_reproceso')::integer;
      dp := pr-(a->>'producido')::integer+dn;
      dr := re-(a->>'recibido')::integer+dn;
      dd := de-(a->>'despachado')::integer;
      ubic := NULL;
      IF dn<>0 OR dr<>0 OR dd<>0 THEN
        SELECT id INTO ubic FROM public.ubicaciones WHERE codigo=f->>'ubicacion_ajuste' AND activa;
        IF ubic IS NULL THEN RAISE EXCEPTION 'Fila %: indica una UBICACION DEL AJUSTE activa para corregir recibido, despachado o no conforme.',numero_fila; END IF;
        SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
          INTO stock FROM public.movimientos WHERE item_orden_id=ident AND ubicacion_id=ubic;
        IF stock+dr-dd-dn<0 THEN RAISE EXCEPTION 'Fila %: el ajuste dejaria stock negativo en el estante. Distribuye previamente la correccion por ubicaciones.',numero_fila; END IF;
      END IF;
      d := a || (f-'ubicacion_ajuste'-'item_orden_id');
      IF nueva OR a IS DISTINCT FROM d THEN
        IF nueva THEN nuevas:=nuevas+1; ELSE modificadas:=modificadas+1; END IF;
        INSERT INTO public.admin_correcciones(item_id,orden_id,actor_id,actor,campo,anterior,nuevo,motivo,antes,despues,ubicacion_id)
        VALUES(ident,orden,auth.uid(),actor.nombre,'importacion_excel',CASE WHEN nueva THEN 'null'::jsonb ELSE a END,d,
          trim(p_motivo)||' [importacion '||lote_importacion||']',CASE WHEN nueva THEN '{}'::jsonb ELSE a END,d,ubic) RETURNING id INTO audit;
        INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,nota,admin_correccion_id)
        SELECT tipo,ident,cantidad,CASE WHEN tipo<>'entrega_produccion' THEN ubic END,actor.id,'Importacion Excel: '||trim(p_motivo),audit
          FROM (VALUES ('entrega_produccion',dp),('recepcion',dr),('despacho',dd),('devolucion_produccion',dn)) ajustes(tipo,cantidad) WHERE cantidad<>0;
        UPDATE public.items_orden SET codigo=f->>'codigo',descripcion=f->>'descripcion',talla=f->>'talla',
          oc=f->>'oc',observacion=f->>'observacion_op',cantidad_pedida=q,
          admin_fecha_entrega=CASE WHEN nueva OR a->'fecha_ultima_entrega' IS DISTINCT FROM f->'fecha_ultima_entrega' THEN (f->>'fecha_ultima_entrega')::date ELSE admin_fecha_entrega END,
          admin_fecha_entrega_activa=admin_fecha_entrega_activa OR nueva OR a->'fecha_ultima_entrega' IS DISTINCT FROM f->'fecha_ultima_entrega'
          WHERE id=ident;
        UPDATE public.ordenes_produccion SET numero_op=f->>'numero_op',cliente=f->>'cliente',
          fecha_esperada_produccion=CASE p_vista WHEN 'produccion' THEN (f->>'fecha_esperada_produccion')::date ELSE fecha_esperada_produccion END,
          fecha_esperada_logistica=CASE p_vista WHEN 'logistica' THEN (f->>'fecha_esperada_logistica')::date ELSE fecha_esperada_logistica END WHERE id=orden;
        cambios := cambios || jsonb_build_array(jsonb_build_object('fila',numero_fila,'op',f->>'numero_op','codigo',f->>'codigo','talla',f->>'talla','nueva',nueva,'antes',CASE WHEN nueva THEN '{}'::jsonb ELSE a END,'despues',d));
      END IF;
    END LOOP;
    SELECT count(*) INTO ausentes FROM public.items_orden WHERE admin_eliminado_en IS NULL AND NOT id=ANY(ids);
    IF ausentes>0 THEN RAISE EXCEPTION 'Faltan % filas activas en el archivo. Exporta toda la tabla antes de importar.',ausentes; END IF;
    resultado := jsonb_build_object('nuevas',nuevas,'modificadas',modificadas,'total',jsonb_array_length(p_filas),'cambios',cambios,'guardado',p_confirmar);
    IF NOT p_confirmar THEN RAISE SQLSTATE 'P0590'; END IF;
    INSERT INTO public.admin_importaciones(id,actor_id,vista,motivo,version_origen,archivo,resumen)
      VALUES(lote_importacion,auth.uid(),p_vista,trim(p_motivo),p_version,p_filas,resultado);
  EXCEPTION WHEN SQLSTATE 'P0590' THEN NULL;
  END;
  RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_importar_kardex(text,text,jsonb,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_importar_kardex(text,text,jsonb,text,boolean) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
