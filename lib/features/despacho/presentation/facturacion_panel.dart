import '../../../application/dashboard_despachos_mensuales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/facturacion_le.dart';

class FacturacionPanel extends ConsumerStatefulWidget {
  const FacturacionPanel({super.key});
  @override
  ConsumerState<FacturacionPanel> createState() => _FacturacionPanelState();
}

class _FacturacionPanelState extends ConsumerState<FacturacionPanel> {
  bool completas = false;
  String buscar = '';
  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(facturacionProvider(completas));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Facturadas sin completar'),
                selected: !completas,
                onSelected: (_) => setState(() => completas = false),
              ),
              ChoiceChip(
                label: const Text('Facturadas completas'),
                selected: completas,
                onSelected: (_) => setState(() => completas = true),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar LE, cliente, OC o remisión',
                ),
                onChanged:
                    (v) => setState(() => buscar = v.trim().toLowerCase()),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar facturación',
              onPressed: () => ref.invalidate(facturacionProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'LE con fecha de entrega al cliente. Completa remisión e ID OC para pasar a Facturadas completas.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: datos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo cargar Facturación. Verifica la conexión y la migración SQL 097.',
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(facturacionProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
            data: (lista) {
              final filas =
                  lista
                      .where(
                        (f) => ['le', 'cliente', 'oc', 'remision', 'id_oc'].any(
                          (k) => '${f[k] ?? ''}'.toLowerCase().contains(buscar),
                        ),
                      )
                      .toList();
              if (filas.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay LE en esta vista con los filtros actuales.',
                  ),
                );
              }
              return ListView.builder(
                itemCount: filas.length,
                itemBuilder:
                    (context, i) => _FacturaCard(
                      key: ValueKey(
                        '${filas[i]['id']}:${filas[i]['revision']}:${filas[i]['version']}:${filas[i]['version_seguimiento']}',
                      ),
                      fila: filas[i],
                    ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FacturaCard extends ConsumerStatefulWidget {
  const _FacturaCard({super.key, required this.fila});
  final Map<String, dynamic> fila;
  @override
  ConsumerState<_FacturaCard> createState() => _FacturaCardState();
}

class _FacturaCardState extends ConsumerState<_FacturaCard> {
  late final TextEditingController remision;
  late final TextEditingController idOc;
  bool guardando = false;
  String? error;
  @override
  void initState() {
    super.initState();
    remision = TextEditingController(text: '${widget.fila['remision'] ?? ''}');
    idOc = TextEditingController(text: '${widget.fila['id_oc'] ?? ''}');
  }

  @override
  void dispose() {
    remision.dispose();
    idOc.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final repo = ref.read(facturacionRepositoryProvider);
    if (repo == null) return;
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await repo.guardar(widget.fila, remision.text, idOc.text);
      if (!mounted) return;
      ref.invalidate(facturacionProvider);
      ref.invalidate(facturacionSemanalProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Facturación guardada. La LE se organiza según sus campos completos.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'No se guardaron los cambios: $e');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fila;
    final ids = (f['ids_erp'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lista de empaque ${f['le']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${f['cliente']} · Entrega: ${f['recibido']}'),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final width =
                    c.maxWidth >= 650 ? (c.maxWidth - 16) / 2 : c.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: remision,
                        enabled: !guardando,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'N° de remisión *',
                          counterText: '',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: idOc,
                        enabled: !guardando,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'ID OC *',
                          counterText: '',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: Text(
                        'Orden de compra: ${f['oc'] == '' ? 'Sin registro' : f['oc']}',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: Text('Lista de empaque: ${f['le']}'),
                    ),
                  ],
                );
              },
            ),
            if (ids.length > 1)
              Text(
                'Esta LE reúne varios ID OC del ERP: ${ids.join(', ')}. Confirma el ID OC que corresponde.',
              ),
            if (ids.isEmpty && (f['id_oc'] ?? '') == '')
              const Text(
                'Sin ID OC en la hoja Orden del ERP. Puedes diligenciarlo manualmente.',
              ),
            if ((f['oc'] ?? '').toString().trim().isEmpty)
              const Text(
                'Falta la orden de compra; esta LE permanecerá sin completar.',
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: guardando ? null : guardar,
                icon: const Icon(Icons.save_outlined),
                label: Text(guardando ? 'Guardando…' : 'Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
