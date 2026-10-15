import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../application/dashboard_despachos_mensuales.dart';

class DashboardFacturacionSemanal extends ConsumerWidget {
  const DashboardFacturacionSemanal({super.key, required this.filtro});
  final FiltroDespachosMensuales filtro;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(facturacionSemanalProvider(filtro))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, __) => Column(
              children: [
                const Text(
                  'No se pudo consultar facturación. Verifica la migración SQL 098.',
                ),
                TextButton(
                  onPressed:
                      () => ref.invalidate(facturacionSemanalProvider(filtro)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
        data: (datos) => DonaFacturacionSemanal(datos: datos),
      );
}

class DonaFacturacionSemanal extends StatefulWidget {
  const DonaFacturacionSemanal({super.key, required this.datos});
  final List<Map<String, dynamic>> datos;
  @override
  State<DonaFacturacionSemanal> createState() => _DonaState();
}

class _DonaState extends State<DonaFacturacionSemanal> {
  String? semana;
  @override
  Widget build(BuildContext context) {
    if (widget.datos.isEmpty) {
      return const Text('Sin semanas disponibles en este período.');
    }
    final fila = widget.datos.firstWhere(
      (d) => d['semana'] == semana,
      orElse: () => widget.datos.last,
    );
    final total = (fila['total'] as num).toInt();
    final completas = (fila['completas'] as num).toInt();
    final pendientes = total - completas;
    final avance = total == 0 ? 0.0 : completas / total;
    const verde = Color(0xff158568);
    const naranja = Color(0xffbf6516);
    String rango(String valor) {
      final inicio = DateTime.parse(valor);
      final formato = DateFormat('dd/MM/yyyy');
      return '${formato.format(inicio)} – ${formato.format(inicio.add(const Duration(days: 4)))}';
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: fila['semana'] as String,
            items: [
              for (final d in widget.datos)
                DropdownMenuItem(
                  value: d['semana'] as String,
                  child: Text(
                    rango(d['semana'] as String),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => semana = v),
          ),
          const Text(
            'Lun–vie · Dentro del período filtrado',
            style: TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 12),
          Center(
            child: Semantics(
              label:
                  '$completas de $total despachos con facturación completada',
              child: SizedBox(
                height: 100,
                width: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: avance,
                        strokeWidth: 16,
                        color: verde,
                        backgroundColor:
                            total == 0 ? Colors.blueGrey.shade100 : naranja,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total == 0
                              ? '—'
                              : '${(avance * 100).toStringAsFixed(1)} %',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const Text(
                          'Completada',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Total de despachos: $total',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            '● Facturación completada: $completas',
            style: const TextStyle(color: verde, fontSize: 12),
          ),
          Text(
            '● Pendientes de completar: $pendientes',
            style: const TextStyle(color: naranja, fontSize: 12),
          ),
          if (total == 0)
            const Text(
              'Sin despachos en esta semana.',
              style: TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
