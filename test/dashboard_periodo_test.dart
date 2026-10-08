import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_periodo.dart';
import 'package:orbiloq_wms/application/dashboard_tendencias.dart';
import 'package:orbiloq_wms/application/dashboard_recepcion.dart';
import 'package:orbiloq_wms/application/dashboard_enfoque.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_ejecutivo_page.dart';

void main() {
  final corte = DateTime.utc(2026, 10, 7);
  final rango = PeriodoDashboard(DateTime(2026, 10, 2), DateTime(2026, 10, 5));
  final filas = [
    {
      'fecha': '2026-10-03T04:59:59Z',
      'tipo': 'despacho',
      'cantidad': 2,
      'cliente': 'A',
      'causal': 'Tela',
    },
    {
      'fecha': '2026-10-03T05:00:00Z',
      'tipo': 'despacho',
      'cantidad': 40,
      'cliente': 'A',
      'causal': 'Tela',
    },
    {
      'fecha': '2026-10-05T12:00:00Z',
      'tipo': 'despacho',
      'cantidad': 3,
      'cliente': 'A',
      'causal': 'Tela',
    },
    {
      'fecha': '2026-10-06T12:00:00Z',
      'tipo': 'despacho',
      'cantidad': 10,
      'cliente': 'A',
      'causal': 'Tela',
    },
  ];
  test(
    'Calendario inclusivo, viernes y lunes separados, Bogotá y sin fines de semana',
    () {
      final t = calcularTendencias(filas, corte: corte, periodo: rango);
      expect(t.semanas.map((d) => d.inicio.weekday), [5, 1]);
      expect(t.semanas.map((d) => d.unidades[2]), [2, 3]);
      expect(
        volumenClientes(filas, corte: corte, semanas: 12, periodo: rango),
        {'A': 5},
      );
      final nc = compararCausales(filas, corte, periodo: rango).single;
      expect(nc.recientes, 5);
      expect(nc.historico, 55);
    },
  );
  test('Rango sin días laborables no produce errores ni totales', () {
    final finde = PeriodoDashboard(
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 4),
    );
    expect(
      calcularTendencias(filas, corte: corte, periodo: finde).semanas,
      isEmpty,
    );
    final r = calcularRecepcion(
      [],
      filas,
      corte: corte,
      semanas: 12,
      periodo: finde,
    );
    expect(r.semanas, isEmpty);
    expect(r.tasaSobrantes, isNull);
    expect(
      volumenClientes(filas, corte: corte, semanas: 12, periodo: finde),
      isEmpty,
    );
  });
  testWidgets('Gráfica admite un solo día y un período vacío', (tester) async {
    for (final dias in [
      [SemanaVolumen(DateTime.utc(2026, 10, 5))],
      <SemanaVolumen>[],
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GraficaVolumenSemanal(semanas: dias))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
