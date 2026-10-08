import 'package:flutter/material.dart';
import '../../../application/dashboard_periodo.dart';

class DashboardCalendario extends StatelessWidget {
  const DashboardCalendario({
    super.key,
    required this.periodo,
    required this.onChanged,
  });
  final PeriodoDashboard periodo;
  final ValueChanged<PeriodoDashboard> onChanged;
  String fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.date_range),
    label: Text('${fecha(periodo.inicio)} – ${fecha(periodo.fin)} · Lun–Vie'),
    onPressed: () async {
      final rango = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
          start: DateTime(
            periodo.inicio.year,
            periodo.inicio.month,
            periodo.inicio.day,
          ),
          end: DateTime(periodo.fin.year, periodo.fin.month, periodo.fin.day),
        ),
        helpText:
            'Selecciona el período · solo se contabilizan lunes a viernes',
        saveText: 'Aplicar',
      );
      if (rango != null) onChanged(PeriodoDashboard(rango.start, rango.end));
    },
  );
}
