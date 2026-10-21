// Autorización local independiente: nunca reemplaza los secretos de Drive.
import {createServer} from 'node:http';
import {randomBytes,createHash} from 'node:crypto';
import {readFile,writeFile} from 'node:fs/promises';
const origin='http://localhost:8765';
const account='analistasdedatosing@gmail.com';
const scope='https://www.googleapis.com/auth/gmail.send';
const random=()=>randomBytes(32).toString('base64url');
const client=JSON.parse(await readFile('.dart_tool/conductor-oauth-client.json','utf8')).web;
if(client.project_id!=='orbiloq-transporte'||!client.redirect_uris.includes(origin+'/oauth/callback')) throw Error('Cliente OAuth incorrecto');
const entry=random(),session=random(),csrf=random();
let pending,completed=false;
const server=createServer(async(req,res)=>{
 const nonce=random();
 res.setHeader('Cache-Control','no-store');res.setHeader('Referrer-Policy',req.url?.startsWith('/oauth/callback')?'no-referrer':'same-origin');res.setHeader('X-Content-Type-Options','nosniff');
 res.setHeader('Content-Security-Policy',`default-src 'none'; script-src 'nonce-${nonce}'; connect-src 'self'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'`);
 const send=(status,text)=>{res.writeHead(status,{'Content-Type':'text/html; charset=utf-8'});res.end(text);};
 const redirect=url=>{res.writeHead(303,{Location:url});res.end();};
 try{
  if(req.headers.host!=='localhost:8765')return send(403,'Host inválido');
  const url=new URL(req.url,origin);
  if(req.method==='GET'&&url.pathname==='/'&&url.searchParams.get('entry')===entry){res.setHeader('Set-Cookie',`gmail_setup=${session}; HttpOnly; SameSite=Lax; Path=/; Max-Age=1800`);return redirect('/');}
  if(!req.headers.cookie?.split(';').some(c=>c.trim()===`gmail_setup=${session}`))return send(403,'Abre el enlace local de configuración.');
  if(req.method==='POST'&&url.pathname==='/start'&&!completed){
   if(req.headers.origin!==origin)return send(403,'Origen inválido');
   let body='';for await(const chunk of req){body+=chunk;if(body.length>2048)return send(413,'Solicitud demasiado grande');}
   if(new URLSearchParams(body).get('csrf')!==csrf)return send(403,'Solicitud inválida');
   pending={state:random(),verifier:random(),time:Date.now()};
   const target=new URL('https://accounts.google.com/o/oauth2/v2/auth');
   target.search=new URLSearchParams({client_id:client.client_id,redirect_uri:origin+'/oauth/callback',response_type:'code',scope:`openid email ${scope}`,access_type:'offline',prompt:'consent',login_hint:account,state:pending.state,code_challenge:createHash('sha256').update(pending.verifier).digest('base64url'),code_challenge_method:'S256'}).toString();
   res.writeHead(200,{'Content-Type':'application/json'});return res.end(JSON.stringify({url:target.href}));
  }
  if(req.method==='GET'&&url.pathname==='/oauth/callback'){
   if(!pending||Date.now()-pending.time>600000||url.searchParams.get('state')!==pending.state)return send(400,'Autorización expirada o inválida.');
   const verifier=pending.verifier;pending=undefined;
   if(url.searchParams.has('error')||!url.searchParams.get('code'))return send(400,'No se autorizó Gmail.');
   const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:client.client_id,client_secret:client.client_secret,code:url.searchParams.get('code'),code_verifier:verifier,grant_type:'authorization_code',redirect_uri:origin+'/oauth/callback'}),signal:AbortSignal.timeout(30000)});
   if(!response.ok)throw Error('OAuth');const tokens=await response.json();
   if(!tokens.refresh_token||!tokens.scope?.split(' ').includes(scope))throw Error('Falta autorización');
   const identity=await fetch('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:`Bearer ${tokens.access_token}`},signal:AbortSignal.timeout(15000)});
   if(!identity.ok)throw Error('Identidad');const user=await identity.json();
   if(user.email!==account||user.email_verified!==true)return send(403,'Se requiere autorizar exclusivamente analistasdedatosing@gmail.com.');
   const values={ENTREGA_GOOGLE_CLIENT_ID:client.client_id,ENTREGA_GOOGLE_CLIENT_SECRET:client.client_secret,ENTREGA_GOOGLE_REFRESH_TOKEN:tokens.refresh_token,ENTREGA_GMAIL_FROM:account};
   if(Object.values(values).some(v=>/[\r\n]/.test(v)))throw Error('Formato inválido');
   await writeFile('.dart_tool/entrega-gmail-secrets.env',Object.entries(values).map(([k,v])=>`${k}=${v}`).join('\n')+'\n',{mode:0o600});
   completed=true;return redirect('/');
  }
  if(req.method!=='GET'||url.pathname!=='/')return send(404,'No encontrado');
  send(200,`<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Gmail · ORBILOQ DEV</title><style>body{background:#edf3f5;color:#093e52;font:16px Arial;margin:0}main{max-width:640px;margin:8vh auto;padding:32px;background:white;border-radius:18px}p{line-height:1.7}button{background:#c2d501;color:#093e52;border:0;padding:16px;border-radius:10px;font-size:16px;font-weight:bold}</style><main><h1>Correo de entregas · ORBILOQ</h1><p>Ambiente de pruebas · <strong>${account}</strong></p><p>Se solicita permiso para enviar mensajes y comprobar la dirección de la cuenta. No se solicita leer ni eliminar correos. La conexión existente de Drive se conserva.</p>${completed?'<h2>Autorización guardada localmente</h2><p>Falta instalar los secretos y desplegar la función en Supabase DEV. No se ha enviado ningún correo.</p>':`<form action="/start" method="post"><input type="hidden" name="csrf" value="${csrf}"><button type="submit">Autorizar Gmail</button></form>`}<p>Si Google mantiene la aplicación en modo Pruebas, la autorización sin conexión puede expirar a los siete días.</p></main><script nonce="${nonce}">const form=document.querySelector("form");if(form)form.onsubmit=async(e)=>{e.preventDefault();const r=await fetch("/start",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({csrf:${JSON.stringify(csrf)}})});if(r.ok){const d=await r.json();location.assign(d.url);}else{document.body.textContent=await r.text();}};</script></html>`);
 }catch{send(502,'No se completó la autorización. No se muestran tokens ni datos privados. Vuelve al inicio para reintentar.');}
});
server.requestTimeout=35000;server.headersTimeout=10000;
server.listen(8765,'127.0.0.1',async()=>{await writeFile('.dart_tool/entrega-gmail-setup.json',JSON.stringify({url:`${origin}/?entry=${entry}`}));});
setTimeout(()=>{server.close();server.closeAllConnections();},1800000).unref();
