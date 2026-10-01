import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../application/providers.dart';
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
          type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
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
      if (mounted) setState(() => _error = e is PostgrestException ? e.message : e is FormatException ? e.message.toString() : 'No se pudo completar la operación: $e');
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
      setState(() =>
          _error = 'La importación requiere conexión a Supabase de pruebas.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final result = await service.importar(_archivo!, _motivo.text.trim(),
          confirmar: confirmar);
      if (!mounted) return;
      if (confirmar) {
        await ref.read(wmsRepositoryProvider).refrescar();
        if (!mounted) return;
        ref.read(kardexPaginaProvider.notifier).ir(0);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Importación completada. Ambas vistas actualizadas.')));
      } else {
        setState(() { _preview = result; _pagina = 0; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preview = null;
          _error = e is PostgrestException ? e.message : e is FormatException ? e.message.toString() : 'No se pudo completar la operación: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_ocupado,
      child: WmsDialogShell(
          title:
              'Importar tabla · ${widget.vista == Rol.produccion ? "Producción" : "Logística"}',
          icon: Icons.upload_file,
          iconColor: Colors.teal,
          canClose: !_ocupado,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'Usa el archivo de «Exportar tabla». Incluye todas las filas, sin filtros ni paginación. Las OP son compartidas: los cambios se reflejan en ambas vistas.'),
            const SizedBox(height: 12),
            const Text(
                'Pendientes, estados y días faltantes se recalculan. Los ajustes se registran sin borrar movimientos ni lotes. Si cambias recibido, despachado o no conforme, indica el estante en «UBICACIÓN DEL AJUSTE».'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _ocupado ? null : _elegir,
                icon: const Icon(Icons.folder_open),
                label: const Text('Seleccionar Excel')),
            if (_nombre != null)
              Text('$_nombre · ${_archivo!.filas.length} filas'),
            TextField(
                controller: _motivo,
                enabled: !_ocupado && _preview == null,
                decoration:
                    const InputDecoration(labelText: 'Motivo del reemplazo')),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SelectableText(_error!,
                      style: const TextStyle(color: Colors.red))),
            if (_ocupado) const LinearProgressIndicator(),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text(
                  'Nuevas: ${_preview!["nuevas"]} · Modificadas: ${_preview!["modificadas"]} · Total del archivo: ${_preview!["total"]}'),
              const Text(
                  'Revisa el detalle. Todavía no se ha guardado ningún cambio.'),
              for (final cambio in (_preview!['cambios'] as List).skip(_pagina * 25).take(25))
                ExpansionTile(
                  title: Text(
                      'Fila ${cambio["fila"]} · OP ${cambio["op"]} · ${cambio["codigo"]} · ${cambio["talla"]}'),
                  children: [
                    for (final key in ExcelKardex.columnas(widget.vista).keys)
                      if (!ExcelKardex.calculadas.contains(key) &&
                          key != 'item_orden_id' &&
                          key != 'ubicacion_ajuste' &&
                          cambio['antes'][key] != cambio['despues'][key])
                        ListTile(
                            dense: true,
                            title:
                                Text(ExcelKardex.columnas(widget.vista)[key]!),
                            subtitle: Text(
                                '${cambio["antes"][key] ?? "—"} → ${cambio["despues"][key] ?? "—"}')),
                  ],
                ),
            ],
            if (_preview != null && (_preview!['cambios'] as List).length > 25)
              Wrap(spacing: 8, children: [
                TextButton(onPressed: _ocupado || _pagina == 0 ? null : () => setState(() => _pagina--), child: const Text('Cambios anteriores')),
                Text('Página ${_pagina+1} de ${((_preview!['cambios'] as List).length+24) ~/ 25}'),
                TextButton(onPressed: _ocupado || (_pagina+1)*25 >= (_preview!['cambios'] as List).length ? null : () => setState(() => _pagina++), child: const Text('Más cambios')),
              ]),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              TextButton(
                  onPressed: _ocupado ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              if (_preview == null)
                FilledButton(
                    onPressed: _ocupado || _archivo == null
                        ? null
                        : () => _ejecutar(false),
                    child: const Text('Revisar reemplazo')),
              if (_preview != null) ...[
                TextButton(
                    onPressed:
                        _ocupado ? null : () => setState(() => _preview = null),
                    child: const Text('Volver')),
                FilledButton(
                    onPressed: _ocupado ? null : () => _ejecutar(true),
                    child: const Text('Confirmar reemplazo de la tabla')),
              ],
            ]),
          ])));
}
