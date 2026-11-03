import 'dart:convert';
import 'dart:io';
import 'package:orbiloq_wms/features/masiva/masiva_importador_parser.dart';

/// Prepara únicamente un archivo local de metadatos. No abre conexiones ni
/// modifica operaciones, validaciones o existencias de Supabase.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Uso: dart run tools/masiva_preparar_enriquecimiento.dart origen.xlsx destino.json',
    );
    exitCode = 64;
    return;
  }
  final input = File(args[0]);
  final result = parsearMasivaExcel(
    await input.readAsBytes(),
    tipo: 'personal',
  );
  if (!result.valida) {
    stderr.writeln(
      'No se preparó el enriquecimiento: ${result.errores.length} errores de validación.',
    );
    exitCode = 1;
    return;
  }
  final output = File(args[1]);
  await output.parent.create(recursive: true);
  final resumen = {
    'filas': result.filas.length,
    'unidades': result.unidades,
    'kits': result.kits,
    'listas': result.listas,
  };
  await output.writeAsString(
    jsonEncode({
      'formato_version': 1,
      'archivo': input.uri.pathSegments.last,
      'tipo': 'personal',
      'resumen': resumen,
      'filas': result.filas,
    }),
    flush: true,
  );
  stdout.writeln(jsonEncode({...resumen, 'bytes': await output.length()}));
}
