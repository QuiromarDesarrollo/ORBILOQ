-- Solo servidor local del ensayo.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000077','sede@local');
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email,activo)
VALUES('ADMIN SEDE','admin','00000000-0000-0000-0000-000000000077','977','sede@local',true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000077',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb := '{"nombre":"PRUEBA SEDES","direccion":"Calle 10"}'; filas jsonb;
BEGIN
  PERFORM public.le_importar_clientes(jsonb_build_array(r));
  PERFORM public.le_importar_clientes(jsonb_build_array(r || '{"sede":""}'));
  PERFORM public.le_importar_clientes(jsonb_build_array(r || '{"sede":"Norte"}'));
  PERFORM public.le_importar_clientes(jsonb_build_array(r || '{"sede":"Sur"}'));
  PERFORM public.le_importar_clientes(jsonb_build_array(r || '{"sede":"Norte"}'));
  SELECT jsonb_agg(value) INTO filas FROM jsonb_array_elements(public.le_clientes())
    WHERE value->'datos'->>'nombre'='PRUEBA SEDES';
  IF jsonb_array_length(filas)<>3 THEN RAISE EXCEPTION 'Las sedes se sobrescriben o duplican'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(filas) WHERE value->'datos'->>'direccion'<>'Calle 10')
    THEN RAISE EXCEPTION 'Direccion alterada'; END IF;
END $$;
ROLLBACK;
