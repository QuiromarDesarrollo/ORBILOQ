import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

Future<void> showObservacionDialog(BuildContext context, ItemKardex k) {
  final obs = k.item.observacionOp;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'OBSERVACIÓN OP: ${k.item.op}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referencia: ${k.item.codigo}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              obs.isEmpty ? 'Sin observaciones registradas.' : obs,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
          child: const Text('ENTENDIDO'),
        ),
      ],
    ),
  );
}
