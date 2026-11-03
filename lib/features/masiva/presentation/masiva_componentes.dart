part of 'masiva_page.dart';

ThemeData _masivaTheme() {
  final base = AppTheme.kardex(TemaModo.corporativo);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'ConductorSans'),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        minimumSize: const Size(0, 42),
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
  );
}

Widget _panel({required Widget child, double padding = 22}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 16),
  padding: EdgeInsets.all(padding),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _line),
  ),
  child: Material(color: Colors.transparent, child: child),
);

Widget _pill(String text, {Color color = _ink, bool dark = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
  decoration: BoxDecoration(
    color: dark ? _lime.withValues(alpha: .13) : color.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: dark ? _lime : color,
    ),
  ),
);

Widget _notice(String text, IconData icon, {Widget? action}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF5DF),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: const Color(0xFF926000)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF795318),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
      if (action != null) action,
    ],
  ),
);

Widget _empty(String title, String detail) => _panel(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 40, color: _muted),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
        ),
      ],
    ),
  ),
);

String _date(dynamic raw) {
  final dt = DateTime.tryParse('$raw')?.toLocal();
  if (dt == null) return '—';
  String n(int value) => value.toString().padLeft(2, '0');
  return '${n(dt.day)}/${n(dt.month)}/${dt.year} ${n(dt.hour)}:${n(dt.minute)}';
}

String _duration(dynamic raw) {
  final seconds = numeroMasiva(raw);
  if (seconds <= 0) return 'Sin registros';
  final minutes = seconds ~/ 60;
  return minutes < 60
      ? '$minutes min ${seconds % 60} s'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}

String _auditDetail(MasivaJson row) {
  final data = mapaMasiva(row['datos']);
  final input = mapaMasiva(data['entrada']);
  final result = mapaMasiva(data['resultado']);
  return [
    if (input['lista'] != null) 'Lista ${input['lista']}',
    if (input['sku'] != null) 'SKU ${input['sku']}',
    if (input['cantidad'] != null) 'Cantidad ${input['cantidad']}',
    if (input['motivo'] != null) '${input['motivo']}',
    if (result['diferencia'] != null) 'Ajuste ${result['diferencia']}',
    if (input['soporte'] != null) 'Soporte ${input['soporte']}',
  ].join(' · ');
}

extension _MasivaViews on _MasivaPageState {
  Widget _assignmentPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Asignaciones y tiempos de empaque',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (final a in _assignments.take(12))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista ${a['lista']} · ${a['empacador']}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Personas ${a['desde']} a ${a['hasta']} · ${a['kits']} kits · ${a['estado']}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(
                      _duration(
                        numeroMasiva(a['segundos']) +
                            (a['estado'] == 'en_curso'
                                ? DateTime.now()
                                    .difference(
                                      DateTime.tryParse(
                                            '${a['ultimo_inicio']}',
                                          ) ??
                                          DateTime.now(),
                                    )
                                    .inSeconds
                                    .clamp(0, 2147483647)
                                : 0),
                      ),
                    ),
                    if (a['estado'] != 'finalizado') ...[
                      OutlinedButton.icon(
                        onPressed:
                            _editable
                                ? () => _execute('tiempo', {
                                  'asignacion_id': a['id'],
                                  'accion':
                                      a['estado'] == 'en_curso'
                                          ? 'pausar'
                                          : 'iniciar',
                                })
                                : null,
                        icon: Icon(
                          a['estado'] == 'en_curso'
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 17,
                        ),
                        label: Text(
                          a['estado'] == 'en_curso' ? 'Pausar' : 'Iniciar',
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _editable && a['inicio'] != null
                                ? () => _execute('tiempo', {
                                  'asignacion_id': a['id'],
                                  'accion': 'finalizar',
                                })
                                : null,
                        child: const Text('Finalizar empaque'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        if (_assignments.length > 12)
          Text(
            'Se muestran 12 de ${_assignments.length} asignaciones. Filtra por lista para localizar las demás.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
      ],
    ),
  );

  Widget _stats(
    double width,
    List<(String, String, String, IconData)> entries,
  ) => LayoutBuilder(
    builder: (_, box) {
      final columns =
          box.maxWidth < 480
              ? 1
              : box.maxWidth < 900
              ? 2
              : 4;
      final size = (box.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 0,
        children: [
          for (final e in entries)
            SizedBox(
              width: size,
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.$1,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                        Icon(e.$4, size: 21, color: _ink),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      e.$2,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.$3,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _summary(double width) {
    final m = mapaMasiva(_data['metricas']);
    final kits = numeroMasiva(m['kits']);
    final armado = numeroMasiva(m['armados']);
    final validated = numeroMasiva(m['validados']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(width < 600 ? 22 : 28),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UNA OPERACIÓN, TODO CONECTADO',
                style: TextStyle(
                  color: Color(0xFFB6D1DC),
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_operation['nombre'] ?? 'Masiva'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_operation['cliente'] ?? ''} · $validated de $kits kits validados',
                style: const TextStyle(color: Color(0xFFCBDDE5)),
              ),
              const SizedBox(height: 23),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: kits == 0 ? 0 : validated / kits,
                  minHeight: 7,
                  backgroundColor: const Color(0xFF315E70),
                  color: _lime,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _select(kits == 0 ? 1 : 3),
                    icon: Icon(
                      kits == 0
                          ? Icons.move_to_inbox_outlined
                          : Icons.qr_code_scanner,
                      size: 18,
                    ),
                    label: Text(
                      kits == 0 ? 'Ir a recepción' : 'Continuar validación',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _select(4),
                    icon: const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Ver documentos',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _stats(width, [
          (
            'Prendas recibidas',
            '${m['recibido'] ?? 0}',
            'Ingresos confirmados',
            Icons.move_to_inbox_outlined,
          ),
          (
            'Disponibles',
            '${m['disponible'] ?? 0}',
            'Inventario de esta masiva',
            Icons.inventory_2_outlined,
          ),
          (
            'Empaques registrados',
            '$armado / $kits',
            'Listos para revisión',
            Icons.task_alt,
          ),
          (
            'Kits validados',
            '$validated',
            'Revisión de prendas completa',
            Icons.verified_outlined,
          ),
        ]),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avanza paso a paso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 20),
              for (final step in [
                (
                  1,
                  '01',
                  'Recepción e inventario',
                  'Carga las cantidades iniciales y registra cada ingreso.',
                  Icons.move_to_inbox_outlined,
                ),
                (
                  8,
                  '02',
                  'Base de datos maestra',
                  'Carga y consulta la distribución de prendas por persona.',
                  Icons.inventory_2_outlined,
                ),
                (
                  2,
                  '03',
                  'Listado maestro',
                  'Revisa el avance por lista, asigna empacadores y registra sus tiempos.',
                  Icons.view_list_outlined,
                ),
                (
                  3,
                  '04',
                  'Validación y empaque',
                  'Otra persona revisa las prendas y agrupa los kits en cajas o bolsas.',
                  Icons.qr_code_scanner,
                ),
                (
                  4,
                  '05',
                  'Listas y rótulos',
                  'Documentos por lista, con responsable principal y logos configurables.',
                  Icons.description_outlined,
                ),
              ])
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: CircleAvatar(
                    backgroundColor: _bg,
                    foregroundColor: _ink,
                    child: Text(
                      step.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    step.$3,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      step.$4,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _select(step.$1),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reportError() async {
    final v = await _form(
      'Reportar MAL EMPAQUE',
      'El error se asocia al empacador original del kit y aplica la penalización configurada. No modifica cantidades de inventario.',
      [const _Field('motivo', 'Describe el error', multiline: true)],
      submit: 'Registrar error',
    );
    if (v == null || !mounted) return;
    await _execute('reportar_error', {
      'kit_id': _kit['id'],
      'motivo': v['motivo'],
      'request_id': MasivaRepository.requestId(),
    });
  }

  Widget _indicators(double width) {
    final m = mapaMasiva(_data['metricas']);
    final total = numeroMasiva(m['kits']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tiempos de la operación',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Estos intervalos incluyen las pausas entre movimientos. El tiempo activo de empaque se mide con el cronómetro.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                children: [
                  for (final t in [
                    (
                      'Recepción',
                      'primera_recepcion',
                      'ultima_recepcion',
                      'duracion_recepcion_segundos',
                    ),
                    (
                      'Validación',
                      'inicio_validacion',
                      'fin_validacion',
                      'duracion_validacion_segundos',
                    ),
                  ])
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$1,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_date(m[t.$2])} → ${m[t.$3] == null && m[t.$2] != null ? 'En curso' : _date(m[t.$3])}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _duration(m[t.$4]),
                            style: const TextStyle(color: _ink),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _stats(width, [
          (
            'Tiempo de empaque',
            _duration(m['segundos_empaque']),
            'Tiempo activo acumulado',
            Icons.timer_outlined,
          ),
          (
            'Promedio por kit',
            _duration(m['promedio_segundos_kit']),
            'Asignaciones terminadas',
            Icons.av_timer,
          ),
          (
            'Kits parciales',
            '${m['parciales'] ?? 0}',
            'Con prendas por completar',
            Icons.timelapse,
          ),
          (
            'Unidades requeridas',
            '${m['unidades'] ?? 0}',
            'Demanda de la base del personal',
            Icons.checklist,
          ),
        ]),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avance de la operación',
                style: TextStyle(
                  fontSize: 18,
                  color: _ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              for (final point in [
                ('Empaques registrados', numeroMasiva(m['armados'])),
                ('Kits validados', numeroMasiva(m['validados'])),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              point.$1,
                              style: const TextStyle(color: _muted),
                            ),
                          ),
                          Text(
                            '${point.$2} / $total',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Semantics(
                        label: point.$1,
                        value: '${point.$2} de $total',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value:
                                total == 0 ? 0 : (point.$2 / total).clamp(0, 1),
                            color: _lime,
                            backgroundColor: _bg,
                            minHeight: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productividad de empaque',
                style: TextStyle(
                  fontSize: 18,
                  color: _ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El promedio corresponde al tiempo activo del rango dividido entre sus kits. No se atribuyen tiempos individuales que no se hayan medido.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 18),
              if (_rows.isEmpty)
                const Text(
                  'Los indicadores aparecerán al registrar tiempos y finalizar kits.',
                  style: TextStyle(color: _muted),
                ),
              for (var i = 0; i < _rows.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _bg,
                    foregroundColor: _ink,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(
                    '${_rows[i]['nombre']}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_rows[i]['kits'] ?? 0} kits · ${_rows[i]['errores'] ?? 0} errores · ${_duration(_rows[i]['promedio_segundos'])} / kit',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _pill('${_rows[i]['puntos'] ?? 0} pts'),
                ),
            ],
          ),
        ),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Validación',
                style: TextStyle(
                  fontSize: 18,
                  color: _ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final v in filasMasiva(m['validadores']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${v['nombre'] ?? v['actor_nombre']}'),
                  subtitle: Text(
                    '${v['prendas'] ?? v['unidades'] ?? 0} prendas validadas',
                  ),
                  trailing: _pill('${v['puntos'] ?? 0} pts'),
                ),
              if (filasMasiva(m['validadores']).isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'Aún no hay validaciones registradas.',
                    style: TextStyle(color: _muted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settings(double width) => Column(
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identidad de los documentos',
              style: TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Los logos vectoriales de Colsubsidio y Quiromar son fijos en los documentos de Masiva. Cada uno conserva el tamaño del rótulo de Despacho: 50 × 8,5 mm.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _marcaDocumento('Colsubsidio'),
                _marcaDocumento('Quiromar'),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _editable ? _leader : null,
              icon: const Icon(Icons.person_pin_outlined, size: 18),
              label: const Text('Responsable principal por lista'),
            ),
          ],
        ),
      ),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personas que arman los kits',
              style: TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final p in _people)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text('${p['nombre']}'),
                subtitle: Text(
                  p['usuario_numero'] == null
                      ? 'Personal sin cuenta de acceso'
                      : 'Usuario ${p['usuario_numero']}',
                ),
              ),
            if (_people.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Registra al personal para asignar listas completas o rangos de kits.',
                  style: TextStyle(color: _muted),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _editable ? _addPerson : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar persona'),
            ),
          ],
        ),
      ),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catálogo compartido de Despacho',
              style: TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Los nombres, medidas y la tara se comparten con Despacho. El peso promedio lleno se configura solo para Masiva.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final p in _packages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(textoEmpaque(p['nombre'])),
                subtitle: Text(
                  '${p['activo'] == false ? 'Inactivo · ' : ''}'
                  '${p['largo'] ?? p['largo_cm'] ?? '—'} × ${p['ancho'] ?? p['ancho_cm'] ?? '—'} × ${p['alto'] ?? p['alto_cm'] ?? '—'} cm · Tara ${p['peso_vacio'] ?? p['peso_neto_kg'] ?? '—'} kg\n'
                  'Promedio Masiva: ${p['peso_promedio_masiva_kg'] == null ? 'pendiente de configurar' : '${p['peso_promedio_masiva_kg']} kg'}',
                ),
                trailing: IconButton(
                  tooltip: 'Editar ${textoEmpaque(p['nombre'])}',
                  onPressed: _editable && _admin ? () => _editPackage(p) : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            if (_packages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Agrega cajas y paquetes al catálogo compartido con su tara y dimensiones.',
                  style: TextStyle(color: _muted),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _editable && _admin ? () => _editPackage() : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar empaque'),
            ),
          ],
        ),
      ),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puntuación',
              style: TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_operation['puntos_kit'] ?? 1} punto(s) por kit · ${_operation['puntos_prenda'] ?? 1} por prenda validada · ${_operation['penalizacion_error'] ?? 2} de penalización por error.',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _editable ? _points : null,
              child: const Text('Configurar puntuación'),
            ),
          ],
        ),
      ),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cierre de operación',
              style: TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Archiva la masiva terminada y crea una nueva cuando tengas la siguiente base. Se conserva todo el historial.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _editable ? _close : null,
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archivar masiva'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _marcaDocumento(String nombre) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_outlined, size: 17, color: _ink),
        const SizedBox(width: 8),
        Text(
          nombre,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Future<void> _points() async {
    final v = await _form(
      'Puntuación de la operación',
      'Los indicadores se recalculan con estos valores. El historial de actividades se conserva.',
      [
        _Field(
          'puntos_kit',
          'Puntos por kit empacado',
          number: true,
          min: 0,
          initial: '${_operation['puntos_kit'] ?? 1}',
        ),
        _Field(
          'puntos_prenda',
          'Puntos por prenda validada',
          number: true,
          min: 0,
          initial: '${_operation['puntos_prenda'] ?? 1}',
        ),
        _Field(
          'penalizacion_error',
          'Penalización por error',
          number: true,
          min: 0,
          initial: '${_operation['penalizacion_error'] ?? 2}',
        ),
      ],
    );
    if (v == null || !mounted) return;
    await _execute(
      'configurar',
      v.map((key, value) => MapEntry(key, int.parse(value))),
    );
  }
}

class _Field {
  const _Field(
    this.key,
    this.label, {
    this.hint,
    this.initial = '',
    this.required = true,
    this.number = false,
    this.min = 1,
    this.max,
    this.multiline = false,
    this.options,
  });
  final String key, label, initial;
  final String? hint;
  final bool required, number, multiline;
  final int min;
  final int? max;
  final List<(String, String)>? options;
}

class _MasivaForm extends StatefulWidget {
  const _MasivaForm({
    required this.title,
    required this.help,
    required this.fields,
    required this.submit,
  });
  final String title, help, submit;
  final List<_Field> fields;
  @override
  State<_MasivaForm> createState() => _MasivaFormState();
}

class _MasivaFormState extends State<_MasivaForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(_Field f, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return f.required ? 'Completa este campo' : null;
    if (f.number) {
      final n = int.tryParse(value);
      if (n == null ||
          !n.isFinite ||
          n < f.min ||
          (f.max != null && n > f.max!)) {
        return f.max == null
            ? 'Ingresa un valor válido desde ${f.min}'
            : 'Ingresa un valor entre ${f.min} y ${f.max}';
      }
    }
    if (f.key == 'hasta' || f.key == 'desde') {
      final from = _controllers['desde']?.text.trim() ?? '';
      final to = _controllers['hasta']?.text.trim() ?? '';
      if (from.isEmpty != to.isEmpty) {
        return 'Completa ambos límites o deja ambos vacíos';
      }
      if (from.isNotEmpty &&
          (int.tryParse(from) ?? 0) > (int.tryParse(to) ?? 0)) {
        return 'El inicio no puede superar el final';
      }
    }
    if (f.key == 'motivo' && value.length < 3) {
      return 'Describe el motivo con al menos 3 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.help,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child:
                      f.options != null
                          ? DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue:
                                _controllers[f.key]!.text.isEmpty
                                    ? null
                                    : _controllers[f.key]!.text,
                            decoration: InputDecoration(
                              labelText: '${f.label}${f.required ? ' *' : ''}',
                            ),
                            items:
                                f.options!
                                    .map(
                                      (o) => DropdownMenuItem(
                                        value: o.$1,
                                        child: Text(
                                          o.$2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => _controllers[f.key]!.text = v ?? '',
                            validator: (v) => _validate(f, v),
                          )
                          : TextFormField(
                            controller: _controllers[f.key],
                            maxLines: f.multiline ? 3 : 1,
                            maxLength: f.multiline ? 1000 : null,
                            keyboardType:
                                f.number
                                    ? TextInputType.number
                                    : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: '${f.label}${f.required ? ' *' : ''}',
                              hintText: f.hint,
                            ),
                            validator: (v) => _validate(f, v),
                          ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.pop(
              context,
              _controllers.map((k, c) => MapEntry(k, c.text.trim())),
            );
          }
        },
        child: Text(widget.submit),
      ),
    ],
  );
}
