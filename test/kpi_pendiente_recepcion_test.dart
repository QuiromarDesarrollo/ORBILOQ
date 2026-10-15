import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/admin/presentation/kpi_pendiente_recepcion.dart';

void main() {
  for (final ancho in [110.0, 180.0, 300.0]) {
    testWidgets('Pendiente y avance mantienen lectura compacta $ancho', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: ancho,
              child: const KpiPendienteRecepcion(
                solicitadas: 1000,
                recibidas: 750,
              ),
            ),
          ),
        ),
      );
      expect(find.text('250'), findsOneWidget);
      expect(find.text('1.000'), findsOneWidget);
      expect(find.text('750'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(
        tester.getSize(find.byType(KpiPendienteRecepcion)).height,
        lessThan(ancho < 150 ? 140 : 100),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Sin base y exceso no ocultan el resultado', (tester) async {
    for (final entrada in [(0, 0, '—'), (100, 125, '125 %')]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: KpiPendienteRecepcion(
                solicitadas: entrada.$1,
                recibidas: entrada.$2,
              ),
            ),
          ),
        ),
      );
      expect(find.text(entrada.$3), findsOneWidget);
      if (entrada.$1 == 100) expect(find.text('-25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
