import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/operario_actual.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../shared/widgets/responsive_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showAliadosNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const AliadosNoConformeDialog());

class AliadosNoConformeDialog extends StatefulWidget {
  const AliadosNoConformeDialog({super.key});

  @override
  State<AliadosNoConformeDialog> createState() => _AliadosDialogState();
}

class _AliadosDialogState extends State<AliadosNoConformeDialog> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'Productos no conforme de aliados',
      subtitle: 'Control de devoluciones y liberaciones',
      compactHeader: true,
      canClose: !_busy,
      icon: Icons.handshake_outlined,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1080,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            IgnorePointer(
              ignoring: _busy,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.petroleo,
                unselectedLabelColor: AppColors.slate600,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: AppColors.lima, width: 3),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: 'Enviar a aliado'),
                  Tab(child: _PendientesLabel()),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _EnviarTab(),
                  _PendientesTab(
                    onBusyChanged: (value) {
                      if (mounted) setState(() => _busy = value);
                    },
                  ),
                  const _HistorialTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendientesLabel extends ConsumerWidget {
  const _PendientesLabel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cantidad =
        ref
            .watch(noConformesAliadosProvider)
            .valueOrNull
            ?.where((a) => a.pendiente)
            .length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Pendientes'),
        if (cantidad != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lima,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                color: AppColors.petroleo,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CausalDropdownAliados extends ConsumerWidget {
  const _CausalDropdownAliados({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const WmsLoadingStrip(),
      error:
          (e, _) => Text(
            'No se pudieron cargar las causales: $e',
            style: const TextStyle(color: AppColors.alertRed),
          ),
      data: (lista) {
        final valida = lista.any((c) => c.id == valor);
        if (valor != null && !valida) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) onChanged(null);
          });
        }
        return DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey('${lista.map((c) => c.id).join('|')}::$valor'),
          initialValue: valida ? valor : null,
          decoration: wmsInput(
            'Causal de la no conformidad',
            icon: Icons.report_problem_outlined,
          ),
          items: [
            for (final c in lista)
              DropdownMenuItem(value: c.id, child: Text(c.nombre)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ================================================================ pestaña 1: enviar

class _EnviarTab extends ConsumerStatefulWidget {
  const _EnviarTab();

  @override
  ConsumerState<_EnviarTab> createState() => _EnviarTabState();
}

class _EnviarTabState extends ConsumerState<_EnviarTab> {
  final _opCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  List<ItemKardex> _resultados = [];
  String? _errorBusqueda;
  ItemKardex? _seleccionado;
  String? _causalId;
  String? _personaAliado;
  String get _operario => ref.read(nombreOperarioProvider);
  bool _enviando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _opCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  /// Reconoce si lo que se escribió/escaneó es un QR de prenda o un número
  /// de OP simple — misma lógica que ya usa Recepción.
  void _procesarEntrada(String raw) {
    final texto = raw.trim();
    final kardex =
        ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionado = null;
      if (texto.isEmpty) {
        _errorBusqueda = 'Escanea una prenda o escribe un número de OP.';
        _resultados = [];
        return;
      }

      final qr = QrPrenda.tryParse(texto);
      if (qr != null) {
        final encontrado =
            kardex
                .where((k) => k.item.op == qr.op && k.item.codigo == qr.codigo)
                .toList();
        if (encontrado.isEmpty) {
          _errorBusqueda = 'No se encontró esa prenda.';
          _resultados = [];
          return;
        }
        _resultados = encontrado;
        _errorBusqueda = null;
        _seleccionado = encontrado.first;
        return;
      }

      // No es un QR: se interpreta como número de OP. Esto es 100%
      // informativo — no depende de lo entregado ni de ningún otro número
      // del inventario, así que se puede reportar sobre cualquier OP/talla.
      _resultados = kardex.where((k) => k.item.op == texto).toList();
      _errorBusqueda =
          _resultados.isEmpty
              ? 'No se encontraron tallas para la OP $texto.'
              : null;
    });
  }

  Future<void> _enviar() async {
    final k = _seleccionado;
    if (k == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (_causalId == null) {
      setState(
        () => _msg = const FeedbackMessage.error('Selecciona una causal.'),
      );
      return;
    }
    if (_personaAliado == null || _personaAliado!.trim().isEmpty) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Selecciona a quién de Aliados se le entrega la prenda.',
            ),
      );
      return;
    }
    if (cantidad == null || cantidad <= 0) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Ingresa una cantidad mayor a 0.',
            ),
      );
      return;
    }

    setState(() {
      _enviando = true;
      _msg = null;
    });
    final res = await ref
        .read(wmsRepositoryProvider)
        .enviarNoConformeAliado(
          itemId: k.id,
          cantidad: cantidad,
          causalId: _causalId!,
          operario: _operario,
          personaAliadoEntrega: _personaAliado!,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok(
            '${cantidad}u de ${k.item.descripcion} (${k.item.talla}) enviadas a $_personaAliado.',
          );
          _seleccionado = null;
          _causalId = null;
          _personaAliado = null;
          _cantidadCtrl.clear();
          _notaCtrl.clear();
          _resultados = [];
          _opCtrl.clear();
          ref.invalidate(noConformesAliadosProvider);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          OperarioActual(label: 'Enviado por (Producción)'),
          const SizedBox(height: 10),
          ResponsiveRow(
            children: [
              Expanded(
                child: WmsScanField(
                  permiteManual: true,
                  controller: _opCtrl,
                  autofocus: true,
                  decoration: wmsInput(
                    'Escanear prenda o buscar por OP',
                    icon: Icons.qr_code_scanner,
                  ),
                  onSubmitted: (v) => _procesarEntrada(v),
                  enabled: !_enviando,
                  onCameraSubmitted: (raw) {
                    _procesarEntrada(raw);
                    return _errorBusqueda != null
                        ? FeedbackMessage.error(_errorBusqueda!)
                        : FeedbackMessage.ok(
                          'OP ${_resultados.first.item.op} · Prenda localizada. Completa el formulario para enviarla al aliado.',
                        );
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _procesarEntrada(_opCtrl.text),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('BUSCAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 8),
            AvisoFormulario(_errorBusqueda!),
          ],
          if (_resultados.isNotEmpty && _seleccionado == null) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final r in _resultados)
                    ListTile(
                      onTap: () => setState(() => _seleccionado = r),
                      leading: const Icon(
                        Icons.checkroom,
                        color: AppColors.primaryNavy,
                      ),
                      title: Text(
                        '${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('OP: ${r.item.op} | OC: ${r.item.oc}'),
                    ),
                ],
              ),
            ),
          ],
          if (_seleccionado != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveRow(
                      children: [
                        Expanded(
                          child: Text(
                            'OP: ${_seleccionado!.item.op} - ${_seleccionado!.item.descripcion} (${_seleccionado!.item.talla})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _seleccionado = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CausalDropdownAliados(
                      valor: _causalId,
                      onChanged: (v) => setState(() => _causalId = v),
                    ),
                    const SizedBox(height: 10),
                    AddablePersonDropdown(
                      label: 'A quién de Aliados se le entrega *',
                      valor: _personaAliado,
                      onChanged: (v) => setState(() => _personaAliado = v),
                      itemsProvider: personalAliadosProvider,
                      onAgregar:
                          (ref, nombre) => ref
                              .read(wmsRepositoryProvider)
                              .agregarPersonalAliado(nombre),
                      tituloDialogo: 'Agregar persona de Aliados',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a reportar'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notaCtrl,
                      decoration: wmsInput(
                        'Nota (opcional)',
                        icon: Icons.notes,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon:
                            _enviando
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: WmsLoader(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(
                                  Icons.outbox_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        label: const Text('ENVIAR A ALIADO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ pestaña 2: pendientes

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab({required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final _buscarCtrl = TextEditingController();
  String? _opFiltro;
  String? _seleccionId;
  final _detalleKey = GlobalKey();
  bool get _ocupado => _liberando.values.any((v) => v);
  final Map<String, String?> _personaMap = {};
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};

  /// Solicitudes que se acaban de completar EN ESTA SESIÓN — se siguen
  /// mostrando aquí, en verde y sin controles, hasta que se cierre y se
  /// vuelva a abrir el diálogo (ahí ya solo viven en Historial).
  final Set<String> _recienCompletadas = {};
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _buscarCtrl.dispose();
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(NoConformeAliado a) {
    return _cantidadCtrls.putIfAbsent(
      a.id,
      () => TextEditingController(text: '${a.cantidadPendiente}'),
    );
  }

  Future<void> _liberar(NoConformeAliado a) async {
    if (_ocupado) return;
    final persona = _personaMap[a.id];
    if (persona == null || persona.trim().isEmpty) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Selecciona quién de Aliados realizó la liberación.',
            ),
      );
      return;
    }
    final cantidad = int.tryParse(_ctrlPara(a).text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Ingresa una cantidad mayor a 0 para liberar.',
            ),
      );
      return;
    }
    if (cantidad > a.cantidadPendiente) {
      setState(
        () =>
            _msg = FeedbackMessage.error(
              'LÍMITE EXCEDIDO: solo quedan ${a.cantidadPendiente} Uds pendientes por liberar.',
            ),
      );
      return;
    }

    setState(() {
      _msg = null;
      _liberando[a.id] = true;
    });
    widget.onBusyChanged(true);
    Result<void> res;
    try {
      res = await ref
          .read(wmsRepositoryProvider)
          .liberarNoConformeAliado(
            id: a.id,
            cantidad: cantidad,
            operario: ref.read(nombreOperarioProvider),
            personaAliadoLibera: persona,
          );
    } catch (_) {
      res = const Err(
        'No se pudo confirmar la liberación. Revisa el historial antes de volver a intentarlo.',
      );
    }
    if (!mounted) return;
    setState(() {
      widget.onBusyChanged(false);
      _liberando[a.id] = false;
      switch (res) {
        case Ok():
          final quedan = a.cantidadPendiente - cantidad;
          _msg = FeedbackMessage.ok(
            quedan > 0
                ? '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — quedan $quedan Uds pendientes.'
                : '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — solicitud completada.',
          );
          if (quedan <= 0) _recienCompletadas.add(a.id);
          _personaMap.remove(a.id);
          // El proveedor puede conservar brevemente la fila anterior al refrescar.
          // Mantener el controlador evita recrearlo con el saldo anterior.
          _ctrlPara(a).text = '${quedan > 0 ? quedan : 0}';
          // noConformesAliadosProvider/liberacionesAliadosProvider son
          // FutureProvider normales — a diferencia del kardex principal, no
          // se refrescan solos; hay que pedírselo explícitamente o el
          // contador de "Faltan X Uds" se queda con el valor viejo.
          ref.invalidate(noConformesAliadosProvider);
          ref.invalidate(liberacionesAliadosProvider);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  Widget _pill(NoConformeAliado a) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: a.pendiente ? AppColors.amberChipBg : AppColors.greenChipBg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      a.pendiente ? 'Faltan ${a.cantidadPendiente} Uds' : 'COMPLETADO',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: a.pendiente ? AppColors.amberChip : AppColors.actionGreen,
      ),
    ),
  );
  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
  Widget _info(String title, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.petroleo,
          ),
        ),
      ],
    ),
  );
  Widget _detail(NoConformeAliado a) => Column(
    key: _detalleKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'OP ${a.item.op}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate600,
                  ),
                ),
                _pill(a),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${a.item.descripcion} · ${a.item.talla}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.petroleo,
              ),
            ),
            const SizedBox(height: 12),
            ResponsiveRow(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _info('Causal', a.causal)),
                const SizedBox(width: 8),
                Expanded(child: _info('Entregado a', a.personaAliadoEntrega)),
                const SizedBox(width: 8),
                Expanded(
                  child: _info(
                    'Enviado por',
                    '${a.usuarioSolicitud} · ${formatFechaHora(a.fechaSolicitud)}',
                  ),
                ),
              ],
            ),
            if (a.cantidadLiberada > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Liberado: ${a.cantidadLiberada} de ${a.cantidad} Uds',
                ),
              ),
            if (a.notaSolicitud.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Nota: ${a.notaSolicitud}'),
              ),
          ],
        ),
      ),
      if (a.pendiente) ...[
        const SizedBox(height: 14),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Liberar producto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.petroleo,
                ),
              ),
              const SizedBox(height: 14),
              AbsorbPointer(
                absorbing: _ocupado,
                child: ResponsiveRow(
                  children: [
                    Expanded(
                      child: OperarioActual(label: 'Liberado por (Producción)'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AddablePersonDropdown(
                        key: ValueKey(a.id),
                        label: 'Quién de Aliados liberó *',
                        valor: _personaMap[a.id],
                        onChanged: (v) {
                          if (mounted && !_ocupado) {
                            setState(() => _personaMap[a.id] = v);
                          }
                        },
                        itemsProvider: personalAliadosProvider,
                        onAgregar:
                            (ref, nombre) => ref
                                .read(wmsRepositoryProvider)
                                .agregarPersonalAliado(nombre),
                        tituloDialogo: 'Agregar persona de Aliados',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Cantidad a liberar (máx ${a.cantidadPendiente} Uds)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      key: ValueKey('aliados-cantidad-${a.id}'),
                      controller: _ctrlPara(a),
                      enabled: !_ocupado,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        prefixIcon: IconButton(
                          tooltip: 'Restar una unidad',
                          onPressed: _ocupado ? null : () => _ajustar(a, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Sumar una unidad',
                          onPressed: _ocupado ? null : () => _ajustar(a, 1),
                          icon: const Icon(Icons.add),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _ocupado ? null : () => _liberar(a),
                    icon:
                        _ocupado
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: WmsLoader(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_circle_outline),
                    label: Text(_ocupado ? 'Liberando…' : 'LIBERAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(146, 48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ],
  );
  void _ajustar(NoConformeAliado a, int delta) {
    final ctrl = _ctrlPara(a);
    setState(
      () =>
          ctrl.text =
              '${((int.tryParse(ctrl.text) ?? 0) + delta).clamp(1, a.cantidadPendiente)}',
    );
  }

  Widget _clear() => OutlinedButton(
    onPressed:
        _ocupado
            ? null
            : () => setState(() {
              _buscarCtrl.clear();
              _opFiltro = null;
            }),
    child: const Text('Limpiar'),
  );

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(noConformesAliadosProvider)
        .when(
          loading: () => const Center(child: WmsLoader()),
          error:
              (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: AppColors.alertRed),
                ),
              ),
          data: (lista) {
            final disponibles =
                lista
                    .where(
                      (a) => a.pendiente || _recienCompletadas.contains(a.id),
                    )
                    .toList();
            final ops =
                disponibles.map((a) => a.item.op).toSet().toList()..sort();
            final filtro = ops.contains(_opFiltro) ? _opFiltro : null;
            final query = _buscarCtrl.text.trim().toLowerCase().replaceFirst(
              RegExp(r'^op\s*'),
              '',
            );
            final visibles =
                disponibles
                    .where(
                      (a) =>
                          (filtro == null || a.item.op == filtro) &&
                          a.item.op.toLowerCase().contains(query),
                    )
                    .toList();
            final seleccion =
                visibles.where((a) => a.id == _seleccionId).firstOrNull ??
                visibles.firstOrNull;
            final grupos = <String, List<NoConformeAliado>>{};
            for (final a in visibles) {
              grupos.putIfAbsent(a.item.op, () => []).add(a);
            }
            final pending = visibles.where((a) => a.pendiente).toList();
            final search = TextField(
              key: const ValueKey('aliados-buscar-op'),
              controller: _buscarCtrl,
              enabled: !_ocupado,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por OP',
                labelText: 'Buscar por OP',
                border: OutlineInputBorder(),
              ),
            );
            final filter = DropdownButtonFormField<String>(
              key: ValueKey('aliados-filtro-op-$filtro'),
              itemHeight: null,
              selectedItemBuilder:
                  (context) => [
                    const Text('Todas las OP'),
                    for (final op in ops) Text('OP $op'),
                  ],
              initialValue: filtro ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_alt_outlined),
                labelText: 'Filtrar por OP',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todas las OP')),
                for (final op in ops)
                  DropdownMenuItem(
                    value: op,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OP $op',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${disponibles.firstWhere((a) => a.item.op == op).item.descripcion} · ${disponibles.where((a) => a.item.op == op && a.pendiente).length} pendientes',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              onChanged:
                  _ocupado
                      ? null
                      : (v) => setState(() => _opFiltro = v == '' ? null : v),
            );
            final cards = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      'OP ${group.key}  ${group.value.first.item.descripcion} · ${group.value.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.petroleo,
                      ),
                    ),
                  ),
                  for (final a in group.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color:
                            seleccion?.id == a.id
                                ? AppColors.slate50
                                : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color:
                                seleccion?.id == a.id
                                    ? AppColors.petroleo
                                    : AppColors.cardBorder,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('aliados-solicitud-${a.id}'),
                          onTap:
                              _ocupado
                                  ? null
                                  : () {
                                    setState(() => _seleccionId = a.id);
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      final detalle =
                                          _detalleKey.currentContext;
                                      if (mounted && detalle != null) {
                                        // Solo desplazar el panel vertical; los ancestros
                                        // incluyen el TabBarView horizontal del diálogo.
                                        Scrollable.of(
                                          detalle,
                                        ).position.ensureVisible(
                                          detalle.findRenderObject()!,
                                          alignment: 0,
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                    context,
                                                  )
                                                  ? Duration.zero
                                                  : const Duration(
                                                    milliseconds: 220,
                                                  ),
                                        );
                                      }
                                    });
                                  },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  width: 4,
                                  color:
                                      seleccion?.id == a.id
                                          ? AppColors.lima
                                          : Colors.transparent,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'T. ${a.item.talla}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.petroleo,
                                      ),
                                    ),
                                    _pill(a),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Causal: ${a.causal}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${a.personaAliadoEntrega} · enviado por ${a.usuarioSolicitud} · ${formatFechaHora(a.fechaSolicitud)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_msg != null) FeedbackBanner(message: _msg!),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: LayoutBuilder(
                    builder:
                        (context, c) =>
                            c.maxWidth >= 700
                                ? Row(
                                  children: [
                                    Expanded(flex: 3, child: search),
                                    const SizedBox(width: 10),
                                    Expanded(flex: 2, child: filter),
                                    const SizedBox(width: 10),
                                    _clear(),
                                  ],
                                )
                                : Column(
                                  children: [
                                    search,
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: filter),
                                        const SizedBox(width: 8),
                                        _clear(),
                                      ],
                                    ),
                                  ],
                                ),
                  ),
                ),
                Text(
                  '${pending.length} pendientes · ${pending.fold<int>(0, (n, a) => n + a.cantidadPendiente)} Uds por liberar',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.all(8),
                    child:
                        seleccion == null
                            ? Center(
                              child: Text(
                                disponibles.isEmpty
                                    ? 'No hay envíos a Aliados pendientes por liberar.'
                                    : 'No hay resultados para estos filtros.',
                              ),
                            )
                            : LayoutBuilder(
                              builder:
                                  (context, c) =>
                                      c.maxWidth >= 850
                                          ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: SingleChildScrollView(
                                                  child: cards,
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                flex: 3,
                                                child: SingleChildScrollView(
                                                  child: _detail(seleccion),
                                                ),
                                              ),
                                            ],
                                          )
                                          : SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                cards,
                                                const SizedBox(height: 12),
                                                _detail(seleccion),
                                              ],
                                            ),
                                          ),
                            ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

// ============================================================ pestaña 3: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(noConformesAliadosProvider);
    final liberaciones = ref.watch(liberacionesAliadosProvider);
    if (solicitudes.isLoading || liberaciones.isLoading) {
      return const Center(child: WmsLoader());
    }
    if (solicitudes.hasError || liberaciones.hasError) {
      return Center(
        child: Text('Error: ${solicitudes.error ?? liberaciones.error}'),
      );
    }
    return HistorialAgrupado(
      grupos: [
        for (final a in solicitudes.requireValue)
          GrupoHistorial(
            id: a.id,
            op: a.item.op,
            titulo:
                'OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
            detalle:
                'Código: ${a.item.codigo} | Solicitado: ${a.cantidad} Uds | Causal: ${a.causal} | ${a.pendiente ? 'PENDIENTE' : 'LIBERADO'}',
            eventos: [
              EventoHistorial(
                id: '${a.id}-solicitud',
                fecha: a.fechaSolicitud,
                titulo: 'Envío a Aliado · ${a.cantidad} Uds',
                cantidad: a.cantidad,
                categoriaCantidad: 'Prendas enviadas a aliados',
                detalle:
                    'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud}'
                    '${a.notaSolicitud.isEmpty ? '' : '\nNota: ${a.notaSolicitud}'}',
                color: Colors.blue,
              ),
              for (final e in liberaciones.requireValue.where(
                (e) => e.solicitudId == a.id,
              ))
                EventoHistorial(
                  id: e.id,
                  fecha: e.fecha,
                  cantidad: e.cantidad,
                  categoriaCantidad: 'Prendas liberadas por aliados',
                  titulo:
                      '${e.tipo == 'completa' ? 'ENTREGA COMPLETA' : 'ENTREGA PARCIAL'} · ${e.cantidad} Uds',
                  detalle:
                      '${e.operario} ← ${e.personaAliado}${e.nota.isEmpty ? '' : '\nNota: ${e.nota}'}',
                  color:
                      e.tipo == 'completa'
                          ? AppColors.actionGreen
                          : Colors.orange.shade700,
                ),
            ],
          ),
      ],
    );
  }
}
