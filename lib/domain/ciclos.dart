import 'dart:math' as math;

enum ProcesoCiclo {
  compras('Compras', 6),
  trazo('Trazo', 3),
  corte('Corte', 3),
  separado('Separado', 4),
  aliados('Aliados', 11),
  terminado('Terminado', 2),
  logistica('Logística', 3);

  const ProcesoCiclo(this.titulo, this.diasIniciales);
  final String titulo;
  final int diasIniciales;
  bool get porOrdenes => index < 2;
  String get unidad => porOrdenes ? 'OP' : 'unidades';
  int? get semanalInicial => switch (this) {
    corte || separado => 7000,
    aliados => 17000,
    _ => null,
  };
}

DateTime diaCiclo(DateTime d) => DateTime.utc(d.year, d.month, d.day);
String fechaCiclo(DateTime d) => d.toIso8601String().substring(0, 10);
DateTime? leerFechaCiclo(dynamic s) =>
    s == null ? null : diaCiclo(DateTime.parse('$s'));

/// Festivos nacionales de Colombia, Ley 51 de 1983. Fechas civiles sin zona horaria.
class CalendarioColombia {
  final _cache = <int, Set<DateTime>>{};
  Set<DateTime> festivos(int y) => _cache.putIfAbsent(y, () {
    DateTime lunes(DateTime d) => d.add(Duration(days: (8 - d.weekday) % 7));
    // Computus gregoriano (Meeus/Jones/Butcher).
    final a = y % 19,
        b = y ~/ 100,
        c = y % 100,
        d = b ~/ 4,
        e = b % 4,
        f = (b + 8) ~/ 25,
        g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30,
        i = c ~/ 4,
        k = c % 4,
        l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451, n = h + l - 7 * m + 114;
    final pascua = DateTime.utc(y, n ~/ 31, n % 31 + 1);
    return {
      for (final md in [
        [1, 1],
        [5, 1],
        [7, 20],
        [8, 7],
        [12, 8],
        [12, 25],
      ])
        DateTime.utc(y, md[0], md[1]),
      for (final md in [
        [1, 6],
        [3, 19],
        [6, 29],
        [8, 15],
        [10, 12],
        [11, 1],
        [11, 11],
      ])
        lunes(DateTime.utc(y, md[0], md[1])),
      pascua.subtract(const Duration(days: 3)),
      pascua.subtract(const Duration(days: 2)),
      for (final dias in [39, 60, 68]) lunes(pascua.add(Duration(days: dias))),
    };
  });
  bool habil(DateTime d) =>
      d.weekday <= 5 && !festivos(d.year).contains(diaCiclo(d));
  DateTime sumar(DateTime inicio, int dias) {
    var d = diaCiclo(inicio);
    for (var n = 0; n < dias;) {
      d = d.add(const Duration(days: 1));
      if (habil(d)) n++;
    }
    return d;
  }

  /// Excluye el día inicial e incluye el final. Una entrega el mismo día dura 0.
  int transcurridos(DateTime inicio, DateTime fin) {
    var n = 0;
    for (
      var d = diaCiclo(inicio).add(const Duration(days: 1));
      !d.isAfter(diaCiclo(fin));
      d = d.add(const Duration(days: 1))
    ) {
      if (habil(d)) n++;
    }
    return n;
  }
}

class ParametroCiclo {
  ParametroCiclo(
    this.id,
    this.proceso,
    this.desde,
    this.dias,
    this.diaria,
    this.semanal, {
    this.umbralCola,
  });
  final String id;
  final ProcesoCiclo proceso;
  final DateTime desde;
  final int dias;
  final int? diaria, semanal, umbralCola;
  factory ParametroCiclo.json(Map<String, dynamic> j) => ParametroCiclo(
    '${j['id']}',
    ProcesoCiclo.values.byName(j['proceso']),
    leerFechaCiclo(j['vigente_desde'])!,
    j['dias'] as int,
    j['capacidad_diaria'] as int?,
    j['capacidad_semanal'] as int?,
    umbralCola: j['umbral_cola'] as int?,
  );
}

ParametroCiclo? parametroVigente(
  List<ParametroCiclo> parametros,
  ProcesoCiclo p,
  DateTime dia,
) {
  final candidatos =
      parametros
          .where((v) => v.proceso == p && !v.desde.isAfter(diaCiclo(dia)))
          .toList()
        ..sort((a, b) => b.desde.compareTo(a.desde));
  return candidatos.firstOrNull;
}

class OrdenCiclo {
  OrdenCiclo(
    this.op,
    this.cliente,
    this.cantidad,
    this.inicio,
    this.fines,
    this.versiones,
  );
  final String op, cliente;
  final int cantidad;
  final DateTime? inicio;
  final List<DateTime?> fines;
  final Map<String, dynamic> versiones;
  factory OrdenCiclo.json(Map<String, dynamic> j) => OrdenCiclo(
    '${j['op']}',
    '${j['cliente']}',
    j['cantidad'] as int,
    leerFechaCiclo(j['inicio']),
    [
      for (final p in ProcesoCiclo.values)
        leerFechaCiclo((j['fines'] as Map)[p.name]),
    ],
    Map<String, dynamic>.from(j['versiones'] as Map? ?? {}),
  );
  DateTime? inicioDe(ProcesoCiclo p) =>
      p.index == 0 ? inicio : fines[p.index - 1];
  bool get completa => inicio != null && fines.every((d) => d != null);
}

class MedicionCiclo {
  MedicionCiclo(
    this.orden,
    this.proceso,
    this.parametro,
    this.calendario,
    this.hoy,
  );
  final OrdenCiclo orden;
  final ProcesoCiclo proceso;
  final ParametroCiclo? parametro;
  final CalendarioColombia calendario;
  final DateTime hoy;
  DateTime? get inicio => orden.inicioDe(proceso);
  DateTime? get fin => orden.fines[proceso.index];
  DateTime? get esperada =>
      inicio == null || parametro == null
          ? null
          : calendario.sumar(inicio!, parametro!.dias);
  int? get duracion =>
      inicio == null || fin == null
          ? null
          : calendario.transcurridos(inicio!, fin!);
  bool? get cumplio =>
      esperada == null || fin == null ? null : !fin!.isAfter(esperada!);
  String get estado =>
      inicio == null
          ? 'Sin iniciar'
          : parametro == null
          ? 'Sin parámetros vigentes'
          : fin != null
          ? (cumplio! ? 'A tiempo' : 'Con retraso')
          : hoy.isAfter(esperada!)
          ? 'Vencido'
          : 'En proceso';
}

class DatosCiclos {
  DatosCiclos(this.ordenes, this.parametros, this.hoy, this.revision);
  final List<OrdenCiclo> ordenes;
  final List<ParametroCiclo> parametros;
  final DateTime hoy;
  final String revision;
  final calendario = CalendarioColombia();
  MedicionCiclo medir(OrdenCiclo o, ProcesoCiclo p) {
    final id = o.versiones[p.name];
    // Sin asignación no se inventa una versión: el servidor la asocia al importar/configurar.
    final parametro =
        parametros.where((v) => v.id == id && v.proceso == p).firstOrNull;
    return MedicionCiclo(o, p, parametro, calendario, hoy);
  }

  int? objetivoTotal(OrdenCiclo o) {
    final versiones = [
      for (final p in ProcesoCiclo.values) medir(o, p).parametro,
    ];
    if (versiones.any((p) => p == null)) return null;
    return versiones.fold<int>(3, (s, p) => s + p!.dias);
  }
}

double? percentil(Iterable<int> valores, double p) {
  final v = valores.toList()..sort();
  if (v.isEmpty) return null;
  final x = (v.length - 1) * p, a = x.floor(), b = x.ceil();
  return v[a] + (v[b] - v[a]) * (x - a);
}

class CargaCiclo {
  const CargaCiclo(
    this.inicial,
    this.entradas,
    this.salidas,
    this.finalPendiente,
    this.ordenesTerminadas,
  );
  final int inicial, entradas, salidas, finalPendiente, ordenesTerminadas;
  int get porAtender => inicial + entradas;
  static CargaCiclo calcular(
    List<OrdenCiclo> ordenes,
    ProcesoCiclo p,
    DateTime desde,
    DateTime hasta,
  ) {
    var inicial = 0, entradas = 0, salidas = 0, ops = 0;
    for (final o in ordenes) {
      final inicio = o.inicioDe(p),
          fin = o.fines[p.index],
          n = p.porOrdenes ? 1 : o.cantidad;
      if (inicio == null || inicio.isAfter(hasta)) continue;
      if (inicio.isBefore(desde) && (fin == null || !fin.isBefore(desde))) {
        inicial += n;
      }
      if (!inicio.isBefore(desde)) entradas += n;
      if (fin != null && !fin.isBefore(desde) && !fin.isAfter(hasta)) {
        salidas += n;
        ops++;
      }
    }
    return CargaCiclo(
      inicial,
      entradas,
      salidas,
      math.max(0, inicial + entradas - salidas),
      ops,
    );
  }
}
