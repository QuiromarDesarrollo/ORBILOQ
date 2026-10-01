import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

String mensajeErrorCrearUsuario(FunctionException error) {
  dynamic detalle = error.details;
  if (detalle is String) {
    try {
      detalle = jsonDecode(detalle);
    } on FormatException {
      // Una respuesta HTML o de infraestructura no se muestra como mensaje.
      detalle = null;
    }
  }
  final codigo = 'HTTP ${error.status}';
  if (error.status == 0) {
    return 'No se recibió respuesta de admin-crear-usuario. Comprueba la conexión y actualiza la lista antes de reintentar; todavía no se puede confirmar si se creó la cuenta.';
  }
  if (error.status == 404) {
    return 'No se encontró admin-crear-usuario en el proyecto al que está conectada la aplicación ($codigo). Revisa su despliegue en ese mismo proyecto.';
  }
  if (error.status == 401) {
    return 'La solicitud fue rechazada por autenticación ($codigo). Inicia sesión nuevamente. Si persiste, revisa la configuración JWT de admin-crear-usuario.';
  }
  if (error.status == 403) {
    return 'No se autorizó la creación ($codigo). Comprueba que tu cuenta siga activa y tenga rol Administrador.';
  }
  if (error.status >= 500) {
    return 'La función no pudo ejecutarse ($codigo). Revisa los registros de admin-crear-usuario en Supabase antes de reintentar.';
  }
  if (detalle is Map && detalle['error'] is String) {
    return '${detalle['error']} ($codigo)';
  }
  return 'No se pudo confirmar la creación ($codigo). Actualiza la lista de usuarios y revisa los registros de admin-crear-usuario antes de reintentar.';
}
