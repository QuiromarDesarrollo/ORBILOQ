part of 'masiva_page.dart';

extension _MasivaValidationWorkspace on _MasivaPageState {
  bool get _validationAvailable =>
      _editable && !_loading && !_scanning && !_scanAlert;

  String? get _validationSelectedPacker {
    final assigned = '${_kit['empacador_id'] ?? ''}';
    if (assigned.isNotEmpty) return assigned;
    return _people.any(
          (p) => p['activo'] != false && '${p['id']}' == _validationPackerId,
        )
        ? _validationPackerId
        : null;
  }

  Widget _validationWorkspace(double width) => LayoutBuilder(
    builder: (context, constraints) {
      if (_operationId == null) {
        return _loading
            ? const WmsLoadingPanel(label: 'Actualizando Masiva…')
            : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _onboarding(),
            );
      }
      final guards = <Widget>[
        if (!_scanning && _repo.movimientoPendiente != null)
          _notice(
            'Hay un movimiento sin confirmación. Recupera su respuesta antes de continuar.',
            Icons.sync_problem,
            action: TextButton(
              onPressed:
                  () =>
                      _work('Recuperando la confirmación original…', () async {
                        await _repo.recuperarConfirmacion();
                      }),
              child: const Text('Recuperar'),
            ),
          ),
        if (_archived)
          _notice(
            'Operación archivada. La validación está disponible solo para consulta.',
            Icons.lock_outline,
          ),
        if (_error != null)
          _notice(
            _error!,
            Icons.wifi_off,
            action: TextButton(
              onPressed: () => _load(),
              child: const Text('Reintentar'),
            ),
          ),
      ];
      final latePacker =
          _kit.isNotEmpty && '${_kit['empacador_id'] ?? ''}'.isEmpty;
      final bounded =
          constraints.hasBoundedHeight &&
          constraints.maxWidth >= 900 &&
          constraints.maxHeight >= 610 &&
          MediaQuery.textScalerOf(context).scale(14) <= 16.8;
      final items = filasMasiva(_kit['articulos']);
      Widget workspace() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _validationHeader(),
            const SizedBox(height: 10),
            if (!bounded)
              for (final guard in guards) ...[guard, const SizedBox(height: 8)],
            _validationControls(),
            if (latePacker && !bounded) ...[
              const SizedBox(height: 8),
              _notice(
                _people.any((p) => p['activo'] != false)
                    ? 'Selecciona quién empacó este kit. Al validar la primera prenda se registrará MAL EMPAQUE por no haber registrado el empaque.'
                    : 'No hay empacadores disponibles. Regístralos en Configuración para continuar.',
                Icons.info_outline,
              ),
            ],
            const SizedBox(height: 10),
            if (_kit.isNotEmpty) ...[
              _validationPerson(compact: bounded),
              const SizedBox(height: 10),
            ],
            _validationScanner(),
            const SizedBox(height: 6),
            _validationFeedback(compact: bounded),
            const SizedBox(height: 8),
            if (bounded)
              Expanded(
                child:
                    _loading
                        ? const WmsLoadingPanel(label: 'Buscando documento…')
                        : _kit.isEmpty
                        ? _validationWaiting()
                        : _validationArticles(items, bounded: true),
              )
            else if (_loading)
              const SizedBox(
                height: 180,
                child: WmsLoadingPanel(label: 'Buscando documento…'),
              )
            else if (_kit.isEmpty)
              _validationWaiting()
            else
              _validationArticles(items, bounded: false),
            const SizedBox(height: 8),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 8),
            _validationActions(items),
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.all(width < 600 ? 10 : 12),
        child:
            bounded ? workspace() : SingleChildScrollView(child: workspace()),
      );
    },
  );

  Widget _validationHeader() => LayoutBuilder(
    builder: (_, box) {
      final operation =
          '${_operation['nombre'] ?? 'Masiva'} · ${_operation['cliente'] ?? ''}';
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Empaque y validación',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Tooltip(
            message: operation,
            child: Text(
              operation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ],
      );
      final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _validationAvailable ? _time : null,
            icon: const Icon(Icons.timer_outlined, size: 18),
            label: const Text('Registrar empaque'),
          ),
          IconButton(
            tooltip: 'Cambiar operación',
            onPressed: !_scanning && !_scanAlert ? () => _select(0) : null,
            icon: const Icon(Icons.swap_horiz, color: _ink),
          ),
        ],
      );
      return box.maxWidth >= 620
          ? Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 12),
              actions,
            ],
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 10), actions],
          );
    },
  );

  Widget _validationControls() => LayoutBuilder(
    builder: (_, box) {
      final assigned = '${_kit['empacador_id'] ?? ''}'.isNotEmpty;
      final packers = _people.where((p) => p['activo'] != false).toList();
      final validator = ref.watch(usuarioSesionProvider).valueOrNull?.nombre;
      Widget readOnly(String label, String value, IconData icon) =>
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
            ),
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, fontSize: 13),
              ),
            ),
          );
      final fields = <Widget>[
        readOnly(
          'Validador',
          validator == null || validator.trim().isEmpty
              ? 'Usuario actual'
              : validator,
          Icons.verified_user_outlined,
        ),
        if (assigned)
          readOnly(
            'Empacador',
            '${_kit['empacador'] ?? _personName(_kit['empacador_id'])}',
            Icons.person_outline,
          )
        else
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Empacador',
              prefixIcon: Icon(Icons.person_outline, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('masiva-validation-packer'),
                focusNode: _validationPackerFocus,
                value: _validationSelectedPacker,
                isExpanded: true,
                hint: Text(
                  packers.isEmpty
                      ? 'Sin empacadores'
                      : 'Selecciona una persona',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                items: [
                  for (final p in packers)
                    DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(
                        '${p['nombre']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    _validationAvailable && _kit.isNotEmpty
                        ? (value) {
                          _redraw(() => _validationPackerId = value);
                          if (value != null) _focusSku();
                        }
                        : null,
              ),
            ),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('pack-type-${_kit['id']}-${_packType ?? ''}'),
          initialValue:
              _validationPackages.any((p) => '${p['id']}' == _packType)
                  ? _packType
                  : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de empaque',
            prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: [
            for (final p in _validationPackages)
              DropdownMenuItem(
                value: '${p['id']}',
                child: Text(
                  textoEmpaque(p['nombre']),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged:
              _validationAvailable && _kit['caja'] == null
                  ? (value) => _redraw(() => _packType = value)
                  : null,
        ),
        TextField(
          key: const ValueKey('masiva-validation-container'),
          controller: _packNumber,
          enabled: _validationAvailable && _kit['caja'] == null,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'N.º de contenedor',
            prefixIcon: Icon(Icons.tag, size: 18),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ];
      final columns =
          box.maxWidth >= 820
              ? 4
              : box.maxWidth >= 520
              ? 2
              : 1;
      final fieldWidth = (box.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 14,
        children: [
          for (final field in fields) SizedBox(width: fieldWidth, child: field),
        ],
      );
    },
  );

  Widget _validationPerson({required bool compact}) {
    final items = filasMasiva(_kit['articulos']);
    final total = items.fold<int>(0, (n, a) => n + numeroMasiva(a['cantidad']));
    final done = items.fold<int>(0, (n, a) => n + numeroMasiva(a['validado']));
    final complete = total > 0 && done >= total;
    final color = complete ? AppColors.actionGreen : AppColors.amberChip;
    final name = '${_kit['nombre'] ?? ''}';
    final identity =
        'Documento ${_kit['cedula']} · Lista ${_kit['lista']} · Persona ${_kit['numero_persona']}';
    final counts =
        'Requeridas: $total · Validadas: $done · Pendientes: ${(total - done).clamp(0, total)}';
    return Container(
      key: const ValueKey('masiva-validation-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KIT EN VALIDACIÓN',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Tooltip(
                      message: name,
                      child: Text(
                        name,
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (compact) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    counts,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (compact)
                _pill(
                  complete
                      ? 'Completo'
                      : done > 0
                      ? 'Parcial'
                      : 'Pendiente',
                  color: color,
                ),
              IconButton(
                tooltip: 'Cerrar kit',
                onPressed: !_scanning && !_scanAlert ? _closeValidation : null,
                icon: const Icon(Icons.close, size: 20),
                color: _ink,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Tooltip(
            message: identity,
            child: Text(
              identity,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: const TextStyle(color: _ink, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder:
                (_, box) => Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final item in [
                      ('Sede', 'sede'),
                      ('Ciudad', 'ciudad'),
                      ('Sector', 'sector'),
                    ])
                      if ('${_kit[item.$2] ?? ''}'.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                compact
                                    ? (box.maxWidth - 32) / 3
                                    : box.maxWidth,
                          ),
                          child: Tooltip(
                            message: '${item.$1}: ${_kit[item.$2]}',
                            child: Text(
                              '${item.$1}: ${_kit[item.$2]}',
                              maxLines: compact ? 1 : null,
                              overflow: compact ? TextOverflow.ellipsis : null,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              counts,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _validationScanner() => LayoutBuilder(
    builder: (_, box) {
      final ready = _kit.isNotEmpty && _validationSelectedPacker != null;
      final person = Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('masiva-persona'),
              controller: _search,
              focusNode: _personFocus,
              enabled: !_scanning && !_scanAlert,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '1. Documento / cédula',
                hintText: 'Escanea o escribe la cédula completa',
                prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Buscar documento',
                  onPressed: !_scanning && !_scanAlert ? _searchRecords : null,
                  icon: const Icon(Icons.search, size: 20),
                ),
              ),
              onSubmitted: (_) => _searchRecords(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            key: const ValueKey('masiva-documento-camera'),
            tooltip: 'Leer documento con cámara',
            onPressed:
                !_loading && !_scanning && !_scanAlert
                    ? () => _camera(document: true)
                    : null,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      );
      final sku = Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('masiva-sku'),
              controller: _sku,
              focusNode: _scanFocus,
              enabled:
                  (_editable || _scanning) && !_loading && ready && !_scanAlert,
              autocorrect: false,
              enableSuggestions: false,
              onEditingComplete: () {},
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '2. SKU / código de prenda',
                hintText: 'Escanea o escribe el código',
                prefixIcon: Icon(Icons.qr_code_scanner, size: 19),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _validate(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            key: const ValueKey('masiva-sku-camera'),
            tooltip: 'Leer código con cámara',
            onPressed: _validationAvailable && ready ? _camera : null,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      );
      final buttons = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _validationAvailable && ready ? _validate : null,
            icon: const Icon(Icons.add_task, size: 17),
            label: const Text('Validar 1 unidad'),
          ),
        ],
      );
      if (box.maxWidth >= 820) {
        return Row(
          children: [
            Expanded(child: person),
            const SizedBox(width: 10),
            Expanded(child: sku),
            const SizedBox(width: 10),
            buttons,
          ],
        );
      }
      final fieldWidth =
          box.maxWidth >= 620 ? (box.maxWidth - 10) / 2 : box.maxWidth;
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          SizedBox(width: fieldWidth, child: person),
          SizedBox(width: fieldWidth, child: sku),
          buttons,
        ],
      );
    },
  );

  Widget _validationFeedback({required bool compact}) {
    final pending = !_scanning && _repo.movimientoPendiente != null;
    final warning = compact && !_scanning;
    final text =
        _scanning
            ? 'Validando lectura…'
            : warning && pending
            ? 'Hay un movimiento sin confirmación. Recupera su respuesta antes de continuar.'
            : warning && _error != null
            ? _error!
            : warning && _archived
            ? 'Operación archivada. La validación está disponible solo para consulta.'
            : warning &&
                _kit.isNotEmpty &&
                '${_kit['empacador_id'] ?? ''}'.isEmpty
            ? (_people.any((p) => p['activo'] != false)
                ? 'Selecciona quién empacó este kit. Al validar la primera prenda se registrará MAL EMPAQUE por no haber registrado el empaque.'
                : 'No hay empacadores disponibles. Regístralos en Configuración para continuar.')
            : _scanFeedback ??
                (_kit.isNotEmpty && _kit['revision_abierta'] != true
                    ? 'Este kit está validado. Las lecturas adicionales detectan prendas incorrectas o excedentes.'
                    : 'Cada lectura suma 1 unidad. En calzado, una unidad equivale a un par.');
    final feedback = Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (_scanning) ...[
            const WmsLoader(width: 28),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Tooltip(
              message: text,
              child: Text(
                text,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (warning && pending)
            TextButton(
              onPressed:
                  () => _work(
                    'Recuperando la confirmación original…',
                    () async => _repo.recuperarConfirmacion(),
                  ),
              child: const Text('Recuperar'),
            )
          else if (warning && _error != null)
            TextButton(
              onPressed: () => _load(),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
    // Network state must never change the table's layout or vertical position.
    return compact ? SizedBox(height: 40, child: feedback) : feedback;
  }

  Widget _validationWaiting() => const WmsEmptyState(
    title: 'Listo para escanear',
    message: 'Ingresa la cédula para ver las prendas y comenzar la validación.',
    icon: Icons.badge_outlined,
  );

  String _validationItemState(MasivaJson item) =>
      numeroMasiva(item['validado']) >= numeroMasiva(item['cantidad'])
          ? 'Completo'
          : numeroMasiva(item['validado']) > 0
          ? 'Parcial'
          : 'Pendiente';
  Color _validationItemColor(MasivaJson item) =>
      _validationItemState(item) == 'Completo'
          ? AppColors.actionGreen
          : AppColors.amberChip;
  String _validationItemTime(MasivaJson item) {
    final instant =
        DateTime.tryParse('${item['fecha_hora_validado']}')?.toLocal();
    return instant == null
        ? '—'
        : '${_date(item['fecha_hora_validado'])}:${instant.second.toString().padLeft(2, '0')}';
  }

  Widget _validationCorrect(MasivaJson item) => IconButton(
    tooltip: 'Corregir cantidad con motivo',
    onPressed:
        _validationAvailable && _kit['revision_abierta'] == true
            ? () => _correct(item)
            : null,
    icon: const Icon(Icons.edit_outlined, size: 18),
  );

  Widget _validationArticles(List<MasivaJson> items, {required bool bounded}) {
    if (!bounded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalle de prendas del kit',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    '${item['sku']}' == _lastScanSku
                        ? _lime.withValues(alpha: .1)
                        : Colors.white,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          '${item['sku']}',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _pill(
                        _validationItemState(item),
                        color: _validationItemColor(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item['descripcion']}',
                    style: const TextStyle(color: _ink, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Requerido: ${item['cantidad']} · Validado: ${item['validado']}',
                          style: TextStyle(
                            color: _validationItemColor(item),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _validationCorrect(item),
                    ],
                  ),
                  Text(
                    'Última validación: ${_validationItemTime(item)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    Widget row(List<Widget> cells) => Row(
      children: [
        SizedBox(width: 112, child: cells[0]),
        const SizedBox(width: 10),
        Expanded(child: cells[1]),
        const SizedBox(width: 10),
        SizedBox(width: 64, child: cells[2]),
        SizedBox(width: 64, child: cells[3]),
        SizedBox(width: 154, child: cells[4]),
        SizedBox(width: 84, child: cells[5]),
        SizedBox(width: 44, child: cells[6]),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Detalle de prendas del kit',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            child: row([
              const Text('SKU'),
              const Text('DESCRIPCIÓN / PRENDA'),
              const Text('REQ.'),
              const Text('VAL.'),
              const Text('FECHA Y HORA'),
              const Text('ESTADO'),
              const Tooltip(
                message: 'Corregir cantidad',
                child: Icon(Icons.edit_outlined, color: Colors.white, size: 16),
              ),
            ]),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('masiva-validation-items'),
            child: Column(
              children: [
                for (final item in items)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color:
                          '${item['sku']}' == _lastScanSku
                              ? _lime.withValues(alpha: .12)
                              : _validationItemState(item) == 'Completo'
                              ? AppColors.actionGreen.withValues(alpha: .05)
                              : Colors.white,
                      border: const Border(bottom: BorderSide(color: _line)),
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: _ink, fontSize: 12),
                      child: row([
                        Tooltip(
                          message: '${item['sku']}',
                          child: SelectableText(
                            '${item['sku']}',
                            maxLines: 1,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: '${item['descripcion']}',
                          child: Text(
                            '${item['descripcion']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${item['cantidad']}'),
                        Text(
                          '${item['validado']}',
                          style: TextStyle(
                            color: _validationItemColor(item),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _validationItemTime(item),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _pill(
                            _validationItemState(item),
                            color: _validationItemColor(item),
                          ),
                        ),
                        _validationCorrect(item),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _validationActions(List<MasivaJson> items) {
    final selected = _kit.isNotEmpty;
    final done = items.fold<int>(0, (n, a) => n + numeroMasiva(a['validado']));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed:
              _validationAvailable && selected && done > 0 ? _pack : null,
          icon: const Icon(Icons.inventory_2_outlined, size: 17),
          label: const Text('Empacar'),
        ),
        OutlinedButton.icon(
          onPressed:
              _validationAvailable && selected && done > 0
                  ? _resetValidation
                  : null,
          icon: const Icon(Icons.restart_alt, size: 17),
          label: const Text('Reiniciar validación'),
        ),
        if (selected && _kit['revision_abierta'] != true)
          TextButton.icon(
            onPressed:
                _validationAvailable && _kit['validacion_inicio'] != null
                    ? _reopen
                    : null,
            icon: const Icon(Icons.lock_open_outlined, size: 17),
            label: const Text('Reabrir revisión'),
          ),
        TextButton.icon(
          onPressed:
              _validationAvailable && selected && _kit['empacador_id'] != null
                  ? _reportError
                  : null,
          icon: const Icon(Icons.report_outlined, size: 17),
          label: const Text('Reportar MAL EMPAQUE'),
        ),
      ],
    );
  }
}
