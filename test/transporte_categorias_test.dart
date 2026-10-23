import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/kit_semanal_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/transporte_scaffold.dart';

class _Repo extends ConductorRepository {
  _Repo() : super(null);
  Map<String, dynamic>? guardado;
  @override
  Future<void> guardar(
    String id,
    String tipo,
    int km,
    Map<String, dynamic> datos,
  ) async {
    guardado = datos;
  }
}

const vehiculo = VehiculoConductor(
  id: 'demo',
  placa: 'TEST01',
  descripcion: 'Vehículo de prueba',
  km: 100,
);
void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Categorías conservan 27 respuestas y validan antes de guardar a $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: RegistroConductorPage(
                vehiculo: vehiculo,
                tipo: 'Inicio de jornada',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar registro'));
        await tester.pumpAndSettle();
        expect(repo.guardado, isNull);
        for (var i = 0; i < checklistConductor.length; i++) {
          final nav = tester.widget<TransporteCategorias>(
            find.byType(TransporteCategorias),
          );
          await tester.ensureVisible(find.byType(TransporteCategorias));
          await tester.pumpAndSettle();
          nav.onSelected(i);
          await tester.pumpAndSettle();
          for (final pregunta in checklistConductor.values.elementAt(i)) {
            final point = find.byKey(ValueKey('punto-$pregunta'));
            final chip = find.descendant(
              of: point,
              matching: find.widgetWithText(ChoiceChip, 'Buen estado'),
            );
            expect(
              chip,
              findsOneWidget,
              reason: 'Categoría $i, punto $pregunta',
            );
            await tester.ensureVisible(chip);
            await tester.pumpAndSettle();
            await tester.tap(chip);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }
        tester
            .widget<TransporteCategorias>(find.byType(TransporteCategorias))
            .onSelected(0);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .where((c) => c.selected)
              .length,
          3,
        );
        await tester.tap(find.text('Guardar registro'));
        await tester.pumpAndSettle();
        expect((repo.guardado!['respuestas'] as Map).length, 27);
        expect(
          (repo.guardado!['respuestas'] as Map).values.every(
            (r) => r == 'Buen estado',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Kit conserva detalle al cambiar de categoría', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: KitSemanalPage(vehiculo: vehiculo)),
      ),
    );
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(ChoiceChip, 'Con novedad').first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final detalle = find.widgetWithText(TextField, 'Detalle de la novedad *');
    await tester.enterText(detalle, 'Reemplazar mecanismo');
    tester
        .widget<ChoiceChip>(find.byKey(const ValueKey('kit-categoria-1')))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.byKey(const ValueKey('kit-categoria-0')))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.text('Reemplazar mecanismo'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Con novedad').first,
          )
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
