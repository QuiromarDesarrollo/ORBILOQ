const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const respuesta = (status, body) => new Response(JSON.stringify(body), { status, headers });

export function crearHandler(api) {
  return async req => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers });
    if (req.method !== 'POST') return respuesta(405, { error: 'Método no permitido.' });
    try {
      const token = req.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
      if (!token) return respuesta(401, { error: 'Inicia sesión nuevamente.' });
      const actor = await api.identificar(token);
      if (!actor || !(await api.esAdmin(actor))) return respuesta(403, { error: 'Acceso exclusivo del administrador.' });
      if (Number(req.headers.get('Content-Length') ?? 0) > 4096) return respuesta(413, { error: 'Solicitud demasiado grande.' });
      const raw = await req.text();
      if (raw.length > 4096) return respuesta(413, { error: 'Solicitud demasiado grande.' });
      let datos;
      try { datos = JSON.parse(raw); } catch { return respuesta(400, { error: 'Solicitud inválida.' }); }
      if (!datos || typeof datos !== 'object' || Array.isArray(datos) ||
          typeof datos.usuario_id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(datos.usuario_id) ||
          typeof datos.contrasena !== 'string' || datos.contrasena.length < 12 || datos.contrasena.length > 128) {
        return respuesta(400, { error: 'Indica el usuario y una contraseña de 12 a 128 caracteres.' });
      }
      const usuario = await api.usuario(datos.usuario_id);
      if (!usuario?.auth_id) return respuesta(409, { error: 'El usuario no tiene una cuenta de acceso vinculada.' });
      // El destino se resuelve en la base: nunca aceptar un auth_id del cliente.
      if (!(await api.esAdmin(actor))) return respuesta(403, { error: 'Acceso exclusivo del administrador.' });
      await api.actualizar(usuario.auth_id, datos.contrasena);
      return respuesta(200, { actualizada: true });
    } catch {
      // No incluir cuerpos, contraseñas, tokens ni mensajes internos de Auth.
      return respuesta(409, { error: 'No se pudo confirmar el cambio de contraseña. Revisa la conexión e inténtalo nuevamente.' });
    }
  };
}
