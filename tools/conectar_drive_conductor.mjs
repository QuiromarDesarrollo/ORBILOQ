// Herramienta administrativa local; nunca se incluye en Flutter ni se publica.
import { createServer } from 'node:http';
import { randomBytes, createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const ORIGIN = 'http://localhost:8765';
export const FOLDER = '1KCgLHDHkiek82eyTwpdjfPACmRGC1l7W';
const SCOPE = 'https://www.googleapis.com/auth/drive.file';
const random = () => randomBytes(32).toString('base64url');

export function createConnectionServer({ client, pickerKey, saveSecrets, fetchGoogle = fetch }) {
  if (client.project_id !== 'orbiloq-transporte' || !client.redirect_uris.includes(`${ORIGIN}/oauth/callback`)) {
    throw new Error('Se requiere el cliente del proyecto ORBILOQ Transporte con retorno local.');
  }
  const entry = random(), session = random(), csrf = random();
  let pending, tokens, completed = false;
  const google = async (url, options = {}) => {
    const response = await fetchGoogle(url, { ...options, signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error('Google rechazó la operación. Revisa cuenta, permisos y carpeta.');
    return response.json();
  };
  const server = createServer(async (req, res) => {
    const nonce = random();
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', req.url === '/' ? 'strict-origin-when-cross-origin' : 'no-referrer');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Security-Policy', `default-src 'none'; script-src 'nonce-${nonce}' https://apis.google.com; style-src 'unsafe-inline'; frame-src https://docs.google.com https://accounts.google.com; connect-src 'self' https://*.google.com https://*.googleapis.com; img-src 'self' data: https://*.google.com https://*.gstatic.com; base-uri 'none'; form-action 'self' https://docs.google.com; frame-ancestors 'none'`);
    const send = (status, body, type = 'text/plain; charset=utf-8') => {
      res.writeHead(status, { 'Content-Type': type }); res.end(body);
    };
    const redirect = url => { res.writeHead(303, { Location: url }); res.end(); };
    try {
      // Host exacto impide DNS rebinding. La escucha se limita a loopback.
      if (req.headers.host !== 'localhost:8765') return send(403, 'Host no permitido.');
      const url = new URL(req.url, ORIGIN);
      if (req.method === 'GET' && url.pathname === '/' && url.searchParams.get('entry') === entry) {
        res.setHeader('Set-Cookie', `conductor_setup=${session}; HttpOnly; SameSite=Lax; Path=/; Max-Age=1800`);
        return redirect('/');
      }
      if (!req.headers.cookie?.split(';').some(c => c.trim() === `conductor_setup=${session}`)) {
        return send(403, 'Abre el enlace local generado por la herramienta.');
      }
      if (req.method === 'POST' && (req.headers.origin !== ORIGIN || req.headers['x-setup-csrf'] !== csrf)) {
        return send(403, 'Solicitud no autorizada.');
      }
      if (url.pathname === '/oauth/start' && req.method === 'POST') {
        pending = { state: random(), verifier: random(), created: Date.now() };
        const target = new URL('https://accounts.google.com/o/oauth2/v2/auth');
        target.search = new URLSearchParams({ client_id: client.client_id,
          redirect_uri: `${ORIGIN}/oauth/callback`, response_type: 'code', scope: SCOPE,
          access_type: 'offline', prompt: 'consent', state: pending.state,
          code_challenge: createHash('sha256').update(pending.verifier).digest('base64url'),
          code_challenge_method: 'S256' }).toString();
        return send(200, JSON.stringify({ url: target.href }), 'application/json');
      }
      if (url.pathname === '/oauth/callback' && req.method === 'GET') {
        if (!pending || Date.now() - pending.created > 600000 || url.searchParams.get('state') !== pending.state) {
          return send(400, 'La autorización expiró o no corresponde a esta sesión. Vuelve al inicio.');
        }
        const verifier = pending.verifier; pending = undefined;
        if (url.searchParams.has('error') || !url.searchParams.get('code')) return send(400, 'No se autorizó Google.');
        const received = await google('https://oauth2.googleapis.com/token', {
          method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ client_id: client.client_id, client_secret: client.client_secret,
            code: url.searchParams.get('code'), code_verifier: verifier, grant_type: 'authorization_code',
            redirect_uri: `${ORIGIN}/oauth/callback` }) });
        if (!received.access_token || !received.refresh_token || !received.scope?.split(' ').includes(SCOPE)) {
          return send(400, 'Falta permiso de Drive o autorización sin conexión. Vuelve a conectar Google.');
        }
        tokens = received;
        return redirect('/');
      }
      if (url.pathname === '/picker-config' && req.method === 'POST') {
        if (!tokens || completed) return send(409, 'Conecta Google primero.');
        return send(200, JSON.stringify({ token: tokens.access_token, key: pickerKey,
          appId: client.client_id.split('-')[0] }), 'application/json');
      }
      if (url.pathname === '/verify' && req.method === 'POST') {
        if (!tokens || completed) return send(409, 'Conecta Google primero.');
        let body = '';
        for await (const chunk of req) { body += chunk; if (body.length > 2048) return send(413, 'Solicitud demasiado grande.'); }
        if (JSON.parse(body).folderId !== FOLDER) return send(400, 'Selecciona únicamente la carpeta TRANSPORTE indicada.');
        const folder = await google(`https://www.googleapis.com/drive/v3/files/${FOLDER}?supportsAllDrives=true&fields=id,name,mimeType,trashed,capabilities(canAddChildren)`, {
          headers: { Authorization: `Bearer ${tokens.access_token}` } });
        if (folder.id !== FOLDER || folder.trashed || folder.mimeType !== 'application/vnd.google-apps.folder' || !folder.capabilities?.canAddChildren) {
          return send(403, 'La cuenta no puede agregar archivos a TRANSPORTE.');
        }
        await saveSecrets({ clientId: client.client_id, clientSecret: client.client_secret,
          refreshToken: tokens.refresh_token });
        completed = true; tokens = undefined;
        return send(200, JSON.stringify({ ok: true, folder: folder.name }), 'application/json');
      }
      if (url.pathname !== '/' || req.method !== 'GET') return send(404, 'No encontrado.');
      send(200, page({ csrf, nonce, connected: Boolean(tokens), completed }), 'text/html; charset=utf-8');
    } catch {
      // No imprimir errores de OAuth: pueden incluir códigos, tokens o secretos.
      send(502, 'No se completó la conexión. Revisa la configuración de Google y vuelve a intentarlo.');
    }
  });
  server.requestTimeout = 35000;
  server.headersTimeout = 10000;
  return { server, entryUrl: `${ORIGIN}/?entry=${entry}` };
}

function page({ csrf, nonce, connected, completed }) {
  return `<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Conectar TRANSPORTE · ORBILOQ DEV</title><style>
body{margin:0;background:#f1f6f7;color:#123d4c;font:16px system-ui}main{max-width:720px;margin:8vh auto;padding:32px;background:white;border:1px solid #d7e5e9;border-radius:24px}h1{font-size:28px}p{line-height:1.6}button{font:600 16px system-ui;border:0;border-radius:12px;padding:16px 24px;background:#c4d600;color:#0b3444;cursor:pointer;margin:12px 0}button:disabled{opacity:.45;cursor:default}.badge{background:#e8f0c3;padding:8px 12px;border-radius:8px}.notice{padding:16px;background:#eef6fb;border-radius:12px}#status{white-space:pre-wrap}@media(max-width:760px){main{margin:20px;padding:24px}}
</style><main><span class="badge">Ambiente de pruebas</span><h1>Conectar la carpeta TRANSPORTE</h1>
<p>Esta conexión permite guardar las evidencias del conductor en la carpeta de Google Drive de la empresa.</p>
<ol><li>Autoriza tu cuenta de Google.</li><li>Selecciona <strong>TRANSPORTE</strong> en el selector de Google.</li><li>Se comprobará el permiso para agregar archivos.</li></ol>
<p class="notice">Solo se solicita acceso a los archivos y carpetas que autorices para ORBILOQ. No se cambia quién puede ver la carpeta.</p>
<button id="connect" ${completed ? 'disabled' : ''}>${connected ? 'Volver a conectar Google' : 'Conectar con Google'}</button>
<button id="pick" disabled>Seleccionar TRANSPORTE</button>
<button id="verify-existing" ${!connected || completed ? 'disabled' : ''}>Verificar carpeta TRANSPORTE existente</button>
<p id="status" role="status">${completed ? 'Carpeta verificada. Credenciales guardadas localmente para Supabase DEV. Falta activar y probar la función de subida.' : connected ? 'Google conectado. Selecciona TRANSPORTE para continuar.' : 'Pendiente de autorización de Google.'}</p>
<p>Mientras la aplicación esté en modo Pruebas de Google, la autorización puede requerir renovación a los siete días.</p></main>
<script nonce="${nonce}">
const connected=${connected}, completed=${completed}, csrf=${JSON.stringify(csrf)};
const status=document.getElementById('status'), pick=document.getElementById('pick');
document.addEventListener('securitypolicyviolation',e=>{status.textContent='El selector bloqueó un recurso: '+e.effectiveDirective+' · '+e.blockedURI.split('?')[0];});
async function post(path,body){const r=await fetch(path,{method:'POST',headers:{'X-Setup-CSRF':csrf,'Content-Type':'application/json'},body:JSON.stringify(body||{})});if(!r.ok)throw new Error(await r.text());return r.json();}
document.getElementById('connect').onclick=async()=>{try{const r=await post('/oauth/start');location.assign(r.url);}catch(e){status.textContent=e.message;}};
document.getElementById('verify-existing').onclick=async()=>{try{status.textContent='Verificando la carpeta previamente autorizada…';await post('/verify',{folderId:${JSON.stringify(FOLDER)}});location.replace('/');}catch(e){status.textContent=e.message+' Si falta permiso, usa Seleccionar TRANSPORTE.';}};
window.pickerLoaded=()=>gapi.load('picker',()=>{pick.disabled=!connected||completed;});
pick.onclick=async()=>{pick.disabled=true;try{const c=await post('/picker-config');const view=new google.picker.DocsView(google.picker.ViewId.FOLDERS).setIncludeFolders(true).setSelectFolderEnabled(true);
const picker=new google.picker.PickerBuilder().addView(view).setOAuthToken(c.token).setDeveloperKey(c.key).setAppId(c.appId).setOrigin(location.origin).setTitle('Selecciona la carpeta TRANSPORTE').setCallback(async(data)=>{
if(data.action===google.picker.Action.PICKED){try{status.textContent='Verificando permisos de la carpeta…';await post('/verify',{folderId:data.docs[0].id});location.replace('/');}catch(e){status.textContent=e.message;pick.disabled=false;}}
if(data.action===google.picker.Action.CANCEL)pick.disabled=false;}).build();picker.setVisible(true);
}catch(e){status.textContent=e.message;pick.disabled=false;}};
</script><script nonce="${nonce}" src="https://apis.google.com/js/api.js?onload=pickerLoaded" async defer></script></html>`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const directory = resolve('.dart_tool');
  const client = JSON.parse(await readFile(resolve(directory, 'conductor-oauth-client.json'), 'utf8')).web;
  const pickerKey = (await readFile(resolve(directory, 'conductor-picker-key.txt'), 'utf8')).trim();
  const { server, entryUrl } = createConnectionServer({ client, pickerKey,
    saveSecrets: async values => {
      const env = { CONDUCTOR_GOOGLE_CLIENT_ID: values.clientId,
        CONDUCTOR_GOOGLE_CLIENT_SECRET: values.clientSecret, CONDUCTOR_GOOGLE_REFRESH_TOKEN: values.refreshToken };
      if (Object.values(env).some(value => !/^[A-Za-z0-9._\/-]+$/.test(value))) throw new Error('Formato inesperado.');
      await writeFile(resolve(directory, 'conductor-drive-secrets.env'),
        Object.entries(env).map(([k,v]) => `${k}=${v}`).join('\n') + '\n', { mode: 0o600 });
    } });
  server.listen(8765, '127.0.0.1', () => console.log(`Abre este enlace local (no lo compartas): ${entryUrl}`));
  setTimeout(() => { server.close(); server.closeAllConnections(); }, 30 * 60 * 1000).unref();
}
