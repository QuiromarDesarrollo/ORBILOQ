import '../data/reportes_admin_repository.dart';

String diaDashboard(DateTime d) =>
    '${const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Fechas calendario de Bogotá, inclusivas. Solo incluye lunes a viernes.
class PeriodoDashboard {
  PeriodoDashboard(DateTime inicio, DateTime fin)
    : inicio = DateTime.utc(inicio.year, inicio.month, inicio.day),
      fin = DateTime.utc(fin.year, fin.month, fin.day);
  final DateTime inicio, fin;
  List<DateTime> get dias => [
    for (var d = inicio; !d.isAfter(fin); d = d.add(const Duration(days: 1)))
      if (d.weekday <= DateTime.friday) d,
  ];
  bool contiene(Object? fecha) {
    final local = fechaReporte(fecha);
    if (local == null) return false;
    final d = DateTime.utc(local.year, local.month, local.day);
    return d.weekday <= 5 && !d.isBefore(inicio) && !d.isAfter(fin);
  }
}
