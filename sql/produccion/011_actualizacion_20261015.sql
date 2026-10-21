-- CANDIDATO incremental 2026-10-15. Ensayar sobre respaldo antes de aplicar.
-- SOLO producción cxrflhgnxvomcvxzugda. No copia datos DEV ni reinicia consecutivos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regclass('public.facturacion_le') IS NOT NULL OR to_regprocedure('public.dashboard_despachos_mensuales(date,date,text,timestamptz)') IS NOT NULL THEN RAISE EXCEPTION 'Actualizacion ya iniciada/instalada'; END IF;
 IF to_regprocedure('public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Falta despliegue del 13'; END IF;
END $$;
DO $baseline$ BEGIN
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_guardar(text, uuid, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28d15223e73f3b181d881e592f7b1cda' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_guardar(text, uuid, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_listar(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '15ca446753397c8af4df941f3a90ab8b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_listar(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_contexto_edicion(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM '92eed44998dfea36a342ff6f55f06d71' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_contexto_edicion(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_editar_kardex(uuid, text, jsonb, text, text, uuid, uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '296b65ec649fbcc2d4d07a0f1b25e9d8' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_editar_kardex(uuid, text, jsonb, text, text, uuid, uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_editar_recepciones(uuid, text, jsonb, text, text, jsonb, uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'da6652aac9b24a517c19da8a64bb895c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_editar_recepciones(uuid, text, jsonb, text, text, jsonb, uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_eliminar_linea(uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '058c432424ea51fda0232a875cdec68d' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_eliminar_linea(uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_empaque_guardar(uuid, text, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '94f3b7d549cbbc426ae543be67aa7450' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_empaque_guardar(uuid, text, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_empaque_guardar_v92(uuid, text, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f28a63698de891897a6d2596538593fa' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_empaque_guardar_v92(uuid, text, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_es_admin()')), E'\r\n', E'\n')) IS DISTINCT FROM '5ce1b98b713dde03a81a64f4dfa459a9' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_es_admin()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_exportar_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '28dda8245e0bba92af1167368d9f9f8a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_exportar_kardex()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_importar_kardex(text, text, jsonb, text, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e39d438c21344efac59b39473d5872f7' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_importar_kardex(text, text, jsonb, text, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_pagina(text, text, timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM '5d3c83e1c43b8f8ed161eddce8284131' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_reporte_pagina(text, text, timestamp with time zone)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_resumen()')), E'\r\n', E'\n')) IS DISTINCT FROM 'caab38bd9c4433368a82fa02d33c8c35' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_reporte_resumen()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_sincronizar_envios_corregidos()')), E'\r\n', E'\n')) IS DISTINCT FROM '852847fd778020175d6fc04f9da74efa' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_sincronizar_envios_corregidos()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_trazabilidad_base_v90(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '6e1a06e16390b6df2bc4fc6d283afa08' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_trazabilidad_base_v90(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_trazabilidad_op(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '9e4a7aacc9e330794e4a3033542b3cce' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_trazabilidad_op(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_alta_pendiente(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '58cd4920a2523e673613349dc15d0be1' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_alta_pendiente(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_guardar(uuid, text, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'c5b9fe6d84e5f8247527461b2dfc9d45' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_guardar(uuid, text, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_guardar_roles(uuid, text, text[], boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fad70b8bb2843c410d47029aa45bfda5' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_guardar_roles(uuid, text, text[], boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_registrar(uuid, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a43577d177c2e1853931ffa184c624f2' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_registrar(uuid, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_registrar_roles(uuid, uuid, text, text, text[])')), E'\r\n', E'\n')) IS DISTINCT FROM 'd288cd8a1db90761d4e7003da1f519d8' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_registrar_roles(uuid, uuid, text, text, text[])'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_version_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '15c1d98c07bf0877b8b91023c7e90a84' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_version_kardex()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_aliado(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '291208d88384db9e9cfd1a841c1a1e14' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_aliado(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_logistica(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'decb7a3991e2da1f9bfa42aeb4f5b5fc' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_logistica(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_produccion(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '33cee1f3bdbca4529b60594d3b555f0a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_produccion(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.cerrar_lote_item_con_faltante(uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '66e3a5b10c1180de93c1bd7a02b2471c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.cerrar_lote_item_con_faltante(uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_configurar(text, date, integer, integer, integer, text, integer)')), E'\r\n', E'\n')) IS DISTINCT FROM '1eed144861f60867a3748ad449c7de57' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_configurar(text, date, integer, integer, integer, text, integer)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_estado()')), E'\r\n', E'\n')) IS DISTINCT FROM 'ff6f158f4252b9b6d19a47a3892bb5b1' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_estado()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_importar(jsonb, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f05027656568da3e694825c717155f0f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_importar(jsonb, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_pagina(text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'dd068044c4d70cb1412e583bda6d5a00' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_pagina(text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_versiones(date, jsonb, ciclos_ordenes)')), E'\r\n', E'\n')) IS DISTINCT FROM '4c3100b89b0094a44903d623d9d6a5fa' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_versiones(date, jsonb, ciclos_ordenes)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.corregir_despacho_le(uuid, text, text, text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a5a8ac028ba2110b385cd337f40bb35f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.corregir_despacho_le(uuid, text, text, text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.corregir_despacho_le_base_v81(uuid, text, text, text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '9e06779128fc8ffb38729e5d56eebe6d' THEN RAISE EXCEPTION 'Cambió función: %', 'public.corregir_despacho_le_base_v81(uuid, text, text, text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.crear_lote(jsonb, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '995effb7257694e56a04201b945ece84' THEN RAISE EXCEPTION 'Cambió función: %', 'public.crear_lote(jsonb, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar(uuid, integer, uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fdf4c441ccc75070926e9f92b41b6180' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar(uuid, integer, uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc(text, text, text, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '30ebe63dfca07528dbd72a00934b7968' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc(text, text, text, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_bultos(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '1dcf533fdc7288d1bd3790fbc8ab18bb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_bultos(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_bultos_base_v81(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '1188e33f1d1fe1aa41d4a4aecbd73132' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_bultos_base_v81(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_empaques(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '5376f0437b2ac8682b6896b675260080' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_empaques(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_prendas_empaques(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '30fdae3265684f3b687feb10e0814b03' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_prendas_empaques(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despacho_para_corregir(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fbbf1cac0ae1415ec1ed986cffb2c4a9' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despacho_para_corregir(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.destinatarios_para_empaque()')), E'\r\n', E'\n')) IS DISTINCT FROM '2c01bf620442878d0a8e6f5fa232d347' THEN RAISE EXCEPTION 'Cambió función: %', 'public.destinatarios_para_empaque()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.empaques_listar(boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '1bc6149a501a215f9867ffe79e1c32c6' THEN RAISE EXCEPTION 'Cambió función: %', 'public.empaques_listar(boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '8ea0ccba98e601d04d9a72736e48fcda' THEN RAISE EXCEPTION 'Cambió función: %', 'public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5e763479636c23d70bbb78c66d513d06' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario_v90(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a006f4d07a96e584503ffb248c61dedd' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario_v90(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario_v92(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'ae6ae0b76d6a1800bd3d4b458a707f07' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario_v92(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_base_v90(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd0698d67a3aca7667d259ed154ece072' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_base_v90(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_empaques(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '858e930ea0863fbce40243dad883f673' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_empaques(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_oc(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e11d59b90d3f483b0e08da945c6b801f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_oc(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_fechas_esperadas(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '8d27b01ae790c9238d56e6c2fd6c6e6c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_fechas_esperadas(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5478b89211abbd38a98970277c06ba72' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_acceso()')), E'\r\n', E'\n')) IS DISTINCT FROM '311dd52126630853d55866628e44cabb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_acceso()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_clientes()')), E'\r\n', E'\n')) IS DISTINCT FROM '99f4492d129d70280068540c1831e2db' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_clientes()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_configurar(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b346b4b8680c6ad7ea430b8314ea4ff3' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_configurar(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_documento(text, uuid, jsonb, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '0cc9e6d79d135800fca147350b4891a9' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_documento(text, uuid, jsonb, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_importar_clientes(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '2f3f6274a9c33af3a35c173e3fa75b2e' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_importar_clientes(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_importar_clientes_internacionales(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '69250d480d60aa8c0edec01afb1c0f8c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_importar_clientes_internacionales(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'c73bbbf2d2e58e7ecbcd19a5cc672ae6' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme(uuid, integer, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'bd4fd0b839e8c7fee97e434b8e914264' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme(uuid, integer, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme_aliado(uuid, integer, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'ed4a741d782846b5ff001b4728371c91' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme_aliado(uuid, integer, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.proteger_reservas()')), E'\r\n', E'\n')) IS DISTINCT FROM '991d83e8ff92205f9ddd46df0f84f880' THEN RAISE EXCEPTION 'Cambió función: %', 'public.proteger_reservas()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.puede_ver_dashboards()')), E'\r\n', E'\n')) IS DISTINCT FROM '00f5da112898ca71af257b3a87214473' THEN RAISE EXCEPTION 'Cambió función: %', 'public.puede_ver_dashboards()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid, integer, uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '268d31774c5a01f7fcb6ff5d2a0009a0' THEN RAISE EXCEPTION 'Cambió función: %', 'public.recibir_lote_item(uuid, integer, uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid, integer, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '39b65fb0d73e845cc5d9c13375672420' THEN RAISE EXCEPTION 'Cambió función: %', 'public.recibir_lote_item(uuid, integer, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '6d89833f5384b88acab0ef96287bc4b2' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_no_conforme(uuid, integer, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '1d85a97b6551685abc04a8c86607d883' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_no_conforme(uuid, integer, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_sobrante(uuid, uuid, integer, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '376a6837145f08aacd9d0da6ff18c00a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_sobrante(uuid, uuid, integer, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.reservar_empaque_interno(uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd162072cc031fb5f3f5b28f8ec6cb800' THEN RAISE EXCEPTION 'Cambió función: %', 'public.reservar_empaque_interno(uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.resolver_sobrante(uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '0fd3b05d95187718351026464e9b8577' THEN RAISE EXCEPTION 'Cambió función: %', 'public.resolver_sobrante(uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_acceso()')), E'\r\n', E'\n')) IS DISTINCT FROM 'cb4b12feeb49732420426337d680e5ac' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_acceso()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_archivo_permitido(text, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'daa8d6f9758801965b440f30907d5402' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_archivo_permitido(text, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_confirmar(uuid, integer, uuid, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '40deb7aec7619fd4ca03d88cc82dc411' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_confirmar(uuid, integer, uuid, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_guardar(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '88494fcd3e3a86c1700ef3ea4c0686bb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_guardar(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_guardar_v87(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '73edae96e2c62b78c711b51ccfb18511' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_guardar_v87(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_listar(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM '68d3416ae5da6167153ce33deeb0a648' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_listar(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_guardar_base_v87(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '7dfc3f0301ca785f7d85d0780dd274b8' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_guardar_base_v87(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_listar_base_v87(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a16ef2c28a5713c9f323c51c3ccc0b90' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_listar_base_v87(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.traza_fecha_empaque()')), E'\r\n', E'\n')) IS DISTINCT FROM '666ca5e76493588aef91855e1e032e34' THEN RAISE EXCEPTION 'Cambió función: %', 'public.traza_fecha_empaque()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.usuario_roles_normalizar(text[])')), E'\r\n', E'\n')) IS DISTINCT FROM '1889b40cfcc83faca37bfb3477d5499c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.usuario_roles_normalizar(text[])'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.validar_reservas_item(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'ced288b1bd8dbf7a53c0a7062fab06c6' THEN RAISE EXCEPTION 'Cambió función: %', 'public.validar_reservas_item(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.validar_stock_no_conforme(uuid, integer)')), E'\r\n', E'\n')) IS DISTINCT FROM '57af750f91737187f2a5da8f855c16a4' THEN RAISE EXCEPTION 'Cambió función: %', 'public.validar_stock_no_conforme(uuid, integer)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_cuenta_activa()')), E'\r\n', E'\n')) IS DISTINCT FROM '22ed4e3986b546d43054c2014765043f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_cuenta_activa()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_cuenta_operativa()')), E'\r\n', E'\n')) IS DISTINCT FROM 'f55d1ba8a9fea130289af677367a7bc1' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_cuenta_operativa()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_nombre_actor()')), E'\r\n', E'\n')) IS DISTINCT FROM 'dafe4b70701bdf326cdf2bf0edc80652' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_nombre_actor()'; END IF;
END $baseline$;
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY,columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text,fila jsonb) ON COMMIT DROP;
CREATE TEMP TABLE previo_secuencias ON COMMIT DROP AS SELECT to_jsonb(s) fila FROM pg_sequences s WHERE schemaname='public';
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth','storage') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  IF t.nspname IN ('public','respaldo_mantenimiento') THEN EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname); END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;

-- 095_admin_destinatarios.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
-- Requiere 094. Conserva UUID e instantáneas de despachos ya registrados.
CREATE OR REPLACE FUNCTION public.admin_destinatario_editar(p_id uuid, p_original jsonb, p_datos jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE anterior jsonb; k text; campo text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 SELECT datos INTO anterior FROM public.destinatarios_empaque WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El destinatario ya no existe. Actualiza el catálogo.'; END IF;
 IF anterior IS DISTINCT FROM p_original THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo antes de editar.'; END IF;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR length(p_datos::text)>10000 OR coalesce(length(btrim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'Datos del destinatario inválidos';
 END IF;
 FOR campo IN SELECT jsonb_object_keys(p_datos) LOOP
  IF jsonb_typeof(p_datos->campo) IS DISTINCT FROM 'string' OR length(p_datos->>campo)>500 THEN RAISE EXCEPTION 'Campo inválido: %',campo; END IF;
 END LOOP;
 IF coalesce(p_datos->>'tipo_destinatario','nacional') NOT IN ('nacional','internacional') THEN RAISE EXCEPTION 'Tipo de destinatario inválido'; END IF;
 IF p_datos->>'tipo_destinatario'='internacional' THEN
  FOREACH campo IN ARRAY ARRAY['email','via','tipo_carga','embalaje','puerto_embarque','pais_origen','puerto_destino','pais_destino','termino_negociacion'] LOOP
   IF coalesce(length(btrim(p_datos->>campo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Completa el campo internacional: %',campo; END IF;
  END LOOP;
  k:=md5(jsonb_build_array('internacional',p_datos->>'nombre',p_datos->>'nit',p_datos->>'direccion',p_datos->>'ciudad',p_datos->>'contacto',p_datos->>'telefono',p_datos->>'celular',coalesce(nullif(btrim(p_datos->>'sede'),''),''))::text);
 ELSE
  k:=md5(jsonb_build_array(p_datos->>'nombre',p_datos->>'nit',p_datos->>'direccion',p_datos->>'ciudad',p_datos->>'contacto',p_datos->>'telefono',p_datos->>'celular')::text);
  IF nullif(btrim(p_datos->>'sede'),'') IS NOT NULL THEN k:=md5(jsonb_build_array(k,btrim(p_datos->>'sede'))::text); END IF;
 END IF;
 UPDATE public.destinatarios_empaque SET datos=p_datos,clave=k WHERE id=p_id;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Ya existe un destinatario con esos mismos datos. No se combinaron los registros.';
END $$;
CREATE OR REPLACE FUNCTION public.admin_destinatario_eliminar(p_id uuid, p_original jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE anterior jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 SELECT datos INTO anterior FROM public.destinatarios_empaque WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El destinatario ya no existe. Actualiza el catálogo.'; END IF;
 IF anterior IS DISTINCT FROM p_original THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo antes de eliminar.'; END IF;
 DELETE FROM public.destinatarios_empaque WHERE id=p_id;
EXCEPTION WHEN foreign_key_violation THEN
 RAISE EXCEPTION 'No se puede eliminar: tiene despachos vinculados. Puedes editarlo; los documentos existentes conservarán sus datos.';
END $$;
REVOKE ALL ON FUNCTION public.admin_destinatario_editar(uuid,jsonb,jsonb),public.admin_destinatario_eliminar(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_destinatario_editar(uuid,jsonb,jsonb),public.admin_destinatario_eliminar(uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';


-- 096_entregado_con_novedad_dashboard.sql
-- ORBILOQ-DEV. Requiere estados de Seguimiento y acceso a dashboards (071, 086).
-- Conserva estados, cantidades y movimientos existentes. Ejecutar completo.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
ALTER TABLE public.seguimiento_entregas DROP CONSTRAINT IF EXISTS seguimiento_estado_valido;
ALTER TABLE public.seguimiento_entregas ADD CONSTRAINT seguimiento_estado_valido
 CHECK(estado IN ('en_transito','entregado','entregado_con_novedad','devuelto_cliente','devolucion_parcial'));

CREATE OR REPLACE FUNCTION public.dashboard_despachos_mensuales(
 p_desde date, p_hasta date, p_cliente text DEFAULT NULL, p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN
  RAISE EXCEPTION 'Acceso exclusivo de Administracion y Gerencia' USING ERRCODE='42501';
 END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde
 OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
  WITH meses AS (
   SELECT generate_series(date_trunc('month',p_desde::timestamp),date_trunc('month',p_hasta::timestamp),interval '1 month')::date mes
  ), datos AS (
   SELECT date_trunc('month',d.fecha AT TIME ZONE 'America/Bogota')::date mes,
    count(*) total,
    count(*) FILTER(WHERE s.estado='entregado') sin_contratiempo,
    count(*) FILTER(WHERE s.estado='entregado_con_novedad') con_contratiempo
   FROM public.despachos_oc d
   LEFT JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
   WHERE d.fase='despachado'
    AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
    AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
    AND d.fecha<=least(p_corte,now())
    AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
    AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
   GROUP BY 1
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('mes',m.mes,'total',coalesce(d.total,0),
   'sin_contratiempo',coalesce(d.sin_contratiempo,0),'con_contratiempo',coalesce(d.con_contratiempo,0)) ORDER BY m.mes),'[]'::jsonb)
  FROM meses m LEFT JOIN datos d USING(mes)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_despachos_mensuales(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_despachos_mensuales(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';


-- 097_facturacion_le.sql
-- ORBILOQ-DEV. Requiere Seguimiento, roles y datos ERP existentes.
-- No altera inventario, estados de entrega ni documentos históricos.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE TABLE IF NOT EXISTS public.facturacion_le(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id),
 revision integer NOT NULL,
 remision text NOT NULL DEFAULT '' CHECK(length(remision)<=150),
 id_oc text NOT NULL DEFAULT '' CHECK(length(id_oc)<=150),
 version integer NOT NULL DEFAULT 1,
 actualizado_en timestamptz NOT NULL DEFAULT now(),
 actualizado_por uuid NOT NULL REFERENCES auth.users(id),
 PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.facturacion_le ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.facturacion_le FROM PUBLIC,anon,authenticated;

-- Uso interno: la fecha de recibido en la revision vigente habilita la tarjeta.
CREATE OR REPLACE FUNCTION public.facturacion_le_dato(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 WITH base AS (
 SELECT d.id,d.ediciones revision,d.cliente,l.numero le,
 coalesce(nullif(trim(d.oc_documento),''),d.oc,'') oc,
 s.recibido,s.version version_seguimiento,coalesce(f.version,0) version,
 coalesce(f.remision,l.datos->>'remision','') remision,
 coalesce(f.id_oc,CASE WHEN cardinality(ids.valores)=1 THEN ids.valores[1] ELSE '' END) id_oc,
 coalesce(to_jsonb(ids.valores),'[]'::jsonb) ids_erp
 FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id
 JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 LEFT JOIN public.facturacion_le f ON f.despacho_id=d.id AND f.revision=d.ediciones
 LEFT JOIN LATERAL (
  SELECT array_agg(DISTINCT o.oc_id_erp::text ORDER BY o.oc_id_erp::text) FILTER(WHERE o.oc_id_erp IS NOT NULL) valores
  FROM jsonb_array_elements(coalesce(d.detalle,'[]'::jsonb)) e
  JOIN public.items_orden i ON i.id::text=e->>'item_id'
  JOIN public.ordenes_produccion o ON o.id=i.orden_id
 ) ids ON true
 WHERE d.id=p_id AND d.fase='despachado' AND s.recibido IS NOT NULL AND l.numero IS NOT NULL
 ) SELECT to_jsonb(b)||jsonb_build_object('completa',length(trim(b.remision))>0 AND length(trim(b.id_oc))>0 AND length(trim(b.oc))>0) FROM base b
$$;
REVOKE ALL ON FUNCTION public.facturacion_le_dato(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.facturacion_le_listar(p_completa boolean DEFAULT false,p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Administrador' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.dato ORDER BY x.numero DESC) FROM (
  SELECT l.numero, public.facturacion_le_dato(l.despacho_id) dato FROM public.listas_empaque l
  WHERE (p_antes IS NULL OR l.numero<p_antes)
   AND (public.facturacion_le_dato(l.despacho_id)->>'completa')::boolean=p_completa
  ORDER BY l.numero DESC LIMIT 200
 ) x),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.facturacion_le_guardar(p_id uuid,p_revision integer,p_version integer,p_version_seguimiento integer,p_remision text,p_id_oc text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; v integer; s public.seguimiento_entregas%rowtype;
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Se requiere Seguimiento o Administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.fase<>'despachado' OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambió. Actualiza Facturación'; END IF;
 SELECT * INTO s FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision FOR UPDATE;
 IF NOT FOUND OR s.recibido IS NULL OR s.version IS DISTINCT FROM p_version_seguimiento THEN RAISE EXCEPTION 'Cambió el seguimiento o falta fecha de entrega. Actualiza Facturación'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.listas_empaque WHERE despacho_id=p_id AND numero IS NOT NULL) THEN RAISE EXCEPTION 'Falta la lista de empaque'; END IF;
 SELECT version INTO v FROM public.facturacion_le WHERE despacho_id=p_id AND revision=p_revision;
 IF coalesce(v,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Otra persona editó la facturación. Recarga antes de guardar'; END IF;
 IF length(coalesce(p_remision,''))>150 OR length(coalesce(p_id_oc,''))>150 THEN RAISE EXCEPTION 'Máximo 150 caracteres por campo'; END IF;
 INSERT INTO public.facturacion_le(despacho_id,revision,remision,id_oc,version,actualizado_por)
 VALUES(p_id,p_revision,trim(coalesce(p_remision,'')),trim(coalesce(p_id_oc,'')),coalesce(v,0)+1,auth.uid())
 ON CONFLICT(despacho_id,revision) DO UPDATE SET remision=excluded.remision,id_oc=excluded.id_oc,version=excluded.version,actualizado_por=excluded.actualizado_por,actualizado_en=now();
 RETURN coalesce(v,0)+1;
END $$;
REVOKE ALL ON FUNCTION public.facturacion_le_listar(boolean,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.facturacion_le_guardar(uuid,integer,integer,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.facturacion_le_listar(boolean,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facturacion_le_guardar(uuid,integer,integer,integer,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';


-- 098_dashboard_facturacion_semanal.sql
-- Reporte semanal de facturacion. Requiere 097. Solo lectura de datos existentes.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.dashboard_facturacion_semanal(
 p_desde date, p_hasta date, p_cliente text DEFAULT NULL, p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso al dashboard' USING ERRCODE='42501'; END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
 WITH semanas AS (
 SELECT generate_series(date_trunc('week',p_desde::timestamp),date_trunc('week',least(p_hasta,(least(p_corte,now()) AT TIME ZONE 'America/Bogota')::date)::timestamp),interval '1 week')::date semana
 ), datos AS (
 SELECT date_trunc('week',d.fecha AT TIME ZONE 'America/Bogota')::date semana,
 count(*) total,
 count(*) FILTER(WHERE coalesce((public.facturacion_le_dato(d.id)->>'completa')::boolean,false)) completas
 FROM public.despachos_oc d
 WHERE d.fase='despachado'
 AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<=least(p_corte,now())
 AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
 AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
 GROUP BY 1
 ) SELECT coalesce(jsonb_agg(jsonb_build_object('semana',s.semana,'total',coalesce(d.total,0),'completas',coalesce(d.completas,0),'pendientes',coalesce(d.total,0)-coalesce(d.completas,0)) ORDER BY s.semana),'[]'::jsonb)
 FROM semanas s LEFT JOIN datos d USING(semana)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_facturacion_semanal(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_facturacion_semanal(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';


-- 099_opciones_admin_le.sql
-- Solo desarrollo. Requiere 092. Opciones administrativas por LE.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;

CREATE TABLE IF NOT EXISTS public.le_ajustes_admin(
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id),revision integer NOT NULL,
 numero_anterior bigint,numero_solicitado bigint,fecha_solicitada date,
 fecha_registro timestamptz NOT NULL DEFAULT now(),actor uuid NOT NULL,
 resultado jsonb NOT NULL,PRIMARY KEY(despacho_id,revision)
);
ALTER TABLE public.le_ajustes_admin ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.le_ajustes_admin FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_confirmar_le(p_id uuid,p_revision integer,p_destinatario uuid,p_datos jsonb DEFAULT '{}',p_numero bigint DEFAULT NULL,p_fecha date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE d public.despachos_oc%rowtype; previo public.le_ajustes_admin%rowtype; r jsonb; anterior bigint; fecha_operativa timestamptz;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF p_numero IS NOT NULL AND (p_numero<1 OR p_numero>9007199254740991) THEN RAISE EXCEPTION 'Numero LE invalido'; END IF;
 IF p_fecha IS NOT NULL AND (p_fecha<'2000-01-01'::date OR p_fecha>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'Fecha de salida invalida'; END IF;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO d FROM public.despachos_oc WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR d.ediciones IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La LE cambio. Actualiza antes de confirmar'; END IF;
 SELECT * INTO previo FROM public.le_ajustes_admin WHERE despacho_id=p_id AND revision=p_revision;
 IF FOUND THEN
  IF previo.numero_solicitado IS DISTINCT FROM p_numero OR previo.fecha_solicitada IS DISTINCT FROM p_fecha THEN RAISE EXCEPTION 'Salida ya confirmada con otros datos'; END IF;
  RETURN previo.resultado;
 END IF;
 IF d.fase<>'empacado' THEN RAISE EXCEPTION 'Solo se pueden ajustar LE por liberar'; END IF;
 PERFORM 1 FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
 SELECT numero INTO anterior FROM public.listas_empaque WHERE despacho_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Falta la LE reservada'; END IF;
 IF p_numero IS NOT NULL THEN
  IF EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=p_numero AND despacho_id<>p_id) THEN RAISE EXCEPTION 'El numero LE ya existe'; END IF;
  UPDATE public.listas_empaque SET numero=p_numero WHERE despacho_id=p_id;
 END IF;
 r:=public.seguimiento_confirmar(p_id,p_revision,p_destinatario,p_datos);
 IF p_fecha IS NOT NULL THEN
  fecha_operativa:=(p_fecha+time '12:00') AT TIME ZONE 'America/Bogota';
  UPDATE public.despachos_oc SET fecha=fecha_operativa WHERE id=p_id;
  -- Solo la salida generada en esta transaccion; no toca correcciones previas.
  UPDATE public.movimientos SET fecha=fecha_operativa WHERE despacho_oc_id=p_id AND tipo='despacho' AND cantidad>0 AND fecha=transaction_timestamp();
  UPDATE public.listas_empaque SET datos=jsonb_set(datos,'{fecha}',to_jsonb(fecha_operativa)) WHERE despacho_id=p_id;
  r:=jsonb_set(r,'{fecha}',to_jsonb(fecha_operativa));
 END IF;
 INSERT INTO public.le_ajustes_admin(despacho_id,revision,numero_anterior,numero_solicitado,fecha_solicitada,actor,resultado)
 VALUES(p_id,p_revision,anterior,p_numero,p_fecha,auth.uid(),r);
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date) TO authenticated;
-- Mantiene el siguiente global. Si un numero manual ya lo ocupa, el automatico
-- avanza solo hasta el primer numero libre cuando le corresponda asignar.
DO $$ DECLARE firma text; f text; ancla text:='INSERT INTO public.listas_empaque(despacho_id,numero,datos)'; BEGIN
 FOREACH firma IN ARRAY ARRAY['public.reservar_empaque_interno(uuid,boolean)','public.le_documento(text,uuid,jsonb,boolean)'] LOOP
  SELECT pg_get_functiondef(firma::regprocedure) INTO f;
  IF position('LE_LIBRE_V99' IN f)=0 THEN
   IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Revisar asignacion de numero en %',firma; END IF;
   f:=replace(f,ancla,$x$-- LE_LIBRE_V99
   WHILE EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n) LOOP n:=n+1; END LOOP;
   INSERT INTO public.listas_empaque(despacho_id,numero,datos)$x$);
   IF firma='public.le_documento(text,uuid,jsonb,boolean)' THEN
    f:=replace(f,'WHILE EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n)', 'WHILE doc.numero IS NULL AND EXISTS(SELECT 1 FROM public.listas_empaque WHERE numero=n)');
   END IF;
   EXECUTE f;
  END IF;
 END LOOP;
END $$;
DO $$ DECLARE f text; ancla text:='LOCK TABLE public.usuarios IN SHARE MODE;'; BEGIN
 SELECT pg_get_functiondef('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)'::regprocedure) INTO f;
 IF position('MASIVO_ADMIN_V99' IN f)=0 THEN
  IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Revisar guardado de empaques'; END IF;
  EXECUTE replace(f,ancla,ancla||$x$
  -- MASIVO_ADMIN_V99
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e WHERE e->>'admin_masivo'='true') AND NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Empaque masivo exclusivo de Administrador' USING ERRCODE='42501'; END IF;
  $x$);
 END IF;
END $$;
NOTIFY pgrst,'reload schema';


-- 100_dashboard_puntualidad_mensual.sql
-- Puntualidad por salida de bodega. Solo lectura; DEV.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.dashboard_puntualidad_mensual(
 p_desde date,p_hasta date,p_cliente text DEFAULT NULL,p_corte timestamptz DEFAULT now()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Sin acceso al dashboard' USING ERRCODE='42501'; END IF;
 IF p_desde IS NULL OR p_hasta IS NULL OR p_corte IS NULL OR p_hasta<p_desde OR p_hasta-p_desde>36600 THEN RAISE EXCEPTION 'Periodo invalido'; END IF;
 RETURN (
 WITH meses AS (
 SELECT generate_series(date_trunc('month',p_desde::timestamp),date_trunc('month',p_hasta::timestamp),interval '1 month')::date mes
 ), salidas AS (
 SELECT date_trunc('month',d.fecha AT TIME ZONE 'America/Bogota')::date mes,
 (d.fecha AT TIME ZONE 'America/Bogota')::date salida,plazo.esperada,
 plazo.lineas>0 AND plazo.faltantes=0 evaluable
 FROM public.despachos_oc d
 CROSS JOIN LATERAL (
  SELECT count(*) lineas,count(*) FILTER(WHERE o.fecha_esperada_logistica IS NULL) faltantes,min(o.fecha_esperada_logistica) esperada
  FROM jsonb_array_elements(coalesce(d.detalle,'[]'::jsonb)) x
  LEFT JOIN public.items_orden i ON i.id::text=x->>'item_id'
  LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id
 ) plazo
 WHERE d.fase='despachado'
 AND d.fecha>=p_desde::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<(p_hasta+1)::timestamp AT TIME ZONE 'America/Bogota'
 AND d.fecha<=least(p_corte,now())
 AND extract(isodow FROM d.fecha AT TIME ZONE 'America/Bogota')<=5
 AND (p_cliente IS NULL OR coalesce(nullif(trim(d.cliente),''),'Sin cliente registrado')=p_cliente)
 ), grupos AS (
 SELECT mes,count(*) total,count(*) FILTER(WHERE evaluable AND salida<=esperada) a_tiempo,
 count(*) FILTER(WHERE evaluable AND salida>esperada) con_retraso,
 count(*) FILTER(WHERE NOT evaluable) sin_fecha
 FROM salidas GROUP BY mes
 ) SELECT coalesce(jsonb_agg(jsonb_build_object('mes',m.mes,'total',coalesce(g.total,0),
 'a_tiempo',coalesce(g.a_tiempo,0),'con_retraso',coalesce(g.con_retraso,0),'sin_fecha',coalesce(g.sin_fecha,0)) ORDER BY m.mes),'[]'::jsonb)
 FROM meses m LEFT JOIN grupos g USING(mes)
 );
END $$;
REVOKE ALL ON FUNCTION public.dashboard_puntualidad_mensual(date,date,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.dashboard_puntualidad_mensual(date,date,text,timestamptz) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Ninguna fila ni columna original puede cambiar; incluye documentos emitidos y Auth.
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
 IF EXISTS((SELECT fila FROM previo_secuencias EXCEPT ALL SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public') UNION ALL (SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public' EXCEPT ALL SELECT fila FROM previo_secuencias)) THEN RAISE EXCEPTION 'Cambió un consecutivo: rollback'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
