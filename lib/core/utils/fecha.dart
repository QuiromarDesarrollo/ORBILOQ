import 'package:intl/intl.dart';

final _fechaFmt = DateFormat('dd/MM/yyyy');
final _fechaHoraFmt = DateFormat('dd/MM/yyyy HH:mm');

String formatFecha(DateTime? d) => d == null ? '-' : _fechaFmt.format(d);
String formatFechaHora(DateTime? d) => d == null ? '-' : _fechaHoraFmt.format(d);

/// Descarta la hora (para filtros por día).
DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
