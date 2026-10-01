import 'package:orbiloq_wms/features/auth/presentation/login_page.dart';
import 'package:orbiloq_wms/features/kardex/presentation/edicion_admin_dialog.dart';
import 'package:orbiloq_wms/features/kardex/presentation/eliminar_linea_dialog.dart';
import 'package:orbiloq_wms/domain/edicion_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_page.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/recepcion_dialog.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';
import 'package:orbiloq_wms/features/no_conforme/presentation/no_conforme_dialog.dart';
import 'package:orbiloq_wms/features/reproceso/presentation/reproceso_dialog.dart';
import 'package:orbiloq_wms/features/sobrantes/presentation/sobrantes_dialog.dart';
import 'package:orbiloq_wms/features/ubicaciones/presentation/ubicaciones_dialog.dart';
import 'package:orbiloq_wms/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart';
import 'package:orbiloq_wms/features/importacion/presentation/importar_ordenes_dialog.dart';
import 'package:orbiloq_wms/features/importacion/presentation/importar_kardex_dialog.dart';
import 'package:orbiloq_wms/features/importacion_fechas/presentation/importar_fechas_dialog.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
    const Size(844, 390)
  ]) {
    testWidgets('Página en ${size.width}x${size.height}, ambas vistas',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        usarSupabaseProvider.overrideWithValue(false),
        wmsRepositoryProvider.overrideWithValue(repo)
      ], child: const MaterialApp(home: KardexPage())));
      await tester.pumpAndSettle();

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      expect(scaffold.isDrawerOpen, isFalse);
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isTrue);
      for (final accion in [
        'Administración',
        'Importar tabla',
        'Extraer tabla',
        'Importar fechas'
      ]) {
        expect(find.text(accion).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Cerrar menú'));
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);

      final container =
          ProviderScope.containerOf(tester.element(find.byType(KardexPage)));
      container.read(rolProvider.notifier).cambiar(Rol.logistica);
      await tester.pumpAndSettle();
    });
  }
  for (final size in [const Size(320, 640), const Size(1024, 600)]) {
    testWidgets('Login ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginPage())));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('Edición y borrado con teclado y texto ampliado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final item = (await repo.watch().first).kardex.first;
    for (final dialog in [
      EdicionAdminDialog(item: item, campo: CampoAdmin.cantidad),
      EliminarLineaDialog(item: item)
    ]) {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo)
          ],
          child: MaterialApp(
              home: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(390, 844),
                      viewInsets: EdgeInsets.only(bottom: 300),
                      textScaler: TextScaler.linear(1.3)),
                  child: Scaffold(body: dialog)))));
      await tester.pumpAndSettle();
    }
  });
  final dialogs = <Widget>[
    const EntregaProduccionDialog(),
    const RecepcionDialog(),
    const DespachoDialog(),
    const NoConformeDialog(),
    const ReprocesoDialog(),
    const SobrantesDialog(),
    const UbicacionesDialog(),
    const AliadosNoConformeDialog(),
    const ImportarOrdenesDialog(),
    const ImportarFechasDialog(),
    const ImportarKardexDialog(vista: Rol.produccion),
  ];
  for (final dialog in dialogs) {
    testWidgets('${dialog.runtimeType} en celular, pestañas', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        usarSupabaseProvider.overrideWithValue(false),
        wmsRepositoryProvider.overrideWithValue(repo)
      ], child: MaterialApp(home: Scaffold(body: dialog))));
      await tester.pumpAndSettle();
      final tabs = find.byType(Tab);
      for (var i = 0; i < tabs.evaluate().length; i++) {
        final tabContext = tester.element(tabs.at(i));
        DefaultTabController.of(tabContext).animateTo(i);
        await tester.pumpAndSettle();
      }
    });
  }
}
