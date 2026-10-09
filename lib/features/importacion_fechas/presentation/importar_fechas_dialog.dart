import '../../../shared/widgets/boton_plantilla_excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/importacion_result.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showImportarFechasDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ImportarFechasDialog());

class ImportarFechasDialog extends ConsumerStatefulWidget {
  const ImportarFechasDialog({super.key});

  @override
  ConsumerState<ImportarFechasDialog> createState() =>
      _ImportarFechasDialogState();
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
    if (!mounted || resultado == null || resultado.files.isEmpty) return;
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
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Esta función necesita conexión a Supabase (la app está en modo de datos de prueba).',
            ),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _msg = null;
      _resumen = null;
    });

    Result<ResumenImportacionFechas> res;
    try {
      res = await importador.importar(
        bytes: bytes,
        nombreArchivo: archivo.name,
      );
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
      await ref.read(wmsRepositoryProvider).refrescar().catchError((Object _) {
        /* El stream informa el fallo de recarga; no repetir lo ya guardado. */
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = ref.watch(importadorFechasProvider) != null;
    return PopScope(
      canPop: !_cargando,
      child: WmsDialogShell(
        title: 'Importar fechas esperadas',
        subtitle:
            'Actualiza las fechas de OP que ya existen. Nunca crea OP nuevas.',
        icon: Icons.event_available,
        iconColor: AppColors.primaryNavy,
        maxWidth: 700,
        mobileCatalog: true,
        canClose: !_cargando,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _archivo == null
                  ? 'Elige un archivo para continuar.'
                  : 'Archivo seleccionado: ${_archivo!.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed:
                      _cargando || !disponible || _archivo?.bytes == null
                          ? null
                          : _importar,
                  icon: const Icon(Icons.upload_outlined, size: 17),
                  label: Text(_cargando ? 'Importando…' : 'Importar fechas'),
                ),
              ],
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                const Text(
                  'Columnas que debe tener el Excel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                BotonPlantillaExcel(
                  tipo: PlantillaExcel.fechas,
                  habilitado: !_cargando,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDCE6EC)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  for (final fila in [
                    ('COLUMNA', 'QUÉ ACTUALIZA'),
                    (
                      'N° DE ORDEN',
                      'Identifica la OP; si no existe, se ignora.',
                    ),
                    ('FECHA PROD', 'Fecha esperada de Producción.'),
                    (
                      'FECHA LOG',
                      'Fecha esperada y días faltantes de Logística.',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 95,
                            child: Text(
                              fila.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fila.$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: const Color(0xFFF4F8F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFAAC1CE)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _cargando || !disponible ? null : _elegirArchivo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 40,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _archivo == null
                            ? Icons.upload_outlined
                            : Icons.description_outlined,
                        size: 30,
                        color: AppColors.primaryNavy,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _archivo?.name ?? 'Selecciona tu archivo .xlsx',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _archivo == null
                            ? 'Elígelo desde tu equipo'
                            : 'Toca para cambiar el archivo',
                        style: const TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!disponible)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Esta función necesita conexión a Supabase. La app está usando datos de prueba.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FeedbackBanner(message: _msg!),
              ),
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
                  itemBuilder:
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${_resumen!.noEncontradas[i]}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
