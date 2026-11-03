import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';

import 'masiva_ui_test.dart' show captureMasiva;
import 'masiva_validacion_test.dart'
    show ValidacionFixture, openValidation, scanSku, searchPerson, tapVisible;

class WorkspaceFixture extends ValidacionFixture {
  WorkspaceFixture(this.articleCount, {super.missingPacker = false})
    : allPending = missingPacker,
      super(validated: missingPacker ? 0 : 1);

  final int articleCount;
  final bool allPending;

  String get lastSku => '9000${articleCount.toString().padLeft(4, '0')}';

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    final data = await super.consultar(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
    if (operacion == null ||
        !['kits', 'validacion_documento'].contains(vista)) {
      return data;
    }
    return {
      ...data,
      'filas': [
        for (final kit in filasMasiva(data['filas']))
          {
            ...kit,
            'articulos': [
              ...filasMasiva(kit['articulos']),
              for (var i = 2; i <= articleCount; i++)
                {
                  'id': 'art$i',
                  'sku': '9000${i.toString().padLeft(4, '0')}',
                  'descripcion':
                      i.isEven
                          ? 'Prenda $i de trabajo, manga larga y protección reforzada talla XL'
                          : 'Prenda de trabajo $i talla M',
                  'cantidad': 1,
                  'validado': allPending ? 0 : 1,
                  'fecha_hora_validado':
                      allPending ? null : '2026-10-27T14:30:00Z',
                },
            ],
          },
      ],
    };
  }
}

Finder get _person => find.byKey(const ValueKey('masiva-persona'));
Finder get _sku => find.byKey(const ValueKey('masiva-sku'));
Finder get _container =>
    find.byKey(const ValueKey('masiva-validation-container'));
Finder get _pack => find.widgetWithText(FilledButton, 'Empacar');

void expectVisible(WidgetTester tester, Finder finder, Size viewport) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewport.width + .1));
  expect(rect.top, greaterThanOrEqualTo(72));
  expect(rect.bottom, lessThanOrEqualTo(viewport.height + .1));
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> chooseContainer(WidgetTester tester) async {
  final type = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Tipo de empaque',
  );
  await tapVisible(tester, type);
  await tester.tap(find.text('Caja mediana').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(_container);
  await tester.enterText(_container, '3');
  await tester.pumpAndSettle();
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
    final roboto =
        FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
    await roboto.load();
  });

  for (final size in [const Size(1366, 768), const Size(1920, 930)]) {
    for (final articles in [3, 20]) {
      testWidgets(
        'Estación ${size.width.toInt()}×${size.height.toInt()} conserva captura y Empacar con $articles prendas',
        (tester) async {
          final repo = WorkspaceFixture(articles);
          await openValidation(tester, repo, size: size, search: false);
          expectVisible(tester, _person, size);
          if (articles == 3) {
            await captureMasiva(
              tester,
              'masiva-workspace-inicial-${size.width.toInt()}',
            );
          }
          await searchPerson(tester);
          for (final control in [_person, _sku, _container, _pack]) {
            expectVisible(tester, control, size);
          }
          expect(
            find.ancestor(of: _sku, matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'La captura no debe pertenecer al scroll del detalle',
          );
          final before = {
            'person': tester.getRect(_person),
            'sku': tester.getRect(_sku),
            'pack': tester.getRect(_pack),
          };
          if (articles == 3) {
            expect(
              find.text(repo.lastSku).hitTestable(),
              findsOneWidget,
              reason:
                  'Un kit de tres prendas debe verse completo sin desplazar',
            );
          }
          if (articles == 20) {
            final items = find.byKey(const ValueKey('masiva-validation-items'));
            expect(items, findsOneWidget);
            final scrollable = find.descendant(
              of: items,
              matching: find.byType(Scrollable),
            );
            final vertical = scrollable.evaluate().where((element) {
              final widget = element.widget as Scrollable;
              return widget.axisDirection == AxisDirection.down ||
                  widget.axisDirection == AxisDirection.up;
            });
            expect(vertical, hasLength(1));
            final state =
                (vertical.single as StatefulElement).state as ScrollableState;
            expect(state.position.maxScrollExtent, greaterThan(0));
            await tester.drag(items, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(state.position.pixels, greaterThan(0));
            state.position.jumpTo(state.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(find.text(repo.lastSku).hitTestable(), findsOneWidget);
            expect(tester.getRect(_person), before['person']);
            expect(tester.getRect(_sku), before['sku']);
            expect(tester.getRect(_pack), before['pack']);
          }
          await captureMasiva(
            tester,
            'masiva-workspace-kit-${size.width.toInt()}-$articles',
          );
          await scanSku(tester, '000123');
          expect(repo.writes.single.action, 'validar');
          expect(tester.widget<TextField>(_sku).focusNode!.hasFocus, isTrue);
          for (final control in [_person, _sku, _container, _pack]) {
            expectVisible(tester, control, size);
          }
          await chooseContainer(tester);
          expectVisible(tester, _pack, size);
          await tester.tap(_pack);
          await tester.pumpAndSettle();
          expect(repo.writes.last.action, 'embalar');
          expect(repo.writes.last.data['caja'], 3);
          expect(tester.widget<TextField>(_person).focusNode!.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(390, 844), const Size(768, 1024)]) {
    testWidgets(
      'Captura, prendas y empaque accesibles con scroll a ${size.width.toInt()} px',
      (tester) async {
        final repo = WorkspaceFixture(3);
        await openValidation(tester, repo, size: size, search: false);
        await tester.ensureVisible(_person);
        await tester.pumpAndSettle();
        await captureMasiva(
          tester,
          'masiva-workspace-inicial-${size.width.toInt()}',
        );
        await searchPerson(tester);
        await scanSku(tester, '000123');
        expect(repo.writes.single.action, 'validar');
        await tester.ensureVisible(find.text(repo.lastSku));
        await tester.pumpAndSettle();
        expect(find.text(repo.lastSku).hitTestable(), findsOneWidget);
        await tester.ensureVisible(_pack);
        await tester.pumpAndSettle();
        expect(_pack.hitTestable(), findsOneWidget);
        await captureMasiva(
          tester,
          'masiva-workspace-kit-${size.width.toInt()}',
        );
        await chooseContainer(tester);
        await tapVisible(tester, _pack);
        expect(repo.writes.last.action, 'embalar');
        expect(repo.writes.last.data['caja'], 3);
        await tester.ensureVisible(_person);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(_person).focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Sin empaque previo conserva atribución y prendas en escritorio',
    (tester) async {
      const size = Size(1366, 768);
      final repo = WorkspaceFixture(3, missingPacker: true);
      await openValidation(tester, repo, size: size);
      final picker = find.byKey(const ValueKey('masiva-validation-packer'));
      expect(
        tester.widget<DropdownButton<String>>(picker).focusNode!.hasFocus,
        isTrue,
      );
      expect(find.textContaining('MAL EMPAQUE'), findsWidgets);
      for (final control in [_person, _sku, _container, picker, _pack]) {
        expectVisible(tester, control, size);
      }
      expect(find.text(repo.lastSku).hitTestable(), findsOneWidget);
      await captureMasiva(tester, 'masiva-workspace-sin-empaque-1366');
      await tapVisible(tester, picker);
      await tester.tap(find.text('Empacador de ejemplo').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_sku).focusNode!.hasFocus, isTrue);
      await scanSku(tester, '000123');
      expect(repo.writes.single.data['empacador_id'], 'person1');
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (size: const Size(1366, 600), textScale: 1.0, name: 'altura reducida'),
    (size: const Size(1366, 768), textScale: 1.4, name: 'texto ampliado'),
  ]) {
    testWidgets('Fallback con ${scenario.name} mantiene acciones accesibles', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scenario.textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = WorkspaceFixture(3);
      await openValidation(tester, repo, size: scenario.size);
      await scanSku(tester, '000123');
      expect(repo.writes.single.action, 'validar');
      await chooseContainer(tester);
      await tapVisible(tester, _pack);
      expect(repo.writes.last.action, 'embalar');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Móvil conserva captura manual con espacio para teclado virtual',
    (tester) async {
      final repo = WorkspaceFixture(3);
      await openValidation(tester, repo, size: const Size(390, 844));
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await scanSku(tester, '000123');
      expect(repo.writes.single.action, 'validar');
      expect(_sku.hitTestable(), findsOneWidget);
      expect(tester.getRect(_sku).bottom, lessThanOrEqualTo(544));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await chooseContainer(tester);
      await tapVisible(tester, _pack);
      expect(repo.writes.last.action, 'embalar');
      expect(tester.takeException(), isNull);
    },
  );
}
