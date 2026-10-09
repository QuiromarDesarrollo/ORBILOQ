import 'package:flutter/material.dart';

class CatalogoActions extends StatelessWidget {
  const CatalogoActions({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.label = 'Guardar cambios',
  });
  final VoidCallback? onSave, onCancel;
  final String label;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final actions = Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(onPressed: onCancel, child: const Text('Cancelar')),
          FilledButton(onPressed: onSave, child: Text(label)),
        ],
      );
      if (c.maxWidth < 440) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(onPressed: onSave, child: Text(label)),
            ),
          ],
        );
      }
      return Row(
        children: [
          const Text('* Obligatorio', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: actions),
        ],
      );
    },
  );
}

class CatalogoEstado extends StatelessWidget {
  const CatalogoEstado({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final estado in [true, false]) ...[
            if (!estado) const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                selected: value == estado,
                child: OutlinedButton.icon(
                  onPressed:
                      onChanged == null ? null : () => onChanged!(estado),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color:
                          value == estado
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                      width: value == estado ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    value == estado
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  label: Text(estado ? 'Activo' : 'Inactivo'),
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

class CatalogoCampos extends StatelessWidget {
  const CatalogoCampos({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, c) =>
            c.maxWidth < 420
                ? Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      children[i],
                    ],
                  ],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: children[i]),
                    ],
                  ],
                ),
  );
}

String catalogoSingular(String tipo) => switch (tipo) {
  'usuarios' => 'usuario',
  'empaques' => 'empaque',
  'ubicaciones' => 'ubicación',
  'causales_devolucion' => 'causal',
  _ => 'persona',
};
