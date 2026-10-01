import assert from 'node:assert/strict';
import { crearHandler } from '../supabase/functions/admin-crear-usuario/handler.mjs';

const datos = { numero: '0007', nombre: 'Persona', rol: 'produccion', contrasena: 'clave-prueba-segura' };
const request = (body=datos, token='valid') => new Request('http://localhost', { method:'POST',
  headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body) });
let calls=[];
const base = {
  identificar:async(token)=>token==='valid'?'admin':null,
  esAdmin:async()=>true, existeNumero:async()=>false, pendiente:async()=>null,
  crearAuth:async(data)=>{calls.push(['auth',data.email]);return 'nuevo';},
  registrar:async(data)=>{calls.push(['perfil',data]);return {id:'perfil'};},
};
let checks=0;
async function probar(api,req,status){
  calls=[];const res=await crearHandler({...base,...api})(req);assert.equal(res.status,status);checks++;return res.json();
}
await probar({},request(datos,null),401);assert.deepEqual(calls,[]);
await probar({},request(datos,'bad'),403);assert.deepEqual(calls,[]);
await probar({esAdmin:async()=>false},request(),403);assert.deepEqual(calls,[]);
await probar({},request({...datos,rol:'superuser'}),400);
await probar({},request({...datos,numero:'bad@domain'}),400);
await probar({},request({...datos,contrasena:'corta'}),400);
await probar({existeNumero:async()=>true},request(),409);assert.deepEqual(calls,[]);
let body=await probar({},request(),200);assert.equal(body.usuario.id,'perfil');assert.equal(calls[0][1],'0007@orbiloq.local');
assert.ok(!JSON.stringify(body).includes(datos.contrasena));checks++;
body=await probar({pendiente:async()=>'pendiente'},request(),200);
assert.equal(body.recuperada,true);assert.equal(calls.length,1);assert.equal(calls[0][1].authId,'pendiente');checks++;
await probar({registrar:async()=>{throw Error('timeout');}},request(),409);
assert.deepEqual(calls,[['auth','0007@orbiloq.local']]);checks++;
const opts=await crearHandler(base)(new Request('http://localhost',{method:'OPTIONS'}));assert.equal(opts.status,200);checks++;
console.log(`Usuarios: ${checks} comprobaciones correctas. Auth simulado, sin conexiones remotas.`);
