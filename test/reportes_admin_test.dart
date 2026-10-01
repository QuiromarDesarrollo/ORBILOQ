import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/data/reportes_admin_repository.dart';
import 'package:orbiloq_wms/data/kardex_excel_exportador.dart';
import 'package:orbiloq_wms/features/admin/presentation/reportes_admin_dialog.dart';

class _Reportes extends ReportesAdminRepository {
  int llamadas = 0;
  @override
  Future<FilaReporte> resumen() async {
    llamadas++;
    return {
      'op_activas': 3,
      'op_atrasadas': 1,
      'op_no_conforme': 2,
      'sobrantes_pendientes': 4,
      'unidades_sobrantes': 8
    };
  }

  @override
  Future<List<FilaReporte>> cargar(String tipo) async {
    llamadas++;
    return [
      for (var i = 0; i < 55; i++)
        {
          'registro': 'id$i',
          'fecha': '2026-09-30T13:00:00Z',
          'op': '90001',
          'codigo': 'C1',
          'producto': 'Camiseta',
          'talla': 'M',
          'cliente': 'Cliente A',
          'persona': 'Ana',
          'origen': 'Logística',
          'tipo': 'Reporte',
          'cantidad': 2,
          'causal': 'Tela',
          'contraparte': 'Luis',
          'detalle': 'Nota',
          'datos_crudos': {'id': 'id$i', 'cantidad': 2}
        },
    ];
  }
}

void main() {
  test(
      'Filtros combinados en Bogotá y tendencias no confunden reportes con unidades',
      () {
    final filas = <FilaReporte>[
      {
        'fecha': '2026-10-01T02:00:00Z',
        'op': '90001',
        'persona': 'Ana',
        'cliente': 'A',
        'causal': 'Tela',
        'cantidad': 5
      },
      {
        'fecha': '2026-10-01T06:00:00Z',
        'op': '90001',
        'persona': 'Ana',
        'cliente': 'A',
        'causal': 'Tela',
        'cantidad': 7
      },
      {
        'fecha': '2026-10-01T02:00:00Z',
        'op': '90002',
        'persona': 'Carlos',
        'cliente': 'B',
        'causal': 'Costura',
        'cantidad': 1
      },
    ];
    final f = filtrarReporte(filas,
        op: '90001',
        persona: 'ANA',
        desde: DateTime(2026, 9, 30),
        hasta: DateTime(2026, 9, 30));
    expect(f.length, 1);
    expect(f.first['cantidad'], 5);
    expect(resumirNoConforme(filas, 'causal').first,
        {'grupo': 'Tela', 'reportes': 2, 'unidades': 12});
    expect(resumirNoConforme(filas, 'mes').length, 2);
  });
  test('Excel conserva números y texto literal en hojas de detalle y resumen',
      () {
    final bytes = KardexExcelExportador.generarReporte({
      'Detalle': [
        ['Cantidad', 'Nota'],
        [-3, '=1+1']
      ],
      'Resumen': [
        ['Total'],
        [55]
      ]
    });
    final libro = Excel.decodeBytes(bytes);
    expect(libro.tables.keys, containsAll(['Detalle', 'Resumen']));
    expect(libro['Detalle'].rows[1][0]!.value, IntCellValue(-3));
    expect(libro['Detalle'].rows[1][1]!.value, TextCellValue('=1+1'));
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1440, 900)
  ]) {
    testWidgets('Cuatro reportes adaptables $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Reportes();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            reportesAdminProvider.overrideWithValue(repo)
          ],
          child:
              const MaterialApp(home: Scaffold(body: ReportesAdminDialog()))));
      await tester.pumpAndSettle();
      expect(find.text('OP activas'), findsOneWidget);
      for (final nombre in [
        'Movimientos completos',
        'No Conforme consolidado',
        'Actividad por persona'
      ]) {
        final selector = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text(nombre).last);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('55 registros coincidentes'), findsOneWidget);
        expect(find.text('Página 1 de 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('Cuenta no administradora no consulta ni exporta reportes',
      (tester) async {
    final repo = _Reportes();
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(true),
      reportesAdminProvider.overrideWithValue(repo),
      usuarioSesionProvider.overrideWith((ref) async => const UsuarioSesion(
          numeroUsuario: '1', nombre: 'Ana', rolCuenta: RolCuenta.logistica))
    ], child: const MaterialApp(home: Scaffold(body: ReportesAdminDialog()))));
    await tester.pumpAndSettle();
    expect(repo.llamadas, 0);
    expect(find.text('Acceso exclusivo del administrador.'), findsOneWidget);
  });
}
