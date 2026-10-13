import '../../../domain/destinatario_internacional.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'historial_despachos_vista.dart';
import '../../../data/seguimiento_entregas.dart';
import 'seguimiento_entregas_tabla.dart';
import 'dart:convert';
import 'dart:math' show max, min;
import '../../../data/destinatarios_empaque.dart';
import '../../../data/rotulo_empaque_pdf.dart';
import '../../../domain/rotulo_empaque.dart';
import '../../../shared/descargar_pdf.dart';
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
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
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
  bool get _puedeSeguimiento =>
      !ref.read(usarSupabaseProvider) ||
      const {
        RolCuenta.admin,
        RolCuenta.seguimiento,
      }.contains(ref.read(usuarioSesionProvider).valueOrNull?.rolCuenta);
  int _paso = 0;
  bool _exito = false;
  bool _pantallaCompleta = false;
  final _buscarOpEmpaque = TextEditingController();
  bool _coincideOp(ItemKardex i) => i.item.op.toLowerCase().contains(
    _buscarOpEmpaque.text.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase(),
  );
  int _confirmadas = 0, _bultosConfirmados = 0;
  List<Map<String, dynamic>>? _planRevisado;
  String? _cliente, _oc, _destinatarioId;
  final _ocDocumento = TextEditingController();
  String get _ocVisible =>
      _ocDocumento.text.trim().isEmpty ? (_oc ?? '') : _ocDocumento.text.trim();
  final _pesosBrutos = <String, String>{};
  final _rotulosGenerados = <String, String>{};
  bool _generandoRotulo = false;
  String _buscarDestino = '';
  Map<String, dynamic>? get _destino =>
      ref
          .read(destinatariosEmpaqueProvider)
          .valueOrNull
          ?.where((d) => d['id'] == _destinatarioId)
          .firstOrNull;
  bool get _faltaDestino => ref.read(usarSupabaseProvider) && _destino == null;

  RotuloEmpaque _rotulo(String pieza) {
    if (_destino == null) {
      throw const FormatException(
        'Selecciona el destinatario antes de empacar.',
      );
    }
    final productos = <String, ProductoRotulo>{};
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      final a = _asignaciones[i.id]?[pieza];
      if (a == null) continue;
      final n = int.tryParse(a.prendas);
      if (n == null || n < 1 || n > 999999) {
        throw const FormatException(
          'Completa las cantidades de esta pieza antes de generar su rótulo.',
        );
      }
      final key = jsonEncode([i.item.op, i.item.descripcion, i.item.talla]);
      productos[key] = ProductoRotulo(
        i.item.descripcion,
        i.item.talla,
        (productos[key]?.cantidad ?? 0) + n,
        op: i.item.op,
      );
    }
    // También cuenta las prendas ya distribuidas en las otras piezas.
    final totales = <String, int>{};
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      for (final a in (_asignaciones[i.id] ?? {}).values) {
        final n = int.tryParse(a.prendas) ?? 0;
        if (n > 0) totales[i.id] = (totales[i.id] ?? 0) + n;
      }
    }
    planificarDespacho(_lineas, totales);
    final empaque =
        (ref.read(empaquesProvider).value ?? [])
            .where((e) => e['id'] == _bultos[pieza])
            .firstOrNull;
    if (empaque == null) {
      throw const FormatException('Actualiza el catálogo de empaques.');
    }
    return RotuloEmpaque(
      tipoEmpaque: empaque['categoria'] == 'CAJA' ? 'Caja' : 'Paquete',
      pesoBrutoKg: _pesoBruto(pieza, empaque),
      numero: _numeros[pieza]!,
      destinatario: Map<String, dynamic>.from(_destino!['datos'] as Map),
      oc: _ocVisible,
      empacadoPor:
          ref.read(usarSupabaseProvider)
              ? (ref.read(usuarioSesionProvider).valueOrNull?.nombre ?? '')
              : 'Operario de prueba',
      productos: productos.values.toList(),
    );
  }

  bool _rotuloPendiente(String pieza) {
    if (!_rotulosGenerados.containsKey(pieza)) return false;
    try {
      return _rotulosGenerados[pieza] !=
          '${_bultos[pieza]}:${_rotulo(pieza).firma}';
    } catch (_) {
      return true;
    }
  }

  Future<void> _generarRotulo(String pieza) async {
    if (_generandoRotulo) return;
    setState(() => _generandoRotulo = true);
    try {
      final rotulo = _rotulo(pieza);
      final bytes = await crearRotuloEmpaquePdf(
        rotulo,
        logo:
            (await rootBundle.load(
              'assets/images/logo_quiromar_vector_bn.svg',
            )).buffer.asUint8List(),
        fuenteRegular: await rootBundle.load(
          'assets/fonts/LiberationSans-Regular.ttf',
        ),
        fuenteNegrita: await rootBundle.load(
          'assets/fonts/LiberationSans-Bold.ttf',
        ),
      );
      await descargarPdf(bytes, 'Rotulo_pieza_${rotulo.numero}.pdf');
      if (mounted) {
        setState(
          () => _rotulosGenerados[pieza] = '${_bultos[pieza]}:${rotulo.firma}',
        );
      }
    } catch (e) {
      if (mounted) {
        await mostrarAviso(
          context,
          e is FormatException
              ? e.message.toString()
              : 'No se pudo generar el rótulo: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoRotulo = false);
    }
  }

  Widget _selectorDestino(bool congelado) => ref
      .watch(destinatariosEmpaqueProvider)
      .when(
        loading: () => const WmsLoadingStrip(),
        error:
            (_, __) => TextButton(
              onPressed: () => ref.invalidate(destinatariosEmpaqueProvider),
              child: const Text(
                'No se pudieron cargar los destinatarios. Reintentar',
              ),
            ),
        data: (datos) {
          final opciones = [
            ...datos.where((d) => d['id'] == _destinatarioId),
            ...datos
                .where(
                  (d) =>
                      d['id'] != _destinatarioId &&
                      '${d['datos']}'.toLowerCase().contains(
                        _buscarDestino.toLowerCase(),
                      ),
                )
                .take(99),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Destino del empaque',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                enabled: !congelado,
                decoration: const InputDecoration(
                  labelText: 'Buscar destinatario o sede',
                ),
                onChanged: (v) => setState(() => _buscarDestino = v),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('destino-$_destinatarioId'),
                initialValue:
                    datos.any((d) => d['id'] == _destinatarioId)
                        ? _destinatarioId
                        : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Destinatario / sede (obligatorio)',
                ),
                items: [
                  for (final d in opciones)
                    DropdownMenuItem(
                      value: '${d['id']}',
                      child: Text(
                        '${d['datos']['nombre']} · ${d['datos']['sede'] ?? ''} · ${d['datos']['ciudad'] ?? ''}${esDestinatarioInternacional(d['datos'] as Map) ? ' · Internacional · ${d['datos']['pais_destino']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    congelado
                        ? null
                        : (v) => setState(() => _destinatarioId = v),
              ),
              if (_destino != null) ...[
                const SizedBox(height: 12),
                _panel(
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: _green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreDestino,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_destino!['datos']['direccion'] ?? ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextButton.icon(
                onPressed:
                    congelado
                        ? null
                        : () => ref.invalidate(destinatariosEmpaqueProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar destinatarios'),
              ),
              if (datos.isEmpty)
                const Text(
                  'Administración debe registrar un destinatario antes de empacar.',
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      );
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
    _paso = 2;
    _destinatarioId = d['destinatario_id'] as String?;
    _cliente = d['cliente'] as String;
    _oc = d['oc'] as String;
    _ocDocumento.text = d['oc_documento'] as String? ?? '';
    for (final e in d['empaques'] as List) {
      final numero = (e['numero'] as num).toInt();
      if (e['peso_tara_kg'] != null && e['peso_bruto_kg'] != null) {
        _pesosBrutos['$numero'] = '${e['peso_bruto_kg']}';
      }
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
    _buscarOpEmpaque.dispose();
    _ocDocumento.dispose();
    _motivoCorreccion.dispose();
    _qr.dispose();
    super.dispose();
  }

  void _limpiar() {
    _pesosBrutos.clear();
    _opAbierta.clear();
    _buscarOpEmpaque.clear();
    _ocDocumento.clear();
    _rotulosGenerados.clear();
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

  final _opAbierta = <String, bool>{};
  bool _abierta(ItemKardex i) =>
      _opAbierta[i.id] ?? i.disponibleParaDespacho > 0;

  int _prendasBulto(String key) => _asignaciones.values.fold(
    0,
    (n, a) => n + (int.tryParse(a[key]?.prendas ?? '0') ?? 0),
  );

  String? get _pendienteEmpaque {
    if (_bultos.isEmpty) return 'Agrega al menos un empaque para continuar.';
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      if (_total(i) >
          min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho)) {
        return 'OP ${i.item.op}: revisa la cantidad disponible.';
      }
    }
    final catalogo = ref.read(empaquesProvider).value ?? [];
    for (final b in _bultos.entries) {
      if (_prendasBulto(b.key) <= 0) {
        return 'Agrega prendas al empaque ${_numeros[b.key]} o quítalo.';
      }
      final e = catalogo.where((e) => e['id'] == b.value).firstOrNull;
      if (e == null) return 'Actualiza el tipo del empaque ${_numeros[b.key]}.';
      try {
        _pesoBruto(b.key, e);
      } catch (_) {
        return 'Indica un peso bruto válido para el empaque ${_numeros[b.key]}.';
      }
    }
    return null;
  }

  void _agregarRapido(ItemKardex i, Map<String, dynamic> e) {
    setState(() {
      final key = '${_siguienteEmpaque++}';
      _asignaciones.putIfAbsent(i.id, () => {})[key] = _EmpaqueAsignado(
        '${e['id']}',
      );
      _revisionEmpaques++;
    });
  }

  Widget _indicadoresEmpaque(ItemKardex i) {
    final total = _total(i);
    final disponible = i.disponibleParaDespacho;
    final progreso =
        disponible <= 0 ? 0.0 : (total / disponible).clamp(0.0, 1.0);
    Widget dato(
      String titulo,
      String valor,
      Color fondo, {
      bool barra = false,
    }) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 10, color: Color(0xff648090)),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (barra) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progreso,
              color: total > disponible ? Colors.red : _green,
              backgroundColor: const Color(0xffe3ecef),
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final ancho =
            c.maxWidth >= 600 ? (c.maxWidth - 24) / 4 : (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: ancho,
              child: dato(
                '$total de $disponible prendas en empaques',
                '${(progreso * 100).round()} %',
                _soft,
                barra: true,
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Disponibles',
                'Quedan ${disponible - total} en bodega',
                const Color(0xffe6f4ee),
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Pendientes de recibir en Bodega: ${max(0, i.producido - i.recibido)}',
                '${max(0, i.producido - i.recibido)}',
                _soft,
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Pendientes de Producción: ${i.pendienteProduccion}',
                '${i.pendienteProduccion}',
                const Color(0xfffff3db),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detalleSeleccion(bool congelado) => ref
      .watch(empaquesProvider)
      .when(
        loading: () => const WmsLoadingStrip(),
        error:
            (_, __) => TextButton(
              onPressed: () => ref.invalidate(empaquesProvider),
              child: const Text('Reintentar catálogo de empaques'),
            ),
        data:
            (catalogo) => LayoutBuilder(
              builder: (context, constraints) {
                final tarjetas = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_lineas.any(
                      (i) => _ops.contains(i.item.op) && _coincideOp(i),
                    ))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No hay OP que coincidan con la búsqueda.'),
                      ),
                    for (final i in _lineas.where(
                      (i) => _ops.contains(i.item.op) && _coincideOp(i),
                    ))
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap:
                                  () => setState(
                                    () => _opAbierta[i.id] = !_abierta(i),
                                  ),
                              trailing: Icon(
                                _abierta(i)
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              title: Text(
                                'OP ${i.item.op} · ${i.item.descripcion} · Talla ${i.item.talla}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                i.disponibleParaDespacho <= 0
                                    ? 'Sin prendas en bodega · ${max(0, i.producido - i.recibido)} por recibir · ${i.pendienteProduccion} en producción'
                                    : '${_total(i)} de ${i.disponibleParaDespacho} en empaques · ${i.ubicaciones.keys.join(', ')}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            if (_abierta(i))
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _indicadoresEmpaque(i),
                                  const SizedBox(height: 14),
                                  if ((_asignaciones[i.id]?.isEmpty ?? true))
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        'Aún no hay empaques para esta OP. Elige el tipo para empezar.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  for (final entry
                                      in (_asignaciones[i.id] ?? {}).entries)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, c) {
                                          final tipo = DropdownButtonFormField<
                                            String
                                          >(
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
                                                  'Empaque ${_numeros[entry.key]}',
                                              isDense: true,
                                            ),
                                            items: [
                                              for (final e in catalogo)
                                                DropdownMenuItem(
                                                  value: '${e['id']}',
                                                  child: Text(
                                                    descripcionEmpaque(e),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                            onChanged:
                                                congelado
                                                    ? null
                                                    : (tipo) {
                                                      if (tipo != null) {
                                                        setState(() {
                                                          for (final a
                                                              in _asignaciones
                                                                  .values) {
                                                            if (a[entry.key] !=
                                                                null) {
                                                              a[entry.key]!
                                                                      .empaqueId =
                                                                  tipo;
                                                            }
                                                          }
                                                        });
                                                      }
                                                    },
                                          );
                                          final cantidad = Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Restar prenda',
                                                onPressed:
                                                    congelado
                                                        ? null
                                                        : () => setState(() {
                                                          final n =
                                                              int.tryParse(
                                                                entry
                                                                    .value
                                                                    .prendas,
                                                              ) ??
                                                              0;
                                                          entry.value.prendas =
                                                              '${n > 0 ? n - 1 : 0}';
                                                          _revisionEmpaques++;
                                                        }),
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 62,
                                                child: TextFormField(
                                                  key: ValueKey(
                                                    'prendas-${i.id}-${entry.key}-$_revisionEmpaques',
                                                  ),
                                                  initialValue:
                                                      entry.value.prendas,
                                                  enabled: !congelado,
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Prendas',
                                                        isDense: true,
                                                      ),
                                                  onChanged:
                                                      (v) => setState(
                                                        () =>
                                                            entry
                                                                .value
                                                                .prendas = v,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Sumar prenda',
                                                onPressed:
                                                    congelado
                                                        ? null
                                                        : () => setState(() {
                                                          entry.value.prendas =
                                                              '${(int.tryParse(entry.value.prendas) ?? 0) + 1}';
                                                          _revisionEmpaques++;
                                                        }),
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 18,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Quitar empaque',
                                                onPressed:
                                                    congelado
                                                        ? null
                                                        : () => setState(() {
                                                          _asignaciones[i.id]!
                                                              .remove(
                                                                entry.key,
                                                              );
                                                          _revisionEmpaques++;
                                                        }),
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          );
                                          return c.maxWidth < 500
                                              ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  tipo,
                                                  const SizedBox(height: 8),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: cantidad,
                                                  ),
                                                ],
                                              )
                                              : Row(
                                                children: [
                                                  Expanded(child: tipo),
                                                  const SizedBox(width: 8),
                                                  cantidad,
                                                ],
                                              );
                                        },
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final e in catalogo.take(2))
                                        OutlinedButton.icon(
                                          onPressed:
                                              congelado ||
                                                      i.disponibleParaDespacho <=
                                                          0
                                                  ? null
                                                  : () => _agregarRapido(i, e),
                                          icon: Icon(
                                            e['categoria'] == 'CAJA'
                                                ? Icons.inventory_2_outlined
                                                : Icons.shopping_bag_outlined,
                                            size: 15,
                                          ),
                                          label: Text(
                                            '+ ${textoEmpaque(e['nombre'])}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
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
                                            'Usar empaque ${_numeros[b.key]}',
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
                                              if (id == null) return;
                                              setState(() {
                                                final existe = id.startsWith(
                                                  'usar:',
                                                );
                                                final key =
                                                    existe
                                                        ? id.substring(5)
                                                        : (_siguienteEmpaque++)
                                                            .toString();
                                                final tipo =
                                                    existe
                                                        ? _bultos[key]!
                                                        : id.substring(6);
                                                _asignaciones.putIfAbsent(
                                                  i.id,
                                                  () => {},
                                                )[key] = _EmpaqueAsignado(tipo);
                                                _revisionEmpaques++;
                                              });
                                            },
                                  ),
                                  if (catalogo.isEmpty)
                                    const Text(
                                      'No hay empaques activos. Créalos en Administración → Empaques.',
                                    ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed:
                                          congelado ||
                                                  (_asignaciones[i.id]
                                                          ?.isEmpty ??
                                                      true)
                                              ? null
                                              : () => setState(() {
                                                final maximo =
                                                    i.disponibleParaDespacho <
                                                            i.pendienteDisponibleDespacho
                                                        ? i.disponibleParaDespacho
                                                        : i.pendienteDisponibleDespacho;
                                                final falta =
                                                    maximo - _total(i);
                                                if (falta > 0) {
                                                  final ultima =
                                                      _asignaciones[i.id]!
                                                          .values
                                                          .last;
                                                  ultima.prendas =
                                                      '${(int.tryParse(ultima.prendas) ?? 0) + falta}';
                                                  _revisionEmpaques++;
                                                }
                                              }),
                                      child: const Text(
                                        'Repartir lo que falta',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                );
                final resumen = _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _titulo(
                        'Empaques del despacho',
                        '${_bultos.length} empaques · $_cantidadTotal prendas',
                      ),
                      if (_bultos.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 12,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xff648090),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Todavía no hay empaques',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Agrega una caja o paquete. Aquí aparecerá su número, peso y rótulo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      for (final b in _bultos.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: _navy,
                            child: Text(
                              '${_numeros[b.key]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            descripcionEmpaque(
                              catalogo
                                      .where((e) => e['id'] == b.value)
                                      .firstOrNull ??
                                  {'nombre': 'No disponible'},
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${_asignaciones.values.fold<int>(0, (n, a) => n + (int.tryParse(a[b.key]?.prendas ?? '0') ?? 0))} prendas${_rotuloPendiente(b.key) ? ' · Rótulo cambió' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (_prendasBulto(b.key) <= 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Vacío · agrega prendas o quita este empaque',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff9a6700),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      key: ValueKey('peso-bruto-${b.key}'),
                                      initialValue: _pesosBrutos[b.key] ?? '',
                                      enabled: !congelado,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Peso bruto (kg) *',
                                        isDense: true,
                                        helperText:
                                            'Pésalo cerrado, con las prendas dentro.',
                                        helperMaxLines: 2,
                                      ),
                                      onChanged:
                                          (valor) => setState(
                                            () => _pesosBrutos[b.key] = valor,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Generar rótulo ${_numeros[b.key]}',
                                    onPressed:
                                        congelado ||
                                                _destino == null ||
                                                _prendasBulto(b.key) <= 0
                                            ? null
                                            : () => _generarRotulo(b.key),
                                    icon: const Icon(
                                      Icons.print_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed:
                            congelado ||
                                    _destino == null ||
                                    _bultos.isEmpty ||
                                    _bultos.keys.any(
                                      (key) => _prendasBulto(key) <= 0,
                                    )
                                ? null
                                : () async {
                                  for (final b in _bultos.keys.toList()) {
                                    await _generarRotulo(b);
                                    if (!mounted) break;
                                  }
                                },
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Generar todos los rótulos'),
                      ),
                      const Text(
                        'Rótulos de 10 × 10 cm. Imprime al 100 %. Generarlos no guarda ni confirma la salida.',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Documentos del despacho',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ocDocumento,
                        enabled: !congelado,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: 'OC para este despacho (opcional)',
                          hintText: _oc,
                          helperText:
                              'Vacío conserva la OC original. Solo cambia este despacho y sus documentos.',
                          helperMaxLines: 3,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
                return constraints.maxWidth < 800
                    ? Column(children: [tarjetas, resumen])
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: tarjetas),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: resumen),
                      ],
                    );
              },
            ),
      );

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
        _items
            .where(
              (i) =>
                  q == null
                      ? i.item.codigo == texto.trim() ||
                          i.item.op == texto.trim()
                      : i.item.op == q.op && i.item.codigo == q.codigo,
            )
            .firstOrNull;
    if (item == null) {
      setState(() => _mensaje = 'QR no encontrado.');
      return;
    }
    if (item.disponibleParaDespacho <= 0 ||
        item.pendienteDisponibleDespacho <= 0) {
      _mensaje = 'La prenda no tiene unidades disponibles en bodega.';
      return;
    }
    if (_ops.isNotEmpty &&
        (_cliente != item.item.cliente || _oc != item.item.oc)) {
      _mensaje =
          'La etiqueta pertenece a otra OC. Termina la selección actual antes de cambiar.';
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
    if (item.disponibleParaDespacho <= 0 ||
        item.pendienteDisponibleDespacho <= 0) {
      return const FeedbackMessage.error('Sin prendas disponibles en bodega.');
    }
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

  double _pesoBruto(String pieza, Map<String, dynamic> empaque) {
    try {
      return validarPesoBruto(
        _pesosBrutos[pieza] ?? '',
        (empaque['peso_neto_kg'] as num?) ?? 0,
      );
    } on FormatException catch (e) {
      throw FormatException('Empaque ${_numeros[pieza]}: ${e.message}');
    }
  }

  String _resumenPeso(String pieza, String empaqueId) {
    final e =
        ref
            .read(empaquesProvider)
            .valueOrNull
            ?.where((e) => e['id'] == empaqueId)
            .firstOrNull;
    if (e == null) return 'Peso pendiente';
    try {
      final bruto = _pesoBruto(pieza, e);
      final tara = (e['peso_neto_kg'] as num?) ?? 0;
      return 'Bruto: $bruto kg · Tara: $tara kg · Neto: ${(bruto - tara).toStringAsFixed(3)} kg';
    } on FormatException {
      return 'Peso pendiente o inválido';
    }
  }

  Future<void> _preparar({bool completa = false}) async {
    if (_ocupado || _preparando) return;
    if (_pendiente != null) {
      await _guardar();
      return;
    }
    setState(() => _preparando = true);
    try {
      if (_faltaDestino) {
        throw const FormatException(
          'Selecciona el destinatario antes de empacar.',
        );
      }
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
            'peso_bruto_kg': _pesoBruto(entry.key, e),
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
      if (_paso != 3 || _planRevisado == null) {
        setState(() {
          _planRevisado = plan;
          _paso = 3;
        });
        return;
      }
      if (widget.correccion != null && _motivoCorreccion.text.trim().isEmpty) {
        throw const FormatException(
          'Indica el motivo de la corrección para guardar los cambios.',
        );
      }
      if (_bultos.keys.any(_rotuloPendiente)) {
        throw const FormatException(
          'Vuelve a generar los rótulos modificados antes de confirmar.',
        );
      }
      if (_planRevisado.toString() != plan.toString()) {
        setState(() => _planRevisado = plan);
        throw const FormatException(
          'Cambió la disponibilidad. Revisa nuevamente los estantes y confirma.',
        );
      }
      _confirmadas = total;
      _bultosConfirmados = _bultos.length;
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
          ocDocumento: _ocDocumento.text.trim(),
          destinatarioId: _destinatarioId,
          destinatarioVersion: _destino?['version'] as String?,
        );

        _correccionGuardada = true;
      } else {
        await repo.confirmar(
          _solicitud!,
          _cliente!,
          _oc!,
          _pendiente!,
          empaques: _empaquesPendientes,
          ocDocumento: _ocDocumento.text.trim(),
          destinatarioId: _destinatarioId,
          destinatarioVersion: _destino?['version'] as String?,
        );
      }
      _pendiente = null;
      _solicitud = null;
      ref.invalidate(historialDespachosProvider);
      ref.invalidate(entregasProvider);

      try {
        await ref.read(wmsRepositoryProvider).refrescar();
      } catch (_) {
        // El guardado ya fue confirmado; no repetirlo si falla el refresco.
      }
      if (mounted) {
        setState(() {
          _exito = true;
        });
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

  static const _navy = Color(0xff123e4f);
  static const _soft = Color(0xfff4f8f9);
  static const _green = Color(0xff1c704b);
  int get _cantidadTotal => _lineas
      .where((i) => _ops.contains(i.item.op))
      .fold(0, (n, i) => n + _total(i));
  String get _nombreDestino =>
      _destino == null
          ? 'Destino de prueba'
          : '${_destino!['datos']['nombre']} · ${_destino!['datos']['ciudad'] ?? _destino!['datos']['sede'] ?? ''}';
  Widget _panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffdce6eb)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  Widget _titulo(String titulo, String detalle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, color: _navy),
        ),
        Text(
          detalle,
          style: const TextStyle(fontSize: 12, color: Color(0xff648090)),
        ),
      ],
    ),
  );
  Widget _cabeceraEmpaque() => LayoutBuilder(
    builder: (context, c) {
      final titulo = _titulo(
        'Reparte las prendas en cajas o paquetes',
        'Cada empaque tiene su número, su peso y su rótulo.',
      );
      final buscador = TextField(
        controller: _buscarOpEmpaque,
        decoration: InputDecoration(
          labelText: 'Buscar por OP',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _buscarOpEmpaque.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Limpiar búsqueda de OP',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_buscarOpEmpaque.clear),
                  ),
        ),
        onChanged: (_) => setState(() {}),
      );
      return c.maxWidth < 650
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titulo, buscador],
          )
          : Row(
            children: [
              Expanded(child: titulo),
              const SizedBox(width: 20),
              SizedBox(width: 240, child: buscador),
            ],
          );
    },
  );
  Widget _pasos() => LayoutBuilder(
    builder: (context, c) {
      const nombres = ['Destino', 'Prendas', 'Empaques', 'Confirmar'];
      return Container(
        color: _soft,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            for (var n = 0; n < 4; n++) ...[
              if (n > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: n <= _paso ? _green : const Color(0xffe2ebef),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor:
                        n < _paso
                            ? _green
                            : n == _paso
                            ? _navy
                            : const Color(0xffe2ebef),
                    child:
                        n < _paso
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                            : Text(
                              '${n + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: n == _paso ? Colors.white : _navy,
                              ),
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nombres[n],
                    style: TextStyle(
                      fontSize: c.maxWidth < 400 ? 10 : 12,
                      fontWeight:
                          n == _paso ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _destinoPaso(bool bloqueado) {
    final clientes =
        _items
            .where(
              (i) =>
                  i.disponibleParaDespacho > 0 &&
                  i.pendienteDisponibleDespacho > 0,
            )
            .map((i) => i.item.cliente)
            .toSet()
            .toList()
          ..sort();
    if (widget.correccion != null &&
        _cliente != null &&
        !clientes.contains(_cliente)) {
      clientes.add(_cliente!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(
          '¿A quién va el empaque?',
          'El destinatario y su sede salen impresos en el rótulo.',
        ),
        if (ref.watch(usarSupabaseProvider)) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  bloqueado ? null : () => mostrarListaEmpaque(context, ''),
              icon: const Icon(Icons.contacts_outlined, size: 16),
              label: const Text('Catálogo / consecutivo LE'),
            ),
          ),
          _selectorDestino(bloqueado),
        ],
        _titulo(
          '¿De qué cliente son las prendas?',
          'En el siguiente paso verás sus órdenes de compra.',
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(_cliente),
          initialValue: _cliente,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: [
            for (final c in clientes)
              DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged:
              bloqueado
                  ? null
                  : (v) => setState(() {
                    _limpiar();
                    _cliente = v;
                    _oc = null;
                  }),
        ),
        if (clientes.isEmpty)
          const Text('No hay prendas disponibles en bodega.'),
      ],
    );
  }

  Future<void> _entradaCodigo() async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => WmsExpandableAlertDialog(
            title: const Text('Seleccionar prendas'),
            content: SizedBox(
              width: 400,
              child: WmsScanField(
                controller: _qr,
                decoration: const InputDecoration(
                  labelText: 'QR o código de etiqueta',
                ),
                onSubmitted: (v) {
                  _escanear(v);
                  Navigator.pop(ctx);
                },
                onCameraSubmitted: _leerCamara,
              ),
            ),
          ),
    );
  }

  Widget _avanceProduccion(Iterable<ItemKardex> lineas, String alcance) {
    final total = lineas.fold<int>(0, (s, i) => s + i.cantidadPedida);
    final entregado = lineas.fold<int>(0, (s, i) => s + i.producido);
    final avance = total > 0 ? entregado / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Producción $alcance: $entregado de $total prendas · ${(avance * 100).toStringAsFixed(1)} %',
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: avance.clamp(0.0, 1.0)),
        ],
      ),
    );
  }

  Widget _prendasPaso(bool bloqueado) {
    // El avance incluye las tallas y OP que todavía no tienen stock en bodega.
    final todas = _items.where((i) => i.item.cliente == _cliente).toList();
    final items =
        todas
            .where(
              (i) =>
                  i.item.cliente == _cliente &&
                  i.disponibleParaDespacho > 0 &&
                  i.pendienteDisponibleDespacho > 0,
            )
            .toList();
    final ocs = items.map((i) => i.item.oc).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(
          '¿Qué OP van en este despacho?',
          '$_cliente · Solo aparecen prendas disponibles en bodega. Se empaca una OC a la vez.',
        ),
        for (final oc in ocs)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      oc.isEmpty ? 'Sin OC' : oc,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    OutlinedButton(
                      onPressed:
                          bloqueado
                              ? null
                              : () => setState(() {
                                if (_oc != oc) _limpiar();
                                _oc = oc;
                                _ops.addAll(
                                  items
                                      .where((i) => i.item.oc == oc)
                                      .map((i) => i.item.op),
                                );
                              }),
                      child: const Text('Elegir toda la OC'),
                    ),
                  ],
                ),
                _avanceProduccion(todas.where((i) => i.item.oc == oc), 'OC'),
                for (final op
                    in items
                        .where((i) => i.item.oc == oc)
                        .map((i) => i.item.op)
                        .toSet())
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _oc == oc && _ops.contains(op),
                    title: Text(
                      'OP $op',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items
                              .where((i) => i.item.oc == oc && i.item.op == op)
                              .map(
                                (i) =>
                                    '${i.item.descripcion} · Talla ${i.item.talla} · ${i.disponibleParaDespacho} en bodega · ${i.ubicaciones.keys.join(', ')}',
                              )
                              .join('\n'),
                        ),
                        _avanceProduccion(
                          todas.where(
                            (i) => i.item.oc == oc && i.item.op == op,
                          ),
                          'OP $op',
                        ),
                      ],
                    ),
                    onChanged:
                        bloqueado
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
        if (ocs.isEmpty)
          const Text('No hay prendas disponibles para este cliente.'),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titulo(
                '¿Tienes las prendas en la mano?',
                'Escanéalas y se marcan solas.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        bloqueado
                            ? null
                            : () => showDialog<void>(
                              context: context,
                              builder:
                                  (_) => WmsCameraScanner(onRead: _leerCamara),
                            ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Cámara'),
                  ),
                  OutlinedButton(
                    onPressed: bloqueado ? null : _entradaCodigo,
                    child: const Text('Lector'),
                  ),
                  OutlinedButton(
                    onPressed: bloqueado ? null : _entradaCodigo,
                    child: const Text('Escribir código'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revision() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _titulo(
        'Revisa antes de confirmar',
        'Si algo no cuadra, vuelve al paso que corresponda. Nada se ha guardado todavía.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final dato in [
            ('Destinatario', _nombreDestino),
            ('Cliente', _cliente ?? ''),
            ('Orden de compra', _ocVisible),
            ('Se reserva en bodega', '$_cantidadTotal prendas'),
          ])
            SizedBox(
              width: 220,
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dato.$1, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      dato.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '${_bultos.length} empaques',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed:
                _ocupado || _pendiente != null
                    ? null
                    : () => setState(() {
                      _paso = 2;
                      _planRevisado = null;
                    }),
            child: const Text('Editar empaques'),
          ),
        ],
      ),
      for (final b in _bultos.entries)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empaque ${_numeros[b.key]} · ${descripcionEmpaque(ref.read(empaquesProvider).valueOrNull?.where((c) => c['id'] == b.value).firstOrNull ?? {'nombre': 'Empaque'})}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_resumenPeso(b.key, b.value)),
              for (final i in _lineas.where(
                (i) =>
                    _ops.contains(i.item.op) &&
                    _asignaciones[i.id]?[b.key] != null,
              ))
                Text(
                  'OP ${i.item.op} · Talla ${i.item.talla} · ${_asignaciones[i.id]![b.key]!.prendas} prendas',
                ),
              Text(
                _rotuloPendiente(b.key)
                    ? 'Rótulo modificado: vuelve a generarlo'
                    : _rotulosGenerados.containsKey(b.key)
                    ? 'Rótulo generado'
                    : 'Rótulo sin generar',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      if (_planRevisado != null)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estantes de origen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final l in _planRevisado!)
                Text(
                  'OP ${l['op']} · Talla ${l['talla']} · ${l['cantidad']} desde ${l['ubicacion']}',
                ),
            ],
          ),
        ),
      if (widget.correccion != null)
        TextField(
          controller: _motivoCorreccion,
          decoration: const InputDecoration(
            labelText: 'Motivo de la corrección (obligatorio)',
          ),
        ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfffff4dd),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Al confirmar, las prendas quedan reservadas y se crea la LE. La salida física se registra después en Seguimiento, cuando el transportador recoja.',
        ),
      ),
    ],
  );
  Widget _resultado(BuildContext tabContext) => Center(
    child: SingleChildScrollView(
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xffe5f3eb),
            child: Icon(Icons.check, color: _green, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Empaque confirmado',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Las $_confirmadas prendas quedaron reservadas en $_bultosConfirmados empaques. La LE aparece en Seguimiento para registrar la salida.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _panel(Text('$_ocVisible · $_nombreDestino')),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed:
                    () => setState(() {
                      _limpiar();
                      _exito = false;
                      _paso = 0;
                      _planRevisado = null;
                      _oc = null;
                    }),
                child: const Text('Empacar otra OC'),
              ),
              if (_puedeSeguimiento)
                FilledButton(
                  onPressed:
                      () => DefaultTabController.of(tabContext).animateTo(1),
                  child: const Text('Ir a Seguimiento'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _contenidoTabs(BuildContext context, List<Widget> paginas) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder:
          (_, __) => IndexedStack(index: controller.index, children: paginas),
    );
  }

  @override
  Widget build(BuildContext context) {
    // El catálogo autoDispose debe seguir observado al ocultar el paso Destino.
    // Los rótulos y la confirmación necesitan sus datos y su versión hasta cerrar.
    ref.watch(destinatariosEmpaqueProvider);
    ref.watch(usuarioSesionProvider);
    final puedeSeguimiento = _puedeSeguimiento;
    final estado = ref.watch(wmsSnapshotProvider);
    final congelado =
        _ocupado || _preparando || _generandoRotulo || _pendiente != null;
    return PopScope(
      canPop: !congelado,
      child: WmsDialogShell(
        canClose: !congelado,
        mobileCatalog: true,
        fullscreen: _pantallaCompleta,
        onToggleFullscreen:
            () => setState(() => _pantallaCompleta = !_pantallaCompleta),
        expand: true,
        maxWidth: 1100,
        title:
            widget.correccion == null
                ? 'Despachos por orden de compra'
                : 'Corregir despacho · LE ${widget.correccion!['le_numero'] ?? ''}',
        subtitle: 'Empaca: ${ref.watch(nombreOperarioProvider)}',
        icon: Icons.local_shipping_outlined,
        iconColor: _navy,
        child: DefaultTabController(
          key: ValueKey(puedeSeguimiento),
          length: puedeSeguimiento ? 3 : 2,
          initialIndex:
              widget.correccion == null &&
                      ref.watch(usarSupabaseProvider) &&
                      ref.watch(usuarioSesionProvider).valueOrNull?.rolCuenta ==
                          RolCuenta.seguimiento
                  ? 1
                  : 0,
          child: Builder(
            builder:
                (tabContext) => Column(
                  children: [
                    TabBar(
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        const Tab(text: 'Despacho'),
                        if (puedeSeguimiento) const Tab(text: 'Seguimiento'),
                        const Tab(text: 'Historial'),
                      ],
                    ),
                    Expanded(
                      child: _contenidoTabs(tabContext, [
                        _exito
                            ? _resultado(tabContext)
                            : Column(
                              children: [
                                _pasos(),
                                if (estado.isLoading || _ocupado || _preparando)
                                  const WmsLoadingStrip(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child:
                                        _paso == 0
                                            ? _destinoPaso(congelado)
                                            : _paso == 1
                                            ? _prendasPaso(congelado)
                                            : _paso == 2
                                            ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _cabeceraEmpaque(),
                                                const SizedBox(height: 12),
                                                _detalleSeleccion(congelado),
                                              ],
                                            )
                                            : _revision(),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: _soft,
                                    border: Border(
                                      top: BorderSide(color: Color(0xffdce6eb)),
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final siguiente = FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              _paso == 3 ? _green : _navy,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed:
                                            _ocupado ||
                                                    _preparando ||
                                                    _generandoRotulo ||
                                                    (_paso == 0 &&
                                                        (_cliente == null ||
                                                            _faltaDestino)) ||
                                                    (_paso == 1 &&
                                                        _ops.isEmpty) ||
                                                    (_paso == 2 &&
                                                        _pendienteEmpaque !=
                                                            null)
                                                ? null
                                                : () {
                                                  if (_paso >= 2) {
                                                    _preparar();
                                                  } else {
                                                    setState(() => _paso++);
                                                  }
                                                },
                                        icon: Icon(
                                          _paso == 3
                                              ? Icons.check_circle_outline
                                              : Icons.arrow_forward,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _ocupado
                                              ? 'Guardando…'
                                              : _pendiente != null
                                              ? 'Reintentar mismo despacho'
                                              : [
                                                'Elegir prendas',
                                                'Armar empaques',
                                                'Revisar empaque',
                                                'Confirmar empaque',
                                              ][_paso],
                                        ),
                                      );
                                      final atras = OutlinedButton.icon(
                                        onPressed:
                                            congelado || _paso == 0
                                                ? null
                                                : () => setState(() {
                                                  _paso--;
                                                  _planRevisado = null;
                                                }),
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          size: 16,
                                        ),
                                        label: const Text('Atrás'),
                                      );
                                      final resumen = Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _paso == 0
                                                ? 'Paso 1 de 4 · Destino'
                                                : _paso == 1
                                                ? '${_ops.length} OP elegidas'
                                                : '$_cantidadTotal prendas · ${_bultos.length} empaques',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (_paso == 2 &&
                                              _pendienteEmpaque != null)
                                            Text(
                                              _pendienteEmpaque!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xff9a6700),
                                              ),
                                            ),
                                        ],
                                      );
                                      return c.maxWidth < 550
                                          ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              resumen,
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (_paso > 0) ...[
                                                    atras,
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(child: siguiente),
                                                ],
                                              ),
                                            ],
                                          )
                                          : Row(
                                            children: [
                                              if (_paso > 0) atras,
                                              Expanded(child: resumen),
                                              siguiente,
                                            ],
                                          );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        if (puedeSeguimiento)
                          const SeguimientoPanel(
                            pendientes: _Historial(seguimiento: true),
                          ),
                        const _Historial(),
                      ]),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _Historial extends ConsumerStatefulWidget {
  const _Historial({this.seguimiento = false});
  final bool seguimiento;
  @override
  ConsumerState<_Historial> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<_Historial> {
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
      ref.invalidate(entregasProvider);
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
          tipo: TipoAviso.error,
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoCorreccion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conectado = ref.watch(usarSupabaseProvider);
    final rol = ref.watch(usuarioSesionProvider).valueOrNull?.rolCuenta;
    final puedeVerEntregas =
        !conectado || rol == RolCuenta.seguimiento || rol == RolCuenta.admin;
    // Despacho conserva el historial sin consultar una RPC restringida.
    final entregas =
        puedeVerEntregas ? ref.watch(entregasProvider).valueOrNull : null;
    return ref
        .watch(historialDespachosProvider)
        .when(
          loading: () => const WmsLoadingPanel(),
          error:
              (_, __) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(historialDespachosProvider),
                  child: const Text('No se pudo cargar. Reintentar'),
                ),
              ),
          data:
              (todas) => HistorialDespachosVista(
                filas:
                    todas
                        .where(
                          (f) =>
                              (f['fase'] == 'empacado') == widget.seguimiento,
                        )
                        .toList(),
                entregas: entregas,
                mostrarEntregadas: puedeVerEntregas,
                pendientes: widget.seguimiento,
                ocupado: _abriendoCorreccion,
                onCorregir: conectado ? _corregir : null,
                onDocumento:
                    conectado ? (id) => mostrarListaEmpaque(context, id) : null,
              ),
        );
  }
}
