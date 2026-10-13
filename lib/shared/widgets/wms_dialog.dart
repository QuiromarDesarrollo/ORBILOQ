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
class WmsDialogShell extends StatefulWidget {
  const WmsDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.maxWidth = 900,
    this.expand = false,
    this.canClose = true,
    this.closeTooltip = 'Cerrar',
    this.subtitle,
    this.footer,
    this.mobileCatalog = false,
    this.showHeaderIcon = true,
    this.fullscreen = false,
    this.onToggleFullscreen,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double maxWidth;
  final bool expand;
  final bool canClose;
  final String closeTooltip;
  final String? subtitle;
  final Widget? footer;
  final bool mobileCatalog;
  final bool showHeaderIcon;
  final bool fullscreen;
  final VoidCallback? onToggleFullscreen;

  @override
  State<WmsDialogShell> createState() => _WmsDialogShellState();
}

class _WmsDialogShellState extends State<WmsDialogShell> {
  bool _fullscreen = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final icon = widget.icon;
    final child = widget.child;
    final maxWidth = widget.maxWidth;
    final expand = widget.expand;
    final canClose = widget.canClose;
    final subtitle = widget.subtitle;
    final footer = widget.footer;
    final showHeaderIcon = widget.showHeaderIcon;
    final fullscreen =
        widget.onToggleFullscreen == null ? _fullscreen : widget.fullscreen;
    final onToggleFullscreen =
        widget.onToggleFullscreen ??
        () => setState(() => _fullscreen = !_fullscreen);

    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom <
            600;
    final maxHeight = (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom -
            (fullscreen
                ? 0
                : compact
                ? 16
                : 32))
        .clamp(100.0, fullscreen || compact ? 10000.0 : 720.0);
    final dialog = Dialog(
      // Fijo en blanco a propósito: estos diálogos usan texto navy fijo
      // (título, iconos) diseñado para fondo claro, y no deben oscurecerse
      // con el tema oscuro del Kardex o el texto queda ilegible.
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(
        fullscreen
            ? 0
            : compact
            ? 8
            : 16,
      ),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fullscreen ? 0 : 18),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: WmsDialogLoadingHost(
        child: ConstrainedBox(
          key: const ValueKey('wms-dialog-surface'),
          constraints: BoxConstraints(
            minWidth: fullscreen ? MediaQuery.sizeOf(context).width : 0,
            maxWidth:
                fullscreen
                    ? MediaQuery.sizeOf(context).width
                    : maxWidth.clamp(320.0, 1080.0),
            maxHeight: maxHeight,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
            ),
            child: Column(
              mainAxisSize:
                  expand || compact || fullscreen
                      ? MainAxisSize.max
                      : MainAxisSize.min,
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
                              subtitle,
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
                      tooltip:
                          fullscreen ? 'Restaurar tamaño' : 'Ampliar pantalla',
                      icon: Icon(
                        fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                      onPressed: onToggleFullscreen,
                    ),
                    IconButton(
                      tooltip: widget.closeTooltip,
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
                  footer,
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
