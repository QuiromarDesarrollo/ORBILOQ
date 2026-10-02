import 'package:flutter/material.dart';

/// Único indicador de espera de la aplicación, también dentro de botones.
class WmsLoader extends StatelessWidget {
  const WmsLoader({super.key, this.color, this.strokeWidth = 2.5});
  final Color? color;
  final double strokeWidth;
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 22,
        child: MediaQuery.disableAnimationsOf(context)
            ? Icon(Icons.hourglass_top_rounded,
                size: 20,
                color: color ?? Theme.of(context).colorScheme.primary,
                semanticLabel: 'Cargando')
            : CircularProgressIndicator(
                strokeWidth: strokeWidth,
                color: color,
                semanticsLabel: 'Cargando',
                strokeCap: StrokeCap.round),
      );
}

class WmsLoadingStrip extends StatelessWidget {
  const WmsLoadingStrip({super.key, this.label = 'Cargando…'});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const WmsLoader(),
        const SizedBox(width: 10),
        Flexible(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      ]));
}
