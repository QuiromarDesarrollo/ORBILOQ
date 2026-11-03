import test from 'node:test';
import assert from 'node:assert/strict';
import { crearHandler } from '../supabase/functions/entrega-correo/handler.mjs';
import { plantillaEntrega } from '../supabase/functions/entrega-correo/plantilla.mjs';
import { mensajeGmail, REMITENTE } from '../supabase/functions/entrega-correo/gmail.mjs';
import { tokenGmail } from '../supabase/functions/entrega-correo/oauth.mjs';
const id='11111111-1111-4111-8111-111111111111';
const request=()=>new Request('https://local.test',{method:'POST',headers:{authorization:'Bearer test'},body:JSON.stringify({id})});
test('OAuth distingue autorización revocada de caídas temporales sin exponer secretos',async()=>{
 for (const [error,codigo] of [['invalid_grant','gmail_autorizacion_vencida'],['invalid_client','gmail_configuracion'],['server_error','gmail_temporal']]) {
  await assert.rejects(tokenGmail({},async()=>new Response(JSON.stringify({error,error_description:'privado'}),{status:400})),e=>e.codigo===codigo && e.noEnviado===true && !e.message.includes('privado'));
 }
 assert.equal(await tokenGmail({},async()=>new Response(JSON.stringify({access_token:'token-simulado'}))), 'token-simulado');
});
test('Autorización vencida no inicia envío ni descarga adjuntos y conserva diagnóstico',async()=>{
 const {deps,calls}=setup();
 deps.prepararEnvio=async()=>{throw Object.assign(Error('privado'),{codigo:'gmail_autorizacion_vencida',noEnviado:true});};
 const response=await crearHandler(deps)(request());
 assert.equal((await response.json()).codigo,'gmail_autorizacion_vencida');
 assert.deepEqual(calls.map(c=>c[0]),['finish']);
 assert.equal(calls[0][1].estado,'error');
 assert.equal(calls[0][1].envio_iniciado,false);
 assert.match(calls[0][1].error,/reconectar Gmail/);
});
function setup(adjuntos=[]) {
  const calls=[];
  const deps={habilitado:true,configurado:true,
    autorizar:async()=>({estado:'pendiente'}),
    reclamar:async()=>({id,despacho_id:id,revision:0,destinatario:'comercial@example.com',datos:{le:1042,ops:['26238','26241'],cliente:'Cliente',adjuntos}}),
    descargar:async path=>{calls.push(['download',path]);return new Uint8Array([1,2,3]);},
    base64:bytes=>Buffer.from(bytes).toString('base64'),
    marcarInicio:async()=>calls.push(['start']),
    enviar:async(data,key)=>{calls.push(['send',data,key]);return 'proveedor-1';},
    finalizar:async(id,data)=>calls.push(['finish',data]),
  };
  return {deps,calls};
}
for (const tipos of [[],['le'],['guia'],['le','guia']]) test(`Adjuntos disponibles: ${tipos.join('+')||'ninguno'}`,async()=>{
  const {deps,calls}=setup(tipos.map(t=>({path:`${id}/0/evidencia_${t}/a.pdf`,nombre:`${t}.pdf`})));
  assert.equal((await crearHandler(deps)(request())).status,200);
  const send=calls.find(c=>c[0]==='send');
  assert.equal(send[1].attachments.length,tipos.length);
  assert.deepEqual(send[1].to,['comercial@example.com']);
  assert.equal(send[2],id);
  assert.match(send[1].text,/26238 · 26241/);
  assert.equal(calls.at(-1)[1].estado,'enviado');
});
test('Permisos y configuración impiden descargar o enviar',async()=>{
  for (const override of [{autorizar:async()=>null},{configurado:false},{habilitado:false}]) {
    const {deps,calls}=setup(); Object.assign(deps,override);
    assert.ok((await crearHandler(deps)(request())).status>=400);
    assert.equal(calls.length,0);
  }
});
test('Un correo enviado no se repite',async()=>{
  const {deps,calls}=setup(); deps.autorizar=async()=>({estado:'enviado'});
  assert.equal((await crearHandler(deps)(request())).status,200);assert.equal(calls.length,0);
});
test('Error de adjunto o proveedor nunca se declara enviado',async()=>{
  for (const escenario of ['path','download','provider']) {
    const {deps,calls}=setup([{path:escenario==='path'?'otro/0/evidencia_le/a.pdf':`${id}/0/evidencia_le/a.pdf`,nombre:'le.pdf'}]);
    if(escenario==='download') deps.descargar=async()=>{throw Error('privado');};
    if(escenario==='provider') deps.enviar=async()=>{throw Error('clave secreta');};
    const response=await crearHandler(deps)(request());
    assert.equal(response.status,502);assert.equal(calls.at(-1)[1].estado,escenario==='provider'?'revision_manual':'error');
    assert.doesNotMatch(await response.text(),/secreta|privado/);
  }
});
test('MIME Gmail conserva remitente, UTF-8, adjuntos y logo inline',()=>{
 const p=plantillaEntrega({le:1,cliente:'Compañía',ops:['42'],adjuntos:[{nombre:'Guía firmada.pdf'}]});
 const raw=mensajeGmail({...p,to:['ventas@example.com'],attachments:[{filename:'Guía firmada.pdf',content:'AQID'}]},id,'BAUG');
 const mime=Buffer.from(raw,'base64url').toString('utf8');
 assert.match(mime,new RegExp(REMITENTE.replace(/\./g,'\\.')));
 assert.match(mime,/Content-ID: <orbiloq-logo>/);assert.match(mime,/filename\*=UTF-8''Gu%C3%ADa%20firmada.pdf/);
 assert.match(mime,/Content-Type: multipart\/alternative/);
 assert.throws(()=>mensajeGmail({...p,to:['a@b.com\r\nBcc:evil@x.com'],attachments:[]},id,''),/Cabecera/);
});
test('Un rechazo inequívoco permite reintento; fallo después de enviar requiere revisión',async()=>{
 for(const conocido of [true,false]){
  const {deps,calls}=setup();
  deps.enviar=async()=>{throw Object.assign(Error('Rechazado'),{noEnviado:conocido});};
  await crearHandler(deps)(request());
  assert.equal(calls.at(-1)[1].estado,conocido?'error':'revision_manual');
 }
});
test('Plantilla escapa contenido y usa logo CID, paleta y texto alternativo',()=>{
  const p=plantillaEntrega({le:1042,cliente:'<script>hola</script>',ops:[],adjuntos:[]});
  assert.doesNotMatch(p.html,/<script>/);assert.match(p.html,/&lt;script&gt;/);
  assert.match(p.html,/cid:orbiloq-logo/);assert.match(p.html,/#c2d501/);assert.match(p.html,/#093e52/);
  assert.match(p.text,/sin OP/);assert.match(p.text,/no tiene documentos/);
});
test('Solicitudes inválidas y reserva ocupada no envían',async()=>{
  const {deps,calls}=setup();
  assert.equal((await crearHandler(deps)(new Request('https://local.test',{method:'POST'}))).status,401);
  deps.reclamar=async()=>null;
  assert.equal((await crearHandler(deps)(request())).status,409);assert.equal(calls.length,0);
});
