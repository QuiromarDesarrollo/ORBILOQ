import test from 'node:test';
import assert from 'node:assert/strict';
import { crearHandler, DRIVE_FOLDER_ID } from '../supabase/functions/conductor-evidencia/handler.mjs';

const input = { vehiculo: '11111111-1111-4111-8111-111111111111',
  tipo: 'Registro diario', campo: 'foto_frontal', nombre: 'foto.jpg',
  mime: 'image/jpeg', bytes: 12345 };
const session = 'https://www.googleapis.com/upload/drive/v3/files?upload_id=TEST';
const options = { habilitado: true, configurado: true,
  autorizar: async () => ({ placa: 'ABC123', actor: 'actor-auth-id' }), iniciar: async () => session };
const req = (data = input, token = 'Bearer test') => new Request('https://example.test', {
  method: 'POST', headers: { Authorization: token, 'Content-Type': 'application/json', Origin: 'https://pruebas.example.test' },
  body: JSON.stringify(data),
});

test('Admite los dos laterales y conserva compatibilidad con fotos anteriores', async () => {
  for (const campo of ['foto_lateral', 'foto_lateral_derecho', 'foto_lateral_izquierdo']) {
    let metadata;
    const handler = crearHandler({ ...options, iniciar: async (v) => { metadata = v.metadata; return session; } });
    assert.equal((await handler(req({ ...input, campo }))).status, 200);
    assert.equal(metadata.appProperties.campo, campo);
    assert.ok(metadata.name.startsWith(`ABC123_${campo}_`));
  }
});

test('Sesión solo para carpeta fija y metadatos derivados de usuario/vehículo', async () => {
  let payload;
  const handler = crearHandler({ ...options, iniciar: async (v) => { payload = v; return session; } });
  const r = await handler(req({ ...input, parents: ['otra-carpeta'], actor: 'suplantado' }));
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { uploadUrl: session });
  assert.deepEqual(payload.metadata.parents, [DRIVE_FOLDER_ID]);
  assert.equal(payload.metadata.appProperties.actor, 'actor-auth-id');
  assert.equal(payload.bytes, input.bytes);
  assert.match(payload.metadata.name, /^ABC123_foto_frontal_/);
  assert.equal(payload.origin, 'https://pruebas.example.test');
});
test('Sin JWT, vehículo ajeno y producción no acceden a Drive', async () => {
  let calls = 0;
  const iniciar = async () => { calls++; return session; };
  assert.equal((await crearHandler({ ...options, iniciar })(req(input, ''))).status, 401);
  assert.equal((await crearHandler({ ...options, iniciar, autorizar: async () => null })(req())).status, 403);
  assert.equal((await crearHandler({ ...options, iniciar, habilitado: false })(req())).status, 403);
  assert.equal(calls, 0);
});
test('Rechaza tamaño, MIME, campo y tipo inválidos antes de pedir una sesión', async () => {
  let calls = 0;
  const handler = crearHandler({ ...options, iniciar: async () => { calls++; return session; } });
  for (const invalid of [{bytes:0}, {bytes:10485761}, {bytes:1.5}, {mime:'text/html'},
    {campo:'invento'}, {tipo:'Asignación'}, {vehiculo:'invalido'}, {nombre:'x'.repeat(201)},
    {mime:'application/pdf'}]) {
    assert.equal((await handler(req({...input,...invalid}))).status, 400);
  }
  assert.equal(calls, 0);
  assert.equal((await handler(req({...input,nombre:'x'.repeat(5000)}))).status, 413);
});
test('Falta de configuración explícita, sin exponer errores o secretos', async () => {
  const missing = await crearHandler({ ...options, configurado:false })(req());
  assert.equal(missing.status,503);
  assert.deepEqual(await missing.json(),{code:'DRIVE_NOT_CONFIGURED'});
  for (const iniciar of [async()=>{throw new Error('secret-token');}, async()=> 'https://evil.test/upload']) {
    const r = await crearHandler({...options,iniciar})(req());
    assert.equal(r.status,502);
    assert.deepEqual(await r.json(),{code:'DRIVE_UNAVAILABLE'});
  }
});
test('Documentos y preflight admitidos sin conceder acceso público a archivos', async () => {
  const handler = crearHandler(options);
  assert.equal((await handler(req({...input,campo:'enlace',mime:'application/pdf',nombre:'factura.pdf'}))).status,200);
  assert.equal((await handler(new Request('https://example.test',{method:'OPTIONS'}))).status,204);
  assert.equal((await handler(new Request('https://example.test'))).status,405);
});
