import 'package:flutter/material.dart';

class WmsEmptyState extends StatelessWidget {
  const WmsEmptyState(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.search_rounded});
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ]))));
}
