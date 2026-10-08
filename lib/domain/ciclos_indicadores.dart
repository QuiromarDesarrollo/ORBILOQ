import 'ciclos.dart';

class IndicadoresCiclos {
  IndicadoresCiclos(this.datos, {this.desde, this.hasta, this.cliente});
  final DatosCiclos datos;
  final DateTime? desde, hasta;
  final String? cliente;
  List<OrdenCiclo> get ordenes =>
      datos.ordenes
          .where((o) => cliente == null || o.cliente == cliente)
          .toList();
  bool enPeriodo(DateTime? d) =>
      d != null &&
      (desde == null || !d.isBefore(desde!)) &&
      (hasta == null || !d.isAfter(hasta!)) &&
      !d.isAfter(datos.hoy);
  List<MedicionCiclo> terminadas(ProcesoCiclo p) => [
    for (final o in ordenes)
      if (enPeriodo(o.fines[p.index]) && o.inicioDe(p) != null)
        datos.medir(o, p),
  ];
  List<OrdenCiclo> get completas =>
      ordenes.where((o) => o.completa && enPeriodo(o.fines.last)).toList();
  int duracionTotal(OrdenCiclo o) =>
      datos.calendario.transcurridos(o.inicio!, o.fines.last!);
  double? get cumplimientoTotal {
    final evaluables =
        completas.where((o) => datos.objetivoTotal(o) != null).toList();
    if (evaluables.isEmpty) return null;
    return 100 *
        evaluables
            .where((o) => duracionTotal(o) <= datos.objetivoTotal(o)!)
            .length /
        evaluables.length;
  }

  int? get objetivoActual {
    final versiones = [
      for (final p in ProcesoCiclo.values)
        parametroVigente(datos.parametros, p, datos.hoy),
    ];
    return versiones.any((v) => v == null)
        ? null
        : versiones.fold<int>(3, (s, v) => s + v!.dias);
  }

  double? cumplimientoProceso(ProcesoCiclo p, {bool compararActual = false}) {
    final objetivo = parametroVigente(datos.parametros, p, datos.hoy);
    final lista =
        terminadas(p)
            .where((m) => compararActual ? objetivo != null : m.cumplio != null)
            .toList();
    if (lista.isEmpty) return null;
    return 100 *
        lista
            .where(
              (m) =>
                  compararActual ? m.duracion! <= objetivo!.dias : m.cumplio!,
            )
            .length /
        lista.length;
  }

  /// Capacidad semanal independiente. Si cambia a mitad de semana no se inventa
  /// una prorrata: se muestra sin valor y se consulta el desglose diario.
  int? capacidad(
    ProcesoCiclo p,
    DateTime desde,
    DateTime hasta, {
    required bool semanal,
  }) {
    if (!semanal) {
      return datos.calendario.habil(desde)
          ? parametroVigente(datos.parametros, p, desde)?.diaria
          : null;
    }
    final versiones = <String>{};
    int? capacidad;
    for (var d = desde; !d.isAfter(hasta); d = d.add(const Duration(days: 1))) {
      if (!datos.calendario.habil(d)) continue;
      final v = parametroVigente(datos.parametros, p, d);
      if (v?.semanal == null) return null;
      versiones.add(v!.id);
      capacidad = v.semanal;
    }
    return versiones.length == 1 ? capacidad : null;
  }
}
