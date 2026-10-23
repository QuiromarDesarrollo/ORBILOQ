import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';
import 'package:orbiloq_wms/features/admin/presentation/cambiar_contrasena_dialog.dart';
import 'package:orbiloq_wms/features/auth/presentation/login_page.dart';

class _Repo extends CatalogosRepository {
  int cambios = 0;
  String? destino;
  @override
  Future<void> cambiarContrasena(String usuarioId, String contrasena) async {
    cambios++;
    destino = usuarioId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Olvidé mi contraseña muestra contacto con administrador', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pump(const Duration(seconds: 1));
    final boton = find.text('¿Olvidaste tu contraseña?');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('aviso-global')), findsOneWidget);
    expect(
      find.text(
        'Comunícate con el administrador de ORBILOQ para que te asigne una nueva contraseña.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Contraseña requiere longitud, coincidencia y confirmación', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogosAdminProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showDialog(
                          context: context,
                          builder:
                              (_) => const CambiarContrasenaDialog(
                                usuarioId: 'usuario-catalogo',
                                nombre: 'Oscar',
                              ),
                        ),
                    child: const Text('Abrir'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    final clave = find.byKey(const ValueKey('nueva-contrasena'));
    final confirmacion = find.byKey(const ValueKey('confirmar-contrasena'));
    await tester.enterText(clave, 'corta');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('Usa entre 12 y 128 caracteres.'), findsOneWidget);
    expect(repo.cambios, 0);
    await tester.enterText(clave, 'Clave-de-prueba-123');
    await tester.enterText(confirmacion, 'otra');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(repo.cambios, 0);
    await tester.enterText(confirmacion, 'Clave-de-prueba-123');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(repo.cambios, 0);
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cambiar contraseña'));
    await tester.pumpAndSettle();
    expect(repo.cambios, 1);
    expect(repo.destino, 'usuario-catalogo');
    expect(find.text('Operación completada'), findsOneWidget);
    await tester.tap(find.text('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(find.byType(CambiarContrasenaDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
