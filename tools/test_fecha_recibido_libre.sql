-- Exclusivamente PostgreSQL local del ensayo.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
UPDATE public.usuarios SET rol='seguimiento' WHERE auth_id='00000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE d jsonb; id uuid; revision integer; v integer; fecha text; rechazo boolean; BEGIN
 d:=public.seguimiento_entregas_listar()->0;
 id:=(d->>'id')::uuid; revision:=(d->>'revision')::integer; v:=(d->>'version')::integer;
 IF id IS NULL THEN RAISE EXCEPTION 'Falta fixture liberado'; END IF;
 FOREACH fecha IN ARRAY ARRAY['2000-01-01','2099-12-31'] LOOP
  v:=public.seguimiento_entregas_guardar_v87(id,revision,v,jsonb_build_object('recibido',fecha,'estado','entregado'));
  IF public.seguimiento_entregas_listar()->0->>'recibido' IS DISTINCT FROM fecha THEN RAISE EXCEPTION 'No guardó fecha %',fecha; END IF;
 END LOOP;
 rechazo:=false;
 BEGIN PERFORM public.seguimiento_entregas_guardar_v87(id,revision,v,'{"recibido":"2026-02-30"}'); EXCEPTION WHEN datetime_field_overflow THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Aceptó fecha imposible'; END IF;
 rechazo:=false;
 BEGIN PERFORM public.seguimiento_entregas_guardar_v87(id,revision,v-1,'{"recibido":null}'); EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Aceptó versión obsoleta'; END IF;
 v:=public.seguimiento_entregas_guardar_v87(id,revision,v,'{"recibido":null,"estado":"en_transito"}');
 IF public.seguimiento_entregas_listar()->0->>'recibido' IS NOT NULL THEN RAISE EXCEPTION 'No limpió fecha'; END IF;
END $$;
ROLLBACK;
