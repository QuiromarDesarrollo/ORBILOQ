# Preparación del despliegue de ORBILOQ

Estado actual: SQL aplicado manualmente en producción y conservación verificada.
NO volver a ejecutar 002. Falta publicar el build y validar con sesiones reales.
Las secciones siguientes conservan el registro de preparación y ensayos.
Destino: `cxrflhgnxvomcvxzugda`. Pruebas: `igfuafcekcpugpmsoqbe`.

## Evidencia disponible

- Inventarios de estructura (17) producción y (18) pruebas, del 2 de octubre de 2026.
- Respaldo nativo de producción del 2 de octubre a las 21:49 UTC.
- Ensayo local: 64 tablas, 5.793 filas; conteos y contenido coinciden con el respaldo.
- El ensayo se hizo con propietarios/ACL omitidos y roles locales NOLOGIN. No demuestra
  el funcionamiento de permisos, Auth, Realtime, Vault ni Edge Functions en Supabase.
- El respaldo incluye metadatos de Storage, no los archivos físicos.
- Los respaldos, copias locales y resultados con datos deben permanecer fuera de Git.

## Primer archivo

`001_diagnostico_previo.sql` es de solo lectura, usa una instantánea consistente y
consulta cantidades, integridad, firmas RPC, cuentas activas y efecto de fórmulas.
No repara datos ni agrega columnas. Se prueba primero contra la copia local.
Los resultados de esa copia describen la fecha del respaldo, no el estado actual remoto.

## Hallazgos del ensayo del 2 de octubre de 2026

Diagnóstico probado con éxito en `D:\ORBILOQ-restauracion-20261002-170805`.
La segunda exportación local volvió a coincidir en las 64 tablas y 5.793 filas.

- 692 OP, 2.831 líneas, 985 movimientos, 259 lotes y 497 líneas de lote.
- Sin líneas huérfanas de OP ni movimientos huérfanos de líneas; ninguna OC vacía.
- Un administrador activo. Tres perfiles activos sin referencia a una cuenta Auth
  existente. Pueden ser perfiles históricos: no eliminarlos ni asociarlos por nombre.
  Revisar si las personas que necesitan acceso tienen una cuenta válida antes de
  activar las políticas de cuenta obligatoria. No se detectaron auth_id duplicados.
- Un bucket y 18 objetos de Storage registrados. Los 18 archivos se descargaron,
  copiaron a D: y verificaron por ruta/tamaño contra el inventario y lectura XLSX.
  Se guardaron SHA256 locales. La app archiva los Excel en `documentos`.
- Las fórmulas DEV cambiarían el recibido de una línea y el total en -1 unidad.
  Existe un movimiento NC sin ubicación. No inferir su estante ni aplicar una
  compensación automática. Revisar recepción/devolución/liberación de esa línea
  y documentar la regla elegida antes de reemplazar la vista.
- En esta instantánea no cambia el producido ni el saldo por ubicación con las
  fórmulas comparadas. Esto no prueba todos los casos futuros.
- Sigue presente únicamente recepción de cuatro parámetros.
- El propietario confirmó que `admin-crear-usuario` no existe en producción.
- El propietario no sabe si hay otros escritores externos. No dar por hecho que
  cerrar la app detiene todas las escrituras; confirmar integraciones antes de la ventana.

El propietario confirmó que los tres perfiles sin Auth eran nombres seleccionables:
se conservan sin crearles accesos. Confirmó también que la última recepción de la OP
25438, código 2026556528, talla 30, fue el regreso de la unidad reprocesada: recibido
neto correcto = 30 recepciones - 1 devolución = 29. No se modifica ningún movimiento.

## Paquete preparado

- `002_aplicar_produccion.sql`: una transacción. Comprueba las 17 funciones originales
  contra el inventario y se detiene si cambiaron. Conserva tablas/columnas ERP y el
  importador completo. Agrega funcionalidad administrativa, reportes y despacho por OC.
- Antes de cambiar el esquema toma una copia temporal de los valores de las 20 tablas
  originales de public; antes del COMMIT compara todos esos valores, no solo conteos.
  Una diferencia provoca error y cancela la transacción. Las columnas nuevas no son
  parte de esa comparación porque no existían en el original.
- Reemplaza únicamente la restricción positiva conocida de movimientos por la regla
  que admite cantidades negativas cuando tienen auditoría. Conserva el resto.
- Mantiene recepción de cuatro parámetros; añade cinco parámetros obligatorios para
  evitar que esa nueva sobrecarga compita con llamadas antiguas de cuatro argumentos.
- Conserva las políticas/vistas exclusivas del ERP. Aplica las nuevas reglas de cuenta
  activa a las tablas/vistas WMS. No intenta resolver escritores externos desconocidos.
- `003_verificar_despues.sql`: consultas de solo lectura tras aplicar 002.
- `tools/test_migracion_produccion.sql`: SOLO local, datos sintéticos con ROLLBACK.

Ensayo final del SQL: `D:\ORBILOQ-restauracion-20261002-173921`.
Restauración 64/64 tablas, 5.793 filas verificadas; migración sin errores y datos
originales preservados. Pruebas: fórmula histórica 29, reportes, exportación,
importación con campos ERP, actor autenticado, recepción parcial/completa y antigua,
corrección sin cambiar recepciones, versión obsoleta, despacho idempotente, rechazo
de exceso, ciclo devolución/liberación/nueva recepción sin duplicar saldo, acceso
de Logística y denegación de reportes admin a Logística/anónimos. También se ejecutó
el archivo 003 de comprobación final: mismos 692 OP, 2.831 líneas, 985 movimientos,
259 lotes, 497 líneas de lote y seis perfiles; OP 25438 con 29 producidas/recibidas.
Se restauraron ACL de public para estas pruebas; se habilitó uso local del esquema
auth. Esto prueba SQL/RLS localmente, NO el transporte PostgREST, JWT o servicios reales.

Las consultas prueban que los datos existentes se conservan, no que los clientes
antiguos puedan seguir operando indefinidamente: cerrar todas las sesiones antiguas
durante el cambio y reabrir solo tras publicar y validar la nueva app.

IMPORTANTE: no ejecutar 002 dos veces. Se detiene si admin_correcciones ya existe.
No comentar las guardias para forzar una ejecución si la estructura ha cambiado.
No ejecutar estos SQL en pruebas: se diseñaron contra la estructura de producción.

## Cambios que requieren adaptación

1. Conservar clientes, devoluciones_cliente, vistas auxiliares del ERP y todas las
   columnas originales. No copiar tablas/datos de pruebas sobre producción.
2. Preservar la importación ERP completa: la función de pruebas es simplificada y
   no es reemplazo válido. Adaptar actor, bloqueo y OC sin perder campos ni historial.
3. Añadir recepción de cinco parámetros y conservar compatibilidad con la llamada
   anterior. Evitar defaults que hagan ambiguas las sobrecargas. Probar ambas firmas.
4. Añadir auditoría administrativa, importaciones, catálogos y despachos por OC;
   columnas nuevas deben admitir los registros existentes y conservar sus identificadores.
5. Revisar la restricción positiva de movimientos para admitir ajustes auditados;
   no deshabilitar todas las restricciones ni modificar cantidades antiguas.
6. Medir diferencias de kardex y stock antes de cambiar sus fórmulas. No confundir
   conservación de registros con conservación de los saldos calculados.
7. Revisar RLS/permisos y las cuentas existentes. Las políticas globales de pruebas
   afectan también tablas exclusivas de producción si se copian sin adaptación.
8. Desplegar por separado admin-crear-usuario, con validación de sesión/rol en servidor
   y secretos suministrados por el proyecto destino. Nunca incluir claves privilegiadas
   en Flutter, GitHub Pages o SQL compartido.

## Secuencia pendiente

1. Confirmar escritores externos, Storage y Edge Function de producción.
2. Revisar diagnóstico, preparar migración incremental y ensayarla sobre otra copia
   local del respaldo, comparando valores originales antes/después (no solo conteos).
3. Probar flujos con roles y sesiones en Supabase de pruebas, y comprobar diferencias
   que el entorno local no reproduce. Validar app nueva y compatibilidad de transición.
4. Fijar ventana sin escrituras y conservar una copia del build/commit publicado.
5. Obtener respaldo final y diagnóstico actualizado durante esa ventana.
6. El propietario aplica el SQL específico de producción, completo y transaccional.
   Ante un error, detenerse; no ejecutar fragmentos sueltos ni borrar restricciones al azar.
7. Validar base, Edge Function, compilar master con URL/clave pública de producción
   y publicar gh-pages. Verificar recepción parcial, despacho, usuarios e historiales.
8. Reabrir operaciones tras validación. Si falla, priorizar corrección hacia adelante;
   no restaurar un respaldo antiguo sobre nuevas operaciones ni borrar tablas nuevas.

No ejecutar `sql/pruebas/055` a `064` directamente en producción. Sus protecciones
son deliberadas: quitar la comprobación de entorno no adapta las diferencias.

El disco C: tenía espacio crítico durante el ensayo. Las nuevas copias deben usar
un destino con espacio suficiente; no borrar archivos automáticamente para liberarlo.

## Aplicación manual, cuando el build y la ventana estén preparados

1. Liberar espacio en C: antes de compilar. Preparar el build de master con URL
   `https://cxrflhgnxvomcvxzugda.supabase.co`, clave publicable de ese proyecto y
   base-href `/ORBILOQ/`. Conservar el build publicado y su commit de gh-pages.
   No publicar ni cambiar de rama todavía.
2. Preparar `admin-crear-usuario` con `index.ts` y `handler.mjs` de
   `supabase/functions/admin-crear-usuario`. En producción usa las variables
   SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY suministradas por el servidor.
   Configurar verify_jwt=false: la función valida el JWT con auth.getUser y verifica
   administrador activo internamente. No copiar secretos a Flutter ni al repositorio.
3. Coordinar pausa del taller y de cualquier integración escritora. Hacer respaldo
   final con `scripts/respaldo_produccion.ps1` (ahora guarda en D:), verificarlo y
   actualizar la copia de Storage si hay nuevas importaciones. Guardar diagnóstico 001.
4. En SQL Editor, comprobar que el proyecto seleccionado es cxrflhgnxvomcvxzugda.
   Ejecutar TODO `002_aplicar_produccion.sql` una sola vez. No editar sus guardias.
   Si falla, detenerse y compartir el error: la transacción no debe confirmarse por partes.
5. Ejecutar `003_verificar_despues.sql` y comparar conteos con el diagnóstico final.
   La OP histórica vale 29 solo si no hubo nuevas operaciones legítimas desde el ensayo.
   Revisar que anónimos no ejecuten las RPC nuevas y que se conserven ambos receptores.
6. Desplegar/comprobar la Edge Function y publicar el build preparado en gh-pages.
   Entrar con las cuentas reales, recargar para evitar caché anterior y validar flujos.
   No registrar movimientos ficticios en producción para probar; usar una OP controlada
   acordada con el taller o realizar la prueba funcional en DEV.
7. Reabrir operaciones tras aceptación. Si el SQL ya confirmó y falla el frontend,
   mantener la pausa y corregir; no ejecutar una restauración antigua encima de datos
   nuevos. Volver únicamente al frontend antiguo no equivale a revertir la base.

El paquete aún necesita validación del servicio Edge, JWT/PostgREST y publicación real.
Las pruebas locales no demuestran esas partes del despliegue. No se ejecutó ninguna
migración remota ni se publicó la app durante su preparación.

## Compilación preparada

Se compiló una copia del commit master `0a5e906f9b44132fb3df9e615cb74cbb16145b99`
en `D:\ORBILOQ-compilacion-20261002\fuente` porque C: seguía prácticamente lleno.
No se cambió el proyecto original ni el checkout de gh-pages.

- `flutter build web --release --no-pub`: correcto, base-href `/ORBILOQ/`.
- URL y clave publicable de producción verificadas en el JavaScript generado;
  no contiene la URL del proyecto de pruebas.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --reporter expanded`: 141 pruebas correctas.
- `node tools/test_admin_usuarios.mjs`: 14 comprobaciones con Auth simulado correctas.
- Build: `D:\ORBILOQ-compilacion-20261002\fuente\build\web`.
- ZIP: `D:\ORBILOQ-compilacion-20261002\ORBILOQ-web-produccion.zip`.
- Huellas individuales: `D:\ORBILOQ-compilacion-20261002\build-manifiesto.json`.
- Copia del commit local de gh-pages `70623ab2bf472966640adfa2fdb4ad0779d006da`:
  `D:\ORBILOQ-compilacion-20261002\gh-pages-publicado.zip`.
- Además se conservaron los cambios locales existentes de build/web por separado en
  `D:\ORBILOQ-compilacion-20261002\publicado\copia-local-web`.
- Edge Function preparada (no desplegada): `D:\ORBILOQ-compilacion-20261002\admin-crear-usuario`.

No reconstruir encima de build/web sin conservar su .git. No publicar la copia de
build/web antigua que tiene cambios locales: el artefacto validado es el generado en D:.
Si cambia el código de master, repetir la compilación/validación antes de publicar.

## Respaldo final durante pausa confirmada

El propietario confirmó que nadie usaba ORBILOQ. Se pidió mantener la pausa hasta
terminar el despliegue. Respaldo final: `D:\ORBILOQ-respaldos\produccion-20261002-175549-3744126c`.
Ensayo sobre este respaldo: `D:\ORBILOQ-restauracion-20261002-175756`.
Se verificaron las 64 tablas/5.793 filas, la conservación tras migración y las pruebas
funcionales. La comprobación final conserva 692 OP, 2.831 líneas y 985 movimientos.
Los hashes de contenido de storage.objects y storage.buckets coinciden con la copia
anterior cuyos 18 archivos físicos se descargaron; no hay cambios de metadatos.

El usuario desplegó `admin-crear-usuario` en producción. Una solicitud POST vacía
sin sesión devolvió HTTP 401 con el mensaje propio del handler, sin crear cuentas.
Esto prueba disponibilidad y rechazo de acceso anónimo, no el alta autenticada completa.

La migración de producción sigue pendiente de ejecución manual del propietario.
Si se reanudan operaciones antes de aplicarla, actualizar el respaldo y las verificaciones.

## Corrección del control de definiciones al pegar en SQL Editor

El primer intento manual se detuvo en agregar_personal_aliado, antes de crear tablas.
Una consulta remota de SOLO LECTURA confirmó que las 17 funciones seguían exactamente
iguales al inventario, admin_correcciones no existía y los conteos eran 692/2831/985.
Se reprodujo localmente el mismo fallo al convertir el archivo de CRLF a LF, como
puede ocurrir al copiar/pegar en un editor web. Las 17 guardias ahora normalizan
exclusivamente CRLF a LF en ambos lados; no se eliminó la comprobación del contenido.

Ensayo de corrección: `D:\ORBILOQ-restauracion-20261002-180425`. El SQL anterior
normalizado falló de la misma manera; el corregido normalizado pasó migración,
conservación de valores, pruebas funcionales y verificación final. Se debe volver
a copiar el archivo 002 completo actualizado, no reejecutar el texto viejo del editor.

## Migración aplicada y verificada en producción

Tras el segundo intento, el editor mostró `relation preservacion does not exist`.
La captura aportada muestra la opción «Run and enable RLS». Si se eligió, es consistente
con un ALTER TABLE añadido por el editor después del COMMIT: la tabla temporal
preservacion tiene ON COMMIT DROP. No confundir este error posterior con un rollback.
La comprobación remota confirmó las cuatro tablas nuevas, 36 funciones y las dos
firmas de recepción. No se volvió a aplicar la migración desde la terminal.

Se ejecutó 003 en producción en modo de solo lectura, con éxito. La OP 25438 muestra
29 producidas y 29 recibidas; los tres perfiles históricos y todos los conteos permanecen.
Las RPC comprobadas deniegan acceso a anon; admin_usuario_registrar no se concede
a authenticated. La creación real de cuentas todavía debe probarse desde la app.

Además se exportaron los datos actuales y se compararon TODAS las columnas originales
de cada tabla con el respaldo final. Resultado: 65/65 tablas, 5.793 filas sin diferencias.
El conteo incluye también la tabla de Vault del respaldo remoto, excluida del ensayo
PostgreSQL local de 64 tablas. Las columnas nuevas se excluyen de la comparación porque
no existían antes; no se excluyen columnas antiguas ni filas duplicadas.

Evidencia privada, fuera de Git:
- `D:\ORBILOQ-paquete-produccion\verificacion-produccion-aplicada.txt`
- `D:\ORBILOQ-paquete-produccion\conservacion-produccion.csv`
- `D:\ORBILOQ-paquete-produccion\datos-produccion-despues.sql`

Mantener pausa de operaciones hasta publicar y validar el build preparado en D:.
No volver a ejecutar 002 ni intentar crear preservacion en public para silenciar el error.
