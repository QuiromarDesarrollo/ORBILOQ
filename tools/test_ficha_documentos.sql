BEGIN;
UPDATE public.conductor_vehiculos SET datos=datos||'{"conductor_documento":"DOC-TEST","foto_conductor":"foto-test","doc_licencia":"licencia-test","licencia_desde":"2026-01-01","marca":"Marca intacta","doc_soat":"soat-test"}'::jsonb WHERE placa='TEST02';
UPDATE public.conductor_vehiculos SET conductor_id=NULL WHERE placa='TEST02';
DO $$ DECLARE d jsonb; BEGIN
 SELECT datos INTO d FROM public.conductor_vehiculos WHERE placa='TEST02';
 IF d ?| ARRAY['conductor_documento','foto_conductor','doc_licencia','licencia_desde'] THEN RAISE EXCEPTION 'Ficha personal heredada'; END IF;
 IF d->>'marca'<>'Marca intacta' OR d->>'doc_soat'<>'soat-test' THEN RAISE EXCEPTION 'Se alteraron datos del vehículo'; END IF;
END $$;
ROLLBACK;
