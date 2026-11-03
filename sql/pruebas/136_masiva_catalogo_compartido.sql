-- Solo ORBILOQ-DEV. Después de 135 y del catálogo compartido v92.
-- No copia ni elimina catálogos. Contenedores antiguos conservan FK y snapshot.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='180s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF position('masiva_135_roles_compatibles' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))=0 THEN RAISE EXCEPTION 'Aplica primero 135'; END IF;
 IF to_regprocedure('public.admin_empaque_guardar_v92(uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Se requiere el catálogo compartido v92'; END IF;
END $$;
ALTER TABLE public.empaques ADD COLUMN IF NOT EXISTS peso_promedio_masiva_kg numeric;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.empaques'::regclass AND conname='empaques_promedio_masiva_valido') THEN
  ALTER TABLE public.empaques ADD CONSTRAINT empaques_promedio_masiva_valido CHECK(peso_promedio_masiva_kg IS NULL OR (peso_promedio_masiva_kg>0 AND peso_promedio_masiva_kg<=100000 AND peso_promedio_masiva_kg>=peso_neto_kg));
 END IF;
END $$;
ALTER TABLE public.masiva_cajas ALTER COLUMN empaque_id DROP NOT NULL;
ALTER TABLE public.masiva_cajas ADD COLUMN IF NOT EXISTS empaque_catalogo_id uuid REFERENCES public.empaques(id);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.masiva_cajas'::regclass AND conname='masiva_cajas_un_catalogo') THEN
  ALTER TABLE public.masiva_cajas ADD CONSTRAINT masiva_cajas_un_catalogo CHECK((empaque_id IS NULL)<>(empaque_catalogo_id IS NULL));
 END IF;
END $$;
CREATE OR REPLACE VIEW public.masiva_catalogo_empaques AS
 SELECT e.*,lower(e.categoria) AS tipo,e.largo_cm AS largo,e.ancho_cm AS ancho,e.alto_cm AS alto,
 e.peso_neto_kg AS peso_vacio,e.peso_promedio_masiva_kg AS peso_lleno,md5(to_jsonb(e)::text) AS version
 FROM public.empaques e;
REVOKE ALL ON public.masiva_catalogo_empaques FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_empaque_guardar_v92(p_id uuid,p_version text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; promedio numeric;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.empaques IN SHARE ROW EXCLUSIVE MODE;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object'
 OR p_datos->>'categoria' IS NULL OR p_datos->>'categoria' NOT IN ('CAJA','BOLSA')
 OR coalesce(length(trim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 150
 OR jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Datos del empaque invalidos.'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['largo_cm','ancho_cm','alto_cm','peso_neto_kg']) k
   WHERE jsonb_typeof(p_datos->k) IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Medidas y pesos deben ser numeros.'; END IF;
 IF p_datos ? 'peso_promedio_masiva_kg' AND p_datos->'peso_promedio_masiva_kg'<>'null'::jsonb THEN
  IF jsonb_typeof(p_datos->'peso_promedio_masiva_kg') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'El promedio de Masiva debe ser numérico'; END IF;
  promedio:=(p_datos->>'peso_promedio_masiva_kg')::numeric;
  IF promedio<=0 OR promedio>100000 OR promedio<(p_datos->>'peso_neto_kg')::numeric THEN RAISE EXCEPTION 'El promedio de Masiva debe ser mayor que cero e igual o mayor que la tara'; END IF;
 END IF;
 IF p_id IS NOT NULL THEN
   SELECT to_jsonb(e) INTO anterior FROM public.empaques e WHERE id=p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza la lista.'; END IF;
   UPDATE public.empaques SET nombre=trim(p_datos->>'nombre'),categoria=p_datos->>'categoria',
     largo_cm=(p_datos->>'largo_cm')::numeric,ancho_cm=(p_datos->>'ancho_cm')::numeric,alto_cm=(p_datos->>'alto_cm')::numeric,
     peso_promedio_masiva_kg=CASE WHEN p_datos ? 'peso_promedio_masiva_kg' THEN promedio ELSE peso_promedio_masiva_kg END,
     peso_neto_kg=(p_datos->>'peso_neto_kg')::numeric,peso_bruto_kg=NULL,activo=(p_datos->>'activo')::boolean
   WHERE id=p_id RETURNING to_jsonb(empaques.*) INTO nuevo;
 ELSE
   INSERT INTO public.empaques(nombre,categoria,largo_cm,ancho_cm,alto_cm,peso_neto_kg,peso_bruto_kg,activo,peso_promedio_masiva_kg)
   VALUES(trim(p_datos->>'nombre'),p_datos->>'categoria',(p_datos->>'largo_cm')::numeric,(p_datos->>'ancho_cm')::numeric,
     (p_datos->>'alto_cm')::numeric,(p_datos->>'peso_neto_kg')::numeric,NULL,(p_datos->>'activo')::boolean,promedio)
   RETURNING to_jsonb(empaques.*) INTO nuevo;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues)
 VALUES(auth.uid(),'empaques',(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

REVOKE ALL ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION pg_temp.masiva136_reemplazar(fuente text,patron text,nuevo text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE encontrado text;
BEGIN
 encontrado:=substring(fuente from patron);
 IF encontrado IS NULL THEN RAISE EXCEPTION 'Definición inesperada en integración del catálogo compartido'; END IF;
 RETURN replace(fuente,encontrado,nuevo);
END $$;
DO $migration$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.masiva_consultar(uuid,text,text,integer,text)'::regprocedure);
 IF position('masiva_catalogo_empaques' IN f)=0 THEN
 f:=pg_temp.masiva136_reemplazar(f,$pattern$FROM[[:space:]]+public\.masiva_empaques[[:space:]]+e[[:space:]]+WHERE[[:space:]]+e\.activo$pattern$,$new$FROM public.masiva_catalogo_empaques e WHERE e.activo$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$c\.numero[[:space:]]+AS[[:space:]]+caja,c\.empaque_id,c\.empaque_snapshot\->>'tipo'$pattern$,$new$c.numero AS caja,coalesce(c.empaque_catalogo_id,c.empaque_id) AS empaque_id,c.empaque_snapshot,c.empaque_snapshot->>'tipo'$new$);
 EXECUTE f; END IF;
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva136_catalogo_compartido' IN f)=0 THEN
 f:=pg_temp.masiva136_reemplazar(f,$pattern$asig[[:space:]]+public\.masiva_asignaciones;$pattern$,$new$v_catalogo_empaque jsonb; asig public.masiva_asignaciones;$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$WHEN[[:space:]]+'guardar_empaque'[[:space:]]+THEN[[:space:]]+INSERT[[:space:]]+INTO[[:space:]]+public\.masiva_empaques\(nombre,peso_vacio,peso_lleno,largo,ancho,alto,tipo,creado_por\)[[:space:]]+VALUES\(trim\(p_datos\->>'nombre'\),\(p_datos\->>'peso_vacio'\)::numeric,\(p_datos\->>'peso_lleno'\)::numeric,\(p_datos\->>'largo'\)::numeric,[[:space:]]+\(p_datos\->>'ancho'\)::numeric,\(p_datos\->>'alto'\)::numeric,coalesce\(p_datos\->>'tipo','caja'\),actor\)[[:space:]]+RETURNING[[:space:]]+id[[:space:]]+INTO[[:space:]]+id_nuevo;[[:space:]]+resultado:=jsonb_build_object\('id',id_nuevo\);$pattern$,$new$WHEN 'guardar_empaque' THEN RAISE EXCEPTION 'Usa el catálogo compartido de empaques de Administración o Configuración de Masiva';$new$);
 f:=pg_temp.masiva136_reemplazar(f,$pattern$SELECT[[:space:]]+\*[[:space:]]+INTO[[:space:]]+empaque[[:space:]]+FROM[[:space:]]+public\.masiva_empaques[[:space:]]+WHERE[[:space:]]+id=\(p_datos\->>'empaque_id'\)::uuid[[:space:]]+AND[[:space:]]+activo;[[:space:]]+IF[[:space:]]+empaque\.id[[:space:]]+IS[[:space:]]+NULL[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'Selecciona[[:space:]]+el[[:space:]]+tipo[[:space:]]+de[[:space:]]+empaque';[[:space:]]+END[[:space:]]+IF;[[:space:]]+SELECT[[:space:]]+\*[[:space:]]+INTO[[:space:]]+caja[[:space:]]+FROM[[:space:]]+public\.masiva_cajas[[:space:]]+WHERE[[:space:]]+operacion_id=operacion[[:space:]]+AND[[:space:]]+lista=k\.lista[[:space:]]+AND[[:space:]]+numero=n;[[:space:]]+IF[[:space:]]+k\.caja_id[[:space:]]+IS[[:space:]]+NOT[[:space:]]+NULL[[:space:]]+AND[[:space:]]+k\.caja_id[[:space:]]+IS[[:space:]]+DISTINCT[[:space:]]+FROM[[:space:]]+caja\.id[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'El[[:space:]]+kit[[:space:]]+ya[[:space:]]+pertenece[[:space:]]+a[[:space:]]+otro[[:space:]]+empaque;[[:space:]]+conserva[[:space:]]+allí[[:space:]]+sus[[:space:]]+prendas[[:space:]]+faltantes';[[:space:]]+END[[:space:]]+IF;[[:space:]]+IF[[:space:]]+caja\.id[[:space:]]+IS[[:space:]]+NOT[[:space:]]+NULL[[:space:]]+AND[[:space:]]+caja\.empaque_id<>empaque\.id[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+'Ese[[:space:]]+número[[:space:]]+ya[[:space:]]+utiliza[[:space:]]+otro[[:space:]]+tipo[[:space:]]+de[[:space:]]+empaque';[[:space:]]+END[[:space:]]+IF;[[:space:]]+IF[[:space:]]+caja\.id[[:space:]]+IS[[:space:]]+NULL[[:space:]]+THEN[[:space:]]+INSERT[[:space:]]+INTO[[:space:]]+public\.masiva_cajas\(operacion_id,lista,numero,empaque_id,empaque_snapshot,creado_por\)[[:space:]]+VALUES\(operacion,k\.lista,n,empaque\.id,to_jsonb\(empaque\),actor\)[[:space:]]+RETURNING[[:space:]]+\*[[:space:]]+INTO[[:space:]]+caja;[[:space:]]+END[[:space:]]+IF;$pattern$,$new$/* masiva136_catalogo_compartido: activos nuevos; históricos desde snapshot. */
   SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n FOR UPDATE;
   IF k.caja_id IS NOT NULL AND k.caja_id IS DISTINCT FROM caja.id THEN RAISE EXCEPTION 'El kit ya pertenece a otro empaque; conserva allí sus prendas faltantes'; END IF;
   IF caja.id IS NOT NULL THEN
    IF coalesce(caja.empaque_catalogo_id,caja.empaque_id) IS DISTINCT FROM nullif(p_datos->>'empaque_id','')::uuid THEN RAISE EXCEPTION 'Ese número ya utiliza otro tipo de empaque'; END IF;
   ELSE
    SELECT to_jsonb(e) INTO v_catalogo_empaque FROM public.masiva_catalogo_empaques e WHERE e.id=nullif(p_datos->>'empaque_id','')::uuid AND e.activo FOR SHARE;
    IF v_catalogo_empaque IS NULL THEN RAISE EXCEPTION 'Selecciona un empaque activo del catálogo compartido'; END IF;
    IF v_catalogo_empaque->>'peso_lleno' IS NULL THEN RAISE EXCEPTION 'Configura el peso promedio de Masiva para este empaque antes de utilizarlo'; END IF;
    INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_catalogo_id,empaque_snapshot,creado_por)
    VALUES(operacion,k.lista,n,(v_catalogo_empaque->>'id')::uuid,v_catalogo_empaque,actor) RETURNING * INTO caja;
   END IF;
$new$);
 EXECUTE f; END IF;
END $migration$;
NOTIFY pgrst,'reload schema';
COMMIT;
