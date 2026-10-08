/* ORBILOQ — SOLO PRUEBAS igfuafcekcpugpmsoqbe. NO EJECUTAR EN PRODUCCION.
 Ejecutar archivo COMPLETO en SQL Editor, sin seleccionar fragmentos.
 Una sola transaccion; aborta si cambió el esquema o los datos no cumplen.
 No copia datos de produccion ni modifica auth.users o Storage.
 Conserva todas las filas y valores originales; documentos/importaciones deben estar vacios.
 movimientos.creado_en se inicializa con fecha (aproximacion historica, no fecha de migracion).
 Si Supabase avisa de operaciones destructivas, corresponden a columnas vacias,
 un indice y funciones/restricciones reemplazadas dentro de esta transaccion.
 No crea tablas temporales ni requiere agregar RLS desde el editor.
 Origen CSV SHA256: a6ca3957a216b683350108a6cf4550f60ece05647da701224900f647f0f17823
 Referencia CSV SHA256: 3462844f3c75946fc00b83f3d434e21106ffa4477092e4b1c273b1b98045fd60
*/
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='180s';
SET LOCAL search_path=public,extensions;
DO $alinear$
DECLARE esperado jsonb; actual jsonb; diferencia text; conservacion jsonb:='{}'; filas jsonb; tabla text;
BEGIN
IF current_setting('app.settings.project_ref',true) = 'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'PRODUCCION: ejecucion prohibida'; END IF;
IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN RAISE EXCEPTION 'Base incorrecta o migracion ya aplicada: no continuar'; END IF;
IF EXISTS(SELECT 1 FROM public.documentos) OR EXISTS(SELECT 1 FROM public.importaciones) THEN RAISE EXCEPTION 'Documentos/importaciones ya tienen datos: solicitar nueva revision'; END IF;
LOCK TABLE public.admin_catalogos_historial,public.admin_correcciones,public.admin_importaciones,public.causales_devolucion,public.despachos_oc,public.devoluciones_produccion,public.documentos,public.importaciones,public.items_orden,public.liberaciones_aliados,public.liberaciones_no_conforme,public.lote_items,public.lotes,public.movimientos,public.no_conformes_aliados,public.ordenes_produccion,public.personal_aliados,public.personal_logistica,public.personal_produccion,public.sobrantes_bodega,public.ubicaciones,public.usuarios IN ACCESS EXCLUSIVE MODE;

-- SHA256 por objeto y sección: valida el inventario completo sin incrustarlo.
esperado := $inventario${"02_relaciones":"cd2b315eb4de9416c7a7332d3ac4c8e6201c8cd7878bcc30277ac9e6df25df7b","03_columnas":"e18e410275324a727114328b108ffbe0baf1239611e2b5bd0c36cdbd67b45030","04_restricciones":"9c3443043da10d73bfeaaaedee209778ec7307af603d2bbf8e6aa559d375a8ef","05_indices":"ebdeb47896296a4a9c85a15431c19a2dde60c190267eb7c0936af484952206af","06_vistas":"c02655348fb30c0fe6951c87fd7f8d43b07ef236446d1d87d9ef475085a8824b","07_funciones_y_procedimientos":"6ead48f1dc83a0e5b970ee5836683b8f07cb3eb543d150498feac872cf2dc3ee","09_politicas_rls":"7d9e63e9423681612ba559e6c752bc71b3ebc0fb52b8343bc902f663ff9c9ec8","10_permisos_relaciones":"44e95d6fabd88598a94e19c21daf15a4125028020a6cd7463247aae33c2e66da","11_permisos_funciones":"398cc9bd4e6e236d93391039227ba55d4d3bd358ae8e3470e14f8b9dcef7b860","12_permisos_predeterminados":"31caf190b8c1d91c3129abb2943495844d08ef5983d63614c1efdc6672b3b628","14_secuencias_configuracion":"81f6bbb1e8ea8426449f998be59217a5390a6d65f8150eb9fb12b337ec4410c7","16_publicaciones":"af82eb388f5bc2c5b281e98345f7de6a35f8a6e599fed9d623ce41374873096d"}$inventario$::jsonb;
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
 RAISE EXCEPTION 'La estructura de PRUEBAS cambió desde el inventario: %. No se guardaron cambios.',diferencia;
END IF;

FOR tabla IN SELECT unnest(ARRAY['public.admin_catalogos_historial','public.admin_correcciones','public.admin_importaciones','public.causales_devolucion','public.despachos_oc','public.devoluciones_produccion','public.documentos','public.importaciones','public.items_orden','public.liberaciones_aliados','public.liberaciones_no_conforme','public.lote_items','public.lotes','public.movimientos','public.no_conformes_aliados','public.ordenes_produccion','public.personal_aliados','public.personal_logistica','public.personal_produccion','public.sobrantes_bodega','public.ubicaciones','public.usuarios']::text[]) LOOP
 EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),''[]''::jsonb) FROM %s t',tabla) INTO filas;
 conservacion := conservacion || jsonb_build_object(tabla,filas);
END LOOP;
EXECUTE $ddl$ALTER TABLE public.documentos RENAME COLUMN creado_en TO fecha_carga;$ddl$;

EXECUTE $ddl$ALTER TABLE public.importaciones RENAME COLUMN creado_en TO fecha;$ddl$;

EXECUTE $ddl$CREATE TABLE public.clientes (
"id" uuid DEFAULT gen_random_uuid() NOT NULL,
"nombre" text NOT NULL,
"nit" text,
"activo" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL
);$ddl$;

EXECUTE $ddl$ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;$ddl$;

EXECUTE $ddl$CREATE TABLE public.devoluciones_cliente (
"id" uuid DEFAULT gen_random_uuid() NOT NULL,
"movimiento_id" uuid NOT NULL,
"item_orden_id" uuid NOT NULL,
"remision_id" uuid,
"causal_id" uuid,
"destino" text,
"nota" text,
"fecha_registro" timestamp with time zone DEFAULT now() NOT NULL,
"usuario_id" uuid
);$ddl$;

EXECUTE $ddl$ALTER TABLE public.devoluciones_cliente ENABLE ROW LEVEL SECURITY;$ddl$;

EXECUTE $ddl$ALTER TABLE public."admin_catalogos_historial" ALTER COLUMN "id" SET DEFAULT extensions.gen_random_uuid();$ddl$;

EXECUTE $ddl$ALTER TABLE public."admin_correcciones" ALTER COLUMN "id" SET DEFAULT extensions.gen_random_uuid();$ddl$;

EXECUTE $ddl$ALTER TABLE public."admin_importaciones" ALTER COLUMN "id" SET DEFAULT extensions.gen_random_uuid();$ddl$;

EXECUTE $ddl$ALTER TABLE public."despachos_oc" ALTER COLUMN "id" SET DEFAULT extensions.gen_random_uuid();$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "entidad_id" uuid NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "entidad_tipo" text NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "hash_sha256" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "mime_type" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "subido_por" uuid;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "tamano_bytes" bigint;$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD COLUMN "tipo_documento" text NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "detalle_errores" jsonb DEFAULT '[]'::jsonb NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "estado" text DEFAULT 'procesando'::text NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "filas_con_advertencia" integer DEFAULT 0 NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "filas_con_error" integer DEFAULT 0 NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "ops_actualizadas" integer DEFAULT 0 NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "ops_creadas" integer DEFAULT 0 NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "ops_omitidas" integer DEFAULT 0 NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "tipo" text NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD COLUMN "usuario_id" uuid;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "cantidad_pedida" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "descripcion" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "observacion" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "observacion" DROP NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "oc" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "oc" DROP NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ADD COLUMN "oc_id_erp" bigint;$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ALTER COLUMN "talla" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public.movimientos ADD COLUMN creado_en timestamp with time zone;$ddl$;

EXECUTE $ddl$UPDATE public.movimientos SET creado_en=fecha;$ddl$;

EXECUTE $ddl$ALTER TABLE public.movimientos ALTER COLUMN creado_en SET DEFAULT now(), ALTER COLUMN creado_en SET NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."movimientos" ALTER COLUMN "nota" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."movimientos" ALTER COLUMN "nota" DROP NOT NULL;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "cantidad_total_erp" integer;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ALTER COLUMN "cliente" DROP DEFAULT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "estado" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "estado_movimiento_erp" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "etapa_movimiento" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_acordada" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_comprometida" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_entrega" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_inicio" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_inicio_movimiento" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_planeacion" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_planeada_movimiento" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "fecha_solicitud" date;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "importacion_id" uuid;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "nombre_ficha_tecnica" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "nombre_prenda_resumen" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "observaciones" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "oc_cabecera" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "oc_id_erp" bigint;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD COLUMN "tipo_orden" text;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ubicaciones" ADD COLUMN "tipo" text DEFAULT 'almacenamiento'::text NOT NULL;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE VIEW public.admin_reporte_auditoria_interno AS  SELECT ('Movimientos:'::text || (movimientos.id)::text) AS registro,
    movimientos.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(u.nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Movimientos'::text AS origen,
    movimientos.tipo,
    (movimientos.cantidad)::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    movimientos.nota AS detalle,
    to_jsonb(movimientos.*) AS datos_crudos
   FROM (((movimientos
     LEFT JOIN usuarios u ON ((u.id = movimientos.usuario_id)))
     LEFT JOIN items_orden io ON ((io.id = movimientos.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Logística:'::text || (devoluciones_produccion.id)::text) AS registro,
    devoluciones_produccion.creado_en AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(devoluciones_produccion.operario_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Logística'::text AS origen,
    'Reporte no conforme'::text AS tipo,
    (devoluciones_produccion.cantidad)::bigint AS cantidad,
    c.nombre AS causal,
    devoluciones_produccion.recibido_de_produccion AS contraparte,
    devoluciones_produccion.nota AS detalle,
    to_jsonb(devoluciones_produccion.*) AS datos_crudos
   FROM (((devoluciones_produccion
     LEFT JOIN causales_devolucion c ON ((c.id = devoluciones_produccion.causal_id)))
     LEFT JOIN items_orden io ON ((io.id = devoluciones_produccion.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Aliados:'::text || (no_conformes_aliados.id)::text) AS registro,
    no_conformes_aliados.fecha_solicitud AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(no_conformes_aliados.usuario_produccion_solicitud_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Aliados'::text AS origen,
    'Envío no conforme a Aliado'::text AS tipo,
    (no_conformes_aliados.cantidad_solicitada)::bigint AS cantidad,
    c.nombre AS causal,
    no_conformes_aliados.persona_aliado_entrega AS contraparte,
    no_conformes_aliados.nota_solicitud AS detalle,
    to_jsonb(no_conformes_aliados.*) AS datos_crudos
   FROM (((no_conformes_aliados
     LEFT JOIN causales_devolucion c ON ((c.id = no_conformes_aliados.causal_id)))
     LEFT JOIN items_orden io ON ((io.id = no_conformes_aliados.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Producción:'::text || (lote_items.id)::text) AS registro,
    l.fecha_envio AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(l.operario_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Producción'::text AS origen,
    'Entrega de lote'::text AS tipo,
    (lote_items.cantidad_enviada)::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    l.numero AS detalle,
    to_jsonb(lote_items.*) AS datos_crudos
   FROM (((lote_items
     JOIN lotes l ON ((l.id = lote_items.lote_id)))
     LEFT JOIN items_orden io ON ((io.id = lote_items.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Recepción:'::text || (lote_items.id)::text) AS registro,
    lote_items.fecha_recepcion AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(lote_items.recibido_por, ''::text), 'Sin registrar'::text) AS persona,
    'Recepción'::text AS origen,
    'Última recepción acumulada'::text AS tipo,
    (lote_items.cantidad_recibida)::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    COALESCE(lote_items.novedad, ''::text) AS detalle,
    to_jsonb(lote_items.*) AS datos_crudos
   FROM ((lote_items
     LEFT JOIN items_orden io ON ((io.id = lote_items.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
  WHERE (lote_items.fecha_recepcion IS NOT NULL)
UNION ALL
 SELECT ('Liberaciones:'::text || (liberaciones_no_conforme.id)::text) AS registro,
    liberaciones_no_conforme.creado_en AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(liberaciones_no_conforme.operario_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Liberaciones'::text AS origen,
    'Liberación no conforme'::text AS tipo,
    (liberaciones_no_conforme.cantidad)::bigint AS cantidad,
    ''::text AS causal,
    liberaciones_no_conforme.recibido_por_logistica AS contraparte,
    liberaciones_no_conforme.nota AS detalle,
    to_jsonb(liberaciones_no_conforme.*) AS datos_crudos
   FROM ((liberaciones_no_conforme
     LEFT JOIN items_orden io ON ((io.id = liberaciones_no_conforme.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Liberaciones Aliados:'::text || (liberaciones_aliados.id)::text) AS registro,
    liberaciones_aliados.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(liberaciones_aliados.usuario_produccion_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Liberaciones Aliados'::text AS origen,
    'Liberación Aliado'::text AS tipo,
    (liberaciones_aliados.cantidad)::bigint AS cantidad,
    ''::text AS causal,
    liberaciones_aliados.persona_aliado_libera AS contraparte,
    liberaciones_aliados.nota AS detalle,
    to_jsonb(liberaciones_aliados.*) AS datos_crudos
   FROM (((liberaciones_aliados
     LEFT JOIN no_conformes_aliados s ON ((s.id = liberaciones_aliados.solicitud_id)))
     LEFT JOIN items_orden io ON ((io.id = s.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Sobrantes:'::text || (sobrantes_bodega.id)::text) AS registro,
    sobrantes_bodega.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(sobrantes_bodega.operario_nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Sobrantes'::text AS origen,
    'Registro sobrante'::text AS tipo,
    (sobrantes_bodega.cantidad)::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    sobrantes_bodega.nota AS detalle,
    to_jsonb(sobrantes_bodega.*) AS datos_crudos
   FROM ((sobrantes_bodega
     LEFT JOIN items_orden io ON ((io.id = sobrantes_bodega.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Resoluciones:'::text || (sobrantes_bodega.id)::text) AS registro,
    sobrantes_bodega.fecha_resolucion AS fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF('Sin registrar'::text, ''::text), 'Sin registrar'::text) AS persona,
    'Resoluciones'::text AS origen,
    'Resolución sobrante'::text AS tipo,
    NULL::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    COALESCE(sobrantes_bodega.resolucion, ''::text) AS detalle,
    to_jsonb(sobrantes_bodega.*) AS datos_crudos
   FROM ((sobrantes_bodega
     LEFT JOIN items_orden io ON ((io.id = sobrantes_bodega.item_orden_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
  WHERE (sobrantes_bodega.fecha_resolucion IS NOT NULL)
UNION ALL
 SELECT ('Correcciones:'::text || (admin_correcciones.id)::text) AS registro,
    admin_correcciones.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(admin_correcciones.actor, ''::text), 'Sin registrar'::text) AS persona,
    'Correcciones'::text AS origen,
    ('Corrección: '::text || admin_correcciones.campo) AS tipo,
    NULL::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    admin_correcciones.motivo AS detalle,
    to_jsonb(admin_correcciones.*) AS datos_crudos
   FROM ((admin_correcciones
     LEFT JOIN items_orden io ON ((io.id = admin_correcciones.item_id)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Catálogos:'::text || (admin_catalogos_historial.id)::text) AS registro,
    admin_catalogos_historial.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(u.nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Catálogos'::text AS origen,
    ('Cambio catálogo: '::text || admin_catalogos_historial.catalogo) AS tipo,
    NULL::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    (admin_catalogos_historial.registro_id)::text AS detalle,
    to_jsonb(admin_catalogos_historial.*) AS datos_crudos
   FROM (((admin_catalogos_historial
     LEFT JOIN usuarios u ON ((u.auth_id = admin_catalogos_historial.actor_id)))
     LEFT JOIN items_orden io ON ((io.id = NULL::uuid)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Importación Excel:'::text || (admin_importaciones.id)::text) AS registro,
    admin_importaciones.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(NULLIF(u.nombre, ''::text), 'Sin registrar'::text) AS persona,
    'Importación Excel'::text AS origen,
    ('Importar tabla: '::text || admin_importaciones.vista) AS tipo,
    NULL::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    admin_importaciones.motivo AS detalle,
    (to_jsonb(admin_importaciones.*) - 'archivo'::text) AS datos_crudos
   FROM (((admin_importaciones
     LEFT JOIN usuarios u ON ((u.auth_id = admin_importaciones.actor_id)))
     LEFT JOIN items_orden io ON ((io.id = NULL::uuid)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)))
UNION ALL
 SELECT ('Importación ERP:'::text || (importaciones.id)::text) AS registro,
    importaciones.fecha,
    COALESCE(op.numero_op, ''::text) AS op,
    COALESCE(io.codigo, ''::text) AS codigo,
    COALESCE(io.descripcion, ''::text) AS producto,
    COALESCE(io.talla, ''::text) AS talla,
    COALESCE(op.cliente, ''::text) AS cliente,
    COALESCE(( SELECT NULLIF(ui.nombre, ''::text) AS "nullif"
           FROM usuarios ui
          WHERE (ui.id = importaciones.usuario_id)), 'Sin registrar'::text) AS persona,
    'Importación ERP'::text AS origen,
    'Importar ERP'::text AS tipo,
    NULL::bigint AS cantidad,
    ''::text AS causal,
    ''::text AS contraparte,
    importaciones.nombre_archivo AS detalle,
    to_jsonb(importaciones.*) AS datos_crudos
   FROM ((importaciones
     LEFT JOIN items_orden io ON ((io.id = NULL::uuid)))
     LEFT JOIN ordenes_produccion op ON ((op.id = io.orden_id)));$ddl$;

EXECUTE $ddl$ALTER TABLE public.importaciones DROP COLUMN usuario_nombre;$ddl$;

EXECUTE $ddl$ALTER TABLE public.no_conformes_aliados RENAME CONSTRAINT no_conformes_aliados_cantidad_check TO no_conformes_aliados_cantidad_solicitada_check;$ddl$;

EXECUTE $ddl$ALTER TABLE public."clientes" ADD CONSTRAINT "clientes_nombre_key" UNIQUE (nombre);$ddl$;

EXECUTE $ddl$ALTER TABLE public."clientes" ADD CONSTRAINT "clientes_pkey" PRIMARY KEY (id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_destino_check" CHECK ((destino = ANY (ARRAY['reingreso_bodega'::text, 'no_conforme_produccion'::text, 'descarte'::text])));$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_movimiento_id_key" UNIQUE (movimiento_id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_pkey" PRIMARY KEY (id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD CONSTRAINT "documentos_entidad_tipo_check" CHECK ((entidad_tipo = ANY (ARRAY['orden_produccion'::text, 'remision'::text, 'movimiento'::text, 'ubicacion'::text, 'importacion'::text])));$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD CONSTRAINT "importaciones_estado_check" CHECK ((estado = ANY (ARRAY['procesando'::text, 'completado'::text, 'fallido'::text])));$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD CONSTRAINT "importaciones_tipo_check" CHECK ((tipo = ANY (ARRAY['ordenes_produccion'::text, 'fechas_entrega'::text])));$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ADD CONSTRAINT "items_orden_cantidad_pedida_check" CHECK ((cantidad_pedida > 0));$ddl$;

EXECUTE $ddl$ALTER TABLE public."ubicaciones" ADD CONSTRAINT "ubicaciones_tipo_check" CHECK ((tipo = ANY (ARRAY['almacenamiento'::text, 'no_conforme'::text, 'transito_produccion'::text])));$ddl$;

EXECUTE $ddl$ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_auth_id_key" UNIQUE (auth_id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_email_key" UNIQUE (email);$ddl$;

EXECUTE $ddl$ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_nombre_rol_unique" UNIQUE (nombre, rol);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_causal_id_fkey" FOREIGN KEY (causal_id) REFERENCES causales_devolucion(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_item_orden_id_fkey" FOREIGN KEY (item_orden_id) REFERENCES items_orden(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_movimiento_id_fkey" FOREIGN KEY (movimiento_id) REFERENCES movimientos(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."devoluciones_cliente" ADD CONSTRAINT "devoluciones_cliente_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES usuarios(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."documentos" ADD CONSTRAINT "documentos_subido_por_fkey" FOREIGN KEY (subido_por) REFERENCES usuarios(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."importaciones" ADD CONSTRAINT "importaciones_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES usuarios(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" DROP CONSTRAINT "items_orden_orden_id_fkey";$ddl$;

EXECUTE $ddl$ALTER TABLE public."items_orden" ADD CONSTRAINT "items_orden_orden_id_fkey" FOREIGN KEY (orden_id) REFERENCES ordenes_produccion(id) ON DELETE RESTRICT;$ddl$;

EXECUTE $ddl$ALTER TABLE public."ordenes_produccion" ADD CONSTRAINT "ordenes_produccion_importacion_id_fkey" FOREIGN KEY (importacion_id) REFERENCES importaciones(id);$ddl$;

EXECUTE $ddl$ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_auth_id_fkey" FOREIGN KEY (auth_id) REFERENCES auth.users(id) ON DELETE SET NULL;$ddl$;

EXECUTE $ddl$CREATE INDEX idx_documentos_entidad ON public.documentos USING btree (entidad_tipo, entidad_id);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_items_orden_orden_codigo ON public.items_orden USING btree (orden_id, codigo);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_movimientos_fecha ON public.movimientos USING btree (fecha);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_movimientos_item_ubicacion_fecha ON public.movimientos USING btree (item_orden_id, ubicacion_id, fecha) WHERE (tipo = 'recepcion'::text);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_movimientos_remision ON public.movimientos USING btree (lote_id);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_movimientos_tipo ON public.movimientos USING btree (tipo);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_op_cliente ON public.ordenes_produccion USING btree (cliente);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_op_estado ON public.ordenes_produccion USING btree (estado);$ddl$;

EXECUTE $ddl$CREATE INDEX idx_op_fecha_entrega_logistica ON public.ordenes_produccion USING btree (fecha_esperada_logistica);$ddl$;

EXECUTE $ddl$DROP INDEX public.idx_movimientos_lote;$ddl$;

EXECUTE $ddl$DROP FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text);$ddl$;

EXECUTE $ddl$DROP FUNCTION public.liberar_no_conforme_aliado(p_id uuid, p_operario_nombre text, p_persona_aliado_libera text, p_nota text);$ddl$;

EXECUTE $ddl$DROP FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text);$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.despachar(p_item_orden_id uuid, p_cantidad integer, p_ubicacion_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  DECLARE c text; o text; u text;
  BEGIN
   SELECT op.cliente,io.oc INTO c,o FROM public.items_orden io JOIN public.ordenes_produccion op ON op.id=io.orden_id WHERE io.id=p_item_orden_id;
   SELECT codigo INTO u FROM public.ubicaciones WHERE id=p_ubicacion_id;
   RETURN public.despachar_oc(gen_random_uuid()::text,c,o,jsonb_build_array(jsonb_build_object('item_id',p_item_orden_id,'cantidad',p_cantidad,'ubicacion',u)));
  END $function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.despachar_oc(p_solicitud text, p_cliente text, p_oc text, p_lineas jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET lock_timeout TO '5s'
AS $function$
  DECLARE actor public.usuarios%rowtype; previo public.despachos_oc%rowtype; solicitud_id uuid:=gen_random_uuid();
   r record; item public.items_orden%rowtype; cliente_actual text; stock bigint; pendiente bigint; ubic uuid;
   detalle jsonb:='[]'; pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas);
  BEGIN
   SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
   IF actor.id IS NULL THEN RAISE EXCEPTION 'Se requiere Logística o Administrador activo.' USING ERRCODE='42501'; END IF;
   IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR p_cliente IS NULL OR p_oc IS NULL OR jsonb_typeof(p_lineas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Solicitud inválida.'; END IF;
   IF jsonb_array_length(p_lineas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Selecciona de 1 a 1000 retiros.'; END IF;
   LOCK TABLE public.usuarios IN SHARE MODE;
   LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
   SELECT * INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica');
   IF actor.id IS NULL THEN RAISE EXCEPTION 'Cuenta sin acceso.' USING ERRCODE='42501'; END IF;
   SELECT * INTO previo FROM public.despachos_oc WHERE solicitud=p_solicitud;
   IF FOUND THEN
     IF previo.actor_id<>actor.id OR previo.pedido<>pedido THEN RAISE EXCEPTION 'La solicitud ya se usó para otro despacho.'; END IF;
     RETURN jsonb_build_object('id',previo.id,'detalle',previo.detalle,'repetido',true);
   END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_lineas) x WHERE coalesce(x->>'cantidad','') !~ '^[1-9][0-9]*$' OR nullif(x->>'item_id','') IS NULL OR nullif(x->>'ubicacion','') IS NULL) THEN RAISE EXCEPTION 'Cada retiro requiere prenda, estante y cantidad positiva.'; END IF;
   FOR r IN SELECT (x->>'item_id')::uuid item_id,sum((x->>'cantidad')::bigint) cantidad FROM jsonb_array_elements(p_lineas) x GROUP BY 1 LOOP
     SELECT * INTO item FROM public.items_orden WHERE id=r.item_id AND admin_eliminado_en IS NULL;
     IF NOT FOUND THEN RAISE EXCEPTION 'Prenda inexistente u oculta.'; END IF;
     SELECT cliente INTO cliente_actual FROM public.ordenes_produccion WHERE id=item.orden_id;
     IF cliente_actual IS DISTINCT FROM p_cliente OR item.oc IS DISTINCT FROM p_oc THEN RAISE EXCEPTION 'Las prendas deben pertenecer al cliente y OC seleccionados.'; END IF;
     SELECT item.cantidad_pedida-coalesce(sum(cantidad),0) INTO pendiente FROM public.movimientos WHERE item_orden_id=item.id AND tipo='despacho';
     IF r.cantidad>pendiente THEN RAISE EXCEPTION 'La cantidad supera el pendiente de la OP (% Uds).',pendiente; END IF;
     SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
     INTO stock FROM public.movimientos WHERE item_orden_id=item.id;
     IF r.cantidad>stock THEN RAISE EXCEPTION 'Stock total insuficiente para la prenda. Disponible: %.',stock; END IF;
   END LOOP;
   FOR r IN SELECT (x->>'item_id')::uuid item_id,x->>'ubicacion' ubicacion,sum((x->>'cantidad')::bigint) cantidad FROM jsonb_array_elements(p_lineas) x GROUP BY 1,2 ORDER BY 1,2 LOOP
     SELECT id INTO ubic FROM public.ubicaciones WHERE codigo=r.ubicacion AND activa;
     IF ubic IS NULL THEN RAISE EXCEPTION 'Estante inactivo o inexistente.'; END IF;
     SELECT coalesce(sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END),0)
     INTO stock FROM public.movimientos WHERE item_orden_id=r.item_id AND ubicacion_id=ubic;
     IF r.cantidad>stock THEN RAISE EXCEPTION 'Stock insuficiente en %. Disponible: %.',r.ubicacion,stock; END IF;
     SELECT * INTO item FROM public.items_orden WHERE id=r.item_id;
     detalle:=detalle||jsonb_build_array(jsonb_build_object('item_id',item.id,'op',(SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id),
       'codigo',item.codigo,'producto',item.descripcion,'talla',item.talla,'ubicacion',r.ubicacion,'ubicacion_id',ubic,'cantidad',r.cantidad));
   END LOOP;
   INSERT INTO public.despachos_oc(id,solicitud,actor_id,actor,cliente,oc,pedido,detalle) VALUES(solicitud_id,p_solicitud,actor.id,actor.nombre,p_cliente,p_oc,pedido,detalle);
   INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,despacho_oc_id,nota)
   SELECT 'despacho',(x->>'item_id')::uuid,(x->>'cantidad')::integer,(x->>'ubicacion_id')::uuid,actor.id,solicitud_id,'Despacho OC '||p_oc FROM jsonb_array_elements(detalle) x;
   RETURN jsonb_build_object('id',solicitud_id,'detalle',detalle,'repetido',false);
  END $function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.historial_despachos_oc(p_despues text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  DECLARE resultado jsonb;
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Acceso exclusivo de Logística o Administrador.' USING ERRCODE='42501'; END IF;
   SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY registro),'[]') INTO resultado FROM (
   SELECT m.id::text registro,m.fecha,m.cantidad,coalesce(d.cliente,op.cliente) cliente,coalesce(d.oc,io.oc) oc,coalesce(d.actor,u.nombre,'Sin registrar') persona,
   op.numero_op AS op,io.id item_id,io.codigo,io.descripcion producto,io.talla,ub.codigo ubicacion,m.nota,m.despacho_oc_id
   FROM public.movimientos m JOIN public.items_orden io ON io.id=m.item_orden_id JOIN public.ordenes_produccion op ON op.id=io.orden_id
   LEFT JOIN public.usuarios u ON u.id=m.usuario_id LEFT JOIN public.ubicaciones ub ON ub.id=m.ubicacion_id LEFT JOIN public.despachos_oc d ON d.id=m.despacho_oc_id
   WHERE m.tipo='despacho' AND m.id::text>p_despues ORDER BY m.id::text LIMIT 1000
   ) t;
   RETURN resultado;
  END $function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_importacion_id uuid;
  v_usuario_id uuid;
  v_ops_creadas integer;
  v_ops_omitidas integer;
  v_filas_invalidas integer;
  v_lineas_tallas integer;
  v_advertencias jsonb;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_usuario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into importaciones (nombre_archivo, tipo, storage_path, usuario_id, estado)
  values (p_nombre_archivo, 'ordenes_produccion', p_storage_path, v_usuario_id, 'procesando')
  returning id into v_importacion_id;

  -- --------------------------------------------------------- 1) Órdenes nuevas
  with filas as (
    select
      trim(o->>'identificador') as numero_op,
      nullif(trim(o->>'tipo_orden'), '') as tipo_orden,
      nullif(trim(o->>'estado'), '') as estado,
      coalesce(nullif(trim(o->>'cliente'), ''), 'SIN CLIENTE') as cliente,
      nullif(trim(o->>'oc_cabecera'), '') as oc_cabecera,
      nullif(o->>'oc_id_erp', '')::bigint as oc_id_erp,
      nullif(trim(o->>'nombre_ficha_tecnica'), '') as nombre_ficha_tecnica,
      nullif(trim(o->>'nombre_prenda_resumen'), '') as nombre_prenda_resumen,
      nullif(o->>'cantidad_total_erp', '')::integer as cantidad_total_erp,
      nullif(o->>'fecha_solicitud', '')::date as fecha_solicitud,
      nullif(o->>'fecha_inicio', '')::date as fecha_inicio,
      nullif(o->>'fecha_comprometida', '')::date as fecha_comprometida,
      nullif(o->>'fecha_acordada', '')::date as fecha_acordada,
      nullif(o->>'fecha_entrega', '')::date as fecha_entrega,
      nullif(o->>'fecha_planeacion', '')::date as fecha_planeacion,
      nullif(trim(o->>'observaciones'), '') as observaciones,
      nullif(trim(o->>'etapa_movimiento'), '') as etapa_movimiento,
      nullif(trim(o->>'estado_movimiento_erp'), '') as estado_movimiento_erp,
      nullif(o->>'fecha_inicio_movimiento', '')::date as fecha_inicio_movimiento,
      nullif(o->>'fecha_planeada_movimiento', '')::date as fecha_planeada_movimiento
    from jsonb_array_elements(p_ordenes) as o
    where trim(o->>'identificador') <> ''
  )
  insert into ordenes_produccion (
    numero_op, tipo_orden, estado, cliente, oc_cabecera, oc_id_erp,
    nombre_ficha_tecnica, nombre_prenda_resumen, cantidad_total_erp,
    fecha_solicitud, fecha_inicio, fecha_comprometida, fecha_acordada,
    fecha_entrega, fecha_planeacion, observaciones,
    etapa_movimiento, estado_movimiento_erp,
    fecha_inicio_movimiento, fecha_planeada_movimiento, importacion_id
  )
  select
    numero_op, tipo_orden, estado, cliente, oc_cabecera, oc_id_erp,
    nombre_ficha_tecnica, nombre_prenda_resumen, cantidad_total_erp,
    fecha_solicitud, fecha_inicio, fecha_comprometida, fecha_acordada,
    fecha_entrega, fecha_planeacion, observaciones,
    etapa_movimiento, estado_movimiento_erp,
    fecha_inicio_movimiento, fecha_planeada_movimiento, v_importacion_id
  from filas
  on conflict (numero_op) do nothing;

  get diagnostics v_ops_creadas = row_count;

  select count(*) into v_ops_omitidas
  from jsonb_array_elements(p_ordenes) as o
  where trim(o->>'identificador') <> ''
    and exists (
      select 1 from ordenes_produccion op
      where op.numero_op = trim(o->>'identificador') and op.importacion_id is distinct from v_importacion_id
    );

  select count(*) into v_filas_invalidas
  from jsonb_array_elements(p_ordenes) as o
  where trim(coalesce(o->>'identificador', '')) = '';

  -- ------------------------------------------------------ 2) Tallas de las OP
  -- El join por importacion_id garantiza que solo se insertan tallas de las
  -- OP recién creadas en ESTA carga (las que ya existían quedan intactas).
  --
  -- El "No. OC" que se guarda (oc) viene de la hoja "Orden" (op.oc_cabecera),
  -- no de la hoja "Tallas" (antes se usaba ft.oc, que a veces viene vacío).
  with filas_tallas as (
    select
      trim(t->>'identificador_orden') as numero_op,
      trim(t->>'codigo') as codigo,
      trim(t->>'descripcion') as descripcion,
      trim(t->>'talla') as talla,
      nullif(trim(t->>'cantidad'), '')::integer as cantidad,
      nullif(trim(t->>'oc'), '') as oc,
      nullif(t->>'oc_id_erp', '')::bigint as oc_id_erp,
      nullif(trim(t->>'observacion'), '') as observacion
    from jsonb_array_elements(p_tallas) as t
  )
  insert into items_orden (orden_id, codigo, descripcion, talla, cantidad_pedida, oc, oc_id_erp, observacion)
  select op.id, ft.codigo, ft.descripcion, ft.talla, ft.cantidad, op.oc_cabecera, ft.oc_id_erp, ft.observacion
  from filas_tallas ft
  join ordenes_produccion op
    on op.numero_op = ft.numero_op and op.importacion_id = v_importacion_id
  where coalesce(ft.cantidad, 0) > 0
    and coalesce(ft.codigo, '') <> ''
    and coalesce(ft.talla, '') <> ''
  on conflict (orden_id, codigo, talla) do nothing;

  get diagnostics v_lineas_tallas = row_count;

  -- ---------------------------------------------- 3) Advertencias de cantidad
  -- OP nuevas donde el total declarado en el ERP no coincide con la suma real
  -- de sus tallas importadas (por ejemplo, si el Excel trae una OP sin líneas).
  select coalesce(jsonb_agg(
    format('OP %s: declara %s Uds pero sus tallas suman %s Uds',
           op.numero_op, op.cantidad_total_erp, coalesce(s.total, 0))
  ), '[]'::jsonb)
  into v_advertencias
  from ordenes_produccion op
  left join (
    select orden_id, sum(cantidad_pedida) as total from items_orden group by orden_id
  ) s on s.orden_id = op.id
  where op.importacion_id = v_importacion_id
    and op.cantidad_total_erp is not null
    and op.cantidad_total_erp <> coalesce(s.total, 0);

  -- ORBILOQ_OC_PROD
 UPDATE public.items_orden io SET oc=op.oc_cabecera FROM public.ordenes_produccion op WHERE op.id=io.orden_id AND coalesce(trim(io.oc),'')='' AND coalesce(trim(op.oc_cabecera),'')<>'' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_ordenes) o WHERE trim(o->>'identificador')=op.numero_op);
 update importaciones set
    ops_creadas = v_ops_creadas,
    ops_omitidas = v_ops_omitidas,
    filas_con_advertencia = jsonb_array_length(v_advertencias),
    filas_con_error = v_filas_invalidas,
    detalle_errores = v_advertencias,
    estado = 'completado'
  where id = v_importacion_id;

  return jsonb_build_object(
    'importacion_id', v_importacion_id,
    'ops_creadas', v_ops_creadas,
    'ops_omitidas', v_ops_omitidas,
    'filas_invalidas', v_filas_invalidas,
    'lineas_tallas_creadas', v_lineas_tallas,
    'advertencias', v_advertencias
  );
end;
$function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_usuario_id uuid;
  v_pendiente_reproceso integer;
  v_liberacion_id uuid;
  v_lote_id uuid;
  v_numero text;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','produccion')) THEN RAISE EXCEPTION 'Esta operacion requiere Produccion o Administrador.' USING ERRCODE='42501'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  select coalesce(sum(case
           when tipo = 'devolucion_produccion' then cantidad
           when tipo = 'liberacion_no_conforme' then -cantidad
           else 0
         end), 0)
    into v_pendiente_reproceso
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_pendiente_reproceso then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds pendientes por reprocesar para este producto.', v_pendiente_reproceso;
  end if;

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into liberaciones_no_conforme (item_orden_id, cantidad, operario_id, operario_nombre, nota)
  values (p_item_orden_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota)
  returning id into v_liberacion_id;

  v_numero := 'LOTE-' || nextval('lotes_numero_seq');
  insert into lotes (numero, operario_id, operario_nombre)
  values (v_numero, v_usuario_id, p_operario_nombre)
  returning id into v_lote_id;

  insert into lote_items (lote_id, item_orden_id, cantidad_enviada, origen)
  values (v_lote_id, p_item_orden_id, p_cantidad, 'reproceso');

  insert into movimientos (tipo, item_orden_id, cantidad, lote_id, usuario_id, nota)
  values ('liberacion_no_conforme', p_item_orden_id, p_cantidad, v_lote_id, v_usuario_id, p_nota);

  return jsonb_build_object(
    'id', v_liberacion_id, 'item_orden_id', p_item_orden_id,
    'cantidad', p_cantidad, 'lote_numero', v_numero
  );
end;
$function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_li lote_items%rowtype;
  v_diff integer;
  v_novedad text := '';
  v_estado_linea text;
  v_pendientes_en_lote integer;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN RAISE EXCEPTION 'Estante inactivo o inexistente.'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then
    raise exception 'La línea del lote no existe.';
  end if;
  if v_li.estado <> 'en_transito' then
    raise exception 'Esta línea ya fue recibida.';
  end if;

  -- CORREGIDO: antes decía "p_cantidad < 0", lo que dejaba pasar el 0.
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;

  if not exists (select 1 from ubicaciones where id = p_ubicacion_id and activa) then
    raise exception 'Ubicación no válida.';
  end if;

  -- A partir de aquí es exactamente igual que antes: nada de esto se
  -- ejecuta si la cantidad no pasó la validación de arriba.
  v_diff := p_cantidad - v_li.cantidad_enviada;
  if v_diff < 0 then
    v_novedad := format('FALTANTE: Se recibieron %s de %s Uds (faltaron %s).',
                         p_cantidad, v_li.cantidad_enviada, abs(v_diff));
  elsif v_diff > 0 then
    v_novedad := format('SOBRANTE: Se recibieron %s de %s Uds (+%s).',
                         p_cantidad, v_li.cantidad_enviada, v_diff);
  end if;
  if coalesce(trim(p_nota), '') <> '' then
    v_novedad := trim(coalesce(v_novedad || ' ', '') || 'Obs: ' || p_nota);
  end if;

  v_estado_linea := case when v_novedad = '' then 'recibido_conforme' else 'recibido_con_novedad' end;

  update lote_items set
    estado = v_estado_linea,
    cantidad_recibida = p_cantidad,
    ubicacion_destino_id = p_ubicacion_id,
    novedad = v_novedad,
    fecha_recepcion = now()
  where id = p_lote_item_id;

  insert into movimientos (tipo, item_orden_id, cantidad, ubicacion_id, lote_id, lote_item_id, nota)
  values ('recepcion', v_li.item_orden_id, p_cantidad, p_ubicacion_id, v_li.lote_id, p_lote_item_id, v_novedad);

  select count(*) into v_pendientes_en_lote
  from lote_items where lote_id = v_li.lote_id and estado = 'en_transito';

  update lotes set
    estado = case when v_pendientes_en_lote = 0 then 'recibido_completo' else 'recibido_parcial' end
  where id = v_li.lote_id;

  return jsonb_build_object('lote_item_id', p_lote_item_id, 'estado', v_estado_linea, 'novedad', v_novedad);
end;
$function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_li lote_items%rowtype;
  v_recibido_previo integer;
  v_pendiente integer;
  v_completa boolean;
  v_recibido_por text;
  v_pendientes_en_lote integer;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_recibido_por := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion_id AND activa) THEN RAISE EXCEPTION 'Estante inactivo o inexistente.'; END IF;


  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  v_recibido_por := nullif(trim(p_recibido_por), '');
  if v_recibido_por is null then
    raise exception 'Debes indicar quién de Logística recibió esta prenda.';
  end if;

  select * into v_li from lote_items where id = p_lote_item_id for update;
  if not found then raise exception 'La línea del lote no existe.'; end if;
  if v_li.estado <> 'en_transito' then raise exception 'Esta línea ya fue cerrada.'; end if;
  if p_cantidad is null or p_cantidad <= 0 then raise exception 'La cantidad debe ser mayor a 0.'; end if;
  if not exists (select 1 from ubicaciones where id = p_ubicacion_id and activa) then
    raise exception 'Ubicación no válida.';
  end if;

  v_recibido_previo := coalesce(v_li.cantidad_recibida, 0);
  v_pendiente := v_li.cantidad_enviada - v_recibido_previo;

  if p_cantidad > v_pendiente then
    raise exception
      'LÍMITE EXCEDIDO: solo faltan % Uds por recibir en esta línea. Si llegó más de lo declarado, usa la Bandeja de Sobrantes para el exceso.',
      v_pendiente;
  end if;

  v_completa := (v_recibido_previo + p_cantidad) >= v_li.cantidad_enviada;

  update lote_items set
    cantidad_recibida = v_recibido_previo + p_cantidad,
    ubicacion_destino_id = p_ubicacion_id,
    recibido_por = v_recibido_por,
    fecha_recepcion = now(),
    estado = case when v_completa then 'recibido_conforme' else 'en_transito' end
  where id = p_lote_item_id;

  insert into movimientos (tipo, item_orden_id, cantidad, ubicacion_id, lote_id, lote_item_id, nota)
  values ('recepcion', v_li.item_orden_id, p_cantidad, p_ubicacion_id, v_li.lote_id, p_lote_item_id, p_nota);

  select count(*) into v_pendientes_en_lote from lote_items where lote_id = v_li.lote_id and estado = 'en_transito';
  update lotes set estado = case when v_pendientes_en_lote = 0 then 'recibido_completo' else 'recibido_parcial' end
  where id = v_li.lote_id;

  return jsonb_build_object(
    'lote_item_id', p_lote_item_id, 'completa', v_completa,
    'recibido_total', v_recibido_previo + p_cantidad, 'pendiente', v_li.cantidad_enviada - (v_recibido_previo + p_cantidad)
  );
end;
$function$
;$ddl$;

EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET lock_timeout TO '5s'
AS $function$
declare
  v_usuario_id uuid;
  v_producido integer;
  v_devolucion_id uuid;
BEGIN
 -- ORBILOQ_ACTOR_V61
 PERFORM public.wms_nombre_actor();
 p_operario_nombre := public.wms_nombre_actor();

 -- ORBILOQ_CUENTA_V60
 IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta inactiva o sin acceso.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol IN ('admin','logistica')) THEN RAISE EXCEPTION 'Esta operacion requiere Logistica o Administrador.' USING ERRCODE='42501'; END IF;

  -- ORBILOQ_ADMIN_LOCK_V55
  LOCK TABLE public.ordenes_produccion, public.items_orden, public.lotes, public.lote_items, public.movimientos IN SHARE ROW EXCLUSIVE MODE;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0.';
  end if;
  if not exists (select 1 from causales_devolucion where id = p_causal_id and activa) then
    raise exception 'Causal no válida.';
  end if;

  select coalesce(sum(case
           when tipo = 'entrega_produccion' then cantidad
           when tipo = 'devolucion_produccion' then -cantidad
           else 0
         end), 0)
    into v_producido
    from movimientos where item_orden_id = p_item_orden_id;

  if p_cantidad > v_producido then
    raise exception 'LÍMITE EXCEDIDO: solo hay % Uds entregadas por Producción para este producto.', v_producido;
  end if;

  select id into v_usuario_id from usuarios where auth_id = auth.uid() and activo limit 1;

  insert into devoluciones_produccion (item_orden_id, causal_id, cantidad, operario_id, operario_nombre, nota)
  values (p_item_orden_id, p_causal_id, p_cantidad, v_usuario_id, p_operario_nombre, p_nota)
  returning id into v_devolucion_id;

  insert into movimientos (tipo, item_orden_id, cantidad, usuario_id, nota)
  values ('devolucion_produccion', p_item_orden_id, p_cantidad, v_usuario_id, p_nota);

  return jsonb_build_object('id', v_devolucion_id, 'item_orden_id', p_item_orden_id, 'cantidad', p_cantidad);
end;
$function$
;$ddl$;

EXECUTE $ddl$CREATE VIEW public."vista_fifo_sugerido" AS  SELECT DISTINCT ON (item_orden_id, ubicacion_id) item_orden_id,
    ubicacion_id,
    fecha AS fecha_recepcion_mas_antigua
   FROM movimientos
  WHERE (tipo = 'recepcion'::text)
  ORDER BY item_orden_id, ubicacion_id, fecha;$ddl$;

EXECUTE $ddl$CREATE VIEW public."vista_lotes" AS  SELECT l.id,
    l.numero,
    l.operario_nombre,
    l.fecha_envio,
    l.estado,
    count(li.id) AS total_lineas,
    count(*) FILTER (WHERE (li.estado = 'en_transito'::text)) AS lineas_pendientes
   FROM (lotes l
     LEFT JOIN lote_items li ON ((li.lote_id = l.id)))
  GROUP BY l.id, l.numero, l.operario_nombre, l.fecha_envio, l.estado;$ddl$;

EXECUTE $ddl$CREATE VIEW public."vista_saldos_item" AS  SELECT io.id AS item_orden_id,
    COALESCE(sum(
        CASE
            WHEN (m.tipo = 'entrega_produccion'::text) THEN m.cantidad
            ELSE 0
        END), (0)::bigint) AS producido,
    COALESCE(sum(
        CASE
            WHEN (m.tipo = 'recepcion'::text) THEN m.cantidad
            WHEN (m.tipo = 'devolucion_produccion'::text) THEN (- m.cantidad)
            ELSE 0
        END), (0)::bigint) AS recibido,
    COALESCE(sum(
        CASE
            WHEN (m.tipo = 'despacho'::text) THEN m.cantidad
            WHEN (m.tipo = 'devolucion_cliente'::text) THEN (- m.cantidad)
            ELSE 0
        END), (0)::bigint) AS despachado
   FROM (items_orden io
     LEFT JOIN movimientos m ON ((m.item_orden_id = io.id)))
  GROUP BY io.id;$ddl$;

EXECUTE $ddl$CREATE VIEW public."vista_stock_ubicacion" AS  SELECT item_orden_id,
    ubicacion_id,
    sum(
        CASE
            WHEN (tipo = 'recepcion'::text) THEN cantidad
            WHEN (tipo = 'despacho'::text) THEN (- cantidad)
            WHEN (tipo = 'devolucion_cliente'::text) THEN cantidad
            ELSE 0
        END) AS cantidad
   FROM movimientos
  WHERE (ubicacion_id IS NOT NULL)
  GROUP BY item_orden_id, ubicacion_id
 HAVING (sum(
        CASE
            WHEN (tipo = 'recepcion'::text) THEN cantidad
            WHEN (tipo = 'despacho'::text) THEN (- cantidad)
            WHEN (tipo = 'devolucion_cliente'::text) THEN cantidad
            ELSE 0
        END) > 0);$ddl$;

EXECUTE $ddl$CREATE POLICY "solo_autenticados" ON public."clientes" AS PERMISSIVE FOR ALL TO "authenticated" USING (true) WITH CHECK (true);$ddl$;

EXECUTE $ddl$CREATE POLICY "solo_autenticados" ON public."devoluciones_cliente" AS PERMISSIVE FOR ALL TO "authenticated" USING (true) WITH CHECK (true);$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.clientes FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.clientes TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.clientes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.clientes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.clientes TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.devoluciones_cliente FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.devoluciones_cliente TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.devoluciones_cliente TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.devoluciones_cliente TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.devoluciones_cliente TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.vista_fifo_sugerido FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_fifo_sugerido TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_fifo_sugerido TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_fifo_sugerido TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_fifo_sugerido TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.vista_lotes FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_lotes TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_lotes TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_lotes TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_lotes TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.vista_saldos_item FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_saldos_item TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_saldos_item TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_saldos_item TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_saldos_item TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON TABLE public.vista_stock_ubicacion FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT DELETE ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT INSERT ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT MAINTAIN ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT REFERENCES ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT SELECT ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRIGGER ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT TRUNCATE ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_stock_ubicacion TO "anon";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_stock_ubicacion TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_stock_ubicacion TO "postgres";$ddl$;

EXECUTE $ddl$GRANT UPDATE ON TABLE public.vista_stock_ubicacion TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text) FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text) TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text) TO "postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.importar_ordenes_produccion(p_ordenes jsonb, p_tallas jsonb, p_nombre_archivo text, p_storage_path text, p_usuario_nombre text) TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text) FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text) TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text) TO "postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.liberar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_operario_nombre text, p_nota text) TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text) FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text) TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text) TO "postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.recibir_lote_item(p_lote_item_id uuid, p_cantidad integer, p_ubicacion_id uuid, p_nota text, p_recibido_por text) TO "service_role";$ddl$;

EXECUTE $ddl$REVOKE ALL ON FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text) FROM PUBLIC,"anon","authenticated","service_role","postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text) TO "authenticated";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text) TO "postgres";$ddl$;

EXECUTE $ddl$GRANT EXECUTE ON FUNCTION public.registrar_no_conforme(p_item_orden_id uuid, p_cantidad integer, p_causal_id uuid, p_operario_nombre text, p_nota text) TO "service_role";$ddl$;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('actor_id',t."actor_id",'antes',t."antes",'catalogo',t."catalogo",'despues',t."despues",'fecha',t."fecha",'id',t."id",'registro_id',t."registro_id") v FROM public.admin_catalogos_historial t) original;
IF filas IS DISTINCT FROM conservacion->'public.admin_catalogos_historial' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.admin_catalogos_historial. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('actor',t."actor",'actor_id',t."actor_id",'anterior',t."anterior",'antes',t."antes",'campo',t."campo",'despues',t."despues",'fecha',t."fecha",'id',t."id",'item_id',t."item_id",'lote_antes',t."lote_antes",'lote_despues',t."lote_despues",'lote_item_id',t."lote_item_id",'motivo',t."motivo",'nuevo',t."nuevo",'orden_id',t."orden_id",'ubicacion_id',t."ubicacion_id") v FROM public.admin_correcciones t) original;
IF filas IS DISTINCT FROM conservacion->'public.admin_correcciones' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.admin_correcciones. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('actor_id',t."actor_id",'archivo',t."archivo",'fecha',t."fecha",'id',t."id",'motivo',t."motivo",'resumen',t."resumen",'version_origen',t."version_origen",'vista',t."vista") v FROM public.admin_importaciones t) original;
IF filas IS DISTINCT FROM conservacion->'public.admin_importaciones' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.admin_importaciones. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activa',t."activa",'id',t."id",'nombre',t."nombre") v FROM public.causales_devolucion t) original;
IF filas IS DISTINCT FROM conservacion->'public.causales_devolucion' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.causales_devolucion. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('actor',t."actor",'actor_id',t."actor_id",'cliente',t."cliente",'detalle',t."detalle",'fecha',t."fecha",'id',t."id",'oc',t."oc",'pedido',t."pedido",'solicitud',t."solicitud") v FROM public.despachos_oc t) original;
IF filas IS DISTINCT FROM conservacion->'public.despachos_oc' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.despachos_oc. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad',t."cantidad",'causal_id',t."causal_id",'creado_en',t."creado_en",'estado',t."estado",'id',t."id",'item_orden_id',t."item_orden_id",'nota',t."nota",'operario_id',t."operario_id",'operario_nombre',t."operario_nombre",'recibido_de_produccion',t."recibido_de_produccion") v FROM public.devoluciones_produccion t) original;
IF filas IS DISTINCT FROM conservacion->'public.devoluciones_produccion' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.devoluciones_produccion. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('creado_en',t."fecha_carga",'id',t."id",'nombre_archivo',t."nombre_archivo",'storage_path',t."storage_path") v FROM public.documentos t) original;
IF filas IS DISTINCT FROM conservacion->'public.documentos' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.documentos. Revertir transaccion.'; END IF;
IF EXISTS(SELECT 1 FROM public.importaciones) THEN RAISE EXCEPTION 'Importaciones dejo de estar vacia'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('admin_eliminado_en',t."admin_eliminado_en",'admin_fecha_entrega',t."admin_fecha_entrega",'admin_fecha_entrega_activa',t."admin_fecha_entrega_activa",'cantidad_pedida',t."cantidad_pedida",'codigo',t."codigo",'creado_en',t."creado_en",'descripcion',t."descripcion",'id',t."id",'observacion',t."observacion",'oc',t."oc",'orden_id',t."orden_id",'talla',t."talla") v FROM public.items_orden t) original;
IF filas IS DISTINCT FROM conservacion->'public.items_orden' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.items_orden. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad',t."cantidad",'es_entrega_completa',t."es_entrega_completa",'fecha',t."fecha",'id',t."id",'nota',t."nota",'persona_aliado_libera',t."persona_aliado_libera",'solicitud_id',t."solicitud_id",'usuario_produccion_nombre',t."usuario_produccion_nombre") v FROM public.liberaciones_aliados t) original;
IF filas IS DISTINCT FROM conservacion->'public.liberaciones_aliados' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.liberaciones_aliados. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad',t."cantidad",'creado_en',t."creado_en",'id',t."id",'item_orden_id',t."item_orden_id",'nota',t."nota",'operario_id',t."operario_id",'operario_nombre',t."operario_nombre",'recibido_por_logistica',t."recibido_por_logistica") v FROM public.liberaciones_no_conforme t) original;
IF filas IS DISTINCT FROM conservacion->'public.liberaciones_no_conforme' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.liberaciones_no_conforme. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad_enviada',t."cantidad_enviada",'cantidad_recibida',t."cantidad_recibida",'estado',t."estado",'fecha_recepcion',t."fecha_recepcion",'id',t."id",'item_orden_id',t."item_orden_id",'lote_id',t."lote_id",'novedad',t."novedad",'origen',t."origen",'recibido_por',t."recibido_por",'ubicacion_destino_id',t."ubicacion_destino_id") v FROM public.lote_items t) original;
IF filas IS DISTINCT FROM conservacion->'public.lote_items' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.lote_items. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('creado_en',t."creado_en",'estado',t."estado",'fecha_envio',t."fecha_envio",'id',t."id",'numero',t."numero",'operario_id',t."operario_id",'operario_nombre',t."operario_nombre") v FROM public.lotes t) original;
IF filas IS DISTINCT FROM conservacion->'public.lotes' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.lotes. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('admin_correccion_id',t."admin_correccion_id",'cantidad',t."cantidad",'despacho_oc_id',t."despacho_oc_id",'fecha',t."fecha",'id',t."id",'item_orden_id',t."item_orden_id",'lote_id',t."lote_id",'lote_item_id',t."lote_item_id",'nota',t."nota",'tipo',t."tipo",'ubicacion_id',t."ubicacion_id",'usuario_id',t."usuario_id") v FROM public.movimientos t) original;
IF filas IS DISTINCT FROM conservacion->'public.movimientos' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.movimientos. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad_solicitada',t."cantidad_solicitada",'causal_id',t."causal_id",'estado',t."estado",'fecha_solicitud',t."fecha_solicitud",'id',t."id",'item_orden_id',t."item_orden_id",'nota_solicitud',t."nota_solicitud",'persona_aliado_entrega',t."persona_aliado_entrega",'usuario_produccion_solicitud_id',t."usuario_produccion_solicitud_id",'usuario_produccion_solicitud_nombre',t."usuario_produccion_solicitud_nombre") v FROM public.no_conformes_aliados t) original;
IF filas IS DISTINCT FROM conservacion->'public.no_conformes_aliados' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.no_conformes_aliados. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cliente',t."cliente",'creado_en',t."creado_en",'fecha_esperada_logistica',t."fecha_esperada_logistica",'fecha_esperada_produccion',t."fecha_esperada_produccion",'id',t."id",'numero_op',t."numero_op") v FROM public.ordenes_produccion t) original;
IF filas IS DISTINCT FROM conservacion->'public.ordenes_produccion' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.ordenes_produccion. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activo',t."activo",'id',t."id",'nombre',t."nombre") v FROM public.personal_aliados t) original;
IF filas IS DISTINCT FROM conservacion->'public.personal_aliados' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.personal_aliados. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activo',t."activo",'id',t."id",'nombre',t."nombre") v FROM public.personal_logistica t) original;
IF filas IS DISTINCT FROM conservacion->'public.personal_logistica' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.personal_logistica. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activo',t."activo",'id',t."id",'nombre',t."nombre") v FROM public.personal_produccion t) original;
IF filas IS DISTINCT FROM conservacion->'public.personal_produccion' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.personal_produccion. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('cantidad',t."cantidad",'estado',t."estado",'fecha',t."fecha",'fecha_resolucion',t."fecha_resolucion",'id',t."id",'item_orden_id',t."item_orden_id",'lote_item_id',t."lote_item_id",'nota',t."nota",'operario_nombre',t."operario_nombre",'resolucion',t."resolucion") v FROM public.sobrantes_bodega t) original;
IF filas IS DISTINCT FROM conservacion->'public.sobrantes_bodega' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.sobrantes_bodega. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activa',t."activa",'codigo',t."codigo",'id',t."id") v FROM public.ubicaciones t) original;
IF filas IS DISTINCT FROM conservacion->'public.ubicaciones' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.ubicaciones. Revertir transaccion.'; END IF;
SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object('activo',t."activo",'auth_id',t."auth_id",'creado_en',t."creado_en",'email',t."email",'id',t."id",'nombre',t."nombre",'numero_usuario',t."numero_usuario",'rol',t."rol") v FROM public.usuarios t) original;
IF filas IS DISTINCT FROM conservacion->'public.usuarios' THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de public.usuarios. Revertir transaccion.'; END IF;

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

RAISE NOTICE 'Estructura alineada y todas las filas/valores originales conservados.';
END $alinear$;
NOTIFY pgrst,'reload schema';
COMMIT;
SELECT 'OK: PRUEBAS alineada; datos originales conservados' AS resultado;
