import 'package:flutter/material.dart';

abstract final class CiclosColores {
  static const fondo = Color(0xff080f1d);
  static const panel = Color(0xff101d30);
  static const borde = Color(0xff2a405a);
  static List<Color> superficie(BuildContext c, {Color? acento}) =>
      oscuro(c)
          ? [
            Color.alphaBlend(
              (acento ?? const Color(0xff4ea3dc)).withValues(alpha: .10),
              const Color(0xff172940),
            ),
            const Color(0xff101b2d),
          ]
          : [Theme.of(c).colorScheme.surface, Theme.of(c).colorScheme.surface];

  static bool oscuro(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color bien(BuildContext c) =>
      oscuro(c) ? const Color(0xff38d9bf) : const Color(0xff0f766e);
  static Color alerta(BuildContext c) =>
      oscuro(c) ? const Color(0xffffc66d) : const Color(0xffa16207);
  static Color error(BuildContext c) =>
      oscuro(c) ? const Color(0xffff7f91) : const Color(0xffbe123c);
  static Color neutro(BuildContext c) =>
      oscuro(c) ? const Color(0xff94a3b8) : const Color(0xff475569);
  static List<Color> paleta(BuildContext c) =>
      oscuro(c)
          ? const [
            Color(0xff7dd3fc),
            Color(0xffc4b5fd),
            Color(0xff5eead4),
            Color(0xfffcd34d),
            Color(0xfffda4af),
            Color(0xffa5b4fc),
            Color(0xff86efac),
          ]
          : const [
            Color(0xff24476a),
            Color(0xff497594),
            Color(0xff326e70),
            Color(0xff65758b),
            Color(0xff557c82),
            Color(0xff445a78),
            Color(0xff527763),
          ];
}
