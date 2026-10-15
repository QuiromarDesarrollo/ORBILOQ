import 'ciclos.dart';

class IndicadoresCiclos {
  IndicadoresCiclos(this.datos, {this.desde, this.hasta, this.cliente});
  final DatosCiclos datos;
  final DateTime? desde, hasta;
  final String? cliente;
  late final List<OrdenCiclo> ordenes =
      datos.ordenes
          .where((o) => cliente == null || o.cliente == cliente)
          .toList();
  bool enPeriodo(DateTime? d) =>
      d != null &&
      (desde == null || !d.isBefore(desde!)) &&
      (hasta == null || !d.isAfter(hasta!)) &&
      !d.isAfter(datos.hoy);
  final _terminadas = <ProcesoCiclo, List<MedicionCiclo>>{};
  final _duracionesOrdenadas = <ProcesoCiclo, List<int>>{};
  double? percentilProceso(ProcesoCiclo proceso, double p) {
    final valores = _duracionesOrdenadas.putIfAbsent(
      proceso,
      () => terminadas(proceso).map((m) => m.duracion!).toList()..sort(),
    );
    if (valores.isEmpty) return null;
    final posicion = (valores.length - 1) * p;
    final a = posicion.floor(), b = posicion.ceil();
    return valores[a] + (valores[b] - valores[a]) * (posicion - a);
  }

  List<MedicionCiclo> terminadas(ProcesoCiclo p) => _terminadas.putIfAbsent(
    p,
    () => [
      for (final o in ordenes)
        if (enPeriodo(o.fines[p.index]) && o.inicioDe(p) != null)
          datos.medir(o, p),
    ],
  );
  late final List<OrdenCiclo> completas =
      ordenes.where((o) => o.completa && enPeriodo(o.fines.last)).toList();
  int duracionTotal(OrdenCiclo o) =>
      datos.calendario.transcurridos(o.inicio!, o.fines.last!);
  late final double? cumplimientoTotal = _cumplimientoTotal();
  double? _cumplimientoTotal() {
    final evaluables =
        completas.where((o) => datos.objetivoTotal(o) != null).toList();
    if (evaluables.isEmpty) return null;
    return 100 *
        evaluables
            .where((o) => duracionTotal(o) <= datos.objetivoTotal(o)!)
            .length /
        evaluables.length;
  }

  /// Exceso sobre la misma meta histórica usada para cumplimiento total.
  /// Solo OP completas, evaluables y terminadas tarde dentro del filtro.
  late final List<int> atrasosTerminadas = [
    for (final o in completas)
      if (datos.objetivoTotal(o) != null &&
          duracionTotal(o) > datos.objetivoTotal(o)!)
        duracionTotal(o) - datos.objetivoTotal(o)!,
  ];

  double? get atrasoPromedioTerminadas {
    final dias = atrasosTerminadas;
    return dias.isEmpty
        ? null
        : dias.fold<int>(0, (s, d) => s + d) / dias.length;
  }

  /// Promedia el exceso relativo de cada OP tardía, con igual peso por OP.
  /// No es el porcentaje de órdenes atrasadas ni se limita al 100 %.
  late final double? excesoPromedioPorcentaje = _excesoPromedioPorcentaje();
  double? _excesoPromedioPorcentaje() {
    final excesos = <double>[];
    for (final o in completas) {
      final meta = datos.objetivoTotal(o);
      if (meta == null || meta <= 0) continue;
      final exceso = duracionTotal(o) - meta;
      if (exceso > 0) excesos.add(100 * exceso / meta);
    }
    return excesos.isEmpty
        ? null
        : excesos.reduce((a, b) => a + b) / excesos.length;
  }

  late final int? objetivoActual = _objetivoActual();
  int? _objetivoActual() {
    final versiones = [
      for (final p in ProcesoCiclo.values)
        parametroVigente(datos.parametros, p, datos.hoy),
    ];
    return versiones.any((v) => v == null)
        ? null
        : versiones.fold<int>(3, (s, v) => s + v!.dias);
  }

  final _cumplimientos = <(ProcesoCiclo, bool), double?>{};
  double? cumplimientoProceso(ProcesoCiclo p, {bool compararActual = false}) =>
      _cumplimientos.putIfAbsent((
        p,
        compararActual,
      ), () => _cumplimientoProceso(p, compararActual));
  double? _cumplimientoProceso(ProcesoCiclo p, bool compararActual) {
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
