import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_page.dart';

void main() {
  for (final cuenta in RolCuenta.values) {
    testWidgets('Permisos y columnas de ${cuenta.etiqueta}', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(true),
            wmsRepositoryProvider.overrideWithValue(repo),
            usuarioSesionProvider.overrideWith(
              (ref) async => UsuarioSesion(
                numeroUsuario: '123',
                nombre: 'Cuenta prueba',
                rolCuenta: cuenta,
              ),
            ),
          ],
          child: const MaterialApp(home: KardexPage()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(KardexPage)),
      );
      if (cuenta == RolCuenta.gerencia) {
        expect(find.text('Dashboards'), findsOneWidget);
        expect(find.text('Control de operaciones'), findsNothing);
        return;
      }
      final original = container.read(rolProvider);
      expect(original, switch (cuenta) {
        RolCuenta.produccion ||
        RolCuenta.admin ||
        RolCuenta.gerencia => Rol.produccion,
        RolCuenta.logistica => Rol.logistica,
        RolCuenta.despacho || RolCuenta.seguimiento => Rol.despacho,
      });
      for (final vista in Rol.values) {
        container.read(rolProvider.notifier).cambiar(vista);
        await tester.pumpAndSettle();
        final efectiva = cuenta == RolCuenta.admin ? vista : original;
        expect(container.read(rolProvider), efectiva);
        final columnas = container.read(extractoresColumnaProvider);
        if (efectiva == Rol.logistica) {
          expect(find.text('FECHA DE RECIBIDO'), findsOneWidget);
          expect(find.text('Despacho por orden'), findsNothing);
          expect(find.text('Estantes y tickets'), findsNothing);
          expect(find.text('Bandeja de Sobrantes'), findsOneWidget);
          expect(find.text('PENDIENTE POR DESPACHAR'), findsNothing);
          expect(columnas.containsKey(ColKardex.despachadas), isFalse);
          expect(columnas.containsKey(ColKardex.fechaRecibido), isTrue);
          expect(columnas.containsKey(ColKardex.diasFaltantesBodega), isFalse);
        } else if (efectiva == Rol.despacho) {
          expect(find.text('Despacho por orden'), findsOneWidget);
          expect(find.text('Estantes y tickets'), findsOneWidget);
          expect(find.text('Bandeja de Sobrantes'), findsNothing);
          expect(find.text('Producto no conforme'), findsNothing);
          expect(find.text('ENTREGADO POR PRODUCCIÓN'), findsNothing);
          expect(find.text('PENDIENTE POR PRODUCCIÓN'), findsNothing);
          expect(find.text('PRODUCTO NO CONFORME'), findsNothing);
          expect(find.text('PENDIENTE POR DESPACHAR'), findsOneWidget);
          expect(columnas.containsKey(ColKardex.despachadas), isTrue);
          expect(columnas.containsKey(ColKardex.fechaRecibido), isFalse);
          expect(columnas.containsKey(ColKardex.produccion), isFalse);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}
