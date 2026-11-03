part of 'masiva_page.dart';

extension _MasivaActions on _MasivaPageState {
  Future<Map<String, String>?> _form(
    String title,
    String help,
    List<_Field> fields, {
    String submit = 'Guardar',
  }) async {
    if (_scanning || _scanAlert) return null;
    _dialog = true;
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => Theme(
              data: _masivaTheme(),
              child: _MasivaForm(
                title: title,
                help: help,
                fields: fields,
                submit: submit,
              ),
            ),
      );
    } finally {
      _dialog = false;
    }
  }

  Future<void> _newOperation() async {
    final v = await _form(
      'Nueva masiva',
      'Cada operación comienza con inventario independiente y sus propios documentos.',
      [
        const _Field(
          'nombre',
          'Nombre de la operación',
          hint: 'Masiva II · 2026',
        ),
        const _Field('cliente', 'Cliente'),
      ],
      submit: 'Crear operación',
    );
    if (v == null || !mounted) return;
    await _work('Creando la masiva…', () async {
      final r = await _repo.ejecutar('crear_operacion', v);
      _operationId = (r['id'] ?? r['operacion_id'])?.toString();
      _section = 0;
      _page = 1;
    });
  }

  Future<void> _import(String type) async {
    final imported = mapaMasiva(
      mapaMasiva(mapaMasiva(_data['metricas'])['importaciones'])[type],
    );
    if (imported['estado'] == 'confirmada') {
      await mostrarAviso(
        context,
        'Esta base ya fue cargada. Al terminar la operación, archívala y crea otra masiva para una nueva base.',
      );
      return;
    }
    if (imported['id'] != null) {
      final discard = await _form(
        'Carga anterior sin finalizar',
        'Hay una importación incompleta. Puedes descartar únicamente esa carga pendiente y volver a seleccionar el Excel. Los datos confirmados no se modifican.',
        [],
        submit: 'Descartar carga pendiente',
      );
      if (discard == null || !mounted) return;
      var cancelled = false;
      await _work('Descartando carga incompleta…', () async {
        await _repo.ejecutar('cancelar_importacion', {
          'operacion_id': _operationId,
          'importacion_id': imported['id'],
        });
        cancelled = true;
      });
      if (!cancelled || !mounted) return;
    }
    _dialog = true;
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
    } catch (e) {
      if (mounted) await mostrarAviso(context, errorMasiva(e), error: true);
    } finally {
      _dialog = false;
    }
    if (picked == null || !mounted) return;
    final file = picked.files.single;
    if (file.bytes == null) return;
    MasivaImportacion? preview;
    await _work('Analizando el Excel y comprobando sus datos…', () async {
      preview = await leerMasivaExcel(file.bytes!, tipo: type);
    });
    if (preview == null || !mounted) return;
    final p = preview!;
    _dialog = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              type == 'recepcion'
                  ? 'Revisar plan de recepción'
                  : 'Revisar base del personal',
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Text('${p.filas.length} filas · ${p.unidades} unidades'),
                    const SizedBox(height: 14),
                    if (type == 'recepcion')
                      const Text(
                        'Solo se cargarán las cantidades solicitadas. Las cantidades recibidas empiezan en cero.',
                      ),
                    if (type == 'personal')
                      const Text(
                        'Se crearán los kits por lista y cédula. La base se carga una sola vez por operación.',
                      ),
                    for (final warning in p.avisos.take(15))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          warning,
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    if (p.errores.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        '${p.errores.length} errores por corregir',
                        style: const TextStyle(
                          color: Color(0xFFAA3424),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final e in p.errores.take(30))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(e),
                        ),
                      if (p.errores.length > 30)
                        const Text(
                          'Corrige los errores del archivo y vuelve a analizarlo para revisar los restantes.',
                        ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Muestra de las primeras filas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final r in p.filas.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${r['sku']} · ${r['descripcion']}'),
                        subtitle: Text(
                          type == 'recepcion'
                              ? '${r['proveedor']} · Pedido ${r['pedido']}'
                              : 'Lista ${r['lista']} · Persona ${r['numero_persona']}',
                        ),
                        trailing: Text('× ${r['cantidad']}'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed:
                    p.errores.isEmpty && p.filas.isNotEmpty
                        ? () => Navigator.pop(ctx, true)
                        : null,
                child: const Text('Confirmar carga'),
              ),
            ],
          ),
    );
    _dialog = false;
    if (accepted != true || !mounted) return;
    await _work(
      'Cargando y verificando la base…',
      () => _repo.importar(
        operacion: _operationId!,
        tipo: type,
        archivo: file.name,
        filas: p.filas,
        progreso: (n) => _redraw(() => _progress = n),
      ),
    );
  }

  Future<void> _receive(MasivaJson row) => _openReceiptStation(initialRow: row);

  List<(String, String)> get _personOptions =>
      _people.map((p) => ('${p['id']}', '${p['nombre']}')).toList();
  List<_Field> _rangeFields() => [
    _Field('lista', 'Lista de empaque', initial: _list.text),
    _Field('empacador_id', 'Empacador', options: _personOptions),
    const _Field(
      'desde',
      'Desde el número de persona',
      number: true,
      required: false,
    ),
    const _Field(
      'hasta',
      'Hasta el número de persona',
      number: true,
      required: false,
    ),
  ];

  MasivaJson _rangeData(Map<String, String> v) => {
    'lista': v['lista'],
    'empacador_id': v['empacador_id'],
    if (v['desde']?.isNotEmpty == true) 'desde': int.parse(v['desde']!),
    if (v['hasta']?.isNotEmpty == true) 'hasta': int.parse(v['hasta']!),
  };

  Future<void> _assign() async {
    if (_people.isEmpty) {
      await mostrarAviso(
        context,
        'Registra primero las personas que empacan en Configuración. No necesitan una cuenta de acceso.',
      );
      return;
    }
    final v = await _form(
      'Asignar empaque de kits',
      'Deja ambos números vacíos si una persona empaca toda la lista. Si trabajan varias personas, indica el rango inclusivo. La asignación no sobrescribe kits de otra persona.',
      _rangeFields(),
      submit: 'Asignar kits',
    );
    if (v == null || !mounted) return;
    await _execute('asignar', _rangeData(v));
  }

  Future<void> _time() async {
    if (_people.isEmpty) {
      await mostrarAviso(
        context,
        'Registra primero al empacador en Configuración.',
      );
      return;
    }
    final v = await _form(
      'Registrar empaque (tiempo real)',
      'Selecciona la lista y el empacador. Deja ambos números vacíos si empacó toda la lista. Iniciar asigna los kits y comienza el tiempo; las pausas no cuentan. La validación puede avanzar en paralelo.',
      [
        ..._rangeFields(),
        const _Field(
          'accion',
          'Acción',
          initial: 'iniciar',
          options: [
            ('iniciar', 'Iniciar / continuar'),
            ('pausar', 'Pausar'),
            ('finalizar', 'Finalizar empaque'),
          ],
        ),
      ],
      submit: 'Registrar',
    );
    if (v == null || !mounted) return;
    await _execute('tiempo', {..._rangeData(v), 'accion': v['accion']});
  }

  Future<void> _camera({bool document = false, bool reception = false}) async {
    if (_cameraOpen || _scanning || _scanAlert || _loading) return;
    if (reception && (_receiptOrder == null || !_editable)) return;
    if (!document &&
        !reception &&
        (!_validationAvailable ||
            _kit.isEmpty ||
            _validationSelectedPacker == null)) {
      return;
    }
    final previousDialog = _dialog;
    _cameraOpen = true;
    _dialog = true;
    FocusManager.instance.primaryFocus?.unfocus();
    String? captured;
    try {
      captured = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => MasivaCameraScanner(
              title:
                  document
                      ? 'Leer documento'
                      : reception
                      ? 'Recibir prenda'
                      : 'Validar prenda',
              subtitle:
                  document
                      ? 'Masivas · Documento / cédula'
                      : reception
                      ? 'OC ${_receiptOrder!['pedido']} · ${_receiptOrder!['proveedor']}'
                      : 'Lista ${_kit['lista']} · ${_kit['nombre']}',
              instruction:
                  document
                      ? 'Enfoca el código del documento o ingresa la cédula manualmente.'
                      : reception
                      ? 'Cada lectura añade 1 unidad pendiente de confirmar.'
                      : 'Cada lectura válida registra 1 unidad del kit.',
              closeOnSuccess: document,
              onRead: (code) async {
                if (!mounted) {
                  return const FeedbackMessage.error('La vista se cerró.');
                }
                if (document) {
                  _search.text = code;
                  await _searchRecords();
                  if (_kit.isNotEmpty && '${_kit['cedula']}' == code) {
                    return const FeedbackMessage.ok('Documento encontrado');
                  }
                  return FeedbackMessage.error(
                    _error ??
                        _scanFeedback ??
                        'No se encontró el documento. Ingresa la cédula manualmente.',
                  );
                }
                if (!_editable) {
                  return FeedbackMessage.error(
                    _error ??
                        'Revisa la operación antes de continuar. Si hay una confirmación pendiente, vuelve al formulario para recuperarla.',
                  );
                }
                if (reception) {
                  _receiptSku.text = code;
                  await _scanReceipt();
                  return _receiptError
                      ? FeedbackMessage.error(
                        _receiptMessage ?? 'No se pudo añadir la prenda.',
                      )
                      : FeedbackMessage.ok(
                        _receiptMessage ?? 'Prenda pendiente de confirmar',
                      );
                }
                final article =
                    filasMasiva(
                      _kit['articulos'],
                    ).where((a) => a['sku'] == code).firstOrNull;
                if (article == null) {
                  return FeedbackMessage.error(
                    '$code no pertenece al kit. Retira la prenda antes de continuar.',
                  );
                }
                if (numeroMasiva(article['validado']) >=
                    numeroMasiva(article['cantidad'])) {
                  return FeedbackMessage.error(
                    '$code: cantidad completa. Retira la unidad adicional; no se sumó al kit.',
                  );
                }
                _sku.text = code;
                await _validate();
                return _scanFeedback != null
                    ? FeedbackMessage.ok(_scanFeedback!)
                    : FeedbackMessage.error(
                      _error ??
                          'Esta lectura no se sumó. Revisa el kit antes de continuar.',
                    );
              },
            ),
      );
    } finally {
      _cameraOpen = false;
      _dialog = previousDialog;
      if (mounted) {
        if (reception && _receiptDialogOpen) {
          _receiptFocus.requestFocus();
        } else if (document && (captured == null || _kit.isEmpty)) {
          _personFocus.requestFocus();
        } else if (_kit.isNotEmpty && _validationSelectedPacker == null) {
          _validationPackerFocus.requestFocus();
        } else {
          _focusSku();
        }
      }
    }
  }

  Future<void> _reopen() async {
    final v = await _form(
      'Reabrir kit',
      'Se conservarán el empacador, la caja y las cantidades ya validadas. El motivo quedará en auditoría.',
      [const _Field('motivo', 'Motivo de la reapertura', multiline: true)],
      submit: 'Reabrir kit',
    );
    if (v == null || !mounted) return;
    await _execute('reabrir', {'kit_id': _kit['id'], 'motivo': v['motivo']});
  }

  Future<void> _correct(MasivaJson item) async {
    final v = await _form(
      'Corregir cantidad validada',
      '${item['sku']} · ${item['descripcion']}\nSe registra la cantidad final correcta. El inventario se ajustará únicamente por la diferencia.',
      [
        _Field(
          'cantidad',
          'Cantidad final validada',
          initial: '${item['validado'] ?? 0}',
          number: true,
          min: 0,
          max: numeroMasiva(item['cantidad']),
        ),
        const _Field('motivo', 'Motivo de la corrección', multiline: true),
      ],
      submit: 'Guardar corrección',
    );
    if (v == null || !mounted) return;
    await _execute('corregir', {
      'kit_id': _kit['id'],
      'articulo_id': item['id'],
      'cantidad': int.parse(v['cantidad']!),
      'motivo': v['motivo'],
      'request_id': MasivaRepository.requestId(),
    });
  }

  Future<void> _document(String type) async {
    final v = await _form(
      type == 'lista' ? 'Generar lista de empaque' : 'Generar rótulos',
      'Se emitirá una versión con las prendas validadas y ubicadas en un empaque. Incluirá sus pendientes en un anexo. El responsable y los logos se conservarán para reimprimirla.',
      [_Field('lista', 'Lista de empaque', initial: _list.text)],
      submit: 'Generar PDF',
    );
    if (v == null || !mounted) return;
    await _work('Preparando y guardando el documento…', () async {
      final doc = await _repo.ejecutar('documento', {
        'operacion_id': _operationId,
        'lista': v['lista'],
        'tipo': type,
      });
      await _downloadDocument(doc, type);
    });
  }

  Future<void> _downloadDocument(MasivaJson doc, String type) async {
    final snapshot = mapaMasiva(doc['snapshot']);
    if (snapshot.isEmpty) {
      throw const MasivaError('No se encontró la versión del documento.');
    }
    final bytes =
        type == 'rotulo'
            ? await generarRotulosMasiva(snapshot)
            : await generarListaMasiva(snapshot);
    final number =
        snapshot['lista'] is Map
            ? mapaMasiva(snapshot['lista'])['lista']
            : snapshot['lista'];
    if (type == 'lista') {
      await descargarPdf(bytes, nombreArchivoListaMasiva(snapshot));
    } else {
      final name =
          '${type}_${number}_v${doc['version'] ?? snapshot['version'] ?? 1}'
              .replaceAll(RegExp(r'[^\w-]'), '_');
      await descargarPdf(bytes, '$name.pdf');
    }
  }

  Future<void> _reprint(MasivaJson row) =>
      _work('Recuperando la versión guardada…', () async {
        final result = await _repo.consultar(
          operacion: _operationId,
          vista: 'documentos',
          buscar: '${row['id']}',
        );
        final doc =
            filasMasiva(
              result['filas'],
            ).where((d) => d['id'] == row['id']).firstOrNull;
        if (doc == null) {
          throw const MasivaError('No se encontró el documento solicitado.');
        }
        if (row['tipo'] == 'lista') {
          await _repo.ejecutar('registrar_impresion', {
            'operacion_id': _operationId,
            'documento_id': row['id'],
            'lista': row['lista'],
          });
        }
        await _downloadDocument(doc, '${row['tipo']}');
      });

  Future<void> _export() => _work(
    'Preparando todas las filas del reporte…',
    () async {
      final all = <MasivaJson>[];
      var page = 1;
      while (true) {
        final result =
            _section == 1
                ? await _repo.consultarRecepcion(
                  operacion: _operationId!,
                  buscar: _search.text.trim(),
                  filtros: _receiptOrder == null ? _receptionFilters : const {},
                  pagina: page,
                  proveedor: _receiptOrder?['proveedor']?.toString(),
                  pedido: _receiptOrder?['pedido']?.toString(),
                )
                : await _repo.consultar(
                  operacion: _operationId,
                  vista: _sections[_section].$3,
                  buscar: _search.text.trim(),
                  lista: _list.text.trim(),
                  pagina: page,
                );
        final rows = filasMasiva(result['filas']);
        all.addAll(rows);
        if (rows.isEmpty || all.length >= numeroMasiva(result['total'])) break;
        page++;
      }
      await exportarMasivaExcel(
        _section == 1
            ? [
              for (final row in all)
                {
                  'ORDEN DE COMPRA': row['pedido'],
                  'PROVEEDOR': row['proveedor'],
                  if (_receiptOrder != null) 'SKU': row['sku'],
                  if (_receiptOrder != null) 'PRENDA': row['descripcion'],
                  'CANTIDAD PENDIENTE POR RECIBIR': row['pendiente'],
                  'CANTIDAD A RECIBIR': row['esperado'],
                  'CANTIDAD RECIBIDA': row['recibido'],
                  if (_receiptOrder == null) 'HORARIO': row['horario'],
                  if (_receiptOrder == null) 'NOVEDAD': row['novedad'],
                  'SALDO':
                      _receiptOrder == null
                          ? row['saldo']
                          : row['saldo_oc_sku'],
                },
            ]
            : all,
        nombre: 'Masiva_${_sections[_section].$3}',
      );
    },
  );

  Future<void> _addPerson() async {
    final v = await _form(
      'Registrar empacador',
      'Seleccionable al asignar kits. Si tiene cuenta ORBILOQ, vincula su número de usuario para conservar la atribución del empaque y la validación.',
      [
        const _Field('nombre', 'Nombre completo'),
        const _Field(
          'usuario_numero',
          'Número de usuario ORBILOQ',
          required: false,
        ),
      ],
    );
    if (v == null || !mounted) return;
    await _execute('guardar_personal', {
      'nombre': v['nombre'],
      if (v['usuario_numero']?.isNotEmpty == true)
        'usuario_numero': v['usuario_numero'],
    });
  }

  Future<void> _editPackage([MasivaJson? package]) async {
    if (!_admin || !_editable) return;
    _dialog = true;
    try {
      final saved = await showWmsDialog<bool>(
        context,
        (_) => EmpaqueEditor(fila: package, mostrarPesoMasiva: true),
      );
      if (saved == true && mounted) await _load(silent: true);
    } finally {
      _dialog = false;
    }
  }

  Future<void> _leader() async {
    final v = await _form(
      'Responsable principal de la lista',
      'Selecciona el nombre del responsable principal que aparecerá en el encabezado. Los líderes originales permanecen guardados en la lista.',
      [
        _Field('lista', 'Lista de empaque', initial: _list.text),
        const _Field('responsable', 'Nombre del responsable principal'),
      ],
    );
    if (v == null || !mounted) return;
    await _execute('configurar', v);
  }

  Future<void> _close() async {
    final v = await _form(
      'Archivar operación',
      'La operación quedará disponible para consulta. Se conservarán auditoría, documentos, autoría e indicadores; los sobrantes permanecerán en esta masiva y no pasarán a otra.',
      [const _Field('motivo', 'Motivo o nota de cierre', multiline: true)],
      submit: 'Archivar masiva',
    );
    if (v == null || !mounted) return;
    await _execute('cerrar_operacion', v, label: 'Archivando la operación…');
  }
}
