import {PGlite} from '../.dart_tool/sql-test/node_modules/@electric-sql/pglite/dist/index.js';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
 CREATE FUNCTION puede_ver_dashboards() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.acceso',true),'si')='si' $$;
 CREATE TABLE ordenes_produccion(id int primary key,fecha_esperada_logistica date);
 CREATE TABLE items_orden(id text primary key,codigo text,orden_id int);
 INSERT INTO items_orden VALUES('0701856a-7771-4536-9762-658a58af8803','DEMO-001',null),('i1','C',1),('i2','C',2),('i3','C',3);
 INSERT INTO ordenes_produccion VALUES(1,'2025-02-03'),(2,'2025-02-07'),(3,null);
 CREATE TABLE despachos_oc(id int primary key,fecha timestamptz,cliente text,fase text,detalle jsonb);
 INSERT INTO despachos_oc VALUES
 (1,'2025-02-04T02:00Z','A','despachado','[{"item_id":"i1"},{"item_id":"i1"}]'),
 (2,'2025-02-04T15:00Z','A','despachado','[{"item_id":"i1"},{"item_id":"i2"}]'),
 (3,'2025-02-04T15:00Z','A','despachado','[{"item_id":"i2"},{"item_id":"i3"}]'),
 (4,'2025-02-04T15:00Z','B','despachado','[{"item_id":"i2"}]'),
 (5,'2025-02-04T15:00Z','A','empacado','[{"item_id":"i1"}]'),
 (6,'2025-02-08T15:00Z','A','despachado','[{"item_id":"i1"}]');`);
 const sql=readFileSync('sql/pruebas/100_dashboard_puntualidad_mensual.sql','utf8');
 await db.exec(sql);await db.exec(sql);
 const query=async(cliente='A',corte='2025-04-01')=>(await db.query("SELECT dashboard_puntualidad_mensual('2025-02-01','2025-03-31',$1,$2) datos",[cliente,corte])).rows[0].datos;
 assert.deepEqual(await query(),[{mes:'2025-02-01',total:3,a_tiempo:1,con_retraso:1,sin_fecha:1},{mes:'2025-03-01',total:0,a_tiempo:0,con_retraso:0,sin_fecha:0}]);
 assert.equal((await query(null))[0].total,4);
 assert.equal((await query('A','2025-02-04T03:00Z'))[0].total,1);
 await db.exec(`INSERT INTO despachos_oc VALUES(7,'2025-02-04T15:00Z','A','despachado','[]'),(8,'2025-02-04T15:00Z','A','despachado','[{"item_id":"no-existe"}]')`);
 assert.equal((await query())[0].sin_fecha,3);
 await db.exec("SET test.acceso='no'");await assert.rejects(()=>query(),/Sin acceso/);
 console.log('OK: por LE, varias OP, igualdad de fechas, retrasos, faltantes, Bogotá, cliente, corte, fase, permisos e idempotencia.');
}finally{await db.close();}
