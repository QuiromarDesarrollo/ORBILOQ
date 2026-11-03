-- PostgreSQL LOCAL aislado. Base con 129 aplicada y fixture de auth/usuarios.
-- 30.000 filas sintéticas, 10.000 kits, 1.000 listas. Todo termina en ROLLBACK.
BEGIN;
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000001');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('00000000-0000-0000-0000-000000000001','TEST-VOLUMEN','Admin de prueba','admin',ARRAY['admin'],true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE op uuid; imp uuid; lote integer; filas jsonb; antes timestamptz:=clock_timestamp(); resultado jsonb;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Prueba de 30000 filas","cliente":"Ficticio"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','30000_filas.xlsx','total_filas',30000,'total_lotes',30))->>'importacion_id')::uuid;
 FOR lote IN 0..29 LOOP
  SELECT jsonb_agg(jsonb_build_object('lista',(((n-1)/30)+1)::text,'numero_persona',(((n-1)%30)/3)+1,
   'cedula','PERSONA-'||(((n-1)/3)+1),'nombre','Nombre ficticio '||(((n-1)/3)+1),'sku','SKU-'||((n-1)%3),
   'descripcion','Prenda ficticia '||((n-1)%3),'cantidad',1,'lider','Responsable de prueba')) INTO filas
  FROM generate_series(lote*1000+1,(lote+1)*1000) n;
  PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',lote,'filas',filas));
 END LOOP;
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 IF (SELECT count(*) FROM public.masiva_kits WHERE operacion_id=op)<>10000 THEN RAISE EXCEPTION 'No se crearon 10000 kits'; END IF;
 IF (SELECT count(*) FROM public.masiva_listas WHERE operacion_id=op)<>1000 THEN RAISE EXCEPTION 'No se crearon 1000 listas'; END IF;
 IF (SELECT count(*) FROM public.masiva_articulos a JOIN public.masiva_kits k ON k.id=a.kit_id WHERE k.operacion_id=op)<>30000 THEN RAISE EXCEPTION 'No se crearon 30000 prendas'; END IF;
 resultado:=public.masiva_consultar(op,'kits','',200,'');
 IF jsonb_array_length(resultado->'filas')<>50 OR (resultado->>'total')::integer<>10000 THEN RAISE EXCEPTION 'Paginación incorrecta'; END IF;
 RAISE NOTICE 'MASIVA: 30000 filas / 10000 kits / 1000 listas verificadas en % segundos (base local)',extract(epoch FROM clock_timestamp()-antes);
END $$;
ROLLBACK;
