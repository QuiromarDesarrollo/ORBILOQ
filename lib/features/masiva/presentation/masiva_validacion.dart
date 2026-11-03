part of 'masiva_page.dart';

extension _MasivaValidation on _MasivaPageState {
  void _focusSku() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _kit.isNotEmpty &&
          !_dialog &&
          !_cameraOpen &&
          !_scanning &&
          !_scanAlert &&
          (_kit['empacador_id'] != null || _validationPackerId != null)) {
        _scanFocus.requestFocus();
      }
    });
  }

  Future<void> _searchRecords() async {
    if (_scanning || _scanAlert) return;
    if (_section != 3) {
      _page = 1;
      await _load();
      return;
    }
    final query = _search.text.trim();
    if (query.isEmpty || _operationId == null) return;
    _closeValidation(focus: false);
    final operation = _operationId!;
    final serial = ++_epoch;
    _redraw(() => _loading = true);
    try {
      final result = await _repo.consultar(
        operacion: operation,
        vista: 'validacion_documento',
        buscar: query,
      );
      if (!mounted ||
          serial != _epoch ||
          operation != _operationId ||
          query != _search.text.trim()) {
        return;
      }
      final matches =
          filasMasiva(
            result['filas'],
          ).where((row) => '${row['cedula']}' == query).toList();
      _redraw(() {
        _loading = false;
        _error = null;
      });
      if (matches.length == 1 && numeroMasiva(result['total']) == 1) {
        _openValidation(matches.single);
      } else {
        _redraw(
          () =>
              _scanFeedback =
                  matches.isEmpty
                      ? 'No se encontró el documento. Escanea o escribe la cédula completa.'
                      : 'El documento está duplicado en la base. Revisa la carga antes de validar.',
        );
        if (!_cameraOpen) _personFocus.requestFocus();
      }
    } catch (e) {
      if (mounted && serial == _epoch) {
        _redraw(() {
          _loading = false;
          _error = errorMasiva(e);
        });
      }
    }
  }

  void _openValidation(MasivaJson kit) {
    if (_scanning || _scanAlert) return;
    _redraw(() {
      _kit = kit;
      _validationPackerId = kit['empacador_id']?.toString();
      if (kit['caja'] != null) {
        _packNumber.text = '${kit['caja']}';
        _packType = kit['empaque_id']?.toString();
      }
      _sku.clear();
      _lastScanSku = null;
      _scanFeedback = null;
    });
    if (_validationPackerId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_cameraOpen && _kit.isNotEmpty) {
          _validationPackerFocus.requestFocus();
        }
      });
    } else {
      _focusSku();
    }
  }

  void _closeValidation({bool focus = true}) {
    if (_scanning || _scanAlert) return;
    _redraw(() {
      _kit = {};
      _validationPackerId = null;
      _sku.clear();
      _lastScanSku = null;
      _scanFeedback = null;
    });
    if (focus) _personFocus.requestFocus();
  }

  Future<void> _refreshValidation(String kitId, String operation) async {
    final fresh = await _repo.consultar(
      operacion: operation,
      vista: 'kits',
      buscar: kitId,
    );
    final row =
        filasMasiva(fresh['filas']).where((r) => r['id'] == kitId).firstOrNull;
    if (row == null) {
      throw const MasivaError(
        'No se pudo actualizar el kit. Consulta nuevamente el documento antes de continuar.',
      );
    }
    if (mounted && _kit['id'] == kitId && _operationId == operation) {
      _redraw(() {
        _kit = row;
        _data = {
          ..._data,
          'filas': [for (final r in _rows) r['id'] == kitId ? row : r],
        };
        _updated = DateTime.now();
      });
    }
  }

  Future<void> _rejectScan(String sku, {MasivaJson? article}) async {
    final waiting = _scanQueue.length;
    _scanQueue.clear();
    _sku.clear();
    _redraw(() => _scanAlert = true);
    _dialog = true;
    try {
      // Disable the scan field before the modal acquires focus. Otherwise its
      // rebuild can unfocus the newly opened alert and restore the page scope.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await mostrarAvisoContenido(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SKU: $sku',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 8),
            if (article == null) ...[
              Text('Este código no pertenece al kit de ${_kit['nombre']}.'),
              const SizedBox(height: 12),
              const Text(
                'Revisa el empaque y retira esta prenda antes de continuar.',
              ),
            ] else ...[
              Text('${article['descripcion']}'),
              const SizedBox(height: 8),
              Text(
                'Requeridas: ${article['cantidad']} · Ya validadas: ${article['validado']}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Retira la unidad adicional y devuélvela al lote. Esta lectura no se sumó al kit.',
              ),
            ],
            if (waiting > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Se detuvieron $waiting lecturas posteriores. Vuelve a escanear esas prendas después de retirar la incorrecta.',
              ),
            ],
          ],
        ),
        tipo: article == null ? TipoAviso.error : TipoAviso.advertencia,
        tituloPersonalizado:
            article == null ? 'Código incorrecto' : 'Unidad excedente',
        cerrarEtiqueta: 'Prenda retirada · continuar',
        requiereConfirmacion: true,
        esperarCierreCompleto: true,
      );
    } finally {
      _dialog = false;
      _redraw(() => _scanAlert = false);
      if (mounted) _focusSku();
    }
  }

  Future<void> _validate() async {
    final code = _sku.text.trim();
    if (code.isEmpty ||
        _kit.isEmpty ||
        (!_editable && !_scanning) ||
        _scanAlert ||
        (_kit['empacador_id'] == null && _validationPackerId == null)) {
      return;
    }
    _sku.clear();
    _scanQueue.add(code);
    if (_scanning) return;
    final kitId = '${_kit['id']}';
    final operation = _operationId!;
    ++_epoch; // Discard older periodic reads while validating.
    _redraw(() {
      _scanning = true;
      _scanFeedback = null;
    });
    try {
      while (mounted && _scanQueue.isNotEmpty) {
        final sku = _scanQueue.removeAt(0);
        final article =
            filasMasiva(
              _kit['articulos'],
            ).where((a) => a['sku'] == sku).firstOrNull;
        if (article == null ||
            numeroMasiva(article['validado']) >=
                numeroMasiva(article['cantidad'])) {
          await _rejectScan(sku, article: article);
          break;
        }
        try {
          await _repo.ejecutar('validar', {
            'operacion_id': operation,
            'kit_id': kitId,
            'sku': sku,
            if (_kit['empacador_id'] == null)
              'empacador_id': _validationPackerId,
            'request_id': MasivaRepository.requestId(),
          });
          // Only confirmed server values are displayed; no optimistic stock changes.
          await _refreshValidation(kitId, operation);
          _redraw(() {
            _lastScanSku = sku;
            _scanFeedback = '$sku · 1 unidad validada';
          });
        } catch (e) {
          MasivaJson detail = {};
          if (e is PostgrestException && e.details != null) {
            try {
              final raw = e.details;
              detail = mapaMasiva(raw is String ? jsonDecode(raw) : raw);
            } catch (_) {
              /* A plain business error has no structured detail. */
            }
          }
          if (['sku_incorrecto', 'unidad_excedente'].contains(detail['tipo'])) {
            await _rejectScan(
              sku,
              article: detail['tipo'] == 'unidad_excedente' ? detail : null,
            );
            try {
              await _refreshValidation(kitId, operation);
            } catch (refreshError) {
              _redraw(() => _error = errorMasiva(refreshError));
            }
          } else {
            final pending = _scanQueue.length;
            _scanQueue.clear();
            _sku.clear();
            _redraw(() {
              _scanAlert = true;
              _error = errorMasiva(e);
            });
            _dialog = true;
            await WidgetsBinding.instance.endOfFrame;
            if (mounted) {
              await mostrarAvisoContenido(
                context,
                Text(
                  '${errorMasiva(e)}${pending > 0 ? '\nSe detuvieron $pending lecturas posteriores; deberán escanearse de nuevo.' : ''}',
                ),
                error: true,
                requiereConfirmacion: true,
                esperarCierreCompleto: true,
              );
            }
            _dialog = false;
            _redraw(() => _scanAlert = false);
          }
          break;
        }
      }
    } finally {
      _scanQueue.clear();
      _redraw(() => _scanning = false);
      if (mounted) _focusSku();
    }
  }

  Future<void> _resetValidation() async {
    if (!_editable || _scanning || _kit.isEmpty) return;
    final kitId = _kit['id'];
    final quantities = [
      for (final item in filasMasiva(_kit['articulos']))
        {'articulo_id': item['id'], 'validado': numeroMasiva(item['validado'])},
    ];
    final v = await _form(
      'Reiniciar validación',
      'Se devolverán al inventario las prendas validadas de este kit para contarlas otra vez. Se conservan el empacador, el empaque y la auditoría. Si otra persona modifica el kit mientras confirmas, deberás actualizarlo.',
      [const _Field('motivo', 'Motivo del reinicio', multiline: true)],
      submit: 'Reiniciar validación',
    );
    if (v == null || !mounted) return;
    await _execute('reiniciar_validacion', {
      'kit_id': kitId,
      'cantidades': quantities,
      'motivo': v['motivo'],
      'request_id': MasivaRepository.requestId(),
    }, label: 'Reiniciando la validación y devolviendo las prendas…');
    if (mounted) _focusSku();
  }

  Future<void> _pack() async {
    if (!_editable || _scanning || _kit.isEmpty) return;
    final items = filasMasiva(_kit['articulos']);
    final done = items.fold<int>(0, (n, a) => n + numeroMasiva(a['validado']));
    if (done == 0) return;
    final missing =
        items
            .where(
              (a) => numeroMasiva(a['validado']) < numeroMasiva(a['cantidad']),
            )
            .toList();
    if (missing.isNotEmpty) {
      _dialog = true;
      final accepted = await confirmarAviso(
        context,
        'Faltan prendas por validar:\n${missing.map((a) => "${a['sku']} · ${a['descripcion']}: faltan ${numeroMasiva(a['cantidad']) - numeroMasiva(a['validado'])}").join('\n')}\n\nPuedes agregarlas después al mismo empaque.',
        titulo: 'Kit incompleto',
        confirmar: 'Empacar parcial',
        cancelar: 'Seguir validando',
      );
      _dialog = false;
      if (!accepted || !mounted) {
        if (mounted) _focusSku();
        return;
      }
    }
    final packages = _validationPackages;
    if (packages.isEmpty) {
      await mostrarAviso(
        context,
        'Crea primero el catálogo de empaques en Configuración.',
      );
      return;
    }
    final number = int.tryParse(_packNumber.text.trim());
    if (number == null ||
        number <= 0 ||
        !packages.any((p) => '${p['id']}' == _packType)) {
      await mostrarAviso(
        context,
        'Selecciona el tipo de empaque e indica un número de contenedor mayor que cero.',
      );
      return;
    }
    var saved = false;
    await _work('Guardando el empaque del kit…', () async {
      await _repo.ejecutar('embalar', {
        'operacion_id': _operationId,
        'kit_id': _kit['id'],
        'caja': number,
        'empaque_id': _packType,
      });
      saved = true;
    });
    if (saved && mounted) {
      _closeValidation();
      _search.clear();
      _redraw(
        () =>
            _scanFeedback =
                'Empaque guardado. Escanea el documento del siguiente kit.',
      );
    }
  }
}
