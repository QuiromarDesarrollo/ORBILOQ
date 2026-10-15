import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/ciclos_providers.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_page.dart';

void main() {
  for (final roles in [
    {RolCuenta.admin},
    {RolCuenta.admin, RolCuenta.gerencia},
    {RolCuenta.gerencia},
    {RolCuenta.despacho, RolCuenta.gerencia},
  ]) {
    testWidgets('Acciones de ciclos según perfiles reales $roles', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(true),
            usuarioSesionProvider.overrideWith(
              (ref) async => UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Usuario de prueba',
                rolCuenta: roles.first,
                roles: roles,
              ),
            ),
            ciclosProvider.overrideWith(
              (ref) async => DatosCiclos([], [], DateTime(2026, 10, 14), '0'),
            ),
          ],
          child: const MaterialApp(home: CiclosPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin acceso a dashboards.'), findsNothing);
      final admin = roles.contains(RolCuenta.admin);
      expect(find.byTooltip('Excel'), admin ? findsOneWidget : findsNothing);
      expect(
        find.byTooltip('Parámetros'),
        admin ? findsOneWidget : findsNothing,
      );
      if (admin) {
        await tester.tap(find.byTooltip('Excel'));
        await tester.pumpAndSettle();
        expect(find.text('Importar históricos Excel'), findsOneWidget);
        expect(find.text('Descargar plantilla Excel'), findsOneWidget);
      }
    });
  }
}
