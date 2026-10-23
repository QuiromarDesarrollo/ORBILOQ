class CampoFichaVehiculo {
  const CampoFichaVehiculo(
    this.key,
    this.label, {
    this.numero = false,
    this.fecha = false,
    this.opciones = const [],
  });
  final String key, label;
  final bool numero, fecha;
  final List<String> opciones;
}

const fichaVehiculoCampos = <String, List<CampoFichaVehiculo>>{
  'Identificación del vehículo': [
    CampoFichaVehiculo('marca', 'Marca'),
    CampoFichaVehiculo('linea', 'Línea'),
    CampoFichaVehiculo('modelo', 'Modelo / año', numero: true),
    CampoFichaVehiculo('color', 'Color'),
    CampoFichaVehiculo('tipo_vehiculo', 'Tipo de vehículo'),
    CampoFichaVehiculo('ciudad', 'Ciudad'),
    CampoFichaVehiculo('centro_costos', 'Centro de costos'),
    CampoFichaVehiculo('identificacion_aux', 'Identificación del auxiliar'),
  ],
  'Características técnicas': [
    CampoFichaVehiculo('vin', 'VIN / número de chasis'),
    CampoFichaVehiculo('motor', 'Número de motor'),
    CampoFichaVehiculo('tipo_carroceria', 'Tipo de carrocería'),
    CampoFichaVehiculo('cantidad_sillas', 'Cantidad de sillas', numero: true),
    CampoFichaVehiculo(
      'capacidad_toneladas',
      'Capacidad de carga · toneladas',
      numero: true,
    ),
    CampoFichaVehiculo(
      'tipo_servicio',
      'Tipo de servicio',
      opciones: ['Público', 'Particular', 'Oficial', 'Otro'],
    ),
    CampoFichaVehiculo(
      'tipo_combustible',
      'Tipo de combustible',
      opciones: [
        'Diésel (ACPM)',
        'Gasolina',
        'Gas',
        'Eléctrico',
        'Híbrido',
        'Otro',
      ],
    ),
    CampoFichaVehiculo('codigo_fasecolda', 'Código Fasecolda'),
    CampoFichaVehiculo(
      'medicion_km',
      'Medición por kilómetros',
      opciones: ['Sí', 'No'],
    ),
    CampoFichaVehiculo(
      'medicion_hora',
      'Medición por horas',
      opciones: ['Sí', 'No'],
    ),
  ],
  'Compra y registro': [
    CampoFichaVehiculo('fecha_compra', 'Fecha de compra', fecha: true),
    CampoFichaVehiculo(
      'odometro_compra',
      'Odómetro de compra · km',
      numero: true,
    ),
    CampoFichaVehiculo(
      'horometro_compra',
      'Horómetro de compra · horas',
      numero: true,
    ),
    CampoFichaVehiculo('precio_compra', 'Precio de compra · COP', numero: true),
    CampoFichaVehiculo('vendedor', 'Vendedor'),
    CampoFichaVehiculo('registrado_por', 'Registrado por · sistema de origen'),
    CampoFichaVehiculo(
      'registrado_desde',
      'Registrado desde · sistema de origen',
      fecha: true,
    ),
  ],
};
const documentosFicha = <String, String>{
  'soat': 'SOAT',
  'tecno': 'Revisión tecnicomecánica',
  'licencia': 'Licencia de conducción',
  'extintor': 'Extintor',
};
