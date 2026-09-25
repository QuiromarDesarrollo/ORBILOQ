import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const NoConformeDialog());

class NoConformeDialog extends StatelessWidget {
  const NoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTO NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.qr_code_scanner, size: 16), text: 'ESCANEAR QR'),
                Tab(height: 38, icon: Icon(Icons.edit_note, size: 16), text: 'BÚSQUEDA MANUAL'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EscanearTab(), _ManualTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una tarjeta = un producto que se va a reportar como no conforme, con su
/// propia cantidad, causal y nota. Independiente de cualquier lote.
class _TarjetaNoConforme {
  _TarjetaNoConforme({required this.itemId})
      : cantidadCtrl = TextEditingController(text: '1'),
        notaCtrl = TextEditingController();

  final String itemId;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  int conteo = 1;
  String? causalId;
  String? recibidoDeProduccion;
  bool enviando = false;
  bool enviada = false;

  void dispose() {
    cantidadCtrl.dispose();
    notaCtrl.dispose();
  }
}

Future<void> _reportarTodo({
  required WidgetRef ref,
  required List<_TarjetaNoConforme> pendientes,
  required String operario,
  required void Function(void Function()) setStateFn,
  required bool Function() estaMontado,
  required void Function(FeedbackMessage?) setMensaje,
}) async {
  for (final t in pendientes) {
    if (t.causalId == null) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin causal seleccionada.'));
      return;
    }
    if (t.recibidoDeProduccion == null || t.recibidoDeProduccion!.trim().isEmpty) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin indicar quién de Producción entregó la prenda.'));
      return;
    }
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta con cantidad inválida.'));
      return;
    }
  }

  setStateFn(() {
    setMensaje(null);
    for (final t in pendientes) {
      t.enviando = true;
    }
  });

  var okCount = 0;
  String? primerError;
  for (final t in pendientes) {
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    final res = await ref.read(wmsRepositoryProvider).registrarNoConforme(
          itemId: t.itemId,
          cantidad: cantidad,
          causalId: t.causalId!,
          operario: operario,
          recibidoDeProduccion: t.recibidoDeProduccion!.trim(),
          nota: t.notaCtrl.text,
        );
    if (!estaMontado()) return;
    switch (res) {
      case Ok():
        okCount++;
        setStateFn(() {
          t.enviando = false;
          t.enviada = true;
        });
      case Err(:final message):
        primerError ??= message;
        setStateFn(() => t.enviando = false);
    }
  }

  setStateFn(() {
    if (primerError != null) {
      setMensaje(FeedbackMessage.error(
        okCount == 0 ? primerError : '$okCount reportado(s) — falló al menos uno: $primerError',
      ));
    } else {
      setMensaje(FeedbackMessage.ok('$okCount producto(s) reportado(s) como no conforme.'));
    }
  });
}

class _CausalDropdown extends ConsumerWidget {
  const _CausalDropdown({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudieron cargar las causales: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) => DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: wmsInput('Causal de la no conformidad', icon: Icons.report_problem_outlined),
        items: [for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================ pestaña 1: QR

class _EscanearTab extends ConsumerStatefulWidget {
  const _EscanearTab();

  @override
  ConsumerState<_EscanearTab> createState() => _EscanearTabState();
}

class _EscanearTabState extends ConsumerState<_EscanearTab> with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _qrFocus = FocusNode();
  String _operario = WmsConstantes.operarios.first;
  final List<_TarjetaNoConforme> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        existente.conteo++;
        existente.cantidadCtrl.text = '${existente.conteo}';
      } else {
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE LA PRENDA NO CONFORME', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (_tarjetas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escanea una prenda para reportarla como no conforme.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== pestaña 2: manual

class _ManualTab extends ConsumerStatefulWidget {
  const _ManualTab();

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab> with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String _operario = WmsConstantes.operarios.first;
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaNoConforme> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _opCtrl.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _buscar() {
    final op = _opCtrl.text.trim();
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionados.clear();
      if (op.isEmpty) {
        _resultados = [];
        _errorBusqueda = 'Escribe un número de OP.';
        return;
      }
      // Solo tiene sentido reportar productos que ya fueron entregados por Producción.
      _resultados = kardex.where((k) => k.item.op == op && k.producido > 0).toList();
      _errorBusqueda = _resultados.isEmpty
          ? 'No se encontraron tallas con unidades entregadas por Producción para la OP $op.'
          : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  keyboardType: TextInputType.number,
                  decoration: wmsInput('Número de OP', icon: Icons.tag),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 10),
              ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscar),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 10),
            FeedbackBanner(message: FeedbackMessage.error(_errorBusqueda!)),
          ],
          if (_resultados.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (final r in _resultados)
                    CheckboxListTile(
                      dense: true,
                      value: _seleccionados.contains(r.id),
                      activeColor: AppColors.alertRed,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _seleccionados.add(r.id);
                        } else {
                          _seleccionados.remove(r.id);
                        }
                      }),
                      title: Text(
                        '${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Entregadas por Producción: ${r.producido} Uds'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                icon: Icons.playlist_add,
                label: 'AGREGAR SELECCIONADAS (${_seleccionados.length})',
                color: AppColors.primaryNavy,
                onPressed: _seleccionados.isEmpty ? null : _agregarSeleccionadas,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_tarjetas.isEmpty && _resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escribe una OP y busca para ver sus tallas entregadas.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== tarjeta (compartida)

class _TarjetaWidget extends StatefulWidget {
  const _TarjetaWidget({required this.tarjeta, required this.kardex, required this.onQuitar});

  final _TarjetaNoConforme tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onQuitar;

  @override
  State<_TarjetaWidget> createState() => _TarjetaWidgetState();
}

class _TarjetaWidgetState extends State<_TarjetaWidget> {
  @override
  Widget build(BuildContext context) {
    final k = widget.kardex;
    final t = widget.tarjeta;
    if (k == null) return const SizedBox.shrink();
    final enviada = t.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: enviada ? Colors.grey.shade600 : AppColors.primaryNavy,
                        ),
                      ),
                      Text('OP: ${k.item.op} | Entregadas por Producción: ${k.producido} Uds',
                          style: TextStyle(color: enviada ? Colors.grey.shade600 : null)),
                    ],
                  ),
                ),
                if (enviada)
                  const Icon(Icons.check_circle, color: AppColors.actionGreen)
                else if (t.enviando)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: widget.onQuitar,
                  ),
              ],
            ),
            const Divider(),
            if (!enviada) ...[
              MetricWrap(children: [
                MetricCard(
                  title: 'ENTREGADAS',
                  value: '${k.producido} Uds',
                  color: AppColors.actionGreen,
                  icon: Icons.check_circle,
                ),
                MetricCard(
                  title: 'NO CONFORME ACTUAL',
                  value: '${k.pendienteReproceso} Uds',
                  color: k.pendienteReproceso > 0 ? AppColors.alertRed : Colors.grey,
                  icon: Icons.report_problem_outlined,
                ),
              ]),
              const SizedBox(height: 12),
              _CausalDropdown(
                valor: t.causalId,
                onChanged: (v) => setState(() => t.causalId = v),
              ),
              const SizedBox(height: 10),
              AddablePersonDropdown(
                label: 'Quién de Producción entregó la prenda',
                valor: t.recibidoDeProduccion,
                onChanged: (v) => setState(() => t.recibidoDeProduccion = v),
                itemsProvider: personalProduccionProvider,
                onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalProduccion(nombre),
                tituloDialogo: 'Agregar persona de Producción',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: t.cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad no conforme (máx ${k.producido} Uds)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: t.notaCtrl,
                      decoration: wmsInput('Nota (opcional)', icon: Icons.note_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 3: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Devolucion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarDevoluciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Devolucion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final devoluciones = snapshot.data ?? const [];
        if (devoluciones.isEmpty) {
          return const Center(
            child: Text('Aún no hay productos no conformes reportados.', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          itemCount: devoluciones.length,
          itemBuilder: (_, i) {
            final d = devoluciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.alertRed,
                  child: Icon(Icons.report_problem_outlined, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${d.item.codigo} (${d.item.talla}) — ${d.cantidad} Uds — ${d.causal}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${d.item.op} | Reportado por: ${d.operario}'
                  '${d.recibidoDeProduccion.isNotEmpty ? ' | Recibido de Producción: ${d.recibidoDeProduccion}' : ''}'
                  ' | ${formatFechaHora(d.fecha)}'
                  '${d.nota.isNotEmpty ? ' | ${d.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
