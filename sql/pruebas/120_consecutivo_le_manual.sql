  -- SOLO PRUEBAS. Requiere 099. No recupera huecos históricos ni renumera documentos.
  BEGIN;
  SET LOCAL lock_timeout='5s';
  SET LOCAL client_min_messages=warning;
  DO $$ BEGIN
   IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
  END $$;
  CREATE TABLE IF NOT EXISTS public.le_numeros_disponibles (
   numero bigint PRIMARY KEY CHECK(numero>0), despacho_origen uuid NOT NULL REFERENCES public.despachos_oc(id),
   liberado_en timestamptz NOT NULL DEFAULT now()
  );
  ALTER TABLE public.le_numeros_disponibles ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.le_numeros_disponibles FROM PUBLIC,anon,authenticated;
  -- Solo uso interno. Todos los asignadores mantienen bloqueada la configuración.
  CREATE OR REPLACE FUNCTION public.le_tomar_numero_disponible(p_siguiente bigint) RETURNS bigint
  LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
  DECLARE n bigint;
  BEGIN
   PERFORM 1 FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
   DELETE FROM public.le_numeros_disponibles x USING public.listas_empaque l WHERE x.numero=l.numero;
   SELECT numero INTO n FROM public.le_numeros_disponibles ORDER BY numero LIMIT 1 FOR UPDATE;
   IF n IS NOT NULL THEN DELETE FROM public.le_numeros_disponibles WHERE numero=n; END IF;
   RETURN coalesce(n,p_siguiente);
  END $$;
  REVOKE ALL ON FUNCTION public.le_tomar_numero_disponible(bigint) FROM PUBLIC,anon,authenticated;
  DO $$ DECLARE f text; firma text; ancla text; BEGIN
   FOREACH firma IN ARRAY ARRAY['public.reservar_empaque_interno(uuid,boolean)','public.le_documento(text,uuid,jsonb,boolean)'] LOOP
    SELECT pg_get_functiondef(firma::regprocedure) INTO f;
    IF position('LE_DISPONIBLE_V120' IN f)>0 THEN CONTINUE; END IF;
    IF position('LE_LIBRE_V99' IN f)=0 OR position('SET siguiente=n+1' IN f)=0 THEN RAISE EXCEPTION 'Asignador inesperado: %',firma; END IF;
    IF firma='public.le_documento(text,uuid,jsonb,boolean)' THEN
     f:=replace(f,'-- LE_LIBRE_V99', E'-- LE_DISPONIBLE_V120\n IF doc.numero IS NULL THEN n:=public.le_tomar_numero_disponible(n); END IF;\n -- LE_LIBRE_V99');
    ELSE
     f:=replace(f,'-- LE_LIBRE_V99', E'-- LE_DISPONIBLE_V120\n n:=public.le_tomar_numero_disponible(n);\n -- LE_LIBRE_V99');
    END IF;
    f:=replace(f,'SET siguiente=n+1','SET siguiente=greatest(siguiente,n+1)');
    EXECUTE f;
   END LOOP;
   SELECT pg_get_functiondef('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)'::regprocedure) INTO f;
   IF position('LE_DISPONIBLE_V120' IN f)=0 THEN
    ancla:='UPDATE public.listas_empaque SET numero=p_numero WHERE despacho_id=p_id;';
    IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Confirmación administrativa inesperada'; END IF;
    f:=replace(f,ancla,ancla||$patch$
    -- LE_DISPONIBLE_V120: reserva sustituida, solo tras la confirmación exitosa de toda la transacción.
    DELETE FROM public.le_numeros_disponibles WHERE numero=p_numero;
    IF anterior<>p_numero AND d.ediciones=0 THEN
     INSERT INTO public.le_numeros_disponibles(numero,despacho_origen) VALUES(anterior,p_id) ON CONFLICT(numero) DO NOTHING;
    END IF;
  $patch$);
    EXECUTE f;
   END IF;
   SELECT pg_get_functiondef('public.le_configurar(bigint)'::regprocedure) INTO f;
   IF position('LE_DISPONIBLE_V120' IN f)=0 THEN
    ancla:='UPDATE public.lista_empaque_config SET siguiente=p_siguiente WHERE id=true;';
    IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Configuración inesperada'; END IF;
    EXECUTE replace(f,ancla,ancla||E'\n -- LE_DISPONIBLE_V120: el cambio global explícito inicia el rango solicitado.\n DELETE FROM public.le_numeros_disponibles;');
   END IF;
  END $$;
  NOTIFY pgrst,'reload schema';
  COMMIT;
