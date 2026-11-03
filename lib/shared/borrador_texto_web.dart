import 'package:web/web.dart' as web;

String? leerTextoBorrador(String key) => web.window.localStorage.getItem(key);
void escribirTextoBorrador(String key, String value) =>
    web.window.localStorage.setItem(key, value);
