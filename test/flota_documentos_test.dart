import 'package:orbiloq_wms/features/conductor/presentation/historial_conductor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/flota_admin_page.dart';

void main() {
  testWidgets('Vehículos tiene catálogo propio con búsqueda y acceso a ficha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Autorizaciones'), findsNothing);
    expect(find.text('Revisar salidas'), findsNothing);
    await tester.tap(find.text('Vehículos').first);
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Sin foto registrada'), findsWidgets);
    expect(find.text('Ver ficha del vehículo'), findsWidgets);
    final buscar = find.byKey(const ValueKey('buscar-catalogo-vehiculos'));
    await tester.enterText(buscar, 'NO-EXISTE');
    await tester.pumpAndSettle();
    expect(find.text('Sin vehículos para mostrar'), findsOneWidget);
    await tester.enterText(buscar, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver ficha del vehículo').first);
    await tester.pumpAndSettle();
    expect(find.text('Volver a la flota'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Notificaciones es una lista con lectura y acceso directo a documentos',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notificaciones').first);
      await tester.pumpAndSettle();
      expect(find.text('Registrar vehículo / asignar conductor'), findsNothing);
      expect(find.text('Ver vehículo'), findsNothing);
      expect(find.text('Gestionar documentación'), findsWidgets);
      final aviso =
          find
              .byWidgetPredicate(
                (w) =>
                    w is InkWell &&
                    w.key is ValueKey<String> &&
                    (w.key as ValueKey<String>).value.startsWith(
                      'aviso-admin-documento:',
                    ),
              )
              .first;
      await tester.tap(aviso);
      await tester.pumpAndSettle();
      expect(
        find.text('Documentos del vehículo y conductor asignado'),
        findsOneWidget,
      );
      await tester.tap(find.text('Volver a notificaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar todas como leídas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin leer'));
      await tester.pumpAndSettle();
      expect(find.text('Sin notificaciones'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Historial solo muestra vehículos y abre sus reportes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial y reportes').first);
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Registrar vehículo / asignar conductor'), findsNothing);
    final card =
        find
            .byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(
                    'historial-vehiculo-',
                  ),
            )
            .first;
    final id = (tester.widget<InkWell>(card).key as ValueKey<String>).value
        .substring('historial-vehiculo-'.length);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(HistorialConductorView), findsOneWidget);
    expect(
      tester
          .widget<HistorialConductorView>(find.byType(HistorialConductorView))
          .vehiculo
          .id,
      id,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Volver a historial y reportes'));
    await tester.pumpAndSettle();
    expect(find.text('Ver historial y reportes'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mantenimiento solo muestra vehículos y abre sus servicios', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mantenimiento').first);
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Registrar vehículo / asignar conductor'), findsNothing);
    final card =
        find
            .byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(
                    'mantenimiento-vehiculo-',
                  ),
            )
            .first;
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Registrar Mantenimiento preventivo'), findsOneWidget);
    expect(find.text('Registrar Mantenimiento correctivo'), findsOneWidget);
    expect(
      find.text('Documentos del vehículo y conductor asignado'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Volver a mantenimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Gestionar mantenimiento'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Documentos solo muestra vehículos y abre su documentación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documentos').first);
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Registrar vehículo / asignar conductor'), findsNothing);
    expect(find.text('Gestionar documentos'), findsWidgets);
    final card =
        find
            .byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(
                    'documentos-vehiculo-',
                  ),
            )
            .first;
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.text('Documentos del vehículo y conductor asignado'),
      findsOneWidget,
    );
    expect(find.text('Actualizar documentos y vencimientos'), findsOneWidget);
    expect(find.text('Volver a documentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Volver a documentos'));
    await tester.pumpAndSettle();
    expect(find.text('Gestionar documentos'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
