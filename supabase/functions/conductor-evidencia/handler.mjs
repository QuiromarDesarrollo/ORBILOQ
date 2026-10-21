export const DRIVE_FOLDER_ID = '1KCgLHDHkiek82eyTwpdjfPACmRGC1l7W';
const tipos = new Set(['Inicio de jornada', 'Fin de jornada', 'Registro diario',
  'Tanqueo', 'Lavado', 'Reposición de fluidos', 'Mantenimiento preventivo',
  'Mantenimiento correctivo', 'Siniestro vial', 'Novedad', 'Documentos']);
const campos = new Set(['enlace', 'evidencia_siniestro', 'foto_frontal',
  'foto_lateral', 'foto_lateral_derecho', 'foto_lateral_izquierdo', 'foto_trasera', 'foto_tablero']);
const extensiones = {
  'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
  'application/pdf': 'pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
};
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const json = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});

// No recibe bytes ni devuelve tokens de Google. La URL de sesión únicamente
// permite completar esta carga, en la carpeta y con los metadatos fijados aquí.
export function crearHandler({ habilitado, configurado, autorizar, iniciar }) {
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (request.method !== 'POST') return json(405, { code: 'METHOD_NOT_ALLOWED' });
    if (!habilitado) return json(403, { code: 'DEV_ONLY' });
    const token = request.headers.get('authorization')?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) return json(401, { code: 'UNAUTHORIZED' });
    // Leer con límite real, incluso si el cliente omite Content-Length.
    let input;
    try {
      const reader = request.body?.getReader();
      if (!reader) return json(400, { code: 'INVALID_INPUT' });
      const chunks = []; let size = 0;
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > 4096) { await reader.cancel(); return json(413, { code: 'TOO_LARGE' }); }
        chunks.push(value);
      }
      const bytes = new Uint8Array(size); let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
      input = JSON.parse(new TextDecoder().decode(bytes));
    } catch { return json(400, { code: 'INVALID_INPUT' }); }
    if (!input || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(input.vehiculo ?? '') ||
        !tipos.has(input.tipo) || !campos.has(input.campo) ||
        !Object.hasOwn(extensiones, input.mime ?? '') ||
        !Number.isSafeInteger(input.bytes) || input.bytes < 1 || input.bytes > 10 * 1024 * 1024 ||
        typeof input.nombre !== 'string' || input.nombre.length > 200 ||
        (input.campo.startsWith('foto_') && !input.mime.startsWith('image/'))) {
      return json(400, { code: 'INVALID_INPUT' });
    }
    try {
      const acceso = await autorizar(token, input.vehiculo);
      if (!acceso) return json(403, { code: 'FORBIDDEN' });
      if (!configurado) return json(503, { code: 'DRIVE_NOT_CONFIGURED' });
      const origin = request.headers.get('origin');
      const nombre = `${acceso.placa.replace(/[^a-zA-Z0-9_-]/g, '')}_${input.campo}_${new Date().toISOString().replace(/[:.]/g, '-')}_${crypto.randomUUID()}.${extensiones[input.mime]}`;
      const uploadUrl = await iniciar({
        mime: input.mime, bytes: input.bytes,
        origin: origin && /^https?:\/\/[^/\s]+$/.test(origin) ? origin : null,
        metadata: { name: nombre, mimeType: input.mime, parents: [DRIVE_FOLDER_ID],
          appProperties: { vehiculo: input.vehiculo, actor: acceso.actor,
            campo: input.campo, tipo: input.tipo, entorno: 'ORBILOQ-DEV' } },
      });
      const url = new URL(uploadUrl);
      if (url.protocol !== 'https:' || url.hostname !== 'www.googleapis.com' ||
          url.pathname !== '/upload/drive/v3/files' || url.username || url.password) throw new Error();
      return json(200, { uploadUrl });
    } catch {
      // Nunca incluir tokens, URL de sesión ni errores crudos de Google en logs/respuesta.
      return json(502, { code: 'DRIVE_UNAVAILABLE' });
    }
  };
}
