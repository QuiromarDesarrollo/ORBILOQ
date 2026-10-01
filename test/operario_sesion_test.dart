import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/recepcion_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/operario_actual.dart';

void main() {
  testWidgets('Producción y recepción usan el nombre de la cuenta sin selector',
      (tester) async {
    for (final nombre in ['Ana Producción', 'Carlos Logística']) {
      for (final dialog in [
        const EntregaProduccionDialog(),
        const RecepcionDialog()
      ]) {
        final repo = InMemoryWmsRepository.seeded();
        await tester.pumpWidget(ProviderScope(
            key: UniqueKey(),
            overrides: [
              usarSupabaseProvider.overrideWithValue(true),
              wmsRepositoryProvider.overrideWithValue(repo),
              usuarioSesionProvider.overrideWith((ref) async => UsuarioSesion(
                  numeroUsuario: '123',
                  nombre: nombre,
                  rolCuenta: RolCuenta.admin)),
            ],
            child: MaterialApp(home: Scaffold(body: dialog))));
        await tester.pumpAndSettle();
        final campo = find.byType(OperarioActual).first;
        expect(find.descendant(of: campo, matching: find.text(nombre)),
            findsOneWidget);
        expect(find.descendant(of: campo, matching: find.byType(TextField)),
            findsNothing);
        expect(
            find.descendant(
                of: campo, matching: find.byIcon(Icons.arrow_drop_down)),
            findsNothing);
        await tester.pumpWidget(const SizedBox());
        repo.dispose();
      }
    }
  });
}
