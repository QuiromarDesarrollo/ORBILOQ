import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers.dart';
import '../../../application/auth_providers.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_alert.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../shared/widgets/wms_loader.dart';

class CambiarContrasenaDialog extends ConsumerStatefulWidget {
  const CambiarContrasenaDialog({
    super.key,
    required this.usuarioId,
    required this.nombre,
  });
  final String usuarioId, nombre;
  @override
  ConsumerState<CambiarContrasenaDialog> createState() =>
      _CambiarContrasenaState();
}

class _CambiarContrasenaState extends ConsumerState<CambiarContrasenaDialog> {
  final _form = GlobalKey<FormState>();
  final _clave = TextEditingController(),
      _confirmacion = TextEditingController();
  bool _ocupado = false, _visible = false;
  bool get _admin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.tieneRol(RolCuenta.admin) == true;
  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_ocupado || !_admin || !_form.currentState!.validate()) return;
    final confirmar = await confirmarAviso(
      context,
      'Se establecerá una nueva contraseña de acceso para ${widget.nombre}.',
      titulo: 'Cambiar contraseña',
      confirmar: 'Cambiar contraseña',
    );
    if (!confirmar || !mounted || !_admin) return;
    setState(() => _ocupado = true);
    try {
      final repo = ref.read(catalogosAdminProvider);
      if (repo == null) {
        throw const FormatException(
          'No hay conexión con la administración de usuarios.',
        );
      }
      await repo.cambiarContrasena(widget.usuarioId, _clave.text);
      _clave.clear();
      _confirmacion.clear();
      if (!mounted) return;
      setState(() => _ocupado = false);
      await mostrarAviso(
        context,
        'Contraseña actualizada. Comunica la nueva contraseña al usuario por un canal privado.',
        tipo: TipoAviso.exito,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      await mostrarAviso(
        context,
        e is FormatException
            ? e.message.toString()
            : 'No se pudo confirmar el cambio de contraseña. Revisa la conexión e inténtalo nuevamente.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: WmsDialogShell(
      title: 'Nueva contraseña',
      subtitle: widget.nombre,
      icon: Icons.password_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      maxWidth: 520,
      canClose: !_ocupado,
      footer: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          TextButton(
            onPressed: _ocupado ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _ocupado || !_admin ? null : _guardar,
            child: const Text('Actualizar contraseña'),
          ),
        ],
      ),
      child:
          _ocupado
              ? const WmsLoadingPanel(label: 'Actualizando contraseña…')
              : Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('nueva-contrasena'),
                      controller: _clave,
                      obscureText: !_visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        helperText: 'Entre 12 y 128 caracteres.',
                        suffixIcon: IconButton(
                          tooltip:
                              _visible
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator:
                          (v) =>
                              v == null || v.length < 12 || v.length > 128
                                  ? 'Usa entre 12 y 128 caracteres.'
                                  : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('confirmar-contrasena'),
                      controller: _confirmacion,
                      obscureText: !_visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                      ),
                      validator:
                          (v) =>
                              v != _clave.text
                                  ? 'Las contraseñas no coinciden.'
                                  : null,
                    ),
                  ],
                ),
              ),
    ),
  );
}
