import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';

import 'masiva_validacion_test.dart' show ValidacionFixture, openValidation;

class _FocusFixture extends ValidacionFixture {
  _FocusFixture() : super(validated: 1, secondArticle: true);

  int secondValidated = 0;

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    final result = await super.consultar(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
    if (operacion != null && ['kits', 'validacion_documento'].contains(vista)) {
      for (final row in filasMasiva(result['filas'])) {
        for (final article in filasMasiva(row['articulos'])) {
          if (article['sku'] == '000456') article['validado'] = secondValidated;
        }
      }
    }
    return result;
  }

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'validar' && datos['sku'] == '000456') {
      calls.add(accion);
      writes.add((action: accion, data: Map.of(datos)));
      secondValidated++;
      return {'validado': secondValidated};
    }
    return super.ejecutar(accion, datos);
  }
}

Finder get _sku => find.byKey(const ValueKey('masiva-sku'));

void _expectReaderReady(WidgetTester tester) {
  final field = tester.widget<TextField>(_sku);
  expect(field.enabled, isTrue);
  expect(
    field.focusNode!.hasPrimaryFocus,
    isTrue,
    reason: 'El lector debe escribir directamente sin volver a hacer clic.',
  );
  expect(
    tester.testTextInput.hasAnyClients,
    isTrue,
    reason: 'El foco debe conservar una conexión de entrada activa.',
  );
  expect(field.controller!.text, isEmpty);
}

// Deliberately never call tester.enterText/showKeyboard or tap the SKU field:
// those helpers refocus it and would conceal the post-dialog regression.
Future<void> _readerScan(WidgetTester tester, String sku) async {
  _expectReaderReady(tester);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: sku,
      selection: TextSelection.collapsed(offset: sku.length),
    ),
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (find.text('Prenda retirada · continuar').evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final size in [const Size(1440, 1000), const Size(390, 844)]) {
    for (final keyboardDismiss in [false, true]) {
      testWidgets('Lector continúa tras alertas repetidas ${size.width} '
          '${keyboardDismiss ? 'Enter' : 'clic'}', (tester) async {
        final repo = _FocusFixture();
        await openValidation(tester, repo, size: size);
        await _readerScan(tester, '000123');
        expect(repo.validated, 2);

        for (final code in ['000123', '000123', 'NO-PERTENECE']) {
          await _readerScan(tester, code);
          expect(
            find.text(
              code == '000123' ? 'Unidad excedente' : 'Código incorrecto',
            ),
            findsOneWidget,
          );
          final button = find.widgetWithText(
            FilledButton,
            'Prenda retirada · continuar',
          );
          if (keyboardDismiss) {
            // Reach the modal action through keyboard focus, not SKU focus.
            for (var tab = 0; tab < 8; tab++) {
              final context = tester.element(
                find.text('Prenda retirada · continuar'),
              );
              if (Focus.of(context).hasPrimaryFocus) break;
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
            }
            expect(
              Focus.of(
                tester.element(find.text('Prenda retirada · continuar')),
              ).hasPrimaryFocus,
              isTrue,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.ensureVisible(button);
            await tester.tap(button);
          }
          await tester.pumpAndSettle();
          expect(find.text('Prenda retirada · continuar'), findsNothing);
          _expectReaderReady(tester);
          expect(repo.writes, hasLength(1));
        }

        await _readerScan(tester, '000456');
        expect(repo.secondValidated, 1);
        expect(repo.writes, hasLength(2));
        expect(repo.writes.last.data['sku'], '000456');
        _expectReaderReady(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
