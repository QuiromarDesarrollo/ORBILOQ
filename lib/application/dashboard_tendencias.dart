import '../data/reportes_admin_repository.dart';

const tiposVolumen = ['entrega_produccion', 'recepcion', 'despacho'];

class SemanaVolumen {
  SemanaVolumen(this.inicio) : unidades = [0, 0, 0];
  final DateTime inicio;
  final List<int> unidades;
}

class TendenciasVolumen {
  const TendenciasVolumen(this.semanas, this.registrosInvalidos);
  final List<SemanaVolumen> semanas;
  final int registrosInvalidos;
  List<int> get totales => [
        for (var serie = 0; serie < 3; serie++)
          semanas.fold(0, (n, s) => n + s.unidades[serie])
      ];
}

/// Volumen operativo bruto por fecha del movimiento (no saldos del kardex).
/// Correcciones/importaciones administrativas y movimientos inversos no se
/// interpretan como producción física realizada en la semana de la corrección.
TendenciasVolumen calcularTendencias(List<FilaReporte> filas,
    {required DateTime corte, int semanas = 12}) {
  final hoy = fechaReporte(corte.toUtc().toIso8601String())!;
  final lunes = DateTime.utc(hoy.year, hoy.month, hoy.day - hoy.weekday + 1);
  final desde = lunes.subtract(Duration(days: 7 * (semanas - 1)));
  final buckets = [
    for (var i = 0; i < semanas; i++)
      SemanaVolumen(desde.add(Duration(days: i * 7)))
  ];
  var invalidos = 0;
  for (final f in filas) {
    final serie = tiposVolumen.indexOf('${f['tipo']}');
    if (serie < 0) continue;
    final crudo = f['datos_crudos'];
    if (crudo is Map && crudo['admin_correccion_id'] != null) continue;
    final cantidad = num.tryParse('${f['cantidad']}');
    final instante = DateTime.tryParse('${f['fecha']}');
    if (cantidad == null ||
        !cantidad.isFinite ||
        cantidad != cantidad.truncateToDouble() ||
        instante == null) {
      invalidos++;
      continue;
    }
    if (cantidad <= 0 || instante.toUtc().isAfter(corte.toUtc())) continue;
    final local = fechaReporte(f['fecha'])!;
    final dia = DateTime.utc(local.year, local.month, local.day);
    final dias = dia.difference(desde).inDays;
    if (dias < 0 || dias >= semanas * 7) continue;
    buckets[dias ~/ 7].unidades[serie] += cantidad.toInt();
  }
  return TendenciasVolumen(buckets, invalidos);
}
