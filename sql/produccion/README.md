# Preparación del despliegue de ORBILOQ

## Actualización 20261030 aplicada; publicación web completada el 3 de noviembre

**SQL 015 aplicado y verificado. NO volver a ejecutarlo.**

- Proyectos conservados: producción `cxrflhgnxvomcvxzugda`; DEV `igfuafcekcpugpmsoqbe`.
- Migración 129–143 incremental, sin copiar datos DEV. SQL 016 comprobó esquema,
  RLS y permisos. COMMIT confirmado en el registro de migración.
- Respaldo final privado: `D:\ORBILOQ-respaldos\final-20261030-120539-1\produccion-20261030-120540-b16720d6`.
  `resultado.json`: aplicada_y_verificada; `comparacion-final.csv`: **100 tablas,
  17.402 filas originales, cero diferencias** en todas las columnas anteriores.
  Contiene metadatos Storage; no incluye una nueva copia de archivos físicos.
- Ensayo previo con respaldo de producción restaurado: 99 tablas y 17.404 filas
  conservadas. El conteo final anterior es el correspondiente al respaldo definitivo.
- Intentos previos interrumpidos por conexión/NOTICE no confirmaron transacción.
  Se corrigió compatibilidad PowerShell y manejo de stderr, manteniendo ON_ERROR_STOP.
- Frontend publicado en gh-pages, commit `550394e`, desde `build/produccion-20261030`.
  GitHub Pages sirve index/bootstrap 20261030, JavaScript idéntico al build tras
  normalizar saltos de línea, worker Masiva, assets y favicon con HTTP 200.
- Actualizadas `admin-crear-usuario` y `entrega-correo` en producción. Dashboard
  confirmó actualización; ambas rechazan solicitudes sin sesión con HTTP 401.
  Las otras dos funciones no cambiaron. No se enviaron correos en esta publicación.
- OAuth Gmail sigue pendiente: desplegar código no renueva la autorización Google.
  Consultar `docs/correo-entrega.md`; no considerar el envío real restablecido.
- Pruebas: 624 pasaron inicialmente y seis fallaron; los archivos corregidos pasaron
  sus repeticiones. Análisis sin errores, nueve avisos informativos. Pruebas Node
  de usuarios, correo y evidencias correctas. No se afirma una nueva suite completa.
- Versiones web previas conservadas para recuperación. No volver a ejecutar el
  lanzador de migración para repetir la publicación del frontend.

## Despliegue del 23 de octubre de 2026

**SQL 013 ya aplicado en producción. NO volver a ejecutarlo.**

Destino conservado: `cxrflhgnxvomcvxzugda`. DEV sigue siendo
`igfuafcekcpugpmsoqbe`; no se copiaron datos de DEV a producción.

- `013_actualizacion_20261023.sql` integra 101–128 en una transacción y compara
  las columnas y filas originales antes del COMMIT. Manifiesto de fuentes junto al SQL.
- Ensayo local completo: `D:\ORBILOQ-restauracion-20261023-175638`, restauración,
  migración, conservación y consultas/permisos de `014` correctos.
- Respaldo final privado:
  `D:\ORBILOQ-respaldos\final-20261023-175821\produccion-20261023-175821-1e4cec97`.
  Incluye dump, roles sin contraseñas, 33 adjuntos actuales (rutas/tamaños verificados,
  CRC ZIP y SHA256 local), código anterior de `admin-crear-usuario` y evidencia SQL.
- Conservación final: **83 tablas y 14.745 filas originales idénticas**, incluyendo
  Auth, Storage y Vault. El comparador estricto señaló únicamente
  `realtime.subscription` (12→6 conexiones temporales); se revisó y documentó
  esta excepción en `resultado.json`. No representa registros de negocio eliminados.
  No se reejecutó la migración tras esa alerta.
- Cuatro Edge Functions desplegadas, con JWT validado mediante Auth.getUser y
  permisos internos. Las cuatro rechazan invocación sin sesión (401). Las integraciones
  Google se copiaron a secretos del servidor con autorización explícita; renovación
  de ambos tokens comprobada sin enviar correos ni subir documentos de prueba.
- 32 pruebas locales de funciones correctas. Suite Flutter inicial: 486 correctas
  y 8 fallidas; se corrigieron y repitieron sus archivos, además de la prueba de
  entornos. Todas las repeticiones pasaron. Análisis: sin errores, 9 avisos informativos.
- Build release con el mismo proyecto y clave publicable del despliegue anterior.
  Commit enviado a gh-pages: `f2601ef91bd2eb1eb7f0b9289b3a2d0849068d85`.
  Reversión del frontend: commit anterior `31f9f8793bd8464b119ee638cb6bcdfb298ba810`;
  no restaurar la base completa para revertir solamente la interfaz.
- Revisión autenticada detectó caché de la versión anterior (Fecha esperada y menú sin Transporte). Se corrigió con entradas y recursos versionados; revisión final `c5d8346`. La sesión ya muestra FECHA PACTADA, bienvenida y Transporte. Se revisaron Resumen, Vehículos, Actividades, Mantenimiento, Documentos, Historial, Notificaciones y Perfil. Flota vacía en producción: no se crearon registros de prueba.
- Pages comprobado: aplicación, bootstrap y tres workers servidos coinciden con el build publicado. Navegación privada de Producción y Transporte revisada con administrador. Recursos versionados publicados y confirmados visualmente (incluidos iconos); sin nuevos errores de consola. Captura: `.dart_tool/revision-produccion-final-20261023.png`. No se probaron escrituras ni flujos con vehículos porque la flota de producción está vacía.


## Preparación del 15 de octubre de 2026

El último despliegue verificado corresponde al 13 de octubre: `gh-pages`
`fef28bcae7ffe901e54861102104b87a6e1f6936`, confirmado con `git ls-remote`.
El registro privado `D:\ORBILOQ-preparacion-20261013\despliegue-resultado.json`
documenta migración aplicada, 82 tablas y 8.572 filas originales conservadas.
Esto no sustituye el diagnóstico actual de producción.

Preparados `010_diagnostico_20261015.sql` (solo lectura) y
`scripts/preparar_respaldo_20261015.ps1` (contraseña oculta en terminal, exportación
a D: y diagnóstico). Respaldo generado en
`D:\ORBILOQ-respaldos\preparacion-20261015-173122\produccion-20261015-173123-3b7e015a`.
Restauración local verificada: 81 tablas, 10.516 filas, contenido idéntico.
El candidato `011_actualizacion_20261015.sql` reúne las versiones 095–100,
verifica las funciones previas y exige conservar filas originales y consecutivos.
El ensayo en `D:\ORBILOQ-restauracion-20261015-173646` confirmó conservación
de las 81 tablas y 10.516 filas tras aplicarlo localmente.
Pruebas funcionales locales de permisos y flujo importación/recepción/empaque/
salida/seguimiento: correctas (datos de ensayo revertidos).
Storage completo: 23 XLSX descargados, rutas y tamaños comparados con el respaldo,
contenido comprimido legible y hashes locales guardados en `storage` dentro de la
carpeta privada del respaldo. No se compararon hashes contra el servidor remoto.
Compilación release preparada en `D:\ORBILOQ-preparacion-20261015\web-produccion`,
con URL/clave pública del último despliegue y los tres lectores Excel en workers.
Pruebas Flutter: 363 pasaron inicialmente; las otras dos buscaban la tarjeta
retirada de estados de OP. Se actualizaron para verificar el snapshot y la
revocación de acceso, y pasaron al repetirlas. Análisis de `lib` y `test`: limpio.
El análisis de todo el repositorio informa tres avisos informativos preexistentes
en utilidades de `outputs/ciclos_limpieza_20261014`, ajenos al build publicado.
`012_verificar_actualizacion_20261015.sql` comprueba permisos, tablas privadas y
consultas nuevas; pasó en `D:\ORBILOQ-restauracion-20261015-174956`, conservando
81 tablas y 10.516 filas. `scripts/aplicar_produccion_20261015.ps1` exige pausa,
credencial oculta, respaldo final y coincidencia de Storage antes de aplicar 011;
después ejecuta 012 y compara contenido original. No publica el frontend.
Pausa confirmada por el usuario. SQL 011 aplicado y 012 verificado en producción
el 15 de octubre. NO volver a ejecutar 011.
Respaldo final: `D:\ORBILOQ-respaldos\final-20261015-175302\produccion-20261015-175302-3d293bcb`.
Comparación antes/después: 82 tablas, 10.374 filas originales idénticas, incluyendo
Auth, Storage y Vault. El conteo difiere del ensayo porque corresponde al respaldo
final, tomado después; no se eliminó ninguna fila durante la migración.
Los 23 adjuntos también se verificaron contra el respaldo final.
Web enviada a `gh-pages`, commit `31f9f8793bd8464b119ee638cb6bcdfb298ba810`.
Pages terminó correctamente: ejecución `38820284943`. Se comparó el contenido
servido de `main.dart.js`, `flutter_bootstrap.js` y los tres workers con el build
preparado (normalizando saltos de línea de Git). Sesión de administrador abierta
y sincronizada, kardex e indicadores consultados, sin errores de consola observados.
Evidencia final: `D:\ORBILOQ-preparacion-20261015\despliegue-resultado.json`.

Las secciones siguientes son registros históricos; no indican que deba volver
a ejecutarse la migración 002.

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

Nota de verificación web (actualización 20261030): Producción cargó y sincronizó sus datos. Masiva cargó el estado inicial vacío esperado, sin importar datos DEV. Su pie conserva el texto estático ENTORNO DE PRUEBAS; es una etiqueta visual pendiente, no el destino real de conexión. El build verificado usa cxrflhgnxvomcvxzugda.

### Pendientes del despliegue: avance del 3 de noviembre

Etiqueta Masiva corregida por SUPABASE_URL, sin cambios de estilo ni base de datos. Compilación release 20261103, análisis dirigido sin errores. Frontend `ab686fc`, política aprobada `7b4dd29`, ambos publicados en gh-pages. JavaScript servido idéntico al build normalizando saltos de línea. Verificación en web: Masiva muestra PRODUCCIÓN / Datos de la operación. Google Auth Platform pasó a En producción con autorización expresa; renovación Gmail todavía pendiente de completar por el titular. Ver docs/correo-entrega.md para estado exacto del correo.

Cierre de pendientes: correo renovado e instalado en producción el 3 de noviembre a las 12:57 UTC, con huellas verificadas y secretos de Drive intactos. Prueba ficticia autorizada aceptada por Gmail. No hubo migraciones, cambios de inventario ni eliminación de registros en esta corrección. Política y etiqueta disponibles en el frontend 7b4dd29.
