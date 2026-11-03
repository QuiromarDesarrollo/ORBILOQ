part of 'masiva_page.dart';

extension _MasivaReception on _MasivaPageState {
  Widget _receptionRecords(double width) {
    if (_receiptOrder != null) {
      final current = mapaMasiva(_data['pedido']);
      final order = current.isEmpty ? _receiptOrder! : current;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panel(
            child: Wrap(
              spacing: 18,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed:
                      !_scanning && !_scanAlert
                          ? () => _chooseReceipt(null, preserveFilters: true)
                          : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver a órdenes'),
                ),
                Text(
                  'OC ${order['pedido']} · ${order['proveedor']}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ('${order['horario'] ?? ''}'.isNotEmpty)
                  Text(
                    'Horario: ${order['horario']}',
                    style: const TextStyle(color: _muted),
                  ),
                if ('${order['novedad'] ?? ''}'.isNotEmpty)
                  Text(
                    'Novedad: ${order['novedad']}',
                    style: const TextStyle(color: _muted),
                  ),
              ],
            ),
          ),
          if (_rows.isEmpty)
            _empty(
              'No hay prendas con esa búsqueda',
              'Limpia la búsqueda para ver las referencias de esta orden.',
            )
          else
            _records(width),
        ],
      );
    }
    final options = mapaMasiva(_data['opciones']);
    return _panel(
      padding: 0,
      child: MasivaRecepcionTabla(
        filas: _rows,
        filtros: _receptionFilters,
        opciones: {
          for (final e in options.entries)
            e.key: (e.value as List? ?? []).map((v) => '$v').toList(),
        },
        onFiltrosChanged: (filters) {
          _redraw(() {
            _receptionFilters
              ..clear()
              ..addAll(filters);
            _page = 1;
          });
          _load();
        },
        onAbrir: (order) => _chooseReceipt(order, preserveFilters: true),
      ),
    );
  }

  Future<void> _editReceiptOrder() async {
    final latest = mapaMasiva(_data['pedido']);
    final order = latest.isEmpty ? _receiptOrder! : latest;
    final v = await _form(
      'Horario y novedad',
      'OC ${order['pedido']} · ${order['proveedor']}\nEstos datos no modifican las cantidades del plan ni del inventario.',
      [
        _Field(
          'horario',
          'Horario',
          initial: '${order['horario'] ?? ''}',
          required: false,
          hint: 'Ej. 8:00 AM a 10:00 AM',
        ),
        _Field(
          'novedad',
          'Novedad',
          initial: '${order['novedad'] ?? ''}',
          required: false,
          multiline: true,
        ),
      ],
    );
    if (v == null || !mounted) return;
    await _execute('configurar_recepcion', {
      'proveedor': order['proveedor'],
      'pedido': order['pedido'],
      ...v,
    });
  }
}
