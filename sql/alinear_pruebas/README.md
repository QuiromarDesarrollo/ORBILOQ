# Alinear pruebas con producción

Estado: SQL preparado y ensayado localmente; pendiente aplicación manual en pruebas.
No se ha modificado ninguna base remota. No ejecutar la migración histórica
`sql/produccion/002_aplicar_produccion.sql` en pruebas: fue diseñada para otro origen.

## Alcance y origen

- Objetivo: estructura de aplicación de producción del 5 de octubre de 2026.
- Destino exclusivo: pruebas, `igfuafcekcpugpmsoqbe`.
- Producción `cxrflhgnxvomcvxzugda` se usa como referencia de solo lectura.
- Inventarios: `estructura_produccion_actual.csv` (08:26 -05) y
  `estructura_pruebas_actual.csv` (08:30 -05), facilitados por el usuario.
- Los inventarios contienen metadatos de `public`, no datos, configuración de
  Authentication, secretos, código de Edge Functions ni contenido de Storage.
- No copiar cuentas, contraseñas, identificadores Auth ni datos de producción.

## Diferencias que requieren tratamiento

- Faltan en pruebas las tablas `clientes` y `devoluciones_cliente` y las vistas
  `vista_fifo_sugerido`, `vista_lotes`, `vista_saldos_item`, `vista_stock_ubicacion`.
- Faltan campos ERP en órdenes e ítems, datos de documentos/importaciones,
  `movimientos.creado_en` y `ubicaciones.tipo`.
- Las fechas de documentos/importaciones tienen nombres diferentes. Deben
  conservarse al adaptar `creado_en` a `fecha_carga`/`fecha` respectivamente.
- `importaciones.usuario_nombre` no tiene equivalente textual en producción:
  allí se usa `usuario_id`. No descartar nombres históricos ni inferir identidad
  únicamente por coincidencia del nombre.
- Producción exige campos de documentos que no existen en pruebas: `entidad_id`,
  `entidad_tipo`, `tipo_documento`. Si hay documentos, hay que resolver su origen.
- Existen diferencias de RPC, incluida la importación ERP, recepción y firmas
  antiguas de No Conforme. Revisar dependencias y parámetros por nombre antes
  de retirar sobrecargas. No usar DROP CASCADE.
- Hay nuevas restricciones de cantidades, unicidad y referencias de usuarios a
  Auth. No eliminar duplicados ni modificar cantidades para forzar la migración.
- Hay diferencias en índices, permisos de los objetos faltantes y políticas RLS.
  No basta con copiar las columnas.

## Diagnóstico recibido

El usuario ejecutó `001_diagnostico_datos.sql` en pruebas: 4 usuarios, 2 órdenes,
3 ítems, 53 movimientos y 4 solicitudes a aliados. Documentos e importaciones
vacíos. No hay cantidades no positivas/nulas, usuarios duplicados ni referencias
Auth inexistentes. Los 53 movimientos tienen fecha.

Por ello se puede renombrar las fechas de documentos/importaciones y retirar
`importaciones.usuario_nombre` sin perder valores. El SQL exige nuevamente que
ambas tablas estén vacías al ejecutarse. No asigna usuarios ni entidades ficticias.
Inicializa el nuevo `movimientos.creado_en` con la `fecha` de cada movimiento:
es una aproximación histórica explícita; la fecha de creación original no existía
en pruebas. Todos los campos originales de movimientos permanecen intactos.

## Aplicación manual, solo en pruebas

1. No registrar operaciones en pruebas durante esta secuencia. No requiere detener
   producción. Verificar el proyecto `igfuafcekcpugpmsoqbe` en Supabase.
2. Ejecutar `000_exportar_datos_pruebas.sql` y guardar sus 22 filas completas en
   un CSV privado fuera del repositorio. Conservar el inventario original de pruebas.
   Este respaldo cubre datos de las tablas public existentes; no exporta contraseñas
   Auth ni archivos Storage, que no son modificados por esta migración.
3. Ejecutar **completo** `002_alinear_solo_pruebas.sql`. Esperar el resultado
   `OK: PRUEBAS alineada; datos originales conservados`.
4. Si Supabase muestra el aviso de operaciones destructivas, el SQL retira una
   columna vacía, un índice sobrante y reemplaza funciones/restricciones. Se ensayó
   la conservación y todo ocurre en una transacción. Si ofrece opciones RLS,
   elegir **Run without RLS**: el archivo ya establece las políticas y RLS que
   corresponden. No significa desactivar el RLS existente. No permitir que el editor
   añada sentencias a este archivo.
5. Ante cualquier error, detenerse y compartirlo; no ejecutar fragmentos restantes.
   Si la sesión quedó en transacción abortada, ejecutar únicamente `ROLLBACK;`.
   No borrar objetos para saltarse las comprobaciones ni volver a aplicar el SQL
   histórico de producción. Tras el éxito, no volver a ejecutar 002.
6. Ejecutar `003_verificar_estructura.sql`. Debe confirmar que la estructura de
   public coincide con la referencia de producción del 05-10-2026.
7. Probar la app conectada a pruebas: acceso, importación Excel, entrega, recepción
   parcial/completa, despacho, historial y reportes. No necesita publicar gh-pages.

Las comprobaciones comparan columnas, tipos, defaults, restricciones, índices,
funciones, vistas, propietarios, grants, RLS, publicaciones y secuencias del alcance.
Ignoran solo posición física de columnas, estimaciones de filas, orden de ACL
reemplazado por grants explícitos y diferencias CRLF/LF en definiciones.
El script se niega a operar si ya existen `clientes` o `devoluciones_cliente`, como
ocurre en producción, o si el esquema no coincide exactamente con el inventario
de origen. El ajuste de project_ref es una protección adicional si está configurado,
no se presupone que Supabase exponga ese parámetro.

## Evidencia de ensayo local

PostgreSQL 17.11 local, fixture del esquema de pruebas y referencia de producción
reconstruidas desde los inventarios PG 17.6, sin datos ni credenciales reales.
Último ensayo completo: `.dart_tool/alinear/ensayo-20261005-101446`.

- Alineación y verificación de estructura completas: correctas.
- Conservación de todas las columnas originales en las 22 tablas: comprobada en
  la transacción; además se verificaron cantidades, fechas y notas sintéticas.
- Ejecución sobre referencia de producción y repetición: rechazadas, sin cambios.
- Documento nuevo, cantidad cero o índice no inventariado: rechazo y rollback.
- Corrupción deliberada de una cantidad durante el ensayo: detectada por el
  control de conservación; esquema y cantidad original restaurados por rollback.
- Importación ERP, actor autenticado, recepción de cuatro/cinco parámetros,
  correcciones de administrador, despacho idempotente, límites, ciclo de No Conforme
  y separación administrador/logística/anon: correctos.
- Los tests funcionales usan una transacción revertida; no se publicaron cambios
  ni se invocaron Supabase Auth/Edge Functions reales.

La primera versión (1.234.528 bytes) fue rechazada por tamaño en el SQL Editor,
antes de ejecutarse. La versión compacta ocupa 115.921 bytes. Compara SHA256
por objeto y sección del mismo inventario normalizado, en lugar de incrustar
los inventarios completos. El orden de las huellas usa collation C explícita.
La conservación de datos sigue comparando todos los valores originales directamente.
Se repitió el ensayo completo con esta versión; no se dividió la transacción.

SHA256 de 002 compacto ensayado:
`1600AE155306A9AA9236BDF8C9F78FFE3CC374580023B7606B619D464E316099`.

Generación reproducible: `tools/generar_alineacion_pruebas.mjs` recibe los dos CSV
(producción primero, pruebas después). `tools/ensayar_alineacion_pruebas.ps1`
inicia y detiene PostgreSQL únicamente en loopback con registros ficticios.

## Criterios de entrega de la migración

1. Respaldo recuperable de pruebas y ensayo local antes de aplicarla.
2. Protección contra ejecución en producción, controles de estructura de origen
   y transacción completa. Una discrepancia debe abortar sin cambios parciales.
3. Preservación de filas y valores existentes; documentar cada transformación.
4. Verificación de firmas RPC, restricciones, permisos, RLS, vistas e índices.
5. Nuevo inventario de pruebas y comparación con producción tras aplicar el SQL.
   El orden físico de columnas y estimaciones de filas no son diferencias de lógica.
6. Validar acceso, importación, recepción, despacho e historial con la app de pruebas.
7. Validar aparte Edge Functions, configuración Auth y Storage, que no están
   descritos por estos inventarios.

## Despliegues futuros

Versionar cada nueva migración junto con el código en `master`; aplicarla primero
en pruebas, registrar resultado y usar exactamente ese archivo en producción
tras comprobar la estructura de origen y disponer del respaldo. No editar una
migración aplicada: generar otra. Git no aplica SQL a Supabase automáticamente.
Antes de cada despliegue, comparar inventarios para detectar cambios manuales.
