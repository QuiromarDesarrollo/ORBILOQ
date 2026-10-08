-- SOLO ORBILOQ-DEV. Requiere 073. Ejecutar completo. No modifica despachos antiguos.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide el inventario de pruebas'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb; resultado jsonb;
BEGIN
 -- La funcion existente verifica la cuenta activa y su rol.
 filas:=public.historial_despachos_oc(p_despues);
 SELECT coalesce(jsonb_agg(x.value||jsonb_build_object('empaques',d.empaques,'le_numero',le.numero) ORDER BY x.value->>'registro'),'[]') INTO resultado
 FROM jsonb_array_elements(filas) x LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_oc_id')::uuid LEFT JOIN public.listas_empaque le ON le.despacho_id=d.id;
 RETURN resultado;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
