#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Orden de filtros de fecha por fecha real (no por texto)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_orden_fechas_filtro.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Corrigiendo orden de filtros de fecha..."

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

enum _Orden { ninguno, ascendente, descendente }

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late Set<T> _sel;
  String _query = '';
  _Orden _orden = _Orden.ninguno;

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

  /// Compara por fecha si ambas etiquetas tienen forma "DD/MM/AAAA" (para
  /// que ordene por fecha real y no por el número del día como texto), por
  /// número si ambas lo son (para que "2" quede antes que "10"), y si no,
  /// alfabéticamente sin distinguir mayúsculas.
  int _comparar(T a, T b) {
    final la = widget.labelOf(a);
    final lb = widget.labelOf(b);
    final fa = _fechaDesdeEtiqueta(la);
    final fb = _fechaDesdeEtiqueta(lb);
    if (fa != null && fb != null) return fa.compareTo(fb);
    final na = num.tryParse(la);
    final nb = num.tryParse(lb);
    if (na != null && nb != null) return na.compareTo(nb);
    return la.toLowerCase().compareTo(lb.toLowerCase());
  }

  static final _formatoFecha = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

  DateTime? _fechaDesdeEtiqueta(String etiqueta) {
    final m = _formatoFecha.firstMatch(etiqueta);
    if (m == null) return null;
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  }

  void _alternarOrden(_Orden tocado) {
    setState(() => _orden = _orden == tocado ? _Orden.ninguno : tocado);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final visibles = widget.options.where((o) => widget.labelOf(o).toLowerCase().contains(q)).toList();
    if (_orden != _Orden.ninguno) {
      visibles.sort(_comparar);
      if (_orden == _Orden.descendente) {
        final invertidos = visibles.reversed.toList();
        visibles
          ..clear()
          ..addAll(invertidos);
      }
    }
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
            Row(
              children: [
                const Text('Ordenar:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                _BotonOrden(
                  icono: Icons.arrow_upward,
                  etiqueta: 'Ascendente',
                  activo: _orden == _Orden.ascendente,
                  onPressed: () => _alternarOrden(_Orden.ascendente),
                ),
                const SizedBox(width: 6),
                _BotonOrden(
                  icono: Icons.arrow_downward,
                  etiqueta: 'Descendente',
                  activo: _orden == _Orden.descendente,
                  onPressed: () => _alternarOrden(_Orden.descendente),
                ),
              ],
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

/// Botón pequeño tipo "chip" para elegir orden ascendente/descendente.
class _BotonOrden extends StatelessWidget {
  const _BotonOrden({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onPressed,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiqueta,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: activo ? AppColors.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: activo ? AppColors.primaryNavy : Colors.grey.shade400),
          ),
          child: Icon(icono, size: 16, color: activo ? Colors.white : Colors.grey.shade700),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
