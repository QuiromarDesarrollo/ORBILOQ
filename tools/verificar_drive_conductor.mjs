// Prueba administrativa de la conexión; no suplanta una sesión de conductor.
import { readFile, writeFile } from 'node:fs/promises';
import { FOLDER } from './conectar_drive_conductor.mjs';

const request = async (url, options = {}) => fetch(url, { ...options, signal: AbortSignal.timeout(30000) });
const env = Object.fromEntries((await readFile('.dart_tool/conductor-drive-secrets.env', 'utf8'))
  .trim().split(/\r?\n/).map(line => { const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1)]; }));
const functionUrl = 'https://igfuafcekcpugpmsoqbe.supabase.co/functions/v1/conductor-evidencia';
const unauthorized = await request(functionUrl, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
const unauthorizedBody = await unauthorized.json();
if (unauthorized.status !== 401 || unauthorizedBody.code !== 'UNAUTHORIZED') throw new Error('La función no respondió con su validación de sesión esperada.');
console.log('Función DEV desplegada: rechaza solicitudes sin sesión (401).');
const refreshed = await request('https://oauth2.googleapis.com/token', {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ client_id: env.CONDUCTOR_GOOGLE_CLIENT_ID,
    client_secret: env.CONDUCTOR_GOOGLE_CLIENT_SECRET,
    refresh_token: env.CONDUCTOR_GOOGLE_REFRESH_TOKEN, grant_type: 'refresh_token' }),
});
if (!refreshed.ok) throw new Error('No se pudo renovar la autorización de Google.');
const { access_token } = await refreshed.json();
const authorization = { Authorization: `Bearer ${access_token}` };
const folderResponse = await request(`https://www.googleapis.com/drive/v3/files/${FOLDER}?supportsAllDrives=true&fields=id,name,capabilities(canAddChildren)`, { headers: authorization });
if (!folderResponse.ok || !(await folderResponse.json()).capabilities?.canAddChildren) throw new Error('TRANSPORTE no admite archivos con esta cuenta.');
console.log('Renovación OAuth correcta. Carpeta TRANSPORTE accesible para escritura.');
if (process.argv.includes('--subir-prueba')) {
  // PNG de 1 píxel, sin contenido personal: comprueba el protocolo de carga real.
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==', 'base64');
  const started = await request('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true&fields=id,name,parents,webViewLink', {
    method: 'POST', headers: { ...authorization, 'Content-Type': 'application/json',
      'X-Upload-Content-Type': 'image/png', 'X-Upload-Content-Length': String(png.length), Origin: 'http://localhost:8765' },
    body: JSON.stringify({ name: `PRUEBA_CONEXION_ORBILOQ_DEV_${new Date().toISOString().replace(/[:.]/g, '-')}.png`,
      mimeType: 'image/png', parents: [FOLDER], description: 'Prueba técnica de conexión. Imagen de un píxel sin datos personales.', appProperties: { entorno: 'ORBILOQ-DEV', prueba: 'conexion' } }),
  });
  const location = started.headers.get('location');
  if (!started.ok || !location) throw new Error('No se pudo iniciar la subida de prueba.');
  const target = new URL(location);
  if (target.protocol !== 'https:' || target.hostname !== 'www.googleapis.com' || target.pathname !== '/upload/drive/v3/files') throw new Error('Destino de carga inesperado.');
  const uploaded = await request(location, { method: 'PUT', headers: { 'Content-Type': 'image/png', 'Content-Length': String(png.length), Origin: 'http://localhost:8765' }, body: png });
  if (!uploaded.ok) throw new Error('La subida de prueba no se completó.');
  const file = await uploaded.json();
  if (!file.parents?.includes(FOLDER)) throw new Error('La evidencia de prueba quedó en una carpeta inesperada.');
  const report = { id: file.id, name: file.name, link: file.webViewLink || `https://drive.google.com/file/d/${file.id}/view`, bytes: png.length, folder: FOLDER, verified: new Date().toISOString() };
  await writeFile('.dart_tool/conductor-drive-prueba.json', JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
}
