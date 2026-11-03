import 'package:shared_preferences/shared_preferences.dart';

Future<String?> operar(String key, String? value, {bool delete = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final name = 'orbiloq-transporte-borrador:$key';
  if (delete) {
    if (!await prefs.remove(name)) {
      throw StateError('No se pudo quitar el borrador.');
    }
  } else if (value != null) {
    if (!await prefs.setString(name, value)) {
      throw StateError('No se pudo guardar el borrador.');
    }
  } else {
    return prefs.getString(name);
  }
  return null;
}
