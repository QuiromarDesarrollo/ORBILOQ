import '../../../shared/widgets/wms_loader.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/inventario_repository.dart';

void mostrarFlujoInventario(BuildContext context) => showDialog<void>(
  context: context,
  builder:
      (context) => AlertDialog(
        title: const Text('Cómo funciona el inventario'),
        content: const SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Paso(
                  '1',
                  'Recibir en Bodega',
                  'Indica el estante y la cantidad recibida. Las prendas quedan disponibles para su OP original. Usa Transferir desde OP para enviar después la cantidad que quieras a inventario.',
                ),
                _Paso(
                  '2',
                  'Consultar existencias',
                  'El inventario se separa por cliente, ficha técnica (incluida su versión) y talla. Abre una fila para ver sus estantes y OP de origen.',
                ),
                _Paso(
                  '3',
                  'Reservar y despachar',
                  'Despacho o Administrador selecciona una transferencia libre, una OC del mismo cliente, destinatario y empaque. Se genera una LE reservada; Seguimiento confirma la salida.',
                ),
                _Paso(
                  '4',
                  'Corregir una transferencia',
                  'Bodega o Administrador puede devolver las unidades libres a su OP, talla y estante originales, indicando el motivo. Primero libera las reservas. Las unidades ya despachadas no se revierten como transferencia.',
                ),
                Text(
                  'También puedes usar Transferir desde OP para prendas que ya fueron recibidas. Una transferencia no duplica la recepción ni cambia físicamente el estante.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
);

class _Paso extends StatelessWidget {
  const _Paso(this.numero, this.titulo, this.texto);
  final String numero, titulo, texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 15, child: Text(numero)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(texto),
            ],
          ),
        ),
      ],
    ),
  );
}

class InventarioVista extends StatelessWidget {
  const InventarioVista({
    super.key,
    required this.datos,
    required this.buscar,
    required this.onBuscar,
    required this.pagina,
    required this.onPagina,
    required this.onAbrir,
    required this.onTransferir,
    required this.onRefrescar,
    required this.conectado,
    this.onDespachar,
    this.onImportar,
    this.seleccionadas = const {},
    this.clienteSeleccionado,
    this.onSeleccionar,
    this.onDespacharSeleccion,
    this.onVaciarSeleccion,
    this.preparando = false,
    this.onFiltro,
    this.onLimpiar,
    this.filtrosActivos = const {},
  });
  final Future<InventarioFila>? datos;
  final TextEditingController buscar;
  final ValueChanged<String> onBuscar;
  final int pagina;
  final ValueChanged<int> onPagina;
  final ValueChanged<InventarioFila> onAbrir;
  final ValueChanged<InventarioFila>? onDespachar;
  final VoidCallback? onTransferir;
  final VoidCallback? onImportar;
  final VoidCallback onRefrescar;
  final bool conectado;
  final Set<String> seleccionadas;
  final String? clienteSeleccionado;
  final void Function(InventarioFila, bool)? onSeleccionar;
  final VoidCallback? onDespacharSeleccion, onVaciarSeleccion;
  final bool preparando;
  String _clave(InventarioFila r) =>
      jsonEncode([r['cliente'], r['ficha'], r['talla']]);
  bool _seleccionable(InventarioFila r) =>
      _n(r, 'libre') > 0 &&
      (clienteSeleccionado == null || clienteSeleccionado == r['cliente']);
  final Set<String> filtrosActivos;
  final void Function(String, String)? onFiltro;
  final VoidCallback? onLimpiar;
  static const columnas = <String, String>{
    'ficha': 'Ficha técnica',
    'producto': 'Producto',
    'talla': 'Talla',
    'cliente': 'Cliente',
    'pendiente_producir': 'Pendiente por\nproducción',
    'bodega': 'En\nbodega',
    'libre': 'Stock\ndisponible',
    'reservado': 'Reservado',
    'despachado': 'Despachado\ndesde\ninventario',
  };

  Widget _encabezado(String key, String label, {bool numero = false}) =>
      InkWell(
        onTap: onFiltro == null ? null : () => onFiltro!(key, label),
        child: SizedBox(
          width: numero ? 94 : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                numero ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: numero ? TextAlign.center : TextAlign.start,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Filtrar por ${label.replaceAll('\n', ' ')}',
                child: Icon(
                  Icons.filter_alt,
                  size: 14,
                  color:
                      filtrosActivos.contains(key)
                          ? AppColors.lima
                          : const Color(0xFFC5DFEB),
                ),
              ),
            ],
          ),
        ),
      );
  int _n(InventarioFila r, String k) => (r[k] as num?)?.toInt() ?? 0;

  Widget _accion(InventarioFila r, {bool compacta = false}) =>
      onDespachar == null
          ? TextButton(
            onPressed: () => onAbrir(r),
            child: const Text('Ver detalle'),
          )
          : _n(r, 'libre') > 0
          ? compacta
              ? IconButton.filled(
                tooltip: 'Despachar',
                onPressed: () => onDespachar!(r),
                icon: const Icon(Icons.local_shipping_outlined, size: 17),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xff0d3e50),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
              : FilledButton.icon(
                onPressed: () => onDespachar!(r),
                icon: const Icon(Icons.local_shipping_outlined, size: 17),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0d3e50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                label: const Text('Despachar'),
              )
          : const Text(
            'Sin stock libre',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          );

  Widget _numero(BuildContext context, InventarioFila r, String k) {
    final n = _n(r, k);
    return Text(
      '$n',
      style: TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color:
            n == 0
                ? Theme.of(context).colorScheme.outline
                : k == 'libre'
                ? const Color(0xff087c69)
                : null,
      ),
    );
  }

  Widget _tabla(BuildContext context, List<InventarioFila> rows) =>
      LayoutBuilder(
        builder:
            (context, size) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: size.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: onSeleccionar != null,
                    columnSpacing: 12,
                    horizontalMargin: 14,
                    headingRowHeight: 64,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 64,
                    dataTextStyle: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    dividerThickness: 0.4,
                    headingRowColor: WidgetStatePropertyAll(AppColors.petroleo),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.25,
                    ),
                    columns: [
                      for (final h in columnas.entries)
                        DataColumn(
                          label: _encabezado(
                            h.key,
                            h.value,
                            numero:
                                ![
                                  'ficha',
                                  'producto',
                                  'talla',
                                  'cliente',
                                ].contains(h.key),
                          ),
                        ),
                      const DataColumn(
                        label: Padding(
                          padding: EdgeInsets.only(left: 24),
                          child: Text('Acciones'),
                        ),
                      ),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          selected: seleccionadas.contains(_clave(r)),
                          onSelectChanged:
                              onSeleccionar != null && _seleccionable(r)
                                  ? (v) => onSeleccionar!(r, v ?? false)
                                  : null,
                          cells: [
                            DataCell(
                              SizedBox(
                                width: size.maxWidth < 1300 ? 145 : 170,
                                child: Text(
                                  '${r['ficha']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              onTap: () => onAbrir(r),
                            ),
                            DataCell(
                              SizedBox(
                                width: size.maxWidth < 1300 ? 160 : 210,
                                child: Text(
                                  '${r['producto']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onTap: () => onAbrir(r),
                            ),
                            DataCell(
                              Text('${r['talla'] ?? 'Sin talla'}'),
                              onTap: () => onAbrir(r),
                            ),
                            DataCell(
                              SizedBox(
                                width: size.maxWidth < 1300 ? 125 : 150,
                                child: Text(
                                  '${r['cliente']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onTap: () => onAbrir(r),
                            ),
                            for (final k in [
                              'pendiente_producir',
                              'bodega',
                              'libre',
                              'reservado',
                              'despachado',
                            ])
                              DataCell(
                                SizedBox(
                                  width: 94,
                                  child: Center(child: _numero(context, r, k)),
                                ),
                                onTap: () => onAbrir(r),
                              ),
                            DataCell(
                              Row(
                                children: [
                                  const SizedBox(width: 24),
                                  _accion(r, compacta: true),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Ver movimientos de esta talla',
                                    iconSize: 17,
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(32, 32),
                                      maximumSize: const Size(32, 32),
                                      padding: const EdgeInsets.all(6),
                                    ),
                                    onPressed: () => onAbrir(r),
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
      );

  Widget _tarjetas(BuildContext context, List<InventarioFila> rows) =>
      ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = rows[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onSeleccionar != null)
                  Row(
                    children: [
                      Checkbox(
                        value: seleccionadas.contains(_clave(r)),
                        onChanged:
                            _seleccionable(r)
                                ? (v) => onSeleccionar!(r, v ?? false)
                                : null,
                      ),
                      const Expanded(child: Text('Agregar al despacho')),
                    ],
                  ),
                Text(
                  '${r['producto']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r['ficha']}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                Text(
                  'Talla ${r['talla'] ?? 'Sin talla'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${r['cliente']}', style: const TextStyle(fontSize: 12)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final k in [
                      ('libre', 'Disponible'),
                      ('reservado', 'Reservado'),
                      ('despachado', 'Despachado'),
                      ('pendiente_producir', 'Por producir'),
                      ('bodega', 'Bodega OP'),
                    ])
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _numero(context, r, k.$1),
                          Text(
                            k.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    _accion(r),
                    if (onDespachar != null)
                      TextButton(
                        onPressed: () => onAbrir(r),
                        child: const Text('Ver detalle'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: palOf(context).bg,
      appBar: AppBar(
        title: const Text('Inventario'),
        backgroundColor: const Color(0xff0d3e50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Cómo funciona',
            onPressed: () => mostrarFlujoInventario(context),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Actualizar inventario',
            onPressed: onRefrescar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, size) {
            final mobile = size.maxWidth < 800;
            final contenido = Padding(
              padding: EdgeInsets.all(mobile ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      final titulo = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OPERACIONES / INVENTARIO',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Control de inventario',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Prendas ingresadas por transferencia o Excel, agrupadas por ficha técnica, cliente y talla.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      );
                      final accion =
                          onTransferir == null
                              ? null
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'ACCIONES DE INVENTARIO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      if (onImportar != null)
                                        OutlinedButton.icon(
                                          onPressed: onImportar,
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text(
                                            'Importar inventario Excel',
                                          ),
                                        ),
                                      FilledButton.icon(
                                        onPressed: onTransferir,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.lima,
                                          foregroundColor: AppColors.petroleo,
                                        ),
                                        icon: const Icon(
                                          Icons.add_box_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Transferir desde OP',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                      return box.maxWidth < 800
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titulo,
                              if (accion != null) ...[
                                const SizedBox(height: 12),
                                accion,
                              ],
                            ],
                          )
                          : Row(
                            children: [
                              Expanded(child: titulo),
                              if (accion != null) ...[
                                const SizedBox(width: 24),
                                accion,
                              ],
                            ],
                          );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (conectado)
                    FutureBuilder<InventarioFila>(
                      future: datos,
                      builder: (context, s) {
                        if (!s.hasData ||
                            s.connectionState != ConnectionState.done ||
                            s.hasError) {
                          return const SizedBox.shrink();
                        }
                        final filas =
                            (s.data?['filas'] as List? ?? [])
                                .cast<InventarioFila>();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'UNIDADES EN LA PÁGINA ACTUAL',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 112,
                              child: LayoutBuilder(
                                builder:
                                    (context, box) => ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: 5,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(width: 12),
                                      itemBuilder: (_, i) {
                                        final campos = [
                                          (
                                            'pendiente_producir',
                                            'PENDIENTE DE PRODUCIR',
                                            Icons.factory_outlined,
                                          ),
                                          (
                                            'bodega',
                                            'BODEGA ASIGNADA A OP',
                                            Icons.warehouse_outlined,
                                          ),
                                          (
                                            'libre',
                                            'STOCK DISPONIBLE',
                                            Icons.inventory_2_outlined,
                                          ),
                                          (
                                            'reservado',
                                            'RESERVADO',
                                            Icons.lock_outline,
                                          ),
                                          (
                                            'despachado',
                                            'DESPACHADO DE INVENTARIO',
                                            Icons.local_shipping_outlined,
                                          ),
                                        ];
                                        final campo = campos[i];
                                        final valor = filas.fold<int>(
                                          0,
                                          (n, r) => n + _n(r, campo.$1),
                                        );
                                        return Container(
                                          width:
                                              box.maxWidth >= 1000
                                                  ? (box.maxWidth - 48) / 5
                                                  : 210,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                AppColors.petroleo,
                                                Color(0xff176888),
                                              ],
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      campo.$2,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    campo.$3,
                                                    color: AppColors.lima,
                                                    size: 22,
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                '$valor',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                Icon(Icons.table_rows_outlined, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Inventario y seguimiento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final search = TextField(
                                  controller: buscar,
                                  onChanged: onBuscar,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Buscar ficha, talla, producto o cliente',
                                    prefixIcon: Icon(Icons.search),
                                    isDense: true,
                                  ),
                                );
                                final transfer = OutlinedButton.icon(
                                  onPressed: () {
                                    if (onLimpiar != null) {
                                      onLimpiar!();
                                    } else {
                                      buscar.clear();
                                      onBuscar('');
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.filter_alt_off_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Limpiar'),
                                );
                                return box.maxWidth < 650
                                    ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        search,
                                        ...[
                                          const SizedBox(height: 10),
                                          transfer,
                                        ],
                                      ],
                                    )
                                    : Row(
                                      children: [
                                        Expanded(child: search),
                                        ...[
                                          const SizedBox(width: 16),
                                          transfer,
                                        ],
                                      ],
                                    );
                              },
                            ),
                          ),
                          if (seleccionadas.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${seleccionadas.length} prendas seleccionadas · $clienteSeleccionado',
                                  ),
                                  FilledButton.icon(
                                    onPressed: onDespacharSeleccion,
                                    icon:
                                        preparando
                                            ? const WmsLoader(width: 40)
                                            : const Icon(
                                              Icons.local_shipping_outlined,
                                            ),
                                    label: Text(
                                      preparando
                                          ? 'Preparando…'
                                          : 'Despachar seleccionadas',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: onVaciarSeleccion,
                                    child: const Text('Quitar selección'),
                                  ),
                                ],
                              ),
                            ),
                          if (mobile && onFiltro != null)
                            PopupMenuButton<String>(
                              tooltip: 'Filtros por columna',
                              onSelected:
                                  (key) => onFiltro!(key, columnas[key]!),
                              itemBuilder:
                                  (_) => [
                                    for (final h in columnas.entries)
                                      PopupMenuItem(
                                        value: h.key,
                                        child: Text(
                                          h.value.replaceAll('\n', ' '),
                                        ),
                                      ),
                                  ],
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.filter_alt_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Filtros por columna'),
                                  ],
                                ),
                              ),
                            ),
                          if (filtrosActivos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${filtrosActivos.length} filtros de columna activos · Limpiar para ver todos',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          Expanded(
                            child:
                                !conectado
                                    ? const Center(
                                      child: Text(
                                        'Conecta con ORBILOQ-DEV para consultar inventario.',
                                      ),
                                    )
                                    : FutureBuilder<InventarioFila>(
                                      future: datos,
                                      builder: (context, s) {
                                        if (s.connectionState !=
                                            ConnectionState.done) {
                                          return const WmsLoadingPanel(
                                            label: 'Cargando inventario…',
                                          );
                                        }
                                        if (s.hasError) {
                                          return Center(
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'No se pudo cargar inventario',
                                                  ),
                                                  Text('${s.error}'),
                                                  TextButton(
                                                    onPressed: onRefrescar,
                                                    child: const Text(
                                                      'Reintentar',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                        final rows =
                                            (s.data?['filas'] as List? ?? [])
                                                .cast<InventarioFila>();
                                        final total =
                                            (s.data?['total'] as num?)
                                                ?.toInt() ??
                                            0;
                                        final disponibles =
                                            rows
                                                .where(
                                                  (r) => _n(r, 'libre') > 0,
                                                )
                                                .length;
                                        return Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    0,
                                                    16,
                                                    12,
                                                  ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '$total filas por talla · $disponibles con stock libre en esta página',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: c.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child:
                                                  rows.isEmpty
                                                      ? const Center(
                                                        child: Text(
                                                          'No hay prendas para esta búsqueda.',
                                                        ),
                                                      )
                                                      : mobile
                                                      ? _tarjetas(context, rows)
                                                      : _tabla(context, rows),
                                            ),
                                            const Divider(height: 1),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Página ${pagina + 1} · ${rows.length} resultados',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Anterior',
                                                    onPressed:
                                                        pagina == 0
                                                            ? null
                                                            : () => onPagina(
                                                              pagina - 1,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.chevron_left,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Siguiente',
                                                    onPressed:
                                                        (pagina + 1) * 25 >=
                                                                total
                                                            ? null
                                                            : () => onPagina(
                                                              pagina + 1,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.chevron_right,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!mobile)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Disponible: stock libre para nuevas OC. Bodega OP: prendas que conservan su pedido original.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                ],
              ),
            );
            return FutureBuilder<InventarioFila>(
              future: datos,
              builder: (context, snapshot) {
                final count = (snapshot.data?['filas'] as List? ?? []).length;
                final desired = mobile ? 1200.0 : 700.0 + count * 64;
                final height = desired < 1100 ? 1100.0 : desired;
                return SingleChildScrollView(
                  child: SizedBox(
                    height: height < size.maxHeight ? size.maxHeight : height,
                    child: contenido,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
