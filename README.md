# ORBILOQ WMS (reingeniería)

Flutter + Riverpod, con repositorios Supabase y en memoria.

## Edición administrativa (v55)

Desarrollo en `master`. SQL e instrucciones **exclusivamente para DEV**:
[sql/pruebas/README.md](sql/pruebas/README.md).
La edición agrega auditoría, vista previa y validación de permisos en el servidor.
No publicar sin validar primero el código y el SQL en pruebas.

**Prioridad del proyecto: conservar todos los datos existentes en producción.**
No copiar el esquema DEV sobre producción. La migración específica de producción
se preparará cuando se autorice el despliegue, conservando las estructuras ERP
y coordinando la recepción de cinco parámetros con la publicación del frontend.

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
`SupabaseWmsRepository` ya está implementado. `main.dart` selecciona Supabase
cuando se proporcionan `SUPABASE_URL` y `SUPABASE_ANON_KEY` con `--dart-define`.
Sin esos valores se usa el modo memoria para pruebas locales.





cd /c/Users/analistadatos/Downloads/orbiloq_wms/orbiloq_wms
flutter create . --platforms=web --project-name orbiloq_wms
flutter pub get
flutter test
flutter run -d chrome





## Excel del kardex y pantallas adaptables

El administrador puede usar **Exportar tabla → editar Excel → Importar tabla → Revisar reemplazo → Confirmar** en cada vista. Se exportan todas las filas activas, incluyendo código, talla y OC, sin aplicar filtros ni paginación. La importación de órdenes ERP sigue siendo un flujo separado.

Requiere aplicar manualmente `sql/pruebas/059_importar_tabla_admin.sql` en DEV después de 055, 057 y 058. Ver `sql/pruebas/README.md` para las validaciones, auditoría y restricciones. No ejecutar estas migraciones DEV en producción.

La página usa navegación compacta, fichas de filas en celulares y formularios adaptables. Validación local: `flutter test --no-pub` y `node tools/test_admin_sql.mjs` (base PostgreSQL desechable, sin acceso a Supabase).


## Administración de catálogos

El administrador dispone de **Administración** en ambas vistas y en el menú móvil: usuarios, ubicaciones/estantes, causales y personal de Logística, Producción y Aliados. Permite buscar, ver activos/inactivos, agregar, corregir y desactivar conservando historial.

En DEV, aplicar `sql/pruebas/060_administrar_catalogos.sql` y, para crear cuentas de acceso, desplegar la Edge Function siguiendo `supabase/functions/admin-crear-usuario/README.md`. No se utiliza una clave privilegiada en Flutter. La preparación para producción sigue siendo independiente.
