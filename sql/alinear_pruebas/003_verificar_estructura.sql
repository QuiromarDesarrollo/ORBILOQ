/* SOLO LECTURA. Ejecutar en PRUEBAS despues de 002. No requiere cambiar RLS. */
BEGIN READ ONLY;
SET LOCAL search_path=public,extensions;
DO $verificar$
DECLARE esperado jsonb; actual jsonb; diferencia text;
BEGIN

-- SHA256 por objeto y sección: valida el inventario completo sin incrustarlo.
esperado := $inventario${"02_relaciones":"3dea8bd75dd0d76d7a196a9d30cb2d34092e01db1c4158c60694730c48631cee","03_columnas":"89a210bf0ac480389023798adf7801e5ad7ccbac2ce337f2708930eea9309655","04_restricciones":"619f084fbd4eaaa71336083ea01fd64318743ee9dadca5c567cd2bc5fc5c5608","05_indices":"6336be64289de2186ebaa131cc8b82df5afca43b2ef1444236f9590bcc936ad7","06_vistas":"57d51b934a8c09982b00d9973e843960c97323de3df8c24da63bfedebc9e6336","07_funciones_y_procedimientos":"63a2ec2b11ca669c5f338034524d63f1b839042b98180f1f8217527a4b90f9aa","09_politicas_rls":"1c68c25d5fcdd4c05aa57fc0f9210403a1b331ae6dae74f2c5ed99f6de0b1a39","10_permisos_relaciones":"3a4bb96bdabec6c80341b130d5c006f03b9a42993bc338f702f0df7d92043af4","11_permisos_funciones":"6a32b9809a488ca4cfec82bb5383ceda7b33d73c429adfb351bbf2825f4894f3","12_permisos_predeterminados":"31caf190b8c1d91c3129abb2943495844d08ef5983d63614c1efdc6672b3b628","14_secuencias_configuracion":"81f6bbb1e8ea8426449f998be59217a5390a6d65f8150eb9fb12b337ec4410c7","16_publicaciones":"af82eb388f5bc2c5b281e98345f7de6a35f8a6e599fed9d623ce41374873096d"}$inventario$::jsonb;
actual := (WITH
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

SELECT coalesce(jsonb_object_agg(seccion,firma),'{}'::jsonb)
FROM (
 SELECT seccion,encode(sha256(convert_to(string_agg(huella,E'\n' ORDER BY huella COLLATE "C"),'UTF8')),'hex') AS firma
 FROM (
  SELECT seccion,encode(sha256(convert_to(jsonb_build_object('s',seccion,'o',objeto,'d',v)::text,'UTF8')),'hex') AS huella
  FROM (SELECT seccion,objeto,(detalle - 'filas_estimadas_no_exactas' - 'posicion'
  - CASE WHEN left(seccion,2) IN ('02','07') THEN 'acl' ELSE '_sin_campo_' END)
  || CASE WHEN detalle ? 'definicion' THEN jsonb_build_object('definicion',replace(detalle->>'definicion', E'\r\n', E'\n')) ELSE '{}'::jsonb END
  || CASE WHEN left(seccion,2)='14' THEN jsonb_build_object('maximo',detalle->>'maximo','minimo',detalle->>'minimo') ELSE '{}'::jsonb END AS v FROM objetos WHERE left(seccion,2) IN ('02','03','04','05','06','07','08','09','10','11','12','13','14','16','17','18')) n
 ) huellas GROUP BY seccion
) firmas);
IF actual IS DISTINCT FROM esperado THEN
 SELECT string_agg(coalesce(a.key,b.key), ', ' ORDER BY coalesce(a.key,b.key)) INTO diferencia
 FROM jsonb_each_text(actual) a FULL JOIN jsonb_each_text(esperado) b ON a.key=b.key
 WHERE a.value IS DISTINCT FROM b.value;
 RAISE EXCEPTION 'La estructura resultante no coincide con PRODUCCION: %. No se guardaron cambios.',diferencia;
END IF;

END $verificar$;
COMMIT;
SELECT 'OK: estructura de public coincide con la referencia de produccion del 05-10-2026' AS resultado;
