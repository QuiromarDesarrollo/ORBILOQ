import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_maestro_tabla.dart';

void main() {
  for (final size in [const Size(1366, 650), const Size(768, 600)]) {
    testWidgets('barra accesible y arrastrable con 50 filas en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  MasivaMaestroTabla(
                    base: true,
                    filas: List.generate(
                      50,
                      (i) => {
                        'id': '$i',
                        'nombre': 'Persona $i',
                        'lista': '$i',
                      },
                    ),
                    filtros: const {},
                    opciones: const {},
                    onFiltrosChanged: (_) {},
                    onAbrir: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(const ValueKey('maestro-horizontal-scrollbar'));
      final rect = tester.getRect(bar);
      expect(rect.bottom, lessThan(size.height));
      final vertical = find.descendant(
        of: bar,
        matching: find.byType(ListView),
      );
      await tester.dragFrom(
        Offset(size.width / 2, rect.bottom - 60),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(vertical);
      expect(list.controller!.offset, greaterThan(0));
      final controller = tester.widget<Scrollbar>(bar).controller!;
      await tester.dragFrom(
        Offset(rect.left + 20, rect.bottom - 7),
        Offset(rect.width - 45, 0),
      );
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        greaterThan(controller.position.maxScrollExtent * .8),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
