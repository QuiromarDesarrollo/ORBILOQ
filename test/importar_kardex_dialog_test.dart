import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/data/excel_kardex.dart';
import 'package:orbiloq_wms/data/supabase_importador_kardex.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/importacion/presentation/importar_kardex_dialog.dart';

class _Picker extends FilePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  @override
  Future<FilePickerResult?> pickFiles(
          {String? dialogTitle,
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
          bool readSequential = false}) async =>
      FilePickerResult(
          [PlatformFile(name: 'tabla.xlsx', size: bytes.length, bytes: bytes)]);
}

class _Servicio implements SupabaseImportadorKardex {
  @override
  SupabaseClient get client => throw UnimplementedError();
  @override
  Future<ArchivoKardex> exportar(Rol vista) => throw UnimplementedError();
  final llamadas = <bool>[];
  @override
  Future<Map<String, dynamic>> importar(ArchivoKardex archivo, String motivo,
      {required bool confirmar}) async {
    llamadas.add(confirmar);
    return {
      'nuevas': 0,
      'modificadas': 1,
      'total': 1,
      'guardado': confirmar,
      'cambios': <dynamic>[]
    };
  }
}

void main() {
  testWidgets('seleccionar y revisar no guarda; solo confirmar aplica',
      (tester) async {
    final service = _Servicio();
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    FilePicker.platform =
        _Picker(ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', [
      {
        'item_orden_id': 'id',
        'numero_op': '1',
        'descripcion': 'Producto',
        'codigo': '001',
        'talla': 'M',
        'cliente': 'Cliente',
        'oc': '',
        'observacion_op': '',
        'cantidad_pedida': 10,
        'producido': 2,
        'pendiente_reproceso': 0,
        'fecha_ultima_entrega': null,
        'fecha_esperada_produccion': null,
        'ubicacion_ajuste': ''
      }
    ])));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
          importadorKardexProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () =>
                            showImportarKardexDialog(context, Rol.produccion),
                        child: const Text('Abrir')))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar Excel'));
    await tester.pumpAndSettle();
    expect(service.llamadas, isEmpty);
    await tester.enterText(find.byType(TextField), 'Corrección general');
    await tester.tap(find.text('Revisar reemplazo'));
    await tester.pumpAndSettle();
    expect(service.llamadas, [false]);
    await tester.ensureVisible(find.text('Confirmar reemplazo de la tabla'));
    await tester.tap(find.text('Confirmar reemplazo de la tabla'));
    await tester.pumpAndSettle();
    expect(service.llamadas, [false, true]);
    expect(find.text('Importación completada. Ambas vistas actualizadas.'),
        findsOneWidget);
  });
}
