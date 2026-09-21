# ORBILOQ WMS (reingeniería)

Flutter + Riverpod. Datos en memoria detrás de un repositorio abstracto (listo para Supabase).

## Ejecutar
```bash
flutter create . --platforms=web,windows,android   # solo si el proyecto aún no tiene carpetas de plataforma
flutter pub get
flutter test
flutter run -d chrome
flutter build web --release
```

## Estructura
```
lib/
├─ main.dart / app.dart          # composición e inyección del repositorio
├─ core/                         # constantes, Result, tema, utilidades de fecha
├─ domain/                       # modelos, parser de QR, contrato WmsRepository
├─ data/                         # InMemoryWmsRepository (ledger de movimientos)
├─ application/                  # providers Riverpod y filtros
├─ shared/widgets/               # widgets reutilizables
└─ features/{kardex,produccion,recepcion,despacho,ubicaciones}/presentation
```

## Conectar Supabase
Implementar `WmsRepository` como `SupabaseWmsRepository` y cambiar el override en `main.dart`.
Las reglas de `InMemoryWmsRepository` (límites, stock) deben replicarse en funciones RPC transaccionales.
