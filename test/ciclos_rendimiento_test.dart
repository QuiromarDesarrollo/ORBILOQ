import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/ciclos_preparacion.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';

void main() {
  test(
    'Calendario optimizado coincide con recorrido diario en festivos y años bisiestos',
    () {
      final calendario = CalendarioColombia(), azar = Random(42);
      for (var i = 0; i < 500; i++) {
        final inicio = DateTime.utc(
          1998 + azar.nextInt(40),
          1,
          1,
        ).add(Duration(days: azar.nextInt(365)));
        final fin = inicio.add(Duration(days: azar.nextInt(800) - 10));
        var esperado = 0;
        for (
          var d = inicio.add(const Duration(days: 1));
          !d.isAfter(fin);
          d = d.add(const Duration(days: 1))
        ) {
          if (calendario.habil(d)) esperado++;
        }
        expect(calendario.transcurridos(inicio, fin), esperado);
        final dias = azar.nextInt(50);
        var fecha = inicio, restantes = dias;
        while (restantes > 0) {
          fecha = fecha.add(const Duration(days: 1));
          if (calendario.habil(fecha)) restantes--;
        }
        expect(calendario.sumar(inicio, dias), fecha);
      }
    },
  );
  test('Una nueva revisión o filtro no reutiliza resultados anteriores', () {
    final inicio = DateTime.utc(2026, 1, 5);
    DatosCiclos datos(int dias) => DatosCiclos(
      [
        OrdenCiclo(
          '1',
          'A',
          10,
          inicio,
          List.filled(7, DateTime.utc(2026, 1, 9)),
          {'compras': 'v'},
        ),
        OrdenCiclo(
          '2',
          'B',
          20,
          inicio,
          List.filled(7, DateTime.utc(2026, 1, 9)),
          {'compras': 'v'},
        ),
      ],
      [ParametroCiclo('v', ProcesoCiclo.compras, inicio, dias, null, null)],
      DateTime.utc(2026, 1, 10),
      '$dias',
    );
    final a = datos(6), b = datos(1);
    expect(a.medir(a.ordenes.first, ProcesoCiclo.compras).cumplio, true);
    expect(b.medir(b.ordenes.first, ProcesoCiclo.compras).cumplio, false);
    expect(IndicadoresCiclos(a, cliente: 'A').ordenes.single.op, '1');
    expect(IndicadoresCiclos(a, cliente: 'B').ordenes.single.op, '2');
    expect(IndicadoresCiclos(a, hasta: inicio).completas, isEmpty);
    expect(IndicadoresCiclos(a).completas.length, 2);
  });
  test(
    'Preparación de 10000 OP cede al bucle de eventos y conserva resultados',
    () async {
      final inicio = DateTime.utc(2025, 1, 1);
      final datos = DatosCiclos(
        [
          for (var n = 0; n < 10000; n++)
            OrdenCiclo(
              '$n',
              'Cliente',
              1,
              inicio,
              [
                for (var p = 0; p < 7; p++)
                  inicio.add(Duration(days: (p + 1) * 6)),
              ],
              {for (final p in ProcesoCiclo.values) p.name: p.name},
            ),
        ],
        [
          for (final p in ProcesoCiclo.values)
            ParametroCiclo(p.name, p, inicio, p.diasIniciales, null, null),
        ],
        DateTime.utc(2026, 10, 14),
        '1',
      );
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      try {
        expect(identical(await prepararCiclos(datos), datos), true);
      } finally {
        timer.cancel();
      }
      expect(ticks, greaterThan(0));
      final indicadores = IndicadoresCiclos(datos);
      expect(indicadores.completas.length, 10000);
      for (final p in ProcesoCiclo.values) {
        expect(
          indicadores.percentilProceso(p, .8),
          percentil(indicadores.terminadas(p).map((m) => m.duracion!), .8),
        );
      }
    },
  );
}
