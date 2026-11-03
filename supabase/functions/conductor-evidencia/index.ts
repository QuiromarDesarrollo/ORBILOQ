import { obtenerVistaPrevia } from './preview.mjs';
import { createClient } from 'npm:@supabase/supabase-js@2';
import { OAuth2Client } from 'npm:google-auth-library@9.15.1';
import { crearHandler, DRIVE_FOLDER_ID } from './handler.mjs';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const clientId = Deno.env.get('CONDUCTOR_GOOGLE_CLIENT_ID');
const clientSecret = Deno.env.get('CONDUCTOR_GOOGLE_CLIENT_SECRET');
const refreshToken = Deno.env.get('CONDUCTOR_GOOGLE_REFRESH_TOKEN');
const oauth = new OAuth2Client(clientId, clientSecret);
oauth.setCredentials({ refresh_token: refreshToken });

Deno.serve(crearHandler({
  habilitado: ['igfuafcekcpugpmsoqbe.supabase.co', 'cxrflhgnxvomcvxzugda.supabase.co'].includes(new URL(supabaseUrl).hostname),
  configurado: Boolean(clientId && clientSecret && refreshToken),
  async autorizar(token: string, vehiculo: string) {
    // La lectura conserva RLS: usuario activo admin o conductor asignado.
    const client = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: auth, error } = await client.auth.getUser(token);
    if (error || !auth.user) return null;
    const { data: v, error: denied } = await client.from('conductor_vehiculos')
      .select('placa,datos').eq('id', vehiculo).maybeSingle();
    return denied || !v ? null : { placa: v.placa, actor: auth.user.id, datos: v.datos };
  },
  async previsualizar({ id, vehiculo }: { id: string; vehiculo: string }) {
    const { token } = await oauth.getAccessToken();
    if (!token) throw new Error('Unavailable');
    return obtenerVistaPrevia({ token, id, vehiculo, carpeta: DRIVE_FOLDER_ID });
  },
  async iniciar({ metadata, mime, bytes, origin }: {
    metadata: Record<string, unknown>; mime: string; bytes: number; origin: string | null;
  }) {
    const { token } = await oauth.getAccessToken();
    if (!token) throw new Error('Google authorization unavailable');
    const response = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true&fields=id', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`, 'Content-Type': 'application/json',
          'X-Upload-Content-Type': mime, 'X-Upload-Content-Length': String(bytes),
          ...(origin ? { Origin: origin } : {}),
        }, body: JSON.stringify(metadata), signal: AbortSignal.timeout(25000),
      });
    if (!response.ok || !response.headers.get('location')) throw new Error('Drive session unavailable');
    return response.headers.get('location')!;
  },
}));
