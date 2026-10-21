# Portal de conductores — master / ORBILOQ-DEV

Disponible solamente en demo local o igfuafcekcpugpmsoqbe.supabase.co.
No se habilita en producción.

## Acceso

- Administrador: menú lateral → Conductores · Pruebas, o menú de usuario → Portal del conductor.
- Cuenta solo Conductor: entra directamente al portal, sin kardex.
- Cuenta con varios perfiles: menú de usuario → Portal del conductor.
- Demo sin Supabase: vehículo ficticio y registros temporales en memoria.

## Habilitación en pruebas

1. Aplicar sql/pruebas/114_conductores.sql exclusivamente en ORBILOQ-DEV.
   La migración aborta si no encuentra el marcador de esa base de pruebas.
2. Actualizar admin-crear-usuario solo en DEV. El servidor permite el nuevo
   perfil únicamente para el hostname DEV.
3. Desde Administración, crear o editar una cuenta con perfil Conductor.
4. Asignar el vehículo a su número de usuario desde el portal del administrador.
5. Compilar/servir con las definiciones de Supabase del entorno DEV.

El equipo indicó que aplicó la migración y actualizó la función en DEV. Verificar
el acceso con una cuenta Conductor antes de usar datos reales. Producción sigue
fuera del alcance de este módulo.

## Alcance y límites

Inspecciones independientes de inicio/cierre: 27 puntos en siete categorías.
El cierre requiere inicio previo en la fecha de Bogotá. Un registro por tipo,
vehículo y día. Esta versión no admite turnos que cruzan medianoche.
El kilometraje nunca retrocede.

El portal usa menú lateral en escritorio y navegación compacta en celular, con
Inicio, Checklist, Seguimiento, Mantenimiento, Mi vehículo, Alertas e Historial.

Documentos, fechas, aceite, registro diario, tanqueos, lavado, reposición de
fluidos, mantenimiento preventivo/correctivo, siniestros y novedades.
Historial de los últimos 100 registros. No hay eliminación de registros.
Asignaciones auditadas. Los próximos controles quedan en el historial.

Alertas internas al cargar/actualizar: documentos próximos a vencer (30 días),
vencidos y aceite a 1.000 km o menos. No hay todavía push, correo ni avisos con
la app cerrada.

## Fotos

Cada campo de evidencia ofrece cámara del navegador, selección de archivo,
vista previa y subida a Drive. El conductor confirma «Subir a Drive» y luego
«Guardar registro». Se conserva la opción de pegar un enlace existente.
El seguimiento diario separa frontal, lateral, trasera y tablero. El cierre
con siniestro tiene evidencia propia. También se incluyen documentos,
inspecciones, tanqueos, lavado, fluidos, mantenimientos y novedades.

Destino fijo: TRANSPORTE (`1KCgLHDHkiek82eyTwpdjfPACmRGC1l7W`). Solo enlaces
HTTPS en la base: las fotos/archivos viajan del navegador directamente a Drive,
sin pasar por Storage ni por el cuerpo de una Edge Function. Supabase autoriza
la sesión con JWT y RLS. No se entrega ningún token OAuth de Google al cliente.

Cámara mediante getUserMedia: requiere HTTPS (o localhost), permiso del usuario
y cámara disponible; prefiere la trasera del celular. Se detiene al cerrar,
capturar o salir. En compilaciones nativas se ofrece selección de archivos y
se informa que la cámara está disponible en el portal web. La app actual es web.
Fotos JPG/PNG/WebP se orientan, reducen a 1600 px y convierten a JPEG calidad 82
sin EXIF. Máximo de entrada 10 MB / 40 megapíxeles; PDF, DOCX y XLSX hasta 10 MB.
No se admiten HEIC ni vídeos. Cada campo conserva un archivo; se puede pegar
un enlace a carpeta cuando se requieren múltiples evidencias.

La selección persiste al desplazarse por el formulario. Los fallos de red
permiten reintentar la misma sesión de Drive sin crear otra mientras el formulario
sigue abierto. Cerrar/recargar descarta la selección local. Si se cancela un
registro después de subir, el archivo permanece en TRANSPORTE; no se elimina
automáticamente. Cambiar una evidencia tampoco elimina el archivo anterior.

**Pendiente de activación:** faltan Google Cloud/OAuth y desplegar la función
`conductor-evidencia` únicamente en DEV. No se han creado credenciales ni hecho
una carga real. Ver [guía de activación](conductor-drive-configuracion.md).

## Seguridad y verificación

RLS limita lecturas a vehículos asignados o administrador activo. No hay
INSERT/UPDATE/DELETE directo para usuarios: RPC verifica perfil, asignación,
kilometraje, checklist, duplicados y datos. Actor obtenido de Auth.
Las novedades requieren descripción. El resultado no autoriza legalmente la ruta;
los criterios de bloqueo críticos deben acordarse con coordinación.

Pruebas: test/conductor_test.dart, test/usuarios_multiperfil_test.dart,
test/roles_logistica_test.dart, tools/test_admin_usuarios.mjs.
tools/ensayar_conductor.ps1 verifica con PostgreSQL local desechable y fixture
mínimo; no es una copia de producción.
