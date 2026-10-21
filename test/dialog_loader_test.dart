import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';

void main() {
  testWidgets('Una pestaña oculta no bloquea el diálogo', (tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder:
                (_, active, __) => WmsDialogLoadingHost(
                  child: Column(
                    children: [
                      TickerMode(
                        enabled: active,
                        child: Offstage(
                          offstage: !active,
                          child: const WmsLoader(),
                        ),
                      ),
                      TextButton(
                        onPressed: () => presses++,
                        child: const Text('Cambiar pestaña'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dialog-loader-central')), findsNothing);
    await tester.tap(find.text('Cambiar pestaña'));
    expect(presses, 1);
    visible.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('dialog-loader-central')), findsOneWidget);
    visible.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('dialog-loader-central')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Cargas simultáneas centradas en el diálogo y retirada al terminar',
    (tester) async {
      final pending = ValueNotifier<int>(2);
      addTearDown(pending.dispose);
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: pending,
              builder:
                  (context, count, _) => WmsDialogShell(
                    title: 'Catálogo',
                    icon: Icons.person,
                    iconColor: Colors.blue,
                    expand: true,
                    child: Column(
                      children: [
                        if (count > 0) const WmsLoadingStrip(),
                        if (count > 1) const WmsLoader(),
                        TextButton(
                          onPressed: () => presses++,
                          child: const Text('Acción'),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final central = find.byKey(const ValueKey('dialog-loader-central'));
      expect(central, findsOneWidget);
      final dialog = tester.getRect(find.byType(Dialog));
      final logo = tester.getCenter(central);
      expect(logo.dx, closeTo(dialog.center.dx, 1));
      expect((logo.dy - dialog.center.dy).abs(), lessThan(30));
      expect(tester.getSize(central).width, greaterThan(150));
      await tester.tap(find.text('Acción'), warnIfMissed: false);
      expect(presses, 0);
      pending.value = 1;
      await tester.pump();
      await tester.pump();
      expect(central, findsOneWidget);
      pending.value = 0;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(central, findsNothing);
      await tester.tap(find.text('Acción'));
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
