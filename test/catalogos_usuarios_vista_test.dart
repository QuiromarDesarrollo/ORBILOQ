import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';
import 'package:orbiloq_wms/features/admin/presentation/catalogos_dialog.dart';

class _Repo implements CatalogosRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(String tipo) async => [
    {
      'id': '1',
      'nombre': 'Ronald',
      'numero_usuario': '1234',
      'rol': 'logistica',
      'activo': true,
      'auth_id': 'a',
    },
    {
      'id': '2',
      'nombre': 'Ana',
      'numero_usuario': '1235',
      'rol': 'produccion',
      'activo': false,
      'auth_id': 'b',
    },
  ];
  @override
  Future<void> guardar(
    String tipo,
    Map<String, dynamic>? anterior,
    String nombre,
    bool activo,
    String rol, {
    List<String>? roles,
  }) async {}
  @override
  Future<bool> crearUsuario(
    String numero,
    String nombre,
    String rol,
    String contrasena, {
    List<String>? roles,
  }) async => false;
}

void main() {
  for (final size in [
    const Size(1100, 850),
    const Size(390, 800),
    const Size(320, 640),
  ]) {
    testWidgets('Usuarios: filtros, edición y desactivación $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogosAdminProvider.overrideWithValue(_Repo()),
            usarSupabaseProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
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
      expect(find.text('Ronald'), findsOneWidget);
      if (size.width < 600) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      expect(find.text('Ana'), findsNothing);
      await tester.tap(find.text('Inactivos 1'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(find.text('Activos 1'));
      await tester.pumpAndSettle();
      // Las acciones permanecen accesibles en tarjetas y en la tabla.
      await tester.ensureVisible(find.byTooltip('Editar Ronald'));
      await tester.tap(find.byTooltip('Editar Ronald'));
      await tester.pumpAndSettle();
      expect(find.text('Editar usuario'), findsOneWidget);
      expect(
        find.text('Identificador de acceso. No editable.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Desactivar Ronald'));
      await tester.tap(find.byTooltip('Desactivar Ronald'));
      await tester.pumpAndSettle();
      expect(find.text('¿Desactivar a Ronald?'), findsOneWidget);
      expect(
        find.textContaining('Sus registros e historial se conservan'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
