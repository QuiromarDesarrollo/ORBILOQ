import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/features/no_conforme/presentation/no_conforme_dialog.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_scan_field.dart';

import 'entrega_produccion_vista_test.dart' show AvanceMemoria;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Roboto')..addFont(
      rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
    )).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final entry
      in <String, Widget>{
        'Producción': const EntregaProduccionDialog(),
        'No conformes': const NoConformeDialog(),
      }.entries) {
    testWidgets(
      '${entry.key}: girar el dispositivo conserva modo manual, código y foco del lector',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = InMemoryWmsRepository.seeded();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usarSupabaseProvider.overrideWithValue(false),
              wmsRepositoryProvider.overrideWithValue(repo),
              transporteBorradorUsuarioProvider.overrideWithValue(
                'dev:responsive',
              ),
              transporteBorradorStoreProvider.overrideWithValue(
                AvanceMemoria(),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.kardex(TemaModo.corporativo),
              home: Scaffold(body: entry.value),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final manual = find.descendant(
          of: find.byType(WmsScanField),
          matching: find.text('Ingresar código manualmente'),
        );
        await tester.ensureVisible(manual);
        await tester.tap(manual);
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byType(WmsScanField),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, '90001-CAMISA-M');
        final original = tester.state(find.byType(WmsScanField));
        final editable = tester.state(
          find.descendant(
            of: find.byType(WmsScanField),
            matching: find.byType(EditableText),
          ),
        );
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 6,
          extentOffset: 12,
        );
        await tester.pump();
        for (final size in [
          const Size(844, 844),
          const Size(844, 390),
          const Size(390, 844),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(
            tester.widget<WmsScanField>(find.byType(WmsScanField)).key,
            same(original.widget.key),
            reason:
                'El State padre debe conservar la clave del lector en $size',
          );
          expect(
            tester.state(find.byType(WmsScanField)),
            same(original),
            reason: 'El cambio Column/Row no debe reiniciar el modo de entrada',
          );
          expect(
            find.descendant(
              of: find.byType(WmsScanField),
              matching: find.text('Usar lector'),
            ),
            findsOneWidget,
          );
          expect(
            tester.state(
              find.descendant(
                of: find.byType(WmsScanField),
                matching: find.byType(EditableText),
              ),
            ),
            same(editable),
          );
          final input = tester.widget<TextField>(field);
          expect(input.controller!.text, '90001-CAMISA-M');
          expect(
            input.controller!.selection,
            const TextSelection(baseOffset: 6, extentOffset: 12),
          );
          expect(input.keyboardType, TextInputType.text);
          expect(input.focusNode!.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          expect(field.hitTestable(), findsOneWidget);
          if (size.height != 844 || size.width == 390) {
            await tester.runAsync(() async {
              final scene = tester.binding.renderViews.single.debugLayer!
                  .buildScene(ui.SceneBuilder());
              try {
                final image = await scene.toImage(
                  size.width.toInt(),
                  size.height.toInt(),
                );
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final module =
                    entry.key == 'Producción' ? 'produccion' : 'no-conformes';
                await File(
                  '.dart_tool/lector-rotacion-$module-${size.width.toInt()}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              } finally {
                scene.dispose();
              }
            });
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
