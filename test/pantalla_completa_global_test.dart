import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_expandable_alert_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_expandable_sheet.dart';

void main() {
  for (final size in [
    const Size(1440, 900),
    const Size(320, 740),
    const Size(740, 360),
  ]) {
    for (final tipo in ['panel', 'formulario', 'hoja']) {
      testWidgets('$tipo amplía y conserva texto en $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const campo = TextField(decoration: InputDecoration(labelText: 'Dato'));
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Abrir'),
                      onPressed: () {
                        if (tipo == 'hoja') {
                          showWmsExpandableSheet<void>(
                            context: context,
                            builder:
                                (_) => const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: campo,
                                ),
                          );
                        } else {
                          showDialog<void>(
                            context: context,
                            builder:
                                (_) =>
                                    tipo == 'panel'
                                        ? WmsDialogShell(
                                          title: 'Formulario de prueba',
                                          icon: Icons.edit,
                                          iconColor: Colors.blue,
                                          footer: TextButton(
                                            onPressed: () {},
                                            child: const Text('Guardar'),
                                          ),
                                          child: campo,
                                        )
                                        : WmsExpandableAlertDialog(
                                          title: const Text(
                                            'Formulario de prueba',
                                          ),
                                          content: campo,
                                          actions: [
                                            TextButton(
                                              onPressed: () {},
                                              child: const Text('Guardar'),
                                            ),
                                          ],
                                        ),
                          );
                        }
                      },
                    ),
                  ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Sin perder datos');
        await tester.tap(find.byTooltip('Ampliar pantalla'));
        await tester.pumpAndSettle();
        expect(find.text('Sin perder datos'), findsOneWidget);
        if (tipo == 'panel') {
          expect(
            tester.getSize(find.byKey(const ValueKey('wms-dialog-surface'))),
            size,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Restaurar tamaño'));
        await tester.pumpAndSettle();
        expect(find.text('Sin perder datos'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size.width == 320) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Ampliar pantalla'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField));
          expect(find.text('Sin perder datos'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
