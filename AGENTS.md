# ORBILOQ: instrucciones de trabajo

## Contexto y referencias
- Aplicación operativa en Flutter/Dart. Lee el código vigente antes de proponer cambios.
- Para UX/UI, las referencias aprobadas son Producción, Bodega y Despacho. Primera prioridad de auditoría: Producción.
- Consulta `docs/diseno-orbiloq.md` para rutas, catálogo de componentes, criterios y flujo de revisión.
- Preserva modificaciones locales de otros trabajos; no reviertas ni sobrescribas archivos ajenos a tu alcance.

## Equipo de diseño
El usuario autorizó usar especialistas para solicitudes de diseño y revisar cada entrega visual:
- `orbiloq_ux`: recorridos y experiencia operativa.
- `orbiloq_ui`: composición y lenguaje visual.
- `orbiloq_componentes`: reutilización y coherencia del sistema de diseño Flutter.
- `orbiloq_revision_visual`: revisión independiente del resultado.
- `orbiloq_responsive_flujos`: adaptación por dispositivo y verificación de tareas completas en todos los módulos.
Sus definiciones están en `.codex/agents/`. El agente principal coordina y mantiene una sola respuesta al usuario.

En trabajos de diseño sustanciales, delega a los especialistas pertinentes; no es necesario ejecutar todo el equipo para un detalle pequeño. Siempre incluye revisión visual de la entrega. Cuando una tarea afecte pantallas, formularios, navegación, modales, tablas o interacción, incluye a `orbiloq_responsive_flujos` para comprobar los flujos afectados en los tamaños pertinentes; comparte evidencia con el revisor visual para evitar trabajo duplicado. Antes de delegar, asigna alcance y propiedad de archivos; solo un agente escribe un archivo a la vez. Los revisores pueden leer en paralelo. Si el cliente no expone los agentes personalizados, el coordinador debe leer sus instrucciones y aplicar las funciones de forma secuencial o mediante subagentes disponibles, indicando esa limitación. No afirme que un agente se ejecutó si solo leyó su definición.

## Autonomía acordada
- Por instrucción explícita del usuario (2026-10-30), los cambios funcionales solicitados incluyen aplicar y verificar sus ajustes necesarios en ORBILOQ-DEV. No dejar SQL preparado sin revisar las vías de acceso existentes, incluido el editor SQL autenticado de Supabase. Confirmar siempre el proyecto DEV antes de ejecutar y documentar el resultado real. Esta autorización no se extiende a producción.
- Dentro de una tarea autorizada, corrige directamente detalles menores en DEV: espacios, alineaciones, contraste, tamaños, desbordamientos y uso incorrecto de componentes, sin cambiar el flujo operativo.
- Antes de un rediseño importante, presenta una propuesta visual concreta con alcance y espera aprobación. Incluye cambios de navegación, secuencia de tareas y componentes globales con impacto amplio.
- Las aprobaciones ya dadas se mantienen; no pidas de nuevo aprobación para implementar lo acordado.
- Los agentes son herramientas de trabajo invocadas durante las tareas, no procesos de vigilancia permanente.

## Límites y verificación
- Una tarea de diseño no autoriza cambios de esquema, permisos, cálculos, inventario, movimientos ni integraciones.
- No despliegues a producción ni ejecutes migraciones por una solicitud visual. Conserva los datos de DEV y producción. No solicites ni expongas secretos para diseñar.
- Reutiliza componentes antes de duplicarlos. Documenta excepciones funcionales; coherencia no implica hacer idénticas todas las pantallas.
- Verifica las vistas afectadas y sus consumidores si cambias componentes compartidos. Ejecuta análisis y pruebas pertinentes; no agregues pruebas triviales que solo repitan la implementación.
- Informa cambios, verificación real y límites. Distingue código editado, compilación local, vista previa y despliegue.
