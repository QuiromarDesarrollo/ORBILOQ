#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - La app nunca debe quedarse 'cargando' sin avisar (v9)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_no_colgar_v9.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando blindaje contra errores de red no atrapados..."

echo "  - lib/data/supabase_importador_ordenes.dart"
mkdir -p "$(dirname 'lib/data/supabase_importador_ordenes.dart')"
cat > 'lib/data/supabase_importador_ordenes.dart' << 'ORBILOQ_EOF'
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
ORBILOQ_EOF

echo "  - lib/features/importacion/presentation/importar_ordenes_dialog.dart"
mkdir -p "$(dirname 'lib/features/importacion/presentation/importar_ordenes_dialog.dart')"
cat > 'lib/features/importacion/presentation/importar_ordenes_dialog.dart' << 'ORBILOQ_EOF'
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/importacion_result.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showImportarOrdenesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ImportarOrdenesDialog());

class ImportarOrdenesDialog extends ConsumerStatefulWidget {
  const ImportarOrdenesDialog({super.key});

  @override
  ConsumerState<ImportarOrdenesDialog> createState() => _ImportarOrdenesDialogState();
}

class _ImportarOrdenesDialogState extends ConsumerState<ImportarOrdenesDialog> {
  PlatformFile? _archivo;
  bool _cargando = false;
  FeedbackMessage? _msg;
  ResumenImportacion? _resumen;

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;
    setState(() {
      _archivo = resultado.files.single;
      _msg = null;
      _resumen = null;
    });
  }

  Future<void> _importar() async {
    final archivo = _archivo;
    final bytes = archivo?.bytes;
    if (archivo == null || bytes == null) return;

    final importador = ref.read(importadorOrdenesProvider);
    if (importador == null) {
      setState(() => _msg = const FeedbackMessage.error(
            'Esta función necesita conexión a Supabase (la app está en modo de datos de prueba).',
          ));
      return;
    }

    setState(() {
      _cargando = true;
      _msg = null;
      _resumen = null;
    });

    Result<ResumenImportacion> res;
    try {
      res = await importador.importar(
        bytes: bytes,
        nombreArchivo: archivo.name,
        usuarioNombre: 'Operario Confección 1', // TODO: usuario real cuando exista login
      );
    } catch (e) {
      // Red de seguridad final: cualquier error no previsto (de red, del
      // parser, lo que sea) termina aquí como mensaje, nunca como una
      // pantalla de "cargando" que no avanza.
      res = Err<ResumenImportacion>('Error inesperado: $e');
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (res) {
        case Ok(:final value):
          _resumen = value;
          _msg = FeedbackMessage.ok(
            '${value.opsCreadas} OP nuevas creadas · ${value.opsOmitidas} ya existían (omitidas) · '
            '${value.lineasTallasCreadas} líneas de tallas cargadas'
            '${value.tuvoProblemas ? ' · revisa los detalles abajo' : ''}.',
          );
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });

    if (res is Ok<ResumenImportacion>) {
      // Refresca el kardex para que las OP recién creadas aparezcan de una vez.
      await ref.read(wmsRepositoryProvider).refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = ref.watch(importadorOrdenesProvider) != null;

    return WmsDialogShell(
      title: 'IMPORTAR ÓRDENES DE PRODUCCIÓN',
      icon: Icons.upload_file,
      iconColor: AppColors.primaryNavy,
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!disponible)
            const FeedbackBanner(
              message: FeedbackMessage.error(
                'Esta función necesita conexión a Supabase. Ahora mismo la app está '
                'usando datos de prueba en memoria.',
              ),
            )
          else ...[
            const Text(
              'Sube el Excel exportado del ERP en formato .xlsx (hojas "Orden" y '
              '"Tallas"). Las Órdenes de Producción que ya existan en el sistema se '
              'omiten automáticamente — nunca se sobrescriben.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cargando ? null : _elegirArchivo,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_archivo?.name ?? 'Seleccionar archivo .xlsx'),
                  ),
                ),
                const SizedBox(width: 10),
                ActionButton(
                  icon: Icons.cloud_upload,
                  label: 'IMPORTAR',
                  color: AppColors.actionGreen,
                  busy: _cargando,
                  onPressed: _archivo == null ? null : _importar,
                ),
              ],
            ),
            if (_msg != null) ...[
              const SizedBox(height: 16),
              FeedbackBanner(message: _msg!),
            ],
            if (_resumen != null && _resumen!.tuvoProblemas) ...[
              const SizedBox(height: 12),
              Text(
                'Detalle'
                '${_resumen!.filasInvalidas > 0 ? ' · ${_resumen!.filasInvalidas} filas sin OP válida' : ''}'
                '${_resumen!.advertencias.isNotEmpty ? ' · ${_resumen!.advertencias.length} advertencias de cantidad' : ''}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (_resumen!.advertencias.isEmpty)
                const Text(
                  'No hay advertencias de cantidad para mostrar, pero revisa el mensaje '
                  'de filas sin OP válida arriba — probablemente el archivo no tiene el '
                  'formato de columnas esperado.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _resumen!.advertencias.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${_resumen!.advertencias[i]}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
