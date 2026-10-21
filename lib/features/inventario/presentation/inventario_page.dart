import '../../../shared/widgets/wms_loader.dart';
import 'dart:convert';
import 'inventario_seleccion.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'inventario_existencias.dart';
import 'inventario_historial.dart';
import '../../../shared/widgets/catalogo_ubicacion_dropdown.dart';
import 'importar_inventario_dialog.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../../shared/widgets/wms_dialog.dart';
import 'inventario_vista.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../data/inventario_repository.dart';
import '../../../data/empaques_repository.dart';
import '../../../domain/sesion.dart';

class InventarioPage extends ConsumerStatefulWidget {
  const InventarioPage({super.key});
  @override
  ConsumerState<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends ConsumerState<InventarioPage> {
  final _buscar = TextEditingController();
  Timer? _debounce;
  int _pagina = 0;
  Future<InventarioFila>? _datos;
  final _filtros = <String, Set<String>>{};
  List<InventarioFila>? _todas;
  bool _abriendoFiltro = false;
  final _seleccion = <String, InventarioFila>{};
  bool _preparando = false;
  String _clave(InventarioFila r) =>
      jsonEncode([r['cliente'], r['ficha'], r['talla']]);
  void _seleccionarFila(InventarioFila r, bool valor) {
    if (_preparando) return;
    if (valor &&
        _seleccion.isNotEmpty &&
        _seleccion.values.first['cliente'] != r['cliente']) {
      return;
    }
    setState(() {
      if (valor) {
        _seleccion[_clave(r)] = r;
      } else {
        _seleccion.remove(_clave(r));
      }
    });
  }

  Future<void> _despacharSeleccion() async {
    if (_preparando || _seleccion.isEmpty) return;
    final cantidades = await showWmsDialog<List<InventarioFila>>(
      context,
      (_) => InventarioSeleccion(filas: _seleccion.values.toList()),
    );
    if (!mounted || cantidades == null) return;
    setState(() => _preparando = true);
    try {
      final origenes = await _repo!.filas('inventario_preparar_despacho', {
        'p_seleccion': cantidades,
      });
      if (!mounted) return;
      setState(() => _preparando = false);
      await showWmsDialog<void>(
        context,
        (_) => DespachoDialog(
          inventario: {
            'cliente': cantidades.first['cliente'],
            'origenes': origenes,
          },
        ),
      );
      if (mounted) _refrescar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo preparar el despacho: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _preparando = false);
    }
  }

  Future<List<InventarioFila>> _leerTodas() async {
    final repo = _repo!;
    final rows = <InventarioFila>[];
    for (var p = 0; ; p++) {
      final result = await repo.listar('', p);
      final page = (result['filas'] as List).cast<InventarioFila>();
      rows.addAll(page);
      if (rows.length >= (result['total'] as num) || page.isEmpty) break;
    }
    return rows;
  }

  Future<InventarioFila> _filtradas() async {
    final rows = _todas ??= await _leerTodas();
    final query = _buscar.text.trim().toLowerCase();
    final filtered =
        rows
            .where(
              (r) =>
                  ['ficha', 'producto', 'cliente', 'talla']
                      .map((k) => '${r[k] ?? ''}')
                      .join(' ')
                      .toLowerCase()
                      .contains(query) &&
                  _filtros.entries.every(
                    (f) =>
                        f.value.isEmpty ||
                        f.value.contains('${r[f.key] ?? ''}'),
                  ),
            )
            .toList();
    final maxPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 25;
    if (_pagina > maxPage) _pagina = maxPage;
    return {
      'total': filtered.length,
      'filas': filtered.skip(_pagina * 25).take(25).toList(),
    };
  }

  Future<void> _filtrar(String key, String label) async {
    if (_abriendoFiltro || _repo == null) return;
    _abriendoFiltro = true;
    try {
      final rows = _todas ??= await _leerTodas();
      if (!mounted) return;
      final options =
          rows.map((r) => '${r[key] ?? ''}').toSet().toList()..sort((a, b) {
            final na = num.tryParse(a), nb = num.tryParse(b);
            return na != null && nb != null ? na.compareTo(nb) : a.compareTo(b);
          });
      final chosen = await showMultiSelectFilter<String>(
        context,
        title: 'Filtrar por ${label.replaceAll('\n', ' ')}',
        options: options,
        selected: _filtros[key] ?? {},
        labelOf: (v) => v.isEmpty ? 'Sin dato' : v,
      );
      if (!mounted || chosen == null) return;
      setState(() {
        if (chosen.isEmpty) {
          _filtros.remove(key);
        } else {
          _filtros[key] = chosen;
        }
        _pagina = 0;
        _cargar();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar los filtros: $e')),
        );
      }
    } finally {
      _abriendoFiltro = false;
    }
  }

  InventarioRepository? get _repo => ref.read(inventarioRepositoryProvider);
  bool _permiso(List<RolCuenta> roles) {
    if (_repo == null) return false;
    final s = ref.read(usuarioSesionProvider).value;
    return roles.any((r) => s?.tieneRol(r) == true);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _datos =
        _repo == null
            ? null
            : _filtros.isEmpty
            ? _repo!.listar(_buscar.text.trim(), _pagina)
            : _filtradas();
  }

  void _refrescar() => setState(() {
    _todas = null;
    _cargar();
  });
  @override
  void dispose() {
    _debounce?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _abrir({
    InventarioFila? grupo,
    bool origenes = false,
    bool despacho = false,
  }) async {
    final seleccion = await showDialog<InventarioFila>(
      context: context,
      builder:
          (_) => _DetalleInventario(
            repo: _repo!,
            grupo: grupo,
            origenes: origenes,
            despacho: despacho,
            puedeTransferir: _permiso([RolCuenta.admin, RolCuenta.logistica]),
            puedeEmpacar: _permiso([RolCuenta.admin, RolCuenta.despacho]),
            puedeEliminar: _permiso([RolCuenta.admin]),
          ),
    );
    if (!mounted) return;
    if (seleccion != null) {
      await showWmsDialog<void>(
        context,
        (_) => DespachoDialog(inventario: seleccion),
      );
      if (!mounted) return;
    }
    _refrescar();
    try {
      await ref.read(wmsRepositoryProvider).refrescar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar el kardex. Pulsa Sincronizar para consultar el saldo actual.',
            ),
          ),
        );
      }
    }
  }

  void _busquedaLimpiar() {
    _debounce?.cancel();
    _buscar.clear();
    _filtros.clear();
    _todas = null;
    _pagina = 0;
    _cargar();
  }

  Future<void> _importar() async {
    final resultado = await showWmsDialog<Map<String, dynamic>>(
      context,
      (_) => const ImportarInventarioDialog(),
    );
    if (!mounted || resultado == null) return;
    _refrescar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['repetido'] == true
              ? 'La carga ya estaba registrada; no se duplicó.'
              : '${resultado['unidades']} unidades agregadas al inventario.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_repo != null) ref.watch(usuarioSesionProvider);
    final puedeTransferir = _permiso([RolCuenta.admin, RolCuenta.logistica]);
    return InventarioVista(
      datos: _datos,
      buscar: _buscar,
      pagina: _pagina,
      conectado: _repo != null,
      onRefrescar: _refrescar,
      filtrosActivos: _filtros.keys.toSet(),
      seleccionadas: _seleccion.keys.toSet(),
      clienteSeleccionado:
          _seleccion.isEmpty ? null : '${_seleccion.values.first['cliente']}',
      onSeleccionar:
          _permiso([RolCuenta.admin, RolCuenta.despacho]) && !_preparando
              ? _seleccionarFila
              : null,
      onDespacharSeleccion:
          _seleccion.isEmpty || _preparando ? null : _despacharSeleccion,
      onVaciarSeleccion: _preparando ? null : () => setState(_seleccion.clear),
      preparando: _preparando,
      onFiltro: _filtrar,
      onLimpiar:
          () => setState(() {
            _busquedaLimpiar();
          }),
      onTransferir: puedeTransferir ? () => _abrir(origenes: true) : null,
      onImportar: puedeTransferir ? _importar : null,
      onAbrir: (fila) => _abrir(grupo: fila),
      onDespachar:
          _permiso([RolCuenta.admin, RolCuenta.despacho])
              ? (fila) => _abrir(grupo: fila, despacho: true)
              : null,
      onPagina:
          (pagina) => setState(() {
            _pagina = pagina;
            _cargar();
          }),
      onBuscar: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _pagina = 0;
              _cargar();
            });
          }
        });
      },
    );
  }
}

class _ErrorInventario extends StatelessWidget {
  const _ErrorInventario(this.error, this.reintentar);
  final Object? error;
  final VoidCallback reintentar;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'No se pudo cargar inventario.\n$error',
          textAlign: TextAlign.center,
        ),
        TextButton(onPressed: reintentar, child: const Text('Reintentar')),
      ],
    ),
  );
}

/// Selector de existencias ya recibidas, reutilizado desde Recepción.
class TransferirInventarioTab extends ConsumerWidget {
  const TransferirInventarioTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(inventarioRepositoryProvider);
    final sesion = ref.watch(usuarioSesionProvider).value;
    if (repo == null) {
      return const Center(
        child: Text('Inventario no está disponible en esta conexión.'),
      );
    }
    if (sesion?.tieneRol(RolCuenta.admin) != true &&
        sesion?.tieneRol(RolCuenta.logistica) != true) {
      return const Center(
        child: Text('Solo Bodega y Administración pueden transferir prendas.'),
      );
    }
    return _DetalleInventario(
      repo: repo,
      origenes: true,
      puedeTransferir: true,
      puedeEmpacar: false,
      integrado: true,
      onTransferencia: () async => ref.read(wmsRepositoryProvider).refrescar(),
    );
  }
}

class _DetalleInventario extends StatefulWidget {
  const _DetalleInventario({
    required this.repo,
    this.grupo,
    required this.origenes,
    this.despacho = false,
    this.puedeEliminar = false,
    this.integrado = false,
    this.onTransferencia,
    required this.puedeTransferir,
    required this.puedeEmpacar,
  });
  final InventarioRepository repo;
  final InventarioFila? grupo;
  final bool origenes, puedeTransferir, puedeEmpacar, despacho, integrado;
  final bool puedeEliminar;
  final Future<void> Function()? onTransferencia;
  @override
  State<_DetalleInventario> createState() => _DetalleInventarioState();
}

class _DetalleInventarioState extends State<_DetalleInventario> {
  String? _aviso;
  bool _historial = false;
  final _buscar = TextEditingController();
  late Future<List<InventarioFila>> _datos;
  int _pagina = 0;
  Timer? _busqueda;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  void _buscarAhora() {
    _busqueda?.cancel();
    setState(() {
      _pagina = 0;
      _cargar();
    });
  }

  void _cargar() {
    _datos = widget.repo.filas(
      widget.origenes ? 'inventario_origenes' : 'inventario_detalle_talla',
      {
        if (widget.origenes) 'p_buscar': _buscar.text.trim(),
        if (!widget.origenes) ...{
          'p_cliente': widget.grupo!['cliente'],
          'p_ficha': widget.grupo!['ficha'],
          'p_talla': widget.grupo!['talla'],
        },
        'p_pagina': _pagina,
      },
    );
  }

  Future<void> _operar(String modo, InventarioFila fila) async {
    if (modo == 'empacar') {
      Navigator.pop(context, fila);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) =>
              _OperacionInventario(repo: widget.repo, modo: modo, fila: fila),
    );
    if (mounted && ok == true) {
      setState(() {
        _aviso = switch (modo) {
          'transferir' => 'Transferencia registrada en inventario.',
          'eliminar_excel' =>
            'Entrada Excel eliminada del stock. Auditoría conservada.',
          'revertir' =>
            'Cantidad devuelta a la OP, talla y estante originales.',
          'empacar' => 'LE reservada. Confirma su salida desde Seguimiento.',
          _ => 'Reserva liberada. Las prendas vuelven a inventario libre.',
        };
        _cargar();
      });
      try {
        await widget.onTransferencia?.call();
      } catch (_) {
        if (mounted) {
          setState(
            () =>
                _aviso =
                    'Transferencia guardada. Actualiza Bodega para consultar el nuevo saldo.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.origenes) {
      return InventarioExistencias(
        grupo: widget.grupo!,
        datos: _datos,
        pagina: _pagina,
        aviso: _aviso,
        puedeEliminar: widget.puedeEliminar,
        puedeTransferir: widget.puedeTransferir,
        puedeEmpacar: widget.puedeEmpacar,
        onOperar: _operar,
        onRecargar: () => setState(_cargar),
        onPagina:
            (p) => setState(() {
              _pagina = p;
              _cargar();
            }),
      );
    }
    final contenido = SizedBox(
      width: 1000,
      height: widget.integrado ? null : 650,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.origenes
                        ? 'Prendas disponibles en bodega'
                        : '${widget.despacho ? 'Seleccionar prenda · ' : ''}${widget.grupo!['ficha']} · Talla ${widget.grupo!['talla'] ?? 'Sin talla'} · ${widget.grupo!['cliente']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!widget.integrado)
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (widget.origenes) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            !_historial
                                ? const Color(0xFFC8DB00)
                                : Colors.transparent,
                      ),
                      onPressed: () => setState(() => _historial = false),
                      child: const Text('Disponibles'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            _historial
                                ? const Color(0xFFC8DB00)
                                : Colors.transparent,
                      ),
                      onPressed: () => setState(() => _historial = true),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Historial'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_historial && widget.origenes)
              Expanded(child: InventarioHistorial(repo: widget.repo))
            else ...[
              if (widget.origenes)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Para transferir, la prenda debe tener ficha técnica, estante activo y saldo libre.',
                  ),
                ),
              if (widget.despacho)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '1. Selecciona la talla y el stock de origen    →    2. Continúa en Despacho: destino, prendas y empaques    →    3. Confirma la LE',
                  ),
                ),
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _aviso!,
                    style: const TextStyle(color: Colors.teal),
                  ),
                ),
              if (widget.origenes)
                TextField(
                  controller: _buscar,
                  onChanged: (_) {
                    _busqueda?.cancel();
                    _busqueda = Timer(const Duration(milliseconds: 350), () {
                      if (mounted) _buscarAhora();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar OP, ficha, producto o cliente',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _buscarAhora,
                    ),
                  ),
                  onSubmitted: (_) => _buscarAhora(),
                ),
              Expanded(
                child: FutureBuilder<List<InventarioFila>>(
                  future: _datos,
                  builder: (context, s) {
                    if (s.connectionState != ConnectionState.done) {
                      return const WmsLoadingPanel();
                    }
                    if (s.hasError) {
                      return _ErrorInventario(s.error, () => setState(_cargar));
                    }
                    final rows = s.data ?? [];
                    return Column(
                      children: [
                        Expanded(
                          child:
                              rows.isEmpty
                                  ? Center(
                                    child: Text(
                                      widget.origenes
                                          ? 'No hay existencias registradas por estante para esta búsqueda. Verifica la recepción y actualiza Bodega.'
                                          : 'No hay registros.',
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (_, i) {
                                      final r = rows[i];
                                      final ficha =
                                          '${r['ficha'] ?? ''}'.trim();
                                      final bloqueo =
                                          !widget.origenes
                                              ? null
                                              : ficha.isEmpty
                                              ? 'Falta ficha técnica: actualiza NOMBRE FICHA TECNICA desde el ERP.'
                                              : r['estante_activo'] == false
                                              ? 'El estante está inactivo.'
                                              : ((r['disponible'] as num?) ??
                                                      0) <=
                                                  0
                                              ? 'Sin saldo libre: las prendas están reservadas o asignadas a inventario.'
                                              : null;
                                      if (widget.origenes) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFE0E5E8),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    'OP ${r['numero_op']}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Chip(
                                                    label: Text(
                                                      'Talla ${r['talla']}',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFFDCEBFF),
                                                    side: BorderSide.none,
                                                  ),
                                                  Chip(
                                                    avatar: const Icon(
                                                      Icons.shelves,
                                                      size: 18,
                                                    ),
                                                    label: Text(
                                                      '${r['ubicacion']}',
                                                    ),
                                                    side: BorderSide.none,
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${r['producto']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                '${r['cliente']}',
                                                style: const TextStyle(
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Wrap(
                                                spacing: 10,
                                                runSpacing: 8,
                                                children: [
                                                  for (final dato in [
                                                    (
                                                      'Ficha',
                                                      ficha.isEmpty
                                                          ? 'Sin ficha técnica'
                                                          : ficha,
                                                    ),
                                                    (
                                                      'Disponibles',
                                                      '${r['disponible']} uds',
                                                    ),
                                                    (
                                                      'En estante',
                                                      '${r['en_bodega'] ?? '—'} uds',
                                                    ),
                                                  ])
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF7F9FA,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            dato.$1,
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .blueGrey,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            dato.$2,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (bloqueo != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 10,
                                                      ),
                                                  child: Text(
                                                    bloqueo,
                                                    style: const TextStyle(
                                                      color: Color(0xFF986000),
                                                    ),
                                                  ),
                                                ),
                                              if (widget.puedeTransferir)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 14,
                                                      ),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: FilledButton.icon(
                                                      style:
                                                          FilledButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFFC8DB00,
                                                                ),
                                                            foregroundColor:
                                                                const Color(
                                                                  0xFF0B2C3C,
                                                                ),
                                                          ),
                                                      onPressed:
                                                          bloqueo == null
                                                              ? () => _operar(
                                                                'transferir',
                                                                r,
                                                              )
                                                              : null,
                                                      icon: const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Enviar a inventario',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }
                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r['entrada_excel'] == true ? 'Entrada por Excel' : 'OP ${r['numero_op']}'} · ${r['producto']} · Talla ${r['talla']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${r['cliente']} · ${r['ubicacion']}',
                                              ),
                                              if (widget.origenes)
                                                Text(
                                                  'Ficha ${ficha.isEmpty ? 'Sin ficha técnica' : ficha} · Disponibles: ${r['disponible']}',
                                                )
                                              else ...[
                                                Text(
                                                  'Transferidas: ${r['cantidad']} · Libres: ${r['libre']} · Reservadas: ${r['reservado']} · Despachadas: ${r['despachado']} · Revertidas: ${r['revertido']}',
                                                ),
                                                Text(
                                                  '${r['fecha']} · ${r['motivo']}',
                                                ),
                                                for (final v
                                                    in r['reversiones']
                                                            as List? ??
                                                        [])
                                                  Text(
                                                    'Reversión: ${v['cantidad']} · ${v['motivo']} · ${v['fecha']}',
                                                  ),
                                              ],
                                              if (widget.origenes &&
                                                  r['en_bodega'] != null)
                                                Text(
                                                  'Existencias en estante: ${r['en_bodega']}',
                                                ),
                                              if (bloqueo != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  child: Text(
                                                    bloqueo,
                                                    style: const TextStyle(
                                                      color: Color(0xff9e6400),
                                                    ),
                                                  ),
                                                ),
                                              Wrap(
                                                spacing: 8,
                                                children: [
                                                  if (widget.origenes &&
                                                      widget.puedeTransferir)
                                                    TextButton(
                                                      onPressed:
                                                          bloqueo != null
                                                              ? null
                                                              : () => _operar(
                                                                'transferir',
                                                                r,
                                                              ),
                                                      child: const Text(
                                                        'Enviar a inventario',
                                                      ),
                                                    ),
                                                  if (!widget.origenes &&
                                                      r['entrada_excel'] ==
                                                          true &&
                                                      widget.puedeEliminar)
                                                    TextButton.icon(
                                                      onPressed:
                                                          (r['reservado']
                                                                          as num) ==
                                                                      0 &&
                                                                  (r['despachado']
                                                                          as num) ==
                                                                      0
                                                              ? () => _operar(
                                                                'eliminar_excel',
                                                                r,
                                                              )
                                                              : null,
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                      ),
                                                      label: const Text(
                                                        'Eliminar entrada Excel',
                                                      ),
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.red,
                                                          ),
                                                    ),
                                                  if (!widget.origenes &&
                                                      r['entrada_excel'] !=
                                                          true &&
                                                      (r['libre'] as num) > 0 &&
                                                      widget.puedeTransferir)
                                                    TextButton(
                                                      onPressed:
                                                          () => _operar(
                                                            'revertir',
                                                            r,
                                                          ),
                                                      child: const Text(
                                                        'Devolver a OP original',
                                                      ),
                                                    ),
                                                  if (!widget.origenes &&
                                                      (r['libre'] as num) > 0 &&
                                                      widget.puedeEmpacar)
                                                    FilledButton(
                                                      onPressed:
                                                          () => _operar(
                                                            'empacar',
                                                            r,
                                                          ),
                                                      child: const Text(
                                                        'Seleccionar para despacho',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              for (final d
                                                  in r['despachos'] as List? ??
                                                      [])
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'LE ${d['le'] ?? '—'} · OC ${d['oc']} · ${d['cantidad']} uds · ${d['fase']}',
                                                      ),
                                                    ),
                                                    if (d['fase'] ==
                                                            'empacado' &&
                                                        widget.puedeEmpacar)
                                                      TextButton(
                                                        onPressed:
                                                            () => _operar(
                                                              'cancelar',
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >.from(d),
                                                            ),
                                                        child: const Text(
                                                          'Liberar reserva',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Página ${_pagina + 1}'),
                            IconButton(
                              onPressed:
                                  _pagina == 0
                                      ? null
                                      : () => setState(() {
                                        _pagina--;
                                        _cargar();
                                      }),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed:
                                  rows.length < 50
                                      ? null
                                      : () => setState(() {
                                        _pagina++;
                                        _cargar();
                                      }),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return widget.integrado ? contenido : Dialog(child: contenido);
  }
}

class _OperacionInventario extends StatefulWidget {
  const _OperacionInventario({
    required this.repo,
    required this.modo,
    required this.fila,
  });
  final InventarioRepository repo;
  final String modo;
  final InventarioFila fila;
  @override
  State<_OperacionInventario> createState() => _OperacionInventarioState();
}

class _OperacionInventarioState extends State<_OperacionInventario> {
  final _cantidad = TextEditingController(),
      _motivo = TextEditingController(),
      _oc = TextEditingController(),
      _peso = TextEditingController();
  final _solicitud = nuevaSolicitudDespacho();
  bool _guardando = false;
  String? _error, _destino, _empaque;
  String _estanteDestino = '';
  List<InventarioFila> _destinos = [], _empaques = [];
  bool _cargando = false;
  @override
  void initState() {
    super.initState();
    if (widget.modo == 'empacar') _catalogos();
    if (widget.modo == 'transferir') {
      _cantidad.text = '1';
      _estanteDestino = '${widget.fila['ubicacion'] ?? ''}';
    }
  }

  Future<void> _catalogos() async {
    setState(() => _cargando = true);
    try {
      final r = await Future.wait([
        widget.repo.filas('destinatarios_para_empaque', {}),
        widget.repo.filas('empaques_listar', {'p_todos': false}),
      ]);
      if (mounted) {
        setState(() {
          _destinos = r[0];
          _empaques = r[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_cantidad, _motivo, _oc, _peso]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final r = widget.fila, modo = widget.modo;
    try {
      final n = int.tryParse(_cantidad.text);
      if (modo != 'cancelar' &&
          modo != 'eliminar_excel' &&
          (n == null ||
              n <= 0 ||
              n > (r[modo == 'transferir' ? 'disponible' : 'libre'] as num))) {
        throw const FormatException(
          'Indica una cantidad positiva dentro del saldo disponible.',
        );
      }
      if (modo != 'empacar' && _motivo.text.trim().isEmpty) {
        throw const FormatException(
          'Indica el motivo para conservar la trazabilidad.',
        );
      }
      final p = <String, dynamic>{'p_solicitud': _solicitud};
      if (modo == 'transferir') {
        if (_estanteDestino.isEmpty) {
          throw const FormatException('Selecciona el estante de destino.');
        }
        p.addAll({
          'p_item': r['item_id'],
          'p_ubicacion': r['ubicacion_id'],
          'p_estante_destino': _estanteDestino,
          'p_cantidad': n,
          'p_motivo': _motivo.text.trim(),
        });
      }
      if (modo == 'eliminar_excel') {
        p.addAll({'p_transferencia': r['id'], 'p_motivo': _motivo.text.trim()});
      }
      if (modo == 'revertir') {
        p.addAll({
          'p_transferencia': r['id'],
          'p_cantidad': n,
          'p_motivo': _motivo.text.trim(),
        });
      }
      if (modo == 'cancelar') {
        p.clear();
        p.addAll({'p_despacho': r['id'], 'p_motivo': _motivo.text.trim()});
      }
      if (modo == 'empacar') {
        if (_oc.text.trim().isEmpty || _destino == null || _empaque == null) {
          throw const FormatException('Completa OC, destinatario y empaque.');
        }
        final d = _destinos.firstWhere((e) => e['id'] == _destino),
            e = _empaques.firstWhere((e) => e['id'] == _empaque);
        p.addAll({
          'p_transferencia': r['id'],
          'p_cantidad': n,
          'p_oc': _oc.text.trim(),
          'p_destinatario': _destino,
          'p_destinatario_version': d['version'],
          'p_empaque': _empaque,
          'p_empaque_version': e['version'],
          'p_peso': validarPesoBruto(_peso.text, e['peso_neto_kg'] as num),
        });
      }
      setState(() {
        _guardando = true;
        _error = null;
      });
      await widget.repo.ejecutar(
        modo == 'transferir'
            ? 'inventario_transferir_estante'
            : 'inventario_$modo',
        p,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: Text(switch (widget.modo) {
        'transferir' => 'Enviar a inventario',
        'revertir' => 'Devolver a la OP original',
        'eliminar_excel' => 'Eliminar entrada Excel',
        'empacar' => 'Reservar inventario para despacho',
        _ => 'Liberar reserva',
      }),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.modo == 'transferir') ...[
                Text(
                  'OP ${widget.fila['numero_op']} · ${widget.fila['producto']} · Talla ${widget.fila['talla']}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('${widget.fila['ubicacion']}')),
                    Chip(
                      label: Text('${widget.fila['disponible']} disponibles'),
                      backgroundColor: const Color(0xFFDDF1DF),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (widget.modo == 'transferir') ...[
                IgnorePointer(
                  ignoring: _guardando,
                  child: CatalogoUbicacionDropdown(
                    label: 'Estante de destino',
                    value: _estanteDestino,
                    onChanged: (v) => setState(() => _estanteDestino = v),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.modo == 'eliminar_excel')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Se retirarán ${widget.fila['libre']} unidades de ${widget.fila['producto']} · Talla ${widget.fila['talla']} · ${widget.fila['ubicacion']}. Esta entrada dejará de aparecer en inventario. Se conservará la auditoría de la eliminación.',
                  ),
                ),
              if (widget.modo != 'cancelar' && widget.modo != 'eliminar_excel')
                TextField(
                  controller: _cantidad,
                  enabled: !_guardando,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: IconButton(
                      tooltip: 'Reducir cantidad',
                      onPressed:
                          _guardando
                              ? null
                              : () {
                                final n = int.tryParse(_cantidad.text) ?? 1;
                                _cantidad.text = (n > 1 ? n - 1 : 1).toString();
                              },
                      icon: const Icon(Icons.remove),
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Aumentar cantidad',
                      onPressed:
                          _guardando
                              ? null
                              : () {
                                final maximo =
                                    (widget.fila[widget.modo == 'transferir'
                                                ? 'disponible'
                                                : 'libre']
                                            as num?)
                                        ?.toInt() ??
                                    0;
                                _cantidad.text =
                                    ((int.tryParse(_cantidad.text) ?? 0) + 1)
                                        .clamp(0, maximo)
                                        .toString();
                              },
                      icon: const Icon(Icons.add),
                    ),
                    helperText:
                        'Máximo ${widget.fila[widget.modo == 'transferir' ? 'disponible' : 'libre']} unidades',
                  ),
                ),
              if (widget.modo != 'empacar')
                TextField(
                  controller: _motivo,
                  enabled: !_guardando,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo obligatorio',
                    hintText:
                        'Ej.: reservar prendas para futuras OC del cliente',
                  ),
                ),
              if (widget.modo == 'empacar') ...[
                Text(
                  'Cliente: ${widget.fila['cliente']}\nSe crea una LE reservada. Confirma su salida desde Seguimiento.',
                ),
                TextField(
                  controller: _oc,
                  enabled: !_guardando,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'OC de destino'),
                ),
                if (_cargando)
                  const WmsLoadingStrip(label: 'Cargando destinatarios…'),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _destino,
                  decoration: const InputDecoration(labelText: 'Destinatario'),
                  items: [
                    for (final d in _destinos)
                      DropdownMenuItem(
                        value: '${d['id']}',
                        child: Text(
                          '${(d['datos'] as Map?)?['nombre'] ?? d['nombre'] ?? d['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      _guardando ? null : (v) => setState(() => _destino = v),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _empaque,
                  decoration: const InputDecoration(
                    labelText: 'Una caja o paquete',
                  ),
                  items: [
                    for (final e in _empaques)
                      DropdownMenuItem(
                        value: '${e['id']}',
                        child: Text(
                          descripcionEmpaque(e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      _guardando ? null : (v) => setState(() => _empaque = v),
                ),
                TextField(
                  controller: _peso,
                  enabled: !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso bruto real (kg)',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando || _cargando ? null : _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B2C3C),
            foregroundColor: Colors.white,
          ),
          child:
              _guardando
                  ? const WmsLoader(width: 40)
                  : Text(
                    widget.modo == 'eliminar_excel'
                        ? 'Confirmar eliminación'
                        : widget.modo == 'transferir'
                        ? 'Confirmar envío'
                        : 'Confirmar',
                  ),
        ),
      ],
    ),
  );
}
