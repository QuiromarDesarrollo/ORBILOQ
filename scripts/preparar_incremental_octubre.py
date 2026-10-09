"""Genera candidato incremental reproducible; nunca conecta a una base de datos."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--inventario', required=True)
args = parser.parse_args()
csv.field_size_limit(10_000_000)
root = Path(__file__).resolve().parents[1]
inventory = {r['seccion']: json.loads(r['detalle_json']) for r in csv.DictReader(Path(args.inventario).open(encoding='utf-8-sig'))}
sources = [65,66,67,68,70,71,72,73,74,75,77,78,79,80,81,82,84,85,86,87,88,89]
parts = ["""-- CANDIDATO: ensayar y revisar antes de aplicar. No ejecutar junto con 002.
-- Destino previsto: cxrflhgnxvomcvxzugda. Sin datos ni catálogos DEV.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regclass('public.empaques') IS NOT NULL THEN RAISE EXCEPTION 'Actualización ya iniciada/instalada; detener'; END IF;
 IF to_regclass('public.clientes') IS NULL OR to_regclass('public.admin_correcciones') IS NULL THEN RAISE EXCEPTION 'Baseline incorrecto'; END IF;
END $$;
"""]
def literal(s):
    return "'" + s.replace("'", "''") + "'"

parts.append('DO $baseline$ BEGIN\n')
for entry in inventory['07_funciones_y_procedimientos']:
    f = entry['detalle']
    types = ','.join(a.split(' ', 1)[1] for a in f['firma'].split(', ')) if f['firma'] else ''
    sig = f"public.{f['nombre']}({types})"
    digest = hashlib.md5(f['definicion'].replace('\r\n','\n').encode()).hexdigest()
    parts.append(f"IF md5(replace(pg_get_functiondef(to_regprocedure({literal(sig)})), E'\\r\\n', E'\\n')) IS DISTINCT FROM '{digest}' THEN RAISE EXCEPTION 'Función cambió: {f['nombre']}'; END IF;\n")
parts.append('END $baseline$;\n')
parts.append("""
-- Captura todas las columnas originales y filas operativas; aborta si cambia alguna.
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY, columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text, fila jsonb) ON COMMIT DROP;
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  -- Auth pertenece al servicio gestionado: se compara, pero no se bloquea.
  IF t.nspname<>'auth' THEN
   EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname);
  END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;
""")
manifest = []
for number in sources:
    matches = list((root/'sql/pruebas').glob(f'{number:03}_*.sql'))
    assert len(matches) == 1, number
    path = matches[0]
    raw = path.read_text(encoding='utf-8-sig')
    sql = raw
    # Remove only the two explicit DEV identity checks, retaining dependency checks.
    for pattern in [r"IF nullif\(current_setting\('app.settings.project_ref'.*?END IF;", r"IF NOT EXISTS\(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803'.*?END IF;"]:
        sql, count = re.subn(pattern, '', sql, count=1, flags=re.S)
        assert count == 1, (number, pattern)
    sql = re.sub(r'^BEGIN;\s*$', '', sql, flags=re.M)
    sql = re.sub(r'^COMMIT;\s*$', '', sql, flags=re.M)
    sql = re.sub(r'^--.*$', '', sql, flags=re.M)
    if number == 71:
        # Restrict WMS policies to its tables; leave unrelated ERP policies intact.
        allowed = ['usuarios','ubicaciones','causales_devolucion','personal_logistica','personal_produccion','personal_aliados','ordenes_produccion','items_orden','movimientos','lotes','lote_items','devoluciones_produccion','liberaciones_no_conforme','no_conformes_aliados','liberaciones_aliados','sobrantes_bodega','despachos_oc','admin_correcciones','empaques']
        anchor = "AND c.relkind='r' AND c.relrowsecurity LOOP"
        assert sql.count(anchor) == 1
        sql = sql.replace(anchor, "AND c.relkind='r' AND c.relrowsecurity AND c.relname IN ("+','.join(map(literal,allowed))+") LOOP")
        sql = sql.replace('ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.wms_cuenta_operativa())', "ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa())")
        sql = sql.replace('ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.wms_cuenta_operativa()) WITH CHECK(public.wms_cuenta_operativa())', "ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa()) WITH CHECK(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa())")
        sql = sql.replace('ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(public.wms_cuenta_operativa())', "ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id NOT IN ('documentos','seguimiento-evidencias') OR public.wms_cuenta_operativa())")
    assert 'DEMO-001' not in sql and 'igfuafcekcpugpmsoqbe' not in sql
    parts.append(f'\n-- Adaptación {path.name}\n{sql}\n')
    manifest.append({'fuente':path.relative_to(root).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
parts.append("""
-- Completa las suscripciones usadas por el repositorio sin quitar tablas existentes.
DO $$ DECLARE tabla text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables) THEN
  FOREACH tabla IN ARRAY ARRAY['items_orden','ordenes_produccion','movimientos','lotes','lote_items','reservas_despacho'] LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=tabla) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',tabla);
   END IF;
  END LOOP;
 END IF;
END $$;
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
END $$;
-- Consecutivo confirmado por el usuario: próxima LE 3000 por instrucción expresa del usuario.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero>=3000) THEN RAISE EXCEPTION 'Consecutivo LE ocupado'; END IF;
 IF EXISTS(SELECT 1 FROM public.lista_empaque_config WHERE siguiente IS NOT NULL) THEN RAISE EXCEPTION 'Consecutivo ya configurado'; END IF;
 UPDATE public.lista_empaque_config SET siguiente=3000 WHERE id=true;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
""")
out = root/'sql/produccion/005_actualizacion_20261009.sql'
out.write_text(''.join(parts),encoding='utf-8')
(out.with_suffix('.fuentes.json')).write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'Candidato generado: {out.name}; {len(sources)} fuentes; requiere ensayo.')
