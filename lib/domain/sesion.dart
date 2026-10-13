import 'models.dart';

/// El rol real de la cuenta con la que se inició sesión. Distinto de [Rol]
/// (que representa qué pantalla se está viendo): un Administrador puede ver
/// tanto la pantalla de Producción como la de Logística.
enum RolCuenta {
  produccion('produccion', 'Producción'),
  logistica('logistica', 'Bodega'),
  despacho('despacho', 'Despacho'),
  seguimiento('seguimiento', 'Seguimiento'),
  gerencia('gerencia', 'Gerencia'),
  admin('admin', 'Administrador');

  const RolCuenta(this.valorBd, this.etiqueta);
  final String valorBd;
  final String etiqueta;
  bool get puedeVerDashboards => this == admin || this == gerencia;

  static RolCuenta? desde(String valor) {
    for (final r in RolCuenta.values) {
      if (r.valorBd == valor) return r;
    }
    return null;
  }

  /// Orden estable compartido con SQL; mantiene el rol principal compatible.
  static const prioridad = [
    admin,
    seguimiento,
    produccion,
    logistica,
    despacho,
    gerencia,
  ];
  static List<RolCuenta> deFila(Map<String, dynamic> fila) {
    final valores =
        fila['roles'] is List ? fila['roles'] as List : [fila['rol']];
    return prioridad.where((r) => valores.contains(r.valorBd)).toList();
  }

  static String etiquetas(Map<String, dynamic> fila) =>
      deFila(fila).map((r) => r.etiqueta).join(' · ');
}

/// Datos de la persona que inició sesión (leídos de la tabla `usuarios`).
class UsuarioSesion {
  const UsuarioSesion({
    required this.numeroUsuario,
    required this.nombre,
    required this.rolCuenta,
    this.roles = const {},
  });

  final String numeroUsuario;
  final String nombre;
  final RolCuenta rolCuenta;
  final Set<RolCuenta> roles;
  Set<RolCuenta> get perfiles => roles.isEmpty ? {rolCuenta} : roles;
  bool tieneRol(RolCuenta rol) => perfiles.contains(rol);
  bool get puedeVerDashboards => perfiles.any((r) => r.puedeVerDashboards);
  bool get puedeSeguimiento =>
      tieneRol(RolCuenta.admin) || tieneRol(RolCuenta.seguimiento);
  String get etiquetas => RolCuenta.prioridad
      .where(perfiles.contains)
      .map((r) => r.etiqueta)
      .join(' · ');
  List<Rol> get areas => [
    if (tieneRol(RolCuenta.admin) || tieneRol(RolCuenta.produccion))
      Rol.produccion,
    if (tieneRol(RolCuenta.admin) || tieneRol(RolCuenta.logistica))
      Rol.logistica,
    if (tieneRol(RolCuenta.admin) ||
        tieneRol(RolCuenta.despacho) ||
        tieneRol(RolCuenta.seguimiento))
      Rol.despacho,
  ];
  bool get soloGerencia => areas.isEmpty && tieneRol(RolCuenta.gerencia);
}
