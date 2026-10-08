import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'lista_empaque_dialog.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import '../../../shared/widgets/feedback_banner.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../data/empaques_repository.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../../domain/avance_despacho.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/operario_actual.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key, this.correccion});
  final Map<String, dynamic>? correccion;
  @override
  ConsumerState<DespachoDialog> createState() => _DespachoState();
}

class _EmpaqueAsignado {
  _EmpaqueAsignado(this.empaqueId);
  String empaqueId;
  String prendas = '0';
}

class _DespachoState extends ConsumerState<DespachoDialog> {
  String? _cliente, _oc;
  final _ops = <String>{};
  final _asignaciones = <String, Map<String, _EmpaqueAsignado>>{};
  int _siguienteEmpaque = 0;
  final _qr = TextEditingController();
  bool _ocupado = false;
  bool _preparando = false;
  String? _solicitud;
  set _mensaje(String? texto) {
    if (texto == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarAviso(context, texto, error: true);
    });
  }

  List<Map<String, dynamic>>? _pendiente;
  List<Map<String, dynamic>> _empaquesPendientes = [];

  int _revisionEmpaques = 0;
  final _motivoCorreccion = TextEditingController();
  bool _correccionGuardada = false;
  @override
  void initState() {
    super.initState();
    final d = widget.correccion;
    if (d == null) return;
    _cliente = d['cliente'] as String;
    _oc = d['oc'] as String;
    for (final e in d['empaques'] as List) {
      final numero = (e['numero'] as num).toInt();
      if (numero > _siguienteEmpaque) _siguienteEmpaque = numero;
      _asignaciones.putIfAbsent('${e['item_id']}', () => {})['$numero'] =
          _EmpaqueAsignado('${e['id']}')..prendas = '${e['cantidad']}';
    }
    for (final i in d['detalle'] as List) {
      _ops.add('${i['op']}');
    }
  }

  @override
  void dispose() {
    _motivoCorreccion.dispose();
    _qr.dispose();
    super.dispose();
  }

  void _limpiar() {
    _asignaciones.clear();
    _siguienteEmpaque = 0;
    _revisionEmpaques++;
    _ops.clear();
  }

  int _total(ItemKardex i) => (_asignaciones[i.id] ?? {}).values.fold(
    0,
    (n, v) => n + (int.tryParse(v.prendas) ?? 0),
  );

  Map<String, String> get _bultos => {
    for (final a in _asignaciones.values)
      for (final e in a.entries) e.key: e.value.empaqueId,
  };
  Map<String, int> get _numeros {
    final keys =
        _bultos.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return {for (var i = 0; i < keys.length; i++) keys[i]: i + 1};
  }

  Widget _detalleSeleccion(bool congelado) {
    final colors = Theme.of(context).colorScheme;
    return ref
        .watch(empaquesProvider)
        .when(
          loading: () => const WmsLoadingStrip(),
          error:
              (_, _) => TextButton(
                onPressed:
                    congelado ? null : () => ref.invalidate(empaquesProvider),
                child: const Text(
                  'No se pudieron cargar los empaques. Reintentar',
                ),
              ),
          data:
              (catalogo) => Column(
                children: [
                  if (_ops.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Cada empaque tiene un número. Usa «Nuevo» para otra caja o bolsa, o «Usar empaque» para añadir esta talla a uno existente.',
                      ),
                    ),
                  if (_bultos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final b in _bultos.keys)
                          Chip(
                            label: Text(
                              'Empaque ${_numeros[b]} · ${_asignaciones.values.fold<int>(0, (s, a) => s + (int.tryParse(a[b]?.prendas ?? '0') ?? 0))} prendas',
                            ),
                          ),
                      ],
                    ),
                  for (final op in _ops)
                    Card(
                      color: colors.primary.withValues(alpha: .07),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'OP $op · Distribuir prendas en empaques',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _AvanceOp(
                              avance: AvanceDespacho(
                                _lineas.where((i) => i.item.op == op),
                              ),
                            ),
                            for (final i in _lineas.where(
                              (i) => i.item.op == op,
                            )) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${i.item.descripcion} · ${i.item.codigo} · Talla ${i.item.talla}',
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Pendientes por Producción: ${i.pendienteProduccion}',
                                  ),
                                  Text(
                                    '${widget.correccion == null ? 'En bodega' : 'Disponible para esta corrección'}: ${i.disponibleParaDespacho}',
                                  ),
                                  Text('Despachadas: ${i.despachado}'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'agregar-${i.id}-$_revisionEmpaques',
                                ),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Agregar empaque',
                                  isDense: true,
                                ),
                                items: [
                                  for (final b in _bultos.entries.where(
                                    (b) =>
                                        !(_asignaciones[i.id] ?? {})
                                            .containsKey(b.key),
                                  ))
                                    DropdownMenuItem(
                                      value: 'usar:${b.key}',
                                      child: Text(
                                        'Usar empaque ${_numeros[b.key]} · ${descripcionEmpaque(catalogo.where((e) => e['id'] == b.value).firstOrNull ?? {'nombre': 'No disponible'})}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  for (final e in catalogo)
                                    DropdownMenuItem(
                                      value: 'nuevo:${e['id']}',
                                      child: Text(
                                        'Nuevo · ${descripcionEmpaque(e)}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged:
                                    congelado
                                        ? null
                                        : (id) {
                                          if (id != null) {
                                            setState(() {
                                              final existente = id.startsWith(
                                                'usar:',
                                              );
                                              final key =
                                                  existente
                                                      ? id.substring(5)
                                                      : (_siguienteEmpaque++)
                                                          .toString();
                                              final tipo =
                                                  existente
                                                      ? _bultos[key]!
                                                      : id.substring(6);
                                              _asignaciones.putIfAbsent(
                                                i.id,
                                                () => {},
                                              )[key] = _EmpaqueAsignado(tipo);
                                              _revisionEmpaques++;
                                            });
                                          }
                                        },
                              ),
                              if (catalogo.isEmpty)
                                const Text(
                                  'No hay empaques activos. Créalos en Administración → Empaques.',
                                ),
                              for (final entry
                                  in (_asignaciones[i.id] ?? {}).entries)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          key: ValueKey(
                                            'tipo-${i.id}-${entry.key}-${entry.value.empaqueId}',
                                          ),
                                          initialValue:
                                              catalogo.any(
                                                    (e) =>
                                                        e['id'] ==
                                                        entry.value.empaqueId,
                                                  )
                                                  ? entry.value.empaqueId
                                                  : null,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Tipo de empaque ${_numeros[entry.key]}',
                                          ),
                                          items: [
                                            for (final e in catalogo)
                                              DropdownMenuItem(
                                                value: '${e['id']}',
                                                child: Text(
                                                  descripcionEmpaque(e),
                                                ),
                                              ),
                                          ],
                                          onChanged:
                                              congelado
                                                  ? null
                                                  : (tipo) {
                                                    if (tipo == null) return;
                                                    setState(() {
                                                      // Un mismo bulto compartido entre tallas conserva un solo tipo.
                                                      for (final a
                                                          in _asignaciones
                                                              .values) {
                                                        if (a[entry.key] !=
                                                            null) {
                                                          a[entry.key]!
                                                              .empaqueId = tipo;
                                                        }
                                                      }
                                                    });
                                                  },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 125,
                                        child: TextFormField(
                                          key: ValueKey(
                                            'prendas-${i.id}-${entry.key}',
                                          ),
                                          initialValue: entry.value.prendas,
                                          enabled: !congelado,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'Prendas',
                                            isDense: true,
                                          ),
                                          onChanged:
                                              (v) => setState(
                                                () => entry.value.prendas = v,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Quitar empaque',
                                        onPressed:
                                            congelado
                                                ? null
                                                : () => setState(() {
                                                  _asignaciones[i.id]!.remove(
                                                    entry.key,
                                                  );
                                                  _revisionEmpaques++;
                                                }),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'A reservar: ${_total(i)} prendas · Disponibles sin reservar: ${i.disponibleParaDespacho - _total(i)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Pendiente de la OP: ${i.pendienteDisponibleDespacho} prendas · '
                                'Por asignar para completar la OP: ${i.pendienteDisponibleDespacho - _total(i) < 0 ? 0 : i.pendienteDisponibleDespacho - _total(i)}',
                              ),
                              if (_total(i) > i.disponibleParaDespacho &&
                                  _total(i) > 0)
                                Text(
                                  'Solo hay ${i.disponibleParaDespacho < 0 ? 0 : i.disponibleParaDespacho} en bodega. Reduce las prendas asignadas.',
                                  style: TextStyle(color: colors.error),
                                ),
                              if (_total(i) > i.pendienteDisponibleDespacho)
                                Text(
                                  'La OP pide ${i.cantidadPedida} y ya se despacharon ${i.despachado}. Quedan ${i.pendienteDisponibleDespacho} por despachar; asignaste ${_total(i)} en los empaques.',
                                  style: TextStyle(color: colors.error),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
        );
  }

  List<ItemKardex> get _items =>
      (ref.read(wmsSnapshotProvider).value?.kardex ?? [])
          .where((i) => !i.eliminada)
          .map((i) {
            final d = widget.correccion;
            if (d == null || _correccionGuardada) return i;
            final retiros = (d['detalle'] as List).where(
              (e) => e['item_id'] == i.id,
            );
            final ubicaciones = {...i.ubicaciones};
            final reservas = {...i.reservas};
            final empacado = d['fase'] == 'empacado';
            var cantidad = 0;
            for (final e in retiros) {
              final n = (e['cantidad'] as num).toInt();
              cantidad += n;
              final u = '${e['ubicacion']}';
              if (empacado) {
                reservas[u] = (reservas[u] ?? 0) - n;
              } else {
                ubicaciones[u] = (ubicaciones[u] ?? 0) + n;
              }
            }
            return ItemKardex(
              item: i.item,
              producido: i.producido,
              recibido: i.recibido,
              despachado: i.despachado - (empacado ? 0 : cantidad),
              ubicaciones: ubicaciones,
              reservas: reservas,
            );
          })
          .toList();
  List<ItemKardex> get _lineas =>
      _items
          .where((i) => i.item.cliente == _cliente && i.item.oc == _oc)
          .toList();
  void _seleccionar(String op, bool seleccionar) {
    setState(() {
      if (seleccionar) {
        _ops.add(op);
      } else {
        _ops.remove(op);
        for (final i in _lineas.where((i) => i.item.op == op)) {
          _asignaciones.remove(i.id);
        }
      }
    });
  }

  void _escanear(String texto) {
    final q = QrPrenda.tryParse(texto);
    _qr.clear();
    final item =
        q == null
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
    final item =
        qr == null
            ? null
            : _items
                .where((i) => i.item.op == qr.op && i.item.codigo == qr.codigo)
                .firstOrNull;
    if (item == null) return const FeedbackMessage.error('QR no encontrado.');
    // La cámara no debe borrar una selección previa al encontrar otra OC.
    if (_ops.isNotEmpty &&
        (_cliente != item.item.cliente || _oc != item.item.oc)) {
      return const FeedbackMessage.error(
        'La etiqueta pertenece a otra OC. Termina la selección actual antes de cambiar de orden.',
      );
    }
    _escanear(raw);
    return FeedbackMessage.ok(
      'OP ${item.item.op} · Agregada a la selección de despacho. Define las cantidades al volver.',
    );
  }

  Future<void> _preparar({bool completa = false}) async {
    if (_ocupado || _preparando) return;
    if (_pendiente != null) {
      await _guardar();
      return;
    }
    setState(() => _preparando = true);
    try {
      final catalogo = ref.read(empaquesProvider).value;
      if (catalogo == null) {
        throw const FormatException(
          'Espera a que cargue el catálogo de empaques.',
        );
      }
      final empaques = <Map<String, dynamic>>[];
      final cantidades = <String, int>{};
      for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
        for (final entry in (_asignaciones[i.id] ?? {}).entries) {
          final n = int.tryParse(entry.value.prendas);
          if (n == null || n <= 0 || n > 999999) {
            throw const FormatException(
              'Indica entre 1 y 999999 prendas por empaque, o quita la fila.',
            );
          }
          final e =
              catalogo
                  .where((e) => e['id'] == entry.value.empaqueId)
                  .firstOrNull;
          if (e == null) {
            throw const FormatException(
              'Un empaque ya no está disponible. Actualiza el catálogo.',
            );
          }
          empaques.add({
            'item_id': i.id,
            'numero': _numeros[entry.key],
            'empaque_id': entry.value.empaqueId,
            'cantidad': n,
            'version': e['version'],
          });
          cantidades[i.id] = (cantidades[i.id] ?? 0) + n;
        }
      }
      if (completa &&
          _lineas.any(
            (i) =>
                i.pendienteDisponibleDespacho > 0 &&
                cantidades[i.id] != i.pendienteDisponibleDespacho,
          )) {
        throw const FormatException(
          'Para completar la OC, distribuye todas las prendas pendientes de cada OP en sus empaques.',
        );
      }
      final plan = planificarDespacho(_lineas, cantidades);
      final total = plan.fold<int>(0, (n, l) => n + (l['cantidad'] as int));
      final confirmar = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(
                completa
                    ? 'Completar toda la OC'
                    : 'Confirmar empaque seleccionado',
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente: $_cliente\nOC: ${_oc!.isEmpty ? 'Sin OC' : _oc}\nTotal: $total Uds',
                      ),
                      const Divider(),
                      const Text(
                        'Prendas distribuidas por OP y empaque',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final e in empaques)
                        Text(
                          'Empaque ${e['numero']} · OP ${_lineas.firstWhere((i) => i.id == e['item_id']).item.op} · Talla ${_lineas.firstWhere((i) => i.id == e['item_id']).item.talla}: ${e['cantidad']} prendas en ${descripcionEmpaque(catalogo.firstWhere((c) => c['id'] == e['empaque_id']))}',
                        ),
                      const Text(
                        'Los pesos del catálogo son aproximados; no son un pesaje del envío.',
                      ),
                      if (widget.correccion != null) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _motivoCorreccion,
                          decoration: const InputDecoration(
                            labelText: 'Motivo de la corrección (obligatorio)',
                            helperText:
                                'Puedes cambiar cantidades, distribución, tipo de empaque o destinatario.',
                          ),
                        ),
                      ],
                      const Divider(),
                      for (final l in plan)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'OP ${l['op']} · ${l['codigo']} (${l['talla']}) · ${l['cantidad']} Uds desde ${l['ubicacion']}',
                          ),
                        ),
                      const Text(
                        'Estas prendas quedarán reservadas. La salida se confirma en Seguimiento.',
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
                  onPressed: () {
                    if (widget.correccion != null &&
                        _motivoCorreccion.text.trim().isEmpty) {
                      mostrarAviso(
                        ctx,
                        'Indica el motivo de la corrección para guardar los cambios.',
                        error: true,
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Confirmar empaque'),
                ),
              ],
            ),
      );
      if (confirmar != true || !mounted) return;
      // Volver a comprobar los saldos si cambiaron mientras se revisaba.
      final actualizado = planificarDespacho(_lineas, cantidades);
      if (actualizado.toString() != plan.toString()) {
        throw const FormatException(
          'Cambió la disponibilidad en los estantes. Revisa el despacho nuevamente.',
        );
      }
      _pendiente = plan;
      _empaquesPendientes = empaques;
      _solicitud = nuevaSolicitudDespacho();
      await _guardar();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _mensaje =
                  e is FormatException
                      ? e.message
                      : 'No se pudo preparar el despacho: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _preparando = false);
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
      if (widget.correccion != null) {
        await repo.corregir(
          '${widget.correccion!['id']}',
          '${widget.correccion!['version']}',
          _solicitud!,
          _motivoCorreccion.text.trim(),
          _cliente!,
          _oc!,
          _pendiente!,
          _empaquesPendientes,
        );

        _correccionGuardada = true;
      } else {
        await repo.confirmar(
          _solicitud!,
          _cliente!,
          _oc!,
          _pendiente!,
          empaques: _empaquesPendientes,
        );
      }
      _pendiente = null;
      _solicitud = null;
      ref.invalidate(historialDespachosProvider);
      var mensaje =
          'Empaque confirmado. La LE está lista en Seguimiento; las prendas quedaron reservadas.';
      try {
        await ref.read(wmsRepositoryProvider).refrescar();
      } catch (_) {
        mensaje = 'Empaque confirmado. Actualiza para ver las reservas.';
      }
      if (mounted) {
        setState(() {
          _limpiar();
        });
        await mostrarAviso(context, mensaje);
      }
    } on PostgrestException catch (e) {
      _pendiente = null;
      _solicitud = null;
      if (mounted) setState(() => _mensaje = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _mensaje =
                  'No se pudo confirmar la respuesta. Reintenta este mismo despacho; su identificador evita duplicarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (mounted && _correccionGuardada) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(wmsSnapshotProvider);
    final items = _items;
    final clientes =
        items
            .where(
              (i) =>
                  i.disponibleParaDespacho > 0 &&
                  i.pendienteDisponibleDespacho > 0,
            )
            .map((i) => i.item.cliente)
            .toSet()
            .toList()
          ..sort();
    final clienteDisponible = clientes.contains(_cliente) ? _cliente : null;
    final ocs =
        items
            .where((i) => i.item.cliente == _cliente)
            .map((i) => i.item.oc)
            .toSet()
            .toList()
          ..sort();
    final congelado = _ocupado || _preparando || _pendiente != null;
    return PopScope(
      canPop: !congelado,
      child: WmsDialogShell(
        canClose: !congelado,
        title:
            widget.correccion == null
                ? 'Despachos por orden de compra'
                : 'Corregir despacho · LE N° ${widget.correccion!['le_numero'] ?? 'sin emitir'}',
        icon: Icons.local_shipping,
        iconColor: Colors.orange,
        expand: true,
        maxWidth: 1100,
        child: DefaultTabController(
          length: 3,
          initialIndex:
              widget.correccion == null &&
                      ref.watch(usarSupabaseProvider) &&
                      ref.watch(usuarioSesionProvider).valueOrNull?.rolCuenta ==
                          RolCuenta.seguimiento
                  ? 1
                  : 0,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'DESPACHO'),
                  Tab(text: 'SEGUIMIENTO'),
                  Tab(text: 'HISTORIAL'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        const SizedBox(height: 12),
                        const OperarioActual(label: 'Empacado por'),
                        if (widget.correccion != null) ...[
                          Text(
                            'Correcciones realizadas: ${widget.correccion!['ediciones'] ?? 0}. Las prendas y el inventario se ajustarán al confirmar. Si cierras, se conserva el despacho anterior.',
                          ),
                        ],
                        if (ref.watch(usarSupabaseProvider))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed:
                                  congelado
                                      ? null
                                      : () => mostrarListaEmpaque(context, ''),
                              icon: const Icon(Icons.contact_mail_outlined),
                              label: const Text(
                                'Catálogo de destinatarios / consecutivo LE',
                              ),
                            ),
                          ),
                        if (estado.isLoading) const WmsLoadingStrip(),
                        if (estado.hasError)
                          const Text(
                            'No se pudo cargar el inventario. Cierra y vuelve a abrir.',
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(clienteDisponible),
                          initialValue: clienteDisponible,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                          ),
                          hint: Text(
                            clientes.isEmpty
                                ? 'No hay clientes con prendas disponibles para despachar'
                                : 'Selecciona un cliente',
                          ),
                          items: [
                            for (final c in clientes)
                              DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged:
                              congelado
                                  ? null
                                  : (v) => setState(() {
                                    _limpiar();
                                    _cliente = v;
                                    _oc = null;
                                  }),
                        ),
                        const SizedBox(height: 12),
                        WmsScanField(
                          permiteManual: false,
                          controller: _qr,
                          enabled: !congelado,
                          decoration: const InputDecoration(
                            labelText: 'O escanear QR para seleccionar la OP',
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          onSubmitted: _escanear,
                          onCameraSubmitted: _leerCamara,
                        ),
                        if (_cliente == null)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Selecciona un cliente para ver sus órdenes de compra.',
                            ),
                          ),
                        for (final oc in ocs)
                          Card(
                            child: ExpansionTile(
                              key: ValueKey('oc-$_cliente-$oc'),
                              initiallyExpanded: _oc == oc,
                              title: _AvanceOc(
                                oc: oc,
                                avance: AvanceDespacho(
                                  items.where(
                                    (i) =>
                                        i.item.cliente == _cliente &&
                                        i.item.oc == oc,
                                  ),
                                ),
                              ),
                              onExpansionChanged:
                                  congelado
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
                                        .where(
                                          (i) =>
                                              i.item.cliente == _cliente &&
                                              i.item.oc == oc,
                                        )
                                        .map((i) => i.item.op)
                                        .toSet()
                                        .toList()
                                      ..sort()))
                                  CheckboxListTile(
                                    value: _oc == oc && _ops.contains(op),
                                    title: Text('OP $op'),
                                    subtitle: _AvanceOp(
                                      avance: AvanceDespacho(
                                        items.where(
                                          (i) =>
                                              i.item.cliente == _cliente &&
                                              i.item.oc == oc &&
                                              i.item.op == op,
                                        ),
                                      ),
                                    ),
                                    onChanged:
                                        congelado
                                            ? null
                                            : (v) {
                                              if (_oc != oc) {
                                                setState(() {
                                                  _limpiar();
                                                  _oc = oc;
                                                });
                                              }
                                              _seleccionar(op, v == true);
                                            },
                                  ),
                              ],
                            ),
                          ),
                        if (_oc != null) _detalleSeleccion(congelado),
                        if (_oc != null)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: _ocupado ? null : () => _preparar(),
                                child: Text(
                                  _ocupado
                                      ? 'Guardando…'
                                      : _pendiente != null
                                      ? 'Reintentar mismo despacho'
                                      : 'Revisar y confirmar empaque',
                                ),
                              ),
                              OutlinedButton(
                                onPressed:
                                    congelado
                                        ? null
                                        : () => _preparar(completa: true),
                                child: const Text('Empacar toda la OC'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    const _Historial(seguimiento: true),
                    const _Historial(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _porcentaje(double fraccion) =>
    '${(fraccion * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

String _detalleEmpaques(dynamic valor) {
  if (valor is! List || valor.isEmpty) {
    return 'Empaques: sin registro histórico.';
  }
  if (valor.any((e) => e['contenido'] == 'prendas')) {
    return 'Distribución del despacho (no sumar por estante):\n${valor.map((e) => '${e['numero'] == null ? '' : 'Empaque ${e['numero']} · '}OP ${e['op']} · Talla ${e['talla']} · ${e['cantidad']} prendas en ${descripcionEmpaque(Map<String, dynamic>.from(e as Map))}').join('\n')}';
  }
  return 'Empaques de todo el despacho (no sumar por cada prenda):\n${valor.map((e) => '${e['cantidad']} × ${descripcionEmpaque(Map<String, dynamic>.from(e as Map))} · Tara: ${e['peso_neto_kg']} kg · Bruto aprox.: ${e['peso_bruto_kg']} kg').join('\n')}';
}

class _AvanceOc extends StatelessWidget {
  const _AvanceOc({required this.oc, required this.avance});
  final String oc;
  final AvanceDespacho avance;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(oc.isEmpty ? 'Sin No. OC' : 'OC: $oc'),
          Text(
            _porcentaje(avance.fraccionOps),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      Text(
        'Avance promedio por OP · ${avance.opsCompletas} de ${avance.ops.length} OP completamente despachadas',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _AvanceOp extends StatelessWidget {
  const _AvanceOp({required this.avance});
  final AvanceDespacho avance;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_porcentaje(avance.fraccionUnidades)} despachado · '
          '${avance.despachadas} de ${avance.pedidas} unidades',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: avance.fraccionUnidades,
          minHeight: 4,
          semanticsLabel: 'Avance de despacho de la OP',
        ),
      ],
    ),
  );
}

class _Historial extends ConsumerStatefulWidget {
  const _Historial({this.seguimiento = false});
  final bool seguimiento;
  @override
  ConsumerState<_Historial> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<_Historial> {
  final _oc = TextEditingController();
  final _le = TextEditingController();
  bool _abriendoCorreccion = false;
  Future<void> _corregir(String id) async {
    if (_abriendoCorreccion) return;
    setState(() => _abriendoCorreccion = true);
    try {
      final d = await ref.read(despachosOcProvider)!.prepararCorreccion(id);
      await ref.read(wmsRepositoryProvider).refrescar();
      if (!mounted) return;
      await showWmsDialog<void>(context, (_) => DespachoDialog(correccion: d));
      ref.invalidate(historialDespachosProvider);
    } catch (e) {
      if (mounted) {
        mostrarAvisoSnack(
          context,
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'No se pudo abrir la corrección. $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoCorreccion = false);
    }
  }

  @override
  void dispose() {
    _oc.dispose();
    _le.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventario = ref.watch(wmsSnapshotProvider);
    return ref
        .watch(historialDespachosProvider)
        .when(
          loading: () => const Center(child: WmsLoader()),
          error:
              (e, _) => Center(
                child: Text(
                  'No se pudo cargar el historial. Cierra y vuelve a intentarlo.',
                ),
              ),
          data: (todas) {
            final filas =
                todas
                    .where(
                      (f) => (f['fase'] == 'empacado') == widget.seguimiento,
                    )
                    .toList();
            final grupos = <String, List<Map<String, dynamic>>>{};
            final coincidencias =
                filas
                    .where(
                      (f) =>
                          '${f['le_numero'] ?? ''}'.contains(_le.text.trim()) &&
                          '${f['oc']}'.toLowerCase().contains(
                            _oc.text.trim().toLowerCase(),
                          ),
                    )
                    .toList();
            final ordenes = <(String, String)>{
              for (final f in coincidencias) ('${f['cliente']}', '${f['oc']}'),
              for (final i in inventario.value?.kardex ?? <ItemKardex>[])
                if (i.item.oc.toLowerCase().contains(
                  _oc.text.trim().toLowerCase(),
                ))
                  (i.item.cliente, i.item.oc),
            };
            for (final f in coincidencias) {
              grupos
                  .putIfAbsent(
                    '${f['despacho_oc_id'] ?? f['registro']}',
                    () => [],
                  )
                  .add(f);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _le,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar por LE N°',
                    prefixIcon: const Icon(Icons.receipt_long),
                    suffixIcon: IconButton(
                      tooltip: 'Limpiar LE',
                      onPressed: () => setState(() => _le.clear()),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                TextField(
                  controller: _oc,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar por OC',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Limpiar OC',
                      onPressed: () => setState(() => _oc.clear()),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                if (_oc.text.trim().isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 110),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final orden in ordenes)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'OC ${orden.$2} · ${orden.$1} · Estado actual: ${inventario.hasError || !inventario.hasValue ? 'No disponible' : estadoDespachoOc(inventario.value!.kardex, orden.$1, orden.$2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Text(
                            'Estado de toda la OC; no cambia al filtrar OP o fechas.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: HistorialAgrupado(
                    etiquetaTotal:
                        widget.seguimiento
                            ? 'Prendas empacadas'
                            : 'Prendas despachadas',
                    grupos: [
                      for (final g in grupos.entries)
                        GrupoHistorial(
                          id: g.key,
                          op: g.value
                              .map((f) => '${f['op']}')
                              .toSet()
                              .join(' '),
                          titulo:
                              g.value.first['le_numero'] != null
                                  ? 'LE N° ${g.value.first['le_numero']}'
                                  : g.value.first['despacho_oc_id'] != null
                                  ? 'Despacho sin LE emitida'
                                  : 'OP ${g.value.first['op']} · ${g.value.first['producto']} (${g.value.first['talla']})',
                          detalle:
                              'Cliente: ${g.value.first['cliente']} | OC: ${g.value.first['oc']} | Correcciones: ${g.value.first['ediciones'] ?? 0}',
                          eventos: [
                            for (final f in g.value)
                              EventoHistorial(
                                id: '${f['registro']}',
                                accion:
                                    f['despacho_oc_id'] == null ||
                                            !ref.watch(usarSupabaseProvider)
                                        ? null
                                        : Wrap(
                                          children: [
                                            TextButton.icon(
                                              onPressed:
                                                  () => mostrarListaEmpaque(
                                                    context,
                                                    '${f['despacho_oc_id']}',
                                                  ),
                                              icon: const Icon(
                                                Icons.picture_as_pdf,
                                              ),
                                              label: Text(
                                                widget.seguimiento
                                                    ? 'Asignar destinatario y confirmar salida'
                                                    : 'Lista de empaque PDF',
                                              ),
                                            ),
                                            if (identical(f, g.value.first))
                                              TextButton.icon(
                                                onPressed:
                                                    _abriendoCorreccion
                                                        ? null
                                                        : () => _corregir(
                                                          '${f['despacho_oc_id']}',
                                                        ),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                label: const Text(
                                                  'Corregir despacho',
                                                ),
                                              ),
                                          ],
                                        ),
                                fecha:
                                    DateTime.tryParse(
                                      '${f['fecha']}',
                                    )?.toLocal(),
                                cantidad: (f['cantidad'] as num).toInt(),
                                titulo:
                                    'OP ${f['op']} · ${f['producto']} (${f['talla']}) · ${f['cantidad']} Uds',
                                detalle:
                                    'Por: ${f['persona']} | Estante: ${f['ubicacion']}\n${f['nota']}\n${_detalleEmpaques(f['empaques'])}',
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
  }
}
