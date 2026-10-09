import 'package:web/web.dart' as web;

const _clave = 'orbiloq.apariencia.sesion';

String? leerTemaGuardado() {
  try {
    return web.window.localStorage.getItem(_clave);
  } catch (_) {
    return null;
  }
}

void escribirTemaGuardado(String valor) {
  try {
    web.window.localStorage.setItem(_clave, valor);
  } catch (_) {
    // La apariencia sigue funcionando si el navegador bloquea el almacenamiento.
  }
}
