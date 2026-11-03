import 'package:web/web.dart' as web;

// Solo se conserva una operación incierta de esta pestaña, separada por usuario.
// Nunca es una cola offline: se recupera explícitamente con la misma clave.
String? leerPendienteMasiva(String usuario) =>
    web.window.sessionStorage.getItem('orbiloq.masiva.pendiente.$usuario');
void guardarPendienteMasiva(String usuario, String? valor) {
  final key = 'orbiloq.masiva.pendiente.$usuario';
  if (valor == null) {
    web.window.sessionStorage.removeItem(key);
  } else {
    web.window.sessionStorage.setItem(key, valor);
  }
}
