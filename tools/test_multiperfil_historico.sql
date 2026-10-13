-- Solo ensayo: permisos y conservación de la función real aportada desde DEV.
BEGIN;
DO $$ DECLARE previo record; actual record; BEGIN
 IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo local'; END IF;
 SELECT * INTO STRICT previo FROM public.test_historico_definicion;
 SELECT * INTO STRICT actual FROM pg_proc WHERE oid='public.kardex_historico(date)'::regprocedure;
 IF actual.prosrc IS DISTINCT FROM replace(previo.prosrc,
   'rol IN (''admin'',''produccion'',''logistica'')',
   '(coalesce(roles,ARRAY[rol]) && ARRAY[''admin'',''produccion'',''logistica'']::text[])')
 OR actual.proacl IS DISTINCT FROM previo.proacl
 OR actual.prosecdef IS DISTINCT FROM previo.prosecdef
 OR actual.proconfig IS DISTINCT FROM previo.proconfig THEN
  RAISE EXCEPTION 'Se alteró algo distinto al predicado de perfiles';
 END IF;
END $$;
INSERT INTO auth.users(id,email) VALUES('94000000-0000-0000-0000-000000000010','9410@orbiloq.local');
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email)
 VALUES('TEST HISTORICO','produccion','94000000-0000-0000-0000-000000000010','9410','9410@orbiloq.local');
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000010',true);
-- Cada combinación representa roles autorizados realmente distintos.
DO $$ DECLARE caso record; resultado jsonb; permitido boolean; BEGIN
 FOR caso IN SELECT * FROM (VALUES
   (ARRAY['admin'],true),(ARRAY['produccion'],true),(ARRAY['logistica'],true),
   (ARRAY['despacho'],false),(ARRAY['seguimiento'],false),(ARRAY['gerencia'],false),
   (ARRAY['seguimiento','produccion'],true),(ARRAY['seguimiento','logistica'],true),
   (ARRAY['seguimiento','despacho'],false),(ARRAY['produccion','gerencia'],true)
 ) c(perfiles,acceso) LOOP
  UPDATE public.usuarios SET roles=caso.perfiles,rol=caso.perfiles[1] WHERE numero_usuario='9410';
  permitido:=true;
  SET LOCAL ROLE authenticated;
  BEGIN
   resultado:=public.kardex_historico((now() AT TIME ZONE 'America/Bogota')::date);
  EXCEPTION WHEN insufficient_privilege THEN permitido:=false;
  END;
  RESET ROLE;
  IF permitido IS DISTINCT FROM caso.acceso THEN RAISE EXCEPTION 'Acceso histórico incorrecto: %',caso.perfiles; END IF;
  IF permitido AND resultado->'filas'<>'[{"cantidad":2}]'::jsonb THEN RAISE EXCEPTION 'Cambió el resultado histórico'; END IF;
 END LOOP;
 -- Compatibilidad con cuentas existentes sin el campo roles asignado.
 UPDATE public.usuarios SET rol='logistica',roles=NULL WHERE numero_usuario='9410';
 SET LOCAL ROLE authenticated;
 resultado:=public.kardex_historico();
 RESET ROLE;
 IF resultado->>'activado_en' IS NULL THEN RAISE EXCEPTION 'Se perdió el acceso anterior'; END IF;
 UPDATE public.usuarios SET activo=false WHERE numero_usuario='9410';
 permitido:=true;
 SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.kardex_historico();
 EXCEPTION WHEN insufficient_privilege THEN permitido:=false;
 END;
 RESET ROLE;
 IF permitido THEN RAISE EXCEPTION 'Cuenta inactiva tiene acceso'; END IF;
END $$;
ROLLBACK;
