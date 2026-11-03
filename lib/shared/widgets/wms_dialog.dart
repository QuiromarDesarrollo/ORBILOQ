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
    this.compactHeader = false,
    this.fullscreen = false,
    this.onToggleFullscreen,
    this.draggable = false,
    this.onClose,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double maxWidth;
  final bool expand;
  final bool canClose;
  final VoidCallback? onClose;
  final String closeTooltip;
  final String? subtitle;
  final Widget? footer;
  final bool mobileCatalog;
  final bool showHeaderIcon;
  final bool compactHeader;
  final bool fullscreen;
  final VoidCallback? onToggleFullscreen;

  /// Permite mover el diálogo desde su título en pantallas amplias.
  final bool draggable;

  @override
  State<WmsDialogShell> createState() => _WmsDialogShellState();
}

class _WmsDialogShellState extends State<WmsDialogShell> {
  bool _fullscreen = false;
  Alignment _position = Alignment.center;
  final _surfaceKey = GlobalKey();
  final _contentKey = GlobalKey();

  void _move(DragUpdateDetails details) {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (surface is! RenderBox) return;
    final media = MediaQuery.of(context);
    final freeX =
        media.size.width -
        media.viewInsets.horizontal -
        32 -
        surface.size.width;
    final freeY =
        media.size.height -
        media.viewInsets.vertical -
        32 -
        surface.size.height;
    setState(() {
      _position = Alignment(
        freeX > 0
            ? (_position.x + details.delta.dx * 2 / freeX).clamp(-1.0, 1.0)
            : 0,
        freeY > 0
            ? (_position.y + details.delta.dy * 2 / freeY).clamp(-1.0, 1.0)
            : 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final icon = widget.icon;
    final child = KeyedSubtree(key: _contentKey, child: widget.child);
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
      alignment:
          widget.draggable && !compact && !fullscreen
              ? _position
              : Alignment.center,
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
        key: _surfaceKey,
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
              widget.compactHeader || MediaQuery.sizeOf(context).width < 600
                  ? 12
                  : 24,
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
                      child: MouseRegion(
                        cursor:
                            widget.draggable && !compact && !fullscreen
                                ? SystemMouseCursors.move
                                : MouseCursor.defer,
                        child: GestureDetector(
                          key: const ValueKey('wms-dialog-drag-handle'),
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate:
                              widget.draggable && !compact && !fullscreen
                                  ? _move
                                  : null,
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
                      onPressed:
                          canClose
                              ? (widget.onClose ?? () => Navigator.pop(context))
                              : null,
                    ),
                  ],
                ),
                Divider(height: widget.compactHeader ? 12 : 16),
                if (!widget.compactHeader) const SizedBox(height: 8),
                Flexible(
                  fit: expand || compact ? FlexFit.tight : FlexFit.loose,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Keep the same ancestors while the keyboard changes height.
                      // Replacing scroll wrappers disconnects the text input on web.
                      return SingleChildScrollView(
                        child:
                            expand
                                ? SizedBox(
                                  height:
                                      compact &&
                                              constraints.maxHeight <
                                                  (widget.compactHeader
                                                      ? 300
                                                      : 430)
                                          ? 430
                                          : constraints.maxHeight,
                                  child: child,
                                )
                                : child,
                      );
                    },
                  ),
                ),
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
    return Theme(
      data:
          !compact
              ? Theme.of(context)
              : Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(
                  context,
                ).inputDecorationTheme.copyWith(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                textTheme: Theme.of(
                  context,
                ).textTheme.apply(fontSizeFactor: .92),
              ),
      child: dialog,
    );
  }
}
