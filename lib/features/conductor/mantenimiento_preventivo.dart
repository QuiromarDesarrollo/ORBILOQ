class ServicioPreventivo {
  const ServicioPreventivo(
    this.id,
    this.nombre, {
    this.dias,
    this.km,
    this.meses,
  });
  final String id, nombre;
  final int? dias, km, meses;
  String get periodicidad =>
      meses != null
          ? 'Cada $meses meses'
          : dias != null
          ? 'Cada $dias días'
          : km != null
          ? 'Cada 8.000 km'
          : 'Sin periodicidad automática';
}

const serviciosPreventivos = [
  ServicioPreventivo('limpieza', 'Limpieza general del vehículo', dias: 8),
  ServicioPreventivo(
    'limpiabrisas',
    'Llenado de tanque de agua para limpiabrisas',
    dias: 8,
  ),
  ServicioPreventivo(
    'combustible',
    'Llenado de tanque de combustible',
    dias: 8,
  ),
  ServicioPreventivo('aceite', 'Cambio de aceite', km: 8000),
  ServicioPreventivo(
    'refrigerante',
    'Llenado de líquido refrigerante',
    dias: 8,
  ),
  ServicioPreventivo('neumaticos', 'Cambio de neumáticos'),
  ServicioPreventivo('discos', 'Cambio de disco de frenos'),
  ServicioPreventivo(
    'calibracion',
    'Calibración de aire en los neumáticos',
    dias: 8,
  ),
  ServicioPreventivo('revision_preventiva', 'Revisión preventiva', meses: 3),
];

class ControlPreventivo {
  ControlPreventivo(this.servicio, this.detalle, this.alerta, this.clave);
  final ServicioPreventivo servicio;
  final String detalle, clave;
  final bool alerta;
}

List<ControlPreventivo> controlesPreventivos(
  Map<String, dynamic> datos,
  int km,
  DateTime hoy,
) {
  final resumen = datos['mantenimientos_preventivos'] as Map? ?? {};
  return serviciosPreventivos.map((s) {
    final ultimo = resumen[s.id] as Map?;
    final fin = DateTime.tryParse(ultimo?['fin']?.toString() ?? '');
    if (s.dias == null && s.km == null && s.meses == null) {
      return ControlPreventivo(s, s.periodicidad, false, s.id);
    }
    if (fin == null) {
      return ControlPreventivo(
        s,
        'Sin registro inicial · ${s.periodicidad}',
        false,
        s.id,
      );
    }
    if (s.km != null) {
      final objetivo =
          (int.tryParse(ultimo?['km']?.toString() ?? '') ?? km) + s.km!;
      final restante = objetivo - km;
      return ControlPreventivo(
        s,
        restante <= 0
            ? 'Cambio pendiente · objetivo $objetivo km'
            : 'Próximo cambio: $objetivo km · faltan $restante km',
        restante <= 1000,
        '${s.id}:$objetivo:${restante <= 0}',
      );
    }
    // Meses calendario: si no existe el día, usar el último del mes destino.
    final destino = DateTime.utc(fin.year, fin.month + (s.meses ?? 0));
    final ultimoDia = DateTime.utc(destino.year, destino.month + 1, 0).day;
    final fecha =
        s.meses != null
            ? DateTime.utc(
              destino.year,
              destino.month,
              fin.day > ultimoDia ? ultimoDia : fin.day,
            )
            : DateTime.utc(
              fin.year,
              fin.month,
              fin.day,
            ).add(Duration(days: s.dias!));
    final dias =
        fecha.difference(DateTime.utc(hoy.year, hoy.month, hoy.day)).inDays;
    final estado =
        dias < 0
            ? 'Vencido hace ${-dias} días'
            : dias == 0
            ? 'Vence hoy'
            : dias == 1
            ? 'Vence mañana'
            : 'Vence en $dias días';
    return ControlPreventivo(
      s,
      '$estado · ${fecha.day}/${fecha.month}/${fecha.year}',
      dias <= 1,
      '${s.id}:${fecha.toIso8601String()}:$dias',
    );
  }).toList();
}
