import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';

class OperarioActual extends ConsumerWidget {
  const OperarioActual({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreOperarioProvider);
    return InputDecorator(
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person_outline),
          suffixIcon: const Icon(Icons.lock_outline),
          helperText: 'Se registra con la cuenta que inició sesión.'),
      child: Text(nombre.isEmpty ? 'Identificando usuario…' : nombre),
    );
  }
}
