import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/masiva/presentation/widgets/masiva_receipt_card.dart';

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
  double height = 850,
  double textScale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.kardex(TemaModo.corporativo),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: RepaintBoundary(
        key: capture,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MasivaReceiptCard _card(
  TextEditingController quantity, {
  String id = 'first',
  String sku = '87005069',
  String description = 'CAMISETA POLO CABALL ADMI T.38',
  int expected = 29,
  int received = 0,
  bool enabled = true,
  String note = '',
  VoidCallback? onRecount,
  VoidCallback? onRemove,
  VoidCallback? onConfirm,
}) => MasivaReceiptCard(
  key: ValueKey('receipt-card-$id'),
  itemId: id,
  sku: sku,
  description: description,
  provider: 'INDUCON',
  order: '4001277684',
  support: '111',
  note: note,
  expected: expected,
  received: received,
  quantity: quantity,
  enabled: enabled,
  onRecount: onRecount ?? () => quantity.text = '1',
  onRemove: onRemove ?? () {},
  onConfirm: onConfirm ?? () {},
);

Future<void> _open(WidgetTester tester, [String id = 'first']) async {
  final toggle = find.byKey(ValueKey('toggle-receipt-$id'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/recepcion-compacta-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['Roboto', 'sans-serif']) {
      await (FontLoader(family)..addFont(
        rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
      )).load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'Resumen y edición de recepción completables a $width px, texto $scale',
        (tester) async {
          final quantity = TextEditingController(text: '1');
          addTearDown(quantity.dispose);
          final capture = GlobalKey();
          int confirmations = 0;
          await _mount(
            tester,
            _card(quantity, onConfirm: () => confirmations++),
            width: width,
            textScale: scale,
            capture: capture,
          );
          expect(
            find.byKey(const ValueKey('receipt-quantity-first')),
            findsNothing,
          );
          expect(find.textContaining('87005069'), findsWidgets);
          expect(find.textContaining('por confirmar'), findsWidgets);
          expect(tester.takeException(), isNull);
          if (width >= 768) {
            expect(
              tester.getSize(find.byType(MasivaReceiptCard)).height,
              lessThan(180),
            );
          }
          if (scale == 1 || width == 320) {
            await _capture(
              tester,
              capture,
              '${width.toInt()}-texto-$scale-plegada',
            );
          }
          await _open(tester);
          final field = find.byKey(const ValueKey('receipt-quantity-first'));
          await tester.ensureVisible(field);
          await tester.enterText(field, '3');
          await tester.pumpAndSettle();
          expect(quantity.text, '3');
          expect(find.textContaining('por confirmar'), findsWidgets);
          final confirm = find.byKey(const ValueKey('confirm-receipt-first'));
          await tester.ensureVisible(confirm);
          expect(confirm.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1 || width == 320) {
            await _capture(
              tester,
              capture,
              '${width.toInt()}-texto-$scale-abierta',
            );
          }
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(confirmations, 1);
          await _open(tester);
          expect(
            find.byKey(const ValueKey('receipt-quantity-first')),
            findsNothing,
          );
          expect(quantity.text, '3');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Límites, Todo y Recontar conservan la cantidad válida', (
    tester,
  ) async {
    final quantity = TextEditingController(text: '1');
    addTearDown(quantity.dispose);
    var confirmations = 0;
    var recounts = 0;
    await _mount(
      tester,
      _card(
        quantity,
        expected: 29,
        received: 7,
        onConfirm: () => confirmations++,
        onRecount: () {
          recounts++;
          quantity.text = '1';
        },
      ),
    );
    await _open(tester);
    final field = find.byKey(const ValueKey('receipt-quantity-first'));
    final confirm = find.byKey(const ValueKey('confirm-receipt-first'));
    for (final invalid in ['0', '23', '']) {
      await tester.enterText(field, invalid);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(confirm).onPressed,
        isNull,
        reason: 'Cantidad inválida: "$invalid"',
      );
    }
    await tester.tap(find.text('Todo (22)'));
    await tester.pumpAndSettle();
    expect(quantity.text, '22');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmations, 1);
    await tester.tap(find.text('Recontar'));
    await tester.pumpAndSettle();
    expect(recounts, 1);
    expect(quantity.text, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Al confirmar se bloquean los controles de escritura', (
    tester,
  ) async {
    final quantity = TextEditingController(text: '2');
    addTearDown(quantity.dispose);
    var enabled = true;
    var writes = 0;
    late StateSetter update;
    await _mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _card(
            quantity,
            enabled: enabled,
            onRecount: () => writes++,
            onRemove: () => writes++,
            onConfirm: () => writes++,
          );
        },
      ),
    );
    await _open(tester);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.byType(FilledButton),
    )) {
      expect(button.onPressed, isNull);
    }
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(quantity.text, '2');
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teclado visible no oculta confirmar ni pierde lo escrito', (
    tester,
  ) async {
    final quantity = TextEditingController(text: '1');
    addTearDown(quantity.dispose);
    var writes = 0;
    await _mount(
      tester,
      _card(quantity, onConfirm: () => writes++),
      width: 390,
      height: 600,
    );
    await _open(tester);
    final field = find.byKey(const ValueKey('receipt-quantity-first'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '12');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('confirm-receipt-first'));
    await tester.ensureVisible(confirm);
    expect(confirm.hitTestable(), findsOneWidget);
    expect(quantity.text, '12');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Texto doble, nombres largos y cantidades de seis cifras en móvil', (
    tester,
  ) async {
    final quantity = TextEditingController(text: '123456');
    addTearDown(quantity.dispose);
    final capture = GlobalKey();
    await _mount(
      tester,
      _card(
        quantity,
        description:
            'CAMISETA POLO MANGA LARGA PARA PERSONAL ADMINISTRATIVO EN ALGODÓN TALLA 38',
        expected: 999999,
        note:
            'Recepción parcial. Verificar todas las tallas antes de confirmar.',
      ),
      width: 320,
      textScale: 2,
      capture: capture,
    );
    expect(tester.takeException(), isNull);
    await _open(tester);
    final confirm = find.byKey(const ValueKey('confirm-receipt-first'));
    await tester.ensureVisible(confirm);
    expect(confirm.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, capture, '320-texto-2.0-largo');
  });

  testWidgets(
    'Reordenar no cambia la cantidad ni la expansión de otra tarjeta',
    (tester) async {
      final first = TextEditingController(text: '2');
      final second = TextEditingController(text: '1');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var reversed = false;
      late StateSetter update;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            final cards = [
              _card(first),
              _card(second, id: 'second', sku: '87005070'),
            ];
            return Column(children: reversed ? cards.reversed.toList() : cards);
          },
        ),
      );
      await _open(tester);
      final quantityField = find.byKey(
        const ValueKey('receipt-quantity-first'),
      );
      await tester.enterText(quantityField, '5');
      update(() => reversed = true);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('receipt-card-second'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('receipt-card-first')))
              .dy,
        ),
      );
      expect(quantityField, findsOneWidget);
      expect(
        find.byKey(const ValueKey('receipt-quantity-second')),
        findsNothing,
      );
      expect(first.text, '5');
      expect(second.text, '1');
      expect(tester.takeException(), isNull);
    },
  );
}
