import '../../../domain/destinatario_internacional.dart';
import 'catalogo_form_widgets.dart';
import '../../../shared/widgets/wms_loader.dart';
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
  final controles = {
    for (final k in [...campos.keys, ...camposDestinatarioInternacional.keys])
      k: TextEditingController(),
  };
  bool ocupado = false;
  bool internacional = false;
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
        for (final k in campos.keys) k: controles[k]!.text.trim(),
        if (internacional) ...{
          'tipo_destinatario': 'internacional',
          for (final k in camposDestinatarioInternacional.keys)
            k: controles[k]!.text.trim(),
        },
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

  Widget _campo(String k) => TextFormField(
    key: ValueKey(k),
    controller: controles[k],
    enabled: !ocupado,
    maxLength: 500,
    decoration: InputDecoration(
      labelText:
          '${campos[k] ?? camposDestinatarioInternacional[k]}${k == 'nombre' || camposDestinatarioInternacional.containsKey(k) ? ' *' : ''}',
      counterText: '',
    ),
    validator:
        (v) =>
            (k == 'nombre' || camposDestinatarioInternacional.containsKey(k)) &&
                    (v?.trim().isEmpty ?? true)
                ? (k == 'nombre'
                    ? 'Ingresa el nombre del destinatario.'
                    : 'Completa este campo.')
                : null,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: WmsDialogShell(
      mobileCatalog: true,
      title: 'Nuevo destinatario',
      subtitle: 'Datos del cliente y sede para la lista de empaque.',
      footer: CatalogoActions(
        onSave: ocupado ? null : guardar,
        onCancel: ocupado ? null : () => Navigator.pop(context),
        label: 'Guardar destinatario',
      ),
      iconColor: Colors.teal,
      icon: Icons.person_add_alt_1,
      canClose: !ocupado,
      maxWidth: 600,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<bool>(
              initialValue: internacional,
              decoration: const InputDecoration(
                labelText: 'Tipo de destinatario',
              ),
              items: const [
                DropdownMenuItem(value: false, child: Text('Nacional')),
                DropdownMenuItem(value: true, child: Text('Internacional')),
              ],
              onChanged:
                  ocupado ? null : (v) => setState(() => internacional = v!),
            ),
            const SizedBox(height: 16),
            Text(
              internacional
                  ? 'Se generará una LE internacional FMT-GL-005. Completa los campos marcados con *.'
                  : 'Datos para la lista de empaque. Puedes registrar varias sedes o contactos del mismo cliente. Solo el nombre es obligatorio.',
            ),
            const SizedBox(height: 20),
            _campo('nombre'),
            const SizedBox(height: 16),
            CatalogoCampos(children: [_campo('nit'), _campo('contacto')]),
            const SizedBox(height: 16),
            CatalogoCampos(children: [_campo('ciudad'), _campo('sede')]),
            const SizedBox(height: 16),
            _campo('direccion'),
            const SizedBox(height: 16),
            CatalogoCampos(children: [_campo('telefono'), _campo('celular')]),
            if (internacional) ...[
              const SizedBox(height: 20),
              const Text(
                'Datos para la LE internacional',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _campo('email'),
              const SizedBox(height: 16),
              CatalogoCampos(children: [_campo('via'), _campo('tipo_carga')]),
              const SizedBox(height: 16),
              CatalogoCampos(
                children: [_campo('embalaje'), _campo('termino_negociacion')],
              ),
              const SizedBox(height: 16),
              CatalogoCampos(
                children: [_campo('puerto_embarque'), _campo('pais_origen')],
              ),
              const SizedBox(height: 16),
              CatalogoCampos(
                children: [_campo('puerto_destino'), _campo('pais_destino')],
              ),
            ],
            if (ocupado) const WmsLoadingStrip(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AvisoFormulario(error!),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
