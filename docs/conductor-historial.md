# Historial del conductor y exportación

Implementado en `master`. Migración `115_conductor_historial_privado.sql` aplicada
y verificada en ORBILOQ-DEV (`igfuafcekcpugpmsoqbe`) el 21 de octubre de 2026.
El cliente nuevo requiere esta migración. No aplicar en producción.

El 21 de octubre también se aplicó `116_conductor_fotos_laterales.sql` en DEV:
el indicador de evidencia reconoce las fotos de lateral derecho e izquierdo.
La función `conductor-evidencia` admite ambos campos. El Excel los exporta en
columnas independientes. `foto_lateral` se conserva para registros anteriores;
no se atribuye retrospectivamente a ninguno de los dos lados.

## Vista y permisos

- Cada tarjeta agrupa una fecha de actividad del vehículo seleccionado. Cuenta
  únicamente Inicio de jornada y Fin de jornada como las dos inspecciones.
  Las demás actividades se conservan dentro de ese día.
- Conductor: fecha, estado de inicio/cierre y número de inspecciones completadas.
  Sin detalle, selección múltiple, exportación ni enlaces de evidencias guardadas.
- Administrador: selección de varios días, seleccionar todos los días del filtro,
  consulta de sus registros y descarga Excel. Cambiar el filtro limpia la selección.
- Filtro inclusivo de fechas, inicialmente desde el primer día del mes hasta hoy.
  No se inventan jornadas para días sin registros.
- `conductor_historial` comprueba la cuenta activa y el vehículo autorizado. El
  rol real del servidor decide qué columnas devuelve; no recibe un parámetro
  que permita pedir permisos de administrador desde el cliente.
- RLS restringe la lectura directa de `conductor_registros` al administrador.
  Para el conductor, la RPC solo devuelve identificador, tipo y fecha. Los dos
  indicadores operativos de hoy (revisión pendiente y evidencia registrada)
  mantienen los avisos del inicio, sin respuestas, notas, archivos ni enlaces.
- La exportación recorre todas las páginas de 200 registros del período. No usa
  los últimos 100 registros que carga el resumen inicial del portal.

## Estructura del Excel

**Jornadas:** una fila por día seleccionado, con fecha, placa, vehículo, inicio,
cierre, inspecciones completadas y total de registros.

**Checklist:** registros de inicio y fin de jornada, diferenciados por la columna
Tipo de registro. **Registro diario:** fotos y seguimiento diario.
**Novedades:** registros de tipo Novedad o Novedades. Los demás tipos (tanqueo,
lavado, mantenimiento, documentos, etc.) generan su propia hoja.

Solo se crean hojas para tipos presentes en los días seleccionados. Cada hoja
contiene una fila por actividad y únicamente las columnas con algún dato en
esa hoja. Se omiten valores nulos, textos en blanco y estructuras vacías; cero
y false (exportado como «No») se conservan. Los campos adicionales, incluidos
objetos anidados y listas, se mantienen. Los nombres de hojas se normalizan para
Excel y se distinguen cuando coinciden, sin sobrescribir registros.

Las URLs se guardan completas como texto. El archivo no contiene fotos ni
documentos incrustados. Los textos aportados por usuarios no se interpretan
como fórmulas. Los valores y kilometrajes se exportan como números cuando son
válidos. Las fechas de actividad usan `datos.fecha`; registros antiguos sin
ella usan la fecha de creación en America/Bogota.

## Verificación

- `node tools/test_conductor_historial.mjs`: PostgreSQL desechable; prueba roles,
  vehículo ajeno, usuario inactivo, lectura directa, fechas, paginación e idempotencia.
- `flutter test test/conductor_historial_test.dart`: agrupación, 401 registros
  paginados, contenido Excel, textos de fórmula seguros y UI por rol a 320 px.
- Verificación remota de instalación: RPC existente y política de lectura
  `admin_es_admin()` en ORBILOQ-DEV.

Verificación final del 21 de octubre de 2026: 13 pruebas Flutter aprobadas
(historial, portal adaptable y guardado de evidencias), análisis sin incidencias
y ensayo SQL aprobado. Se revisaron capturas de ambos roles a 320 px.

Compilación web release completada con la configuración de ORBILOQ-DEV.
Vista local de esta sesión: `http://localhost:8877` (solo este equipo).
Por falta de espacio en C:, la copia de compilación está en
`D:\orbiloq-test-temp\historial-dev-20261021\build\web`.
Se comprobó en navegador que carga la pantalla de acceso. El servidor local
debe estar activo para usar esa URL; no es un despliegue público.

La comprobación automatizada de roles usa datos de prueba. No sustituye un
inicio de sesión manual con cada cuenta. Un cliente anterior que consulte
directamente la tabla ya no puede mostrar sus detalles al conductor; se debe
usar la compilación actualizada.
