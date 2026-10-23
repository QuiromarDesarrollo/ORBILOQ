import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/bandeja_notificaciones.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

void main() {
  testWidgets(
    'Bandeja distingue leídas, filtra y devuelve la acción seleccionada',
    (tester) async {
      final leidas = <String>{};
      AvisoTransporte? seleccionado;
      final aviso = AvisoTransporte(
        id: 'frenos',
        titulo: 'Arreglar frenos',
        detalle: 'Vence mañana',
        accion: 'Ver actividad',
        icono: Icons.build,
        abrir: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      seleccionado = await showDialog<AvisoTransporte>(
                        context: context,
                        builder:
                            (_) => Dialog(
                              child: SizedBox(
                                width: 450,
                                height: 550,
                                child: BandejaNotificaciones(
                                  avisos: [aviso],
                                  leidas: leidas,
                                  alLeer: () {},
                                ),
                              ),
                            ),
                      );
                    },
                    child: const Text('Abrir'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('1 sin leer'), findsOneWidget);
      await tester.tap(find.text('Marcar todas como leídas'));
      await tester.pumpAndSettle();
      expect(leidas, contains('frenos'));
      await tester.tap(find.text('Sin leer'));
      await tester.pumpAndSettle();
      expect(find.text('No hay notificaciones pendientes'), findsOneWidget);
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arreglar frenos'));
      await tester.pumpAndSettle();
      expect(seleccionado, same(aviso));
    },
  );
  for (final ancho in [390.0, 1440.0]) {
    testWidgets(
      'Campana separada de Alertas y documento abre formulario a $ancho',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ConductorPage())),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Notificaciones'));
        await tester.pumpAndSettle();
        expect(find.byType(BandejaNotificaciones), findsOneWidget);
        expect(find.text('Próximos vencimientos y tareas'), findsNothing);
        await tester.ensureVisible(find.text('SOAT').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOAT').last);
        await tester.pumpAndSettle();
        expect(find.byType(RegistroConductorPage), findsOneWidget);
        expect(find.byType(BandejaNotificaciones), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
