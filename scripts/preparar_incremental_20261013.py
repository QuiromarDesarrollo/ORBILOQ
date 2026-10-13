"""Prepara la actualización 090-094; no se conecta ni ejecuta SQL."""
import argparse, hashlib, json, re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--diagnostico',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
diag=json.loads(Path(a.diagnostico).read_text(encoding='utf-8-sig'))
assert not any(diag['nuevas_instaladas'].values()), 'Ya hay migraciones nuevas instaladas'
def lit(v):return "'"+v.replace("'","''")+"'"
parts=["""-- CANDIDATO incremental 2026-10-13. Ensayar sobre respaldo antes de aplicar.
-- SOLO producción cxrflhgnxvomcvxzugda. No copia datos DEV ni reinicia consecutivos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regprocedure('public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)') IS NOT NULL OR to_regprocedure('public.le_importar_clientes_internacionales(jsonb)') IS NOT NULL OR to_regprocedure('public.admin_empaque_guardar_v92(uuid,text,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'Actualización ya iniciada/instalada'; END IF;
 IF to_regprocedure('public.seguimiento_acceso()') IS NULL THEN RAISE EXCEPTION 'Falta despliegue del 09'; END IF;
END $$;
DO $baseline$ BEGIN
"""]
for f in sorted(diag['funciones'],key=lambda f:f['firma']):
 parts.append(f"IF md5(replace(pg_get_functiondef(to_regprocedure({lit(f['firma'])})), E'\\r\\n', E'\\n')) IS DISTINCT FROM '{f['md5']}' THEN RAISE EXCEPTION 'Cambió función: %', {lit(f['firma'])}; END IF;\n")
parts.append("""END $baseline$;
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY,columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text,fila jsonb) ON COMMIT DROP;
CREATE TEMP TABLE previo_secuencias ON COMMIT DROP AS SELECT to_jsonb(s) fila FROM pg_sequences s WHERE schemaname='public';
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth','storage') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  IF t.nspname IN ('public','respaldo_mantenimiento') THEN EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname); END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;
""")
manifest=[]
for num in [90,91,92,93,94]:
 path=next(p for p in (root/'sql/pruebas').glob(f'{num:03}_*.sql') if 'diagnostico' not in p.name);sql=path.read_text(encoding='utf-8-sig')
 for pattern in [r"IF nullif\(current_setting\('app.settings.project_ref'.*?END IF;",r"IF NOT EXISTS\(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803'.*?END IF;"]:
  sql,count=re.subn(pattern,'',sql,count=1,flags=re.S);assert count==1
 sql=re.sub(r'^(BEGIN;|COMMIT;)\s*$','',sql,flags=re.M)
 sql=re.sub(r'^-- SOLO ORBILOQ-DEV.*$','',sql,flags=re.M)
 assert 'DEMO-001' not in sql and 'igfuafcekcpugpmsoqbe' not in sql
 parts.append('\n-- '+path.name+'\n'+sql+'\n')
 manifest.append({'fuente':path.relative_to(root).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
parts.append("""
-- Ninguna fila ni columna original puede cambiar; incluye documentos emitidos y Auth.
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
 IF EXISTS((SELECT fila FROM previo_secuencias EXCEPT ALL SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public') UNION ALL (SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public' EXCEPT ALL SELECT fila FROM previo_secuencias)) THEN RAISE EXCEPTION 'Cambió un consecutivo: rollback'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
""")
out=root/'sql/produccion/008_actualizacion_20261013.sql';out.write_text(''.join(parts),encoding='utf8')
out.with_suffix('.fuentes.json').write_text(json.dumps({'baseline_fecha':diag['fecha_utc'],'fuentes':manifest,'sql_sha256':hashlib.sha256(out.read_bytes()).hexdigest()},indent=2),encoding='utf8')
print(out)
