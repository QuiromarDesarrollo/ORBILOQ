import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../domain/importacion_result.dart';
import 'excel_ordenes_parser.dart';

/// Orquesta la carga de un Excel de Órdenes de Producción:
/// 1) valida y parsea el archivo en el dispositivo,
/// 2) archiva el archivo original en Storage,
/// 3) delega toda la lógica de inserción (insert-only) al RPC de Postgres,
///    que corre en una sola transacción.
class SupabaseImportadorOrdenes {
  SupabaseImportadorOrdenes(this._client);

  final SupabaseClient _client;

  Future<Result<ResumenImportacion>> importar({
    required Uint8List bytes,
    required String nombreArchivo,
    required String usuarioNombre,
  }) async {
    final ExcelOrdenesParseado parseado;
    try {
      parseado = ExcelOrdenesParser.parsear(bytes);
    } on ExcelOrdenesParseException catch (e) {
      return Err<ResumenImportacion>(e.mensaje);
    } catch (e) {
      return Err<ResumenImportacion>('No se pudo interpretar el archivo: $e');
    }

    final storagePath = _rutaStorage(nombreArchivo);

    try {
      await _client.storage.from('documentos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          );
    } on StorageException catch (e) {
      return Err<ResumenImportacion>('No se pudo archivar el Excel original: ${e.message}');
    } catch (e) {
      // Cubre errores de red que no son StorageException (proxies/antivirus
      // que interfieren con la conexión, cortes de conexión, etc.) — sin
      // este catch genérico, un fallo así deja la pantalla "cargando" para
      // siempre sin avisar nada.
      return Err<ResumenImportacion>(
        'No se pudo subir el archivo a Supabase (falla de red). Si tienes un '
        'antivirus con "inspección de conexiones cifradas" (ej. Kaspersky), '
        'intenta desactivarla para este sitio o usa otro navegador. Detalle: $e',
      );
    }

    try {
      final res = await _client.rpc('importar_ordenes_produccion', params: {
        'p_ordenes': parseado.ordenes,
        'p_tallas': parseado.tallas,
        'p_nombre_archivo': nombreArchivo,
        'p_storage_path': storagePath,
        'p_usuario_nombre': usuarioNombre,
      });
      return Ok<ResumenImportacion>(ResumenImportacion.fromJson(res as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      return Err<ResumenImportacion>('Error al importar: ${e.message}');
    } catch (e) {
      return Err<ResumenImportacion>('Error inesperado al importar: $e');
    }
  }

  String _rutaStorage(String nombreArchivo) {
    final sello = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final limpio = nombreArchivo.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    return 'importaciones/$sello-$limpio';
  }
}
