class MasivaImportacion {
  const MasivaImportacion({
    required this.filas,
    required this.errores,
    required this.avisos,
    required this.tipo,
    this.hojas = const [],
  });

  final String tipo;
  final List<Map<String, dynamic>> filas;
  final List<String> errores;
  final List<String> avisos;
  final List<String> hojas;
  bool get valida => errores.isEmpty && filas.isNotEmpty;
  int get unidades => filas.fold(0, (s, f) => s + (f['cantidad'] as int));
  int get referencias => filas.map((f) => f['sku']).toSet().length;
  int get kits =>
      tipo == 'personal'
          ? filas.map((f) => '${f['lista']}\u0000${f['cedula']}').toSet().length
          : 0;
  int get listas =>
      filas.map((f) => f['lista']).whereType<String>().toSet().length;

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'filas': filas,
    'errores': errores,
    'avisos': avisos,
    'hojas': hojas,
  };

  factory MasivaImportacion.fromJson(Map<String, dynamic> json) =>
      MasivaImportacion(
        tipo: json['tipo'] as String,
        filas: [
          for (final f in json['filas'] as List)
            Map<String, dynamic>.from(f as Map),
        ],
        errores: List<String>.from(json['errores'] as List),
        avisos: List<String>.from(json['avisos'] as List),
        hojas: List<String>.from(json['hojas'] as List),
      );
}
