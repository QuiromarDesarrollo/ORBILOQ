import 'package:orbiloq_wms/features/conductor/presentation/actividad_conductor_form.dart';
import 'package:orbiloq_wms/features/conductor/kit_semanal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/presentation/revision_salida_page.dart';

Future<ConductorRepository> preparar() async {
  final repo = ConductorRepository(null);
  await repo.guardar('demo', 'Inicio de jornada', 48250, {
    'notas': 'Revisar frenos',
    'respuestas': {
      for (final p in checklistConductor.values.expand((e) => e))
        p: p == 'Estado frenos' ? 'Con novedad' : 'Buen estado',
    },
  });
  return repo;
}

class _RepositorioGrupos extends ConductorRepository {
  _RepositorioGrupos() : super(null);
  @override
  Future<Map<String, dynamic>> revisionSalida(
    String vehiculo, {
    bool detalle = false,
  }) async => {
    'version': 2,
    'estado': 'Sin checklist',
    'checklists': [],
    'tareas': [
      {
        'id': '3',
        'estado': 'Cerrada',
        'descripcion': 'Luces reparadas',
        'motivos': ['Luces altas'],
        'fecha_limite': '2026-10-25',
      },
      {
        'id': '2',
        'estado': 'Pendiente',
        'descripcion': 'Cambiar llanta',
        'motivos': ['Llanta'],
        'fecha_limite': '2026-10-28',
      },
      {
        'id': '1',
        'estado': 'Pendiente',
        'descripcion': 'Arreglar frenos',
        'motivos': ['Frenos'],
        'fecha_limite': '2026-10-23',
      },
      {
        'id': '4',
        'estado': 'Por verificar',
        'descripcion': 'Revisar entrega',
        'motivos': ['Aceite'],
        'fecha_limite': '2026-10-24',
      },
    ],
  };
}

class _RepositorioFiltros extends ConductorRepository {
  _RepositorioFiltros() : super(null);
  int consultas = 0;
  @override
  Future<Map<String, dynamic>> revisionSalida(
    String vehiculo, {
    bool detalle = false,
  }) async {
    consultas++;
    return {
      'version': 2,
      'estado': 'Sin checklist',
      'tareas': [],
      'checklists': [
        {
          'id': 'inicio',
          'tipo': 'Inicio de jornada',
          'actor_nombre': 'Conductor A',
          'datos': {
            'fecha': '2026-10-20',
            'respuestas': {'Frenos': 'Con novedad', 'Luces': 'Buen estado'},
          },
        },
        {
          'id': 'fin',
          'tipo': 'Fin de jornada',
          'actor_nombre': 'Conductor B',
          'datos': {
            'fecha': '2026-10-21',
            'respuestas': {'Frenos': 'Buen estado', 'Luces': 'Buen estado'},
          },
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'Historial filtra resultados, cuenta puntos y conserva filtros al refrescar',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _RepositorioFiltros();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RevisionSalidaPage(vehiculo: 'demo', administrador: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 con novedad'), findsOneWidget);
      expect(find.text('2 en buen estado'), findsOneWidget);
      final resultado = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'resultado-historial-',
            ),
      );
      await tester.ensureVisible(resultado);
      await tester.pumpAndSettle();
      await tester.tap(resultado);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Con novedad').last);
      await tester.pumpAndSettle();
      expect(find.text('Registrado por Conductor A'), findsOneWidget);
      expect(find.text('Registrado por Conductor B'), findsNothing);
      final antes = repo.consultas;
      await tester.ensureVisible(find.text('Actualizar historial'));
      await tester.tap(find.text('Actualizar historial'));
      await tester.pumpAndSettle();
      expect(repo.consultas, antes + 1);
      expect(find.text('Registrado por Conductor B'), findsNothing);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Registrado por Conductor B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final ancho in [390.0, 1440.0]) {
    testWidgets('Actividades agrupadas y completadas contraídas a $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conductorRepositoryProvider.overrideWithValue(_RepositorioGrupos()),
          ],
          child: const MaterialApp(
            home: RevisionSalidaPage(vehiculo: 'demo', administrador: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('2 actividades'), findsOneWidget);
      expect(find.text('Luces reparadas'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Arreglar frenos')).dy,
        lessThan(tester.getTopLeft(find.text('Cambiar llanta')).dy),
      );
      await tester.ensureVisible(find.text('Completadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completadas'));
      await tester.pumpAndSettle();
      expect(find.text('Luces reparadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Administrador consulta el checklist y asigna sus novedades desde el historial',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await preparar();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RevisionSalidaPage(vehiculo: 'demo', administrador: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Autorizar salida'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver checklist').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver checklist').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Estado frenos'), findsOneWidget);
      expect(find.text('Con novedad'), findsOneWidget);
      final dialogo = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialogo, matching: find.text('Buen estado')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(of: dialogo, matching: find.text('Con novedad')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(
                  of: dialogo,
                  matching: find.text('Buen estado'),
                ),
              )
              .dy,
        ),
      );
      expect(
        find.descendant(of: dialogo, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialogo,
          matching: find.text(
            '${checklistConductor.values.expand((v) => v).length - 1}',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Seleccionar novedades y asignar actividad'));
      await tester.pumpAndSettle();
      expect(find.byType(ActividadConductorForm), findsOneWidget);
      expect(find.text('Estado frenos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Salida pendiente, actividad, verificación y autorización explícita',
    () async {
      final repo = await preparar();
      var resumen = await repo.revisionSalida('demo');
      expect(resumen['estado'], 'Pendiente de aprobación');
      final id = (resumen['checklists'] as List).first['id'] as String;
      await repo.crearActividad(
        id,
        ['Estado frenos'],
        'Reparar frenos',
        fechaKit(hoyColombia()),
      );
      await repo.revisionAccion(
        id,
        'Autorizado',
        'Puede salir, reparación programada',
      );
      expect((await repo.revisionSalida('demo'))['estado'], 'Autorizado');
      resumen = await repo.revisionSalida('demo');
      final tarea = (resumen['tareas'] as List).first['id'] as String;
      await expectLater(
        repo.entregarActividad(tarea, 'Solucionado', ''),
        throwsFormatException,
      );
      await repo.entregarActividad(
        tarea,
        'Reparación realizada',
        'https://drive.google.com/file/d/prueba/view',
      );
      final enviada = (await repo.revisionSalida('demo'))['tareas'][0];
      expect(enviada['estado'], 'Por verificar');
      expect(enviada['entregado_en'], isNotNull);
      final hora = enviada['entregado_en'];
      await repo.entregarActividad(
        tarea,
        'Reparación realizada',
        'https://drive.google.com/file/d/prueba/view',
      );
      expect(
        (await repo.revisionSalida('demo'))['tareas'][0]['entregado_en'],
        hora,
      );
      await repo.revisionAccion(
        id,
        'Cerrada',
        'Reparación comprobada',
        tarea: tarea,
      );
      expect((await repo.revisionSalida('demo'))['estado'], 'Autorizado');
      await repo.revisionAccion(id, 'Autorizado', 'Puede salir');
      expect((await repo.revisionSalida('demo'))['estado'], 'Autorizado');
    },
  );
  testWidgets('Asignar actividad desde novedades y exigir foto al entregar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await preparar();
    final registro =
        (await repo.revisionSalida('demo'))['checklists'][0] as Map;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: ActividadConductorForm(vehiculo: 'demo', registro: registro),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estado frenos'), findsOneWidget);
    expect(find.text('Nivel de aceite'), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.enterText(
      find.widgetWithText(TextField, 'Mantenimiento asignado'),
      'Reparar frenos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instrucciones de la actividad'),
      'Reparar sistema de frenos',
    );
    expect(find.textContaining('Fecha límite:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await repo.crearActividad(
      registro['id'],
      ['Estado frenos'],
      'Reparar sistema de frenos',
      fechaKit(hoyColombia()),
    );
    final tarea = (await repo.revisionSalida('demo'))['tareas'][0] as Map;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: ActividadConductorForm(
            key: const ValueKey('entrega'),
            vehiculo: 'demo',
            tarea: tarea,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reparado');
    await tester.ensureVisible(find.text('Enviar para verificación'));
    await tester.tap(find.text('Enviar para verificación'));
    await tester.pumpAndSettle();
    expect(
      find.text('Describe la solución y adjunta una foto.'),
      findsOneWidget,
    );
    expect(
      (await repo.revisionSalida('demo'))['tareas'][0]['estado'],
      'Pendiente',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Motivo asignado desaparece y su tarjeta permanece incluso completado',
    (tester) async {
      final repo = await preparar();
      final registro =
          (await repo.revisionSalida('demo'))['checklists'][0] as Map;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: ActividadConductorForm(vehiculo: 'demo', registro: registro),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(
        find.widgetWithText(TextField, 'Mantenimiento asignado'),
        'Cambiar pastillas',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Instrucciones de la actividad'),
        'Reparar frenos',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crear actividad'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear actividad'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Reparar frenos'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      final t = (await repo.revisionSalida('demo'))['tareas'][0] as Map;
      await repo.guardar('demo', 'Mantenimiento correctivo', 48250, {
        'actividad_id': t['id'],
        'servicio': 'Cambiar pastillas',
        'taller': 'Taller',
        'valor': '100',
        'enlace': 'https://drive.google.com/file/d/foto/view',
      });
      await repo.revisionAccion(
        registro['id'],
        'Cerrada',
        'Verificado',
        tarea: t['id'],
      );
      await tester.tap(find.byTooltip('Actualizar seguimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Completada'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await expectLater(
        repo.crearActividad(
          registro['id'],
          ['Estado frenos'],
          'Duplicada',
          fechaKit(hoyColombia()),
        ),
        throwsFormatException,
      );
    },
  );
  for (final ancho in [390.0, 1440.0]) {
    testWidgets('Revisión adaptable a $ancho, conductor sin respuestas', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await preparar();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RevisionSalidaPage(vehiculo: 'demo', administrador: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pendiente de aprobación'), findsOneWidget);
      expect(find.text('Autorizar salida'), findsNothing);
      expect(find.textContaining('Estado frenos'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
