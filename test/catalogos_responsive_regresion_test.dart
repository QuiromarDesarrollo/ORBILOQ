import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';
import 'package:orbiloq_wms/features/admin/presentation/catalogos_dialog.dart';

class _Catalogos extends CatalogosRepository {
  int consultas = 0;
  @override
  Future<List<Map<String, dynamic>>> listar(String tipo) async {
    consultas++;
    return [
      {
        'id': '1',
        'nombre': 'Ana Prueba',
        'numero_usuario': '1234',
        'rol': 'logistica',
        'activo': true,
        'auth_id': 'local',
      },
      {
        'id': '2',
        'nombre': 'Luis Prueba',
        'numero_usuario': '1235',
        'rol': 'produccion',
        'activo': false,
      },
    ];
  }

  @override
  Future<void> guardar(
    String tipo,
    Map<String, dynamic>? anterior,
    String nombre,
    bool activo,
    String rol, {
    List<String>? roles,
  }) async => throw StateError('Esta verificación no guarda registros.');

  @override
  Future<bool> crearUsuario(
    String numero,
    String nombre,
    String rol,
    String contrasena, {
    List<String>? roles,
  }) async => throw StateError('Esta verificación no crea cuentas.');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['Roboto', 'sans-serif']) {
      await (FontLoader(family)..addFont(
        rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
      )).load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [320.0, 390.0, 640.0, 680.0, 768.0, 1440.0]) {
    testWidgets(
      'Catálogos: actualizar y abrir usuario sin comprimir a $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Catalogos();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              catalogosAdminProvider.overrideWithValue(repo),
              usarSupabaseProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              theme: AppTheme.kardex(TemaModo.corporativo),
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => showCatalogosDialog(context),
                        child: const Text('Abrir'),
                      ),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        final refresh =
            find
                .ancestor(
                  of: find.byIcon(Icons.refresh),
                  matching: find.byWidgetPredicate(
                    (w) => w is IconButton || w is OutlinedButton,
                  ),
                )
                .first;
        final refreshRect = tester.getRect(refresh);
        expect(
          refreshRect.height,
          lessThanOrEqualTo(60),
          reason:
              'Actualizar no debe apilar las letras en una columna estrecha.',
        );
        expect(refreshRect.width, greaterThanOrEqualTo(40));
        expect(tester.takeException(), isNull);
        final calls = repo.consultas;
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(repo.consultas, calls + 1);
        await tester.tap(find.text('Inactivos 1'));
        await tester.pumpAndSettle();
        expect(find.text('Luis Prueba'), findsOneWidget);
        expect(find.text('Ana Prueba'), findsNothing);
        await tester.tap(find.text('Activos 1'));
        await tester.pumpAndSettle();
        if (width == 390 || width == 640 || width == 768 || width == 1440) {
          await tester.runAsync(() async {
            final scene = tester.binding.renderViews.single.debugLayer!
                .buildScene(ui.SceneBuilder());
            final image = await scene.toImage(width.toInt(), 850);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '.dart_tool/catalogos-responsive-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            scene.dispose();
          });
        }
        await tester.tap(find.text('Agregar usuario'));
        await tester.pumpAndSettle();
        expect(find.text('Crear usuario'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('Ana Prueba'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
