import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_recepcion_tabla.dart';

const _rows = <Map<String, dynamic>>[
  {
    'pedido': '4001273702',
    'proveedor': 'Proveedor de ejemplo',
    'pendiente': 2,
    'esperado': 1452,
    'recibido': 1450,
    'horario': '8:00 AM A 4:00 PM',
    'novedad': 'RECIBIDO PARCIAL',
    'requerido': 1460,
    'saldo': -10,
  },
  {
    'pedido': 'APORTE',
    'proveedor': 'Otro proveedor con un nombre extenso para revisar el ajuste',
    'pendiente': 0,
    'esperado': 20,
    'recibido': 20,
    'horario': '',
    'novedad': '',
    'requerido': null,
    'saldo': null,
  },
];

const _options = <String, List<String>>{
  'pedido': ['4001273702', 'APORTE', 'OC FUERA DE ESTA PÁGINA'],
  'pendiente': ['0', '2'],
  'esperado': ['20', '1452'],
  'recibido': ['20', '1450'],
  'horario': ['', '8:00 AM A 4:00 PM'],
  'novedad': ['', 'RECIBIDO PARCIAL'],
  'saldo': ['', '-10'],
};

Future<void> _show(
  WidgetTester tester, {
  double width = 1440,
  Map<String, Set<String>> filters = const {},
  ValueChanged<Map<String, Set<String>>>? changed,
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
          child: MasivaRecepcionTabla(
            filas: _rows,
            filtros: filters,
            opciones: _options,
            onFiltrosChanged: changed ?? (_) {},
            onAbrir: open ?? (_) {},
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
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets(
    'Se adapta a móvil, tablet y escritorio sin fechas ni desbordes',
    (tester) async {
      for (final width in [320.0, 390.0, 800.0, 1440.0]) {
        await _show(tester, width: width);
        expect(tester.takeException(), isNull, reason: 'Ancho $width');
        expect(find.text('4001273702'), findsOneWidget);
        expect(find.text('-10'), findsOneWidget);
        expect(find.text('Por cruzar'), findsOneWidget);
        expect(find.textContaining('FECHA'), findsNothing);
        expect(find.textContaining('CUMPLIMIENTO'), findsNothing);
        if (width >= 700) {
          for (final key in _options.keys) {
            expect(find.byKey(ValueKey('masiva-filter-$key')), findsOneWidget);
          }
        } else {
          expect(find.text('Filtrar columnas'), findsOneWidget);
        }
      }
    },
  );

  testWidgets('Filtro usa las opciones globales y conserva los otros filtros', (
    tester,
  ) async {
    Map<String, Set<String>>? result;
    final original = <String, Set<String>>{
      'recibido': {'20'},
    };
    await _show(tester, filters: original, changed: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('masiva-filter-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OC FUERA DE ESTA PÁGINA'));
    await tester.tap(find.text('APLICAR FILTRO'));
    await tester.pumpAndSettle();
    expect(result, {
      'recibido': {'20'},
      'pedido': {'OC FUERA DE ESTA PÁGINA'},
    });
    expect(original, {
      'recibido': {'20'},
    });
    // El componente no oculta filas de esta página: consulta externa obligatoria.
    expect(find.text('4001273702'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Móvil permite filtrar cada columna y abrir sus prendas', (
    tester,
  ) async {
    Map<String, dynamic>? opened;
    Map<String, Set<String>>? result;
    await _show(
      tester,
      width: 390,
      open: (value) => opened = value,
      changed: (value) => result = value,
    );
    await tester.tap(find.text('Filtrar columnas'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(7));
    await tester.tap(find.text('SALDO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '-10'));
    await tester.tap(find.text('APLICAR FILTRO'));
    await tester.pumpAndSettle();
    expect(result, {
      'saldo': {'-10'},
    });
    await tester.tap(find.text('Ver prendas').first);
    expect(opened, _rows.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Limpiar filtros y cancelar respetan el contrato', (
    tester,
  ) async {
    Map<String, Set<String>>? result;
    await _show(
      tester,
      filters: {
        'pedido': {'APORTE'},
      },
      changed: (value) => result = value,
    );
    await tester.tap(find.byKey(const ValueKey('masiva-filter-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Limpiar filtros'));
    expect(result, isEmpty);
  });
}
