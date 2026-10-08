// Generador específico de los inventarios del 05-10-2026. No conecta a Supabase.
import fs from 'node:fs';
import crypto from 'node:crypto';
const [prodPath, devPath] = process.argv.slice(2);
if (!prodPath || !devPath) throw Error('Indicar CSV de producción y CSV de pruebas.');
function csv(text) {
  const rows=[]; let row=[], value='', quoted=false;
  for(let i=0;i<text.length;i++) { const c=text[i];
    if(c==='"') { if(quoted&&text[i+1]==='"'){value+='"';i++;}else quoted=!quoted; }
    else if(c===','&&!quoted){row.push(value);value='';}
    else if(c==='\n'&&!quoted){row.push(value.replace(/\r$/,''));rows.push(row);row=[];value='';}
    else value+=c;
  }
  if(quoted)throw Error('CSV truncado');
  if(value||row.length){row.push(value);rows.push(row);}
  const headers=rows.shift();
  return rows.filter(r=>r.length>1).map(r=>Object.fromEntries(headers.map((h,i)=>[h,r[i]])));
}
function load(path) {
  const rows=csv(fs.readFileSync(path,'utf8').replace(/^\uFEFF/,''));
  const result={};
  for(const r of rows) { const a=JSON.parse(r.detalle_json.replace(/("(?:maximo|minimo)"\s*:\s*)(-?\d+)/g,'$1"$2"'));
    if(a.length!==Number(r.cantidad_objetos)||rows.length!==Number(r.total_filas_exportacion))throw Error('Inventario incompleto');
    result[r.seccion]=a;
  } return result;
}
const p=load(prodPath), d=load(devPath);
const sec=(x,prefix)=>x[Object.keys(x).find(k=>k.startsWith(prefix))]??[];
const map=(x,s)=>new Map(sec(x,s).map(r=>[r.objeto,r.detalle]));
const q=s=>'"'+s.replaceAll('"','""')+'"';
const lit=s=>"'"+s.replaceAll("'","''")+"'";
const norm=s=>s?.replaceAll('\r\n','\n');
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const relP=map(p,'02'), relD=map(d,'02'), colsP=map(p,'03'),colsD=map(d,'03');
const tables=[...relD].filter(([,v])=>v.tipo==='r').map(([k])=>k);
const kept=['02','03','04','05','06','07','08','09','10','11','12','13','14','16','17','18'];
function clean(s,v){const x={...v};delete x.filas_estimadas_no_exactas;delete x.posicion;
  if(['02','07'].includes(s.slice(0,2)))delete x.acl; // grants normalizados por separado
  if(x.definicion)x.definicion=norm(x.definicion);return x;}
function expected(x){return Object.entries(x).filter(([s])=>kept.includes(s.slice(0,2))).flatMap(([s,rows])=>rows.map(r=>({s,o:r.objeto,d:clean(s,r.detalle)})));}
// Representación de jsonb::text: claves ordenadas por longitud UTF-8 y bytes.
// Se contrasta contra PostgreSQL real en el ensayo. No depende del locale del SO.
function jsonbText(v) {
 if(Array.isArray(v))return '['+v.map(jsonbText).join(', ')+']';
 if(v!==null&&typeof v==='object')return '{'+Object.keys(v).sort((a,b)=>Buffer.byteLength(a)-Buffer.byteLength(b)||Buffer.compare(Buffer.from(a),Buffer.from(b))).map(k=>JSON.stringify(k)+': '+jsonbText(v[k])).join(', ')+'}';
 return JSON.stringify(v);
}
const sha=s=>crypto.createHash('sha256').update(s,'utf8').digest('hex');
function signatures(x){const groups={};for(const row of expected(x))(groups[row.s]??=[]).push(sha(jsonbText(row)));
 return Object.fromEntries(Object.entries(groups).map(([s,hashes])=>[s,sha(hashes.sort().join('\n'))]));}
const inv=fs.readFileSync('sql/diagnostico/exportar_estructura.sql','utf8');
const cte=inv.slice(inv.indexOf('WITH\n')>=0?inv.indexOf('WITH\n'):inv.indexOf('WITH\r\n'), inv.lastIndexOf('SELECT seccion, cantidad_objetos,'));
const normalized=`(detalle - 'filas_estimadas_no_exactas' - 'posicion'
  - CASE WHEN left(seccion,2) IN ('02','07') THEN 'acl' ELSE '_sin_campo_' END)
  || CASE WHEN detalle ? 'definicion' THEN jsonb_build_object('definicion',replace(detalle->>'definicion', E'\\r\\n', E'\\n')) ELSE '{}'::jsonb END
  || CASE WHEN left(seccion,2)='14' THEN jsonb_build_object('maximo',detalle->>'maximo','minimo',detalle->>'minimo') ELSE '{}'::jsonb END`;
const actual=`${cte}
SELECT coalesce(jsonb_object_agg(seccion,firma),'{}'::jsonb)
FROM (
 SELECT seccion,encode(sha256(convert_to(string_agg(huella,E'\\n' ORDER BY huella COLLATE "C"),'UTF8')),'hex') AS firma
 FROM (
  SELECT seccion,encode(sha256(convert_to(jsonb_build_object('s',seccion,'o',objeto,'d',v)::text,'UTF8')),'hex') AS huella
  FROM (SELECT seccion,objeto,${normalized} AS v FROM objetos WHERE left(seccion,2) IN (${kept.map(lit).join(',')})) n
 ) huellas GROUP BY seccion
) firmas`;
function check(x,label){return `
-- SHA256 por objeto y sección: valida el inventario completo sin incrustarlo.
esperado := $inventario$${JSON.stringify(signatures(x))}$inventario$::jsonb;
actual := (${actual});
IF actual IS DISTINCT FROM esperado THEN
 SELECT string_agg(coalesce(a.key,b.key), ', ' ORDER BY coalesce(a.key,b.key)) INTO diferencia
 FROM jsonb_each_text(actual) a FULL JOIN jsonb_each_text(esperado) b ON a.key=b.key
 WHERE a.value IS DISTINCT FROM b.value;
 RAISE EXCEPTION '${label}: %. No se guardaron cambios.',diferencia;
END IF;\n`;}
const ops=[];
const add=s=>ops.push(s.endsWith(';')?s:s+';');
const column=c=>`${q(c.columna)} ${c.tipo}${c.default_o_expresion?' DEFAULT '+c.default_o_expresion:''}${c.no_nulo?' NOT NULL':''}`;
// Las dos tablas sin filas permiten retirar las tres columnas antiguas sin perder valores.
// Renombrar fechas en vez de regenerarlas. Sus dependencias de vistas se conservan.
add('ALTER TABLE public.documentos RENAME COLUMN creado_en TO fecha_carga');
add('ALTER TABLE public.importaciones RENAME COLUMN creado_en TO fecha');
// La vista de auditoría dependía de usuario_nombre y se reemplaza más abajo.
const audit=map(p,'06').get('public.admin_reporte_auditoria_interno');
for(const [name,r] of relP)if(r.tipo==='r'&&!relD.has(name)) {
 add(`CREATE TABLE ${name} (\n${[...colsP.values()].filter(c=>c.tabla===r.nombre).sort((a,b)=>a.posicion-b.posicion).map(column).join(',\n')}\n)`);
 add(`ALTER TABLE ${name} ${r.rls_habilitado?'ENABLE':'DISABLE'} ROW LEVEL SECURITY`);
}
for(const [name,c] of colsP) {
 const r=relP.get('public.'+c.tabla);if(r.tipo!=='r'||!relD.has('public.'+c.tabla))continue;
 if(name==='public.documentos.fecha_carga'||name==='public.importaciones.fecha')continue;
 const old=colsD.get(name);
 if(!old){if(name==='public.movimientos.creado_en') {
   add('ALTER TABLE public.movimientos ADD COLUMN creado_en timestamp with time zone');
   add('UPDATE public.movimientos SET creado_en=fecha');
   add('ALTER TABLE public.movimientos ALTER COLUMN creado_en SET DEFAULT now(), ALTER COLUMN creado_en SET NOT NULL');
 } else add(`ALTER TABLE public.${q(c.tabla)} ADD COLUMN ${column(c)}`);}
 else {
  if(c.tipo!==old.tipo)throw Error('Cambio de tipo no revisado: '+name);
  if(c.default_o_expresion!==old.default_o_expresion)add(`ALTER TABLE public.${q(c.tabla)} ALTER COLUMN ${q(c.columna)} ${c.default_o_expresion?'SET DEFAULT '+c.default_o_expresion:'DROP DEFAULT'}`);
  if(c.no_nulo!==old.no_nulo)add(`ALTER TABLE public.${q(c.tabla)} ALTER COLUMN ${q(c.columna)} ${c.no_nulo?'SET':'DROP'} NOT NULL`);
 }
}
add(`CREATE OR REPLACE VIEW public.admin_reporte_auditoria_interno AS ${audit.definicion}`);
add('ALTER TABLE public.importaciones DROP COLUMN usuario_nombre');
const cp=map(p,'04'),cd=map(d,'04');
// Mismo CHECK, distinto nombre: no se desactiva la validación.
add('ALTER TABLE public.no_conformes_aliados RENAME CONSTRAINT no_conformes_aliados_cantidad_check TO no_conformes_aliados_cantidad_solicitada_check');
for(const [k,v] of [...cp].sort((a,b)=>(a[1].tipo==='f')-(b[1].tipo==='f'))){
 if(k.endsWith('no_conformes_aliados_cantidad_solicitada_check'))continue;
 const old=cd.get(k);
 if(old&&norm(old.definicion)===norm(v.definicion)&&old.validada===v.validada)continue;
 if(old)add(`ALTER TABLE public.${q(v.tabla)} DROP CONSTRAINT ${q(v.nombre)}`);
 add(`ALTER TABLE public.${q(v.tabla)} ADD CONSTRAINT ${q(v.nombre)} ${v.definicion}`);
}
const ip=map(p,'05'),id=map(d,'05');
for(const [k,v] of ip)if(!id.has(k)&&!sec(p,'04').some(c=>c.detalle.nombre===v.nombre))add(v.definicion);
add('DROP INDEX public.idx_movimientos_lote');
const fp=map(p,'07'),fd=map(d,'07');
// Quitar defaults requiere DROP + CREATE; sin CASCADE para abortar ante dependencias nuevas.
for(const [k,v] of fd)if(!fp.has(k)||v.argumentos_con_defaults!==fp.get(k).argumentos_con_defaults)add(`DROP FUNCTION ${k}`);
for(const [k,v] of fp)if(!fd.has(k)||norm(v.definicion)!==norm(fd.get(k).definicion))add(v.definicion);
function viewOrder(x) {
 const pending=sec(x,'06').map(r=>r.detalle), out=[];
 while(pending.length){const n=pending.findIndex(v=>!pending.some(w=>w!==v&&new RegExp('\\b'+w.nombre+'\\b').test(v.definicion)));
  if(n<0)throw Error('Dependencia circular en vistas');out.push(pending.splice(n,1)[0]);}return out;
}
for(const v of viewOrder(p))if(!map(d,'06').has('public.'+v.nombre))add(`CREATE VIEW public.${q(v.nombre)}${v.opciones?' WITH ('+v.opciones.join(',')+')':''} AS ${v.definicion}`);
for(const r of sec(p,'09'))if(!map(d,'09').has(r.objeto)){const v=r.detalle;
 add(`CREATE POLICY ${q(v.nombre)} ON public.${q(v.tabla)} AS ${v.permisiva?'PERMISSIVE':'RESTRICTIVE'} FOR ${{'*':'ALL',r:'SELECT',a:'INSERT',w:'UPDATE',d:'DELETE'}[v.comando]} TO ${v.roles.map(q).join(',')}${v.using?' USING ('+v.using+')':''}${v.with_check?' WITH CHECK ('+v.with_check+')':''}`);
}
// Igualar los permisos de cada objeto creado/recreado, sin grants amplios al esquema.
const changedRelations=[...relP].filter(([k])=>!relD.has(k)).map(([k])=>k);
const recreatedFunctions=[...fp].filter(([k,v])=>!fd.has(k)||fd.get(k).argumentos_con_defaults!==v.argumentos_con_defaults).map(([k])=>k);
function grants(x,s,object,kind){const a=sec(x,s).filter(r=>r.objeto===object).map(r=>r.detalle);
 const roles=[...new Set(['PUBLIC','anon','authenticated','service_role',...a.map(r=>r.beneficiario)])];
 const sql=[`REVOKE ALL ON ${kind} ${object} FROM ${roles.map(r=>r==='PUBLIC'?'PUBLIC':q(r)).join(',')};`];
 for(const g of a){if(g.otorgante!=='postgres')throw Error('Otorgante no contemplado');sql.push(`GRANT ${g.privilegio} ON ${kind} ${object} TO ${g.beneficiario==='PUBLIC'?'PUBLIC':q(g.beneficiario)}${g.puede_otorgar?' WITH GRANT OPTION':''};`);}return sql;
}
for(const k of changedRelations)for(const s of grants(p,'10',k,'TABLE'))add(s);
for(const k of recreatedFunctions)for(const s of grants(p,'11',k,'FUNCTION'))add(s);
const beforeCheck=check(d,'La estructura de PRUEBAS cambió desde el inventario');
const afterCheck=check(p,'La estructura resultante no coincide con PRODUCCION');
const snapshot=`FOR tabla IN SELECT unnest(ARRAY[${tables.map(lit).join(',')}]::text[]) LOOP
 EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),''[]''::jsonb) FROM %s t',tabla) INTO filas;
 conservacion := conservacion || jsonb_build_object(tabla,filas);
END LOOP;`;
const verifyData=tables.map(t=>{
const keys=[...colsD.values()].filter(c=>'public.'+c.tabla===t).map(c=>`${lit(c.columna)},t.${q(c.columna==='creado_en'&&t==='public.documentos'?'fecha_carga':c.columna==='creado_en'&&t==='public.importaciones'?'fecha':c.columna)}`);
if(t==='public.importaciones')return `IF EXISTS(SELECT 1 FROM public.importaciones) THEN RAISE EXCEPTION 'Importaciones dejo de estar vacia'; END IF;`;
return `SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) INTO filas FROM (SELECT jsonb_build_object(${keys.join(',')}) v FROM ${t} t) original;
IF filas IS DISTINCT FROM conservacion->${lit(t)} THEN RAISE EXCEPTION 'Cambio inesperado en datos originales de ${t}. Revertir transaccion.'; END IF;`;}).join('\n');
const ddl=ops.map(s=>`EXECUTE $ddl$${norm(s)}$ddl$;`).join('\n\n');
const header=`/* ORBILOQ — SOLO PRUEBAS igfuafcekcpugpmsoqbe. NO EJECUTAR EN PRODUCCION.
 Ejecutar archivo COMPLETO en SQL Editor, sin seleccionar fragmentos.
 Una sola transaccion; aborta si cambió el esquema o los datos no cumplen.
 No copia datos de produccion ni modifica auth.users o Storage.
 Conserva todas las filas y valores originales; documentos/importaciones deben estar vacios.
 movimientos.creado_en se inicializa con fecha (aproximacion historica, no fecha de migracion).
 Si Supabase avisa de operaciones destructivas, corresponden a columnas vacias,
 un indice y funciones/restricciones reemplazadas dentro de esta transaccion.
 No crea tablas temporales ni requiere agregar RLS desde el editor.
 Origen CSV SHA256: ${crypto.createHash('sha256').update(fs.readFileSync(devPath)).digest('hex')}
 Referencia CSV SHA256: ${crypto.createHash('sha256').update(fs.readFileSync(prodPath)).digest('hex')}
*/\n`;
const guard=`IF current_setting('app.settings.project_ref',true) = 'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'PRODUCCION: ejecucion prohibida'; END IF;
IF to_regclass('public.clientes') IS NOT NULL OR to_regclass('public.devoluciones_cliente') IS NOT NULL THEN RAISE EXCEPTION 'Base incorrecta o migracion ya aplicada: no continuar'; END IF;
IF EXISTS(SELECT 1 FROM public.documentos) OR EXISTS(SELECT 1 FROM public.importaciones) THEN RAISE EXCEPTION 'Documentos/importaciones ya tienen datos: solicitar nueva revision'; END IF;`;
const output='sql/alinear_pruebas';fs.mkdirSync(output,{recursive:true});
fs.writeFileSync(`${output}/000_exportar_datos_pruebas.sql`, `/* SOLO LECTURA. Ejecutar en PRUEBAS antes de 002 y guardar el resultado CSV
   FUERA del repositorio: respaldo_datos_pruebas_20261005.csv.
   Exporta las 22 tablas public originales. Contiene datos privados: no subir a GitHub.
   Conservar también estructura_pruebas_actual.csv para reconstruir el esquema original.
   No es un respaldo de Auth ni de los archivos fisicos de Storage; 002 no los modifica.
   Se obtiene una sola instantanea para todas las tablas. Debe devolver 22 filas.
*/
WITH respaldo AS (
${tables.map(t=>`SELECT ${lit(t)} AS tabla, count(*) AS cantidad_filas,
 coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text AS filas_json FROM ${t} t`).join('\nUNION ALL\n')}
)
SELECT tabla,cantidad_filas,filas_json,statement_timestamp() AS fecha_exportacion,
 count(*) OVER () AS total_tablas FROM respaldo ORDER BY tabla;
`);
fs.writeFileSync(`${output}/002_alinear_solo_pruebas.sql`,header+`BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='180s';
SET LOCAL search_path=public,extensions;
DO $alinear$
DECLARE esperado jsonb; actual jsonb; diferencia text; conservacion jsonb:='{}'; filas jsonb; tabla text;
BEGIN
${guard}
LOCK TABLE ${tables.join(',')} IN ACCESS EXCLUSIVE MODE;
${beforeCheck}
${snapshot}
${ddl}
${verifyData}
${afterCheck}
RAISE NOTICE 'Estructura alineada y todas las filas/valores originales conservados.';
END $alinear$;
NOTIFY pgrst,'reload schema';
COMMIT;
SELECT 'OK: PRUEBAS alineada; datos originales conservados' AS resultado;
`);
fs.writeFileSync(`${output}/003_verificar_estructura.sql`, `/* SOLO LECTURA. Ejecutar en PRUEBAS despues de 002. No requiere cambiar RLS. */
BEGIN READ ONLY;
SET LOCAL search_path=public,extensions;
DO $verificar$
DECLARE esperado jsonb; actual jsonb; diferencia text;
BEGIN
${afterCheck}
END $verificar$;
COMMIT;
SELECT 'OK: estructura de public coincide con la referencia de produccion del 05-10-2026' AS resultado;
`);
// Fixture local sin datos reales: reproduce ambos inventarios para ensayar el delta.
function fixture(x){const a=['CREATE SCHEMA auth; CREATE SCHEMA extensions;',
 'CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting(\'request.jwt.claim.sub\',true),\'\')::uuid $$;',
 'CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);',
 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions; CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;',
 'SET search_path=public,extensions; SET check_function_bodies=false;'];
 for(const row of sec(x,'14')){const v=row.detalle;a.push(`CREATE SEQUENCE public.${q(v.nombre)} AS ${v.tipo} START ${v.inicio};`);}
 for(const row of sec(x,'02').filter(r=>r.detalle.tipo==='r')){const v=row.detalle;a.push(`CREATE TABLE public.${q(v.nombre)} (${sec(x,'03').map(r=>r.detalle).filter(c=>c.tabla===v.nombre).sort((a,b)=>a.posicion-b.posicion).map(column).join(',')});`);
 if(v.rls_habilitado)a.push(`ALTER TABLE public.${q(v.nombre)} ENABLE ROW LEVEL SECURITY;`);}
 for(const row of sec(x,'04').sort((a,b)=>(a.detalle.tipo==='f')-(b.detalle.tipo==='f'))){const v=row.detalle;a.push(`ALTER TABLE public.${q(v.tabla)} ADD CONSTRAINT ${q(v.nombre)} ${v.definicion};`);}
 for(const row of sec(x,'05'))if(!sec(x,'04').some(c=>c.detalle.nombre===row.detalle.nombre))a.push(row.detalle.definicion+';');
 for(const row of sec(x,'07'))a.push(row.detalle.definicion+';');
 for(const v of viewOrder(x))a.push(`CREATE VIEW public.${q(v.nombre)}${v.opciones?' WITH ('+v.opciones.join(',')+')':''} AS ${v.definicion};`);
 for(const row of sec(x,'09')){const v=row.detalle;a.push(`CREATE POLICY ${q(v.nombre)} ON public.${q(v.tabla)} AS ${v.permisiva?'PERMISSIVE':'RESTRICTIVE'} FOR ${{'*':'ALL',r:'SELECT',a:'INSERT',w:'UPDATE',d:'DELETE'}[v.comando]} TO ${v.roles.map(q).join(',')}${v.using?' USING ('+v.using+')':''}${v.with_check?' WITH CHECK ('+v.with_check+')':''};`);}
 for(const row of sec(x,'02'))a.push(...grants(x,'10',row.objeto,row.detalle.tipo==='S'?'SEQUENCE':'TABLE'));
 for(const row of sec(x,'07'))a.push(...grants(x,'11',row.objeto,'FUNCTION'));
 for(const row of sec(x,'16')){const v=row.detalle;a.push(`CREATE PUBLICATION ${q(v.nombre)}${v.tablas_en_alcance?.length?' FOR TABLE '+v.tablas_en_alcance.map(t=>q(t.esquema)+'.'+q(t.tabla)).join(','):''};`);}
 for(const owner of ['postgres','supabase_admin'])for(const kind of ['TABLES','SEQUENCES','FUNCTIONS'])a.push(`ALTER DEFAULT PRIVILEGES FOR ROLE ${q(owner)} IN SCHEMA public GRANT ALL ON ${kind} TO postgres,anon,authenticated,service_role;`);
 for(const row of sec(x,'07'))if(row.detalle.comentario)a.push(`COMMENT ON FUNCTION ${row.objeto} IS ${lit(row.detalle.comentario)};`);
 for(const row of sec(x,'02'))if(row.detalle.comentario)a.push(`COMMENT ON ${row.detalle.tipo==='v'?'VIEW':'TABLE'} ${row.objeto} IS ${lit(row.detalle.comentario)};`);
 for(const row of sec(x,'03'))if(row.detalle.comentario)a.push(`COMMENT ON COLUMN ${row.objeto} IS ${lit(row.detalle.comentario)};`);
 return a.join('\n');}
fs.mkdirSync('.dart_tool/alinear',{recursive:true});
fs.writeFileSync('.dart_tool/alinear/fixture-pruebas.sql',fixture(d));
fs.writeFileSync('.dart_tool/alinear/fixture-produccion.sql',fixture(p));
fs.writeFileSync('.dart_tool/alinear/verificar-origen.sql',`SET search_path=public,extensions; DO $v$ DECLARE esperado jsonb; actual jsonb; diferencia text; BEGIN ${beforeCheck} END $v$;`);
console.log(JSON.stringify({operaciones:ops.length,tablas_preservadas:tables.length,bytes_sql:fs.statSync(`${output}/002_alinear_solo_pruebas.sql`).size}));
