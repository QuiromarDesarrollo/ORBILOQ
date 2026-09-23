import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';

/// Traduce "número de usuario" a un correo sintético interno, porque
/// Supabase Auth solo entiende correo/contraseña. La persona nunca ve
/// ni escribe un correo — solo su número y su contraseña.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static String emailDesdeUsuario(String numeroUsuario) => '${numeroUsuario.trim()}@orbiloq.local';

  Future<Result<void>> iniciarSesion(String numeroUsuario, String contrasena) async {
    if (numeroUsuario.trim().isEmpty || contrasena.isEmpty) {
      return const Err<void>('Ingresa tu usuario y contraseña.');
    }
    try {
      await _client.auth.signInWithPassword(
        email: emailDesdeUsuario(numeroUsuario),
        password: contrasena,
      );
      return const Ok<void>(null);
    } on AuthException catch (e) {
      return Err<void>(_mensajeAmigable(e));
    } catch (e) {
      return Err<void>('No se pudo iniciar sesión: $e');
    }
  }

  String _mensajeAmigable(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid_credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }
    return e.message;
  }

  Future<void> cerrarSesion() => _client.auth.signOut();
}
