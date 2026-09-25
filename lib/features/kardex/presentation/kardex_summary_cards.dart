import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

class KardexSummaryCards extends ConsumerWidget {
  const KardexSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(kardexResumenProvider);
    final esProduccion = ref.watch(rolProvider) == Rol.produccion;
    final pal = palOf(context);

    final tarjetas = <_SummaryCard>[
      _SummaryCard(
        titulo: 'UNIDADES PEDIDAS',
        valor: '${r.unidadesPedidas}',
        subtitulo: '+${r.cantidadOrdenes} órdenes',
        subtituloColor: pal.textSecondary,
        icono: Icons.bar_chart_rounded,
        acento: AppColors.tealPrimary,
      ),
      _SummaryCard(
        titulo: esProduccion ? 'ENTREGADO A LOGÍSTICA' : 'ENTREGADO POR PRODUCCIÓN',
        valor: '${r.enProduccion}',
        subtitulo: '${r.porcentajeProduccion.toStringAsFixed(1)}% del total',
        subtituloColor: pal.textSecondary,
        icono: Icons.autorenew_rounded,
        acento: AppColors.blueChip,
      ),
      _SummaryCard(
        titulo: esProduccion ? 'PENDIENTE POR ENTREGAR' : 'PENDIENTE POR PRODUCCIÓN',
        valor: '${r.pendientePorEntregar}',
        subtitulo: r.pendientePorEntregar > 0 ? 'Requiere seguimiento' : 'Al día',
        subtituloColor: r.pendientePorEntregar > 0 ? pal.chipRed : pal.chipGreen,
        icono: Icons.local_shipping_rounded,
        acento: AppColors.actionOrange,
      ),
      _SummaryCard(
        titulo: 'PRODUCTO NO CONFORME',
        valor: '${r.totalNoConforme}',
        subtitulo: r.totalNoConforme > 0 ? 'Pendiente por reprocesar' : 'Al día',
        subtituloColor: r.totalNoConforme > 0 ? pal.chipRed : pal.chipGreen,
        icono: Icons.report_problem_rounded,
        acento: AppColors.alertRed,
      ),
      if (!esProduccion) ...[
        _SummaryCard(
          titulo: 'RECIBIDO EN BODEGA',
          valor: '${r.recibidoEnBodega}',
          subtitulo: '${r.porcentajeBodega.toStringAsFixed(1)}% del total',
          subtituloColor: pal.textSecondary,
          icono: Icons.warehouse_rounded,
          acento: AppColors.actionGreen,
        ),
        _SummaryCard(
          titulo: 'PENDIENTE POR DESPACHAR',
          valor: '${r.pendientePorDespachar}',
          subtitulo: r.pendientePorDespachar > 0 ? 'Requiere seguimiento' : 'Al día',
          subtituloColor: r.pendientePorDespachar > 0 ? pal.chipRed : pal.chipGreen,
          icono: Icons.inventory_2_rounded,
          acento: AppColors.accentCyan,
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final n = tarjetas.length;
        final anchoTarjeta = constraints.maxWidth >= 900
            ? (constraints.maxWidth - (n - 1) * 16) / n
            : constraints.maxWidth >= 500
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final t in tarjetas) SizedBox(width: anchoTarjeta, child: t)],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.subtituloColor,
    required this.icono,
    required this.acento,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color subtituloColor;
  final IconData icono;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: acento.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icono, size: 16, color: acento),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: pal.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 12, color: subtituloColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
