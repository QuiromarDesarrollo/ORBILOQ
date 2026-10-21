import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/conductor_entorno.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

void main() {
  test('Solo disponible en demo y DEV, sin permisos operativos implícitos', () {
    expect(conductorHabilitado(''), isTrue);
    expect(
      conductorHabilitado('https://igfuafcekcpugpmsoqbe.supabase.co'),
      isTrue,
    );
    expect(
      conductorHabilitado('https://cxrflhgnxvomcvxzugda.supabase.co'),
      isFalse,
    );
    const usuario = UsuarioSesion(
      numeroUsuario: '1',
      nombre: 'Conductor',
      rolCuenta: RolCuenta.conductor,
    );
    expect(usuario.areas, isEmpty);
    expect(usuario.puedeVerDashboards, isFalse);
    expect(RolCuenta.deFila({'rol': 'conductor'}), [RolCuenta.conductor]);
  });
  test('Inspecciones completas, kilometraje y evidencias', () {
    final respuestas = {
      for (final p in checklistConductor.values.expand((e) => e))
        p: 'Buen estado',
    };
    for (final tipo in ['Inicio de jornada', 'Fin de jornada']) {
      expect(
        validarRegistroConductor(
          tipo: tipo,
          km: 10,
          ultimoKm: 10,
          respuestas: {},
          notas: '',
          enlace: '',
        ),
        isNotNull,
      );
      expect(
        validarRegistroConductor(
          tipo: tipo,
          km: 10,
          ultimoKm: 10,
          respuestas: respuestas,
          notas: '',
          enlace: '',
        ),
        isNull,
      );
    }
    respuestas['Estado frenos'] = 'Con novedad';
    expect(
      validarRegistroConductor(
        tipo: 'Inicio de jornada',
        km: 10,
        ultimoKm: 10,
        respuestas: respuestas,
        notas: '',
        enlace: '',
      ),
      isNotNull,
    );
    expect(
      validarRegistroConductor(
        tipo: 'Tanqueo',
        km: 9,
        ultimoKm: 10,
        respuestas: {},
        notas: '',
        enlace: '',
      ),
      isNotNull,
    );
    expect(
      enlaceDriveValido('https://drive.google.com/file/d/123/view'),
      isTrue,
    );
    expect(
      enlaceDriveValido('https://drive.google.com.ejemplo.com/a'),
      isFalse,
    );
    expect(enlaceDriveValido('javascript:alert(1)'), isFalse);
    expect(
      diasRestantes(DateTime(2026, 10, 22), DateTime(2026, 10, 20, 23)),
      2,
    );
  });
  test('Guardar evidencia mantiene un enlace, no bytes de imagen', () async {
    final repo = ConductorRepository(null);
    await repo.guardar('demo', 'Registro diario', 48251, {
      'enlace': 'https://drive.google.com/file/d/123/view',
    });
    expect((await repo.vehiculos()).first.km, 48251);
    expect(
      (await repo.historial('demo')).single['datos']['enlace'],
      'https://drive.google.com/file/d/123/view',
    );
  });
  for (final width in [320.0, 390.0, 850.0, 1440.0]) {
    testWidgets('Conductor adaptable a $width', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ConductorPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hola, conductor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Checklist').last);
      await tester.pumpAndSettle();
      expect(find.text('Inspección del vehículo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Seguimiento').last);
      await tester.pumpAndSettle();
      expect(find.text('Estado y fotos del vehículo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width >= 900) {
        await tester.tap(find.text('Mantenimiento').last);
      } else {
        await tester.tap(find.text('Más').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mantenimiento').last);
      }
      await tester.pumpAndSettle();
      expect(find.text('Nuevo registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Alertas'));
      await tester.pumpAndSettle();
      expect(find.text('Próximos vencimientos y tareas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tipo in [...eventosConductor, 'Documentos']) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: RegistroConductorPage(
                key: ValueKey(tipo),
                vehiculo: const VehiculoConductor(
                  id: 'demo',
                  placa: 'DEMO 01',
                  descripcion: 'Vehículo prueba',
                  km: 48250,
                ),
                tipo: tipo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tipo);
        expect(find.text('Guardar registro').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
