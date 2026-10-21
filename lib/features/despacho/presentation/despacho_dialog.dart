import '../../../data/inventario_repository.dart';
import '../../../domain/destinatario_internacional.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'historial_despachos_vista.dart';
import '../../../data/seguimiento_entregas.dart';
import 'seguimiento_entregas_tabla.dart';
import 'facturacion_panel.dart';
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
  const DespachoDialog({super.key, this.correccion, this.inventario})
    : assert(correccion == null || inventario == null);
  final InventarioFila? inventario;
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
      (ref.read(usuarioSesionProvider).valueOrNull?.puedeSeguimiento ?? false);
  bool get _admin =>
      ref.read(usuarioSesionProvider).valueOrNull?.tieneRol(RolCuenta.admin) ==
      true;
  bool _empaqueMasivo = false;
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

  Widget _selectorDestinoBuscable(
    List<Map<String, dynamic>> datos,
    bool congelado,
  ) {
    Future<void> elegir() async {
      var consulta = '';
      final id = await showDialog<String>(
        context: context,
        builder:
            (ctx) => StatefulBuilder(
              builder:
                  (ctx, cambiar) => AlertDialog(
                    title: const Text('Seleccionar destinatario o sede'),
                    content: SizedBox(
                      width: 560,
                      height: MediaQuery.sizeOf(ctx).height * .5,
                      child: Column(
                        children: [
                          TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Buscar destinatario o sede',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged:
                                (v) => cambiar(
                                  () => consulta = v.trim().toLowerCase(),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final lista =
                                    datos
                                        .where(
                                          (d) => '${d['datos']}'
                                              .toLowerCase()
                                              .contains(consulta),
                                        )
                                        .toList();
                                if (lista.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No hay destinatarios que coincidan.',
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: lista.length,
                                  itemBuilder: (_, i) {
                                    final d = lista[i];
                                    final info = d['datos'] as Map;
                                    return ListTile(
                                      title: Text('${info['nombre']}'),
                                      subtitle: Text(
                                        '${info['sede'] ?? ''} · ${info['ciudad'] ?? ''} · ${info['direccion'] ?? ''}${esDestinatarioInternacional(info) ? ' · Internacional · ${info['pais_destino']}' : ''}',
                                      ),
                                      trailing:
                                          d['id'] == _destinatarioId
                                              ? const Icon(Icons.check_circle)
                                              : null,
                                      onTap:
                                          () =>
                                              Navigator.pop(ctx, '${d['id']}'),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
            ),
      );
      if (mounted && id != null) setState(() => _destinatarioId = id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Destino del empaque',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Destinatario o sede *',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                onPressed: congelado ? null : elegir,
                icon: const Icon(Icons.search, size: 20),
                label: Text(
                  _destino == null
                      ? 'Buscar y seleccionar destinatario o sede'
                      : _nombreDestino,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Actualizar destinatarios',
              onPressed:
                  congelado
                      ? null
                      : () => ref.invalidate(destinatariosEmpaqueProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _destino == null
              ? '¿No aparece? Actualiza para recargar la lista.'
              : '${_destino!['datos']['direccion'] ?? ''}',
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        if (datos.isEmpty)
          const Text(
            'Administración debe registrar un destinatario antes de empacar.',
          ),
        const SizedBox(height: 20),
      ],
    );
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
        data: (datos) => _selectorDestinoBuscable(datos, congelado),
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
    if (widget.inventario case final origen?) {
      _cliente = origen['cliente'] as String;
      for (final r in _origenesInventario) {
        _ops.add('${r['numero_op']}');
      }
    }
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
    _empaqueMasivo = false;
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

  // Proyección exclusiva para empacar el saldo elegido; no altera el kardex.
  List<InventarioFila> get _origenesInventario =>
      widget.inventario?['origenes'] is List
          ? (widget.inventario!['origenes'] as List).cast<InventarioFila>()
          : [widget.inventario!];

  List<ItemKardex> get _itemsInventario {
    final grupos = <String, List<InventarioFila>>{};
    for (final r in _origenesInventario) {
      grupos.putIfAbsent('${r['item_id']}', () => []).add(r);
    }
    return grupos.entries.map((e) {
      final r = e.value.first;
      final ubicaciones = <String, int>{};
      for (final f in e.value) {
        final u = '${f['ubicacion']}';
        ubicaciones[u] = (ubicaciones[u] ?? 0) + (f['libre'] as num).toInt();
      }
      final libre = ubicaciones.values.fold<int>(0, (a, b) => a + b);
      return ItemKardex(
        item: ItemOrden(
          id: e.key,
          op: '${r['numero_op']}',
          cliente: '${widget.inventario!['cliente']}',
          oc: _ocVisible,
          codigo: '${r['codigo'] ?? ''}',
          descripcion: '${r['producto']}',
          talla: '${r['talla']}',
          cantidadPedida: libre,
        ),
        producido: libre,
        recibido: libre,
        despachado: 0,
        ubicaciones: ubicaciones,
      );
    }).toList();
  }

  List<InventarioFila> _asignacionesInventario() {
    final usadas = <String, int>{};
    for (final linea in _pendiente!) {
      var falta = (linea['cantidad'] as num).toInt();
      for (final r in _origenesInventario.where(
        (r) =>
            r['item_id'] == linea['item_id'] &&
            r['ubicacion'] == linea['ubicacion'],
      )) {
        final id = '${r['id']}';
        final libre = (r['libre'] as num).toInt() - (usadas[id] ?? 0);
        final tomar = falta < libre ? falta : libre;
        if (tomar > 0) {
          usadas[id] = (usadas[id] ?? 0) + tomar;
          falta -= tomar;
        }
        if (falta == 0) break;
      }
      if (falta != 0) {
        throw StateError('Las cantidades superan la selección de inventario.');
      }
    }
    return [
      for (final e in usadas.entries)
        {'transferencia': e.key, 'cantidad': e.value},
    ];
  }

  List<ItemKardex> get _items =>
      widget.inventario != null
          ? _itemsInventario
          : (ref.read(wmsSnapshotProvider).value?.kardex ?? [])
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
                  stockInventario: i.stockInventario,
                  ubicaciones: ubicaciones,
                  reservas: reservas,
                );
              })
              .toList();
  List<ItemKardex> get _lineas =>
      _items
          .where(
            (i) =>
                i.item.cliente == _cliente &&
                (widget.inventario != null || i.item.oc == _oc),
          )
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
            if (_empaqueMasivo) 'admin_masivo': true,
          });
          cantidades[i.id] = (cantidades[i.id] ?? 0) + n;
        }
      }
      if (widget.inventario?['origenes'] is List &&
          _lineas.any(
            (i) => cantidades[i.id] != i.pendienteDisponibleDespacho,
          )) {
        throw const FormatException(
          'Distribuye todas las cantidades seleccionadas en los empaques para conservar el reparto de inventario.',
        );
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
      if (widget.inventario != null) {
        final inventarioRepo = ref.read(inventarioRepositoryProvider);
        if (inventarioRepo == null) {
          throw StateError('Inventario no disponible');
        }
        await inventarioRepo.ejecutar(
          widget.inventario!['origenes'] is List
              ? 'inventario_empacar_multiple'
              : 'inventario_empacar_flujo',
          {
            'p_solicitud': _solicitud!,
            if (widget.inventario!['origenes'] is List)
              'p_asignaciones': _asignacionesInventario()
            else
              'p_transferencia': widget.inventario!['id'],
            'p_oc': _ocVisible,
            'p_destinatario': _destinatarioId,
            'p_destinatario_version': _destino?['version'],
            'p_empaques': _empaquesPendientes,
          },
        );
      } else if (widget.correccion != null) {
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
  Future<void> _empacarOcMasiva() async {
    if (!_admin || _ocupado || _preparando) return;
    final cajas =
        (ref.read(empaquesProvider).valueOrNull ?? [])
            .where((e) => e['categoria'] == 'CAJA')
            .toList();
    final elegibles =
        _lineas
            .where(
              (i) =>
                  min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho) >
                  0,
            )
            .toList();
    if (cajas.isEmpty || elegibles.isEmpty) {
      setState(
        () =>
            _mensaje =
                'Se necesita una caja activa y prendas disponibles de esta OC.',
      );
      return;
    }
    String caja = '${cajas.first['id']}';
    final total = elegibles.fold<int>(
      0,
      (n, i) =>
          n + min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho),
    );
    final elegido = await showDialog<String>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, cambiar) => AlertDialog(
                  title: const Text('Empacar toda la OC en una caja'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'OC $_oc · $total unidades disponibles · ${elegibles.map((i) => i.item.op).toSet().length} OP. Reemplaza la distribución de empaques que estás editando. Las unidades sin stock quedan pendientes.',
                      ),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: caja,
                        items: [
                          for (final e in cajas)
                            DropdownMenuItem(
                              value: '${e['id']}',
                              child: Text(
                                '${e['nombre']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => cambiar(() => caja = v!),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, caja),
                      child: const Text('Preparar empaque'),
                    ),
                  ],
                ),
          ),
    );
    if (elegido == null || !mounted || !_admin) return;
    setState(() {
      _ops
        ..clear()
        ..addAll(elegibles.map((i) => i.item.op));
      _asignaciones.clear();
      _pesosBrutos.clear();
      _rotulosGenerados.clear();
      final pieza = '${_siguienteEmpaque++}';
      for (final i in elegibles) {
        _asignaciones[i.id] = {
          pieza: _EmpaqueAsignado(elegido)
            ..prendas =
                '${min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho)}',
        };
      }
      _empaqueMasivo = true;
      _planRevisado = null;
      _revisionEmpaques++;
      _buscarOpEmpaque.clear();
      _mensaje =
          'OC agrupada en una caja. Indica su peso bruto y revisa antes de confirmar.';
    });
  }

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
      return c.maxWidth < 950
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titulo,
              buscador,
              if (_admin)
                TextButton.icon(
                  onPressed: _ocupado || _preparando ? null : _empacarOcMasiva,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text("Empacar OC completa"),
                ),
            ],
          )
          : Row(
            children: [
              Expanded(child: titulo),
              const SizedBox(width: 20),
              SizedBox(width: 240, child: buscador),
              if (_admin)
                TextButton.icon(
                  onPressed: _ocupado || _preparando ? null : _empacarOcMasiva,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text("Empacar OC completa"),
                ),
            ],
          );
    },
  );
  Widget _pasos() => LayoutBuilder(
    builder: (context, c) {
      const nombres = ['Destino', 'Prendas', 'Empaques', 'Confirmar'];
      return Container(
        color: Colors.white,
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
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 17,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: c.maxWidth < 400 ? 10 : 12,
                        fontWeight:
                            n == _paso ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _destinoPaso(bool bloqueado) {
    if (widget.inventario != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder:
                (context, c) => Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final dato in [
                      ('Cliente', '$_cliente'),
                      (
                        widget.inventario!['origenes'] is List
                            ? 'Fichas técnicas'
                            : 'Ficha técnica',
                        widget.inventario!['origenes'] is List
                            ? '${_origenesInventario.map((r) => r['ficha']).toSet().length}'
                            : '${widget.inventario!['ficha']}',
                      ),
                      (
                        widget.inventario!['origenes'] is List
                            ? 'Prendas seleccionadas'
                            : 'OP origen',
                        widget.inventario!['origenes'] is List
                            ? '${_itemsInventario.fold<int>(0, (a, i) => a + i.recibido)} unidades'
                            : '${widget.inventario!['numero_op']}',
                      ),
                    ])
                      Container(
                        width:
                            c.maxWidth < 550
                                ? c.maxWidth
                                : (c.maxWidth - 24) / 3,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dato.$1,
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dato.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Color(0xFF285D94)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Las prendas conservan su cliente y se asignan a la OC que indiques.',
                    style: TextStyle(color: Color(0xFF285D94)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _selectorDestino(bloqueado),
          TextField(
            controller: _ocDocumento,
            enabled: !bloqueado,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Orden de compra de destino',
              hintText: 'Ej.: OC-2026-0458',
            ),
            onChanged: (v) => setState(() => _oc = v.trim()),
          ),
        ],
      );
    }
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
    Widget tarjeta(List<Widget> contenido) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE6EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contenido,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tarjeta([
          LayoutBuilder(
            builder: (context, c) {
              final titulo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿A quién va el empaque?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'El destinatario y su sede salen impresos en el rótulo.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                  ),
                ],
              );
              final catalogo = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                ),
                onPressed:
                    bloqueado ? null : () => mostrarListaEmpaque(context, ''),
                icon: const Icon(Icons.contacts_outlined, size: 18),
                label: const Text('Catálogo / consecutivo LE'),
              );
              if (!ref.watch(usarSupabaseProvider)) return titulo;
              return c.maxWidth < 650
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titulo, const SizedBox(height: 10), catalogo],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titulo),
                      const SizedBox(width: 16),
                      catalogo,
                    ],
                  );
            },
          ),
          if (ref.watch(usarSupabaseProvider)) ...[
            const SizedBox(height: 16),
            _selectorDestino(bloqueado),
          ],
        ]),
        const SizedBox(height: 16),
        tarjeta([
          const Text(
            '¿De qué cliente son las prendas?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _navy,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'En el siguiente paso verás sus órdenes de compra.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 13),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey(_cliente),
            initialValue: _cliente,
            isExpanded: true,
            menuMaxHeight: 260,
            dropdownColor: Colors.white,
            decoration: const InputDecoration(
              labelText: 'Cliente',
              hintText: 'Selecciona un cliente',
              filled: true,
              fillColor: Colors.white,
            ),
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
        ]),
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
                                if (_oc != oc && widget.inventario == null) {
                                  _limpiar();
                                }
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
              if (widget.inventario == null)
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
            widget.inventario != null
                ? 'Despacho desde inventario'
                : widget.correccion == null
                ? 'Despachos por orden de compra'
                : 'Corregir despacho · LE ${widget.correccion!['le_numero'] ?? ''}',
        subtitle: 'Empaca: ${ref.watch(nombreOperarioProvider)}',
        icon: Icons.local_shipping_outlined,
        iconColor: _navy,
        child: DefaultTabController(
          key: ValueKey(puedeSeguimiento),
          length: puedeSeguimiento ? 4 : 2,
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
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(
                          color: Color(0xFFC8DB00),
                          width: 3,
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: _navy,
                      unselectedLabelColor: Colors.blueGrey,
                      isScrollable: MediaQuery.sizeOf(context).width < 650,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      tabs: [
                        const Tab(text: 'Despacho'),
                        if (puedeSeguimiento) const Tab(text: 'Seguimiento'),
                        if (puedeSeguimiento) const Tab(text: 'Facturación'),
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
                                                            _faltaDestino ||
                                                            (widget.inventario !=
                                                                    null &&
                                                                _ocVisible
                                                                    .isEmpty))) ||
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
                                      final cancelar = OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                        ),
                                        onPressed:
                                            congelado
                                                ? null
                                                : () => Navigator.pop(context),
                                        child: const Text('Cancelar'),
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
                                                  if (_paso == 0) ...[
                                                    cancelar,
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
                                              if (_paso == 0) ...[
                                                cancelar,
                                                const SizedBox(width: 12),
                                              ],
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
                        if (puedeSeguimiento) const FacturacionPanel(),
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
    final puedeSeguimiento =
        ref.watch(usuarioSesionProvider).valueOrNull?.puedeSeguimiento ?? false;
    final puedeVerEntregas = !conectado || puedeSeguimiento;
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
                          (f) => !widget.seguimiento || f['fase'] == 'empacado',
                        )
                        .toList(),
                entregas: entregas,
                mostrarEntregadas: puedeVerEntregas,
                onActualizar: () => ref.invalidate(historialDespachosProvider),
                pendientes: widget.seguimiento,
                ocupado: _abriendoCorreccion,
                onCorregir: conectado ? _corregir : null,
                onDocumento:
                    conectado ? (id) => mostrarListaEmpaque(context, id) : null,
              ),
        );
  }
}
