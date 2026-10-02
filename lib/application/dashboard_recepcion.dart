import '../data/reportes_admin_repository.dart';
import 'dashboard_tendencias.dart';

class ResumenRecepcion {
  const ResumenRecepcion({
    required this.conformes,
    required this.novedades,
    required this.enTransito,
    required this.sobrantes,
    required this.recibidas,
    required this.resueltos,
    required this.diasPromedio,
    required this.tasasSemanales,
    required this.diasSemanales,
    required this.semanas,
    required this.invalidos,
  });
  final int conformes,
      novedades,
      enTransito,
      sobrantes,
      recibidas,
      resueltos,
      invalidos;
  final double? diasPromedio;
  final List<double?> tasasSemanales, diasSemanales;
  final List<DateTime> semanas;
  int get recepciones => conformes + novedades;
  double? get porcentajeConforme =>
      recepciones == 0 ? null : conformes * 100 / recepciones;
  double? get tasaSobrantes =>
      recibidas == 0 ? null : sobrantes * 100 / recibidas;
}

ResumenRecepcion calcularRecepcion(
  List<FilaReporte> auditoria,
  List<FilaReporte> movimientos, {
  required DateTime corte,
  required int semanas,
}) {
  final volumen = calcularTendencias(
    movimientos,
    corte: corte,
    semanas: semanas,
  );
  final inicios = volumen.semanas.map((s) => s.inicio).toList();
  final sobrantesSemana = List<int>.filled(semanas, 0);
  final diasSemana = List<double>.filled(semanas, 0);
  final resueltosSemana = List<int>.filled(semanas, 0);
  var conformes = 0, novedades = 0, enTransito = 0, invalidos = 0;
  int? indice(DateTime? fecha) {
    if (fecha == null || fecha.toUtc().isAfter(corte.toUtc())) return null;
    final local = fechaReporte(fecha.toUtc().toIso8601String())!;
    final dias =
        DateTime.utc(
          local.year,
          local.month,
          local.day,
        ).difference(inicios.first).inDays;
    return dias < 0 || dias >= semanas * 7 ? null : dias ~/ 7;
  }

  final vistos = <String>{};
  for (final fila in auditoria) {
    final origen = fila['origen'];
    if (origen != 'Recepción' && origen != 'Sobrantes') continue;
    final id = '${fila['registro']}';
    if (!vistos.add(id)) continue;
    final raw = fila['datos_crudos'];
    if (raw is! Map) {
      invalidos++;
      continue;
    }
    final fecha = DateTime.tryParse('${fila['fecha']}');
    if (fecha == null) {
      invalidos++;
      continue;
    }
    final semana = indice(fecha);
    if (origen == 'Recepción') {
      if (semana == null) continue;
      switch (raw['estado']) {
        case 'recibido_conforme':
          conformes++;
        case 'recibido_con_novedad':
          novedades++;
        case 'en_transito':
          enTransito++;
        default:
          invalidos++;
      }
    } else {
      if (semana != null) {
        final cantidad = num.tryParse('${raw['cantidad']}');
        if (cantidad == null ||
            !cantidad.isFinite ||
            cantidad <= 0 ||
            cantidad != cantidad.truncateToDouble()) {
          invalidos++;
        } else {
          sobrantesSemana[semana] += cantidad.toInt();
        }
      }
      // La cohorte se define por fecha de resolución, aunque el sobrante
      // haya sido registrado antes del período seleccionado.
      if (raw['estado'] != 'resuelto') continue;
      final fin = DateTime.tryParse('${raw['fecha_resolucion']}');
      final inicio = DateTime.tryParse('${raw['fecha']}');
      if (fin == null || inicio == null || fin.isBefore(inicio)) {
        invalidos++;
        continue;
      }
      final semanaFin = indice(fin);
      if (semanaFin == null) continue;
      diasSemana[semanaFin] +=
          fin.difference(inicio).inSeconds / Duration.secondsPerDay;
      resueltosSemana[semanaFin]++;
    }
  }
  final resueltos = resueltosSemana.fold(0, (a, b) => a + b);
  return ResumenRecepcion(
    conformes: conformes,
    novedades: novedades,
    enTransito: enTransito,
    sobrantes: sobrantesSemana.fold(0, (a, b) => a + b),
    recibidas: volumen.totales[1],
    resueltos: resueltos,
    diasPromedio:
        resueltos == 0
            ? null
            : diasSemana.fold(0.0, (a, b) => a + b) / resueltos,
    tasasSemanales: [
      for (var i = 0; i < semanas; i++)
        volumen.semanas[i].unidades[1] == 0
            ? null
            : sobrantesSemana[i] * 100 / volumen.semanas[i].unidades[1],
    ],
    diasSemanales: [
      for (var i = 0; i < semanas; i++)
        resueltosSemana[i] == 0 ? null : diasSemana[i] / resueltosSemana[i],
    ],
    semanas: inicios,
    invalidos: invalidos,
  );
}
