import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../../shared/widgets/boton_plantilla_excel.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../application/auth_providers.dart';
import '../../../data/excel_kardex.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showImportarKardexDialog(BuildContext context, Rol vista) =>
    showWmsDialog<void>(context, (_) => ImportarKardexDialog(vista: vista));

class ImportarKardexDialog extends ConsumerStatefulWidget {
  const ImportarKardexDialog({super.key, required this.vista});
  final Rol vista;
  @override
  ConsumerState<ImportarKardexDialog> createState() => _ImportarKardexState();
}

class _ImportarKardexState extends ConsumerState<ImportarKardexDialog> {
  final _motivo = TextEditingController();
  ArchivoKardex? _archivo;
  Map<String, dynamic>? _preview;
  String? _nombre, _error;
  bool _ocupado = false;
  int _pagina = 0;
  bool get _admin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    if (!_admin || _ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _preview = null;
      _archivo = null;
      _nombre = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        throw const FormatException('No se pudo leer el archivo.');
      }
      final archivo = ExcelKardex.leer(file.bytes!, widget.vista);
      setState(() {
        _archivo = archivo;
        _nombre = file.name;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : e is FormatException
                      ? e.message.toString()
                      : 'No se pudo completar la operación: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _ejecutar(bool confirmar) async {
    if (!_admin || _ocupado || _archivo == null) return;
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Indica el motivo del reemplazo.');
      return;
    }
    final service = ref.read(importadorKardexProvider);
    if (service == null) {
      setState(
        () =>
            _error = 'La importación requiere conexión a Supabase de pruebas.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final result = await service.importar(
        _archivo!,
        _motivo.text.trim(),
        confirmar: confirmar,
      );
      if (!mounted) return;
      if (confirmar) {
        await ref.read(wmsRepositoryProvider).refrescar().catchError((
          Object _,
        ) {
          /* El stream informa el fallo de recarga; no repetir lo ya guardado. */
        });
        if (!mounted) return;
        ref.read(kardexPaginaProvider.notifier).ir(0);
        Navigator.pop(context);
        mostrarAvisoSnack(
          context,
          const SnackBar(
            content: Text('Importación guardada correctamente.'),
          ),
          tipo: TipoAviso.exito,
        );
      } else {
        setState(() {
          _preview = result;
          _pagina = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preview = null;
          _error =
              e is PostgrestException
                  ? e.message
                  : e is FormatException
                  ? e.message.toString()
                  : 'No se pudo completar la operación: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _paso(int numero, String titulo, Widget contenido) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.primaryNavy,
          child: Text(
            '$numero',
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              contenido,
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: WmsDialogShell(
      title:
          'Importar tabla de ${widget.vista == Rol.produccion ? "Producción" : "Logística"}',
      subtitle: 'Actualiza muchas OP a la vez desde un Excel.',
      icon: Icons.upload_file_outlined,
      iconColor: Colors.teal,
      maxWidth: 760,
      mobileCatalog: true,
      canClose: !_ocupado,
      footer: AnimatedBuilder(
        animation: _motivo,
        builder:
            (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _preview != null
                      ? 'Revisa el detalle antes de confirmar.'
                      : _archivo == null
                      ? 'Elige un archivo para continuar.'
                      : _motivo.text.trim().isEmpty
                      ? 'Escribe el motivo para continuar.'
                      : 'Archivo listo para revisar.',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _ocupado ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    if (_preview != null)
                      TextButton(
                        onPressed:
                            _ocupado
                                ? null
                                : () => setState(() => _preview = null),
                        child: const Text('Volver'),
                      ),
                    FilledButton(
                      onPressed:
                          !_admin ||
                                  _ocupado ||
                                  _archivo == null ||
                                  _motivo.text.trim().isEmpty
                              ? null
                              : () => _ejecutar(_preview != null),
                      child: Text(
                        _preview == null
                            ? 'Revisar cambios'
                            : 'Confirmar reemplazo de la tabla',
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _paso(
            1,
            'Descarga la plantilla',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trae todas las filas actuales, sin filtros. También sirve el archivo de «Exportar tabla».',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 6),
                BotonPlantillaExcel(
                  nombre: 'kardex_${widget.vista.name}',
                  habilitado:
                      _admin &&
                      !_ocupado &&
                      ref.watch(importadorKardexProvider) != null,
                  generar:
                      () async => ExcelKardex.generar(
                        await ref
                            .read(importadorKardexProvider)!
                            .exportar(widget.vista),
                      ),
                ),
              ],
            ),
          ),
          _paso(
            2,
            'Sube el archivo editado',
            Material(
              color:
                  _archivo == null
                      ? const Color(0xFFF4F8F9)
                      : const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: !_admin || _ocupado ? null : _elegir,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombre ?? 'Seleccionar archivo .xlsx',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _archivo == null
                                  ? 'Elige el Excel desde tu equipo'
                                  : '${_archivo!.filas.length} filas · Archivo listo para revisar',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _archivo == null ? 'Elegir' : 'Cambiar',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _paso(
            3,
            'Motivo del reemplazo *',
            TextField(
              controller: _motivo,
              enabled: !_ocupado && _preview == null,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Ej.: corrección de cantidades del cierre de septiembre',
                helperText: 'Queda en la auditoría junto con tu nombre.',
                helperMaxLines: 2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qué pasa al importar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                SizedBox(height: 8),
                Text(
                  '✓ Los cambios se ven en Producción y Logística: las OP son compartidas.\n✓ Pendientes, estados y días faltantes se recalculan.\n✓ No se borran movimientos ni lotes; cada ajuste queda registrado.',
                  style: TextStyle(fontSize: 12, height: 1.7),
                ),
                SizedBox(height: 8),
                Text(
                  'Si cambias recibido, despachado o no conforme, escribe el estante en «UBICACIÓN DEL AJUSTE».',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AvisoFormulario(_error!),
            ),
          if (_ocupado) const WmsLoadingStrip(),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Text(
              'Nuevas: ${_preview!["nuevas"]} · Modificadas: ${_preview!["modificadas"]} · Total del archivo: ${_preview!["total"]}',
            ),
            const Text(
              'Revisa el detalle. Todavía no se ha guardado ningún cambio.',
            ),
            for (final cambio in (_preview!['cambios'] as List)
                .skip(_pagina * 25)
                .take(25))
              ExpansionTile(
                title: Text(
                  'Fila ${cambio["fila"]} · OP ${cambio["op"]} · ${cambio["codigo"]} · ${cambio["talla"]}',
                ),
                children: [
                  for (final key in ExcelKardex.columnas(widget.vista).keys)
                    if (!ExcelKardex.calculadas.contains(key) &&
                        key != 'item_orden_id' &&
                        key != 'ubicacion_ajuste' &&
                        cambio['antes'][key] != cambio['despues'][key])
                      ListTile(
                        dense: true,
                        title: Text(ExcelKardex.columnas(widget.vista)[key]!),
                        subtitle: Text(
                          '${cambio["antes"][key] ?? "—"} → ${cambio["despues"][key] ?? "—"}',
                        ),
                      ),
                ],
              ),
          ],
          if (_preview != null && (_preview!['cambios'] as List).length > 25)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed:
                      _ocupado || _pagina == 0
                          ? null
                          : () => setState(() => _pagina--),
                  child: const Text('Cambios anteriores'),
                ),
                Text(
                  'Página ${_pagina + 1} de ${((_preview!['cambios'] as List).length + 24) ~/ 25}',
                ),
                TextButton(
                  onPressed:
                      _ocupado ||
                              (_pagina + 1) * 25 >=
                                  (_preview!['cambios'] as List).length
                          ? null
                          : () => setState(() => _pagina++),
                  child: const Text('Más cambios'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
