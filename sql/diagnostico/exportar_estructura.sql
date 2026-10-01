/*
ORBILOQ - Inventario de estructura para comparar PRUEBAS y PRODUCCION

USO
1. Abrir SQL Editor en el proyecto Supabase de PRUEBAS.
2. Pegar y ejecutar TODO este archivo. Exportar el resultado completo como
   CSV: estructura_pruebas.csv (conservar la columna detalle_json completa).
3. Repetir en el proyecto de PRODUCCION y guardar estructura_produccion.csv.
4. Compartir ambos CSV. No ejecutar el CSV como SQL: es un informe.

La consulta es un unico SELECT de metadatos. No escribe, no ejecuta las RPC,
no lee registros de negocio ni auth.users, no avanza secuencias y no cambia
permisos. Las definiciones SQL aparecen como TEXTO dentro del resultado.
Si alguna funcion contiene credenciales escritas en su codigo, ocultarlas
en el CSV antes de compartirlo; conservar la estructura y la firma.

ALCANCE
- Por defecto inspecciona public. Si hay esquemas propios del ERP u otra
  logica de negocio, agregarlos al ARRAY en configuracion, por ejemplo:
  ARRAY['public', 'erp']::text[]. Usar la misma lista en ambos entornos.
- La seccion 01 muestra los otros esquemas disponibles para identificarlos.
- Incluye triggers de otros esquemas que llaman funciones del alcance.
- Incluye las funciones individuales con sus firmas, incluidas sobrecargas.
- Excluye cuerpos de funciones provistas por extensiones; lista las
  extensiones y sus versiones por separado.
- No extrae configuracion del Dashboard, secretos, Storage, Edge Functions,
  tareas externas del ERP ni datos. No es un respaldo ni un script de
  reconstruccion de la base. Los conteos de filas son SOLO estimaciones.
- Cada fila corresponde a una seccion; total_filas_exportacion permite
  verificar que el resultado no se haya cortado al exportar.

CRITERIOS PARA EL PROXIMO DESPLIEGUE (solicitados por el propietario)
- master se usa para pruebas; verificar la rama desplegada antes de publicar.
- Preparar y revisar conjuntamente los cambios Flutter y SQL de produccion.
- Prioridad: conservar TODOS los datos que existan al momento del despliegue.
- Nunca reemplazar produccion con la base de pruebas ni aplicar un reset.
- Comparar primero ambos informes: no asumir que los esquemas son iguales.
- Preparar migraciones incrementales y compatibles con las integraciones ERP.
- Antes del despliegue: respaldo recuperable verificado, prueba en DEV,
  validaciones de integridad y plan de recuperacion que contemple las nuevas
  operaciones registradas despues del respaldo. Este informe NO sustituye eso.
- No eliminar sobrecargas RPC automaticamente: revisar dependencias, clientes
  y firmas antes de decidir una migracion y su orden con el frontend.

Referencia de las funciones de introspeccion:
https://www.postgresql.org/docs/current/functions-info.html
*/

WITH
configuracion AS (
  SELECT ARRAY['public']::text[] AS esquemas
),
esquemas AS (
  SELECT n.* FROM pg_catalog.pg_namespace n, configuracion cfg
  WHERE n.nspname = ANY(cfg.esquemas)
),
relaciones AS (
  SELECT c.*, n.nspname
  FROM pg_catalog.pg_class c
  JOIN esquemas n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
),
rutinas AS (
  SELECT p.*, n.nspname
  FROM pg_catalog.pg_proc p
  JOIN esquemas n ON n.oid = p.pronamespace
  WHERE p.prokind IN ('f', 'p', 'w')
    AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_depend d
      WHERE d.classid = 'pg_catalog.pg_proc'::regclass
        AND d.objid = p.oid AND d.deptype = 'e'
    )
),
objetos AS (
  SELECT '00_contexto'::text AS seccion, 'contexto'::text AS objeto,
    jsonb_build_object(
      'formato', 'orbiloq_estructura_v1',
      'fecha_extraccion', statement_timestamp(),
      'base', current_database(),
      'version_postgresql', current_setting('server_version'),
      'usuario_consulta', current_user,
      'esquemas_solicitados', cfg.esquemas,
      'esquemas_encontrados', (SELECT jsonb_agg(nspname ORDER BY nspname) FROM esquemas),
      'zona_horaria', current_setting('TimeZone'),
      'search_path_consulta', current_setting('search_path'),
      'nota', 'Identificar entorno por el nombre del CSV; current_database no identifica el proyecto Supabase.'
    ) AS detalle
  FROM configuracion cfg

  UNION ALL
  SELECT '01_esquemas_disponibles', n.nspname,
    jsonb_build_object('esquema', n.nspname,
      'propietario', pg_get_userbyid(n.nspowner),
      'acl', n.nspacl::text,
      'incluido', n.nspname = ANY(cfg.esquemas))
  FROM pg_catalog.pg_namespace n CROSS JOIN configuracion cfg
  WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'

  UNION ALL
  SELECT '02_relaciones', format('%I.%I', c.nspname, c.relname),
    jsonb_build_object('esquema', c.nspname, 'nombre', c.relname,
      'tipo', c.relkind, 'propietario', pg_get_userbyid(c.relowner),
      'rls_habilitado', c.relrowsecurity, 'rls_forzado', c.relforcerowsecurity,
      'replica_identity', c.relreplident, 'persistencia', c.relpersistence,
      'es_particion', c.relispartition,
      'limite_particion', pg_get_expr(c.relpartbound, c.oid),
      'clave_particion', CASE WHEN c.relkind = 'p' THEN pg_get_partkeydef(c.oid) END,
      'opciones', c.reloptions, 'acl', c.relacl::text,
      'filas_estimadas_no_exactas', c.reltuples,
      'comentario', obj_description(c.oid, 'pg_class'))
  FROM relaciones c

  UNION ALL
  SELECT '03_columnas', format('%I.%I.%I', c.nspname, c.relname, a.attname),
    jsonb_build_object('esquema', c.nspname, 'tabla', c.relname,
      'posicion', a.attnum, 'columna', a.attname,
      'tipo', format_type(a.atttypid, a.atttypmod),
      'no_nulo', a.attnotnull, 'identidad', a.attidentity,
      'generada', a.attgenerated,
      'default_o_expresion', pg_get_expr(d.adbin, d.adrelid),
      'collation', CASE WHEN a.attcollation <> 0 THEN a.attcollation::regcollation::text END,
      'acl', a.attacl::text, 'comentario', col_description(c.oid, a.attnum))
  FROM relaciones c
  JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
  LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
  WHERE a.attnum > 0 AND NOT a.attisdropped AND c.relkind <> 'S'

  UNION ALL
  SELECT '04_restricciones', format('%I.%s.%I', n.nspname,
      CASE WHEN con.conrelid <> 0 THEN con.conrelid::regclass::text
           ELSE con.contypid::regtype::text END, con.conname),
    jsonb_build_object('esquema', n.nspname, 'nombre', con.conname,
      'tabla', CASE WHEN con.conrelid <> 0 THEN con.conrelid::regclass::text END,
      'dominio', CASE WHEN con.contypid <> 0 THEN con.contypid::regtype::text END,
      'tipo', con.contype, 'definicion', pg_get_constraintdef(con.oid, false),
      'validada', con.convalidated, 'diferible', con.condeferrable,
      'inicialmente_diferida', con.condeferred,
      'tabla_referenciada', CASE WHEN con.confrelid <> 0 THEN con.confrelid::regclass::text END)
  FROM pg_catalog.pg_constraint con JOIN esquemas n ON n.oid = con.connamespace

  UNION ALL
  SELECT '05_indices', format('%I.%I', c.nspname, ic.relname),
    jsonb_build_object('esquema', c.nspname, 'tabla', c.relname,
      'nombre', ic.relname, 'definicion', pg_get_indexdef(i.indexrelid),
      'valido', i.indisvalid, 'listo', i.indisready,
      'unico', i.indisunique, 'primario', i.indisprimary,
      'replica_identity', i.indisreplident)
  FROM relaciones c JOIN pg_catalog.pg_index i ON i.indrelid = c.oid
  JOIN pg_catalog.pg_class ic ON ic.oid = i.indexrelid

  UNION ALL
  SELECT '06_vistas', format('%I.%I', c.nspname, c.relname),
    jsonb_build_object('esquema', c.nspname, 'nombre', c.relname,
      'materializada', c.relkind = 'm', 'definicion', pg_get_viewdef(c.oid, false),
      'opciones', c.reloptions, 'propietario', pg_get_userbyid(c.relowner))
  FROM relaciones c WHERE c.relkind IN ('v', 'm')

  UNION ALL
  SELECT '07_funciones_y_procedimientos',
    format('%I.%I(%s)', p.nspname, p.proname, pg_get_function_identity_arguments(p.oid)),
    jsonb_build_object('esquema', p.nspname, 'nombre', p.proname,
      'firma', pg_get_function_identity_arguments(p.oid),
      'argumentos_con_defaults', pg_get_function_arguments(p.oid),
      'resultado', pg_get_function_result(p.oid),
      'definicion', pg_get_functiondef(p.oid),
      'propietario', pg_get_userbyid(p.proowner),
      'security_definer', p.prosecdef, 'configuracion_local', p.proconfig,
      'acl', p.proacl::text, 'comentario', obj_description(p.oid, 'pg_proc'))
  FROM rutinas p

  UNION ALL
  SELECT '08_triggers', format('%I.%I.%I', n.nspname, c.relname, t.tgname),
    jsonb_build_object('esquema', n.nspname, 'tabla', c.relname,
      'nombre', t.tgname, 'habilitado', t.tgenabled,
      'funcion', t.tgfoid::regprocedure::text,
      'definicion', pg_get_triggerdef(t.oid, false))
  FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE NOT t.tgisinternal AND
    (c.relnamespace IN (SELECT oid FROM esquemas) OR t.tgfoid IN (SELECT oid FROM rutinas))

  UNION ALL
  SELECT '09_politicas_rls', format('%I.%I.%I', c.nspname, c.relname, p.polname),
    jsonb_build_object('esquema', c.nspname, 'tabla', c.relname,
      'nombre', p.polname, 'comando', p.polcmd, 'permisiva', p.polpermissive,
      'roles', (SELECT jsonb_agg(CASE WHEN r = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(r)::text END ORDER BY r)
                FROM unnest(p.polroles) AS roles(r)),
      'using', pg_get_expr(p.polqual, p.polrelid),
      'with_check', pg_get_expr(p.polwithcheck, p.polrelid))
  FROM pg_catalog.pg_policy p JOIN relaciones c ON c.oid = p.polrelid

  UNION ALL
  SELECT '10_permisos_relaciones', format('%I.%I', c.nspname, c.relname),
    jsonb_build_object('esquema', c.nspname, 'objeto', c.relname,
      'otorgante', pg_get_userbyid(a.grantor),
      'beneficiario', CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee)::text END,
      'privilegio', a.privilege_type, 'puede_otorgar', a.is_grantable)
  FROM relaciones c
  CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,
    acldefault(CASE WHEN c.relkind = 'S' THEN 'S'::"char" ELSE 'r'::"char" END, c.relowner))) a

  UNION ALL
  SELECT '11_permisos_funciones',
    format('%I.%I(%s)', p.nspname, p.proname, pg_get_function_identity_arguments(p.oid)),
    jsonb_build_object('esquema', p.nspname, 'nombre', p.proname,
      'firma', pg_get_function_identity_arguments(p.oid),
      'otorgante', pg_get_userbyid(a.grantor),
      'beneficiario', CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee)::text END,
      'privilegio', a.privilege_type, 'puede_otorgar', a.is_grantable)
  FROM rutinas p
  CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a

  UNION ALL
  SELECT '12_permisos_predeterminados', pg_get_userbyid(d.defaclrole)::text,
    jsonb_build_object('propietario', pg_get_userbyid(d.defaclrole),
      'esquema', CASE WHEN d.defaclnamespace = 0 THEN '(global)' ELSE n.nspname::text END,
      'tipo_objeto', d.defaclobjtype, 'acl', d.defaclacl::text)
  FROM pg_catalog.pg_default_acl d
  LEFT JOIN esquemas n ON n.oid = d.defaclnamespace
  WHERE d.defaclnamespace = 0 OR n.oid IS NOT NULL

  UNION ALL
  SELECT '13_tipos', format('%I.%I', n.nspname, t.typname),
    jsonb_build_object('esquema', n.nspname, 'nombre', t.typname,
      'tipo', t.typtype, 'propietario', pg_get_userbyid(t.typowner),
      'tipo_base_dominio', CASE WHEN t.typbasetype <> 0 THEN format_type(t.typbasetype, t.typtypmod) END,
      'dominio_no_nulo', t.typnotnull, 'dominio_default', t.typdefault,
      'valores_enum', (SELECT jsonb_agg(e.enumlabel ORDER BY e.enumsortorder)
                       FROM pg_catalog.pg_enum e WHERE e.enumtypid = t.oid),
      'atributos_compuestos', (SELECT jsonb_agg(jsonb_build_object(
        'nombre', a.attname, 'tipo', format_type(a.atttypid, a.atttypmod)) ORDER BY a.attnum)
        FROM pg_catalog.pg_attribute a WHERE a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped),
      'acl', t.typacl::text)
  FROM pg_catalog.pg_type t JOIN esquemas n ON n.oid = t.typnamespace
  WHERE t.typtype IN ('e', 'd', 'r', 'm') OR
    (t.typtype = 'c' AND EXISTS (SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid AND c.relkind = 'c'))

  UNION ALL
  SELECT '14_secuencias_configuracion', format('%I.%I', c.nspname, c.relname),
    jsonb_build_object('esquema', c.nspname, 'nombre', c.relname,
      'tipo', format_type(s.seqtypid, NULL), 'inicio', s.seqstart,
      'incremento', s.seqincrement, 'minimo', s.seqmin, 'maximo', s.seqmax,
      'cache', s.seqcache, 'ciclica', s.seqcycle,
      'pertenece_a', (SELECT jsonb_agg(jsonb_build_object(
        'tabla', d.refobjid::regclass::text, 'columna', a.attname, 'dependencia', d.deptype))
        FROM pg_catalog.pg_depend d
        LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
        WHERE d.classid = 'pg_catalog.pg_class'::regclass AND d.objid = c.oid
          AND d.refclassid = 'pg_catalog.pg_class'::regclass AND d.deptype IN ('a', 'i')))
  FROM pg_catalog.pg_sequence s JOIN relaciones c ON c.oid = s.seqrelid

  UNION ALL
  SELECT '15_extensiones', e.extname,
    jsonb_build_object('nombre', e.extname, 'version', e.extversion,
      'esquema', n.nspname, 'propietario', pg_get_userbyid(e.extowner))
  FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace

  UNION ALL
  SELECT '16_publicaciones', p.pubname,
    jsonb_build_object('nombre', p.pubname, 'todas_las_tablas', p.puballtables,
      'insert', p.pubinsert, 'update', p.pubupdate, 'delete', p.pubdelete,
      'truncate', p.pubtruncate,
      'tablas_en_alcance', (SELECT jsonb_agg(jsonb_build_object('esquema', pt.schemaname, 'tabla', pt.tablename)
        ORDER BY pt.schemaname, pt.tablename)
        FROM pg_catalog.pg_publication_tables pt
        WHERE pt.pubname = p.pubname AND pt.schemaname IN (SELECT nspname FROM esquemas)))
  FROM pg_catalog.pg_publication p

  UNION ALL
  SELECT '17_herencia_y_particiones', format('%I.%I', c.nspname, c.relname),
    jsonb_build_object('hija', format('%I.%I', c.nspname, c.relname),
      'padre', i.inhparent::regclass::text, 'orden', i.inhseqno)
  FROM pg_catalog.pg_inherits i JOIN relaciones c ON c.oid = i.inhrelid

  UNION ALL
  SELECT '18_reglas', format('%I.%I.%I', c.nspname, c.relname, r.rulename),
    jsonb_build_object('tabla', format('%I.%I', c.nspname, c.relname),
      'nombre', r.rulename, 'habilitada', r.ev_enabled,
      'definicion', pg_get_ruledef(r.oid, false))
  FROM pg_catalog.pg_rewrite r JOIN relaciones c ON c.oid = r.ev_class
  WHERE r.rulename <> '_RETURN'
),
secciones AS (
  SELECT seccion, count(*) AS cantidad_objetos,
    jsonb_agg(jsonb_build_object('objeto', objeto, 'detalle', detalle)
      ORDER BY objeto, detalle::text) AS contenido
  FROM objetos GROUP BY seccion
)
SELECT seccion, cantidad_objetos,
  count(*) OVER () AS total_filas_exportacion,
  contenido::text AS detalle_json
FROM secciones
ORDER BY seccion;
