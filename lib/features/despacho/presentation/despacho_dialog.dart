import '../../../shared/widgets/wms_scan_field.dart';
import '../../../shared/widgets/feedback_banner.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/operario_actual.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key});
  @override
  ConsumerState<DespachoDialog> createState() => _DespachoState();
}

class _DespachoState extends ConsumerState<DespachoDialog> {
  String? _cliente, _oc;
  final _ops = <String>{};
  final _cantidades = <String, TextEditingController>{};
  final _qr = TextEditingController();
  bool _ocupado = false;
  String? _mensaje, _solicitud;
  List<Map<String, dynamic>>? _pendiente;
  @override
  void dispose() {
    _qr.dispose();
    for (final c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _limpiar() {
    _ops.clear();
    for (final c in _cantidades.values) {
      c.dispose();
    }
    _cantidades.clear();
  }

  TextEditingController _cantidad(ItemKardex k) =>
      _cantidades.putIfAbsent(k.id, () => TextEditingController(text: '0'));
  List<ItemKardex> get _items =>
      (ref.read(wmsSnapshotProvider).value?.kardex ?? [])
          .where((i) => !i.eliminada)
          .toList();
  List<ItemKardex> get _lineas => _items
      .where((i) => i.item.cliente == _cliente && i.item.oc == _oc)
      .toList();
  void _seleccionar(String op, bool seleccionar) {
    setState(() {
      if (seleccionar) {
        _ops.add(op);
      } else {
        _ops.remove(op);
        for (final i in _lineas.where((i) => i.item.op == op)) {
          _cantidad(i).text = '0';
        }
      }
    });
  }

  void _escanear(String texto) {
    final q = QrPrenda.tryParse(texto);
    _qr.clear();
    final item = q == null
        ? null
        : _items
            .where((i) => i.item.op == q.op && i.item.codigo == q.codigo)
            .firstOrNull;
    if (item == null) {
      setState(() => _mensaje = 'QR no encontrado.');
      return;
    }
    setState(() {
      if (_cliente != item.item.cliente || _oc != item.item.oc) _limpiar();
      _cliente = item.item.cliente;
      _oc = item.item.oc;
      _ops.add(item.item.op);
    });
  }

  FeedbackMessage _leerCamara(String raw) {
    final qr = QrPrenda.tryParse(raw);
    final item = qr == null ? null : _items.where((i) =>
        i.item.op == qr.op && i.item.codigo == qr.codigo).firstOrNull;
    if (item == null) return const FeedbackMessage.error('QR no encontrado.');
    // La cámara no debe borrar una selección previa al encontrar otra OC.
    if (_ops.isNotEmpty && (_cliente != item.item.cliente || _oc != item.item.oc)) {
      return const FeedbackMessage.error('La etiqueta pertenece a otra OC. Termina la selección actual antes de cambiar de orden.');
    }
    _escanear(raw);
    return FeedbackMessage.ok('OP ${item.item.op} · Agregada a la selección de despacho. Define las cantidades al volver.');
  }

  Future<void> _preparar({bool completa = false}) async {
    if (_ocupado) return;
    if (_pendiente != null) {
      await _guardar();
      return;
    }
    try {
      final cantidades = <String, int>{};
      for (final i in _lineas) {
        if (completa) {
          if (i.pendienteDespacho > 0) cantidades[i.id] = i.pendienteDespacho;
        } else if (_ops.contains(i.item.op)) {
          final raw = _cantidad(i).text.trim();
          final q = int.tryParse(raw);
          if (q == null || q < 0) {
            throw const FormatException(
                'Revisa las cantidades. Usa 0 para no despachar una talla.');
          }
          if (q > 0) cantidades[i.id] = q;
        }
      }
      final plan = planificarDespacho(_lineas, cantidades);
      final total = plan.fold<int>(0, (n, l) => n + (l['cantidad'] as int));
      final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(completa
                      ? 'Completar toda la OC'
                      : 'Confirmar despacho seleccionado'),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                'Cliente: $_cliente\nOC: ${_oc!.isEmpty ? 'Sin OC' : _oc}\nTotal: $total Uds'),
                            const Divider(),
                            for (final l in plan)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                      'OP ${l['op']} · ${l['codigo']} (${l['talla']}) · ${l['cantidad']} Uds desde ${l['ubicacion']}')),
                            const Text(
                                'Confirma que vas a retirar estas cantidades de los estantes indicados.'),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirmar despacho'))
                  ]));
      if (confirmar != true || !mounted) return;
      _pendiente = plan;
      _solicitud = nuevaSolicitudDespacho();
      await _guardar();
    } catch (e) {
      if (mounted) {
        setState(() => _mensaje = e is FormatException
            ? e.message
            : 'No se pudo preparar el despacho: $e');
      }
    }
  }

  Future<void> _guardar() async {
    final repo = ref.read(despachosOcProvider);
    if (repo == null) {
      setState(() {
        _mensaje = 'No se pudo conectar al servicio de despachos.';
        _pendiente = null;
        _solicitud = null;
      });
      return;
    }
    setState(() => _ocupado = true);
    try {
      await repo.confirmar(_solicitud!, _cliente!, _oc!, _pendiente!);
      _pendiente = null;
      _solicitud = null;
      ref.invalidate(historialDespachosProvider);
      var mensaje = 'Despacho registrado correctamente.';
      try {
        await ref.read(wmsRepositoryProvider).refrescar();
      } catch (_) {
        mensaje =
            'Despacho registrado. Actualiza la tabla para ver los nuevos saldos.';
      }
      if (mounted) {
        setState(() {
          _limpiar();
          _mensaje = mensaje;
        });
      }
    } on PostgrestException catch (e) {
      _pendiente = null;
      _solicitud = null;
      if (mounted) setState(() => _mensaje = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _mensaje =
            'No se pudo confirmar la respuesta. Reintenta este mismo despacho; su identificador evita duplicarlo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(wmsSnapshotProvider);
    final items = (estado.value?.kardex ?? <ItemKardex>[])
        .where((i) => !i.eliminada)
        .toList();
    final clientes = items.map((i) => i.item.cliente).toSet().toList()..sort();
    final ocs = items
        .where((i) => i.item.cliente == _cliente)
        .map((i) => i.item.oc)
        .toSet()
        .toList()
      ..sort();
    final congelado = _ocupado || _pendiente != null;
    return PopScope(
        canPop: !congelado,
        child: WmsDialogShell(
            canClose: !congelado,
            title: 'Despachos por orden de compra',
            icon: Icons.local_shipping,
            iconColor: Colors.orange,
            expand: true,
            maxWidth: 1100,
            child: DefaultTabController(
                length: 2,
                child: Column(children: [
                  const TabBar(
                      tabs: [Tab(text: 'DESPACHAR'), Tab(text: 'HISTORIAL')]),
                  Expanded(
                      child: TabBarView(children: [
                    ListView(children: [
                      const SizedBox(height: 12),
                      const OperarioActual(label: 'Despachado por'),
                      if (_mensaje != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(_mensaje!)),
                      if (estado.isLoading) const WmsLoadingStrip(),
                      if (estado.hasError)
                        const Text(
                            'No se pudo cargar el inventario. Cierra y vuelve a abrir.'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          key: ValueKey(_cliente),
                          initialValue:
                              clientes.contains(_cliente) ? _cliente : null,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Cliente'),
                          items: [
                            for (final c in clientes)
                              DropdownMenuItem(
                                  value: c,
                                  child:
                                      Text(c, overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: congelado
                              ? null
                              : (v) => setState(() {
                                    _limpiar();
                                    _cliente = v;
                                    _oc = null;
                                  })),
                      const SizedBox(height: 12),
                      WmsScanField(
              permiteManual: false,
              controller: _qr,
                          enabled: !congelado,
                          decoration: const InputDecoration(
                              labelText: 'O escanear QR para seleccionar la OP',
                              prefixIcon: Icon(Icons.qr_code_scanner)),
                          onSubmitted: _escanear,
                          onCameraSubmitted: _leerCamara),
                      if (_cliente == null)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Selecciona un cliente para ver sus órdenes de compra.')),
                      for (final oc in ocs)
                        Card(
                            child: ExpansionTile(
                                key: ValueKey('oc-$_cliente-$oc'),
                                initiallyExpanded: _oc == oc,
                                title:
                                    Text(oc.isEmpty ? 'Sin No. OC' : 'OC: $oc'),
                                subtitle: Text(
                                    '${items.where((i) => i.item.cliente == _cliente && i.item.oc == oc).map((i) => i.item.op).toSet().length} OP asociadas'),
                                onExpansionChanged: congelado
                                    ? null
                                    : (abierta) {
                                        if (abierta && _oc != oc) {
                                          setState(() {
                                            _limpiar();
                                            _oc = oc;
                                          });
                                        }
                                      },
                                children: [
                              for (final op
                                  in (items
                                      .where((i) =>
                                          i.item.cliente == _cliente &&
                                          i.item.oc == oc)
                                      .map((i) => i.item.op)
                                      .toSet()
                                      .toList()
                                    ..sort()))
                                CheckboxListTile(
                                    value: _oc == oc && _ops.contains(op),
                                    title: Text('OP $op'),
                                    onChanged: congelado
                                        ? null
                                        : (v) {
                                            if (_oc != oc) {
                                              setState(() {
                                                _limpiar();
                                                _oc = oc;
                                              });
                                            }
                                            _seleccionar(op, v == true);
                                          })
                            ])),
                      for (final op in _ops)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('OP $op · Cantidades a despachar',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      for (final i in _lineas
                                          .where((i) => i.item.op == op))
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${i.item.descripcion} · ${i.item.codigo} · Talla ${i.item.talla}'),
                                                  Text(
                                                      'Pendiente: ${i.pendienteDespacho} · Stock: ${i.stockDisponible}'),
                                                  TextField(
                                                      controller: _cantidad(i),
                                                      enabled: !congelado,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly
                                                      ],
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Cantidad (0 para omitir)')),
                                                ])),
                                    ]))),
                      if (_oc != null)
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          FilledButton(
                              onPressed: _ocupado ? null : () => _preparar(),
                              child: Text(_ocupado
                                  ? 'Guardando…'
                                  : _pendiente != null
                                      ? 'Reintentar mismo despacho'
                                      : 'Revisar y despachar selección')),
                          OutlinedButton(
                              onPressed: congelado
                                  ? null
                                  : () => _preparar(completa: true),
                              child: const Text(
                                  'Despachar todo lo pendiente de esta OC')),
                        ]),
                      const SizedBox(height: 16),
                    ]),
                    const _Historial(),
                  ])),
                ]))));
  }
}

class _Historial extends ConsumerStatefulWidget {
  const _Historial();
  @override
  ConsumerState<_Historial> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<_Historial> {
  final _oc = TextEditingController();
  @override
  void dispose() {
    _oc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventario = ref.watch(wmsSnapshotProvider);
    return ref.watch(historialDespachosProvider).when(
        loading: () => const Center(child: WmsLoader()),
        error: (e, _) => Center(
            child: Text(
                'No se pudo cargar el historial. Cierra y vuelve a intentarlo.')),
        data: (filas) {
          final grupos = <String, List<Map<String, dynamic>>>{};
          final coincidencias = filas
              .where((f) => '${f['oc']}'
                  .toLowerCase()
                  .contains(_oc.text.trim().toLowerCase()))
              .toList();
          final ordenes = <(String, String)>{
            for (final f in coincidencias) ('${f['cliente']}', '${f['oc']}'),
            for (final i in inventario.value?.kardex ?? <ItemKardex>[])
              if (i.item.oc
                  .toLowerCase()
                  .contains(_oc.text.trim().toLowerCase()))
                (i.item.cliente, i.item.oc),
          };
          for (final f in coincidencias) {
            grupos
                .putIfAbsent(
                    '${f['cliente']}|${f['oc']}|${f['item_id']}', () => [])
                .add(f);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: _oc,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: 'Buscar por OC',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                            tooltip: 'Limpiar OC',
                            onPressed: () => setState(() => _oc.clear()),
                            icon: const Icon(Icons.close)))),
                if (_oc.text.trim().isNotEmpty)
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 110),
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            for (final orden in ordenes)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                      'OC ${orden.$2} · ${orden.$1} · Estado actual: ${inventario.hasError || !inventario.hasValue ? 'No disponible' : estadoDespachoOc(inventario.value!.kardex, orden.$1, orden.$2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                            const Text(
                                'Estado de toda la OC; no cambia al filtrar OP o fechas.',
                                style: TextStyle(fontSize: 12)),
                          ]))),
                Expanded(
                    child: HistorialAgrupado(grupos: [
                  for (final g in grupos.entries)
                    GrupoHistorial(
                        id: g.key,
                        op: '${g.value.first['op']}',
                        titulo:
                            'OP ${g.value.first['op']} · ${g.value.first['producto']} (${g.value.first['talla']})',
                        detalle:
                            'Cliente: ${g.value.first['cliente']} | OC: ${g.value.first['oc']}',
                        eventos: [
                          for (final f in g.value)
                            EventoHistorial(
                                id: '${f['registro']}',
                                fecha: DateTime.tryParse('${f['fecha']}')
                                    ?.toLocal(),
                                cantidad: (f['cantidad'] as num).toInt(),
                                titulo: 'Despacho · ${f['cantidad']} Uds',
                                detalle:
                                    'Por: ${f['persona']} | Estante: ${f['ubicacion']}\n${f['nota']}')
                        ])
                ])),
              ]);
        });
  }
}
