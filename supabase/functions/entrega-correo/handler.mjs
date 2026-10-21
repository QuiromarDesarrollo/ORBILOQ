import { plantillaEntrega } from './plantilla.mjs';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS'};
const respuesta = (status, data) => new Response(JSON.stringify(data), {status, headers:{...cors,'Content-Type':'application/json'}});
export function crearHandler(deps) {
  return async request => {
    if (request.method === 'OPTIONS') return new Response(null, {status:204,headers:cors});
    if (request.method !== 'POST') return respuesta(405,{error:'Método no permitido'});
    let job, iniciado=false;
    try {
      const token = request.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
      if (!token) return respuesta(401,{error:'Inicia sesión'});
      if (Number(request.headers.get('content-length') ?? 0)>2048) return respuesta(413,{error:'Solicitud demasiado grande'});
      const raw = await request.text();
      if (raw.length>2048) return respuesta(413,{error:'Solicitud demasiado grande'});
      let body; try { body=JSON.parse(raw); } catch { return respuesta(400,{error:'Solicitud inválida'}); }
      if (!uuid.test(body?.id ?? '')) return respuesta(400,{error:'Notificación inválida'});
      const permiso = await deps.autorizar(token,body.id);
      if (!permiso) return respuesta(403,{error:'Sin acceso a esta notificación'});
      if (permiso.estado === 'enviado') return respuesta(200,{estado:'enviado'});
      if (!deps.habilitado || !deps.configurado) return respuesta(503,{error:'Entrega guardada. Falta configurar el servicio de correo y el remitente.'});
      job = await deps.reclamar(body.id);
      if (!job) return respuesta(409,{error:'El correo está en proceso o requiere revisión. Actualiza el seguimiento.'});
      const attachments = [];
      for (const a of job.datos.adjuntos ?? []) {
        const prefijo = `${job.despacho_id}/${job.revision}/`;
        if (!a.path?.startsWith(prefijo) || !/^evidencia_(le|guia)\//.test(a.path.slice(prefijo.length)) || a.path.includes('..')) throw new Error('Adjunto inválido');
        const bytes = await deps.descargar(a.path);
        if (!bytes.length || bytes.length>10485760) throw new Error('Tamaño de adjunto inválido');
        attachments.push({filename:a.nombre,content:deps.base64(bytes)});
      }
      const contenido = plantillaEntrega(job.datos);
      await deps.marcarInicio(job.id);
      iniciado=true;
      const id = await deps.enviar({ ...contenido, to:[job.destinatario], attachments },job.id);
      await deps.finalizar(job.id, {estado:'enviado',proveedor_id:id,enviado_en:new Date().toISOString(),error:null});
      return respuesta(200,{estado:'enviado'});
    } catch (error) {
      if (job) {
        const incierto=iniciado && !error?.noEnviado;
        try { await deps.finalizar(job.id,{estado:incierto?'revision_manual':'error',envio_iniciado:incierto,error:incierto?'Comprueba Enviados en Gmail antes de volver a enviar; el resultado no fue confirmado.':'No se envió el correo. Revisa la autorización y reintenta.'}); } catch { /* envio_iniciado impide repetir un envío incierto al expirar la reserva. */ }
      }
      return respuesta(502,{error:'La entrega sigue guardada, pero no se confirmó el correo. Reintenta desde Seguimiento.'});
    }
  };
}
