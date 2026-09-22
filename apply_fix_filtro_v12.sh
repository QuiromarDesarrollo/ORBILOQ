#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Corrige el filtro que 'no hacia nada' al aplicar (v12)
# Aplica a los 4 filtros: OP, OC, Cliente y Fecha (mismo componente)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_filtro_v12.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando correccion del filtro..."

echo "  - lib/shared/widgets/multi_select_filter.dart"
mkdir -p "$(dirname 'lib/shared/widgets/multi_select_filter.dart')"
cat > 'lib/shared/widgets/multi_select_filter.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Diálogo de filtro con búsqueda y casillas. Devuelve el conjunto elegido
/// (vacío = sin filtro / TODOS) o `null` si se cancela.
Future<Set<T>?> showMultiSelectFilter<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> selected,
  required String Function(T) labelOf,
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (_) => _MultiSelectDialog<T>(
      title: title,
      options: options,
      selected: selected,
      labelOf: labelOf,
    ),
  );
}

class _MultiSelectDialog<T> extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
  });

  final String title;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late Set<T> _sel;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Si no hay filtro activo, se empieza sin nada marcado: así buscar y
    // marcar un ítem funciona desde el primer clic (antes se empezaba con
    // TODO marcado, y marcar un ítem buscado en realidad lo desmarcaba de
    // un conjunto ya completo — el resultado se veía "igual que antes").
    // Si se está reabriendo un filtro ya aplicado, se respeta esa selección.
    _sel = <T>{...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final visibles = widget.options.where((o) => widget.labelOf(o).toLowerCase().contains(q)).toList();
    final todos = _sel.length == widget.options.length;
    final ninguno = _sel.isEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          const Icon(Icons.filter_alt, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar en lista...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              tristate: true,
              activeColor: AppColors.primaryNavy,
              title: const Text('SELECCIONAR TODOS', style: TextStyle(fontWeight: FontWeight.bold)),
              value: todos ? true : (ninguno ? false : null),
              onChanged: (_) => setState(() {
                _sel = todos ? <T>{} : <T>{...widget.options};
              }),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 240,
              child: visibles.isEmpty
                  ? const Center(child: Text('Sin coincidencias', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) {
                        final opt = visibles[i];
                        return CheckboxListTile(
                          dense: true,
                          activeColor: AppColors.actionGreen,
                          title: Text(widget.labelOf(opt)),
                          value: _sel.contains(opt),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _sel.add(opt);
                            } else {
                              _sel.remove(opt);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (todos || ninguno) ? <T>{} : _sel),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
          ),
          child: const Text('APLICAR FILTRO', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
