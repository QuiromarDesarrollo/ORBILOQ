import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../core/theme/app_theme.dart';

/// Desplegable respaldado por una lista ampliable de nombres: además de
/// elegir uno ya registrado, permite agregar uno nuevo directo desde el
/// formulario (persistido vía [onAgregar] y reflejado invalidando [itemsProvider]).
class AddablePersonDropdown extends ConsumerWidget {
  const AddablePersonDropdown({
    super.key,
    required this.label,
    required this.valor,
    required this.onChanged,
    required this.itemsProvider,
    required this.onAgregar,
    required this.tituloDialogo,
  });

  static const _valorAgregar = '__agregar_nuevo__';

  final String label;
  final String? valor;
  final ValueChanged<String?> onChanged;
  final FutureProvider<List<String>> itemsProvider;
  final Future<Result<String>> Function(WidgetRef ref, String nombre) onAgregar;
  final String tituloDialogo;

  Future<void> _agregarNuevo(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tituloDialogo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: wmsInput('Nombre completo'),
          onSubmitted: (v) {
            // Misma causa que el fix de "+ AGREGAR NUEVA PERSONA": cerrar el
            // diálogo (Navigator.pop) en el mismo instante en que el campo
            // de texto todavía está procesando el ENTER del teclado/IME
            // puede romper el árbol de elementos. Se retrasa al siguiente
            // frame para que el campo termine de procesar el ENTER primero.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(v.trim());
            });
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text.trim()),
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nombre == null || nombre.isEmpty) return;

    final res = await onAgregar(ref, nombre);
    switch (res) {
      case Ok(:final value):
        ref.invalidate(itemsProvider);
        onChanged(value);
      case Err(:final message):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    return items.when(
      loading: () => const WmsLoadingStrip(),
      error: (e, _) => Text('No se pudo cargar la lista: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) {
        if(valor!=null && !lista.contains(valor)) {
          WidgetsBinding.instance.addPostFrameCallback((_){if(context.mounted)onChanged(null);});
        }
        return DropdownButtonFormField<String>(
                  isExpanded: true,
        key: ValueKey('${lista.join('|')}::$valor'),
        initialValue: lista.contains(valor) ? valor : null,
        decoration: wmsInput(label, icon: Icons.person_outline),
        items: [
          for (final n in lista) DropdownMenuItem(value: n, child: Text(n)),
          const DropdownMenuItem(
            value: _valorAgregar,
            child: Text('+ AGREGAR NUEVA PERSONA…', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        onChanged: (v) {
          if (v == _valorAgregar) {
            // Se retrasa al siguiente frame: si se abre el diálogo en el
            // mismo instante en que el desplegable todavía está cerrando su
            // propio menú, Flutter puede romper el árbol de elementos
            // ("_dependents.isEmpty is not true").
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _agregarNuevo(context, ref);
            });
            return;
          }
          onChanged(v);
        },
      );
      },
    );
  }
}
