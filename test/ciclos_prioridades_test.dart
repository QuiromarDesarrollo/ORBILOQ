import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/domain/ciclos_prioridades.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_prioridades_card.dart';

DateTime dia(int d) => DateTime.utc(2026, 9, d);
OrdenCiclo op(
  String id,
  int inicio, {
  int? fin,
  bool meta = true,
  String cliente = 'Cliente A',
}) => OrdenCiclo(
  id,
  cliente,
  20,
  dia(inicio),
  List<DateTime?>.filled(7, fin == null ? null : dia(fin)),
  meta ? {'compras': 'meta'} : {},
);
DatosCiclos datos() => DatosCiclos(
  [
    op('ATRASADA', 14),
    op('VENCE-HOY', 16),
    op('SIN-META', 14, meta: false),
    op('FUTURA', 21),
    op('OTRO-CLIENTE', 1, cliente: 'Cliente B'),
    op('TERMINADA-TARDE', 14, fin: 17),
    op('TERMINADA-BIEN', 14, fin: 16),
    op('ANTERIOR', 8, fin: 10),
    op('TERMINADA-SIN-META', 14, fin: 17, meta: false),
  ],
  [ParametroCiclo('meta', ProcesoCiclo.compras, dia(1), 2, null, null)],
  dia(18),
  '1',
);
IndicadoresCiclos indicadores() => IndicadoresCiclos(
  datos(),
  cliente: 'Cliente A',
  desde: dia(14),
  hasta: dia(18),
);

void main() {
  test(
    'Prioridades no duplican OP, excluyen futuras y separan metas ausentes',
    () {
      final r = PrioridadesCiclos(indicadores());
      final compras = r.procesos.first;
      expect(compras.abiertas.length, 3);
      expect(compras.atrasadas.map((m) => m.orden.op), ['ATRASADA']);
      expect(compras.sinMeta, 1);
      expect(compras.mayorAtraso, 2);
      expect(compras.prendas, 20);
      expect(r.sinInicio, 1);
      expect(r.procesos.skip(1).every((p) => p.abiertas.isEmpty), isTrue);
      expect(compras.evaluadas.length, 2);
      expect(compras.cumplimiento, 50);
      expect(compras.cambio, -50);
      expect(compras.excesoMedio, 1);
      expect(compras.terminadas.length, 3);
    },
  );
  test(
    'Filtro histórico no elimina atrasos abiertos y no inventa porcentajes sin datos',
    () {
      final r = PrioridadesCiclos(
        IndicadoresCiclos(
          datos(),
          cliente: 'Cliente A',
          desde: dia(1),
          hasta: dia(2),
        ),
      );
      expect(r.procesos.first.atrasadas.length, 1);
      expect(r.procesos.first.cumplimiento, isNull);
      expect(r.procesos.first.cambio, isNull);
      final vacio = PrioridadesCiclos(
        IndicadoresCiclos(DatosCiclos([], [], dia(18), '0')),
      );
      expect(vacio.desde, dia(18).subtract(const Duration(days: 27)));
      expect(vacio.procesos.every((p) => p.cumplimiento == null), isTrue);
    },
  );
  for (final ancho in [320.0, 390.0, 1366.0]) {
    testWidgets('Prioridades y detalle responsive $ancho', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CiclosPrioridadesCard(indicadores: indicadores()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 OP atrasadas de 3 en proceso'), findsOneWidget);
      expect(
        find.textContaining('Fecha de última carga no disponible'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('prioridad-compras')),
      );
      await tester.tap(find.byKey(const ValueKey('prioridad-compras')));
      await tester.pumpAndSettle();
      expect(find.text('OP ATRASADA · Cliente A'), findsOneWidget);
      expect(find.textContaining('2 días hábiles de atraso'), findsOneWidget);
      expect(find.text('OP VENCE-HOY · Cliente A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
