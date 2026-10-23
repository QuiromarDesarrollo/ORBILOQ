import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_design.dart';
import 'package:orbiloq_wms/features/conductor/presentation/perfil_transporte.dart';
import 'package:orbiloq_wms/features/conductor/presentation/flota_admin_page.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';

void main() {
  for (final admin in [false, true]) {
    for (final width in [320.0, 1000.0]) {
      testWidgets('Perfil ${admin ? 'admin' : 'conductor'} a $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fonts =
            FontLoader('ConductorSans')
              ..addFont(
                rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
              )
              ..addFont(
                rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'),
              );
        await fonts.load();
        await (FontLoader('Ahem')..addFont(
          rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
        )).load();
        await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usarSupabaseProvider.overrideWithValue(true),
              usuarioSesionProvider.overrideWith(
                (ref) async => UsuarioSesion(
                  numeroUsuario: '123',
                  nombre: admin ? 'Ana Administradora' : 'Oscar Silva',
                  rolCuenta: admin ? RolCuenta.admin : RolCuenta.conductor,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ConductorDesign.theme(),
              home: Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: PerfilTransporte(
                      administrador: admin,
                      vehiculo:
                          admin
                              ? null
                              : const VehiculoConductor(
                                id: 'demo',
                                placa: 'JOU797',
                                descripcion: 'Peugeot',
                                km: 1000,
                                datos: {'conductor_documento': '10203040'},
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mi perfil'), findsOneWidget);
        expect(find.text('Datos personales'), findsOneWidget);
        expect(find.text('Licencia de conducción'), findsOneWidget);
        expect(find.text('Cerrar sesión'), findsOneWidget);
        expect(find.text('JOU797'), admin ? findsNothing : findsOneWidget);
        expect(find.text('10203040'), admin ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 1000 && !admin) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '.dart_tool/perfil-transporte.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Administrador abre su propio perfil desde la barra', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FlotaAdminPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menú de usuario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(PerfilTransporte), findsOneWidget);
    expect(
      tester.widget<PerfilTransporte>(find.byType(PerfilTransporte)).vehiculo,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Aviso global y confirmación conservan cancelación segura', (
    tester,
  ) async {
    bool? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    const AvisoFormulario('No se guardó el mantenimiento.'),
                    TextButton(
                      onPressed: () async {
                        decision = await confirmarAviso(
                          context,
                          'Hay respuestas sin guardar.',
                          titulo: 'Descartar revisión',
                          confirmar: 'Descartar',
                          cancelar: 'Continuar revisión',
                        );
                      },
                      child: const Text('Probar confirmación'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aviso-global')), findsOneWidget);
    expect(find.text('No se pudo completar'), findsOneWidget);
    await tester.tap(find.text('Cerrar aviso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Probar confirmación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar revisión'));
    await tester.pumpAndSettle();
    expect(decision, false);
    await tester.tap(find.text('Probar confirmación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(decision, true);
  });
}
