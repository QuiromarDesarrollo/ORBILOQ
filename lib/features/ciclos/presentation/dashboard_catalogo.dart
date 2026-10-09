import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth_providers.dart';
import '../../../application/dashboard_acceso.dart';
import '../../../application/providers.dart';
import '../../../application/ciclos_providers.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../domain/ciclos_indicadores.dart';
import '../../../core/utils/fecha.dart';
import '../../admin/presentation/dashboard_ejecutivo_page.dart';
import 'ciclos_page.dart';

final indicadoresResumenProvider = FutureProvider.autoDispose<FilaReporte>((
  ref,
) async {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Sin acceso');
  }
  final repo = ref.watch(reportesAdminProvider);
  if (repo == null) throw StateError('Sin conexión a reportes');
  return repo.resumen();
});

const _navy = Color(0xFF123D4D);
const _muted = Color(0xFF637F8B);
const _lime = Color(0xFFE8F1A2);
const _pale = Color(0xFFF3F7F8);

class DashboardCatalogoPage extends ConsumerWidget {
  const DashboardCatalogoPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
      return const Scaffold(
        body: Center(child: Text('Sin acceso a dashboards.')),
      );
    }
    final resumen = ref.watch(indicadoresResumenProvider);
    final ciclos = ref.watch(ciclosProvider);
    void actualizar() {
      ref.invalidate(indicadoresResumenProvider);
      ref.invalidate(ciclosProvider);
    }

    final ejecutivo = _Tarjeta(
      icono: Icons.grid_view_rounded,
      titulo: 'Dashboard ejecutivo',
      descripcion: 'Producción, recepción y operación del día.',
      boton: 'Abrir dashboard',
      abrir:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DashboardEjecutivoPage(),
            ),
          ),
      contenido: resumen.when(
        loading: () => const _Estado('Consultando indicadores…'),
        error:
            (_, __) => _Estado(
              'No se pudieron cargar los indicadores.',
              reintentar: actualizar,
            ),
        data:
            (d) => Row(
              children: [
                for (final m in [
                  ('op_activas', 'OP activas'),
                  ('op_atrasadas', 'OP atrasadas'),
                  ('op_no_conforme', 'NC pendientes'),
                ]) ...[
                  if (m.$1 != 'op_activas') const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _pale,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d[m.$1] ?? '—'}',
                            style: const TextStyle(
                              color: Color(0xFF167A65),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.$2,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
    final tiempos = _Tarjeta(
      icono: Icons.schedule_outlined,
      titulo: 'Tiempos de ciclo por proceso',
      descripcion:
          'Cumplimiento, tiempos históricos y capacidad diaria y semanal.',
      boton: 'Ver tiempos',
      abrir:
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const CiclosPage())),
      contenido: ciclos.when(
        loading: () => const _Estado('Consultando cumplimiento…'),
        error:
            (_, __) => _Estado(
              'No se pudo cargar el cumplimiento.',
              reintentar: actualizar,
            ),
        data: (d) {
          final lunes = d.hoy.subtract(Duration(days: d.hoy.weekday - 1));
          final inicio = lunes.subtract(const Duration(days: 49));
          final puntos = <double?>[
            for (var n = 0; n < 8; n++)
              IndicadoresCiclos(
                d,
                desde: inicio.add(Duration(days: n * 7)),
                hasta: inicio.add(Duration(days: n * 7 + 6)),
              ).cumplimientoTotal,
          ];
          final valor = IndicadoresCiclos(d, desde: inicio).cumplimientoTotal;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cumplimiento · últimas 8 semanas',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      valor == null ? '—' : '${valor.toStringAsFixed(0)} %',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (valor == null)
                  const SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        'Sin OP completas evaluables',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  )
                else
                  Semantics(
                    label:
                        'Cumplimiento semanal; las semanas sin datos se muestran sin línea.',
                    child: SizedBox(
                      height: 52,
                      child: CustomPaint(painter: _Tendencia(puntos)),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  '– –  Meta 85 %',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
    final corte = fechaReporte(resumen.valueOrNull?['actualizado_en']);
    return Scaffold(
      backgroundColor: const Color(0xFFEDF3F5),
      appBar: AppBar(
        title: const Text(
          'Indicadores',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) {
              if (v == 'actualizar') actualizar();
              if (v == 'salir') {
                ref.read(authRepositoryProvider)?.cerrarSesion();
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'actualizar',
                    child: Text('Actualizar indicadores'),
                  ),
                  PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                ],
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Indicadores de gestión',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Elige qué quieres revisar.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder:
                      (_, c) =>
                          c.maxWidth < 700
                              ? Column(
                                children: [
                                  ejecutivo,
                                  const SizedBox(height: 14),
                                  tiempos,
                                ],
                              )
                              : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: ejecutivo),
                                  const SizedBox(width: 20),
                                  Expanded(child: tiempos),
                                ],
                              ),
                ),
                const SizedBox(height: 22),
                Text(
                  corte == null
                      ? 'Los indicadores se consultan al abrir esta vista.'
                      : 'Datos consultados · ${formatFechaHora(corte)} · Bogotá',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.boton,
    required this.abrir,
    required this.contenido,
  });
  final IconData icono;
  final String titulo, descripcion, boton;
  final VoidCallback abrir;
  final Widget contenido;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE6EA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          offset: Offset(0, 3),
          blurRadius: 7,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: _navy, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        contenido,
        const SizedBox(height: 14),
        FilledButton(
          onPressed: abrir,
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  boton,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Estado extends StatelessWidget {
  const _Estado(this.texto, {this.reintentar});
  final String texto;
  final VoidCallback? reintentar;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(texto, style: const TextStyle(color: _muted, fontSize: 12)),
        if (reintentar != null)
          TextButton(onPressed: reintentar, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _Tendencia extends CustomPainter {
  _Tendencia(this.valores);
  final List<double?> valores;
  @override
  void paint(Canvas canvas, Size size) {
    final meta = 2 + (size.height - 4) * .15;
    final guia =
        Paint()
          ..color = const Color(0xFFBECF35)
          ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, meta),
        Offset((x + 4).clamp(0, size.width), meta),
        guia,
      );
    }
    final linea =
        Paint()
          ..color = _navy
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
    Offset? anterior;
    for (var i = 0; i < valores.length; i++) {
      final valor = valores[i];
      if (valor == null) {
        anterior = null;
        continue;
      }
      final punto = Offset(
        i * size.width / (valores.length - 1),
        2 + (size.height - 4) * (1 - valor / 100),
      );
      if (anterior != null) canvas.drawLine(anterior, punto, linea);
      canvas.drawCircle(punto, 2, Paint()..color = _navy);
      anterior = punto;
    }
  }

  @override
  bool shouldRepaint(covariant _Tendencia oldDelegate) =>
      oldDelegate.valores != valores;
}
