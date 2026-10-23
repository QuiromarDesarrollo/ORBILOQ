-- SOLO LECTURA. Ejecutar en PRODUCCION: cxrflhgnxvomcvxzugda.
-- Compara las 12 OP de GI GROUP del archivo CARGUE 23-10-26.xlsx.
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '30s';
WITH esperadas(op,lineas_excel,unidades_excel) AS (
 VALUES ('25637',1,221),('25638',4,16),('25639',2,6),('25640',1,3),
 ('25641',5,32),('25642',2,18),('25643',5,19),('25644',3,14),
 ('25645',5,27),('25646',1,4),('25647',8,41),('25648',7,25)
), diagnostico AS (
 SELECT e.*,o.id AS orden_id,o.cliente AS cliente_guardado,o.oc_cabecera AS oc_guardada,
   im.nombre_archivo AS archivo_carga_original,
   coalesce(to_jsonb(im)->>'creado_en',to_jsonb(im)->>'fecha',to_jsonb(im)->>'created_at') AS fecha_carga_original,
   t.total AS lineas_bd,t.activas AS lineas_activas,t.eliminadas AS lineas_eliminadas,
   t.unidades AS unidades_activas,v.visibles AS lineas_en_vista,
   CASE WHEN o.id IS NULL THEN 'No existe la cabecera de la OP'
        WHEN t.total=0 THEN 'Existe la OP, pero no tiene tallas: el importador la omite y la tabla no puede mostrarla'
        WHEN t.activas=0 THEN 'Todas las tallas tienen eliminación lógica'
        WHEN upper(coalesce(o.cliente,'')) NOT LIKE '%GI GROUP%' THEN 'Existe con otro nombre de cliente: reimportar no actualiza el cliente'
        WHEN v.visibles=0 THEN 'Tiene tallas activas, pero no están en vista_kardex'
        WHEN t.activas<e.lineas_excel THEN 'Tiene menos tallas activas que el Excel; reimportar no completa las existentes'
        ELSE 'Hay filas disponibles: revisar filtros activos, sincronización y ambiente de la página'
   END AS diagnostico
 FROM esperadas e
 LEFT JOIN public.ordenes_produccion o ON o.numero_op=e.op
 LEFT JOIN public.importaciones im ON im.id=o.importacion_id
 CROSS JOIN LATERAL (
  SELECT count(*) AS total,
   count(*) FILTER(WHERE i.admin_eliminado_en IS NULL) AS activas,
   count(*) FILTER(WHERE i.admin_eliminado_en IS NOT NULL) AS eliminadas,
   coalesce(sum(i.cantidad_pedida) FILTER(WHERE i.admin_eliminado_en IS NULL),0) AS unidades
  FROM public.items_orden i WHERE i.orden_id=o.id
 ) t
 CROSS JOIN LATERAL (
  SELECT count(*) AS visibles FROM public.vista_kardex k
  JOIN public.items_orden i ON i.id=k.item_orden_id
  WHERE i.orden_id=o.id AND i.admin_eliminado_en IS NULL
 ) v
)
SELECT jsonb_build_object(
 'op_gi_group',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.op) FROM diagnostico d),
 'cargas_del_archivo',(SELECT coalesce(jsonb_agg(jsonb_build_object(
   'id',im.id,'archivo',im.nombre_archivo,'ops_creadas',im.ops_creadas,
   'ops_omitidas',im.ops_omitidas,'estado',im.estado,
   'fecha',coalesce(to_jsonb(im)->>'creado_en',to_jsonb(im)->>'fecha',to_jsonb(im)->>'created_at'))),'[]'::jsonb)
  FROM public.importaciones im WHERE im.nombre_archivo ILIKE '%CARGUE%23%10%26%')
) AS resultado_diagnostico;
COMMIT;
