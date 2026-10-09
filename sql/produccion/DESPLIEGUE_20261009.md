# Preparación incremental de octubre de 2026

Estado: **despliegue completado; migración y vistas verificadas, Excel descargado y abierto correctamente según confirmación del usuario**.

## Ejecución autorizada

El usuario autorizó aplicar y publicar. El preflight detectó una entrega de una
unidad posterior al respaldo de las 16:46. Se detuvo la aplicación del SQL, se
confirmó otra vez la pausa y se creó/restauró el respaldo actualizado
`D:\ORBILOQ-respaldos\produccion-20261009-165516-a6353bd3`, con sus 18 archivos
de Storage contrastados con el inventario nuevo.

El primer intento SQL abortó al bloquear `auth.schema_migrations`: ese permiso
no está disponible para el rol administrado de Supabase. Se confirmó la reversión.
El SQL corregido compara Auth sin bloquear sus tablas; conserva los bloqueos de
las tablas de negocio. Se volvió a ensayar íntegramente antes de aplicarlo.

El intento corregido terminó en COMMIT. Hash SHA256 del SQL aplicado:
`5D35DC20E4359A60EE2AE3337323A2937DF85D3C5744C4D86C96345CA47C0B6A`.
La comparación posterior conservó 69/69 tablas y 8.135 filas originales respecto
al preflight final. La diferencia frente a las 8.144 filas del respaldo corresponde
exclusivamente a sesiones y suscripciones cerradas antes de migrar, verificada en
`comparacion-preflight-final.csv`; ninguna fila operativa cambió.

Pasó `006_verificar_actualizacion_20261009.sql`: 692 OP, 2.831 ítems, 507 lotes,
1.090 detalles de lote, 2.287 movimientos y 8 usuarios. Próxima LE 3000, catálogos
vacíos. Se verificaron las concesiones de RPC, el bucket privado, las seis tablas
de Realtime esperadas y consultas autenticadas de reportes/historial/trazabilidad.

El usuario confirmó haber publicado el cambio del handler de usuarios. La prueba
HTTP sin credenciales devolvió 401 desde el handler; no se crearon cuentas de prueba.
La creación autenticada de una cuenta real no se probó durante este despliegue.

Frontend: commit `f9b6915a4fa5afe1b66088f6f03ec9b21500554d`, padre
`65719eeaf699bd231980a3b852a9815b91875c98`. Push sin force a `gh-pages`.
Las diferencias de dos archivos frente al build local son únicamente CRLF/LF
(`manifest.json`, `flutter_service_worker.js`); el JavaScript principal es idéntico.
No se tocó el checkout local `build/web` con sus cambios preexistentes.

Evidencias privadas en `D:\ORBILOQ-preparacion-20261009-155918`:
`aplicacion-produccion-ajustada.log`, `verificacion-produccion.log`,
`conservacion-produccion-final.csv`, `datos-preflight-final.sql`,
`datos-produccion-despues.sql`, `gh-pages-anterior-65719ee.zip`.

Destino: proyecto `cxrflhgnxvomcvxzugda`, aplicación
`https://quiromardesarrollo.github.io/ORBILOQ/`, base href `/ORBILOQ/`.
Código de aplicación revisado: commit `9ffe056`. Suite Flutter: 294 pruebas
correctas. Análisis estático: sin problemas. Handler de alta de usuarios:
17 comprobaciones con Auth simulado correctas.

## Respaldo y conservación

- Respaldo privado: `D:\ORBILOQ-respaldos\produccion-20261009-165516-a6353bd3`.
- Restauración comprobada: 69 tablas, 8.144 filas, contenido idéntico.
- Archivos: `storage-verificado`, 18 importaciones XLSX verificadas contra inventario
  de rutas/tamaños, con hashes locales. No se compararon hashes remotos de Storage.
- Ensayo incremental con permisos y consultas:
  `D:\ORBILOQ-restauracion-20261009-165958`.
  Las 69 tablas conservaron todas sus filas y columnas originales.
  También pasó el flujo de importación, producción, recepción, reserva,
  salida, guía/placa y trazabilidad, con datos sintéticos revertidos.
- Única alta admitida en tablas existentes: bucket privado
  `seguimiento-evidencias`, límite 10 MiB. No se excluyen cambios del bucket existente.
- El ensayo no reproduce servicios gestionados de Supabase ni Vault, propietarios
  originales, Realtime remoto o disponibilidad de la Edge Function.

## Paquete SQL

`005_actualizacion_20261009.sql` **ya fue aplicado**. No reejecutarlo, ni reejecutar
`002_aplicar_produccion.sql`, ni usar los SQL de DEV en producción.
`006_verificar_actualizacion_20261009.sql` es una verificación de solo lectura
del estado inicial del despliegue; sus comprobaciones de LE y catálogos vacíos
dejan de aplicar cuando se empiece a operar.

El generador `scripts/preparar_incremental_octubre.py` usa lista explícita de
22 migraciones, elimina exclusivamente las comprobaciones de identidad DEV y
mantiene las comprobaciones de dependencias. Registra los hashes de las fuentes
en `005_actualizacion_20261009.fuentes.json`.

La migración valida las 36 funciones originales contra el diagnóstico, se ejecuta
en una transacción y compara todas las filas/columnas originales de public,
respaldo_mantenimiento y auth antes de confirmar. El ensayo además compara los
datos completos del respaldo, incluyendo Storage. Las políticas de Gerencia se
limitan a tablas WMS y a sus buckets, para conservar las estructuras del ERP.
Incluye las tablas movimientos/lotes/lote_items en Realtime que faltaban en el
diagnóstico; conserva todas las suscripciones existentes.

No copia catálogos, cuentas ni OP de prueba. No modifica cantidades históricas.
El consecutivo preparado es **3000**, por instrucción expresa del usuario.
Destinatarios y tipos de empaque se crearán desde la aplicación; ambos catálogos
quedan vacíos al desplegar. El usuario confirmó pausa de operaciones y que todos
terminaron de sincronizar. Tras detectar la entrega de las 16:52, se reconfirmó
la pausa y se utilizó el respaldo actualizado de las 16:55.

## Build preparado

Build release JavaScript completado en
`D:\ORBILOQ-preparacion-20261009-155918\web-produccion`, con `/ORBILOQ/` y la
configuración pública recuperada del artefacto del despliegue anterior, validando
que apunta a producción. No se utiliza una clave de servicio en el frontend.
No se modificó `build/web`. Se publicó desde el worktree aislado
`C:\Users\analistadatos\.codex\worktrees\publicacion-octubre\orbiloq_wms`.
GitHub Actions terminó con éxito: ejecución `37997133649`.
El hash del JavaScript servido por Pages coincide con el build:
`a9d444b69576f4789d0e636532efe70e74c49bd7d8913d8893d2539c908b3a3e`.

El compilador advierte de incompatibilidad WebAssembly en la dependencia image y
de una fuente Cupertino no incluida. El build JavaScript termina correctamente;
el código de la aplicación no referencia CupertinoIcons. Arranque del artefacto
servido localmente y del sitio publicado comprobado. La validación autenticada con
Administrador comprobó carga de producción, métricas, movimientos, no conformes,
destino de despacho e historial, sin registrar movimientos. Despacho también se
revisó a 390 px de ancho. Las consultas de base de datos bajo rol authenticated
y su identidad ya habían pasado.

### Corrección de Excel durante la validación autenticada

La prueba de Trazabilidad OP detectó `saveFile() has not been implemented`:
FilePicker no implementa ese guardado en web. Se centralizó la descarga XLSX
con Blob y enlace temporal; la implementación nativa conserva FilePicker.
Reportes, kardex, exportación de tabla y plantillas usan el mismo descargador.
Además, los generadores usan `encode()` en vez de `save()`, para evitar la
descarga adicional `FlutterExcel.xlsx` que produce la librería en navegador.

Artefacto final: `D:\ORBILOQ-preparacion-20261009-155918\web-produccion-excel-final`.
Commit de Pages: `4ef3fae3572f26dd7097a6fb36453dfa2da0b4fd`.
SHA256 JavaScript: `1C0534136B3D558B6FB40B51C73C0BFE62F32224AC412736E3C2291944AEAC78`.
Pasaron nuevamente 23 pruebas de reportes, trazabilidad, plantillas y kardex;
el análisis estático no encontró problemas. Se añadió una regresión web que
valida una sola descarga, nombre, MIME y contenido XLSX. El runner Chrome se
detuvo al iniciar la suite y se canceló; no se contabiliza como prueba aprobada.
La interfaz publicada completó la exportación sin el error original, pero la
herramienta del navegador no recuperó el archivo. El usuario recargó la versión
publicada y confirmó expresamente que `orbiloq_trazabilidad_op.xlsx` se descarga
y abre correctamente. GitHub Pages terminó con éxito (ejecución `37999220802`)
y el JavaScript servido coincide con el hash del artefacto final.

## Cierre del despliegue

### Edge Function comprobada mediante descarga de producción

El archivo `admin-crear-usuario.zip` descargado por el usuario contiene `index.ts`
idéntico a la versión local (normalizando saltos de línea). La única diferencia
en el `handler.mjs` anterior era la lista de roles: admitía admin/produccion/logistica.
El usuario confirmó publicar la actualización que añade despacho/seguimiento/gerencia.
No se modificaron cuentas existentes.
Las 17 pruebas locales del handler ya pasaron sobre este código preparado.

La captura de Settings aportada por el usuario confirma que en el endpoint de
producción está desactivado «Verify JWT with legacy secret» y no hay cambios
pendientes visibles. Coincide con `verify_jwt = false` del archivo local.
Conservar ese ajuste: la función valida la identidad con `auth.getUser` y exige
administrador activo. Esta evidencia acredita la configuración visible, no una
prueba autenticada de alta real de usuarios.

1. Comprobación autenticada de las vistas completada; descarga y apertura del
   Excel confirmadas por el usuario. Flujo SQL, pruebas y compilación completados.
2. Edge Function actualizada por el usuario, configuración verificada por captura
   y rechazo HTTP de llamadas sin sesión comprobado. Tablas de Realtime verificadas
   en producción; no se generaron movimientos para probar entrega de eventos.
3. Configuración acordada: próxima LE 3000, catálogos vacíos para alta en la app.
4. Respaldo final actualizado y restaurado, con los archivos de Storage comprobados.
5. Frontend anterior conservado como ZIP y commit para diagnóstico/reversión.
6. Autorización recibida; SQL aplicado y Pages publicado.
7. Todas las columnas y filas originales comparadas sin diferencias contra el
   preflight inmediatamente anterior a la migración.
8. Validación final cerrada. Antes de reanudar, cada equipo debe recargar la página
   con Ctrl+F5. No se crearon movimientos ni cuentas de prueba en producción.

Si falla SQL antes del COMMIT, la transacción debe revertirse. Si falla la app
después de aplicar SQL, mantener la pausa y diagnosticar compatibilidad: **volver
solo al frontend anterior puede ser incompatible con los nuevos permisos y RPC**.
Nunca restaurar un respaldo sobre producción activa ni perder movimientos nuevos
como mecanismo automático de reversión.
