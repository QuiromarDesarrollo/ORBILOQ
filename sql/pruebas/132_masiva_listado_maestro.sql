-- ORBILOQ / Listado maestro y base de Masiva. EXCLUSIVO DEV.
-- Después de 131. Conserva la fuente por artículo y añade consultas del maestro.
-- La carga inicial solo escribe la nueva tabla; no cambia registros operativos existentes.
-- Despacho y entrega continúan aplazados; sus columnas no inventan información.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001')
 THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
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
COMMIT;
