part of 'masiva_page.dart';

extension _MasivaMaster on _MasivaPageState {
  Map<String, Set<String>> get _masterQueryFilters => {
    for (final e in _masterFilters.entries) e.key: {...e.value},
    if (_list.text.trim().isNotEmpty) 'lista': {_list.text.trim()},
  };

  String? _masterDateParam(DateTime? value) =>
      value == null
          ? null
          : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _masterDateLabel(DateTime? value, String empty) =>
      value == null
          ? empty
          : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _masterPickDate(bool from) async {
    _dialog = true;
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: (from ? _masterFrom : _masterUntil) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: from ? 'Desde qué fecha' : 'Hasta qué fecha',
        cancelText: 'Cancelar',
        confirmText: 'Aplicar',
      );
      if (date == null || !mounted) return;
      if ((from && _masterUntil != null && date.isAfter(_masterUntil!)) ||
          (!from && _masterFrom != null && date.isBefore(_masterFrom!))) {
        await mostrarAviso(
          context,
          'La fecha inicial debe ser anterior o igual a la fecha final.',
        );
        return;
      }
      _redraw(() {
        if (from) {
          _masterFrom = date;
        } else {
          _masterUntil = date;
        }
        _page = 1;
        _selectedLists.clear();
      });
      await _load();
    } finally {
      _dialog = false;
    }
  }

  Widget _masterToolbar(double width) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width < 600 ? double.infinity : 300,
              child: TextField(
                key: const ValueKey('masiva-master-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar',
                  hintText:
                      _section == 8
                          ? 'Cédula, nombre, SKU o destino'
                          : 'Lista, sede, ciudad, persona o SKU',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Consultar',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      _page = 1;
                      _selectedLists.clear();
                      _load();
                    },
                  ),
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _selectedLists.clear();
                  _load();
                },
              ),
            ),
            SizedBox(
              width: width < 600 ? double.infinity : 180,
              child: TextField(
                key: const ValueKey('masiva-master-list'),
                controller: _list,
                decoration: const InputDecoration(
                  labelText: 'Lista de empaque',
                  hintText: 'Todas las listas',
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _selectedLists.clear();
                  _load();
                },
              ),
            ),
            SizedBox(
              width: width < 600 ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey('master-date-$_section-$_masterDateType'),
                initialValue: _masterDateType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtrar fecha por',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'fecha_carga',
                    child: Text('Fecha de cargue'),
                  ),
                  DropdownMenuItem(
                    value:
                        _section == 2
                            ? 'ultima_validacion'
                            : 'fecha_validacion',
                    child: const Text('Fecha de validación'),
                  ),
                  if (_section == 2) ...[
                    const DropdownMenuItem(
                      value: 'fecha_generado',
                      child: Text('Fecha de PDF'),
                    ),
                    const DropdownMenuItem(
                      value: 'fecha_despacho',
                      child: Text('Fecha de despacho'),
                    ),
                    const DropdownMenuItem(
                      value: 'fecha_recepcion',
                      child: Text('Fecha de recepción'),
                    ),
                  ],
                ],
                onChanged: (value) {
                  if (value != null) {
                    _masterDateType = value;
                    _page = 1;
                    _selectedLists.clear();
                    _load();
                  }
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _masterPickDate(true),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(_masterDateLabel(_masterFrom, 'Desde')),
            ),
            OutlinedButton.icon(
              onPressed: () => _masterPickDate(false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_masterDateLabel(_masterUntil, 'Hasta')),
            ),
            TextButton.icon(
              onPressed: () {
                _search.clear();
                _list.clear();
                _masterFilters.clear();
                _selectedLists.clear();
                _masterFrom = null;
                _masterUntil = null;
                _page = 1;
                _load();
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Limpiar filtros'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_section == 8 && _admin)
              FilledButton.icon(
                onPressed: _editable ? () => _import('personal') : null,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Cargar base de distribución'),
              ),
            if (_section == 2) ...[
              OutlinedButton.icon(
                onPressed: _editable ? _assign : null,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Asignar empacador'),
              ),
              OutlinedButton.icon(
                onPressed: _editable ? _time : null,
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Registrar tiempo de empaque'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('masiva-master-generate-lists'),
                onPressed:
                    _editable && _selectedLists.isNotEmpty
                        ? _masterLists
                        : null,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  _selectedLists.isEmpty
                      ? 'Generar lista(s)'
                      : _selectedLists.length == 1
                      ? 'Generar lista (1)'
                      : 'Generar listas (${_selectedLists.length})',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _editable && _selectedLists.isNotEmpty
                        ? _masterLabels
                        : null,
                icon: const Icon(Icons.label_outline, size: 18),
                label: Text(
                  _selectedLists.isEmpty
                      ? 'Rótulos masivos'
                      : 'Rótulos (${_selectedLists.length} listas)',
                ),
              ),
            ],
            TextButton.icon(
              onPressed:
                  _rows.isNotEmpty && _error == null ? _masterExport : null,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Descargar informe Excel'),
            ),
            if (_section == 8)
              TextButton.icon(
                onPressed: _masterTemplate,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Plantilla base'),
              ),
            if (_section == 2)
              TextButton.icon(
                onPressed: () => _select(8),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Ver base de datos maestra'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _masterRecords(double width) {
    final options = mapaMasiva(_data['opciones']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _section == 2
                ? 'Una fila por lista · Total piezas = cajas + bolsas · Peso estimado según el catálogo de empaques.'
                : 'Una fila por prenda y persona. Las fechas de cargue y validación corresponden a registros reales de ORBILOQ.',
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
        ),
        MasivaMaestroTabla(
          base: _section == 8,
          filas: _rows,
          filtros: _masterQueryFilters,
          opciones: {
            for (final e in options.entries)
              e.key: (e.value as List? ?? []).map((v) => '$v').toList(),
          },
          onFiltrosChanged: (filters) {
            _redraw(() {
              _masterFilters
                ..clear()
                ..addAll(filters);
              _list.clear();
              _page = 1;
              _selectedLists.clear();
            });
            _load();
          },
          onAbrir: _openMasterRow,
          seleccionadas: _selectedLists,
          onSeleccionChanged:
              _section == 2
                  ? (values) => _redraw(() {
                    _selectedLists
                      ..clear()
                      ..addAll(values);
                  })
                  : null,
          cargando: _loading || _busy != null,
        ),
        if (_section == 2)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Las columnas de despacho y entrega estarán disponibles para registro en la etapa de despacho.',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Future<void> _openMasterRow(MasivaJson row) async {
    if (_section == 2) {
      await _select(8, lista: '${row['lista']}');
    } else {
      await _select(3, buscar: '${row['kit_id']}');
      if (mounted && _rows.length == 1) _openValidation(_rows.single);
    }
  }

  Widget _masterPagination() {
    final total = numeroMasiva(_data['total']);
    final pages = (total / _masterPageSize).ceil().clamp(1, 100000);
    final first = total == 0 ? 0 : (_page - 1) * _masterPageSize + 1;
    final last = (_page * _masterPageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$total ${_section == 2 ? 'listas' : 'registros'} · Mostrando $first–$last',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              key: ValueKey('master-size-$_masterPageSize'),
              initialValue: _masterPageSize,
              decoration: const InputDecoration(
                labelText: 'Por página',
                isDense: true,
              ),
              items: [
                for (final n in [30, 50, 100])
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (n) {
                if (n != null) {
                  _masterPageSize = n;
                  _page = 1;
                  _load();
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed:
                _page > 1
                    ? () {
                      _page--;
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Página $_page de $pages',
            style: const TextStyle(color: _ink, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed:
                _page < pages
                    ? () {
                      _page++;
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _masterExport() => _work(
    'Preparando el informe completo con los filtros seleccionados…',
    () async {
      final all = <MasivaJson>[];
      final ids = <String>{};
      int? expectedTotal;
      var page = 1;
      final base = _section == 8;
      final query = _masterLoadedQuery;
      final filters = <String, Set<String>>{
        for (final e in mapaMasiva(query['filtros']).entries)
          e.key: Set<String>.from(e.value as Iterable),
      };
      while (true) {
        final result = await _repo.consultarMaestro(
          operacion: _operationId!,
          vista: base ? 'base' : 'listado',
          buscar: '${query['buscar'] ?? ''}',
          filtros: filters,
          pagina: page,
          tamano: 1000,
          fechaTipo: '${query['fecha_tipo'] ?? 'fecha_carga'}',
          desde: query['desde'] as String?,
          hasta: query['hasta'] as String?,
          incluirOpciones: false,
        );
        final rows = filasMasiva(result['filas']);
        final total = numeroMasiva(result['total']);
        expectedTotal ??= total;
        if (total != expectedTotal ||
            rows.any(
              (row) => !ids.add('${row[base ? 'articulo_id' : 'lista']}'),
            )) {
          throw const MasivaError(
            'Los resultados cambiaron durante la descarga. Actualiza los filtros y vuelve a descargar el informe.',
          );
        }
        all.addAll(rows);
        _redraw(
          () => _progress = total == 0 ? 1 : (all.length / total).clamp(0, 1),
        );
        if (all.length >= total) break;
        if (rows.isEmpty) {
          throw const MasivaError(
            'El reporte cambió durante la consulta. Actualiza y vuelve a descargarlo.',
          );
        }
        page++;
      }
      final columns = base ? masivaBaseColumnas : masivaListadoColumnas;
      await exportarMasivaExcel([
        for (final row in all) {for (final c in columns) c.title: row[c.key]},
      ], nombre: base ? 'Base_de_datos_maestra' : 'Listado_maestro');
    },
  );

  Future<void> _masterTemplate() =>
      _work('Preparando la plantilla de distribución…', () async {
        await exportarMasivaExcel([
          {
            for (final title in [
              '#',
              'LOGISTICA',
              'ENTREGA',
              'CEDULA',
              'NOMBRE COMPLETO',
              'UNIDAD ORGANIZATIVA',
              'UNIDAD DIRECTIVA',
              'GERENCIA',
              'SECTOR',
              'CARGO',
              'PRENDA',
              'CODIGO',
              'MATERIAL DESCRIPCION',
              'CANTIDAD A ENVIAR',
              'REGIONAL',
              'DEPARTAMENTO',
              'CIUDAD',
              'SEDE',
              'DIRECCION',
              'LIDER / ENCARGADO',
              'ITEMS KITS',
              'LE',
              'ITEMS LE',
              'ITEMS DIRECCION',
              'FECHA EMPAQUE',
              'FECHA ENTREGA',
            ])
              title: '',
          },
        ], nombre: 'Plantilla_base_distribucion');
      });

  Future<void> _masterLabels() => _work(
    'Generando rótulos de las listas seleccionadas…',
    () async {
      final snapshots = <MasivaJson>[];
      final lists =
          _selectedLists.toList()..sort(
            (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
          );
      for (final list in lists) {
        try {
          final result = await _repo.ejecutar('documento', {
            'operacion_id': _operationId,
            'lista': list,
            'tipo': 'rotulo',
          });
          snapshots.add(mapaMasiva(result['snapshot']));
          _redraw(() => _progress = snapshots.length / lists.length);
        } catch (e) {
          throw MasivaError(
            'Lista $list: ${errorMasiva(e)}${snapshots.isEmpty ? '' : '\nLas ${snapshots.length} versiones ya generadas se conservan en Listas y documentos.'}',
          );
        }
      }
      await descargarPdf(
        await generarRotulosMasivosMasiva(snapshots),
        'Rotulos_masiva_${lists.length}_listas.pdf',
      );
    },
  );

  Future<void> _masterLists() => _work(
    'Generando listas de empaque seleccionadas…',
    () async {
      final snapshots = <MasivaJson>[];
      final lists =
          _selectedLists.toList()..sort(
            (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
          );
      if (lists.isEmpty) {
        throw const MasivaError('Selecciona al menos una lista de empaque.');
      }
      for (final list in lists) {
        try {
          final result = await _repo.ejecutar('documento', {
            'operacion_id': _operationId,
            'lista': list,
            'tipo': 'lista',
          });
          snapshots.add(mapaMasiva(result['snapshot']));
          _redraw(() => _progress = snapshots.length / lists.length);
        } catch (e) {
          throw MasivaError(
            'Lista $list: ${errorMasiva(e)}${snapshots.isEmpty ? '' : '\nLas ${snapshots.length} versiones ya generadas se conservan en Listas y documentos.'}',
          );
        }
      }
      final pdf =
          snapshots.length == 1
              ? await generarListaMasiva(snapshots.single)
              : await generarListasMasivasMasiva(snapshots);
      final filename =
          snapshots.length == 1
              ? nombreArchivoListaMasiva(snapshots.single)
              : 'Listas_de_empaque_masiva_${lists.length}_listas.pdf';
      await descargarPdf(pdf, filename);
      _redraw(() => _selectedLists.clear());
      await _load(silent: true);
    },
  );
}
