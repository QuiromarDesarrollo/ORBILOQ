const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const respuesta = (status, body) => new Response(JSON.stringify(body), { status, headers });

// Adaptador inyectable para probar autorizacion y fallos sin tocar Auth real.
export function crearHandler(api) {
  return async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers });
    if (req.method !== 'POST') return respuesta(405, { error: 'Metodo no permitido.' });
    try {
      const token = req.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
      if (!token) return respuesta(401, { error: 'Inicia sesion nuevamente.' });
      const actor = await api.identificar(token);
      if (!actor || !(await api.esAdmin(actor))) return respuesta(403, { error: 'Acceso exclusivo del administrador.' });
      if (Number(req.headers.get('Content-Length') ?? 0) > 10000) return respuesta(413, { error: 'Solicitud demasiado grande.' });
      const raw = await req.text();
      if (raw.length > 10000) return respuesta(413, { error: 'Solicitud demasiado grande.' });
      let datos;
      try { datos = JSON.parse(raw); } catch { return respuesta(400, { error: 'Solicitud invalida.' }); }
      if (!datos || typeof datos !== 'object') return respuesta(400, { error: 'Solicitud invalida.' });
      const { numero, nombre, rol, contrasena } = datos;
      if (typeof numero !== 'string' || !/^\d{1,30}$/.test(numero) || typeof nombre !== 'string' || !nombre.trim() || nombre.trim().length > 150 ||
          !['admin', 'produccion', 'logistica'].includes(rol) || typeof contrasena !== 'string' || contrasena.length < 12 || contrasena.length > 128) {
        return respuesta(400, { error: 'Completa numero, nombre, rol y una contraseña de 12 a 128 caracteres.' });
      }
      if (await api.existeNumero(numero)) return respuesta(409, { error: 'El numero de usuario ya existe. Edita la cuenta existente.' });
      // Recuperar una alta interrumpida no modifica contraseñas ni cuentas antiguas.
      let authId = await api.pendiente(numero);
      const recuperada = Boolean(authId);
      if (!authId) authId = await api.crearAuth({ email: `${numero}@orbiloq.local`, password: contrasena });
      // El RPC vuelve a comprobar el rol dentro de la transaccion.
      const usuario = await api.registrar({ actor, authId, numero, nombre: nombre.trim(), rol });
      return respuesta(200, { usuario, recuperada });
    } catch {
      // Nunca registrar cuerpos, contraseñas ni tokens. Nunca borrar cuentas para compensar un timeout.
      return respuesta(409, { error: 'No se pudo completar el alta. Actualiza la lista antes de reintentar. Si el alta quedo pendiente, el reintento conservara la contraseña del primer intento.' });
    }
  };
}
