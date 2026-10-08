import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/wms_dialog.dart';

class DestinatarioEditor extends StatefulWidget {
  const DestinatarioEditor({super.key, required this.guardar});
  final Future<void> Function(Map<String, String>) guardar;
  @override
  State<DestinatarioEditor> createState() => _DestinatarioEditorState();
}

class _DestinatarioEditorState extends State<DestinatarioEditor> {
  static const campos = {
    'nombre': 'Nombre o razón social',
    'nit': 'NIT',
    'contacto': 'Quién recibe',
    'ciudad': 'Ciudad',
    'sede': 'Sede',
    'direccion': 'Dirección',
    'telefono': 'Teléfono',
    'celular': 'Celular',
  };
  final form = GlobalKey<FormState>();
  final controles = {for (final k in campos.keys) k: TextEditingController()};
  bool ocupado = false;
  String? error;
  @override
  void dispose() {
    for (final c in controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> guardar() async {
    if (ocupado || !form.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await widget.guardar({
        for (final e in controles.entries) e.key: e.value.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is PostgrestException
                      ? e.message
                      : 'No se pudo guardar. Revisa la conexión e intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: WmsDialogShell(
      title: 'Nuevo destinatario',
      iconColor: Colors.teal,
      icon: Icons.person_add_alt_1,
      canClose: !ocupado,
      maxWidth: 600,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Datos para la lista de empaque. Puedes registrar varias sedes o contactos del mismo cliente. Solo el nombre es obligatorio.',
            ),
            for (final e in campos.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  key: ValueKey(e.key),
                  controller: controles[e.key],
                  enabled: !ocupado,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: e.value,
                    counterText: '',
                  ),
                  validator:
                      (v) =>
                          e.key == 'nombre' && (v?.trim().isEmpty ?? true)
                              ? 'Ingresa el nombre del destinatario.'
                              : null,
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AvisoFormulario(error!),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: ocupado ? null : guardar,
              icon: const Icon(Icons.save_outlined),
              label: Text(ocupado ? 'Guardando…' : 'Guardar destinatario'),
            ),
          ],
        ),
      ),
    ),
  );
}
