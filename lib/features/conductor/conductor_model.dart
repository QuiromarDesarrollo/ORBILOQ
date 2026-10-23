const checklistConductor = <String, List<String>>{
  'Frenos y fluidos': [
    'Estado frenos',
    'Nivel de aceite',
    'Nivel de refrigerante',
  ],
  'Iluminación': [
    'Direccionales delanteras',
    'Direccionales traseras',
    'Luces altas',
    'Luces bajas',
    'Luces stop',
    'Luces de parqueo',
  ],
  'Llantas': ['Llantas delanteras', 'Llantas traseras', 'Llanta de repuesto'],
  'Visibilidad': [
    'Limpiabrisas',
    'Espejo lateral izquierdo',
    'Espejo lateral derecho',
    'Vidrio panorámico',
  ],
  'Seguridad': [
    'Pito',
    'Pito reversa',
    'Cinturón de seguridad',
    'Puertas seguras',
  ],
  'Cabina y carrocería': ['Área de cargue', 'Interior cabina', 'Techos libres'],
  'Elementos de protección personal': [
    'Botas de lluvia',
    'Impermeable',
    'Guantes de trabajo',
    'Chaleco reflectivo',
  ],
  'Kit de carretera': [
    'Botiquín',
    'Herramientas',
    'Kit de derrames',
    'Extintor',
  ],
};

const documentosConductor = [
  'SOAT',
  'Revisión tecnicomecánica',
  'Licencia de conducción',
  'Extintor',
];
const eventosConductor = [
  'Inicio de jornada',
  'Fin de jornada',
  'Registro diario',
  'Tanqueo',
  'Lavado',
  'Reposición de fluidos',
  'Mantenimiento preventivo',
  'Mantenimiento correctivo',
  'Siniestro vial',
  'Novedad',
];

bool enlaceDriveValido(String valor) {
  final u = Uri.tryParse(valor.trim());
  return u != null &&
      u.scheme == 'https' &&
      const ['drive.google.com', 'docs.google.com'].contains(u.host) &&
      u.path.length > 1 &&
      u.userInfo.isEmpty;
}

int diasRestantes(DateTime fecha, DateTime hoy) =>
    DateTime.utc(
      fecha.year,
      fecha.month,
      fecha.day,
    ).difference(DateTime.utc(hoy.year, hoy.month, hoy.day)).inDays;

String? validarRegistroConductor({
  required String tipo,
  required int km,
  required int ultimoKm,
  required Map<String, String> respuestas,
  required String notas,
  required String enlace,
}) {
  if (km < ultimoKm) return 'El kilometraje no puede ser menor a $ultimoKm.';
  if (enlace.isNotEmpty && !enlaceDriveValido(enlace)) {
    return 'Usa un enlace HTTPS de Google Drive.';
  }
  if (tipo == 'Inicio de jornada' || tipo == 'Fin de jornada') {
    if (checklistConductor.values
        .expand((e) => e)
        .any(
          (p) => !const ['Buen estado', 'Con novedad'].contains(respuestas[p]),
        )) {
      return 'Completa todos los puntos de la inspección.';
    }
  }
  if ((respuestas.containsValue('Con novedad') ||
          tipo == 'Novedad' ||
          tipo == 'Siniestro vial') &&
      notas.trim().isEmpty) {
    return 'Describe la novedad o el hecho ocurrido.';
  }
  return null;
}

class VehiculoConductor {
  const VehiculoConductor({
    required this.id,
    required this.placa,
    required this.descripcion,
    required this.km,
    this.datos = const {},
  });
  final String id, placa, descripcion;
  final int km;
  final Map<String, dynamic> datos;
  factory VehiculoConductor.fromJson(Map<String, dynamic> j) =>
      VehiculoConductor(
        id: j['id'] as String,
        placa: j['placa'] as String,
        descripcion: j['descripcion'] as String? ?? '',
        km: (j['km'] as num).toInt(),
        datos: Map<String, dynamic>.from(j['datos'] as Map? ?? {}),
      );
}
