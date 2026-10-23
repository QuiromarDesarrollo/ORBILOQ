import 'package:web/web.dart' as web;

String? leer(String clave) {
  try {
    return web.window.localStorage.getItem(clave);
  } catch (_) {
    return null;
  }
}

void guardar(String clave, String valor) {
  try {
    web.window.localStorage.setItem(clave, valor);
  } catch (_) {}
}
