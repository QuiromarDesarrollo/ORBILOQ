// Ensayo aislado con las filas del diagnostico y las relaciones relevantes.
// No conecta con Supabase ni ejecuta contra una base externa.
import { PGlite } from '../.dart_tool/sql-test/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const sql=readFileSync('sql/diagnostico/reiniciar_op_90006_pruebas.sql','utf8');
const rows=JSON.parse(sql.split('$evidencia$')[1]);
const tables=['ordenes_produccion','items_orden','documentos','devoluciones_cliente','liberaciones_aliados','no_conformes_aliados','liberaciones_no_conforme','devoluciones_produccion','sobrantes_bodega','movimientos','admin_correcciones','lote_items','lotes','listas_empaque','despacho_revisiones','empaque_solicitudes','seguimiento_entregas','reservas_despacho','despachos_oc'];
const quote=s=>'"'+s.replaceAll('"','""')+'"';
async function fixture(){
 const db=new PGlite();
 await db.exec('CREATE ROLE anon; CREATE ROLE authenticated;');
 for(const t of tables){
  const data=rows.filter(x=>x.tabla===t).map(x=>x.fila);
  const keys=[...new Set(data.flatMap(Object.keys))];
  if(!keys.length)keys.push('id');
  const defs=keys.map(k=>{
   const v=data.map(x=>x[k]).find(v=>v!==null&&v!==undefined);
   const type=typeof v==='number'?'bigint':typeof v==='boolean'?'boolean':v&&typeof v==='object'?'jsonb':'text';
   return quote(k)+' '+type;
  });
  const pk=keys.includes('id')?'id':keys.includes('despacho_id')?'despacho_id':'solicitud';
  await db.exec(`CREATE TABLE ${t} (${defs.join(',')}, PRIMARY KEY(${quote(pk)}));`);
  for(const d of data)await db.query(`INSERT INTO ${t} SELECT * FROM jsonb_populate_record(NULL::${t},$1::jsonb)`,[JSON.stringify(d)]);
 }
 for(const [t,col,parent] of [
 ['items_orden','orden_id','ordenes_produccion'],['movimientos','item_orden_id','items_orden'],
 ['movimientos','lote_id','lotes'],['movimientos','lote_item_id','lote_items'],
 ['movimientos','despacho_oc_id','despachos_oc'],['movimientos','despacho_revision_id','despacho_revisiones'],
 ['lote_items','lote_id','lotes'],['lote_items','item_orden_id','items_orden'],
 ['despacho_revisiones','despacho_id','despachos_oc'],['listas_empaque','despacho_id','despachos_oc'],
 ['seguimiento_entregas','despacho_id','despachos_oc']])
 await db.exec(`ALTER TABLE ${t} ADD FOREIGN KEY (${col}) REFERENCES ${parent}(id);`);
 await db.exec(`CREATE VIEW vista_kardex AS SELECT o.numero_op,i.codigo,i.talla,i.cantidad_pedida,
 coalesce(sum(CASE m.tipo WHEN 'entrega_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0) producido,
 coalesce(sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END),0) recibido,
 coalesce(sum(CASE WHEN m.tipo='despacho' THEN m.cantidad ELSE 0 END),0) despachado,
 coalesce(sum(CASE m.tipo WHEN 'devolucion_produccion' THEN m.cantidad WHEN 'liberacion_no_conforme' THEN -m.cantidad ELSE 0 END),0) pendiente_reproceso,
 0 AS pendiente_aliados FROM items_orden i JOIN ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN movimientos m ON m.item_orden_id=i.id GROUP BY o.numero_op,i.id;`);
 await db.exec("INSERT INTO ordenes_produccion(id,numero_op,cliente) VALUES('otra-op','90005','OTRO'); INSERT INTO items_orden(id,orden_id,codigo,talla,cantidad_pedida) VALUES('otra-linea','otra-op','TEST-90005','M',99); INSERT INTO movimientos(id,item_orden_id,tipo,cantidad) VALUES('otro-mov','otra-linea','recepcion',7);");
 return db;
}
let db=await fixture();
try{
 await db.exec(sql);
 const actual=(await db.query("SELECT * FROM vista_kardex WHERE numero_op='90006'")).rows;
 assert.equal(actual.length,2);
 assert.equal(actual.reduce((n,r)=>n+Number(r.cantidad_pedida),0),30);
 assert(actual.every(r=>Number(r.producido)===0&&Number(r.recibido)===0&&Number(r.despachado)===0));
 assert.equal((await db.query("SELECT recibido FROM vista_kardex WHERE numero_op='90005'")).rows[0].recibido, '7');
 const backup=(await db.query('SELECT datos FROM respaldo_pruebas.reinicios')).rows[0].datos;
 assert.equal(backup.movimientos.length,17);
 await assert.rejects(()=>db.exec(sql),/ya ejecutado/);
 await db.exec('ROLLBACK');
 console.log('OK: reinicio, respaldo, otra OP intacta y bloqueo de segunda ejecucion.');
}finally{await db.close();}
for(const [change,pattern] of [
 ["UPDATE movimientos SET cantidad=11 WHERE id='c5ad480f-f135-4790-ab67-8122ef2593d7'",/Cambios en movimientos/],
 ["INSERT INTO lote_items(id,lote_id,item_orden_id) VALUES('compartido','72810e2c-a6eb-415c-b110-255de669e387','otra-linea')",/Dependencia nueva o compartida/]
]){
 db=await fixture();
 try{
  await db.exec(change);
  await assert.rejects(()=>db.exec(sql),pattern);
  await db.exec('ROLLBACK');
  assert.equal((await db.query('SELECT count(*)::integer n FROM movimientos')).rows[0].n,18);
  console.log('OK: cambio o dependencia compartida cancela sin borrar movimientos.');
 }finally{await db.close();}
}
