import 'package:flutter/material.dart';
import '../../../domain/sesion.dart';

/// Distribución vertical para catálogos en teléfonos, sin tabla horizontal.
class CatalogoTarjetas extends StatelessWidget {
  const CatalogoTarjetas({
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

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final empaque = tipo == 'empaques';
    final usuario = tipo == 'usuarios';
    final agrupado = !usuario && !empaque;
    final personal = tipo.startsWith('personal_');
    return ColoredBox(
      color: const Color(0xFFF5F8F9),
      child: ListView.separated(
        padding: const EdgeInsets.all(6),
        itemCount: filas.length,
        separatorBuilder: (_, _) => SizedBox(height: agrupado ? 0 : 8),
        itemBuilder: (context, i) {
          final f = filas[i];
          final activo = (f['activo'] ?? f['activa']) == true;
          final nombre = '${f['nombre'] ?? f['codigo'] ?? ''}';
          final rol =
              RolCuenta.values.where((r) => r.valorBd == f['rol']).firstOrNull;
          final acceso = activo && f['auth_id'] != null;
          final editar = ocupado ? null : () => onEditar(f);
          final desactivar = ocupado || !activo ? null : () => onDesactivar(f);
          Widget estado() => Container(
            padding: EdgeInsets.symmetric(
              horizontal: agrupado ? 0 : 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color:
                  agrupado
                      ? Colors.transparent
                      : activo
                      ? const Color(0xFFE6F4EE)
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              activo ? '● Activo' : '● Inactivo',
              style: TextStyle(
                fontSize: 10,
                color: activo ? const Color(0xFF047857) : Colors.blueGrey,
              ),
            ),
          );
          Widget acciones() => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar $nombre',
                onPressed: editar,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Desactivar $nombre',
                onPressed: desactivar,
                color: const Color(0xFFB42318),
                icon: const Icon(Icons.block, size: 18),
              ),
            ],
          );
          String n(String key) => '${f[key] ?? '—'}'.replaceAll('.', ',');
          double d(String key) => double.tryParse('${f[key]}') ?? 0;
          Widget dato(String titulo, String valor) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
              ),
              Text(valor, style: const TextStyle(fontSize: 12)),
            ],
          );
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  agrupado
                      ? BorderRadius.vertical(
                        top: i == 0 ? const Radius.circular(10) : Radius.zero,
                        bottom:
                            i == filas.length - 1
                                ? const Radius.circular(10)
                                : Radius.zero,
                      )
                      : BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2EBEF), width: .5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (usuario || empaque || personal) ...[
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: color.withValues(alpha: .10),
                        child:
                            empaque
                                ? Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                  color: color,
                                )
                                : Text(
                                  nombre
                                      .trim()
                                      .split(RegExp(r'\s+'))
                                      .where((s) => s.isNotEmpty)
                                      .take(2)
                                      .map((s) => s.characters.first)
                                      .join()
                                      .toUpperCase(),
                                  style: TextStyle(fontSize: 11, color: color),
                                ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (usuario)
                            Text(
                              'N° ${f['numero_usuario'] ?? '—'} · ${rol?.etiqueta ?? f['rol'] ?? '—'}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey,
                              ),
                            ),
                          if (empaque)
                            Text(
                              f['categoria'] == 'CAJA' ? 'Caja' : 'Empaque',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          if (!empaque)
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                estado(),
                                if (usuario)
                                  Text(
                                    acceso ? 'Con acceso' : 'Sin acceso',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2457A0),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (empaque) estado() else acciones(),
                  ],
                ),
                if (empaque) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: dato(
                                'Medidas',
                                '${n('largo_cm')} × ${n('ancho_cm')} × ${n('alto_cm')} cm',
                              ),
                            ),
                            Expanded(
                              child: dato(
                                'Volumen',
                                '${(d('largo_cm') * d('ancho_cm') * d('alto_cm') / 1000000).toStringAsFixed(3).replaceAll('.', ',')} m³',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: dato('Tara', '${n('peso_neto_kg')} kg'),
                            ),
                            Expanded(
                              child: dato(
                                'Peso bruto aprox.',
                                '${n('peso_bruto_kg')} kg',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: editar,
                          child: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB42318),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: desactivar,
                          child: const Text('Desactivar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class CatalogoToolbar extends StatelessWidget {
  const CatalogoToolbar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth >= 600) {
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: ButtonStyle(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 11),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ),
            ),
            child: children.first,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 54, child: children[1]),
              const SizedBox(width: 8),
              Expanded(child: children[2]),
            ],
          ),
        ],
      );
    },
  );
}
