import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Mensaje de resultado mostrado dentro de un diálogo (visible sobre el modal,
/// a diferencia de un SnackBar que queda detrás de la barrera).
class FeedbackMessage {
  const FeedbackMessage.ok(this.text) : isError = false;
  const FeedbackMessage.error(this.text) : isError = true;

  final String text;
  final bool isError;
}

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.message});

  final FeedbackMessage message;

  @override
  Widget build(BuildContext context) {
    final color = message.isError ? AppColors.alertRed : AppColors.actionGreen;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(message.isError ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message.text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
