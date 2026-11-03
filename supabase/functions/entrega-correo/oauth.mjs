// Solo devuelve diagnósticos controlados; nunca mensajes de Google ni tokens en errores.
export async function tokenGmail(config, fetcher = fetch) {
  try {
    const response = await fetcher('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: {'Content-Type':'application/x-www-form-urlencoded'},
      body: new URLSearchParams({...config, grant_type:'refresh_token'}),
      signal: AbortSignal.timeout(15000),
    });
    const data = await response.json();
    if (!response.ok || typeof data.access_token !== 'string' || !data.access_token) {
      const codigo = data.error === 'invalid_grant' ? 'gmail_autorizacion_vencida'
        : ['invalid_client','unauthorized_client'].includes(data.error) ? 'gmail_configuracion'
        : 'gmail_temporal';
      throw Object.assign(new Error('No se autorizó Gmail'), {codigo, noEnviado:true});
    }
    return data.access_token;
  } catch (error) {
    if (error?.noEnviado) throw error;
    throw Object.assign(new Error('No se pudo conectar con Gmail'), {codigo:'gmail_temporal', noEnviado:true});
  }
}
