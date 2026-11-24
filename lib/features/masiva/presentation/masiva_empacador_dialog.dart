import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../masiva_repository.dart';

/// El catálogo guarda personas, no crea cuentas ni permisos de acceso.
class MasivaEmpacadorDialog extends StatefulWidget {
  const MasivaEmpacadorDialog({super.key, required this.guardar});
  final Future<MasivaJson> Function(String nombre) guardar;

  @override
  State<MasivaEmpacadorDialog> createState() => _EmpacadorState();
}

class _EmpacadorState extends State<MasivaEmpacadorDialog> {
  final _nombre = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del empacador.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final person = await widget.guardar(nombre);
      if (mounted) Navigator.of(context).pop(person);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMasiva(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: WmsDialogShell(
      title: 'Agregar empacador',
      icon: Icons.person_add_alt_1,
      iconColor: AppColors.petroleo,
      maxWidth: 520,
      canClose: !_saving,
      footer: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Agregar'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agrega un nombre a la lista de empacadores. No necesita usuario ni contraseña.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombre,
              autofocus: true,
              enabled: !_saving,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
