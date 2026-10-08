-- Solo ensayo local: reproducir las definiciones originales de 071.
DO $$ DECLARE firma text; d text; BEGIN
 IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF;
 FOREACH firma IN ARRAY ARRAY[
  'public.ciclos_configurar(text,date,integer,integer,integer,text,integer)',
  'public.ciclos_importar(jsonb,text,boolean,text)'
 ] LOOP
  d:=pg_get_functiondef(to_regprocedure(firma));
  d:=replace(d,'UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;',
               'UPDATE public.ciclos_revision SET revision=revision+1;');
  d:=replace(d,'UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o) WHERE o.versiones IS DISTINCT FROM public.ciclos_versiones(o.inicio,o.fines,o);',
               'UPDATE public.ciclos_ordenes o SET versiones=public.ciclos_versiones(o.inicio,o.fines,o);');
  EXECUTE d;
 END LOOP;
END $$;
