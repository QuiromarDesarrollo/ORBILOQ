import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<T?> showWmsDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierDismissible: false,
      animationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseDuration: MediaQuery.disableAnimationsOf(context)
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
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double maxWidth;
  final bool expand;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    final maxHeight = (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom -
            32)
        .clamp(100.0, 720.0);
    return Dialog(
      // Fijo en blanco a propósito: estos diálogos usan texto navy fijo
      // (título, iconos) diseñado para fondo claro, y no deben oscurecerse
      // con el tema oscuro del Kardex o el texto queda ilegible.
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: maxWidth.clamp(320.0, 1080.0), maxHeight: maxHeight),
        child: Padding(
          padding:
              EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 24),
          child: Column(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(10)),
                      child:
                          Icon(icon, color: AppColors.tealPrimary, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.slate50),
                    icon: const Icon(Icons.close,
                        color: AppColors.slate600, size: 20),
                    onPressed: canClose ? () => Navigator.pop(context) : null,
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
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
