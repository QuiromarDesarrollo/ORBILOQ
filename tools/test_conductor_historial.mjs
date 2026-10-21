import { PGlite } from '../.dart_tool/sql-test/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const admin = '00000000-0000-0000-0000-000000000001';
const conductor = '00000000-0000-0000-0000-000000000002';
const otro = '00000000-0000-0000-0000-000000000003';
try {
  for (const file of ['tools/test_conductor_fixture.sql', 'sql/pruebas/114_conductores.sql', 'sql/pruebas/115_conductor_historial_privado.sql', 'sql/pruebas/116_conductor_fotos_laterales.sql', 'sql/pruebas/116_conductor_fotos_laterales.sql']) {
    await db.exec(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  }
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [admin]);
  const id = (await db.query("select conductor_asignar_vehiculo('TEST01','Vehículo',100,'2') id")).rows[0].id;
  for (const tipo of ['Inicio de jornada','Fin de jornada','Tanqueo']) {
    await db.query(`insert into conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,creado,datos)
      values($1,$2,'Conductor A',$3,100,'2026-10-21T15:00:00Z',$4)`,
      [id, conductor, tipo, JSON.stringify({fecha:'2026-10-20',notas:'Privado',enlace:'https://drive.google.com/file/d/test/view',respuestas:{Frenos:'Buen estado'}})]);
  }
  const consulta = (desde='2026-10-20',hasta='2026-10-20',offset=0,limite=200) => db.query('select * from conductor_historial($1,$2,$3,$4,$5)',[id,desde,hasta,offset,limite]);
  await db.exec('set role authenticated');
  let rows = (await consulta()).rows.map(r => r.conductor_historial);
  assert.equal(rows.length,3);
  assert.equal(rows[0].datos.notas,'Privado');
  assert.ok((await consulta('2026-10-21','2026-10-21')).rows.every(r=>r.conductor_historial.tipo==='Asignación')); // actividad, no creación
  const paginados = [];
  for (let offset=0;offset<3;offset++) paginados.push((await consulta(undefined,undefined,offset,1)).rows[0].conductor_historial.id);
  assert.equal(new Set(paginados).size,3);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[conductor]);
  rows = (await consulta()).rows.map(r=>r.conductor_historial);
  assert.equal(rows.length,3);
  for (const r of rows) {
    assert.deepEqual(Object.keys(r).sort(),['datos','id','tipo']);
    assert.deepEqual(r.datos,{fecha:'2026-10-20'});
  }
  assert.equal((await db.query('select * from conductor_registros')).rows.length,0);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[otro]);
  await assert.rejects(consulta(),/Sin acceso/);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[admin]);
  await assert.rejects(consulta('2026-10-22','2026-10-20'),/invalido/);
  await assert.rejects(consulta(undefined,undefined,-1),/invalido/);
  await db.exec('reset role');
  for (const campo of ['foto_lateral_derecho', 'foto_lateral_izquierdo']) {
    await db.query(`insert into conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
      values($1,$2,'Conductor A','Registro diario',100,jsonb_build_object('fecha',
        (now() at time zone 'America/Bogota')::date::text,$3::text,'https://drive.google.com/file/d/lateral/view'))`, [id,conductor,campo]);
  }
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[conductor]);
  await db.exec('set role authenticated');
  const fotos = (await consulta(null,null)).rows.map(r=>r.conductor_historial).filter(r=>r.tipo==='Registro diario');
  assert.equal(fotos.length,2);
  assert.ok(fotos.every(r=>r.evidencia_registrada===true && Object.keys(r.datos).join() === 'fecha'));
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[admin]);
  await db.query('update usuarios set activo=false where auth_id=$1',[admin]);
  await db.exec('set role authenticated');
  await assert.rejects(consulta(),/Sin acceso/);
  console.log('OK: administrador, conductor, otro vehículo, inactivo, permisos directos, fechas, paginación e idempotencia.');
} finally { await db.close(); }
