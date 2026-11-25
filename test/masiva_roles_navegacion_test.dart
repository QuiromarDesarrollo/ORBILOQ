import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_page.dart';

import 'masiva_ui_test.dart' show MasivaFixture, captureMasivaOverlay;

const restricted = [
  'Resumen',
  'Indicadores',
  'Conciliación',
  'Listado maestro',
  'Base de datos maestra',
  'Listas y documentos',
  'Auditoría',
  'Configuración',
];

Future<void> mountRole(
  WidgetTester tester,
  double width,
  MasivaFixture repo, {
  required bool admin,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usarSupabaseProvider.overrideWithValue(true),
        transporteBorradorUsuarioProvider.overrideWithValue(null),
        usuarioSesionProvider.overrideWith(
          (ref) async => UsuarioSesion(
            numeroUsuario: 'test',
            nombre: admin ? 'Administrador de prueba' : 'Operario de prueba',
            rolCuenta: admin ? RolCuenta.admin : RolCuenta.masiva,
          ),
        ),
        masivaRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.kardex(TemaModo.corporativo),
        home: const MasivaPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, double width) async {
  if (width < 1080) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font =
        FontLoader('ConductorSans')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Operario solo navega a pantallas permitidas a $width px', (
      tester,
    ) async {
      final repo = MasivaFixture();
      await mountRole(tester, width, repo, admin: false);
      final dynamic state = tester.state(find.byType(MasivaPage));
      expect(state.capturarBorrador()['seccion'], 1);
      for (final label in restricted) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('Listas y rótulos'), findsNothing);
      await openMenu(tester, width);
      for (final label in restricted) {
        expect(find.text(label), findsNothing);
      }
      for (final label in ['Recepción', 'Validación']) {
        expect(find.text(label), findsOneWidget);
      }
      await captureMasivaOverlay(
        tester,
        'masiva-dos-vistas-operario-${width.toInt()}',
      );
      for (final label in ['Recepción', 'Validación', 'Recepción']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await openMenu(tester, width);
      }
      expect(repo.maestroConsultas, isEmpty);
      expect(
        repo.consultas.any(
          (q) =>
              [
                'listado',
                'base',
                'documentos',
                'auditoria',
                'configuracion',
                'conciliacion',
                'indicadores',
              ].contains(q['vista']) ||
              (q['vista'] == 'resumen' && q['operacion'] != null),
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Administrador conserva las ocho pantallas a $width px', (
      tester,
    ) async {
      await mountRole(tester, width, MasivaFixture(), admin: true);
      await openMenu(tester, width);
      for (final label in restricted) {
        expect(find.text(label), findsWidgets);
      }
      await captureMasivaOverlay(
        tester,
        'masiva-dos-vistas-admin-${width.toInt()}',
      );
      for (final target in [('Resumen', 0), ('Indicadores', 5)]) {
        await tester.tap(find.text(target.$1).first);
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(MasivaPage));
        expect(state.capturarBorrador()['seccion'], target.$2);
        expect(tester.takeException(), isNull);
        await openMenu(tester, width);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Borradores de pantallas restringidas no consultan sus datos', (
    tester,
  ) async {
    final repo = MasivaFixture();
    await mountRole(tester, 1440, repo, admin: false);
    final dynamic state = tester.state(find.byType(MasivaPage));
    for (final section in [0, 2, 4, 5, 6, 7, 8, 9]) {
      state.recuperarBorrador(<String, dynamic>{
        'seccion': section,
        'operacion': 'demo',
      });
      await state.alRecuperarBorrador();
      await tester.pumpAndSettle();
      expect(state.capturarBorrador()['seccion'], 1);
      expect(tester.takeException(), isNull);
    }
    expect(repo.maestroConsultas, isEmpty);
    expect(
      repo.consultas.any(
        (q) =>
            [
              'listado',
              'base',
              'documentos',
              'auditoria',
              'configuracion',
              'conciliacion',
              'indicadores',
            ].contains(q['vista']) ||
            (q['vista'] == 'resumen' && q['operacion'] != null),
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
