// Solo ejecuta envío con --enviar; destino fijo a la cuenta autorizada y datos ficticios.
import {readFile,writeFile} from 'node:fs/promises';
import {plantillaEntrega} from '../supabase/functions/entrega-correo/plantilla.mjs';
import {mensajeGmail,REMITENTE} from '../supabase/functions/entrega-correo/gmail.mjs';
import {logoBase64} from '../supabase/functions/entrega-correo/logo.mjs';
function pdf(label){
 const stream=`BT /F1 18 Tf 50 750 Td (${label} - SOLO PRUEBA ORBILOQ) Tj ET`;
 const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',`<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`];
 let result='%PDF-1.4\n';const offsets=[0];
 objects.forEach((obj,i)=>{offsets.push(Buffer.byteLength(result));result+=`${i+1} 0 obj\n${obj}\nendobj\n`;});
 const xref=Buffer.byteLength(result);result+=`xref\n0 6\n0000000000 65535 f \n${offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')}trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
 return Buffer.from(result).toString('base64');
}
const datos={le:'PRUEBA-1042',cliente:'CLIENTE FICTICIO - PRUEBA',ops:['PRUEBA-26238','PRUEBA-26241'],recibido:'2026-10-21',numero_guia:'PRUEBA-987654321',adjuntos:[{nombre:'LE_PRUEBA.pdf'},{nombre:'GUIA_PRUEBA.pdf'}]};
const content=plantillaEntrega(datos);content.subject='[PRUEBA ORBILOQ] '+content.subject;
const raw=mensajeGmail({...content,to:[REMITENTE],attachments:datos.adjuntos.map((a,i)=>({filename:a.nombre,content:pdf(i?'GUIA':'LE')}))},crypto.randomUUID(),logoBase64);
if(!process.argv.includes('--enviar')){
 await writeFile('.dart_tool/correo-gmail-prueba.eml',Buffer.from(raw,'base64url'));
 console.log('Preparado: correo de prueba a la cuenta autorizada, dos PDF ficticios y logo. No enviado.');
}else{
 try{
  const env=Object.fromEntries((await readFile('.dart_tool/entrega-gmail-secrets.env','utf8')).trim().split('\n').map(line=>{const at=line.indexOf('=');return[line.slice(0,at),line.slice(at+1).trim()];}));
  if(env.ENTREGA_GMAIL_FROM!==REMITENTE)throw Error('Remitente inesperado');
  const refresh=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:env.ENTREGA_GOOGLE_CLIENT_ID,client_secret:env.ENTREGA_GOOGLE_CLIENT_SECRET,refresh_token:env.ENTREGA_GOOGLE_REFRESH_TOKEN,grant_type:'refresh_token'}),signal:AbortSignal.timeout(15000)});
  if(!refresh.ok)throw Error('Renovación rechazada');const token=(await refresh.json()).access_token;
  const r=await fetch(`https://gmail.googleapis.com/gmail/v1/users/${REMITENTE}/messages/send`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({raw}),signal:AbortSignal.timeout(30000)});
  if(!r.ok){console.log('Gmail rechazó la prueba. HTTP '+r.status);process.exitCode=1;}else{const result=await r.json();await writeFile('.dart_tool/gmail-prueba-resultado.json',JSON.stringify({id:result.id,fecha:new Date().toISOString(),destino:REMITENTE}));console.log('Gmail aceptó el correo de prueba con dos PDF y logo.');}
 }catch{console.log('No se confirmó el envío. Revisar Enviados antes de repetirlo.');process.exitCode=1;}
}
