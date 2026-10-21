-- EJECUCIÓN MANUAL en el SQL Editor de ORBILOQ-DEV.
-- Cambia CAMBIA_LA_PLACA por la placa que quieres reiniciar.
-- Reinicia Inicio y Fin de jornada de HOY (America/Bogota), de un solo vehículo.
-- Conserva otras fechas, actividades, archivos Drive y el kilometraje actual.
-- Guarda una copia privada de los registros retirados antes de confirmar.
BEGIN;
SET LOCAL lock_timeout = '5s';

DO $$ BEGIN
  IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
     AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe'
  THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.items_orden
    WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001'
  ) THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS respaldo_pruebas;
CREATE TABLE IF NOT EXISTS respaldo_pruebas.checklist_reiniciado (
  registro_id uuid PRIMARY KEY,
  respaldado timestamptz NOT NULL DEFAULT now(),
  placa text NOT NULL,
  fecha_jornada date NOT NULL,
  registro jsonb NOT NULL
);
ALTER TABLE respaldo_pruebas.checklist_reiniciado ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON respaldo_pruebas.checklist_reiniciado FROM PUBLIC,anon,authenticated;

CREATE TEMP TABLE resultado_reinicio_checklist (
  placa text, fecha date, registros_reiniciados integer, kilometraje_conservado integer
) ON COMMIT DROP;

DO $$
DECLARE
  placa_elegida text := 'CAMBIA_LA_PLACA'; -- ÚNICO DATO QUE DEBES CAMBIAR.
  hoy date := (now() AT TIME ZONE 'America/Bogota')::date;
  vehiculo public.conductor_vehiculos%ROWTYPE;
  cantidad integer;
BEGIN
  IF trim(placa_elegida) = '' OR placa_elegida = 'CAMBIA_LA_PLACA'
  THEN RAISE EXCEPTION 'Escribe la placa antes de ejecutar'; END IF;

  -- El guardado normal también bloquea este vehículo: evita carreras durante el reinicio.
  SELECT * INTO STRICT vehiculo FROM public.conductor_vehiculos
  WHERE upper(trim(placa)) = upper(trim(placa_elegida)) FOR UPDATE;

  WITH retirados AS (
    DELETE FROM public.conductor_registros r
    WHERE r.vehiculo_id = vehiculo.id
      AND r.tipo IN ('Inicio de jornada', 'Fin de jornada')
      AND r.datos->>'fecha' = hoy::text
    RETURNING r.*
  )
  INSERT INTO respaldo_pruebas.checklist_reiniciado
    (registro_id, placa, fecha_jornada, registro)
  SELECT r.id, vehiculo.placa, hoy, to_jsonb(r) FROM retirados r;
  -- Si falla el respaldo, PostgreSQL revierte también el borrado.
  GET DIAGNOSTICS cantidad = ROW_COUNT;
  INSERT INTO resultado_reinicio_checklist
  VALUES (vehiculo.placa, hoy, cantidad, vehiculo.km);
EXCEPTION
  WHEN no_data_found THEN RAISE EXCEPTION 'No existe la placa %', placa_elegida;
  WHEN too_many_rows THEN RAISE EXCEPTION 'La placa % no es única', placa_elegida;
END $$;

SELECT * FROM resultado_reinicio_checklist;
COMMIT;

-- Después de ejecutar: actualiza el portal y vuelve a registrar el inicio.
-- El nuevo kilometraje debe ser igual o mayor al actual; este script no lo reduce.
-- El respaldo contiene los registros completos y sus enlaces, no los archivos de Drive.
