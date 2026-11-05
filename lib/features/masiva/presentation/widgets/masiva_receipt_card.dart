import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Recepción pendiente: el resumen permanece compacto durante el escaneo.
/// El controlador y la confirmación siguen perteneciendo al flujo de recepción.
class MasivaReceiptCard extends StatefulWidget {
  const MasivaReceiptCard({
    super.key,
    required this.itemId,
    required this.sku,
    required this.description,
    required this.provider,
    required this.order,
    required this.support,
    required this.note,
    required this.expected,
    required this.received,
    required this.quantity,
    required this.enabled,
    required this.onRecount,
    required this.onRemove,
    required this.onConfirm,
  });

  final String itemId, sku, description, provider, order, support, note;
  final int expected, received;
  final TextEditingController quantity;
  final bool enabled;
  final VoidCallback onRecount, onRemove, onConfirm;

  @override
  State<MasivaReceiptCard> createState() => _MasivaReceiptCardState();
}

class _MasivaReceiptCardState extends State<MasivaReceiptCard> {
  bool _expanded = false;

  int get _count => int.tryParse(widget.quantity.text) ?? 0;
  int get _maximum => widget.expected - widget.received;
  bool get _valid => _count > 0 && _count <= _maximum;

  void _change(int value) => widget.quantity.text = '$value';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.quantity,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFDCE7EC)),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label:
                    '${_expanded ? 'Contraer' : 'Expandir'} tarjeta de SKU ${widget.sku}',
                child: InkWell(
                  key: ValueKey('toggle-receipt-${widget.itemId}'),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        final arrow = SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            color: scheme.onSurfaceVariant,
                          ),
                        );
                        if (constraints.maxWidth >= 760 * scale) {
                          return Row(
                            children: [
                              Expanded(child: _identity(context)),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 220,
                                child: _summaryProgress(context),
                              ),
                              const SizedBox(width: 16),
                              _pending(context),
                              const SizedBox(width: 8),
                              arrow,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: _identity(context)),
                                arrow,
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (constraints.maxWidth >= 360 * scale)
                              Row(
                                children: [
                                  Expanded(child: _summaryProgress(context)),
                                  const SizedBox(width: 16),
                                  _pending(context),
                                ],
                              )
                            else ...[
                              _summaryProgress(context),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _pending(context),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _details(context),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _identity(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SKU ${widget.sku}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' · ${widget.description}'),
            ],
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.provider} · OC ${widget.order} · Remisión ${widget.support}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _summaryProgress(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 2,
        children: [
          Text('Recibidas', style: Theme.of(context).textTheme.bodySmall),
          Text(
            '${widget.received} de ${widget.expected}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      _progress(context, height: 6),
    ],
  );

  Widget _pending(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: (_valid ? AppColors.lima : scheme.error).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _valid ? '+$_count por confirmar' : 'Revisar cantidad',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _valid ? scheme.onSurface : scheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _progress(BuildContext context, {double height = 8}) {
    final total = widget.expected;
    final forecast =
        total > 0 ? ((widget.received + _count) / total).clamp(0.0, 1.0) : 0.0;
    final received =
        total > 0 ? (widget.received / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          LinearProgressIndicator(
            value: forecast,
            color: AppColors.lima,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            minHeight: height,
          ),
          LinearProgressIndicator(
            value: received,
            color: AppColors.petroleo,
            backgroundColor: Colors.transparent,
            minHeight: height,
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    final theme = Theme.of(context);
    final expected = widget.expected;
    final percentage =
        expected > 0
            ? (((widget.received + _count) / expected).clamp(0.0, 1.0) * 100)
                .round()
            : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.note.isNotEmpty) ...[
          Text(widget.note, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Plan $expected'),
            Text('Recibidas ${widget.received}'),
            Text('Límite máximo $_maximum'),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text('Avance de recepción'),
            Text(
              '${widget.received + _count} de $expected uds · $percentage %',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _progress(context),
        const SizedBox(height: 6),
        Text(
          'La franja lima es lo que sumarás al confirmar.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text('Cantidad a recibir', style: theme.textTheme.titleMedium),
        Text('Máximo $_maximum unidades', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Disminuir cantidad',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed:
                  widget.enabled && _count > 1
                      ? () => _change(_count - 1)
                      : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                key: ValueKey('receipt-quantity-${widget.itemId}'),
                controller: widget.quantity,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  isDense: true,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Aumentar cantidad',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed:
                  widget.enabled && _count < _maximum
                      ? () => _change(_count + 1)
                      : null,
              icon: const Icon(Icons.add, size: 18),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.lima,
                foregroundColor: AppColors.petroleo,
              ),
              onPressed:
                  widget.enabled && _maximum > 0
                      ? () => _change(_maximum)
                      : null,
              child: Text('Todo ($_maximum)'),
            ),
          ],
        ),
        if (!_valid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ingresa una cantidad entre 1 y $_maximum.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.enabled ? widget.onRecount : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Recontar'),
            ),
            IconButton.outlined(
              tooltip: 'Quitar tarjeta',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: widget.enabled ? widget.onRemove : null,
              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
            ),
            FilledButton.icon(
              key: ValueKey('confirm-receipt-${widget.itemId}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.petroleo,
                foregroundColor: Colors.white,
              ),
              onPressed: widget.enabled && _valid ? widget.onConfirm : null,
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Confirmar recepción ($_count)',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
