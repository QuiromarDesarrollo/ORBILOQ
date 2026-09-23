import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/sesion.dart';

/// `true` cuando la app está conectada a Supabase (vs. modo de datos de
/// prueba en memoria). Se sobrescribe en main.dart. En modo memoria no hay
/// login: el comportamiento libre de antes se mantiene para desarrollo.
final usarSupabaseProvider = Provider<bool>((ref) => false);

/// `null` en modo memoria; en modo Supabase, la implementación real.
final authRepositoryProvider = Provider<AuthRepository?>((ref) => null);

/// Emite cada cambio de sesión (inicio/cierre) en tiempo real. Solo se debe
/// observar cuando `usarSupabaseProvider` es true.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// La sesión actual con los datos de `usuarios` (rol, nombre) ya resueltos.
/// `null` si no hay nadie autenticado.
final usuarioSesionProvider = FutureProvider<UsuarioSesion?>((ref) async {
  // Observar el stream hace que este provider se vuelva a calcular en cada
  // inicio/cierre de sesión, sin necesidad de refrescar la página.
  ref.watch(authStateProvider);

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final fila = await Supabase.instance.client
      .from('usuarios')
      .select('numero_usuario, nombre, rol')
      .eq('auth_id', user.id)
      .maybeSingle();

  if (fila == null) return null;
  final rol = RolCuenta.desde(fila['rol'] as String);
  if (rol == null) return null;

  return UsuarioSesion(
    numeroUsuario: (fila['numero_usuario'] as String?) ?? '',
    nombre: fila['nombre'] as String,
    rolCuenta: rol,
  );
});
