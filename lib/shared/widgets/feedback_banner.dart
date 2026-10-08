import 'package:flutter/material.dart';

import 'wms_alert.dart';

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
    return AvisoFormulario(message.text, error: message.isError);
  }
}
