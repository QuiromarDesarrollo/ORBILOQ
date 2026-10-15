import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/domain/ciclos_prioridades.dart';

void main(List<String> args) {
  final n = args.isEmpty ? 10000 : int.parse(args.first);
  final datos = DatosCiclos(
    [
      for (var j = 0; j < n; j++)
        OrdenCiclo(
          '$j',
          'Cliente ${j % 20}',
          100,
          DateTime.utc(2025, 1, 1).add(Duration(days: j % 500)),
          [
            for (var p = 0; p < 7; p++)
              j % 4 == 0 && p >= j % 7
                  ? null
                  : DateTime.utc(
                    2025,
                    1,
                    1,
                  ).add(Duration(days: j % 500 + (p + 1) * 5)),
          ],
          {for (final p in ProcesoCiclo.values) p.name: p.name},
        ),
    ],
    [
      for (final p in ProcesoCiclo.values)
        ParametroCiclo(
          p.name,
          p,
          DateTime.utc(2024),
          p.diasIniciales,
          100,
          500,
        ),
    ],
    DateTime.utc(2026, 10, 14),
    '1',
  );
  final i = IndicadoresCiclos(datos);
  final tiempo = Stopwatch()..start();
  double checksum = 0;
  void calcular() {
    checksum += i.cumplimientoTotal ?? 0;
    checksum += i.excesoPromedioPorcentaje ?? 0;
    for (final p in ProcesoCiclo.values) {
      checksum += i.cumplimientoProceso(p) ?? 0;
      checksum += percentil(i.terminadas(p).map((m) => m.duracion!), .8) ?? 0;
    }
    final prioridad = PrioridadesCiclos(i);
    for (final p in prioridad.ordenados) {
      checksum += p.mayorAtraso;
      checksum += p.cumplimiento ?? 0;
    }
  }

  calcular();
  final inicial = tiempo.elapsedMilliseconds;
  calcular();
  // ignore: avoid_print -- salida de la herramienta de medición, no de la app.
  print(
    'OP=$n inicial_ms=$inicial repeticion_ms=${tiempo.elapsedMilliseconds - inicial} checksum=$checksum',
  );
}
