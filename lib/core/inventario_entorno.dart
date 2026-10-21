/// Este módulo se habilita únicamente contra ORBILOQ-DEV mientras se valida.
/// El despliegue de producción requiere su propia migración revisada.
bool get inventarioEnPruebas =>
    Uri.tryParse(const String.fromEnvironment('SUPABASE_URL'))?.host ==
    'igfuafcekcpugpmsoqbe.supabase.co';
