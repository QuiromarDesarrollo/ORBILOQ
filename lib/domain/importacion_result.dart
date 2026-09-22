/// Resultado de una carga de Excel (Órdenes de Producción u otro tipo futuro).
class ResumenImportacion {
  const ResumenImportacion({
    required this.opsCreadas,
    required this.opsOmitidas,
    required this.filasInvalidas,
    required this.lineasTallasCreadas,
    required this.advertencias,
  });

  final int opsCreadas;
  final int opsOmitidas;
  final int filasInvalidas;
  final int lineasTallasCreadas;

  /// Mensajes de advertencia (ej. cantidades que no cuadran), ya listos para mostrar.
  final List<String> advertencias;

  bool get tuvoProblemas => filasInvalidas > 0 || advertencias.isNotEmpty;

  factory ResumenImportacion.fromJson(Map<String, dynamic> json) {
    final advertencias = (json['advertencias'] as List?) ?? const [];
    return ResumenImportacion(
      opsCreadas: (json['ops_creadas'] as num?)?.toInt() ?? 0,
      opsOmitidas: (json['ops_omitidas'] as num?)?.toInt() ?? 0,
      filasInvalidas: (json['filas_invalidas'] as num?)?.toInt() ?? 0,
      lineasTallasCreadas: (json['lineas_tallas_creadas'] as num?)?.toInt() ?? 0,
      advertencias: [for (final a in advertencias) a.toString()],
    );
  }
}
