import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_page.dart';
import 'masiva_validacion_test.dart' show ValidacionFixture, tapVisible;
import 'masiva_ui_test.dart' show captureMasiva;

class _ValidationDraft extends BorradorLocalStore {
  @override
  Future<Map<String, dynamic>?> leer(String key) async => {
    'version': 1,
    'datos': {'operacion': 'demo', 'seccion': 3},
  };
  @override
  Future<void> guardar(String key, Map<String, dynamic> datos) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['ConductorSans', 'Roboto']) {
      await (FontLoader(family)
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('Al recuperar validación vacía enfoca documento $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final repo = ValidacionFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            masivaRepositoryProvider.overrideWithValue(repo),
            transporteBorradorUsuarioProvider.overrideWithValue('foco-test'),
            transporteBorradorStoreProvider.overrideWithValue(
              _ValidationDraft(),
            ),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: ValueKey('capture'),
              child: MasivaPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final person = find.byKey(const ValueKey('masiva-persona'));
      expect(find.text('Listo para escanear'), findsOneWidget);
      expect(
        tester.widget<TextField>(person).focusNode!.hasPrimaryFocus,
        isTrue,
      );
      await captureMasiva(tester, 'masiva-foco-documento-${width.toInt()}');
      // The scanner writes through the active input without tapping the field.
      tester.testTextInput.enterText('DEMO-01');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('KIT EN VALIDACIÓN'), findsOneWidget);
      expect(repo.writes, isEmpty);
      await tapVisible(tester, find.byTooltip('Cerrar kit'));
      expect(find.text('Listo para escanear'), findsOneWidget);
      expect(
        tester.widget<TextField>(person).focusNode!.hasPrimaryFocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(person).controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      // A periodic refresh must not steal focus from the container field.
      final container = find.byKey(
        const ValueKey('masiva-validation-container'),
      );
      await tester.ensureVisible(container);
      await tester.enterText(container, '3');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(person).focusNode!.hasPrimaryFocus,
        isFalse,
      );
      expect(tester.widget<TextField>(container).controller!.text, '3');
      expect(tester.takeException(), isNull);
    });
  }
}
