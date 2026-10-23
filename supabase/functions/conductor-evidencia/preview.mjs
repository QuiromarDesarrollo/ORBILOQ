const imageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

async function leerImagen(response, limite) {
  const mime = response.headers.get('content-type')?.split(';')[0];
  if (!response.ok || !imageTypes.has(mime)) return null;
  const reader = response.body?.getReader();
  if (!reader) return null;
  const chunks = []; let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > limite) { await reader.cancel(); return null; }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  if (!size) return null;
  let binary = '';
  for (const chunk of chunks) {
    for (let i = 0; i < chunk.length; i += 8192) binary += String.fromCharCode(...chunk.subarray(i, i + 8192));
  }
  return { mime, base64: btoa(binary) };
}

// El handler valida previamente JWT, RLS y vínculo del archivo con la ficha.
export async function obtenerVistaPrevia({ token, id, vehiculo, carpeta, fetcher = fetch }) {
  const headers = { Authorization: `Bearer ${token}` };
  const base = `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}`;
  const info = await fetcher(`${base}?fields=thumbnailLink,mimeType,appProperties,parents,trashed&supportsAllDrives=true`, { headers, signal: AbortSignal.timeout(15000) });
  if (!info.ok) return null;
  const metadata = await info.json();
  if (metadata.trashed || !metadata.parents?.includes(carpeta) || metadata.appProperties?.vehiculo !== vehiculo || metadata.appProperties?.entorno !== 'ORBILOQ-DEV') return null;
  if (metadata.thumbnailLink) {
    try {
      const url = new URL(metadata.thumbnailLink);
      if (url.protocol === 'https:' && !url.username && !url.password && (url.hostname === 'googleusercontent.com' || url.hostname.endsWith('.googleusercontent.com'))) {
        const response = await fetcher(url, { headers, redirect: 'error', signal: AbortSignal.timeout(15000) });
        const imagen = await leerImagen(response, 1024 * 1024);
        if (imagen) return imagen;
      }
    } catch { /* Miniatura temporal: intentar la imagen original autenticada. */ }
  }
  if (!imageTypes.has(metadata.mimeType)) return null;
  const original = await fetcher(`${base}?alt=media&supportsAllDrives=true`, { headers, redirect: 'error', signal: AbortSignal.timeout(15000) });
  return leerImagen(original, 10 * 1024 * 1024);
}
