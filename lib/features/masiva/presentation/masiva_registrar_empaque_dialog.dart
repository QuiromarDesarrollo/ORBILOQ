import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_row.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../masiva_repository.dart';
import 'masiva_empacador_dialog.dart';

/// Registro de armado separado de la validación de prendas y del cronómetro.
/// El servidor vuelve a comprobar alcance, propietario y estado al guardar.
class MasivaRegistrarEmpaqueDialog extends StatefulWidget {
  const MasivaRegistrarEmpaqueDialog({
    super.key,
    required this.people,
    required this.consultar,
    required this.registrar,
    this.initialLista = '',
    this.agregarEmpacador,
  });

  final List<MasivaJson> people;
  final Future<MasivaJson> Function(String nombre)? agregarEmpacador;
  final String initialLista;
  final Future<MasivaJson> Function(String lista) consultar;
  final Future<void> Function(MasivaJson datos) registrar;

  @override
  State<MasivaRegistrarEmpaqueDialog> createState() => _EmpaqueState();
}

class _EmpaqueState extends State<MasivaRegistrarEmpaqueDialog> {
  late final _lista = TextEditingController(text: widget.initialLista);
  final _desde = TextEditingController();
  final _hasta = TextEditingController();
  MasivaJson? _data;
  String? _person;
  late final List<MasivaJson> _people = [...widget.people];
  String? _assignment;
  String _scope = 'todos';
  String _action = 'registrar';
  bool _loading = false;
  bool _saving = false;
  bool _changed = false;
  String? _error;
  String? _message;
  String? _payloadFingerprint;
  String? _request;
  bool get _busy => _loading || _saving;

  Future<void> _addPerson() async {
    if (_busy || widget.agregarEmpacador == null) return;
    final person = await showWmsDialog<MasivaJson>(
      context,
      (_) => MasivaEmpacadorDialog(guardar: widget.agregarEmpacador!),
    );
    if (person == null || !mounted) return;
    setState(() {
      if (!_people.any((p) => p['id'] == person['id'])) _people.add(person);
      _person = '${person['id']}';
      _assignment = null;
      _error = null;
    });
  }

  bool get _existing => _action == 'pausar' || _action == 'continuar';
  List<MasivaJson> get _kits => filasMasiva(_data?['kits']);
  List<MasivaJson> get _assignments =>
      filasMasiva(_data?['asignaciones'])
          .where(
            (a) =>
                '${a['empacador_id']}' == _person &&
                a['estado'] != 'finalizado',
          )
          .toList();

  @override
  void initState() {
    super.initState();
    if (widget.initialLista.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _lista.dispose();
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _lista.text.trim().isEmpty) return;
    final list = _lista.text.trim();
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _assignment = null;
    });
    try {
      final data = await widget.consultar(list);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = errorMasiva(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _armed(MasivaJson kit) =>
      kit['armado'] != null &&
      kit['armado'] != false &&
      '${kit['armado']}'.isNotEmpty;
  bool _mineOrFree(MasivaJson kit) =>
      kit['empacador_id'] == null ||
      '${kit['empacador_id']}'.isEmpty ||
      '${kit['empacador_id']}' == _person;

  List<MasivaJson> get _selected {
    if (_existing) {
      return _kits
          .where((k) => '${k['asignacion_id']}' == _assignment)
          .toList();
    }
    if (_scope == 'pendientes') {
      return _kits.where((k) => !_armed(k) && _mineOrFree(k)).toList();
    }
    if (_scope == 'rango') {
      final start = int.tryParse(_desde.text);
      final end = int.tryParse(_hasta.text);
      if (start == null || end == null || start > end) return [];
      return _kits
          .where(
            (k) =>
                numeroMasiva(k['numero_persona']) >= start &&
                numeroMasiva(k['numero_persona']) <= end,
          )
          .toList();
    }
    return _kits;
  }

  String? get _conflict {
    if (_data == null) return 'Consulta una lista antes de registrar.';
    if (_person == null) return 'Selecciona al empacador.';
    if (_existing) {
      if (_assignment == null) {
        return 'Selecciona una asignación del empacador.';
      }
      final assignment =
          _assignments.where((a) => '${a['id']}' == _assignment).firstOrNull;
      if (assignment == null) return 'La asignación ya no está disponible.';
      if (_action == 'pausar' && assignment['estado'] != 'en_curso') {
        return 'Solo puedes pausar una asignación en curso.';
      }
      if (_action == 'continuar' && assignment['estado'] == 'en_curso') {
        return 'La asignación ya está en curso.';
      }
      return null;
    }
    if (_scope == 'rango') {
      final start = int.tryParse(_desde.text);
      final end = int.tryParse(_hasta.text);
      if (start == null || end == null || start <= 0 || start > end) {
        return 'Indica un rango válido de números de persona, desde el menor hasta el mayor.';
      }
    }
    if (_scope == 'rango' &&
        (!_kits.any(
              (k) =>
                  numeroMasiva(k['numero_persona']) ==
                  int.tryParse(_desde.text),
            ) ||
            !_kits.any(
              (k) =>
                  numeroMasiva(k['numero_persona']) ==
                  int.tryParse(_hasta.text),
            ))) {
      return 'Los extremos del rango deben corresponder a personas de esta lista.';
    }
    if (_selected.isEmpty) return 'No hay kits disponibles para este alcance.';
    if (_selected.any(_armed)) {
      return 'El alcance incluye kits ya terminados. Usa Solo pendientes o ajusta el rango.';
    }
    if (_selected.any((k) => !_mineOrFree(k))) {
      return 'El alcance incluye kits de otro empacador. Ajusta el rango o usa Solo pendientes.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = _conflict;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final payload = <String, dynamic>{
      'lista': '${_data!['lista'] ?? _lista.text.trim()}',
      'empacador_id': _person,
      'accion': _action,
      if (_existing) 'asignacion_id': _assignment,
      if (!_existing) 'alcance': _scope,
      if (!_existing && _scope == 'rango') 'desde': int.parse(_desde.text),
      if (!_existing && _scope == 'rango') 'hasta': int.parse(_hasta.text),
    };
    final fingerprint = jsonEncode(payload);
    if (fingerprint != _payloadFingerprint) {
      _payloadFingerprint = fingerprint;
      _request = MasivaRepository.requestId();
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.registrar({...payload, 'request_id': _request});
      if (!mounted) return;
      setState(() {
        _changed = true;
        _message =
            _action == 'registrar'
                ? 'Kits registrados como terminados. La validación de prendas conserva su estado.'
                : _action == 'pausar'
                ? 'Tiempo pausado. El tiempo acumulado se conserva.'
                : 'Tiempo de empaque en curso.';
        _payloadFingerprint = null;
        _request = null;
        _assignment = null;
        _data = null;
      });
      // No vuelve a enviar la escritura si falla la lectura posterior.
      final data = await widget.consultar(_lista.text.trim());
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = errorMasiva(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _input(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());
  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final conflict = _conflict;
    return PopScope(
      canPop: !_busy,
      child: WmsDialogShell(
        title: 'Registrar empaque',
        subtitle: 'Lista completa, rango de personas o kits pendientes',
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.petroleo,
        compactHeader: true,
        maxWidth: 850,
        expand: true,
        canClose: !_busy,
        onClose: () => Navigator.of(context).pop(_changed),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.alertRed),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _message!,
                    style: const TextStyle(
                      color: AppColors.actionGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ResponsiveRow(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('empaque-lista'),
                      controller: _lista,
                      enabled: !_busy,
                      decoration: _input('Lista de empaque'),
                      onChanged:
                          (_) => setState(() {
                            _data = null;
                            _assignment = null;
                            _message = null;
                          }),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.search),
                    label: const Text('Consultar lista'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading) const Center(child: WmsLoader()),
              if (_data != null) ...[
                _box(
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      Text('Total: ${_data!['total'] ?? _kits.length} kits'),
                      Text('Terminados: ${_data!['terminados'] ?? 0}'),
                      Text('Pendientes: ${_data!['pendientes'] ?? 0}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: const ValueKey('empaque-persona'),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('empaque-persona-$_person'),
                    initialValue: _person,
                    isExpanded: true,
                    decoration: _input('Empacador'),
                    items: [
                      for (final p in _people)
                        DropdownMenuItem(
                          value: '${p['id']}',
                          child: Text(
                            '${p['nombre']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        _busy
                            ? null
                            : (v) => setState(() {
                              _person = v;
                              _assignment = null;
                              _error = null;
                            }),
                  ),
                ),
                if (widget.agregarEmpacador != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _addPerson,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Agregar empacador'),
                    ),
                  ),
                if (_people.isEmpty && widget.agregarEmpacador == null)
                  const Text(
                    'Pide al administrador que agregue los nombres de los empacadores.',
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _action,
                  decoration: _input('Qué quieres registrar'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'registrar',
                      child: Text('Registrar kits terminados'),
                    ),
                    DropdownMenuItem(
                      value: 'iniciar',
                      child: Text('Iniciar tiempo de empaque'),
                    ),
                    DropdownMenuItem(
                      value: 'pausar',
                      child: Text('Pausar tiempo'),
                    ),
                    DropdownMenuItem(
                      value: 'continuar',
                      child: Text('Continuar tiempo'),
                    ),
                  ],
                  onChanged:
                      _busy
                          ? null
                          : (v) => setState(() {
                            _action = v!;
                            _assignment = null;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 14),
                if (!_existing) ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('empaque-alcance'),
                    initialValue: _scope,
                    isExpanded: true,
                    decoration: _input('Alcance'),
                    items: const [
                      DropdownMenuItem(
                        value: 'todos',
                        child: Text('Toda la lista'),
                      ),
                      DropdownMenuItem(
                        value: 'rango',
                        child: Text('Parcial · rango de personas'),
                      ),
                      DropdownMenuItem(
                        value: 'pendientes',
                        child: Text('Solo pendientes'),
                      ),
                    ],
                    onChanged:
                        _busy
                            ? null
                            : (v) => setState(() {
                              _scope = v!;
                              _error = null;
                            }),
                  ),
                  if (_scope == 'rango') ...[
                    const SizedBox(height: 14),
                    ResponsiveRow(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('empaque-desde'),
                            controller: _desde,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _input('Desde número de persona'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('empaque-hasta'),
                            controller: _hasta,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _input('Hasta número de persona'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _scope == 'pendientes'
                        ? 'Incluye únicamente kits sin terminar, libres o asignados a este empacador. Conserva lo ya registrado.'
                        : 'Los kits terminados o de otro empacador no se sobrescriben.',
                    style: const TextStyle(
                      color: AppColors.slate600,
                      fontSize: 12,
                    ),
                  ),
                ] else
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'empaque-asignacion-$_person-$_action-$_assignment',
                    ),
                    initialValue: _assignment,
                    isExpanded: true,
                    decoration: _input('Asignación del empacador'),
                    items: [
                      for (final a in _assignments)
                        DropdownMenuItem(
                          value: '${a['id']}',
                          child: Text(
                            '${a['desde'] ?? 'Inicio'}–${a['hasta'] ?? 'Fin'} · ${a['estado']} · ${numeroMasiva(a['segundos'])} s',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        _busy
                            ? null
                            : (v) => setState(() {
                              _assignment = v;
                              _error = null;
                            }),
                  ),
                const SizedBox(height: 14),
                Text(
                  '${selected.length} kits en el alcance seleccionado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (selected.isNotEmpty)
                  SizedBox(
                    height: selected.length < 4 ? selected.length * 64.0 : 220,
                    child: ListView.builder(
                      itemCount: selected.length,
                      itemExtent: 64,
                      itemBuilder: (_, i) {
                        final k = selected[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            'Persona ${k['numero_persona']} · ${k['nombre']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_armed(k) ? 'Terminado' : 'Pendiente'} · ${k['empacador'] ?? 'Sin asignar'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(
                            _armed(k)
                                ? Icons.check_circle_outline
                                : Icons.inventory_2_outlined,
                            color:
                                _armed(k)
                                    ? AppColors.actionGreen
                                    : AppColors.petroleo,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                if (conflict != null)
                  _box(
                    Text(
                      conflict,
                      style: const TextStyle(color: AppColors.amberChip),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _action == 'registrar'
                      ? 'Este registro no inventa una duración: conserva los tiempos reales existentes y pausa el tramo en curso que corresponda.'
                      : 'El cronómetro conserva el tiempo acumulado. Las pausas no cuentan.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate600,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy || conflict != null ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: WmsLoader(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving
                          ? 'Guardando…'
                          : _action == 'registrar'
                          ? 'Registrar terminados'
                          : _action == 'pausar'
                          ? 'Pausar'
                          : _action == 'continuar'
                          ? 'Continuar'
                          : 'Iniciar empaque',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
