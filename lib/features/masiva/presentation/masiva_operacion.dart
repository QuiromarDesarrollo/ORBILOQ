part of 'masiva_page.dart';

class _ReceiptDraft {
  _ReceiptDraft(this.item, this.operation, this.support, this.note);
  MasivaJson item;
  final String operation, support, note;
  final quantity = TextEditingController(text: '1');
  int get count => int.tryParse(quantity.text) ?? 0;
  int get maximum =>
      numeroMasiva(item['esperado']) - numeroMasiva(item['recibido']);
}

extension _MasivaOperation on _MasivaPageState {
  Widget _operationStats(List<(String, String, String)> values) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620 ? 2 : 4;
          final cell = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              for (final value in values)
                SizedBox(
                  width: cell,
                  child: _panel(
                    padding: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.$1,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value.$2,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.$3,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Future<void> _chooseReceipt(
    MasivaJson? order, {
    String? supplier,
    bool preserveFilters = false,
  }) async {
    if (_scanning || _scanAlert) return;
    _redraw(() {
      _receiptOrder = order;
      _receiptSupplier = supplier ?? order?['proveedor']?.toString();
      _receiptSupport.clear();
      _receiptNote.clear();
      _receiptSku.clear();
      _receiptMessage = null;
      _receiptError = false;
      _receiptReads = 0;
      _page = 1;
      _search.clear();
      if (!preserveFilters) _receptionFilters.clear();
      if (!preserveFilters && order == null && _receiptSupplier != null) {
        _receptionFilters['proveedor'] = {_receiptSupplier!};
      }
    });
    await _load();
  }

  Future<void> _openReceiptStation({MasivaJson? initialRow}) async {
    if (_receiptDialogOpen ||
        _busy != null ||
        _scanning ||
        _operationId == null) {
      return;
    }
    if (initialRow != null) {
      if (_receiptOrder?['proveedor'] != initialRow['proveedor'] ||
          _receiptOrder?['pedido'] != initialRow['pedido']) {
        await _chooseReceipt({
          'proveedor': initialRow['proveedor'],
          'pedido': initialRow['pedido'],
        }, preserveFilters: true);
      }
      _receiptSku.text = '${initialRow['sku']}';
    }
    if (!mounted) return;
    _receiptTab = 0;
    _receiptHistoryPage = 1;
    _receiptHistorySearch.clear();
    _receiptHistory = [];
    _receiptHistoryTotal = 0;
    _receiptHistoryError = null;
    ++_receiptHistoryEpoch;
    _receiptDialogOpen = true;
    _dialog = true;
    try {
      await showWmsDialog<void>(
        context,
        (dialogContext) => ValueListenableBuilder<int>(
          valueListenable: _receiptRevision,
          builder: (context, _, child) {
            final blocked =
                _busy != null || _scanning || _scanAlert || _loading;
            final drafts =
                _receiptDrafts
                    .where((d) => d.operation == _operationId)
                    .toList();
            return Theme(
              data: _masivaTheme(),
              child: PopScope(
                canPop: !blocked,
                child: WmsDialogShell(
                  title: 'Recepción de prendas',
                  draggable: true,
                  subtitle: 'Operario: ${ref.read(nombreOperarioProvider)}',
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.lima,
                  expand: true,
                  mobileCatalog: true,
                  maxWidth: 1200,
                  canClose: !blocked,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              _receiptTabButton(
                                0,
                                'Recibir prendas',
                                Icons.qr_code_scanner,
                              ),
                              _receiptTabButton(1, 'Historial', Icons.history),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child:
                                _receiptTab == 1
                                    ? _receiptHistoryView()
                                    : SingleChildScrollView(
                                      key: const ValueKey(
                                        'receipt-dialog-scroll',
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (_repo.movimientoPendiente != null)
                                            _notice(
                                              'Hay una recepción sin confirmación de red. Recupera su respuesta antes de continuar.',
                                              Icons.sync_problem,
                                              action: TextButton(
                                                onPressed:
                                                    blocked
                                                        ? null
                                                        : () => _work(
                                                          'Recuperando recepción…',
                                                          () async {
                                                            await _repo
                                                                .recuperarConfirmacion();
                                                          },
                                                        ),
                                                child: const Text('Recuperar'),
                                              ),
                                            ),
                                          if (_error != null)
                                            _notice(
                                              _error!,
                                              Icons.wifi_off,
                                              action: TextButton(
                                                onPressed:
                                                    blocked
                                                        ? null
                                                        : () => _load(),
                                                child: const Text('Reintentar'),
                                              ),
                                            ),
                                          LayoutBuilder(
                                            builder:
                                                (context, constraints) =>
                                                    _receptionStation(
                                                      constraints.maxWidth,
                                                      inDialog: true,
                                                    ),
                                          ),
                                          if (drafts.isEmpty &&
                                              _receiptMessage == null)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 28,
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.qr_code_scanner,
                                                    size: 36,
                                                    color: _muted,
                                                  ),
                                                  SizedBox(height: 12),
                                                  Text(
                                                    'Escanea una prenda para empezar',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _ink,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Las tarjetas de las prendas aparecerán aquí.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                          ),
                          if (_receiptTab == 0) ...[
                            const Divider(height: 20),
                            AnimatedBuilder(
                              animation: Listenable.merge(
                                drafts.map((d) => d.quantity),
                              ),
                              builder:
                                  (context, _) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${drafts.length} ${drafts.length == 1 ? 'prenda' : 'prendas'} · ${drafts.fold<int>(0, (sum, d) => sum + d.count)} ${drafts.fold<int>(0, (sum, d) => sum + d.count) == 1 ? 'unidad' : 'unidades'} por confirmar\nLas tarjetas pendientes se conservan al cerrar esta ventana.',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (_busy != null || _loading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: .94),
                            child: Center(
                              child: WmsLoadingPanel(
                                label: _busy ?? 'Actualizando recepción…',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      ++_receiptHistoryEpoch;
      _receiptDialogOpen = false;
      _dialog = false;
      _receiptFocus.unfocus();
      if (mounted) await _load(silent: true);
    }
  }

  Widget _receiptTabButton(int tab, String label, IconData icon) {
    final active = _receiptTab == tab;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          key: ValueKey('receipt-tab-$tab'),
          onTap: () {
            if (_receiptTab == tab ||
                _scanning ||
                _scanAlert ||
                _busy != null) {
              return;
            }
            _receiptFocus.unfocus();
            _redraw(() => _receiptTab = tab);
            if (tab == 1) {
              _loadReceiptHistory();
            } else if (_receiptOrder != null && _editable) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _receiptDialogOpen && _receiptTab == 0) {
                  _receiptFocus.requestFocus();
                }
              });
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? _lime : _line,
                  width: active ? 3 : 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: active ? _ink : _muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? _ink : _muted,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadReceiptHistory({int page = 1}) async {
    final operation = _operationId;
    if (operation == null) return;
    final serial = ++_receiptHistoryEpoch;
    _redraw(() {
      _receiptHistoryLoading = true;
      _receiptHistoryError = null;
    });
    try {
      final result = await _repo.consultarHistorialRecepcion(
        operacion: operation,
        buscar: _receiptHistorySearch.text.trim(),
        pagina: page,
      );
      if (!mounted ||
          !_receiptDialogOpen ||
          serial != _receiptHistoryEpoch ||
          operation != _operationId) {
        return;
      }
      _redraw(() {
        _receiptHistory = filasMasiva(result['filas']);
        _receiptHistoryTotal = numeroMasiva(result['total']);
        _receiptHistoryPage = page;
        _receiptHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted || !_receiptDialogOpen || serial != _receiptHistoryEpoch) {
        return;
      }
      _redraw(() {
        _receiptHistoryError = errorMasiva(e);
        _receiptHistoryLoading = false;
      });
    }
  }

  String _receiptHistoryDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return 'Fecha sin registrar';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _receiptHistoryView() => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth < 600;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: mobile ? constraints.maxWidth : 360,
                child: TextField(
                  key: const ValueKey('receipt-history-search'),
                  controller: _receiptHistorySearch,
                  onSubmitted: (_) => _loadReceiptHistory(),
                  decoration: const InputDecoration(
                    hintText: 'Buscar SKU, prenda, OC o proveedor',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _receiptHistoryLoading ? null : () => _loadReceiptHistory(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
              Text(
                '$_receiptHistoryTotal movimientos',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                _receiptHistoryLoading
                    ? const Center(
                      child: WmsLoadingPanel(label: 'Cargando movimientos…'),
                    )
                    : _receiptHistoryError != null
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _receiptHistoryError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed:
                                () => _loadReceiptHistory(
                                  page: _receiptHistoryPage,
                                ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                    : _receiptHistory.isEmpty
                    ? WmsEmptyState(
                      title:
                          _receiptHistorySearch.text.trim().isEmpty
                              ? 'Sin movimientos de recepción'
                              : 'Sin resultados para la búsqueda',
                      message:
                          _receiptHistorySearch.text.trim().isEmpty
                              ? 'Las prendas confirmadas aparecerán aquí.'
                              : 'Prueba con otro SKU, prenda, OC o proveedor.',
                      icon: Icons.history,
                    )
                    : ListView.separated(
                      key: const ValueKey('receipt-history-list'),
                      itemCount: _receiptHistory.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _receiptHistory[index];
                        return _panel(
                          padding: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'SKU ${row['sku']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                  _pill(
                                    '+${numeroMasiva(row['cantidad'])} unidades',
                                  ),
                                  Text(
                                    _receiptHistoryDate(row['creado']),
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text('${row['descripcion'] ?? ''}'),
                              const SizedBox(height: 5),
                              Text(
                                '${row['proveedor']} · OC ${row['pedido']} · ${row['operario']}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                              if ('${row['soporte'] ?? ''}'.isNotEmpty)
                                Text(
                                  'Remisión: ${row['soporte']}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          if (_receiptHistoryTotal > 50) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed:
                      _receiptHistoryLoading || _receiptHistoryPage <= 1
                          ? null
                          : () => _loadReceiptHistory(
                            page: _receiptHistoryPage - 1,
                          ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Página $_receiptHistoryPage de ${(_receiptHistoryTotal / 50).ceil()}',
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Página siguiente',
                  onPressed:
                      _receiptHistoryLoading ||
                              _receiptHistoryPage * 50 >= _receiptHistoryTotal
                          ? null
                          : () => _loadReceiptHistory(
                            page: _receiptHistoryPage + 1,
                          ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );

  Widget _receptionStation(double width, {bool inDialog = false}) {
    final supplier =
        _receiptOrder?['proveedor']?.toString() ?? _receiptSupplier;
    final suppliers =
        _receiptOrders.map((p) => '${p['proveedor']}').toSet().toList()..sort();
    final orders =
        _receiptOrders.where((p) => p['proveedor'] == supplier).toList();
    final selected =
        orders
            .where((p) => p['pedido'] == _receiptOrder?['pedido'])
            .firstOrNull;
    final scope =
        selected != null
            ? [selected]
            : supplier == null
            ? _receiptOrders
            : orders;
    final planned = scope.fold<int>(
      0,
      (n, p) => n + numeroMasiva(p['esperado']),
    );
    final received = scope.fold<int>(
      0,
      (n, p) => n + numeroMasiva(p['recibido']),
    );
    final enabled = !_scanning && !_scanAlert && _busy == null && !_loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!inDialog)
          _operationStats([
            (
              'Plan seleccionado',
              '$planned',
              selected == null
                  ? 'Selecciona proveedor y orden'
                  : 'OC ${selected['pedido']}',
            ),
            ('Recibidas', '$received', 'Ingresos confirmados'),
            ('Pendientes', '${planned - received}', 'Límite de recepción'),
            (
              'Lecturas de esta sesión',
              '$_receiptReads',
              'Una lectura = una unidad',
            ),
          ]),
        if (inDialog)
          _panel(
            padding: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner, color: _ink),
                    const Text(
                      'Puesto de recepción',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    _pill(
                      _scanning
                          ? 'Buscando prenda…'
                          : selected == null
                          ? 'Selecciona una orden'
                          : 'Escaneo por SKU',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final w =
                        c.maxWidth < 660 ? c.maxWidth : (c.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: w,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('receipt-supplier-$supplier'),
                            initialValue:
                                suppliers.contains(supplier) ? supplier : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Proveedor',
                            ),
                            items:
                                suppliers
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                enabled
                                    ? (v) => _chooseReceipt(null, supplier: v)
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              'receipt-order-$supplier-${selected?['pedido']}',
                            ),
                            initialValue: selected?['pedido']?.toString(),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Orden de compra',
                            ),
                            items:
                                orders
                                    .map(
                                      (o) => DropdownMenuItem(
                                        value: '${o['pedido']}',
                                        child: Text(
                                          '${o['pedido']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                enabled
                                    ? (v) => _chooseReceipt(
                                      orders.firstWhere(
                                        (o) => o['pedido'] == v,
                                      ),
                                    )
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: TextField(
                            controller: _receiptSupport,
                            enabled: enabled && selected != null,
                            maxLength: 240,
                            decoration: const InputDecoration(
                              labelText: 'Remisión o soporte',
                              counterText: '',
                            ),
                            onSubmitted: (_) => _receiptFocus.requestFocus(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Novedad de recepción (opcional)',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  children: [
                    TextField(
                      controller: _receiptNote,
                      enabled: enabled,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Novedad',
                        hintText:
                            'Se guardará con las nuevas tarjetas de esta recepción',
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: width < 600 ? double.infinity : 380,
                      child: TextField(
                        key: const ValueKey('masiva-recepcion-sku'),
                        controller: _receiptSku,
                        focusNode: _receiptFocus,
                        enabled:
                            selected != null &&
                            (_editable || _scanning) &&
                            !_scanAlert,
                        autocorrect: false,
                        enableSuggestions: false,
                        onEditingComplete: () {},
                        decoration: InputDecoration(
                          labelText: 'Escanea o escribe el SKU',
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          suffixIcon: IconButton(
                            key: const ValueKey('masiva-recepcion-camera'),
                            tooltip: 'Leer SKU con cámara',
                            onPressed:
                                selected != null &&
                                        _editable &&
                                        !_scanning &&
                                        !_scanAlert &&
                                        !_loading
                                    ? () => _camera(reception: true)
                                    : null,
                            icon: const Icon(Icons.photo_camera_outlined),
                          ),
                        ),
                        onSubmitted: (_) => _scanReceipt(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          selected != null &&
                                  _editable &&
                                  !_scanning &&
                                  !_scanAlert
                              ? _scanReceipt
                              : null,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Agregar +1'),
                    ),
                    if (_scanning && !_scanAlert) const WmsLoader(width: 42),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Escanea para sumar a una tarjeta o escribe la cantidad. El inventario se actualiza al confirmar la recepción. En calzado, una unidad es un par.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                if (_receiptMessage != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color:
                            _receiptError
                                ? const Color(0xFFFFF0EF)
                                : const Color(0xFFE8F5ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _receiptMessage!,
                        style: TextStyle(
                          color:
                              _receiptError
                                  ? const Color(0xFFB93636)
                                  : const Color(0xFF17764C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                for (final draft in _receiptDrafts.where(
                  (d) => d.operation == _operationId,
                ))
                  _receiptCard(draft),
                if (planned > 0) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: received / planned,
                    color: _lime,
                    backgroundColor: _line,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$received de $planned recibidas · ${(received / planned * 100).round()}%',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _scanReceipt() async {
    final code = _receiptSku.text.trim();
    if (code.isEmpty ||
        _receiptOrder == null ||
        (!_editable && !_scanning) ||
        _scanAlert) {
      return;
    }
    final support = _receiptSupport.text.trim();
    if (support.isEmpty) {
      _redraw(() {
        _receiptError = true;
        _receiptMessage =
            'Registra la remisión o soporte antes de recibir prendas.';
      });
      return;
    }
    _receiptSku.clear();
    _scanQueue.add(code);
    if (_scanning) return;
    final operation = _operationId!;
    final provider = '${_receiptOrder!['proveedor']}';
    final order = '${_receiptOrder!['pedido']}';
    ++_epoch;
    _redraw(() => _scanning = true);
    try {
      while (mounted && _scanQueue.isNotEmpty) {
        final sku = _scanQueue.removeAt(0);
        try {
          final lookup = await _repo.consultarRecepcion(
            operacion: operation,
            proveedor: provider,
            pedido: order,
            filtros: {
              'sku': {sku},
            },
          );
          final matches =
              filasMasiva(lookup['filas'])
                  .where(
                    (a) =>
                        a['sku'] == sku &&
                        a['proveedor'] == provider &&
                        a['pedido'] == order,
                  )
                  .toList();
          if (matches.length != 1) {
            throw MasivaError(
              'SKU $sku: no pertenece a $provider · OC $order. Revisa la prenda; no se registró esta lectura.',
            );
          }
          final item = matches.single;
          final existing =
              _receiptDrafts
                  .where(
                    (d) =>
                        d.operation == operation && d.item['id'] == item['id'],
                  )
                  .firstOrNull;
          if (existing != null &&
              (existing.support != support ||
                  existing.note != _receiptNote.text.trim())) {
            throw const MasivaError(
              'Esta prenda tiene una tarjeta con otra remisión o novedad. Confirma o quita esa tarjeta antes de cambiar el soporte.',
            );
          }
          final count = existing?.count ?? 0;
          if (count + numeroMasiva(item['recibido']) >=
              numeroMasiva(item['esperado'])) {
            throw MasivaError(
              'SKU $sku: alcanzaste toda la cantidad autorizada. Revisa la tarjeta; no se agregó la unidad adicional.',
            );
          }
          _redraw(() {
            if (existing == null) {
              _receiptDrafts.insert(
                0,
                _ReceiptDraft(
                  item,
                  operation,
                  support,
                  _receiptNote.text.trim(),
                ),
              );
            } else {
              existing.item = item;
              existing.quantity.text = '${count + 1}';
              _receiptDrafts.remove(existing);
              _receiptDrafts.insert(0, existing);
            }
            _receiptReads++;
            _receiptError = false;
            _receiptMessage =
                '$sku · +1 agregada a la tarjeta, pendiente de confirmar';
          });
        } catch (e) {
          final pending = _scanQueue.length;
          _scanQueue.clear();
          _redraw(() {
            _receiptError = true;
            _scanAlert = true;
            _receiptMessage =
                '${errorMasiva(e)}${pending > 0 ? '\nSe detuvieron $pending lecturas posteriores. Vuelve a escanearlas después de revisar.' : ''}';
          });
          if (mounted) {
            await mostrarAvisoContenido(
              context,
              Text(_receiptMessage!),
              error: true,
              tituloPersonalizado: 'Revisar recepción',
              requiereConfirmacion: true,
            );
          }
          _redraw(() => _scanAlert = false);
          break;
        }
      }
    } finally {
      _scanQueue.clear();
      _redraw(() => _scanning = false);
      if (mounted && _receiptDialogOpen && !_cameraOpen) {
        _receiptFocus.requestFocus();
      }
    }
  }

  Widget _receiptCard(_ReceiptDraft draft) => MasivaReceiptCard(
    key: ValueKey('receipt-card-${draft.item['id']}'),
    itemId: '${draft.item['id']}',
    sku: '${draft.item['sku']}',
    description: '${draft.item['descripcion']}',
    provider: '${draft.item['proveedor']}',
    order: '${draft.item['pedido']}',
    support: draft.support,
    note: draft.note,
    expected: numeroMasiva(draft.item['esperado']),
    received: numeroMasiva(draft.item['recibido']),
    quantity: draft.quantity,
    enabled: _editable && !_scanning && !_scanAlert,
    onRecount: () {
      draft.quantity.text = '1';
      _receiptFocus.requestFocus();
    },
    onRemove: () {
      _redraw(() => _receiptDrafts.remove(draft));
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => draft.quantity.dispose(),
      );
    },
    onConfirm: () => _confirmReceipt(draft),
  );

  Future<void> _confirmReceipt(_ReceiptDraft draft) async {
    if (!_editable || draft.count < 1 || draft.count > draft.maximum) return;
    final quantity = draft.count;
    await _work('Confirmando recepción…', () async {
      try {
        final current = await _repo.consultarRecepcion(
          operacion: draft.operation,
          proveedor: '${draft.item['proveedor']}',
          pedido: '${draft.item['pedido']}',
          filtros: {
            'sku': {'${draft.item['sku']}'},
          },
        );
        final row =
            filasMasiva(
              current['filas'],
            ).where((r) => r['id'] == draft.item['id']).firstOrNull;
        if (row == null) {
          throw const MasivaError(
            'La prenda ya no está disponible en esta orden. Revisa el plan de recepción.',
          );
        }
        _redraw(() => draft.item = row);
        if (quantity > draft.maximum) {
          throw MasivaError(
            'Cambió la cantidad pendiente. Ahora puedes recibir ${draft.maximum}. Revisa la tarjeta antes de confirmar.',
          );
        }
        await _repo.ejecutar('recibir', {
          'operacion_id': draft.operation,
          'inventario_id': draft.item['id'],
          'cantidad': quantity,
          'soporte': draft.support,
          if (draft.note.isNotEmpty) 'novedad': draft.note,
          'request_id': MasivaRepository.requestId(),
        });
        _redraw(() {
          final orderIndex = _receiptOrders.indexWhere(
            (order) =>
                order['proveedor'] == draft.item['proveedor'] &&
                order['pedido'] == draft.item['pedido'],
          );
          if (orderIndex >= 0) {
            final order = _receiptOrders[orderIndex];
            _receiptOrders[orderIndex] = {
              ...order,
              'recibido':
                  (numeroMasiva(order['recibido']) + quantity)
                      .clamp(0, numeroMasiva(order['esperado']))
                      .toInt(),
            };
          }
          _receiptDrafts.remove(draft);
          _receiptError = false;
          _receiptMessage =
              '${draft.item['sku']} · $quantity unidades recibidas';
        });
      } catch (_) {
        // An uncertain write is owned by the persistent recovery banner. Never
        // offer the same quantity as a new request while recovery is pending.
        if (_repo.movimientoPendiente != null) {
          _redraw(() => _receiptDrafts.remove(draft));
        }
        rethrow;
      } finally {
        if (!_receiptDrafts.contains(draft)) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => draft.quantity.dispose(),
          );
        }
      }
    }, refresh: false);
    if (mounted && _receiptDialogOpen) _receiptFocus.requestFocus();
  }

  Widget _balanceView(double width) {
    final m = mapaMasiva(_data['metricas']);
    final ready = m['base_personal_cargada'] == true;
    final fields = <(String, String)>[
      ('esperado', 'Plan'),
      ('recibido', 'Recibido'),
      ('pendiente', 'Por recibir'),
      ('requerido', 'Para personalizar'),
      ('validado', 'Validado'),
      ('disponible', 'Disponible'),
      ('saldo', 'Saldo actual'),
      ('proyeccion', 'Al recibir todo'),
    ];
    String value(MasivaJson r, String k) =>
        r[k] == null ? 'Por cruzar' : '${r[k]}';
    Widget projection(MasivaJson r) {
      if (r['proyeccion'] == null) {
        return _pill('Base pendiente', color: _muted);
      }
      final n = numeroMasiva(r['proyeccion']);
      return _pill(
        n < 0
            ? 'Faltan ${-n}'
            : n > 0
            ? 'Sobran $n'
            : 'Equilibrado',
        color: n < 0 ? const Color(0xFFB93636) : const Color(0xFF17764C),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _operationStats([
          ('Total del plan', '${m['esperado'] ?? 0}', 'Toda la operación'),
          (
            'Recibido',
            '${m['recibido'] ?? 0}',
            '${m['pendiente'] ?? 0} pendientes',
          ),
          (
            'Para personalizar',
            ready ? '${m['requerido'] ?? 0}' : '—',
            'Base del personal',
          ),
          (
            'Validado',
            '${m['validado'] ?? 0}',
            '${m['disponible'] ?? 0} disponibles',
          ),
        ]),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: width < 600 ? double.infinity : 320,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar SKU, prenda o proveedor',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: width < 600 ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _balanceStatus,
                      key: ValueKey(_balanceStatus),
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Balance'),
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text('Todas las referencias'),
                        ),
                        DropdownMenuItem(
                          value: 'faltante',
                          child: Text('Con faltante previsto'),
                        ),
                        DropdownMenuItem(
                          value: 'sobrante',
                          child: Text('Con sobrante previsto'),
                        ),
                        DropdownMenuItem(
                          value: 'equilibrado',
                          child: Text('Equilibrado'),
                        ),
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendientes por recibir'),
                        ),
                        DropdownMenuItem(
                          value: 'sin_pedido',
                          child: Text('Sin pedido'),
                        ),
                      ],
                      onChanged: (v) {
                        _balanceStatus = v ?? '';
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      _page = 1;
                      _load();
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Consultar'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      _balanceStatus = '';
                      _page = 1;
                      _load();
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Limpiar'),
                  ),
                  TextButton.icon(
                    onPressed:
                        _rows.isNotEmpty && _error == null
                            ? _exportBalance
                            : null,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Exportar Excel'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!ready)
          _notice(
            'Carga la base del personal en Base de datos maestra para calcular necesidades y sobrantes.',
            Icons.info_outline,
          ),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _pill(
                  '${m['sobrante_previsto'] ?? 0} unidades de sobrante previsto',
                  color: const Color(0xFF17764C),
                ),
                _pill(
                  '${m['faltante_previsto'] ?? 0} unidades faltantes · ${m['referencias_faltantes'] ?? 0} SKU',
                  color: const Color(0xFFB93636),
                ),
                if (numeroMasiva(m['sin_pedido']) > 0)
                  _pill(
                    '${m['sin_pedido']} SKU sin pedido',
                    color: const Color(0xFF946000),
                  ),
              ],
            ),
          ),
        if (_rows.isEmpty)
          _empty(
            'No hay referencias con estos filtros',
            'Consulta otra prenda o limpia los filtros.',
          )
        else if (width < 650) ...[
          for (final r in _rows)
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['sku']} · ${r['descripcion']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${r['proveedores']}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      for (final f in fields.take(7))
                        SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                              Text(value(r, f.$1)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  projection(r),
                ],
              ),
            ),
        ] else
          _panel(
            padding: 0,
            child: LayoutBuilder(
              builder:
                  (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        horizontalMargin: 14,
                        columnSpacing: 18,
                        headingRowColor: const WidgetStatePropertyAll(
                          AppColors.petroleo,
                        ),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 86,
                        columns: [
                          const DataColumn(label: Text('SKU')),
                          const DataColumn(label: Text('PRENDA')),
                          for (final f in fields)
                            DataColumn(
                              label: Text(f.$2),
                              numeric: f.$1 != 'proyeccion',
                            ),
                        ],
                        rows: [
                          for (final r in _rows)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${r['sku']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 230,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['descripcion']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          '${r['proveedores']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                for (final f in fields)
                                  DataCell(
                                    f.$1 == 'proyeccion'
                                        ? projection(r)
                                        : Text(value(r, f.$1)),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        const Text(
          'Saldo actual = recibido − requerido. Al recibir todo = plan − requerido. Los sobrantes de un SKU no compensan faltantes de otro. Disponible = recibido − validado neto.',
          style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),
        _pagination(),
      ],
    );
  }

  Future<void> _exportBalance() =>
      _work('Preparando conciliación completa…', () async {
        final rows = <MasivaJson>[];
        final search = '${_balanceLoadedQuery['buscar'] ?? ''}',
            status = '${_balanceLoadedQuery['estado'] ?? ''}';
        int total = -1;
        for (var page = 1; ; page++) {
          final data = await _repo.consultarConciliacion(
            operacion: _operationId!,
            buscar: search,
            estado: status,
            pagina: page,
          );
          final batch = filasMasiva(data['filas']);
          final count = numeroMasiva(data['total']);
          if (total >= 0 && count != total) {
            throw const MasivaError(
              'Los datos cambiaron durante la exportación. Consulta de nuevo.',
            );
          }
          total = count;
          rows.addAll(batch);
          if (rows.length >= total) break;
          if (batch.isEmpty) {
            throw const MasivaError('No se pudo completar la exportación.');
          }
        }
        final fields = [
          'sku',
          'descripcion',
          'proveedores',
          'esperado',
          'recibido',
          'pendiente',
          'requerido',
          'validado',
          'disponible',
          'saldo',
          'proyeccion',
        ];
        await exportarMasivaExcel([
          for (final r in rows) {for (final f in fields) f: r[f]},
        ], nombre: 'conciliacion_masiva.xlsx');
      });
}
