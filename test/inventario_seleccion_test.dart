import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/inventario/presentation/inventario_seleccion.dart';

void main() {
  for (final size in [
    const Size(1200, 850),
    const Size(320, 740),
    const Size(740, 360),
  ]) {
    testWidgets('Selección compacta y cantidades en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioSeleccion(
              filas: [
                {
                  'cliente': 'CLIENTE DE PRUEBA CON NOMBRE LARGO',
                  'ficha': 'FICHA V4',
                  'talla': '2XS/32/8',
                  'producto': 'OVEROL  DOS PIEZAS · OVEROL DOS PIEZAS',
                  'libre': 3,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OVEROL DOS PIEZAS'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Total a despachar: 2 unidades'),
        findsOneWidget,
      );
      await tester.tap(find.text('Máx.'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Total a despachar: 3 unidades'),
        findsOneWidget,
      );
      final plus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Aumentar cantidad',
        ),
      );
      expect(plus.onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('cantidad-seleccion-0')),
        '4',
      );
      await tester.tap(find.text('Continuar al despacho'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Revisa la cantidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
