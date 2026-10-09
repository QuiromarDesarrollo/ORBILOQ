import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';

void main() {
  testWidgets(
    'Aviso centrado se puede repetir y cerrar sin cerrar formulario',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Formulario'),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => mostrarAviso(
                                          ctx,
                                          'Revisa las cantidades.',
                                          error: true,
                                        ),
                                    child: const Text('Validar'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Abrir'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Validar'));
        await tester.pumpAndSettle();
        expect(find.text('Revisa las cantidades.'), findsOneWidget);
        final centro = tester.getCenter(
          find.byKey(const ValueKey('aviso-global')),
        );
        expect(centro.dx, closeTo(400, 1));
        expect(centro.dy, closeTo(300, 1));
        await tester.tap(find.text('Cerrar aviso'));
        await tester.pumpAndSettle();
        expect(find.text('Formulario'), findsOneWidget);
        expect(find.text('Revisa las cantidades.'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Avisos de todos los tipos admiten texto largo y acción en móvil', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final tipo in TipoAviso.values) {
      var acciones = 0;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () => mostrarAvisoContenido(
          context, Text(List.filled(20, 'Detalle del resultado.').join(' ')), tipo: tipo,
          accion: SnackBarAction(label: 'Reintentar', onPressed: () => acciones++),
        ), child: const Text('Abrir aviso')),
      ))));
      await tester.tap(find.text('Abrir aviso'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(acciones, 1);
      expect(find.byKey(const ValueKey('aviso-global')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
