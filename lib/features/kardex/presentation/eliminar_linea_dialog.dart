import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../domain/models.dart';
import '../../../domain/edicion_admin.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showWmsEliminarLinea(BuildContext context, ItemKardex item) =>
    showWmsDialog<void>(context, (_) => EliminarLineaDialog(item: item));

class EliminarLineaDialog extends ConsumerStatefulWidget {
  const EliminarLineaDialog({super.key, required this.item});
  final ItemKardex item;
  @override
  ConsumerState<EliminarLineaDialog> createState() => _EliminarLineaState();
}

class _EliminarLineaState extends ConsumerState<EliminarLineaDialog> {
  final _motivo = TextEditingController();
  ContextoEdicionAdmin? _contexto;
  String? _error;
  bool _ocupado = false;
  bool get _esAdmin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      if (!_esAdmin) throw Exception('Acceso exclusivo del administrador.');
      final ctx = await ref
          .read(wmsRepositoryProvider)
          .cargarEdicionAdmin(widget.item.id);
      if (mounted) setState(() => _contexto = ctx);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la confirmación: $e');
      }
    }
  }

  Future<void> _confirmar() async {
    if (_ocupado || _contexto == null) return;
    if (!_esAdmin || _motivo.text.trim().isEmpty) {
      setState(() => _error = !_esAdmin
          ? 'Acceso exclusivo del administrador.'
          : 'Indica el motivo del borrado.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final result = await ref.read(wmsRepositoryProvider).eliminarLineaAdmin(
          widget.item.id, _contexto!.version, _motivo.text.trim());
      if (!mounted) return;
      if (result case Err(:final message)) {
        setState(() {
          _error = message;
          _ocupado = false;
        });
        return;
      }
      ref.read(kardexPaginaProvider.notifier).ir(0);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Fila ocultada en ambas vistas. Historial y existencias conservados.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error =
              'No se pudo verificar el borrado. Actualiza antes de reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_ocupado,
        child: WmsDialogShell(
            title: 'Borrar fila · OP ${widget.item.item.op}',
            icon: Icons.delete_outline,
            iconColor: Colors.red,
            maxWidth: 600,
            canClose: !_ocupado,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      '${widget.item.item.descripcion} · ${widget.item.item.codigo} · Talla ${widget.item.item.talla}'),
                  const SizedBox(height: 16),
                  const Text(
                      '¿Confirmas que quieres borrar esta línea de las tablas de Producción y Logística?'),
                  const SizedBox(height: 8),
                  const Text(
                      'Se ocultará solo este producto y talla, no toda la OP. Se conservarán los datos y el historial. Esta acción no anula entregas, recepciones, despachos ni existencias.'),
                  if (_contexto != null)
                    Text(
                        'Recibido: ${_contexto!.valores['recibido']} · Despachado: ${_contexto!.valores['despachado']}'),
                  if (_contexto == null && _error == null)
                    const WmsLoadingStrip(),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _motivo,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(
                          labelText: 'Motivo del borrado')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 20),
                  Wrap(spacing: 12, children: [
                    TextButton(
                        onPressed:
                            _ocupado ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed:
                            _ocupado || _contexto == null ? null : _confirmar,
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        child: Text(
                            _ocupado ? 'Guardando…' : 'Confirmar borrado')),
                  ]),
                ])),
      );
}
