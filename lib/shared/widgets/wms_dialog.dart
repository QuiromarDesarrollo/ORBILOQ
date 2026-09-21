import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<T?> showWmsDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(context: context, barrierDismissible: false, builder: builder);

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
