import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/flota_admin_page.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Flota administrativa y expediente a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gestión de flota'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final asignar = find.text('Registrar vehículo / asignar conductor');
      await tester.ensureVisible(asignar);
      await tester.pumpAndSettle();
      await tester.tap(asignar);
      await tester.pumpAndSettle();
      expect(find.text('Número de usuario conductor'), findsNothing);
      final selector = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Segundo conductor').last);
      await tester.pumpAndSettle();
      expect(find.text('Segundo conductor'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver vehículo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver vehículo').first);
      await tester.pumpAndSettle();
      expect(find.text('Volver a la flota'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Volver a la flota')).dy,
        lessThan(300),
      );
      expect(find.text('Iniciar checklist de salida'), findsNothing);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Kit de carretera · revisión semanal'), findsOneWidget);
      final kit = find.text('Revisar kit de carretera');
      await tester.ensureVisible(kit);
      await tester.tap(kit);
      await tester.pumpAndSettle();
      expect(find.text('Kit de carretera · semanal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
