-- Ejecutar después de 142 en DEV. Todas las escrituras se revierten.
BEGIN;
DO $$
DECLARE v_ids uuid[];
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.items_orden
   WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
  RAISE EXCEPTION 'No coincide la base de pruebas';
 END IF;
 SELECT array_agg(id) INTO v_ids FROM (SELECT id FROM auth.users ORDER BY id LIMIT 2) u;
 IF coalesce(array_length(v_ids,1),0)<2 THEN
  RAISE EXCEPTION 'La prueba de aislamiento necesita dos usuarios existentes';
 END IF;
 PERFORM set_config('test.usuario_a',v_ids[1]::text,true);
 PERFORM set_config('test.usuario_b',v_ids[2]::text,true);
 PERFORM set_config('test.clave','correccion:'||gen_random_uuid()::text,true);
 PERFORM set_config('request.jwt.claim.sub',v_ids[1]::text,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE v_clave text:=current_setting('test.clave'); v_fila jsonb;
BEGIN
 v_fila:=public.despacho_borrador_guardar(v_clave,'{"paso":2,"empaques":[]}',0);
 IF (v_fila->>'version')::int<>1 THEN RAISE EXCEPTION 'Falló creación'; END IF;
 v_fila:=public.despacho_borrador_cargar(v_clave);
 IF v_fila->'datos'->>'paso'<>'2' THEN RAISE EXCEPTION 'Falló recuperación'; END IF;
 v_fila:=public.despacho_borrador_guardar(v_clave,'{"paso":3}',1);
 IF (v_fila->>'version')::int<>2 THEN RAISE EXCEPTION 'Falló actualización'; END IF;
 BEGIN
  PERFORM public.despacho_borrador_guardar(v_clave,'{"paso":1}',1);
  RAISE EXCEPTION 'No detectó conflicto';
 EXCEPTION WHEN serialization_failure THEN NULL;
 END;
 BEGIN
  PERFORM public.despacho_borrador_eliminar(v_clave,1);
  RAISE EXCEPTION 'Permitió borrar otra versión';
 EXCEPTION WHEN serialization_failure THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub',current_setting('test.usuario_b'),true);
 IF public.despacho_borrador_cargar(v_clave) IS NOT NULL THEN
  RAISE EXCEPTION 'Otro usuario pudo recuperar el borrador';
 END IF;
 IF EXISTS(SELECT 1 FROM public.despacho_borradores WHERE clave=v_clave) THEN
  RAISE EXCEPTION 'RLS no ocultó el borrador';
 END IF;
 PERFORM public.despacho_borrador_eliminar(v_clave,2);
 PERFORM set_config('request.jwt.claim.sub',current_setting('test.usuario_a'),true);
 IF public.despacho_borrador_cargar(v_clave) IS NULL THEN
  RAISE EXCEPTION 'Otro usuario pudo eliminar el borrador';
 END IF;
 BEGIN
  UPDATE public.despacho_borradores SET datos='{}' WHERE clave=v_clave;
  RAISE EXCEPTION 'Permitió escritura directa sin control de versión';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM public.despacho_borrador_eliminar(v_clave,2);
 IF public.despacho_borrador_cargar(v_clave) IS NOT NULL THEN
  RAISE EXCEPTION 'Falló eliminación';
 END IF;
END $$;
RESET ROLE;
SELECT 'OK: guardar, recuperar, actualizar, conflicto, RLS, aislamiento y eliminar' AS verificacion;
ROLLBACK;
