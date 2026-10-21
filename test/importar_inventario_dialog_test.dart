import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/inventario_repository.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/inventario/presentation/importar_inventario_dialog.dart';
import 'excel_inventario_test.dart' show archivo, fila;

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
    PlatformFile(name: 'tabla.xlsx', size: bytes.length, bytes: bytes),
  ]);
}

class _Repo implements InventarioRepository {
  final llamadas = <Map<String, dynamic>>[];
  @override
  Future<dynamic> ejecutar(String f, Map<String, dynamic> p) async {
    expect(f, 'inventario_importar_excel');
    llamadas.add(p);
    return {'filas': p['p_filas'], 'unidades': 14, 'repetido': false};
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 850)]) {
    testWidgets('Vista previa y confirmación de entrada Excel en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FilePicker.platform = _Picker(
        archivo([fila(estante: '')], estante: size.width != 390),
      );
      final repo = _Repo();
      Map<String, dynamic>? resultado;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventarioRepositoryProvider.overrideWithValue(repo),
            ubicacionesProvider.overrideWith(
              (ref) async => ['RACK DEFAULT', 'RACK OTRO'],
            ),
            usuarioSesionProvider.overrideWith(
              (ref) async => const UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Bodega',
                rolCuenta: RolCuenta.logistica,
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Abrir'),
                      onPressed: () async {
                        resultado = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => const ImportarInventarioDialog(),
                        );
                      },
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Seleccionar Excel'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Seleccionar Excel'));
        final limite = DateTime.now().add(const Duration(seconds: 10));
        while (repo.llamadas.isEmpty && DateTime.now().isBefore(limite)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(repo.llamadas.single['p_confirmar'], false);
      expect(
        (repo.llamadas.single['p_filas'] as List).single['estante'],
        'RACK DEFAULT',
      );
      expect(find.textContaining('14 unidades por sumar'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirmar entrada de inventario'));
      await tester.tap(find.text('Confirmar entrada de inventario'));
      await tester.pumpAndSettle();
      expect(repo.llamadas.last['p_confirmar'], true);
      expect(repo.llamadas.last['p_filas'], repo.llamadas.first['p_filas']);
      expect(
        repo.llamadas.last['p_solicitud'],
        repo.llamadas.first['p_solicitud'],
      );
      expect(resultado?['unidades'], 14);
      expect(tester.takeException(), isNull);
    });
  }
}
