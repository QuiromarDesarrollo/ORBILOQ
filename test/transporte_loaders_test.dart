import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/transporte_scaffold.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';

void main() {
  testWidgets(
    'Guardado usa loader grande, bloquea acciones y conserva el formulario',
    (tester) async {
      String? mensaje;
      late StateSetter actualizar;
      var clicks = 0;
      final controller = TextEditingController(text: 'Trabajo ingresado');
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              actualizar = setState;
              return TransporteScaffold(
                loadingLabel: mensaje,
                body: Column(
                  children: [
                    TextField(controller: controller),
                    TextButton(
                      onPressed: () => clicks++,
                      child: const Text('Otra acción'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      actualizar(() => mensaje = 'Subiendo evidencias 1 de 3…');
      await tester.pump();
      final loader = tester.widget<WmsLoader>(find.byType(WmsLoader));
      expect(loader.mode, OrbiloqLoaderMode.orbit);
      expect(loader.width, greaterThanOrEqualTo(200));
      expect(find.text('Subiendo evidencias 1 de 3…'), findsOneWidget);
      await tester.tap(find.text('Otra acción'), warnIfMissed: false);
      expect(clicks, 0);
      actualizar(() => mensaje = 'Enviando mantenimiento para validación…');
      await tester.pump();
      expect(find.text(mensaje!), findsOneWidget);
      actualizar(() => mensaje = null);
      await tester.pumpAndSettle();
      expect(controller.text, 'Trabajo ingresado');
      expect(find.byType(WmsLoader), findsNothing);
      await tester.tap(find.text('Otra acción'));
      expect(clicks, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('Loader grande se adapta a móvil horizontal y texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(568, 320),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: const TransporteScaffold(
            loadingLabel: 'Guardando revisión semanal del kit de carretera…',
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(WmsLoadingPanel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
