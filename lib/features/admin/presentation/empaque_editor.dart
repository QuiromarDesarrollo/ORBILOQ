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
      'peso_bruto_kg',
    ])
      k: TextEditingController(text: widget.fila?[k]?.toString() ?? ''),
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
    if ((datos['peso_bruto_kg'] as double) <
        (datos['peso_neto_kg'] as double)) {
      setState(() => _error = 'El peso bruto no puede ser menor que la tara.');
      return;
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: WmsDialogShell(
      title: widget.fila == null ? 'Agregar empaque' : 'Modificar empaque',
      icon: Icons.inventory_2_outlined,
      iconColor: Colors.teal,
      maxWidth: 520,
      canClose: !_ocupado,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in ['CAJA', 'BOLSA'])
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged:
                  _ocupado ? null : (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 12),
            _campo('nombre', 'Nombre para mostrar', numero: false),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _campo('largo_cm', 'Largo (cm)')),
                const SizedBox(width: 8),
                Expanded(child: _campo('ancho_cm', 'Ancho (cm)')),
                const SizedBox(width: 8),
                Expanded(child: _campo('alto_cm', 'Alto (cm)')),
              ],
            ),
            const SizedBox(height: 12),
            _campo('peso_neto_kg', 'Peso neto / tara (kg)'),
            const SizedBox(height: 12),
            _campo('peso_bruto_kg', 'Peso bruto aproximado (kg)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _activo,
              onChanged: _ocupado ? null : (v) => setState(() => _activo = v),
            ),
            if (_error != null)
              AvisoFormulario(_error!),
            if (_ocupado) const WmsLoadingStrip(),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _ocupado ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: _ocupado ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
