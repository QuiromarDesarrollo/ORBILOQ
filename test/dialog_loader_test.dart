import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';

void main() {
  testWidgets('Cargas simultáneas centradas en el diálogo y retirada al terminar', (tester) async {
    final pending = ValueNotifier<int>(2);
    addTearDown(pending.dispose);
    var presses = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ValueListenableBuilder<int>(
      valueListenable: pending,
      builder: (context, count, _) => WmsDialogShell(title: 'Catálogo', icon: Icons.person, iconColor: Colors.blue, expand: true,
        child: Column(children: [
          if(count > 0) const WmsLoadingStrip(),
          if(count > 1) const WmsLoader(),
          TextButton(onPressed: () => presses++, child: const Text('Acción')),
        ])),
    ))));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
    final central = find.byKey(const ValueKey('dialog-loader-central'));
    expect(central, findsOneWidget);
    final dialog = tester.getRect(find.byType(Dialog));
    final logo = tester.getCenter(central);
    expect(logo.dx, closeTo(dialog.center.dx, 1));
    expect((logo.dy-dialog.center.dy).abs(), lessThan(30));
    expect(tester.getSize(central).width, greaterThan(150));
    await tester.tap(find.text('Acción'), warnIfMissed:false);
    expect(presses,0);
    pending.value=1;
    await tester.pump(); await tester.pump();
    expect(central, findsOneWidget);
    pending.value=0;
    await tester.pump(); await tester.pumpAndSettle();
    expect(central, findsNothing);
    await tester.tap(find.text('Acción')); expect(presses,1);
    expect(tester.takeException(),isNull);
  });
}
