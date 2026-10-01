import { createClient } from 'npm:@supabase/supabase-js@2';
import { crearHandler } from './handler.mjs';

// Estas variables existen SOLO en el entorno del servidor de Supabase.
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } });
const comprobar = (res: { data: any; error: any }) => { if (res.error) throw res.error; return res.data; };

Deno.serve(crearHandler({
  async identificar(token: string) {
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user?.id;
  },
  async esAdmin(id: string) {
    return Boolean(comprobar(await admin.from('usuarios').select('id').eq('auth_id', id).eq('rol', 'admin').eq('activo', true).maybeSingle()));
  },
  async existeNumero(numero: string) {
    return Boolean(comprobar(await admin.from('usuarios').select('id').eq('numero_usuario', numero).maybeSingle()));
  },
  async pendiente(numero: string) {
    return comprobar(await admin.rpc('admin_usuario_alta_pendiente', { p_numero: numero }));
  },
  async crearAuth({ email, password }: { email: string; password: string }) {
    const data = comprobar(await admin.auth.admin.createUser({ email, password, email_confirm: true,
      app_metadata: { orbiloq_alta_catalogo: true } }));
    if (!data?.user?.id) throw new Error('Alta no completada');
    return data.user.id;
  },
  async registrar({ actor, authId, numero, nombre, rol }: { actor: string; authId: string; numero: string; nombre: string; rol: string }) {
    return comprobar(await admin.rpc('admin_usuario_registrar', { p_actor: actor, p_auth_id: authId,
      p_numero: numero, p_nombre: nombre, p_rol: rol }));
  },
}));
