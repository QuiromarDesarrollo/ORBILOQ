import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/mantenimiento_preventivo.dart';

void main() {
  testWidgets('Combustible solicita galones positivos y acepta decimales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegistroConductorPage(
            vehiculo: VehiculoConductor(
              id: 'demo',
              placa: 'TEST',
              descripcion: 'Test',
              km: 1000,
              datos: {},
            ),
            tipo: 'Mantenimiento preventivo',
            servicioPreventivo: 'combustible',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final campo = find.byKey(const ValueKey('campo-galones'));
    await tester.scrollUntilVisible(
      campo,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final validar = tester.widget<TextFormField>(campo).validator!;
    expect(validar(''), isNotNull);
    expect(validar('0'), isNotNull);
    expect(validar('-2'), isNotNull);
    expect(validar('12,5'), isNull);
    expect(validar('12.5'), isNull);
    final selector = find.byType(DropdownButtonFormField<ServicioPreventivo>);
    tester
        .widget<DropdownButtonFormField<ServicioPreventivo>>(selector)
        .onChanged!(serviciosPreventivos.first);
    await tester.pumpAndSettle();
    expect(campo, findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'Revisión preventiva: tres meses calendario, fin de mes y año bisiesto',
    () {
      ControlPreventivo control(String fin, DateTime hoy) =>
          controlesPreventivos(
            {
              'mantenimientos_preventivos': {
                'revision_preventiva': {'fin': fin, 'km': 1000},
              },
            },
            1000,
            hoy,
          ).firstWhere((c) => c.servicio.id == 'revision_preventiva');
      expect(
        control('2026-10-23T10:00:00', DateTime(2027, 1, 21)).alerta,
        false,
      );
      expect(
        control('2026-10-23T10:00:00', DateTime(2027, 1, 22)).detalle,
        contains('Vence mañana'),
      );
      expect(
        control('2026-10-23T10:00:00', DateTime(2027, 1, 23)).detalle,
        contains('Vence hoy'),
      );
      expect(
        control('2026-10-23T10:00:00', DateTime(2027, 1, 24)).detalle,
        contains('Vencido'),
      );
      expect(
        control('2026-01-31T10:00:00', DateTime(2026, 4, 30)).detalle,
        contains('Vence hoy'),
      );
      expect(
        control('2027-11-30T10:00:00', DateTime(2028, 2, 29)).detalle,
        contains('Vence hoy'),
      );
    },
  );

  for (final ancho in [390.0, 1440.0]) {
    testWidgets(
      'Formulario con cuatro campos y servicio preseleccionado $ancho',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: RegistroConductorPage(
                vehiculo: VehiculoConductor(
                  id: 'demo',
                  placa: 'TEST',
                  descripcion: 'Test',
                  km: 1000,
                  datos: {},
                ),
                tipo: 'Mantenimiento preventivo',
                servicioPreventivo: 'limpieza',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Fecha de inicio',
          'Hora de inicio',
          'Fecha fin',
          'Hora fin',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.byType(DropdownButtonFormField<ServicioPreventivo>),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final campo = tester
            .widget<DropdownButtonFormField<ServicioPreventivo>>(
              find.byType(DropdownButtonFormField<ServicioPreventivo>),
            );
        expect(campo.initialValue?.id, 'limpieza');
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Ocho días desde fin y alerta desde el día anterior', () {
    final datos = <String, dynamic>{
      'mantenimientos_preventivos': {
        'limpieza': {'fin': '2026-10-23T18:30:00', 'km': 1000},
      },
    };
    ControlPreventivo control(DateTime hoy) =>
        controlesPreventivos(datos, 1000, hoy).first;
    expect(control(DateTime(2026, 10, 29)).alerta, false);
    expect(control(DateTime(2026, 10, 30)).detalle, contains('mañana'));
    expect(control(DateTime(2026, 10, 31)).detalle, contains('hoy'));
    expect(control(DateTime(2026, 11, 1)).detalle, contains('Vencido'));
  });
  test('Aceite cada 8000 km y servicios sin periodicidad', () {
    final datos = <String, dynamic>{
      'mantenimientos_preventivos': {
        'aceite': {'fin': '2026-10-23T18:30:00', 'km': 1000},
      },
    };
    final antes = controlesPreventivos(datos, 7999, DateTime(2026, 10, 23));
    expect(antes[3].alerta, false);
    expect(
      controlesPreventivos(datos, 8000, DateTime(2026, 10, 23))[3].alerta,
      true,
    );
    expect(
      controlesPreventivos(datos, 9000, DateTime(2026, 10, 23))[3].detalle,
      contains('pendiente'),
    );
    expect(antes[5].alerta, false);
    expect(antes[6].alerta, false);
    expect(antes.first.detalle, contains('Sin registro inicial'));
  });
}
