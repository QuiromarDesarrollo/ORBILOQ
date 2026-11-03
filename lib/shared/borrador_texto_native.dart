// El almacenamiento nativo usa BorradorLocalStore; estas funciones no se invocan.
String? leerTextoBorrador(String key) => null;
void escribirTextoBorrador(String key, String value) =>
    throw UnsupportedError('Solo web');
