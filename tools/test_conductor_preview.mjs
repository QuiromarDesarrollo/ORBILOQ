import test from 'node:test';
import assert from 'node:assert/strict';
import { obtenerVistaPrevia } from '../supabase/functions/conductor-evidencia/preview.mjs';
const meta = { mimeType:'image/jpeg', parents:['folder'], appProperties:{vehiculo:'car',entorno:'ORBILOQ-DEV'} };
const opts = {token:'private',id:'file',vehiculo:'car',carpeta:'folder'};
const image = () => new Response(new Uint8Array([1,2,3]),{headers:{'content-type':'image/jpeg'}});
test('Foto sin miniatura se obtiene del original autenticado', async()=>{
 const calls=[];
 const r=await obtenerVistaPrevia({...opts,fetcher:async(url,options)=>{
   calls.push(String(url)); assert.equal(options.headers.Authorization,'Bearer private');
   return calls.length===1?Response.json(meta):image();
 }});
 assert.equal(r.base64,'AQID'); assert.match(calls[1],/alt=media/);
});
test('Miniatura válida evita descargar original',async()=>{
 const calls=[];
 const r=await obtenerVistaPrevia({...opts,fetcher:async(url)=>{
   calls.push(String(url)); return calls.length===1?Response.json({...meta,thumbnailLink:'https://lh3.googleusercontent.com/photo'}):image();
 }});
 assert.equal(r.mime,'image/jpeg'); assert.equal(calls.length,2); assert.match(calls[1],/googleusercontent/);
});
test('Miniatura caducada recurre a original; PDF sin miniatura no se descarga',async()=>{
 let n=0;
 const r=await obtenerVistaPrevia({...opts,fetcher:async()=>++n===1?Response.json({...meta,thumbnailLink:'https://lh3.googleusercontent.com/photo'}):n===2?new Response('',{status:404}):image()});
 assert.equal(r.base64,'AQID'); assert.equal(n,3);
 n=0;
 assert.equal(await obtenerVistaPrevia({...opts,fetcher:async()=>{n++;return Response.json({...meta,mimeType:'application/pdf'});}}),null);
 assert.equal(n,1);
});
test('No transmite token a enlaces externos ni lee archivos ajenos',async()=>{
 for(const invalid of [{trashed:true},{parents:['other']},{appProperties:{vehiculo:'other',entorno:'ORBILOQ-DEV'}}]){
  let n=0;
  assert.equal(await obtenerVistaPrevia({...opts,fetcher:async()=>{n++;return Response.json({...meta,...invalid});}}),null);
  assert.equal(n,1);
 }
 const calls=[];
 await obtenerVistaPrevia({...opts,fetcher:async(url)=>{calls.push(String(url));return calls.length===1?Response.json({...meta,thumbnailLink:'https://evil.test/photo'}):image();}});
 assert.ok(calls.every(u=>u.startsWith('https://www.googleapis.com/')));
});
test('Rechaza respuestas que no son imagen y originales mayores a 10 MB',async()=>{
 for(const response of [new Response('<html>',{headers:{'content-type':'text/html'}}),new Response(new Uint8Array(10*1024*1024+1),{headers:{'content-type':'image/jpeg'}})]){
  let n=0;
  assert.equal(await obtenerVistaPrevia({...opts,fetcher:async()=>++n===1?Response.json(meta):response}),null);
 }
});
