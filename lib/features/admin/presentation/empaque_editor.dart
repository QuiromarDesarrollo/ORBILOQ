import 'catalogo_form_widgets.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/empaques_repository.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../shared/widgets/wms_loader.dart';

class EmpaqueEditor extends ConsumerStatefulWidget {
  const EmpaqueEditor({super.key, this.fila});
  final Map<String, dynamic>? fila;
  @override
  ConsumerState<EmpaqueEditor> createState() => _EmpaqueEditorState();
}

class _EmpaqueEditorState extends ConsumerState<EmpaqueEditor> {
  final _form = GlobalKey<FormState>();
  late final _campos = {
    for (final k in [
      'nombre',
      'largo_cm',
      'ancho_cm',
      'alto_cm',
      'peso_neto_kg',
    ])
      k: TextEditingController(
        text:
            k == 'nombre'
                ? textoEmpaque(widget.fila?[k])
                : widget.fila?[k]?.toString() ?? '',
      ),
  };
  late String _categoria = widget.fila?['categoria'] ?? 'CAJA';
  late bool _activo = widget.fila?['activo'] ?? true;
  bool _ocupado = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _numero(String valor) =>
      double.tryParse(valor.trim().replaceAll(',', '.'));
  Widget _campo(String key, String label, {bool numero = true}) =>
      TextFormField(
        controller: _campos[key],
        enabled: !_ocupado,
        keyboardType:
            numero
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          if (!numero) {
            return (v ?? '').trim().isEmpty || v!.trim().length > 150
                ? 'Indica un nombre de 1 a 150 caracteres.'
                : null;
          }
          final n = _numero(v ?? '');
          return n == null || !n.isFinite || n <= 0 || n > 100000
              ? 'Usa un valor mayor que 0 y hasta 100000.'
              : null;
        },
      );
  Future<void> _guardar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    final datos = <String, dynamic>{
      'nombre': _campos['nombre']!.text.trim(),
      'categoria': _categoria,
      'activo': _activo,
    };
    for (final k in _campos.keys.where((k) => k != 'nombre')) {
      datos[k] = _numero(_campos[k]!.text);
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = ref.read(empaquesRepositoryProvider);
      if (repo == null) {
        throw const FormatException('Conecta Supabase de pruebas.');
      }
      await repo.guardar(datos, widget.fila);
      ref.invalidate(empaquesProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : 'No se pudo guardar el empaque.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volumen =
        (_numero(_campos['largo_cm']!.text) ?? 0) *
        (_numero(_campos['ancho_cm']!.text) ?? 0) *
        (_numero(_campos['alto_cm']!.text) ?? 0) /
        1000000;
    return PopScope(
      canPop: !_ocupado,
      child: WmsDialogShell(
        mobileCatalog: true,
        title: widget.fila == null ? 'Agregar empaque' : 'Editar empaque',
        subtitle:
            'Catálogo de empaques${widget.fila == null ? '' : ' · ${textoEmpaque(widget.fila!['nombre'])}'}',
        icon: Icons.inventory_2_outlined,
        iconColor: Theme.of(context).colorScheme.primary,
        maxWidth: 600,
        canClose: !_ocupado,
        footer: CatalogoActions(
          onSave: _ocupado ? null : _guardar,
          onCancel: _ocupado ? null : () => Navigator.pop(context),
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatalogoCampos(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _categoria,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría *'),
                    items: const [
                      DropdownMenuItem(value: 'CAJA', child: Text('Caja')),
                      DropdownMenuItem(value: 'BOLSA', child: Text('Paquete')),
                    ],
                    onChanged:
                        _ocupado
                            ? null
                            : (v) => setState(() => _categoria = v!),
                  ),
                  _campo('nombre', 'Nombre para mostrar *', numero: false),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Medidas exteriores *',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              CatalogoCampos(
                children: [
                  _campo('largo_cm', 'Largo (cm)'),
                  _campo('ancho_cm', 'Ancho (cm)'),
                  _campo('alto_cm', 'Alto (cm)'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Volumen calculado: ${volumen.toStringAsFixed(3).replaceAll('.', ',')} m³',
                ),
              ),
              const SizedBox(height: 24),
              const Text('Peso', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              CatalogoCampos(children: [_campo('peso_neto_kg', 'Tara (kg) *')]),
              const SizedBox(height: 8),
              const Text(
                'El peso bruto se asigna a cada caja o paquete al preparar el despacho.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              CatalogoEstado(
                value: _activo,
                onChanged: _ocupado ? null : (v) => setState(() => _activo = v),
              ),
              if (_error != null) AvisoFormulario(_error!),
              if (_ocupado) const WmsLoadingStrip(),
            ],
          ),
        ),
      ),
    );
  }
}
