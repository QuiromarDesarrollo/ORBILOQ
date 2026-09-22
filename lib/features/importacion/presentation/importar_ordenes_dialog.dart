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

    final res = await importador.importar(
      bytes: bytes,
      nombreArchivo: archivo.name,
      usuarioNombre: 'Operario Confección 1', // TODO: usuario real cuando exista login
    );

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
