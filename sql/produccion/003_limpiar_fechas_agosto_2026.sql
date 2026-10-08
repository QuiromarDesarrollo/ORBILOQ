-- PRODUCCIÓN: cxrflhgnxvomcvxzugda. Ejecutar completo en SQL Editor.
-- Antes: ejecutar 003_previsualizar_fechas_agosto_2026.sql y revisar las OP.
-- ACTUALIZADO: solo las 250 OP enumeradas por el usuario y fechas de agosto de 2026.
-- Cada columna se evalúa por separado. Sustituye la versión anterior sin filtro de OP.
-- No elimina órdenes, movimientos, fechas reales ni cantidades.
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE TEMP TABLE ops_limpieza_agosto_2026(numero_op text PRIMARY KEY) ON COMMIT DROP;
INSERT INTO ops_limpieza_agosto_2026(numero_op) VALUES
  ('25812'),('25813'),('25814'),('25815'),('25816'),('25817'),('25818'),('25819'),('25820'),('25821'),
  ('25822'),('25823'),('25825'),('25826'),('25827'),('25828'),('25829'),('25830'),('25832'),('25833'),
  ('25834'),('25835'),('25836'),('25837'),('25838'),('25839'),('25840'),('25841'),('25842'),('25843'),
  ('25844'),('25845'),('25846'),('25847'),('25848'),('25849'),('25850'),('25851'),('25852'),('25857'),
  ('25858'),('25859'),('25860'),('25861'),('25862'),('25863'),('25864'),('25865'),('25866'),('25867'),
  ('25868'),('25869'),('25870'),('25871'),('25872'),('25873'),('25874'),('25875'),('25876'),('25877'),
  ('25878'),('25879'),('25880'),('25881'),('25882'),('25883'),('25884'),('25885'),('25886'),('25887'),
  ('25888'),('25889'),('25890'),('25891'),('25892'),('25893'),('25894'),('25895'),('25896'),('25897'),
  ('25898'),('25899'),('25900'),('25901'),('25902'),('25903'),('25904'),('25905'),('25906'),('25907'),
  ('25908'),('25909'),('25910'),('25911'),('25912'),('25913'),('25914'),('25915'),('25916'),('25917'),
  ('25918'),('25919'),('25920'),('25921'),('25922'),('25923'),('25924'),('25925'),('25926'),('25927'),
  ('25928'),('25929'),('25930'),('25931'),('25932'),('25933'),('25934'),('25935'),('25936'),('25937'),
  ('25938'),('25939'),('25940'),('25941'),('25942'),('25943'),('25944'),('25945'),('25946'),('25947'),
  ('25948'),('25949'),('25950'),('25951'),('25952'),('25953'),('25954'),('25955'),('25956'),('25957'),
  ('25958'),('25959'),('25960'),('25961'),('25962'),('25963'),('25964'),('25965'),('25966'),('25967'),
  ('25968'),('25969'),('25970'),('25971'),('25972'),('25973'),('25974'),('25975'),('25976'),('25977'),
  ('25978'),('25979'),('25980'),('25981'),('25982'),('25983'),('25984'),('25985'),('25986'),('25987'),
  ('25988'),('25989'),('25990'),('25992'),('25993'),('25994'),('25995'),('25996'),('25998'),('25999'),
  ('26000'),('26001'),('26002'),('26003'),('26004'),('26005'),('26006'),('26007'),('26008'),('26009'),
  ('26010'),('26011'),('26012'),('26013'),('26014'),('26015'),('26016'),('26017'),('26018'),('26019'),
  ('26020'),('26021'),('26022'),('26023'),('26024'),('26025'),('26026'),('26027'),('26028'),('26029'),
  ('26030'),('26031'),('26032'),('26033'),('26034'),('26035'),('26036'),('26037'),('26038'),('26039'),
  ('26040'),('26041'),('26042'),('26043'),('26044'),('26045'),('26046'),('26047'),('26048'),('26049'),
  ('26050'),('26051'),('26052'),('26053'),('26054'),('26055'),('26056'),('26057'),('26058'),('26059'),
  ('26060'),('26061'),('26062'),('26063'),('26064'),('26065'),('26066'),('26067'),('26068'),('26069');
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true) <> 'cxrflhgnxvomcvxzugda' THEN
   RAISE EXCEPTION 'Proyecto incorrecto: este archivo es para producción cxrflhgnxvomcvxzugda.';
 END IF;
END $$;
-- Si la instancia no expone project_ref, verificar el proyecto en SQL Editor.
LOCK TABLE public.ordenes_produccion IN SHARE ROW EXCLUSIVE MODE;
CREATE SCHEMA IF NOT EXISTS respaldo_mantenimiento;
REVOKE ALL ON SCHEMA respaldo_mantenimiento FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS respaldo_mantenimiento.fechas_agosto_2026 (
  ejecucion timestamptz NOT NULL,
  orden_id uuid NOT NULL,
  numero_op text,
  fecha_esperada_produccion date,
  fecha_esperada_logistica date,
  PRIMARY KEY (ejecucion, orden_id)
);
ALTER TABLE respaldo_mantenimiento.fechas_agosto_2026 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON respaldo_mantenimiento.fechas_agosto_2026 FROM PUBLIC, anon, authenticated;
INSERT INTO respaldo_mantenimiento.fechas_agosto_2026
SELECT transaction_timestamp(), id, numero_op, fecha_esperada_produccion, fecha_esperada_logistica
FROM public.ordenes_produccion
WHERE numero_op IN (SELECT numero_op FROM ops_limpieza_agosto_2026)
  AND ((fecha_esperada_produccion >= DATE '2026-08-01' AND fecha_esperada_produccion < DATE '2026-09-01')
   OR (fecha_esperada_logistica >= DATE '2026-08-01' AND fecha_esperada_logistica < DATE '2026-09-01'));
UPDATE public.ordenes_produccion
SET fecha_esperada_produccion = CASE
      WHEN fecha_esperada_produccion >= DATE '2026-08-01' AND fecha_esperada_produccion < DATE '2026-09-01'
      THEN NULL ELSE fecha_esperada_produccion END,
    fecha_esperada_logistica = CASE
      WHEN fecha_esperada_logistica >= DATE '2026-08-01' AND fecha_esperada_logistica < DATE '2026-09-01'
      THEN NULL ELSE fecha_esperada_logistica END
WHERE numero_op IN (SELECT numero_op FROM ops_limpieza_agosto_2026)
  AND ((fecha_esperada_produccion >= DATE '2026-08-01' AND fecha_esperada_produccion < DATE '2026-09-01')
   OR (fecha_esperada_logistica >= DATE '2026-08-01' AND fecha_esperada_logistica < DATE '2026-09-01'))
RETURNING numero_op, fecha_esperada_produccion, fecha_esperada_logistica;
SELECT count(*) AS ordenes_corregidas,
       count(*) FILTER (WHERE fecha_esperada_produccion >= DATE '2026-08-01' AND fecha_esperada_produccion < DATE '2026-09-01') AS fechas_produccion_borradas,
       count(*) FILTER (WHERE fecha_esperada_logistica >= DATE '2026-08-01' AND fecha_esperada_logistica < DATE '2026-09-01') AS fechas_logistica_borradas
FROM respaldo_mantenimiento.fechas_agosto_2026 WHERE ejecucion = transaction_timestamp();
COMMIT;
