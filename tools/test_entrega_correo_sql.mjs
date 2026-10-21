import { PGlite } from '../.dart_tool/sql-test/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
const id='11111111-1111-4111-8111-111111111111';
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT '00000000-0000-0000-0000-000000000001'::uuid $$;
 CREATE FUNCTION seguimiento_acceso() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('test.acceso',true)='si' $$;
 SELECT set_config('test.acceso','si',false);
 CREATE TABLE items_orden(id uuid,codigo text,orden_id uuid);
 INSERT INTO items_orden(id,codigo) VALUES('0701856a-7771-4536-9762-658a58af8803','DEMO-001');
 CREATE TABLE ordenes_produccion(id uuid,numero_op text);
 CREATE TABLE despachos_oc(id uuid PRIMARY KEY,ediciones integer,fase text,cliente text,oc text,detalle jsonb);
 CREATE TABLE listas_empaque(despacho_id uuid,numero bigint,datos jsonb);
 CREATE TABLE seguimiento_entregas(despacho_id uuid,revision integer,estado text,recibido date,numero_guia text,evidencia_le jsonb,evidencia_guia jsonb,version integer,PRIMARY KEY(despacho_id,revision));
 CREATE FUNCTION seguimiento_entregas_guardar_v87(p_id uuid,p_revision integer,p_version integer,p_datos jsonb) RETURNS integer LANGUAGE plpgsql AS $$
 BEGIN
 PERFORM 1 FROM despachos_oc WHERE id=p_id FOR UPDATE;
 IF coalesce((SELECT version FROM seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision),0)<>p_version THEN RAISE EXCEPTION 'Version obsoleta'; END IF;
 INSERT INTO seguimiento_entregas VALUES(p_id,p_revision,p_datos->>'estado',(p_datos->>'recibido')::date,'GUIA',p_datos->'evidencia_le',p_datos->'evidencia_guia',p_version+1)
 ON CONFLICT(despacho_id,revision) DO UPDATE SET version=excluded.version,estado=excluded.estado,recibido=excluded.recibido;
 RETURN p_version+1; END $$;
 CREATE FUNCTION seguimiento_entregas_listar(bigint DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_array(jsonb_build_object('id','${id}','revision',0,'le',1042)) $$;
 INSERT INTO despachos_oc VALUES('${id}',0,'despachado','Cliente','OC1','[{"item_id":"0701856a-7771-4536-9762-658a58af8803"}]');
 UPDATE items_orden SET orden_id='22222222-2222-4222-8222-222222222222';
 INSERT INTO ordenes_produccion VALUES('22222222-2222-4222-8222-222222222222','26238');
 INSERT INTO listas_empaque VALUES('${id}',1042,'{"destinatario":{"nombre":"Sede principal"}}');`);
 const sql=readFileSync('sql/pruebas/117_correo_entrega.sql','utf8');await db.exec(sql);await db.exec(sql);
 await db.exec('SET ROLE authenticated');
 const save=(version,email='comercial@example.com',estado='entregado')=>db.query('select seguimiento_entregas_guardar_v117($1,0,$2,$3,$4) r',[id,version,JSON.stringify({estado,recibido:'2026-10-21'}),email]);
 await assert.rejects(save(0,'malo'),/inválido/);
 await assert.rejects(save(0,'comercial@example.com','en_transito'),/selecciona Entregado/);
 const job=(await save(0)).rows[0].r;assert.equal(job.version,1);
 assert.equal((await save(1)).rows[0].r.correo.id,job.correo.id);
 await assert.rejects(save(2,'otra@example.com'),/otro correo/);
 await assert.rejects(db.query('select * from entrega_correos'),/permission denied/);
 await assert.rejects(db.query('select entrega_correo_reclamar($1)',[job.correo.id]),/permission denied/);
 await db.exec("select set_config('test.acceso','no',false)");await assert.rejects(save(2),/Sin acceso/);
 await assert.rejects(db.query('select entrega_correo_consultar($1)',[job.correo.id]),/Sin acceso/);
 await db.exec("select set_config('test.acceso','si',false); RESET ROLE; SET ROLE service_role");
 assert.equal((await db.query('select count(*)::int n from entrega_correos')).rows[0].n,1);
 const claim=()=>db.query('select entrega_correo_reclamar($1) r',[job.correo.id]);
 const payload=(await claim()).rows[0].r;assert.deepEqual(payload.datos.ops,['26238']);assert.equal(payload.destinatario,'comercial@example.com');
 assert.equal((await claim()).rows[0].r,null);
 await db.query("update entrega_correos set estado='error' where id=$1",[job.correo.id]);
 assert.equal((await claim()).rows[0].r.id,job.correo.id);
 await db.query("update entrega_correos set estado='enviado' where id=$1",[job.correo.id]);
 assert.equal((await claim()).rows[0].r,null);
 await db.query("update entrega_correos set estado='enviando',envio_iniciado=true,intento_en=now()-interval '10 minutes' where id=$1",[job.correo.id]);
 assert.equal((await claim()).rows[0].r,null);
 assert.equal((await db.query('select estado from entrega_correos')).rows[0].estado,'revision_manual');
 console.log('OK: migración repetible, validación, transacción, permisos, snapshot OP, unicidad, reserva y envío incierto sin duplicado.');
} finally {await db.close();}
