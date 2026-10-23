import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';

/// Saludo común basado exclusivamente en la sesión activa.
class BienvenidaUsuario extends ConsumerWidget {
  const BienvenidaUsuario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre =
        ref.watch(usarSupabaseProvider)
            ? ref.watch(usuarioSesionProvider).asData?.value?.nombre.trim() ??
                ''
            : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(
        TextSpan(
          text: nombre.isEmpty ? 'Bienvenido' : 'Bienvenido, ',
          children: [
            if (nombre.isNotEmpty)
              TextSpan(
                text: nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
