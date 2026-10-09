-- Exclusivamente en la base temporal del ensayo.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('99999999-0000-0000-0000-000000000001','roles@orbiloq.local');
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email) VALUES ('Ensayo permisos','despacho','99999999-0000-0000-0000-000000000001','999999','roles@orbiloq.local');
CREATE FUNCTION pg_temp.denegado(q text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE q; EXCEPTION WHEN insufficient_privilege THEN RETURN; END;
 RAISE EXCEPTION 'Operacion no autorizada aceptada: %',q;
END $$;
SELECT set_config('request.jwt.claim.sub','99999999-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF NOT public.le_acceso() OR public.seguimiento_acceso() THEN RAISE EXCEPTION 'Permisos de Despacho incorrectos'; END IF;
 PERFORM public.historial_despachos_empaques();
 PERFORM pg_temp.denegado('SELECT public.seguimiento_confirmar(NULL,1,NULL)');
 PERFORM pg_temp.denegado('SELECT public.seguimiento_entregas_listar()');
 PERFORM pg_temp.denegado('SELECT public.seguimiento_entregas_guardar(NULL,1,0,''{}'')');
 PERFORM pg_temp.denegado('SELECT public.seguimiento_entregas_guardar_v87(NULL,1,0,''{}'')');
 IF public.seguimiento_archivo_permitido('x/1/evidencia_le/test.pdf',true) THEN RAISE EXCEPTION 'Evidencia permitida'; END IF;
END $$;
RESET ROLE;
UPDATE public.usuarios SET rol='seguimiento' WHERE auth_id='99999999-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF NOT public.le_acceso() OR NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Seguimiento pierde acceso a Despacho'; END IF;
 PERFORM public.seguimiento_entregas_listar();
 PERFORM public.historial_despachos_empaques();
END $$;
RESET ROLE;
UPDATE public.usuarios SET activo=false WHERE auth_id='99999999-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denegado('SELECT public.seguimiento_entregas_listar()');
ROLLBACK;
