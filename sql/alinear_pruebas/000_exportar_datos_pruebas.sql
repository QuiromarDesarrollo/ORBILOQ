/* SOLO LECTURA. Ejecutar en PRUEBAS antes de 002 y guardar el resultado CSV
   FUERA del repositorio: respaldo_datos_pruebas_20261005.csv.
   Exporta las 22 tablas public originales. Contiene datos privados: no subir a GitHub.
   Conservar también estructura_pruebas_actual.csv para reconstruir el esquema original.
   No es un respaldo de Auth ni de los archivos fisicos de Storage; 002 no los modifica.
   Se obtiene una sola instantanea para todas las tablas. Debe devolver 22 filas.
*/
WITH respaldo AS (
SELECT 'public.admin_catalogos_historial' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.admin_catalogos_historial t
UNION ALL
SELECT 'public.admin_correcciones' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.admin_correcciones t
UNION ALL
SELECT 'public.admin_importaciones' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.admin_importaciones t
UNION ALL
SELECT 'public.causales_devolucion' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.causales_devolucion t
UNION ALL
SELECT 'public.despachos_oc' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.despachos_oc t
UNION ALL
SELECT 'public.devoluciones_produccion' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.devoluciones_produccion t
UNION ALL
SELECT 'public.documentos' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.documentos t
UNION ALL
SELECT 'public.importaciones' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.importaciones t
UNION ALL
SELECT 'public.items_orden' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.items_orden t
UNION ALL
SELECT 'public.liberaciones_aliados' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.liberaciones_aliados t
UNION ALL
SELECT 'public.liberaciones_no_conforme' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.liberaciones_no_conforme t
UNION ALL
SELECT 'public.lote_items' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.lote_items t
UNION ALL
SELECT 'public.lotes' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.lotes t
UNION ALL
SELECT 'public.movimientos' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.movimientos t
UNION ALL
SELECT 'public.no_conformes_aliados' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.no_conformes_aliados t
UNION ALL
SELECT 'public.ordenes_produccion' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.ordenes_produccion t
UNION ALL
SELECT 'public.personal_aliados' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.personal_aliados t
UNION ALL
SELECT 'public.personal_logistica' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.personal_logistica t
UNION ALL
SELECT 'public.personal_produccion' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.personal_produccion t
UNION ALL
SELECT 'public.sobrantes_bodega' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.sobrantes_bodega t
UNION ALL
SELECT 'public.ubicaciones' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.ubicaciones t
UNION ALL
SELECT 'public.usuarios' AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM public.usuarios t
)
SELECT tabla,cantidad_filas,filas_json,statement_timestamp() AS fecha_exportacion,
 count(*) OVER () AS total_tablas FROM respaldo ORDER BY tabla;
