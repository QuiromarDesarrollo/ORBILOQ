import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(768, 900)]) {
    for (final expand in [true, false]) {
      testWidgets('Teclado dentro de ruta $size expand=$expand', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showWmsDialog<void>(context, (_) {
                          final field = TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              labelText: 'Remision',
                            ),
                          );
                          return WmsDialogShell(
                            title: 'Recepcion',
                            icon: Icons.edit,
                            iconColor: Colors.blue,
                            expand: expand,
                            child:
                                expand
                                    ? Column(
                                      children: [
                                        const Text('Recibir prendas'),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 100),
                                                field,
                                                const SizedBox(height: 200),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    : field,
                          );
                        }),
                    child: const Text('Abrir'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Remision pendiente');
        controller.selection = const TextSelection.collapsed(offset: 5);
        await tester.pump();
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        for (final bottom in [180.0, 350.0, 0.0, 350.0]) {
          tester.testTextInput.log.clear();
          tester.view.viewInsets = FakeViewPadding(bottom: bottom);
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(EditableText)), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(controller.text, 'Remision pendiente');
          expect(controller.selection.baseOffset, 5);
          expect(
            tester.testTextInput.log.map((e) => e.method),
            isNot(
              anyOf(
                contains('TextInput.hide'),
                contains('TextInput.clearClient'),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
        tester.testTextInput.enterText('Continua escribiendo');
        await tester.pump();
        expect(controller.text, 'Continua escribiendo');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
