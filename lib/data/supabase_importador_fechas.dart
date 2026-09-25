import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../domain/importacion_result.dart';
import 'excel_fechas_parser.dart';

/// Orquesta la carga del Excel de fechas esperadas: parsea el archivo y
/// delega la actualización (solo OP existentes) al RPC de Postgres.
class SupabaseImportadorFechas {
  SupabaseImportadorFechas(this._client);

  final SupabaseClient _client;

  Future<Result<ResumenImportacionFechas>> importar({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final List<FilaFechaEsperada> filas;
    try {
      filas = ExcelFechasParser.parsear(bytes);
    } on ExcelFechasParseException catch (e) {
      return Err<ResumenImportacionFechas>(e.mensaje);
    } catch (e) {
      return Err<ResumenImportacionFechas>('No se pudo interpretar el archivo: $e');
    }

    try {
      final res = await _client.rpc('importar_fechas_esperadas', params: {'p_filas': filas});
      return Ok<ResumenImportacionFechas>(ResumenImportacionFechas.fromJson(res as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      return Err<ResumenImportacionFechas>('Error al importar: ${e.message}');
    } catch (e) {
      return Err<ResumenImportacionFechas>('Error inesperado al importar: $e');
    }
  }
}
