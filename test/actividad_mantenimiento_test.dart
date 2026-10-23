import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/kit_semanal.dart';
import 'package:orbiloq_wms/features/conductor/presentation/actividad_conductor_form.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

void main() {
  for (final preventivo in [true, false]) {
    testWidgets(
      'Actividad ${preventivo ? 'preventiva' : 'correctiva'} abre formulario bloqueado',
      (tester) async {
        final repo = ConductorRepository(null);
        final tipo =
            preventivo
                ? 'Mantenimiento preventivo'
                : 'Mantenimiento correctivo';
        final trabajo =
            preventivo
                ? 'Llenado de tanque de combustible'
                : 'Cambiar bombillo';
        await repo.crearActividadMantenimiento(
          'demo',
          null,
          [],
          'Trabajo asignado',
          fechaKit(hoyColombia()),
          tipo,
          trabajo,
          servicioId: preventivo ? 'combustible' : null,
        );
        final tarea = (await repo.revisionSalida('demo'))['tareas'][0] as Map;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: ActividadConductorForm(vehiculo: 'demo', tarea: tarea),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RegistroConductorPage), findsOneWidget);
        final campo = find.byKey(const ValueKey('campo-servicio'));
        await tester.scrollUntilVisible(
          campo,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        final input = tester.widget<TextFormField>(campo);
        expect(input.controller!.text, trabajo);
        final editable = tester.widget<EditableText>(
          find.descendant(of: campo, matching: find.byType(EditableText)),
        );
        expect(editable.readOnly, isTrue);
        if (preventivo)
          expect(find.byKey(const ValueKey('campo-galones')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Administrador crea una actividad independiente sin checklist', (
    tester,
  ) async {
    final repo = ConductorRepository(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: ActividadConductorForm(vehiculo: 'demo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Actividad independiente'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mantenimiento asignado'),
      'Reparar frenos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instrucciones de la actividad'),
      'Llevar al taller',
    );
    await tester.ensureVisible(find.text('Crear actividad'));
    await tester.tap(find.text('Crear actividad'));
    await tester.pumpAndSettle();
    final tareas = (await repo.revisionSalida('demo'))['tareas'] as List;
    expect(tareas, hasLength(1));
    expect(tareas.single['registro_id'], isNull);
    expect(tareas.single['mantenimiento_trabajo'], 'Reparar frenos');
    expect(tester.takeException(), isNull);
  });
  test(
    'Entrega vinculada rechaza cambios y espera validación antes del cierre',
    () async {
      final repo = ConductorRepository(null);
      await repo.crearActividadMantenimiento(
        'demo',
        null,
        [],
        'Cambiar pieza',
        fechaKit(hoyColombia()),
        'Mantenimiento correctivo',
        'Cambiar bombillo',
      );
      final tarea = (await repo.revisionSalida('demo'))['tareas'][0];
      final datos = <String, dynamic>{
        'actividad_id': tarea['id'],
        'servicio': 'Cambiar bombillo',
        'valor': '100',
        'taller': 'Taller',
        'enlace': 'https://drive.google.com/file/d/test/view',
      };
      await expectLater(
        repo.guardar('demo', 'Mantenimiento correctivo', 48250, {
          ...datos,
          'servicio': 'Otro',
        }),
        throwsFormatException,
      );
      expect(tarea['estado'], 'Pendiente');
      await repo.guardar('demo', 'Mantenimiento correctivo', 48250, datos);
      expect(tarea['estado'], 'Por verificar');
      expect(tarea['mantenimiento_registro_id'], isNotNull);
      await expectLater(
        repo.guardar('demo', 'Mantenimiento correctivo', 48250, datos),
        throwsFormatException,
      );
      await repo.revisionAccion(
        null,
        'Cerrada',
        'Validado',
        tarea: tarea['id'],
      );
      expect(tarea['estado'], 'Cerrada');
    },
  );
}
