import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../domain/sesion.dart';

/// La revalidación periódica de sesión no debe invalidar los reportes.
/// La identidad y el rol sí cambian el acceso y descartan datos de otra cuenta.
final dashboardAccesoProvider = Provider<(String?, RolCuenta?)>((ref) {
  if (!ref.watch(usarSupabaseProvider)) return ('demo', RolCuenta.admin);
  return ref.watch(
    usuarioSesionProvider.select((sesion) {
      if (sesion.hasError) return (null, null);
      final usuario = sesion.value;
      return (usuario?.numeroUsuario, usuario?.rolCuenta);
    }),
  );
});
