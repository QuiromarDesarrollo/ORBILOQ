import { createClient } from 'npm:@supabase/supabase-js@2';
import { crearHandler } from './handler.mjs';
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } });
const comprobar = (res: { data: any; error: any }) => { if (res.error) throw res.error; return res.data; };
Deno.serve(crearHandler({
  async identificar(token: string) {
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user?.id;
  },
  async esAdmin(actor: string) {
    const usuario = comprobar(await admin.from('usuarios').select('rol,roles').eq('auth_id', actor).eq('activo', true).maybeSingle());
    return usuario && (Array.isArray(usuario.roles) ? usuario.roles.includes('admin') : usuario.rol === 'admin');
  },
  async usuario(id: string) {
    return comprobar(await admin.from('usuarios').select('auth_id').eq('id', id).maybeSingle());
  },
  async actualizar(authId: string, contrasena: string) {
    comprobar(await admin.auth.admin.updateUserById(authId, { password: contrasena }));
  },
}));
