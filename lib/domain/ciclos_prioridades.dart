import 'dart:math' as math;
import 'ciclos.dart';
import 'ciclos_indicadores.dart';

class PrioridadProceso {
  PrioridadProceso(this.proceso);
  final ProcesoCiclo proceso;
  final List<MedicionCiclo> abiertas = [],
      atrasadas = [],
      terminadas = [],
      anteriores = [];
  int get sinMeta => abiertas.where((m) => m.parametro == null).length;
  int get prendas => atrasadas.fold(0, (s, m) => s + m.orden.cantidad);
  int atraso(MedicionCiclo m) => m.calendario.transcurridos(m.esperada!, m.hoy);
  int get mayorAtraso => atrasadas.fold(0, (s, m) => math.max(s, atraso(m)));
  List<MedicionCiclo> get evaluadas =>
      terminadas.where((m) => m.cumplio != null).toList();
  int get aTiempo => evaluadas.where((m) => m.cumplio!).length;
  double? get cumplimiento =>
      evaluadas.isEmpty ? null : 100 * aTiempo / evaluadas.length;
  double? get cambio {
    final antes = anteriores.where((m) => m.cumplio != null).toList();
    if (cumplimiento == null || antes.isEmpty) return null;
    return cumplimiento! -
        100 * antes.where((m) => m.cumplio!).length / antes.length;
  }

  double? get excesoMedio {
    final tarde = evaluadas.where((m) => !m.cumplio!).toList();
    if (tarde.isEmpty) return null;
    return tarde.fold<int>(
          0,
          (s, m) => s + m.calendario.transcurridos(m.esperada!, m.fin!),
        ) /
        tarde.length;
  }
}

class PrioridadesCiclos {
  static final _cache = Expando<PrioridadesCiclos>();
  factory PrioridadesCiclos(IndicadoresCiclos indicadores) =>
      _cache[indicadores] ??= PrioridadesCiclos._(indicadores);
  PrioridadesCiclos._(IndicadoresCiclos indicadores)
    : hoy = indicadores.datos.hoy,
      hasta =
          indicadores.hasta == null ||
                  indicadores.hasta!.isAfter(indicadores.datos.hoy)
              ? indicadores.datos.hoy
              : indicadores.hasta!,
      desde =
          indicadores.desde ??
          (indicadores.hasta == null ||
                      indicadores.hasta!.isAfter(indicadores.datos.hoy)
                  ? indicadores.datos.hoy
                  : indicadores.hasta!)
              .subtract(const Duration(days: 27)) {
    final datos = indicadores.datos;
    final dias = hasta.difference(desde).inDays + 1;
    anteriorHasta = desde.subtract(const Duration(days: 1));
    anteriorDesde = desde.subtract(Duration(days: dias));
    for (final o in indicadores.ordenes) {
      final indice = o.fines.indexWhere((f) => f == null);
      if (indice >= 0) {
        final m = datos.medir(o, ProcesoCiclo.values[indice]);
        if (m.inicio == null || m.inicio!.isAfter(hoy)) {
          sinInicio++;
        } else {
          final p = procesos[indice];
          p.abiertas.add(m);
          if (m.esperada != null && hoy.isAfter(m.esperada!)) {
            p.atrasadas.add(m);
          }
        }
      }
      for (final p in procesos) {
        final m = datos.medir(o, p.proceso);
        if (m.inicio == null || m.fin == null || m.fin!.isAfter(hoy)) continue;
        if (!m.fin!.isBefore(desde) && !m.fin!.isAfter(hasta)) {
          p.terminadas.add(m);
        }
        if (!m.fin!.isBefore(anteriorDesde) && !m.fin!.isAfter(anteriorHasta)) {
          p.anteriores.add(m);
        }
      }
    }
    for (final p in procesos) {
      p.atrasadas.sort((a, b) {
        final dias = p.atraso(b).compareTo(p.atraso(a));
        return dias != 0 ? dias : a.orden.op.compareTo(b.orden.op);
      });
    }
  }
  final DateTime hoy, desde, hasta;
  late final DateTime anteriorDesde, anteriorHasta;
  final procesos = [for (final p in ProcesoCiclo.values) PrioridadProceso(p)];
  int sinInicio = 0;
  List<PrioridadProceso> get ordenados => [...procesos]..sort((a, b) {
    final n = b.atrasadas.length.compareTo(a.atrasadas.length);
    if (n != 0) return n;
    final dias = b.mayorAtraso.compareTo(a.mayorAtraso);
    return dias != 0 ? dias : a.proceso.index.compareTo(b.proceso.index);
  });
}
