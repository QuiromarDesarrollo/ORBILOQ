/// El rol real de la cuenta con la que se inició sesión. Distinto de [Rol]
/// (que representa qué pantalla se está viendo): un Administrador puede ver
/// tanto la pantalla de Producción como la de Logística.
enum RolCuenta {
  produccion('produccion', 'Producción'),
  logistica('logistica', 'Logística'),
  admin('admin', 'Administrador');

  const RolCuenta(this.valorBd, this.etiqueta);
  final String valorBd;
  final String etiqueta;

  static RolCuenta? desde(String valor) {
    for (final r in RolCuenta.values) {
      if (r.valorBd == valor) return r;
    }
    return null;
  }
}

/// Datos de la persona que inició sesión (leídos de la tabla `usuarios`).
class UsuarioSesion {
  const UsuarioSesion({
    required this.numeroUsuario,
    required this.nombre,
    required this.rolCuenta,
  });

  final String numeroUsuario;
  final String nombre;
  final RolCuenta rolCuenta;
}
