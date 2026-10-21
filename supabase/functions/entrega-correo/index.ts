import { createClient } from 'npm:@supabase/supabase-js@2';
import { encodeBase64 } from 'jsr:@std/encoding@1/base64';
import { crearHandler } from './handler.mjs';
import { logoBase64 } from './logo.mjs';
import { mensajeGmail, REMITENTE } from './gmail.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
const clientId = Deno.env.get('ENTREGA_GOOGLE_CLIENT_ID');
const clientSecret = Deno.env.get('ENTREGA_GOOGLE_CLIENT_SECRET');
const refreshToken = Deno.env.get('ENTREGA_GOOGLE_REFRESH_TOKEN');
const from = Deno.env.get('ENTREGA_GMAIL_FROM');
const admin = createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(crearHandler({
  habilitado: new URL(url).hostname === 'igfuafcekcpugpmsoqbe.supabase.co',
  configurado: Boolean(clientId && clientSecret && refreshToken && from === REMITENTE),
  async autorizar(token: string,id: string) {
    const client = createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}});
    const auth = await client.auth.getUser(token);
    if (auth.error || !auth.data.user) return null;
    const {data,error} = await client.rpc('entrega_correo_consultar',{p_id:id});
    return error ? null : data;
  },
  async reclamar(id: string) {
    const {data,error} = await admin.rpc('entrega_correo_reclamar',{p_id:id});
    if (error) throw error;
    return data;
  },
  async descargar(path: string) {
    const {data,error} = await admin.storage.from('seguimiento-evidencias').download(path);
    if (error) throw error;
    return new Uint8Array(await data.arrayBuffer());
  },
  base64: encodeBase64,
  async marcarInicio(id: string) {
    const {error} = await admin.from('entrega_correos').update({envio_iniciado:true}).eq('id',id);
    if (error) throw error;
  },
  async enviar(contenido: Record<string,unknown> & {attachments: unknown[]}, id: string) {
    let token;
    try {
      const refresh = await fetch('https://oauth2.googleapis.com/token', {
        method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:new URLSearchParams({client_id:clientId!,client_secret:clientSecret!,refresh_token:refreshToken!,grant_type:'refresh_token'}),signal:AbortSignal.timeout(15000),
      });
      if (!refresh.ok) throw new Error('Renueva la autorización de Gmail');
      token = (await refresh.json()).access_token;
      if (!token) throw new Error('Falta token');
    } catch { throw Object.assign(new Error('No se autorizó Gmail'),{noEnviado:true}); }
    const raw=mensajeGmail(contenido,id,logoBase64);
    const response = await fetch(`https://gmail.googleapis.com/gmail/v1/users/${REMITENTE}/messages/send`,{
      method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
      body:JSON.stringify({raw}),signal:AbortSignal.timeout(30000),
    });
    if (!response.ok) throw Object.assign(new Error('Gmail no confirmó el envío'),{noEnviado:[400,401,403,404,413,429].includes(response.status)});
    const data = await response.json();
    if (typeof data.id !== 'string') throw new Error('Respuesta inválida');
    return data.id;
  },
  async finalizar(id: string,datos: Record<string,unknown>) {
    const {error} = await admin.from('entrega_correos').update(datos).eq('id',id);
    if (error) throw error;
  },
}));
