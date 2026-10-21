import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/inventario_repository.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../core/theme/app_theme.dart';

class InventarioSeleccion extends StatefulWidget {
  const InventarioSeleccion({super.key, required this.filas});
  final List<InventarioFila> filas;
  @override
  State<InventarioSeleccion> createState() => _InventarioSeleccionState();
}

class _InventarioSeleccionState extends State<InventarioSeleccion> {
  late final _cantidades = [
    for (final _ in widget.filas) TextEditingController(text: '1'),
  ];
  String? _error;
  @override
  void dispose() {
    for (final c in _cantidades) {
      c.dispose();
    }
    super.dispose();
  }

  void _continuar() {
    final seleccion = <InventarioFila>[];
    for (var i = 0; i < widget.filas.length; i++) {
      final r = widget.filas[i], n = int.tryParse(_cantidades[i].text) ?? 0;
      if (n <= 0 || n > (r['libre'] as num) || n > 999999) {
        setState(
          () =>
              _error =
                  'Revisa la cantidad de ${r['ficha']} · Talla ${r['talla']}.',
        );
        return;
      }
      seleccion.add({
        'cliente': r['cliente'],
        'ficha': r['ficha'],
        'talla': r['talla'],
        'cantidad': n,
      });
    }
    Navigator.pop(context, seleccion);
  }

  static const _navy = Color(0xFF0B3545);
  static const _muted = Color(0xFF58717E);
  static const _border = Color(0xFFDCE6EB);

  int _maximo(int i) =>
      (widget.filas[i]['libre'] as num).toInt().clamp(0, 999999);
  int _cantidad(int i) => int.tryParse(_cantidades[i].text) ?? 0;
  int get _total =>
      List.generate(widget.filas.length, _cantidad).fold(0, (a, b) => a + b);
  String _unidades(int n) => '$n ${n == 1 ? 'unidad' : 'unidades'}';
  void _ajustar(int i, int n) {
    if (_maximo(i) < 1) return;
    _cantidades[i].text = n.clamp(1, _maximo(i)).toString();
    setState(() => _error = null);
  }

  String _producto(Object? value) {
    final partes = <String, String>{};
    for (final parte in '$value'.split(' · ')) {
      final limpio = parte.trim().replaceAll(RegExp(r'\s+'), ' ');
      partes.putIfAbsent(limpio.toLowerCase(), () => limpio);
    }
    return partes.values.join(' · ');
  }

  Widget _etiqueta(String texto, Color fondo, Color tinta) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tinta),
    ),
  );

  Widget _controles(int i) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 6,
    children: [
      _paso(
        Icons.remove,
        'Disminuir cantidad',
        _cantidad(i) > 1 ? () => _ajustar(i, _cantidad(i) - 1) : null,
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 86,
        child: TextField(
          key: ValueKey('cantidad-seleccion-$i'),
          controller: _cantidades[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() => _error = null),
          style: const TextStyle(
            fontSize: 18,
            color: _navy,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'Cantidad',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _paso(
        Icons.add,
        'Aumentar cantidad',
        _cantidad(i) < _maximo(i) ? () => _ajustar(i, _cantidad(i) + 1) : null,
      ),
      const SizedBox(width: 4),
      TextButton(
        onPressed:
            _cantidad(i) == _maximo(i) || _maximo(i) == 0
                ? null
                : () => _ajustar(i, _maximo(i)),
        style: TextButton.styleFrom(
          foregroundColor: _navy,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: const Text('Máx.'),
      ),
    ],
  );

  Widget _paso(IconData icono, String tooltip, VoidCallback? accion) =>
      IconButton.outlined(
        tooltip: tooltip,
        onPressed: accion,
        style: IconButton.styleFrom(
          foregroundColor: _navy,
          minimumSize: const Size(42, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: _border),
        ),
        icon: Icon(icono, size: 18),
      );

  Widget _prenda(int i) {
    final r = widget.filas[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _producto(r['producto']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              _etiqueta('Talla ${r['talla']}', const Color(0xFFE5EFF5), _navy),
              _etiqueta(
                '${r['libre']} ${r['libre'] == 1 ? 'disponible' : 'disponibles'}',
                AppColors.lima.withValues(alpha: .18),
                _navy,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r['ficha']}',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _border),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final titulo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cantidad a despachar',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _navy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Máximo ${_unidades(_maximo(i))}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              );
              return c.maxWidth < 540
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      const SizedBox(height: 10),
                      _controles(i),
                    ],
                  )
                  : Row(
                    children: [
                      Expanded(child: titulo),
                      const SizedBox(width: 12),
                      _controles(i),
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WmsDialogShell(
    title: 'Despachar prendas seleccionadas',
    subtitle: '${widget.filas.first['cliente']}',
    icon: Icons.local_shipping_outlined,
    iconColor: _navy,
    maxWidth: 980,
    footer: LayoutBuilder(
      builder: (context, c) {
        final total = Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Total a despachar: ',
                style: TextStyle(color: _muted),
              ),
              TextSpan(
                text: _unidades(_total),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ],
          ),
        );
        final acciones = Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                backgroundColor: Colors.white,
                minimumSize: const Size(90, 44),
              ),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: _continuar,
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 44),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('Continuar al despacho'),
            ),
          ],
        );
        return c.maxWidth < 650
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [total, const SizedBox(height: 10), acciones],
            )
            : Row(
              children: [
                Expanded(child: total),
                const SizedBox(width: 12),
                acciones,
              ],
            );
      },
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _etiqueta(
            'Una OC y un destinatario',
            AppColors.lima.withValues(alpha: .20),
            _navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _navy, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Indica las cantidades. Se propondrán las entradas más antiguas y sus estantes; podrás revisar el reparto antes de guardar.',
                  style: TextStyle(color: _navy, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            const Text(
              'Prendas a despachar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            Text(
              '${widget.filas.length} ${widget.filas.length == 1 ? 'referencia seleccionada' : 'referencias seleccionadas'}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        for (var i = 0; i < widget.filas.length; i++) _prenda(i),
      ],
    ),
  );
}
