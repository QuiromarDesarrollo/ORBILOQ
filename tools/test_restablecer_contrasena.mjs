import test from 'node:test';
import assert from 'node:assert/strict';
import { crearHandler } from '../supabase/functions/admin-restablecer-contrasena/handler.mjs';
const id = '00000000-0000-0000-0000-000000000001';
const clave = 'Clave-de-prueba-123';
const req = (body = { usuario_id: id, contrasena: clave }, token = 'valido') => new Request('http://localhost', { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
function setup(overrides = {}) {
  const calls = [];
  const handler = crearHandler({ identificar: async t => t === 'valido' ? 'admin' : null,
    esAdmin: async () => true, usuario: async usuario => { calls.push(['usuario', usuario]); return { auth_id: 'auth-real' }; },
    actualizar: async (authId, password) => { calls.push(['actualizar', authId]); assert.equal(password, clave); }, ...overrides });
  return {handler, calls};
}
test('Bloquea anónimos, JWT inválido y perfiles no administradores', async () => {
  for (const [token, admin, status] of [[null,true,401], ['malo',true,403], ['valido',false,403]]) {
    const {handler,calls} = setup({esAdmin:async()=>admin});
    assert.equal((await handler(req(undefined, token))).status, status); assert.deepEqual(calls, []);
  }
});
test('Valida destino y longitud antes de consultar Auth', async () => {
  for (const body of [null, [], {}, {usuario_id:'otro',contrasena:clave}, {usuario_id:id,contrasena:'corta'}, {usuario_id:id,contrasena:'x'.repeat(129)}]) {
    const {handler,calls}=setup(); assert.equal((await handler(req(body))).status,400); assert.deepEqual(calls,[]);
  }
});
test('Resuelve cuenta desde catálogo e ignora auth_id inyectado', async () => {
  const {handler,calls}=setup(); const res=await handler(req({usuario_id:id,contrasena:clave,auth_id:'atacante'}));
  assert.equal(res.status,200); assert.deepEqual(await res.json(),{actualizada:true});
  assert.deepEqual(calls,[['usuario',id],['actualizar','auth-real']]);
});
test('Sin cuenta vinculada no cambia credenciales', async () => {
  const {handler,calls}=setup({usuario:async()=>({auth_id:null})});
  assert.equal((await handler(req())).status,409); assert.deepEqual(calls,[]);
});
test('Revalida administrador antes de escribir', async () => {
  let n=0; const {handler,calls}=setup({esAdmin:async()=>++n===1});
  assert.equal((await handler(req())).status,403); assert.equal(calls.some(c=>c[0]==='actualizar'),false);
});
test('Errores no exponen contraseñas ni detalles internos', async () => {
  const {handler}=setup({actualizar:async()=>{throw new Error(clave);}});
  const res=await handler(req()); assert.equal(res.status,409); assert.equal((await res.text()).includes(clave),false);
});
test('Métodos y cuerpos grandes se rechazan', async () => {
  const {handler}=setup(); assert.equal((await handler(new Request('http://localhost'))).status,405);
  assert.equal((await handler(req({relleno:'x'.repeat(5000)}))).status,413);
});
