import 'wms_loader.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<T?> showWmsDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierDismissible: false,
      animationStyle: AnimationStyle(
        duration:
            MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
        reverseDuration:
            MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      ),
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
    this.canClose = true,
    this.subtitle,
    this.footer,
    this.mobileCatalog = false,
    this.showHeaderIcon = true,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double maxWidth;
  final bool expand;
  final bool canClose;
  final String? subtitle;
  final Widget? footer;
  final bool mobileCatalog;
  final bool showHeaderIcon;

  @override
  Widget build(BuildContext context) {
    final compact = mobileCatalog && MediaQuery.sizeOf(context).width < 600;
    final maxHeight = (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom -
            (compact ? 16 : 32))
        .clamp(100.0, compact ? 10000.0 : 720.0);
    final dialog = Dialog(
      // Fijo en blanco a propósito: estos diálogos usan texto navy fijo
      // (título, iconos) diseñado para fondo claro, y no deben oscurecerse
      // con el tema oscuro del Kardex o el texto queda ilegible.
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(compact ? 8 : 16),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: WmsDialogLoadingHost(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth.clamp(320.0, 1080.0),
            maxHeight: maxHeight,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
            ),
            child: Column(
              mainAxisSize:
                  expand || compact ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showHeaderIcon)
                      Container(
                        padding: EdgeInsets.all(compact ? 7 : 10),
                        decoration: BoxDecoration(
                          color:
                              esCorporativo(context)
                                  ? AppColors.lima.withValues(alpha: .24)
                                  : AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: compact ? 18 : 22,
                        ),
                      ),
                    if (showHeaderIcon) SizedBox(width: compact ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: palOf(context).textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.slate50,
                      ),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.slate600,
                        size: 20,
                      ),
                      onPressed: canClose ? () => Navigator.pop(context) : null,
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                if (compact)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        if (!expand) return SingleChildScrollView(child: child);
                        // Keep toolbar and list reachable when the keyboard reduces height.
                        if (c.maxHeight < 430) {
                          return SingleChildScrollView(
                            child: SizedBox(height: 430, child: child),
                          );
                        }
                        return child;
                      },
                    ),
                  )
                else if (expand)
                  Expanded(child: child)
                else
                  Flexible(child: SingleChildScrollView(child: child)),
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!compact) return dialog;
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: .92),
      ),
      child: dialog,
    );
  }
}
