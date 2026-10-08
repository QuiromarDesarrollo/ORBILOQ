/*
 ORBILOQ — alineacion de PRUEBAS con PRODUCCION, 2026-10-05.
 Ejecutar COMPLETO solamente en PRUEBAS (igfuafcekcpugpmsoqbe).
 Exportar todas las filas como diagnostico_alineacion_pruebas.csv.
 SOLO LECTURA: un SELECT. No modifica tablas, cuentas, permisos ni archivos.
 No consulta contrasenas, hashes ni tokens de Auth.
 Este informe no es una migracion ni un respaldo.
 Se basa en estructura_pruebas_actual.csv del 2026-10-05.
*/
WITH
usuarios_por_nombre AS (
  SELECT nombre, count(*) AS coincidencias FROM public.usuarios GROUP BY nombre
),
importaciones_por_ruta AS (
  SELECT storage_path, count(*) AS coincidencias
  FROM public.importaciones
  WHERE storage_path IS NOT NULL AND btrim(storage_path) <> ''
  GROUP BY storage_path
),
hallazgos AS (
  SELECT '01_conteos'::text AS seccion, 'tablas_a_adaptar'::text AS comprobacion,
    jsonb_build_object(
      'usuarios', (SELECT count(*) FROM public.usuarios),
      'documentos', (SELECT count(*) FROM public.documentos),
      'importaciones', (SELECT count(*) FROM public.importaciones),
      'items_orden', (SELECT count(*) FROM public.items_orden),
      'ordenes_produccion', (SELECT count(*) FROM public.ordenes_produccion),
      'movimientos', (SELECT count(*) FROM public.movimientos),
      'no_conformes_aliados', (SELECT count(*) FROM public.no_conformes_aliados)
    ) AS detalle
  UNION ALL
  SELECT '02_restricciones', 'cantidades', jsonb_build_object(
    'items_cantidad_no_positiva', (SELECT count(*) FROM public.items_orden WHERE cantidad_pedida <= 0),
    'items_cantidad_nula', (SELECT count(*) FROM public.items_orden WHERE cantidad_pedida IS NULL),
    'aliados_cantidad_no_positiva', (SELECT count(*) FROM public.no_conformes_aliados WHERE cantidad_solicitada <= 0),
    'aliados_cantidad_nula', (SELECT count(*) FROM public.no_conformes_aliados WHERE cantidad_solicitada IS NULL)
  )
  UNION ALL
  SELECT '02_restricciones', 'usuarios', jsonb_build_object(
    'grupos_auth_id_duplicado', (SELECT count(*) FROM (
      SELECT auth_id FROM public.usuarios WHERE auth_id IS NOT NULL GROUP BY auth_id HAVING count(*) > 1
    ) x),
    'grupos_email_duplicado', (SELECT count(*) FROM (
      SELECT email FROM public.usuarios WHERE email IS NOT NULL GROUP BY email HAVING count(*) > 1
    ) x),
    'grupos_nombre_rol_duplicado', (SELECT count(*) FROM (
      SELECT nombre, rol FROM public.usuarios WHERE nombre IS NOT NULL AND rol IS NOT NULL
      GROUP BY nombre, rol HAVING count(*) > 1
    ) x),
    'referencias_auth_inexistentes', (SELECT count(*) FROM public.usuarios u
      WHERE u.auth_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.id = u.auth_id))
  )
  UNION ALL
  SELECT '03_importaciones', 'conservar_autoria_y_fechas', jsonb_build_object(
    'fecha_nula', (SELECT count(*) FROM public.importaciones WHERE creado_en IS NULL),
    'sin_nombre_autor', (SELECT count(*) FROM public.importaciones WHERE coalesce(btrim(usuario_nombre), '') = ''),
    'autor_coincide_exactamente_un_usuario', (SELECT count(*) FROM public.importaciones i
      JOIN usuarios_por_nombre u ON u.nombre = i.usuario_nombre WHERE u.coincidencias = 1),
    'autor_ambiguo', (SELECT count(*) FROM public.importaciones i
      JOIN usuarios_por_nombre u ON u.nombre = i.usuario_nombre WHERE u.coincidencias > 1),
    'autor_no_coincide', (SELECT count(*) FROM public.importaciones i
      WHERE coalesce(btrim(i.usuario_nombre), '') <> ''
      AND NOT EXISTS (SELECT 1 FROM usuarios_por_nombre u WHERE u.nombre = i.usuario_nombre)),
    'nota', 'Coincidir por nombre no prueba identidad. No se asignara un usuario sin revisar la evidencia. Las fechas y nombres originales deben conservarse.'
  )
  UNION ALL
  SELECT '04_documentos', 'posibles_vinculos_sin_asignar', jsonb_build_object(
    'misma_ruta_una_importacion', (SELECT count(*) FROM public.documentos d
      JOIN importaciones_por_ruta i ON i.storage_path = d.storage_path WHERE i.coincidencias = 1),
    'misma_ruta_varias_importaciones', (SELECT count(*) FROM public.documentos d
      JOIN importaciones_por_ruta i ON i.storage_path = d.storage_path WHERE i.coincidencias > 1),
    'sin_importacion_por_ruta', (SELECT count(*) FROM public.documentos d
      WHERE NOT EXISTS (SELECT 1 FROM importaciones_por_ruta i WHERE i.storage_path = d.storage_path)),
    'fecha_nula', (SELECT count(*) FROM public.documentos WHERE creado_en IS NULL),
    'nota', 'Produccion exige entidad_tipo, entidad_id y tipo_documento. No se inventaran esos valores ni se borraran archivos para satisfacer la restriccion.'
  )
  UNION ALL
  SELECT '05_fechas_movimientos', 'creado_en_por_incorporar', jsonb_build_object(
    'total', (SELECT count(*) FROM public.movimientos),
    'fecha_nula', (SELECT count(*) FROM public.movimientos WHERE fecha IS NULL),
    'nota', 'fecha es la fecha del movimiento; creado_en no existe en pruebas. Evitar presentar la fecha de migracion como fecha historica de creacion.'
  )
)
SELECT seccion, comprobacion, detalle::text AS detalle_json,
  count(*) OVER () AS total_filas_exportacion
FROM hallazgos ORDER BY seccion, comprobacion;
