import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/kit_semanal.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/actividad_notificacion_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/actividad_conductor_form.dart';

class _Repo extends ConductorRepository {
  _Repo() : super(null);
  String estado = 'Pendiente';
  bool visible = true;
  int consultas = 0;
  @override
  Future<Map<String, dynamic>> revisionSalida(
    String vehiculo, {
    bool detalle = false,
  }) async {
    consultas++;
    return {
      'version': 2,
      'estado': 'Sin checklist de salida',
      'tareas': [
        {
          'id': 'luces',
          'descripcion': 'Arreglar luces',
          'estado': 'Pendiente',
          'motivos': ['Luces altas'],
        },
        if (visible)
          {
            'id': 'frenos',
            'descripcion': 'Arreglar frenos',
            'estado': estado,
            'motivos': ['Estado frenos'],
            'fecha_limite': fechaKit(
              hoyColombia().add(const Duration(days: 1)),
            ),
          },
      ],
    };
  }
}

void main() {
  test('Plazos de actividad respetan fechas y estados', () {
    final hoy = DateTime(2026, 10, 23);
    expect(
      plazoActividad({
        'estado': 'Pendiente',
        'fecha_limite': '2026-10-24',
      }, hoy),
      contains('Vence mañana'),
    );
    expect(
      plazoActividad({
        'estado': 'Pendiente',
        'fecha_limite': '2026-10-23',
      }, hoy),
      contains('Vence hoy'),
    );
    expect(
      plazoActividad({
        'estado': 'Pendiente',
        'fecha_limite': '2026-10-22',
      }, hoy),
      contains('Vencida hace 1 día'),
    );
    expect(
      plazoActividad({
        'estado': 'Por verificar',
        'fecha_limite': '2026-10-22',
      }, hoy),
      'Por verificar',
    );
  });
  for (final estado in ['Pendiente', 'Por verificar', 'Cerrada']) {
    testWidgets('Alerta dirige al ID correcto y consulta estado $estado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ConductorPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Pendiente · Vence mañana'),
        ),
        findsOneWidget,
      );
      final consultas = repo.consultas;
      repo.estado = estado;
      if (estado == 'Cerrada') repo.visible = false;
      await tester.ensureVisible(
        find.text('Tienes una actividad pendiente: Arreglar frenos'),
      );
      await tester.tap(
        find.text('Tienes una actividad pendiente: Arreglar frenos'),
      );
      await tester.pumpAndSettle();
      expect(repo.consultas, greaterThan(consultas));
      if (estado == 'Pendiente') {
        final form = tester.widget<ActividadConductorForm>(
          find.byType(ActividadConductorForm),
        );
        expect(form.tarea?['id'], 'frenos');
        expect(form.vehiculo, 'demo');
        expect(find.text('Arreglar frenos'), findsOneWidget);
        expect(find.text('Arreglar luces'), findsNothing);
      } else {
        expect(find.byType(ActividadConductorForm), findsNothing);
        expect(
          find.text(
            estado == 'Cerrada' ? 'Actividad no disponible' : 'Por verificar',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Próximos vencimientos y tareas'), findsNothing);
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
      if (estado == 'Cerrada') {
        expect(
          find.text('Tienes una actividad pendiente: Arreglar frenos'),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
