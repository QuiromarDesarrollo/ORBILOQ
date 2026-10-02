import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';

class OperarioActual extends ConsumerWidget {
  const OperarioActual({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreOperarioProvider);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.account_circle_outlined,
              size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(nombre.isEmpty ? 'Identificando usuario…' : nombre,
                    style: Theme.of(context).textTheme.titleSmall),
              ])),
          const Tooltip(
              message: 'Se registra con la cuenta que inició sesión.',
              child: Icon(Icons.lock_outline, size: 16)),
        ]));
  }
}
