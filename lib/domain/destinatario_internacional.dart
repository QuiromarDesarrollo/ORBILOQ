/// Campos de CLIENTES (I:Q), plantilla FMT-GL-005.
const camposDestinatarioInternacional = <String, String>{
  'email': 'Correo electrónico',
  'via': 'Vía',
  'tipo_carga': 'Tipo de carga',
  'embalaje': 'Embalaje',
  'puerto_embarque': 'Puerto de embarque',
  'pais_origen': 'País de origen',
  'puerto_destino': 'Puerto de destino',
  'pais_destino': 'País de destino',
  'termino_negociacion': 'Término de negociación',
};

bool esDestinatarioInternacional(Map datos) =>
    datos['tipo_destinatario'] == 'internacional';
