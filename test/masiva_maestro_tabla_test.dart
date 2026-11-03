import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_maestro_tabla.dart';

const _listRows = <Map<String, dynamic>>[
  {
    'lista': '0012',
    'cliente': 'Cliente con un nombre extenso para comprobar la distribución',
    'estado': 'EMPAQUE PARCIAL',
    'ciudad': 'Bogotá',
    'sede': 'Oficina principal',
    'direccion': 'Carrera 80 número 20-01',
    'responsable': 'Ana de ejemplo',
    'total_piezas': 3,
    'cajas': 2,
    'bolsas': 1,
    'peso_total': 12.5,
    'volumen': .125,
    'kits_totales': 1500,
    'kits_validados': 1,
    'kits_empacados': 0,
    'ultima_validacion': '2026-10-27T15:45:00Z',
    'fecha_generado': '2026-10-28T15:45:00Z',
    'fecha_despacho': null,
    'fecha_recepcion': null,
    'transportadora': null,
    'placa_guia': null,
    'novedades': 'Pendiente una prenda',
  },
  {'lista': '0013', 'cliente': 'Otro cliente', 'estado': 'POR EMPACAR'},
];
const _baseRows = <Map<String, dynamic>>[
  {
    'id': 'line-1',
    'kit_id': 'kit-1',
    'fecha_carga': '2026-10-27T15:45:00Z',
    'cliente': 'Cliente de ejemplo',
    'lista': '0012',
    'numero_persona': '0002',
    'cedula': '001234567',
    'nombre': 'Una persona con un nombre largo para comprobar el ajuste',
    'sku': '001-ABC',
    'descripcion': 'Camisa de trabajo manga larga de dotación institucional',
    'cantidad': 2,
    'validado': 0,
    'estado': 'PENDIENTE',
    'motivo_modificacion': 'Talla corregida por el administrador',
  },
];

Future<void> _show(
  WidgetTester tester, {
  double width = 1440,
  bool base = false,
  Map<String, Set<String>> filters = const {},
  Set<String> selection = const {},
  ValueChanged<Map<String, Set<String>>>? changed,
  ValueChanged<Set<String>>? selected,
  ValueChanged<Map<String, dynamic>>? open,
  bool loading = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: MasivaMaestroTabla(
            base: base,
            filas: base ? _baseRows : _listRows,
            filtros: filters,
            opciones: const {
              'lista': ['0012', '0013', '0099'],
              'cliente': ['Cliente global'],
            },
            onFiltrosChanged: changed ?? (_) {},
            onAbrir: open ?? (_) {},
            seleccionadas: selection,
            onSeleccionChanged: selected,
            cargando: loading,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('Listado y base funcionan en móvil y escritorio sin desbordes', (
    tester,
  ) async {
    for (final base in [false, true]) {
      for (final width in [390.0, 1440.0]) {
        await _show(tester, width: width, base: base, selected: (_) {});
        expect(
          tester.takeException(),
          isNull,
          reason: 'Base $base, ancho $width',
        );
        expect(
          find.text(base ? 'Base de datos maestra' : 'Listado maestro'),
          findsOneWidget,
        );
        if (width >= 700) {
          for (final column
              in base ? masivaBaseColumnas : masivaListadoColumnas) {
            expect(
              find.byKey(ValueKey('maestro-filter-${column.key}')),
              findsOneWidget,
            );
          }
          expect(find.text('27/10/2026 10:45'), findsOneWidget);
          if (!base) {
            expect(find.text('28/10/2026 10:45'), findsOneWidget);
          }
        } else {
          expect(find.text('Filtrar columnas'), findsOneWidget);
        }
        if (base) {
          expect(find.byType(Checkbox), findsNothing);
        }
      }
    }
  });

  testWidgets(
    'Filtros usan facetas globales sin alterar selección previa ni ocultar filas locales',
    (tester) async {
      Map<String, Set<String>>? result;
      final original = <String, Set<String>>{
        'estado': {'EMPAQUE PARCIAL'},
      };
      await _show(
        tester,
        filters: original,
        changed: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('maestro-filter-lista')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '0099'));
      await tester.tap(find.text('APLICAR FILTRO'));
      await tester.pumpAndSettle();
      expect(result, {
        'estado': {'EMPAQUE PARCIAL'},
        'lista': {'0099'},
      });
      expect(original, {
        'estado': {'EMPAQUE PARCIAL'},
      });
      expect(find.text('0012'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Seleccionar página conserva otras páginas y selecciona por lista',
    (tester) async {
      Set<String>? result;
      await _show(
        tester,
        selection: {'0099'},
        selected: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('maestro-select-page')));
      expect(result, {'0099', '0012', '0013'});
      await _show(
        tester,
        selection: result!,
        selected: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('maestro-select-page')));
      expect(result, {'0099'});
      await _show(
        tester,
        selection: result!,
        selected: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('maestro-select-0012')));
      expect(result, {'0099', '0012'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Móvil expande todas las columnas y conserva códigos y ceros', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await _show(tester, width: 390, base: true, open: (row) => result = row);
    await tester.tap(find.text('Ver todos los datos'));
    await tester.pumpAndSettle();
    expect(find.text('001234567'), findsOneWidget);
    expect(find.text('001-ABC'), findsOneWidget);
    expect(find.text('0002'), findsNWidgets(2));
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Motivo de modificación'), findsOneWidget);
    await tester.ensureVisible(find.text('Abrir kit'));
    await tester.tap(find.text('Abrir kit'));
    expect(result, _baseRows.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Móvil filtra columnas y la carga bloquea callbacks', (
    tester,
  ) async {
    Map<String, Set<String>>? result;
    await _show(tester, width: 390, changed: (value) => result = value);
    await tester.tap(find.text('Filtrar columnas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cliente global'));
    await tester.tap(find.text('APLICAR FILTRO'));
    await tester.pumpAndSettle();
    expect(result, {
      'cliente': {'Cliente global'},
    });
    var invoked = false;
    await _show(
      tester,
      loading: true,
      selected: (_) => invoked = true,
      changed: (_) => invoked = true,
      open: (_) => invoked = true,
    );
    await tester.tap(find.byKey(const ValueKey('maestro-select-page')));
    await tester.tap(find.byKey(const ValueKey('maestro-filter-lista')));
    expect(invoked, isFalse);
    expect(tester.takeException(), isNull);
  });
}
