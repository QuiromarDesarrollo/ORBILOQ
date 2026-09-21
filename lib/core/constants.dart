/// Catálogos fijos del negocio. En Supabase pasarán a tablas (`ubicaciones`, `operarios`).
abstract final class WmsConstantes {
  static const operarios = <String>[
    'OPERARIO CONFECCIÓN 1',
    'PLANTA CORTE BOGOTÁ',
    'TALLER EXTERNO',
  ];

  static const ubicaciones = <String>[
    'ESTANTE A1',
    'ESTANTE B2',
    'PASILLO CENTRAL',
    'PISO BODEGA',
    'RACK C3',
  ];
}
