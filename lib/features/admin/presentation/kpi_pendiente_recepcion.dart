import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Estado acumulado de las mismas líneas vigentes de OP, filtradas por cliente.
class KpiPendienteRecepcion extends StatelessWidget {
  const KpiPendienteRecepcion({
    super.key,
    required this.solicitadas,
    required this.recibidas,
  });
  final int solicitadas, recibidas;

  @override
  Widget build(BuildContext context) {
    final formato = NumberFormat.decimalPattern('es_CO');
    final pendiente = solicitadas - recibidas;
    final avance = solicitadas > 0 ? recibidas / solicitadas : null;
    final porcentaje =
        avance == null ? '—' : '${formato.format(avance * 100)} %';
    Widget dato(String etiqueta, String valor) => Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            etiqueta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          flex: 2,
          child: Text(
            valor,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    return Tooltip(
      message:
          'Unidades pendientes de recepción = solicitadas − recibidas válidas del Kardex. '
          'Estado actual de las OP vigentes del cliente seleccionado; no se limita al período de movimientos. '
          'Sin unidades solicitadas no se calcula avance. Un pendiente negativo indica exceso de recepción.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  formato.format(pendiente),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xffb7791f),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Semantics(
                  label: 'Avance de recepción',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Avance', style: TextStyle(fontSize: 10)),
                      Text(
                        porcentaje,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff158568),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          dato('Solicitadas', formato.format(solicitadas)),
          dato('Recibidas válidas', formato.format(recibidas)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (avance ?? 0).clamp(0.0, 1.0),
              minHeight: 4,
              color: const Color(0xff158568),
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}
