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
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showAliadosNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const AliadosNoConformeDialog());

class AliadosNoConformeDialog extends StatelessWidget {
  const AliadosNoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME DE ALIADOS',
      icon: Icons.handshake_outlined,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
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
                Tab(height: 38, icon: Icon(Icons.outbox_outlined, size: 16), text: 'ENVIAR A ALIADO'),
                Tab(height: 38, icon: Icon(Icons.hourglass_top_outlined, size: 16), text: 'PENDIENTES'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EnviarTab(), _PendientesTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
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
  String _operario = WmsConstantes.operarios.first;
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
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionado = null;
      if (texto.isEmpty) {
        _errorBusqueda = 'Escanea una prenda o escribe un número de OP.';
        _resultados = [];
        return;
      }

      final qr = QrPrenda.tryParse(texto);
      if (qr != null) {
        final encontrado = kardex.where((k) => k.item.op == qr.op && k.item.codigo == qr.codigo).toList();
        if (encontrado.isEmpty || encontrado.first.producido <= 0) {
          _errorBusqueda = 'No se encontró esa prenda con unidades entregadas por Producción.';
          _resultados = [];
          return;
        }
        _resultados = encontrado;
        _errorBusqueda = null;
        _seleccionado = encontrado.first;
        return;
      }

      // No es un QR: se interpreta como número de OP.
      _resultados = kardex.where((k) => k.item.op == texto && k.producido > 0).toList();
      _errorBusqueda = _resultados.isEmpty ? 'No se encontraron tallas entregadas por Producción para la OP $texto.' : null;
    });
  }

  Future<void> _enviar() async {
    final k = _seleccionado;
    if (k == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (_causalId == null) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona una causal.'));
      return;
    }
    if (_personaAliado == null || _personaAliado!.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona a quién de Aliados se le entrega la prenda.'));
      return;
    }
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > k.producido) {
      setState(() => _msg = FeedbackMessage.error('LÍMITE EXCEDIDO: solo hay ${k.producido} Uds entregadas por Producción.'));
      return;
    }

    setState(() {
      _enviando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).enviarNoConformeAliado(
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
          _msg = FeedbackMessage.ok('${cantidad}u de ${k.item.descripcion} (${k.item.talla}) enviadas a $_personaAliado.');
          _seleccionado = null;
          _causalId = null;
          _personaAliado = null;
          _cantidadCtrl.clear();
          _notaCtrl.clear();
          _resultados = [];
          _opCtrl.clear();
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
          if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
          DropdownButtonFormField<String>(
            initialValue: _operario,
            decoration: wmsInput('Enviado por (Producción)', icon: Icons.person_outline),
            items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() => _operario = v ?? _operario),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  autofocus: true,
                  decoration: wmsInput('Escanear prenda o buscar por OP', icon: Icons.qr_code_scanner),
                  onSubmitted: (v) => _procesarEntrada(v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _procesarEntrada(_opCtrl.text),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('BUSCAR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 8),
            Text(_errorBusqueda!, style: const TextStyle(color: AppColors.alertRed)),
          ],
          if (_resultados.isNotEmpty && _seleccionado == null) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final r in _resultados)
                    ListTile(
                      onTap: () => setState(() => _seleccionado = r),
                      leading: const Icon(Icons.checkroom, color: AppColors.primaryNavy),
                      title: Text('${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Entregadas por Producción: ${r.producido} Uds'),
                    ),
                ],
              ),
            ),
          ],
          if (_seleccionado != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OP: ${_seleccionado!.item.op} - ${_seleccionado!.item.descripcion} (${_seleccionado!.item.talla})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _seleccionado = null)),
                      ],
                    ),
                    MetricWrap(children: [
                      MetricCard(
                        title: 'ENTREGADAS',
                        value: '${_seleccionado!.producido} Uds',
                        color: AppColors.actionGreen,
                        icon: Icons.check_circle,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _CausalDropdownAliados(valor: _causalId, onChanged: (v) => setState(() => _causalId = v)),
                    const SizedBox(height: 10),
                    AddablePersonDropdown(
                      label: 'A quién de Aliados se le entrega *',
                      valor: _personaAliado,
                      onChanged: (v) => setState(() => _personaAliado = v),
                      itemsProvider: personalAliadosProvider,
                      onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                      tituloDialogo: 'Agregar persona de Aliados',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a enviar (máx ${_seleccionado!.producido} Uds)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _notaCtrl, decoration: wmsInput('Nota (opcional)', icon: Icons.notes)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.outbox_outlined, color: Colors.white, size: 20),
                        label: const Text('ENVIAR A ALIADO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final Map<String, String?> _personaMap = {};
  final Map<String, String> _operarioMap = {};
  final Map<String, bool> _liberando = {};
  FeedbackMessage? _msg;

  Future<void> _liberar(NoConformeAliado a) async {
    final persona = _personaMap[a.id];
    if (persona == null || persona.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona quién de Aliados realizó la liberación.'));
      return;
    }
    setState(() {
      _msg = null;
      _liberando[a.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConformeAliado(
          id: a.id,
          operario: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
          personaAliadoLibera: persona,
        );
    if (!mounted) return;
    setState(() {
      _liberando[a.id] = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok('${a.cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas de Aliados.');
          _personaMap.remove(a.id);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(noConformesAliadosProvider);
    return todas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        final pendientes = lista.where((a) => a.pendiente).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
            Expanded(
              child: pendientes.isEmpty
                  ? const Center(child: Text('No hay envíos a Aliados pendientes por liberar.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: pendientes.length,
                      itemBuilder: (_, i) {
                        final a = pendientes[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: Colors.amber.shade50,
                            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.amber.shade700), borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                  Text('${a.cantidad} Uds | Causal: ${a.causal}', style: const TextStyle(fontSize: 12)),
                                  Text(
                                    'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud} | ${formatFechaHora(a.fechaSolicitud)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  const Divider(),
                                  DropdownButtonFormField<String>(
                                    initialValue: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
                                    decoration: wmsInput('Liberado por (Producción)', icon: Icons.person_outline),
                                    items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
                                    onChanged: (v) => setState(() => _operarioMap[a.id] = v ?? WmsConstantes.operarios.first),
                                  ),
                                  const SizedBox(height: 10),
                                  AddablePersonDropdown(
                                    label: 'Quién de Aliados liberó *',
                                    valor: _personaMap[a.id],
                                    onChanged: (v) => setState(() => _personaMap[a.id] = v),
                                    itemsProvider: personalAliadosProvider,
                                    onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                                    tituloDialogo: 'Agregar persona de Aliados',
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: (_liberando[a.id] ?? false) ? null : () => _liberar(a),
                                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      label: const Text('LIBERAR'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionGreen, foregroundColor: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
    final todas = ref.watch(noConformesAliadosProvider);
    return todas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(child: Text('Aún no hay solicitudes de Aliados.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: lista.length,
          itemBuilder: (_, i) {
            final a = lista[i];
            return Card(
              color: a.pendiente ? Colors.amber.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                        ),
                        StatusChip(
                          label: a.pendiente ? 'PENDIENTE' : 'LIBERADO',
                          color: a.pendiente ? Colors.amber.shade800 : AppColors.actionGreen,
                        ),
                      ],
                    ),
                    Text('${a.cantidad} Uds | Causal: ${a.causal}', style: const TextStyle(fontSize: 12)),
                    Text(
                      'Solicitud: ${a.usuarioSolicitud} → ${a.personaAliadoEntrega} | ${formatFechaHora(a.fechaSolicitud)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (!a.pendiente)
                      Text(
                        'Liberación: ${a.usuarioLiberacion} ← ${a.personaAliadoLibera} | '
                        '${a.fechaLiberacion != null ? formatFechaHora(a.fechaLiberacion) : ""}',
                        style: const TextStyle(fontSize: 12, color: AppColors.actionGreen, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
