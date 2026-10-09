import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_carga_global.dart';
import 'ciclos_test.dart' show orden, d;

void main() {
  testWidgets('Dona suma unidades, separa OP y aplica cliente', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dia = d('2026-10-09');
    final datos = DatosCiclos(
      [
        orden(op: 'COMPRAS', cantidad: 999),
        orden(
          op: 'TRAZO',
          cantidad: 999,
          fines: ['2026-09-02', null, null, null, null, null, null],
        ),
        orden(
          op: 'CORTE',
          cantidad: 200,
          fines: ['2026-09-02', '2026-09-03', null, null, null, null, null],
        ),
      ],
      [],
      dia,
      '0',
    );
    Future<void> mostrar(String? cliente) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CiclosCargaGlobal(
              indicadores: IndicadoresCiclos(datos, cliente: cliente),
              desde: dia,
              hasta: dia,
              fin: dia,
              semanal: false,
            ),
          ),
        ),
      ),
    );
    await mostrar(null);
    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
    expect(find.textContaining('Compras: 1 OP · Trazo: 1 OP'), findsOneWidget);
    expect(find.text('200 · 100.0 %'), findsOneWidget);
    expect(find.text('Capacidad no comparable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mostrar('Sin coincidencias');
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Sin carga en unidades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
