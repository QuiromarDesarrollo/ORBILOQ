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

Future<void> showImportarFechasDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ImportarFechasDialog());

class ImportarFechasDialog extends ConsumerStatefulWidget {
  const ImportarFechasDialog({super.key});

  @override
  ConsumerState<ImportarFechasDialog> createState() => _ImportarFechasDialogState();
}

class _ImportarFechasDialogState extends ConsumerState<ImportarFechasDialog> {
  PlatformFile? _archivo;
  bool _cargando = false;
  FeedbackMessage? _msg;
  ResumenImportacionFechas? _resumen;

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

    final importador = ref.read(importadorFechasProvider);
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

    Result<ResumenImportacionFechas> res;
    try {
      res = await importador.importar(bytes: bytes, nombreArchivo: archivo.name);
    } catch (e) {
      res = Err<ResumenImportacionFechas>('Error inesperado: $e');
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (res) {
        case Ok(:final value):
          _resumen = value;
          _msg = FeedbackMessage.ok(
            '${value.actualizadas} OP actualizadas'
            '${value.noEncontradas.isNotEmpty ? ' · ${value.noEncontradas.length} OP no encontradas (revisa el detalle abajo)' : ''}.',
          );
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });

    if (res is Ok<ResumenImportacionFechas>) {
      // Refresca el kardex para que las fechas se vean de una vez.
      await ref.read(wmsRepositoryProvider).refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = ref.watch(importadorFechasProvider) != null;

    return WmsDialogShell(
      title: 'IMPORTAR FECHAS ESPERADAS',
      icon: Icons.event_available,
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
              'Sube el Excel con las columnas "N° DE ORDEN", "FECHA PROD" y "FECHA LOG". '
              'Solo actualiza las Órdenes de Producción que ya existen en el sistema — '
              'nunca crea órdenes nuevas. "FECHA PROD" alimenta la "Fecha esperada" de '
              'Producción; "FECHA LOG" alimenta la "Fecha esperada" (y "Días faltantes") '
              'de Logística.',
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
            if (_resumen != null && _resumen!.noEncontradas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'OP del Excel que no existen en el sistema (${_resumen!.noEncontradas.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resumen!.noEncontradas.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${_resumen!.noEncontradas[i]}', style: const TextStyle(fontSize: 12)),
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
