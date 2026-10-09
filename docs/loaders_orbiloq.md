# Loaders Orbiloq

Adaptación del diseño SVG/JS proporcionado el 09/10/2026. Colores originales: azul #1F5C8B, verde #7ED957 y blanco. No se sustituye el verde del logo por el del tema.

- Arranque web: web/orbiloq_loader.js, modo orbit. Se retira con flutter-first-frame, no con window.load; cancela RAF. A los 45 segundos informa de la demora sin simular éxito.
- WmsLoadingPanel: pantallas y consultas de secciones, órbita completa.
- WmsLoadingStrip: esperas cortas, vehículo con rebote.
- WmsLoader: mini para botones/tarjetas (56 px; botones existentes ampliados a 48 × 30).
- value entre 0 y 1: porcentaje real y barra. No se inventan porcentajes; las operaciones actuales no reportan progreso numérico y mantienen animación indeterminada. La variante está disponible para futuras operaciones con callbacks de avance.
- Movimiento reducido: animación detenida, contenido y porcentaje legibles; Flutter respeta TickerMode y libera el controlador al desmontarse.
- Se conservan barras de datos de negocio (avance de OP, volumen) porque no son indicadores de espera.

Pruebas: modos, ciclo de vida, movimiento reducido, semántica del porcentaje y renderización móvil. La captura de prueba se guarda en .dart_tool/orbiloq_loaders.png.
