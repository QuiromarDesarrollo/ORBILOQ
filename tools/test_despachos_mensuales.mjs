import { PGlite } from '../.dart_tool/sql-test/node_modules/@electric-sql/pglite/dist/index.js';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
 CREATE TABLE items_orden(id uuid primary key,codigo text);
 INSERT INTO items_orden VALUES('0701856a-7771-4536-9762-658a58af8803','DEMO-001');
 CREATE FUNCTION puede_ver_dashboards() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.acceso',true),'si')='si' $$;
 CREATE TABLE despachos_oc(id int primary key,fecha timestamptz,cliente text,fase text,ediciones int);
 CREATE TABLE seguimiento_entregas(despacho_id int references despachos_oc,revision int,estado text,primary key(despacho_id,revision),constraint seguimiento_estado_valido check(estado in ('en_transito','entregado','devuelto_cliente','devolucion_parcial')));
 INSERT INTO despachos_oc VALUES
 (1,'2025-01-31T23:00:00Z','A','despachado',1),
 (2,'2025-02-01T02:00:00Z','A','despachado',0),
 (3,'2025-02-03T15:00:00Z','A','despachado',0),
 (4,'2025-02-03T15:00:00Z','B','despachado',0),
 (5,'2025-02-03T15:00:00Z','A','empacado',0),
 (6,'2025-02-08T15:00:00Z','A','despachado',0),
 (7,'2025-02-04T15:00:00Z','A','despachado',0),
 (8,'2025-02-05T15:00:00Z','A','despachado',0);
 INSERT INTO seguimiento_entregas VALUES(1,0,'entregado'),(1,1,'en_transito'),(2,0,'entregado'),(3,0,'en_transito'),(4,0,'entregado'),(7,0,'devuelto_cliente'),(8,0,'devolucion_parcial');`);
 const sql=readFileSync('sql/pruebas/096_entregado_con_novedad_dashboard.sql','utf8');
 await db.exec(sql); await db.exec(sql);
 await db.exec("UPDATE seguimiento_entregas SET estado='entregado_con_novedad' WHERE despacho_id=3;");
 const query=(cliente=null,corte='2025-03-01')=>db.query("SELECT dashboard_despachos_mensuales('2025-01-01','2025-03-31',$1,$2) datos",[cliente,corte]);
 const r=(await query('A')).rows[0].datos;
 assert.deepEqual(r,[{mes:'2025-01-01',total:2,sin_contratiempo:1,con_contratiempo:0},{mes:'2025-02-01',total:3,sin_contratiempo:0,con_contratiempo:1},{mes:'2025-03-01',total:0,sin_contratiempo:0,con_contratiempo:0}]);
 assert.equal((await query()).rows[0].datos[1].total,4);
 assert.equal((await query('A','2025-02-04')).rows[0].datos[1].total,1);
 await assert.rejects(()=>db.exec("UPDATE seguimiento_entregas SET estado='inventado' WHERE despacho_id=3"),/seguimiento_estado_valido/);
 await db.exec("SET test.acceso='no'");
 await assert.rejects(()=>query(),/Acceso exclusivo/);
 console.log('OK: nuevo estado, idempotencia, permisos, meses vacíos, cliente, corte, Bogotá, revisión vigente, fase y devoluciones.');
}finally{await db.close();}
