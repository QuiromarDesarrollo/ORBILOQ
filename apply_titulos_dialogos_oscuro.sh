#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Titulos ilegibles en dialogos con el tema oscuro
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_titulos_dialogos_oscuro.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Corrigiendo titulos de dialogos en tema oscuro..."

echo "  - lib/core/theme/app_theme.dart"
mkdir -p "$(dirname 'lib/core/theme/app_theme.dart')"
cat > 'lib/core/theme/app_theme.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryNavy = Color(0xFF173559);
  static const secondaryNavy = Color(0xFF1F436E);
  static const actionGreen = Color(0xFF2E8B57);
  static const actionOrange = Color(0xFFF37021);
  static const alertRed = Color(0xFFD32F2F);
  static const accentCyan = Color(0xFF00A8CC);
  static const background = Color(0xFFF4F6F9);

  // ---- Paleta del rediseño del Kardex (pantalla principal) ----
  static const tealPrimary = Color(0xFF0F766E);
  static const tealDark = Color(0xFF0B5750);
  static const tealSoft = Color(0xFFE6F4F2);
  static const slate900 = Color(0xFF0F172A);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate50 = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE5E9F0);
  static const amberChip = Color(0xFFB45309);
  static const amberChipBg = Color(0xFFFFF7ED);
  static const redChipBg = Color(0xFFFEF2F2);
  static const greenChipBg = Color(0xFFECFDF5);
  static const blueChipBg = Color(0xFFEFF6FF);
  static const blueChip = Color(0xFF1D4ED8);

  // ---- Paleta oscura (rediseño del Kardex, tema dark) ----
  static const darkBg = Color(0xFF0B1220);
  static const darkHeader = Color(0xFF0E1729);
  static const darkCard = Color(0xFF141B2D);
  static const darkCardBorder = Color(0xFF232D42);
  static const darkInput = Color(0xFF0F1729);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF8895AC);
  static const darkTextMuted = Color(0xFF5B6B85);
  static const tealAccent = Color(0xFF2DD4BF);
  static const chipRedBgDark = Color(0xFF3B1219);
  static const chipRedDark = Color(0xFFFCA5A5);
  static const chipGreenBgDark = Color(0xFF0F2E22);
  static const chipGreenDark = Color(0xFF6EE7B7);
  static const chipNeutralBgDark = Color(0xFF1B2438);
  static const chipNeutralDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy),
        scaffoldBackgroundColor: AppColors.background,
      );

  /// Tema del Kardex (pantalla principal), en su variante oscura o clara,
  /// con [AppPalette] enganchada como [ThemeExtension] para que cualquier
  /// widget pueda leerla con `palOf(context)`.
  static ThemeData kardex(TemaModo modo) {
    final pal = modo == TemaModo.claro ? AppPalette.claro : AppPalette.oscuro;
    return ThemeData(
      useMaterial3: true,
      brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: pal.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealPrimary,
        brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      ),
      extensions: [pal],
    );
  }
}

/// Modo de color de la pantalla del Kardex. No afecta el login ni ninguna
/// funcionalidad: solo cambia qué [AppPalette] se usa.
enum TemaModo { oscuro, claro }

/// Paleta de colores del Kardex, como [ThemeExtension]: cada widget la lee
/// con `palOf(context)` en vez de usar directamente `AppColors.darkXxx`, así
/// el mismo código sirve para el tema oscuro y el claro.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardBorder,
    required this.input,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.chipRedBg,
    required this.chipRed,
    required this.chipGreenBg,
    required this.chipGreen,
    required this.chipNeutralBg,
    required this.warning,
    required this.info,
  });

  final Color bg;
  final Color header;
  final Color card;
  final Color cardBorder;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color chipRedBg;
  final Color chipRed;
  final Color chipGreenBg;
  final Color chipGreen;
  final Color chipNeutralBg;

  /// Color de advertencia (ámbar) para cifras/chips de atención, como
  /// "Producto no conforme" o "HOY". Distinto del rojo de alerta.
  final Color warning;

  /// Azul informativo, para cifras como "Recibido en bodega".
  final Color info;

  static const oscuro = AppPalette(
    bg: AppColors.darkBg,
    header: AppColors.darkHeader,
    card: AppColors.darkCard,
    cardBorder: AppColors.darkCardBorder,
    input: AppColors.darkInput,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    accent: AppColors.tealAccent,
    chipRedBg: AppColors.chipRedBgDark,
    chipRed: AppColors.chipRedDark,
    chipGreenBg: AppColors.chipGreenBgDark,
    chipGreen: AppColors.chipGreenDark,
    chipNeutralBg: AppColors.chipNeutralBgDark,
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
  );

  static const claro = AppPalette(
    bg: Color(0xFFF3F5F9),
    header: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardBorder: AppColors.slate200,
    input: Color(0xFFF8FAFC),
    textPrimary: AppColors.slate900,
    textSecondary: AppColors.slate600,
    textMuted: AppColors.slate400,
    accent: AppColors.tealPrimary,
    chipRedBg: AppColors.redChipBg,
    chipRed: Color(0xFFB91C1C),
    chipGreenBg: AppColors.greenChipBg,
    chipGreen: Color(0xFF047857),
    chipNeutralBg: Color(0xFFF1F5F9),
    warning: AppColors.amberChip,
    info: AppColors.blueChip,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? header,
    Color? card,
    Color? cardBorder,
    Color? input,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? chipRedBg,
    Color? chipRed,
    Color? chipGreenBg,
    Color? chipGreen,
    Color? chipNeutralBg,
    Color? warning,
    Color? info,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      header: header ?? this.header,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      chipRedBg: chipRedBg ?? this.chipRedBg,
      chipRed: chipRed ?? this.chipRed,
      chipGreenBg: chipGreenBg ?? this.chipGreenBg,
      chipGreen: chipGreen ?? this.chipGreen,
      chipNeutralBg: chipNeutralBg ?? this.chipNeutralBg,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      header: Color.lerp(header, other.header, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      input: Color.lerp(input, other.input, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      chipRedBg: Color.lerp(chipRedBg, other.chipRedBg, t)!,
      chipRed: Color.lerp(chipRed, other.chipRed, t)!,
      chipGreenBg: Color.lerp(chipGreenBg, other.chipGreenBg, t)!,
      chipGreen: Color.lerp(chipGreen, other.chipGreen, t)!,
      chipNeutralBg: Color.lerp(chipNeutralBg, other.chipNeutralBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Atajo para leer la paleta activa desde cualquier widget con [context].
AppPalette palOf(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? AppPalette.oscuro;

final ThemeData _temaDialogoClaro = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy, brightness: Brightness.light),
);

/// Envuelve un diálogo utilitario (filtros, confirmaciones, tickets) para
/// que siempre se vea en modo claro, sin importar si el Kardex está en tema
/// oscuro o claro: su diseño (texto navy fijo, tarjeta blanca) no está
/// pensado para adaptarse, y en tema oscuro el título quedaba casi
/// invisible. `showDialog` monta cada diálogo como una ruta aparte, así que
/// esto se aplica en cada `builder`, no una sola vez arriba del árbol.
Widget dialogoClaro(Widget child) => Theme(data: _temaDialogoClaro, child: child);

/// Decoración estándar de campos de texto.
InputDecoration wmsInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}
ORBILOQ_EOF

echo "  - lib/shared/widgets/wms_dialog.dart"
mkdir -p "$(dirname 'lib/shared/widgets/wms_dialog.dart')"
cat > 'lib/shared/widgets/wms_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<T?> showWmsDialog<T>(BuildContext context, WidgetBuilder builder) => showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => dialogoClaro(builder(ctx)),
    );

/// Marco común de los diálogos: título, cierre y tamaño responsive.
/// Con [expand] el contenido ocupa toda la altura disponible (p. ej. pestañas).
class WmsDialogShell extends StatelessWidget {
  const WmsDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.maxWidth = 900,
    this.expand = false,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double maxWidth;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Dialog(
      // Fijo en blanco a propósito: estos diálogos usan texto navy fijo
      // (título, iconos) diseñado para fondo claro, y no deben oscurecerse
      // con el tema oscuro del Kardex o el texto queda ilegible.
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 4),
              if (expand)
                Expanded(child: child)
              else
                Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

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
    builder: (_) => dialogoClaro(
      _MultiSelectDialog<T>(
        title: title,
        options: options,
        selected: selected,
        labelOf: labelOf,
      ),
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
      // Fijo en blanco: el título usa texto navy fijo, pensado para fondo
      // claro (no debe oscurecerse con el tema oscuro del Kardex).
      backgroundColor: Colors.white,
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

echo "  - lib/features/kardex/presentation/observacion_dialog.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/observacion_dialog.dart')"
cat > 'lib/features/kardex/presentation/observacion_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

Future<void> showObservacionDialog(BuildContext context, ItemKardex k) {
  final obs = k.item.observacionOp;
  return showDialog<void>(
    context: context,
    builder: (ctx) => dialogoClaro(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'OBSERVACIÓN OP: ${k.item.op}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referencia: ${k.item.codigo}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              obs.isEmpty ? 'Sin observaciones registradas.' : obs,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
          child: const Text('ENTENDIDO'),
        ),
      ],
    )),
  );
}
ORBILOQ_EOF

echo "  - lib/features/ubicaciones/presentation/ubicaciones_dialog.dart"
mkdir -p "$(dirname 'lib/features/ubicaciones/presentation/ubicaciones_dialog.dart')"
cat > 'lib/features/ubicaciones/presentation/ubicaciones_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showUbicacionesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const UbicacionesDialog());

typedef _Existencia = ({ItemKardex item, int cantidad});

class UbicacionesDialog extends ConsumerStatefulWidget {
  const UbicacionesDialog({super.key});

  @override
  ConsumerState<UbicacionesDialog> createState() => _UbicacionesDialogState();
}

class _UbicacionesDialogState extends ConsumerState<UbicacionesDialog> {
  String _ubicacion = WmsConstantes.ubicaciones.first;
  FeedbackMessage? _msg;

  Future<void> _imprimir(List<_Existencia> items, int total) async {
    final imprimir = await showDialog<bool>(
      context: context,
      builder: (_) => dialogoClaro(_TicketDialog(ubicacion: _ubicacion, items: items, total: total)),
    );
    if (imprimir == true && mounted) {
      setState(() => _msg = FeedbackMessage.ok('Ticket de $_ubicacion enviado a impresora térmica.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(kardexProvider);
    final items = <_Existencia>[
      for (final k in kardex)
        if (k.stockEn(_ubicacion) > 0) (item: k, cantidad: k.stockEn(_ubicacion)),
    ];
    final total = items.fold<int>(0, (s, e) => s + e.cantidad);

    return WmsDialogShell(
      title: 'CONSULTA DE EXISTENCIAS POR ESTANTE',
      icon: Icons.domain,
      iconColor: AppColors.primaryNavy,
      maxWidth: 850,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Seleccionar estante / rack',
            value: _ubicacion,
            items: WmsConstantes.ubicaciones,
            onChanged: (v) => setState(() {
              _ubicacion = v;
              _msg = null;
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total en $_ubicacion: $total unidades disponibles',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                ),
                ActionButton(
                  icon: Icons.print,
                  label: 'TICKET',
                  color: AppColors.actionGreen,
                  onPressed: items.isEmpty ? null : () => _imprimir(items, total),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Este estante no tiene existencias.')),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final e = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${e.item.item.codigo} - ${e.item.item.descripcion} (${e.item.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('OP: ${e.item.item.op} | OC: ${e.item.item.oc} | Cliente: ${e.item.item.cliente}'),
                    trailing: Text(
                      '${e.cantidad} Uds',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.actionGreen),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatelessWidget {
  const _TicketDialog({required this.ubicacion, required this.items, required this.total});

  final String ubicacion;
  final List<_Existencia> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                    child: Column(
                      children: [
                        const Text('ORBILOQ WMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('RÓTULO DE UBICACIÓN FÍSICA', style: TextStyle(fontSize: 11)),
                        const Divider(thickness: 1.5, color: Colors.black),
                        Text(ubicacion, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 110,
                          width: 110,
                          decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.black)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 70),
                              Text('SCAN UBICACIÓN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('QR ID: LOC-$ubicacion', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        const Divider(color: Colors.black),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CONTENIDO ALMACENADO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        for (final e in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${e.item.item.codigo} (${e.item.item.talla}) OP:${e.item.item.op}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                Text('${e.cantidad} Uds', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const Divider(color: Colors.black),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL EN ESTANTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$total UDS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
                  const SizedBox(width: 8),
                  ActionButton(
                    icon: Icons.print,
                    label: 'IMPRIMIR',
                    color: AppColors.actionGreen,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
