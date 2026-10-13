import 'package:flutter/material.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/dashboard_acceso.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/admin/presentation/catalogos_dialog.dart';

class _Repo extends CatalogosRepository {
  List<String>? guardados;
  @override
  Future<List<Map<String, dynamic>>> listar(String tipo) async => [
    {
      'id': '1',
      'nombre': 'Alejandro',
      'numero_usuario': '123456',
      'rol': 'despacho',
      'roles': ['despacho'],
      'activo': true,
      'auth_id': 'test',
      'version': 'v1',
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
  }) async {
    guardados = roles;
  }

  @override
  Future<bool> crearUsuario(
    String numero,
    String nombre,
    String rol,
    String contrasena, {
    List<String>? roles,
  }) async {
    guardados = roles;
    return false;
  }
}

void main() {
  test('Compatibilidad del perfil único y unión de accesos', () {
    expect(RolCuenta.deFila({'rol': 'despacho'}), [RolCuenta.despacho]);
    const s = UsuarioSesion(
      numeroUsuario: '1',
      nombre: 'Multi',
      rolCuenta: RolCuenta.seguimiento,
      roles: {RolCuenta.seguimiento, RolCuenta.despacho, RolCuenta.logistica},
    );
    expect(s.areas, [Rol.logistica, Rol.despacho]);
    expect(s.puedeSeguimiento, true);
    expect(s.tieneRol(RolCuenta.admin), false);
    expect(s.puedeVerDashboards, false);
  });
  test(
    'Cambiar área solo entre permisos asignados y revocar en sesión',
    () async {
      var roles = {
        RolCuenta.produccion,
        RolCuenta.logistica,
        RolCuenta.gerencia,
      };
      final c = ProviderContainer(
        overrides: [
          usarSupabaseProvider.overrideWithValue(true),
          usuarioSesionProvider.overrideWith(
            (ref) async => UsuarioSesion(
              numeroUsuario: '1',
              nombre: 'Multi',
              rolCuenta: RolCuenta.produccion,
              roles: roles,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(usuarioSesionProvider.future);
      expect(c.read(rolProvider), Rol.produccion);
      c.read(rolProvider.notifier).cambiar(Rol.logistica);
      expect(c.read(rolProvider), Rol.logistica);
      c.read(rolProvider.notifier).cambiar(Rol.despacho);
      expect(c.read(rolProvider), Rol.logistica);
      expect(c.read(dashboardAccesoProvider).$2?.puedeVerDashboards, true);
      roles = {RolCuenta.produccion};
      c.invalidate(usuarioSesionProvider);
      await c.read(usuarioSesionProvider.future);
      expect(c.read(rolProvider), Rol.produccion);
      expect(c.read(dashboardAccesoProvider).$2?.puedeVerDashboards, false);
    },
  );
  for (final width in [320.0, 1100.0]) {
    testWidgets('Editar Despacho + Seguimiento y exigir un perfil a $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      final wms = InMemoryWmsRepository.seeded();
      addTearDown(wms.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            catalogosAdminProvider.overrideWithValue(repo),
            wmsRepositoryProvider.overrideWithValue(wms),
          ],
          child: const MaterialApp(home: Scaffold(body: CatalogosDialog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar Alejandro'));
      await tester.pumpAndSettle();
      Finder chip(String text) => find.widgetWithText(FilterChip, text);
      await tester.ensureVisible(chip('Despacho'));
      await tester.tap(chip('Despacho'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona al menos un perfil.'), findsOneWidget);
      expect(repo.guardados, isNull);
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(chip('Despacho'));
      await tester.tap(chip('Despacho'));
      await tester.ensureVisible(chip('Seguimiento'));
      await tester.tap(chip('Seguimiento'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seguimiento, Despacho'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repo.guardados, ['seguimiento', 'despacho']);
      expect(tester.takeException(), isNull);
    });
  }
}
