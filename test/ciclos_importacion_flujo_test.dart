import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/application/ciclos_providers.dart';
import 'package:orbiloq_wms/application/dashboard_acceso.dart';
import 'package:orbiloq_wms/data/ciclos_repository.dart';
import 'package:orbiloq_wms/data/excel_ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_page.dart';

class _Picker extends FilePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'historico.xlsx', size: bytes.length, bytes: bytes),
  ]);
}

class _Repo extends CiclosRepository {
  _Repo(this.fallaRecarga)
    : super(
        SupabaseClient(
          'http://localhost',
          'prueba',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final bool fallaRecarga;
  int guardados = 0, lecturas = 0;
  @override
  Future<Map<String, dynamic>> importar(
    List<Map<String, dynamic>> filas,
    String revision,
    bool confirmar,
    String archivo,
  ) async {
    if (confirmar) guardados++;
    return {
      'total': filas.length,
      'nuevas': 1,
      'actualizadas': 0,
      'fechas_borradas': 0,
    };
  }

  @override
  Future<DatosCiclos> cargar() async {
    lecturas++;
    if (guardados > 0 && fallaRecarga) {
      throw StateError('Servidor no disponible');
    }
    return DatosCiclos([], [], DateTime.utc(2026, 10, 14), '$guardados');
  }
}

void main() {
  setUpAll(() => FilePicker.platform = _Picker(Uint8List(0)));
  for (final falla in [false, true]) {
    testWidgets('Guardado y recarga: falla=$falla', (tester) async {
      final libro = Excel.createExcel();
      libro['Sheet1'].appendRow([
        for (final c in ExcelCiclos.columnas) TextCellValue(c),
      ]);
      libro['Sheet1'].appendRow([
        TextCellValue('OP-1'),
        TextCellValue('Cliente'),
        IntCellValue(1),
        for (var i = 0; i < 8; i++) TextCellValue('2026-01-01'),
      ]);
      final anterior = FilePicker.platform;
      FilePicker.platform = _Picker(Uint8List.fromList(libro.encode()!));
      addTearDown(() => FilePicker.platform = anterior);
      final repo = _Repo(falla);
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardAccesoProvider.overrideWithValue(('1', RolCuenta.admin)),
            ciclosRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: CiclosPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar históricos Excel'));
      for (
        var n = 0;
        n < 30 && find.text('Confirmar importación').evaluate().isEmpty;
        n++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Confirmar importación'), findsOneWidget);
      expect(repo.guardados, 0);
      await tester.tap(find.text('Confirmar importación'));
      await tester.pumpAndSettle();
      expect(repo.guardados, 1);
      expect(repo.lecturas, 2);
      expect(
        find.textContaining(
          falla
              ? 'se guardaron, pero no se pudo recargar'
              : 'Importación completada: 1 OP',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
