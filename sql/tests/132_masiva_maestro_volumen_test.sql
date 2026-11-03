-- Solo PostgreSQL LOCAL. 30.000 artículos / 10.000 kits / 1.000 listas sintéticas.
BEGIN;
INSERT INTO auth.users(id) VALUES('13200000-0000-0000-0000-000000000101');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('13200000-0000-0000-0000-000000000101','MAESTRO-VOLUMEN','Administrador ficticio','admin',ARRAY['admin'],true);
SELECT set_config('request.jwt.claim.sub','13200000-0000-0000-0000-000000000101',true);
DO $$ DECLARE op uuid; imp uuid; lote integer; filas jsonb; r jsonb; antes timestamptz:=clock_timestamp();
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Volumen maestro","cliente":"Ficticio"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal',
  'archivo','volumen-ficticio.xlsx','total_filas',30000,'total_lotes',30))->>'importacion_id')::uuid;
 FOR lote IN 0..29 LOOP
  SELECT jsonb_agg(jsonb_build_object('lista',(((n-1)/30)+1)::text,'numero_persona',(((n-1)%30)/3)+1,
   'cedula','PERSONA-'||(((n-1)/3)+1),'nombre','Nombre ficticio '||(((n-1)/3)+1),'sku','SKU-'||((n-1)%3),
   'descripcion','Prenda ficticia '||((n-1)%3),'cantidad',1,'lider','Responsable de prueba',
   'ciudad','Ciudad '||((n-1)%15),'sede','Sede '||((n-1)%100),'direccion','Dirección '||((n-1)%100),
   'fuente',jsonb_build_object('cargo','Cargo '||((n-1)%50),'logistica','Operador ficticio','entrega','Entrega 1',
    'unidad_directiva','Unidad '||((n-1)%5),'gerencia','Gerencia '||((n-1)%4),'prenda','Blusa','regional','Regional '||((n-1)%7),
    'departamento','Departamento '||((n-1)%20),'items_kit',3,'items_lista',30,'items_direccion',300,
    'fecha_empaque_programada','2099-01-01'),'hoja_origen','BASE','fila_origen',n+1)) INTO filas
  FROM generate_series(lote*1000+1,(lote+1)*1000) n;
  PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',lote,'filas',filas));
 END LOOP;
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 IF(SELECT count(*) FROM public.masiva_base_fuente WHERE operacion_id=op)<>30000 THEN RAISE EXCEPTION 'Fuente incompleta'; END IF;
 RAISE NOTICE '132 importar y conservar fuente 30000 filas: % s',extract(epoch FROM clock_timestamp()-antes);
 antes:=clock_timestamp();
 r:=public.masiva_maestro_consultar(op,'base');
 IF r->>'total'<>'30000' OR r->'metricas'->>'kits'<>'10000' OR jsonb_array_length(r->'filas')<>30
 OR jsonb_array_length(r->'opciones'->'lista')<>1000 THEN RAISE EXCEPTION 'Base o facetas incompletas'; END IF;
 IF r->'filas'->0->>'lista'<>'1' OR r->'filas'->29->>'lista'<>'1' THEN RAISE EXCEPTION 'Orden natural primera página incorrecto'; END IF;
 RAISE NOTICE '132 base con facetas globales: % s',extract(epoch FROM clock_timestamp()-antes);
 antes:=clock_timestamp();
 r:=public.masiva_maestro_consultar(op,'base','', '{}',2,30,'',NULL,NULL,false);
 IF r->'filas'->0->>'lista'<>'2' THEN RAISE EXCEPTION 'Orden natural segunda página incorrecto'; END IF;
 RAISE NOTICE '132 segunda página sin facetas: % s',extract(epoch FROM clock_timestamp()-antes);
 antes:=clock_timestamp();
 r:=public.masiva_maestro_consultar(op,'base','', '{}',30,1000,'',NULL,NULL,false);
 IF r->>'total'<>'30000' OR jsonb_array_length(r->'filas')<>1000 OR r->'opciones'<>'{}'::jsonb
 OR r->'filas'->999->>'lista'<>'1000' THEN RAISE EXCEPTION 'Última página de exportación incorrecta'; END IF;
 RAISE NOTICE '132 exportar 1000 filas sin facetas: % s',extract(epoch FROM clock_timestamp()-antes);
 antes:=clock_timestamp();
 r:=public.masiva_maestro_consultar(op,'listado');
 IF r->>'total'<>'1000' OR r->'metricas'->>'kits'<>'10000' OR r->'metricas'->>'prendas_requeridas'<>'30000'
 OR r->'filas'->0->>'lista'<>'1' OR r->'filas'->1->>'lista'<>'2' OR r->'filas'->29->>'lista'<>'30'
 THEN RAISE EXCEPTION 'Listado agregado incorrecto'; END IF;
 RAISE NOTICE '132 listado 1000 listas con facetas: % s',extract(epoch FROM clock_timestamp()-antes);
END $$;
ROLLBACK;
