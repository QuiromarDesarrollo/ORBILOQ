import '../../../data/empaques_repository.dart';
import 'package:flutter/material.dart';
import 'catalogo_tarjetas.dart';

class CatalogoTabla extends StatelessWidget {
  const CatalogoTabla({
    super.key,
    required this.tipo,
    required this.filas,
    required this.ocupado,
    required this.onEditar,
    required this.onDesactivar,
  });
  final String tipo;
  final List<Map<String, dynamic>> filas;
  final bool ocupado;
  final ValueChanged<Map<String, dynamic>> onEditar, onDesactivar;
  String n(dynamic v) => (v ?? '—').toString().replaceAll('.', ',');
  double d(dynamic v) => double.tryParse('$v') ?? 0;
  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return const Center(child: Text('No hay registros con estos filtros.'));
    }
    final empaque = tipo == 'empaques';
    final personal = tipo.startsWith('personal_');
    return LayoutBuilder(
      builder:
          (context, c) =>
              c.maxWidth < 600
                  ? CatalogoTarjetas(
                    tipo: tipo,
                    filas: filas,
                    ocupado: ocupado,
                    onEditar: onEditar,
                    onDesactivar: onDesactivar,
                  )
                  : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width:
                          c.maxWidth < (empaque ? 950 : 550)
                              ? (empaque ? 950 : 550)
                              : c.maxWidth,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: const WidgetStatePropertyAll(
                            Color(0xFFF3F7F9),
                          ),
                          headingTextStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF425F6D),
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF163442),
                          ),
                          horizontalMargin: 16,
                          columnSpacing: 20,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 76,
                          headingRowHeight: 40,
                          border: TableBorder.all(
                            color: const Color(0xFFEDF2F5),
                            width: .5,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                empaque
                                    ? 'EMPAQUE'
                                    : tipo == 'ubicaciones'
                                    ? 'UBICACIÓN'
                                    : tipo == 'causales_devolucion'
                                    ? 'CAUSAL'
                                    : 'NOMBRE',
                              ),
                            ),
                            if (empaque) ...[
                              for (final title in [
                                'MEDIDAS (CM)',
                                'VOLUMEN',
                                'TARA',
                              ])
                                DataColumn(label: Text(title)),
                            ],
                            const DataColumn(label: Text('ESTADO')),
                            const DataColumn(label: Text('ACCIONES')),
                          ],
                          rows: [
                            for (final f in filas)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (personal ||
                                            empaque ||
                                            tipo == 'ubicaciones') ...[
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: const Color(
                                              0xFFE3EDF1,
                                            ),
                                            child:
                                                personal
                                                    ? Text(
                                                      '${f['nombre'] ?? '?'}'
                                                          .characters
                                                          .take(2)
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Color(
                                                          0xFF093E52,
                                                        ),
                                                      ),
                                                    )
                                                    : Icon(
                                                      empaque
                                                          ? Icons
                                                              .inventory_2_outlined
                                                          : Icons
                                                              .location_on_outlined,
                                                      size: 16,
                                                      color: const Color(
                                                        0xFF093E52,
                                                      ),
                                                    ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 350,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                empaque
                                                    ? textoEmpaque(f['nombre'])
                                                    : '${f['nombre'] ?? f['codigo'] ?? ''}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (empaque)
                                                Text(
                                                  f['categoria'] == 'CAJA'
                                                      ? 'Caja'
                                                      : 'Paquete',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF57707C),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (empaque) ...[
                                    DataCell(
                                      Text(
                                        '${n(f['largo_cm'])} × ${n(f['ancho_cm'])} × ${n(f['alto_cm'])}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${(d(f['largo_cm']) * d(f['ancho_cm']) * d(f['alto_cm']) / 1000000).toStringAsFixed(3).replaceAll('.', ',')} m³',
                                      ),
                                    ),
                                    DataCell(
                                      Text('${n(f['peso_neto_kg'])} kg'),
                                    ),
                                  ],
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (f['activo'] ?? f['activa']) == true
                                                ? const Color(0xFFE6F4EE)
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        (f['activo'] ?? f['activa']) == true
                                            ? '● Activo'
                                            : '● Inactivo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              (f['activo'] ?? f['activa']) ==
                                                      true
                                                  ? const Color(0xFF047857)
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar registro',
                                          onPressed:
                                              ocupado
                                                  ? null
                                                  : () => onEditar(f),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Desactivar registro',
                                          onPressed:
                                              ocupado ||
                                                      (f['activo'] ??
                                                              f['activa']) !=
                                                          true
                                                  ? null
                                                  : () => onDesactivar(f),
                                          icon: const Icon(
                                            Icons.block,
                                            size: 18,
                                          ),
                                          color: const Color(0xFFB42318),
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
  }
}
