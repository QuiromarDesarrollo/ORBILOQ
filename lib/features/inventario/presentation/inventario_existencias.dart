import '../../../shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import '../../../data/inventario_repository.dart';

class InventarioExistencias extends StatelessWidget {
  const InventarioExistencias({
    super.key,
    required this.grupo,
    required this.datos,
    required this.pagina,
    required this.puedeEliminar,
    required this.puedeTransferir,
    required this.puedeEmpacar,
    required this.onOperar,
    required this.onRecargar,
    required this.onPagina,
    this.aviso,
  });
  final InventarioFila grupo;
  final Future<List<InventarioFila>> datos;
  final int pagina;
  final bool puedeEliminar, puedeTransferir, puedeEmpacar;
  final String? aviso;
  final void Function(String, InventarioFila) onOperar;
  final VoidCallback onRecargar;
  final ValueChanged<int> onPagina;
  static const navy = Color(0xFF0B3545);
  static const muted = Color(0xFF627985);

  num _n(InventarioFila r, String key) => (r[key] as num?) ?? 0;

  Widget _badge(String text, IconData icon, Color color, Color background) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _metrics(InventarioFila r, {bool summary = false}) {
    final fields = <String, String>{
      'cantidad': 'Transferidas',
      'libre': 'Libres',
      'reservado': 'Reservadas',
      'despachado': 'Despachadas',
      if (!summary) 'revertido': 'Revertidas',
    };
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : fields.length;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final f in fields.entries)
              Container(
                width: width,
                padding: EdgeInsets.all(summary ? 14 : 12),
                decoration: BoxDecoration(
                  color:
                      summary && f.key == 'libre'
                          ? const Color(0xFFE1F1E2)
                          : const Color(0xFFF5F8F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.value,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_n(r, f.key)}',
                      style: TextStyle(
                        fontSize: summary ? 24 : 19,
                        fontWeight: FontWeight.w600,
                        color:
                            f.key == 'libre'
                                ? const Color(0xFF147347)
                                : _n(r, f.key) == 0
                                ? muted
                                : navy,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _fecha(dynamic value) {
    final d = DateTime.tryParse('$value')?.toUtc();
    if (d == null) return '$value';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} UTC';
  }

  Widget _entrada(InventarioFila r) {
    final excel = r['entrada_excel'] == true;
    final motivo = '${r['motivo'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 8,
            children: [
              _badge(
                excel
                    ? 'Entrada por Excel'
                    : 'Transferencia desde OP ${r['numero_op']}',
                excel ? Icons.upload_file : Icons.swap_horiz,
                excel ? const Color(0xFF236235) : const Color(0xFF514692),
                excel ? const Color(0xFFE1F1E2) : const Color(0xFFEDE9FA),
              ),
              _badge(
                '${r['ubicacion']}',
                Icons.shelves,
                navy,
                const Color(0xFFF5F8F9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${r['producto'] ?? ''}',
            style: const TextStyle(fontSize: 13, color: navy),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _fecha(r['fecha']),
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _metrics(r),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Text(
            excel
                ? motivo.replaceFirst('Entrada por Excel · ', '')
                : 'Nota: $motivo',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (excel && puedeEliminar)
                OutlinedButton.icon(
                  onPressed:
                      _n(r, 'reservado') == 0 && _n(r, 'despachado') == 0
                          ? () => onOperar('eliminar_excel', r)
                          : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB63B3B),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE9A7A7)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar entrada Excel'),
                ),
              if (!excel && puedeTransferir && _n(r, 'libre') > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () => onOperar('revertir', r),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Devolver a OP original'),
                ),
              if (puedeEmpacar && _n(r, 'libre') > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => onOperar('empacar', r),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Seleccionar para despacho'),
                ),
            ],
          ),
          for (final v in r['reversiones'] as List? ?? [])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Reversión: ${v['cantidad']} · ${v['motivo']} · ${_fecha(v['fecha'])}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
          for (final d in r['despachos'] as List? ?? [])
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  'LE ${d['le'] ?? '—'} · OC ${d['oc']} · ${d['cantidad']} uds · ${d['fase']}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (d['fase'] == 'empacado' && puedeEmpacar)
                  TextButton(
                    onPressed:
                        () =>
                            onOperar('cancelar', Map<String, dynamic>.from(d)),
                    child: const Text('Liberar reserva'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 1040,
      height: 760,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (MediaQuery.sizeOf(context).width >= 600) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: navy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFC8DB00),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalle de existencias',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${grupo['ficha']}',
                            style: const TextStyle(fontSize: 14, color: muted),
                          ),
                          _badge(
                            'Talla ${grupo['talla'] ?? 'Sin talla'}',
                            Icons.straighten,
                            const Color(0xFF285887),
                            const Color(0xFFE4EFFB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${grupo['cliente']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: navy),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<InventarioFila>>(
              future: datos,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const WmsLoadingPanel();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No se pudieron cargar las existencias.'),
                        TextButton(
                          onPressed: onRecargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }
                final rows = snapshot.data ?? [];
                final totals = <String, dynamic>{
                  for (final k in [
                    'cantidad',
                    'libre',
                    'reservado',
                    'despachado',
                  ])
                    k: rows.fold<num>(0, (sum, r) => sum + _n(r, k)),
                };
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (aviso != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                aviso!,
                                style: const TextStyle(
                                  color: Color(0xFF147347),
                                ),
                              ),
                            ),
                          _metrics(totals, summary: true),
                          const SizedBox(height: 6),
                          const Text(
                            'Resumen de las entradas de esta página',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Movimientos de entrada',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: navy,
                                  ),
                                ),
                              ),
                              Text(
                                '${rows.length} registros',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No hay registros.'),
                            ),
                          for (final r in rows) _entrada(r),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rows.isEmpty
                                  ? '0 registros'
                                  : 'Mostrando ${pagina * 50 + 1} a ${pagina * 50 + rows.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ),
                          Text(
                            'Página ${pagina + 1}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                          IconButton(
                            tooltip: 'Anterior',
                            onPressed:
                                pagina > 0 ? () => onPagina(pagina - 1) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Siguiente',
                            onPressed:
                                rows.length == 50
                                    ? () => onPagina(pagina + 1)
                                    : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
