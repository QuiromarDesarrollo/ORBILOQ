-- SOLO ORBILOQ-DEV. Ejecutar completo. No modifica cantidades ni movimientos.
-- Añade validación al RPC existente conservando sus permisos, bloqueos y auditoría.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $migracion$
DECLARE
  definicion text;
  ancla text := 'v_r := (d->>''recibido'')::bigint; v_d := (d->>''despachado'')::bigint;';
  validacion text := $regla$
    -- validacion_entregado_recibido_v68
    IF p_campo = 'producido' AND v_p < v_r THEN
      RAISE EXCEPTION 'No puedes dejar lo entregado por Produccion en % prendas: Logistica ya tiene % recibidas. Revisa las recepciones relacionadas antes de corregir la entrega.', v_p, v_r;
    END IF;
$regla$;
BEGIN
  IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true) <> 'igfuafcekcpugpmsoqbe' THEN
    RAISE EXCEPTION 'Solo ORBILOQ-DEV';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
    RAISE EXCEPTION 'No coincide el inventario de pruebas. Revisar el proyecto.';
  END IF;
  SELECT pg_get_functiondef(to_regprocedure('public.admin_editar_kardex(uuid,text,jsonb,text,text,uuid,uuid,boolean)')) INTO definicion;
  IF definicion IS NULL THEN RAISE EXCEPTION 'No existe el RPC de edicion administrativa.'; END IF;
  IF position('validacion_entregado_recibido_v68' in definicion)>0 THEN RETURN; END IF;
  IF (length(definicion)-length(replace(definicion,ancla,''))) / length(ancla) <> 1
     OR position('IN SHARE ROW EXCLUSIVE MODE' in definicion)=0 THEN
    RAISE EXCEPTION 'El RPC cambio; detener y revisar antes de aplicar la validacion.';
  END IF;
  EXECUTE replace(definicion,ancla,ancla || validacion);
END $migracion$;
NOTIFY pgrst,'reload schema';
COMMIT;
