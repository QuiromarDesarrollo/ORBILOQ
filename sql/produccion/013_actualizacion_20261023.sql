-- CANDIDATO incremental 2026-10-23. Ensayar sobre respaldo antes de aplicar.
-- SOLO producción cxrflhgnxvomcvxzugda. No copia datos DEV ni reinicia consecutivos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regclass('public.inventario_transferencias') IS NOT NULL OR to_regclass('public.conductor_vehiculos') IS NOT NULL OR to_regclass('public.entrega_notificaciones') IS NOT NULL THEN RAISE EXCEPTION 'Hay modulos nuevos instalados: revisar antes de continuar'; END IF;
 IF to_regprocedure('public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Falta despliegue del 13'; END IF;
END $$;
DO $baseline$ BEGIN
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_guardar(text, uuid, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28d15223e73f3b181d881e592f7b1cda' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_guardar(text, uuid, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_listar(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '15ca446753397c8af4df941f3a90ab8b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_listar(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_confirmar_le(uuid, integer, uuid, jsonb, bigint, date)')), E'\r\n', E'\n')) IS DISTINCT FROM '007109c4ffe80c86b6c657d154e9a40d' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_confirmar_le(uuid, integer, uuid, jsonb, bigint, date)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_contexto_edicion(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM '92eed44998dfea36a342ff6f55f06d71' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_contexto_edicion(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_destinatario_editar(uuid, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '3156ba9d6ae9cf83a059b6134f2c6c30' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_destinatario_editar(uuid, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_destinatario_eliminar(uuid, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'c37b392de72d59b96b9d327293471760' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_destinatario_eliminar(uuid, jsonb)'; END IF;
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
IF md5(replace(pg_get_functiondef(to_regprocedure('public.dashboard_despachos_mensuales(date, date, text, timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM '24b4832a23bab2ae339a6f488ff0d263' THEN RAISE EXCEPTION 'Cambió función: %', 'public.dashboard_despachos_mensuales(date, date, text, timestamp with time zone)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.dashboard_facturacion_semanal(date, date, text, timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM '0f11dfb750a769e8d76f6290e77ec4e7' THEN RAISE EXCEPTION 'Cambió función: %', 'public.dashboard_facturacion_semanal(date, date, text, timestamp with time zone)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.dashboard_puntualidad_mensual(date, date, text, timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM '1126aa8c6041a9c6de80488b665ea54c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.dashboard_puntualidad_mensual(date, date, text, timestamp with time zone)'; END IF;
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
IF md5(replace(pg_get_functiondef(to_regprocedure('public.facturacion_le_dato(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'c7d82282a961d87dfca581c8a45c7c5b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.facturacion_le_dato(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.facturacion_le_guardar(uuid, integer, integer, integer, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e7b69b4f82527c32edd8fb94a64eaf3a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.facturacion_le_guardar(uuid, integer, integer, integer, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.facturacion_le_listar(boolean, bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM '459e73fa3b7cfb131f266a05ef8ad9fc' THEN RAISE EXCEPTION 'Cambió función: %', 'public.facturacion_le_listar(boolean, bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5e763479636c23d70bbb78c66d513d06' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario_v90(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a006f4d07a96e584503ffb248c61dedd' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario_v90(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario_v92(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '976dfdce5dfcfedb05af51db8afd6cee' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario_v92(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_base_v90(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd0698d67a3aca7667d259ed154ece072' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_base_v90(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_empaques(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '858e930ea0863fbce40243dad883f673' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_empaques(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_oc(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e11d59b90d3f483b0e08da945c6b801f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_oc(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_fechas_esperadas(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '8d27b01ae790c9238d56e6c2fd6c6e6c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_fechas_esperadas(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5478b89211abbd38a98970277c06ba72' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_acceso()')), E'\r\n', E'\n')) IS DISTINCT FROM '311dd52126630853d55866628e44cabb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_acceso()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_clientes()')), E'\r\n', E'\n')) IS DISTINCT FROM '99f4492d129d70280068540c1831e2db' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_clientes()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_configurar(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b346b4b8680c6ad7ea430b8314ea4ff3' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_configurar(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_documento(text, uuid, jsonb, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '3cf53bee5f64029c1f4e23ad90b6c78a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_documento(text, uuid, jsonb, boolean)'; END IF;
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
IF md5(replace(pg_get_functiondef(to_regprocedure('public.reservar_empaque_interno(uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '396285dffb279e7e87b35375d00ce418' THEN RAISE EXCEPTION 'Cambió función: %', 'public.reservar_empaque_interno(uuid, boolean)'; END IF;
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

-- 101_inventario_ficha.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
ALTER TABLE public.ordenes_produccion ADD COLUMN IF NOT EXISTS nombre_ficha_tecnica text;

CREATE TABLE IF NOT EXISTS public.inventario_transferencias (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), solicitud text UNIQUE NOT NULL,
 item_id uuid NOT NULL REFERENCES public.items_orden(id), ubicacion_id uuid NOT NULL REFERENCES public.ubicaciones(id),
 cliente text NOT NULL, ficha text NOT NULL CHECK(length(trim(ficha))>0),
 cantidad integer NOT NULL CHECK(cantidad>0), motivo text NOT NULL CHECK(length(trim(motivo))>0),
 actor uuid NOT NULL REFERENCES public.usuarios(id), fecha timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventario_reversiones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), solicitud text UNIQUE NOT NULL,
 transferencia uuid NOT NULL REFERENCES public.inventario_transferencias(id),
 cantidad integer NOT NULL CHECK(cantidad>0), motivo text NOT NULL CHECK(length(trim(motivo))>0),
 actor uuid NOT NULL REFERENCES public.usuarios(id), fecha timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventario_despachos (
 solicitud text PRIMARY KEY, transferencia uuid NOT NULL REFERENCES public.inventario_transferencias(id),
 cantidad integer NOT NULL CHECK(cantidad>0), actor uuid NOT NULL REFERENCES public.usuarios(id), pedido jsonb NOT NULL,
 despacho_id uuid UNIQUE REFERENCES public.despachos_oc(id), cancelado boolean NOT NULL DEFAULT false,
 motivo_cancelacion text, cancelado_por uuid REFERENCES public.usuarios(id), cancelado_en timestamptz
);
CREATE TABLE IF NOT EXISTS public.inventario_recepciones (
 solicitud text PRIMARY KEY, actor uuid NOT NULL REFERENCES public.usuarios(id), pedido jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS public.inventario_actualizacion(id boolean PRIMARY KEY DEFAULT true CHECK(id),version bigint NOT NULL DEFAULT 0);
INSERT INTO public.inventario_actualizacion(id) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE public.inventario_actualizacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_actualizacion FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.inventario_actualizacion TO authenticated;
DROP POLICY IF EXISTS inventario_actualizacion_lectura ON public.inventario_actualizacion;
CREATE POLICY inventario_actualizacion_lectura ON public.inventario_actualizacion FOR SELECT TO authenticated USING(public.wms_cuenta_activa());
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='inventario_actualizacion') THEN
 ALTER PUBLICATION supabase_realtime ADD TABLE public.inventario_actualizacion;
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS inventario_transferencia_item_idx ON public.inventario_transferencias(item_id,ubicacion_id);
CREATE INDEX IF NOT EXISTS inventario_reversion_transferencia_idx ON public.inventario_reversiones(transferencia);
CREATE INDEX IF NOT EXISTS inventario_despacho_transferencia_idx ON public.inventario_despachos(transferencia);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['inventario_transferencias','inventario_reversiones','inventario_despachos','inventario_recepciones'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_actor(p_roles text[] DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; BEGIN
 SELECT id INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo
 AND (p_roles IS NULL OR coalesce(nullif(roles,'{}'),ARRAY[rol]) && p_roles);
 IF a IS NULL THEN RAISE EXCEPTION 'Tu perfil no permite esta operación de inventario' USING ERRCODE='42501'; END IF;
 RETURN a;
END $$;

CREATE OR REPLACE VIEW public.inventario_saldos AS
SELECT t.*, t.cantidad-coalesce(r.cantidad,0)-coalesce(d.reservado,0)-coalesce(d.despachado,0) libre,
 coalesce(r.cantidad,0) revertido,coalesce(d.reservado,0) reservado,coalesce(d.despachado,0) despachado
FROM public.inventario_transferencias t
LEFT JOIN LATERAL (SELECT sum(cantidad) cantidad FROM public.inventario_reversiones WHERE transferencia=t.id) r ON true
LEFT JOIN LATERAL (SELECT sum(x.cantidad) FILTER(WHERE o.fase='empacado') reservado,
 sum(x.cantidad) FILTER(WHERE o.fase='despachado') despachado
 FROM public.inventario_despachos x JOIN public.despachos_oc o ON o.id=x.despacho_id WHERE x.transferencia=t.id AND NOT x.cancelado) d ON true;
REVOKE ALL ON public.inventario_saldos FROM PUBLIC,anon,authenticated;

-- El mismo orden de bloqueos que usa Despacho evita dobles consumos concurrentes.
CREATE OR REPLACE FUNCTION public.inventario_bloquear() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$ BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 LOCK TABLE public.inventario_transferencias,public.inventario_reversiones,public.inventario_despachos IN SHARE ROW EXCLUSIVE MODE;
END $$;

-- Disponible de la OP: físico menos inventario libre y TODAS las reservas.
CREATE OR REPLACE FUNCTION public.inventario_disponible_op(p_item uuid,p_ubicacion uuid) RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT coalesce((SELECT sum(CASE tipo WHEN 'recepcion' THEN cantidad WHEN 'despacho' THEN -cantidad WHEN 'devolucion_produccion' THEN -cantidad ELSE 0 END)
 FROM public.movimientos WHERE item_orden_id=p_item AND ubicacion_id=p_ubicacion),0)
 -coalesce((SELECT sum(libre) FROM public.inventario_saldos WHERE item_id=p_item AND ubicacion_id=p_ubicacion),0)
 -coalesce((SELECT sum(cantidad) FROM public.reservas_despacho WHERE item_id=p_item AND ubicacion_id=p_ubicacion),0);
$$;

CREATE OR REPLACE FUNCTION public.inventario_transferir(p_solicitud text,p_item uuid,p_ubicacion uuid,p_cantidad integer,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_transferencias%rowtype; f text; c text; nuevo uuid;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT * INTO previo FROM public.inventario_transferencias WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (previo.actor,previo.item_id,previo.ubicacion_id,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_item,p_ubicacion,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la transferencia'; END IF;
 SELECT trim(o.nombre_ficha_tecnica),o.cliente INTO f,c FROM public.items_orden i JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE i.id=p_item AND i.admin_eliminado_en IS NULL;
 IF nullif(f,'') IS NULL THEN RAISE EXCEPTION 'La OP no tiene ficha técnica. Importa NOMBRE FICHA TECNICA antes de transferir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion AND activa) THEN RAISE EXCEPTION 'Estante no disponible'; END IF;
 IF p_cantidad>public.inventario_disponible_op(p_item,p_ubicacion) THEN RAISE EXCEPTION 'Cantidad superior al stock libre de la OP en ese estante'; END IF;
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES(p_solicitud,p_item,p_ubicacion,c,f,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_revertir(p_solicitud text,p_transferencia uuid,p_cantidad integer,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_reversiones%rowtype; nuevo uuid; disponible bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT * INTO previo FROM public.inventario_reversiones WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (previo.actor,previo.transferencia,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_transferencia,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la reversión'; END IF;
 SELECT libre INTO disponible FROM public.inventario_saldos WHERE id=p_transferencia;
 IF disponible IS NULL OR p_cantidad>disponible THEN RAISE EXCEPTION 'Solo puedes devolver inventario libre. Libera primero sus reservas; las prendas despachadas no son reversibles'; END IF;
 INSERT INTO public.inventario_reversiones(solicitud,transferencia,cantidad,motivo,actor) VALUES(p_solicitud,p_transferencia,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;

-- Comprueba al cierre de la transacción: el empaque crea y retira movimientos
-- temporalmente, pero nunca puede confirmar un saldo utilizado dos veces.
CREATE OR REPLACE FUNCTION public.inventario_validar_stock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r record; afectados uuid[]; dato jsonb:=coalesce(to_jsonb(NEW),to_jsonb(OLD)); BEGIN
 IF TG_TABLE_NAME='movimientos' THEN afectados:=ARRAY[(dato->>'item_orden_id')::uuid];
 ELSIF TG_TABLE_NAME IN ('reservas_despacho','inventario_transferencias') THEN afectados:=ARRAY[(dato->>'item_id')::uuid];
 ELSIF TG_TABLE_NAME IN ('inventario_reversiones','inventario_despachos') THEN
 SELECT ARRAY[item_id] INTO afectados FROM public.inventario_transferencias WHERE id=(dato->>'transferencia')::uuid;
 ELSE
 SELECT array_agg(t.item_id) INTO afectados FROM public.inventario_despachos d JOIN public.inventario_transferencias t ON t.id=d.transferencia WHERE d.despacho_id=(dato->>'id')::uuid;
 END IF;
 IF TG_OP='UPDATE' AND TG_TABLE_NAME='movimientos' THEN afectados:=afectados||(to_jsonb(OLD)->>'item_orden_id')::uuid; END IF;
 IF TG_OP='UPDATE' AND TG_TABLE_NAME='reservas_despacho' THEN afectados:=afectados||(to_jsonb(OLD)->>'item_id')::uuid; END IF;
 FOR r IN SELECT DISTINCT item_id,ubicacion_id FROM public.inventario_saldos WHERE item_id=ANY(afectados) AND libre+reservado>0 LOOP
 IF public.inventario_disponible_op(r.item_id,r.ubicacion_id)<0 THEN RAISE EXCEPTION 'Stock asignado a inventario o reservado: revierte o libera primero la asignación'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.inventario_saldos WHERE item_id=ANY(afectados) AND libre<0) THEN RAISE EXCEPTION 'Inventario insuficiente'; END IF;
 RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_auditoria_inmutable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$ BEGIN
 RAISE EXCEPTION 'Las transferencias y reversiones son inmutables; registra una operación compensatoria';
END $$;
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_transferencias;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_transferencias FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_reversiones;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_reversiones FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['movimientos','reservas_despacho','inventario_transferencias','inventario_reversiones','inventario_despachos','despachos_oc'] LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS inventario_stock_guard ON public.%I',t);
 EXECUTE format('CREATE CONSTRAINT TRIGGER inventario_stock_guard AFTER INSERT OR UPDATE OR DELETE ON public.%I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.inventario_validar_stock()',t);
 END LOOP;
END $$;

-- Permite otra OC exclusivamente dentro de una solicitud privada de inventario.
-- Nadie puede insertar solicitudes directamente ni habilitarlo con una variable de sesión.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_V101')=0 THEN
 IF strpos(ddl,'item.oc IS DISTINCT FROM p_oc')=0 THEN RAISE EXCEPTION 'Base de despacho inesperada'; END IF;
 ddl:=replace(ddl,'item.oc IS DISTINCT FROM p_oc',E'(item.oc IS DISTINCT FROM p_oc AND NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv JOIN public.inventario_transferencias it ON it.id=inv.transferencia WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id AND it.item_id=item.id AND it.cliente=p_cliente AND NOT inv.cancelado)) /* INVENTARIO_V101 */');
 EXECUTE ddl;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_empacar(p_solicitud text,p_transferencia uuid,p_cantidad integer,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaque uuid,p_empaque_version text,p_peso numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t record; previo public.inventario_despachos%rowtype; r jsonb; pedido jsonb;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 pedido:=jsonb_build_array(p_transferencia,p_cantidad,trim(p_oc),p_destinatario,p_destinatario_version,p_empaque,p_empaque_version,p_peso);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(trim(p_oc)),0) NOT BETWEEN 1 AND 150 OR coalesce(p_cantidad,0)<=0 THEN RAISE EXCEPTION 'Indica OC y cantidad'; END IF;
 SELECT s.*,u.codigo ubicacion INTO t FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id WHERE s.id=p_transferencia;
 IF NOT FOUND OR p_cantidad>t.libre THEN RAISE EXCEPTION 'Inventario libre insuficiente'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,p_transferencia,p_cantidad,a,pedido);
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,t.cliente,trim(p_oc),
 jsonb_build_array(jsonb_build_object('item_id',t.item_id,'ubicacion',t.ubicacion,'cantidad',p_cantidad)),
 jsonb_build_array(jsonb_build_object('numero',1,'item_id',t.item_id,'empaque_id',p_empaque,'version',p_empaque_version,'cantidad',p_cantidad,'peso_bruto_kg',p_peso)),
 p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;

-- Una LE de inventario reservada se cancela para rehacer su empaque; nunca se
-- corrige por la ruta convencional, que podría cambiar el cliente/origen.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CORRECCION_V101')=0 THEN
 ddl:=replace(ddl,'IF p_id IS NULL THEN',E'-- INVENTARIO_CORRECCION_V101\n IF p_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.inventario_despachos WHERE despacho_id=p_id) THEN RAISE EXCEPTION ''Una LE de inventario no admite corrección convencional; cancela su reserva desde Inventario''; END IF;\n IF p_id IS NULL THEN');
 EXECUTE ddl; END IF;
END $$;

ALTER TABLE public.despachos_oc DROP CONSTRAINT IF EXISTS despachos_oc_fase_check;
ALTER TABLE public.despachos_oc ADD CONSTRAINT despachos_oc_fase_check CHECK(fase IN ('empacado','despachado','cancelado'));
CREATE OR REPLACE FUNCTION public.inventario_cancelar(p_despacho uuid,p_motivo text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; f text; BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF NOT EXISTS(SELECT 1 FROM public.inventario_despachos WHERE despacho_id=p_despacho) THEN RAISE EXCEPTION 'No es una reserva de inventario'; END IF;
 SELECT fase INTO f FROM public.despachos_oc WHERE id=p_despacho;
 IF f='cancelado' THEN RETURN; END IF;
 IF f<>'empacado' THEN RAISE EXCEPTION 'La LE ya salió de bodega; no puede liberarse como reserva'; END IF;
 IF coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica el motivo'; END IF;
 DELETE FROM public.reservas_despacho WHERE despacho_id=p_despacho;
 UPDATE public.inventario_despachos SET cancelado=true,motivo_cancelacion=trim(p_motivo),cancelado_por=a,cancelado_en=now() WHERE despacho_id=p_despacho;
 UPDATE public.despachos_oc SET fase='cancelado' WHERE id=p_despacho;
END $$;
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.seguimiento_confirmar(uuid,integer,uuid,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CANCELADO_V101')=0 THEN
 ddl:=replace(ddl,'IF d.fase=''empacado'' THEN',E'-- INVENTARIO_CANCELADO_V101\n IF d.fase=''cancelado'' THEN RAISE EXCEPTION ''Reserva de inventario cancelada''; END IF;\n IF d.fase=''empacado'' THEN');
 EXECUTE ddl; END IF;
END $$;

DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_PDF_V101')=0 THEN
 ddl:=replace(ddl,'IF d.fase=''empacado'' THEN',E'-- INVENTARIO_PDF_V101\n IF d.fase=''cancelado'' THEN RAISE EXCEPTION ''LE cancelada: no se puede emitir ni reimprimir como salida''; END IF;\n IF d.fase=''empacado'' THEN');
 EXECUTE ddl; END IF;
 -- El ID ERP de la OP de origen no corresponde a la nueva OC de destino.
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NOT NULL THEN
 ddl:=pg_get_functiondef('public.facturacion_le_dato(uuid)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_FACTURA_V101')=0 THEN
 ddl:=replace(ddl,') ids ON true',E' WHERE NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv WHERE inv.despacho_id=d.id) /* INVENTARIO_FACTURA_V101 */\n ) ids ON true');
 EXECUTE ddl; END IF;
 END IF;
END $$;

-- Recepción y asignación en una sola transacción, incluso entre varios lotes.
CREATE OR REPLACE FUNCTION public.inventario_recibir(p_solicitud text,p_plan jsonb,p_ubicacion text,p_recibido_por text,p_nota text,p_inventario integer) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_recepciones%rowtype; pedido jsonb; u uuid; r record; i uuid; queda integer:=p_inventario; n integer; total integer;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 pedido:=jsonb_build_array(p_plan,p_ubicacion,p_recibido_por,p_nota,p_inventario);
 SELECT * INTO previo FROM public.inventario_recepciones WHERE solicitud=p_solicitud;
 IF FOUND THEN IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF; RETURN; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR jsonb_typeof(p_plan) IS DISTINCT FROM 'array' OR jsonb_array_length(p_plan) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Plan inválido'; END IF;
 SELECT sum((x->>'cantidad')::integer) INTO total FROM jsonb_array_elements(p_plan) x;
 IF p_inventario IS NULL OR p_inventario<0 OR p_inventario>total THEN RAISE EXCEPTION 'Cantidad a inventario fuera de rango'; END IF;
 SELECT id INTO u FROM public.ubicaciones WHERE codigo=p_ubicacion AND activa;
 IF u IS NULL THEN RAISE EXCEPTION 'Estante inválido'; END IF;
 FOR r IN SELECT x->>'linea' linea,(x->>'cantidad')::integer cantidad FROM jsonb_array_elements(p_plan) x LOOP
 IF r.cantidad<=0 THEN RAISE EXCEPTION 'Cantidad inválida'; END IF;
 PERFORM public.recibir_lote_item(r.linea::uuid,r.cantidad,u,p_nota,p_recibido_por);
 n:=least(queda,r.cantidad);
 IF n>0 THEN
 SELECT item_orden_id INTO i FROM public.lote_items WHERE id=r.linea::uuid;
 PERFORM public.inventario_transferir(p_solicitud||':'||r.linea,i,u,n,'Asignación desde recepción');
 queda:=queda-n;
 END IF;
 END LOOP;
 INSERT INTO public.inventario_recepciones VALUES(p_solicitud,a,pedido);
END $$;

CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,coalesce(s.despachado,0) inventario_despachado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN LATERAL (SELECT sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado FROM public.inventario_saldos WHERE item_id=i.id) s ON true
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM componentes WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_detalle(p_cliente text,p_ficha text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.talla,o.numero_op,u.codigo ubicacion,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE s.cliente=p_cliente AND s.ficha=p_ficha ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_origenes(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT i.id item_id,u.id ubicacion_id,o.numero_op,o.cliente,o.nombre_ficha_tecnica ficha,i.descripcion producto,i.talla,u.codigo ubicacion,
 s.cantidad en_bodega,u.activa estante_activo,
 public.inventario_disponible_op(i.id,u.id) disponible
 FROM public.vista_stock_ubicacion_detalle s JOIN public.items_orden i ON i.id=s.item_orden_id
 JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.codigo=s.ubicacion_codigo
 WHERE i.admin_eliminado_en IS NULL
 AND concat_ws(' ',o.numero_op,o.cliente,o.nombre_ficha_tecnica,i.descripcion) ILIKE '%'||trim(coalesce(p_buscar,''))||'%'
 ORDER BY o.numero_op,i.id,u.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN r;
END $$;

-- Lectura paginada para restar inventario de la disponibilidad del kardex normal.
CREATE OR REPLACE FUNCTION public.inventario_saldos_items(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT s.item_id,u.codigo ubicacion,sum(s.libre) libre,sum(s.reservado) reservado,
 s.item_id::text||':'||u.codigo clave
 FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE s.item_id::text||':'||u.codigo>p_despues GROUP BY s.item_id,u.codigo
 HAVING sum(s.libre+s.reservado)>0 ORDER BY s.item_id::text||':'||u.codigo LIMIT 500) t;
 RETURN r;
END $$;

DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure firma,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'inventario_%' LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.firma);
 IF f.proname IN ('inventario_transferir','inventario_revertir','inventario_empacar','inventario_cancelar','inventario_recibir','inventario_listar','inventario_detalle','inventario_origenes','inventario_saldos_items') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.firma); END IF;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';



-- 102_inventario_origenes_visibles.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.inventario_origenes(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO r FROM (
 SELECT i.id item_id,u.id ubicacion_id,o.numero_op,o.cliente,o.nombre_ficha_tecnica ficha,i.descripcion producto,i.talla,u.codigo ubicacion,
 s.cantidad en_bodega,u.activa estante_activo,
 public.inventario_disponible_op(i.id,u.id) disponible
 FROM public.vista_stock_ubicacion_detalle s JOIN public.items_orden i ON i.id=s.item_orden_id
 JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.codigo=s.ubicacion_codigo
 WHERE i.admin_eliminado_en IS NULL
 AND concat_ws(' ',o.numero_op,o.cliente,o.nombre_ficha_tecnica,i.descripcion) ILIKE '%'||trim(coalesce(p_buscar,''))||'%'
 ORDER BY o.numero_op,i.id,u.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN r;
END $$;

NOTIFY pgrst, 'reload schema';



-- 103_inventario_consulta_agrupada.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
-- Calcula los saldos una sola vez por consulta, no una vez por línea del kardex.
CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT item_id,libre,reservado,despachado,ficha,cliente FROM public.inventario_saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM componentes WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

NOTIFY pgrst, 'reload schema';



-- 104_inventario_despacho_flujo.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.inventario_empacar_flujo(p_solicitud text,p_transferencia uuid,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t record; previo public.inventario_despachos%rowtype; r jsonb; pedido jsonb; p_cantidad bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' OR jsonb_array_length(p_empaques)=0 THEN RAISE EXCEPTION 'Indica los empaques'; END IF;
 SELECT sum((e->>'cantidad')::bigint) INTO p_cantidad FROM jsonb_array_elements(p_empaques)e;
 pedido:=jsonb_build_array(p_transferencia,trim(p_oc),p_destinatario,p_destinatario_version,p_empaques);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(trim(p_oc)),0) NOT BETWEEN 1 AND 150 OR coalesce(p_cantidad,0)<=0 THEN RAISE EXCEPTION 'Indica OC y cantidad'; END IF;
 SELECT s.*,u.codigo ubicacion INTO t FROM public.inventario_saldos s JOIN public.ubicaciones u ON u.id=s.ubicacion_id WHERE s.id=p_transferencia;
 IF NOT FOUND OR p_cantidad>t.libre THEN RAISE EXCEPTION 'Inventario libre insuficiente'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques)e
 WHERE (e->>'item_id') IS DISTINCT FROM t.item_id::text
 OR coalesce((e->>'cantidad')::bigint,0)<=0) THEN RAISE EXCEPTION 'Los empaques deben pertenecer a la prenda seleccionada'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,p_transferencia,p_cantidad,a,pedido);
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,t.cliente,trim(p_oc),
 jsonb_build_array(jsonb_build_object('item_id',t.item_id,'ubicacion',t.ubicacion,'cantidad',p_cantidad)),
 p_empaques,
 p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.inventario_empacar_flujo(text,uuid,text,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_empacar_flujo(text,uuid,text,uuid,text,jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';



-- 105_inventario_excel.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;

-- Artículos de inventario sin OP: permanecen fuera del kardex de producción
-- (sus vistas enlazan con ordenes_produccion). Se conserva el ledger físico.
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS inventario_manual boolean NOT NULL DEFAULT false;
ALTER TABLE public.items_orden ALTER COLUMN orden_id DROP NOT NULL;
ALTER TABLE public.items_orden DROP CONSTRAINT IF EXISTS items_origen_inventario;
ALTER TABLE public.items_orden ADD CONSTRAINT items_origen_inventario CHECK
 ((inventario_manual AND orden_id IS NULL) OR (NOT inventario_manual AND orden_id IS NOT NULL));
CREATE TABLE IF NOT EXISTS public.inventario_importaciones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), huella text UNIQUE NOT NULL,
 solicitud text UNIQUE NOT NULL, archivo text NOT NULL, actor uuid NOT NULL REFERENCES public.usuarios(id),
 fecha timestamptz NOT NULL DEFAULT now(), filas jsonb NOT NULL, unidades bigint NOT NULL
);
ALTER TABLE public.inventario_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_importaciones FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.inventario_clave(p_texto text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT upper(regexp_replace(btrim(p_texto),'[[:space:]]+',' ','g'))
$$;
CREATE OR REPLACE FUNCTION public.inventario_importar_excel(p_solicitud text,p_archivo text,p_filas jsonb,p_confirmar boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $$
DECLARE a uuid; canon jsonb; h text; previo public.inventario_importaciones%rowtype;
 r record; uid uuid; iid uuid; carga uuid:=gen_random_uuid(); total bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_archivo)),0) NOT BETWEEN 1 AND 255 THEN RAISE EXCEPTION 'Indica archivo y solicitud'; END IF;
 IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo inválido'; END IF;
 IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Máximo 1000 combinaciones de prenda y estante'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) f CROSS JOIN unnest(ARRAY['ficha','cliente','codigo','descripcion','talla','estante']) k
 WHERE jsonb_typeof(f->k) IS DISTINCT FROM 'string' OR coalesce(length(btrim(f->>k)),0) NOT BETWEEN 1 AND 500)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) f WHERE coalesce(f->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Completa los campos y usa cantidades enteras de 1 a 999999'; END IF;
 SELECT jsonb_agg(to_jsonb(x) ORDER BY cliente,ficha,codigo,talla,estante,descripcion),sum(cantidad) INTO canon,total FROM (
 SELECT public.inventario_clave(f->>'ficha') ficha,public.inventario_clave(f->>'cliente') cliente,
 public.inventario_clave(f->>'codigo') codigo,public.inventario_clave(f->>'descripcion') descripcion,
 public.inventario_clave(f->>'talla') talla,public.inventario_clave(f->>'estante') estante,
 sum((f->>'cantidad')::integer) cantidad FROM jsonb_array_elements(p_filas) f GROUP BY 1,2,3,4,5,6) x;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(canon) f GROUP BY f->>'cliente',f->>'ficha',f->>'codigo',f->>'talla',f->>'estante' HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(canon) f WHERE (f->>'cantidad')::bigint>999999) THEN RAISE EXCEPTION 'Hay descripciones contradictorias o cantidades agrupadas superiores a 999999'; END IF;
 h:=md5(canon::text);
 SELECT * INTO previo FROM public.inventario_importaciones WHERE solicitud=p_solicitud;
 IF FOUND AND previo.huella<>h THEN RAISE EXCEPTION 'Solicitud utilizada con otro archivo'; END IF;
 SELECT * INTO previo FROM public.inventario_importaciones WHERE huella=h;
 IF FOUND THEN RETURN jsonb_build_object('repetido',true,'id',previo.id,'unidades',previo.unidades,'archivo',previo.archivo,'fecha',previo.fecha); END IF;
 FOR r IN SELECT DISTINCT f->>'estante' estante FROM jsonb_array_elements(canon) f LOOP
 IF (SELECT count(*) FROM public.ubicaciones WHERE activa AND public.inventario_clave(codigo)=r.estante)<>1 THEN RAISE EXCEPTION 'Estante inexistente, inactivo o ambiguo: %',r.estante; END IF;
 END LOOP;
 IF p_confirmar IS NOT TRUE THEN RETURN jsonb_build_object('filas',canon,'unidades',total,'repetido',false); END IF;
 INSERT INTO public.inventario_importaciones(id,huella,solicitud,archivo,actor,filas,unidades) VALUES(carga,h,p_solicitud,btrim(p_archivo),a,canon,total);
 FOR r IN SELECT * FROM jsonb_to_recordset(canon) AS x(ficha text,cliente text,codigo text,descripcion text,talla text,estante text,cantidad integer) LOOP
 SELECT id INTO STRICT uid FROM public.ubicaciones WHERE activa AND public.inventario_clave(codigo)=r.estante;
 INSERT INTO public.items_orden(orden_id,inventario_manual,codigo,descripcion,talla,cantidad_pedida,oc)
 VALUES(NULL,true,r.codigo,r.descripcion,r.talla,r.cantidad,NULL) RETURNING id INTO iid;
 INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,nota)
 VALUES('recepcion',iid,r.cantidad,uid,a,'Entrada por Excel · '||p_archivo||' · '||carga);
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES('excel:'||carga||':'||iid,iid,uid,r.cliente,r.ficha,r.cantidad,'Entrada por Excel · '||p_archivo,a);
 END LOOP;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN jsonb_build_object('id',carga,'unidades',total,'filas',jsonb_array_length(canon),'repetido',false);
END $$;
REVOKE ALL ON FUNCTION public.inventario_importar_excel(text,text,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_importar_excel(text,text,jsonb,boolean) TO authenticated;
-- Mantener el control del cliente al despachar artículos sin OP.
DO $$ DECLARE ddl text; vieja text; BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 vieja:='SELECT cliente INTO cliente_actual FROM public.ordenes_produccion WHERE id=item.orden_id;';
 IF strpos(ddl,'INVENTARIO_EXCEL_105')=0 THEN
 IF strpos(ddl,vieja)=0 THEN RAISE EXCEPTION 'Base de despacho inesperada'; END IF;
 ddl:=replace(ddl,vieja,vieja||E'\n -- INVENTARIO_EXCEL_105\n IF item.inventario_manual THEN SELECT t.cliente INTO cliente_actual FROM public.inventario_transferencias t JOIN public.inventario_despachos d ON d.transferencia=t.id WHERE t.item_id=item.id AND d.solicitud=p_solicitud AND d.actor=actor.id AND NOT d.cancelado; END IF;');
 ddl:=replace(ddl,'(SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id)', 'coalesce((SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id),''INVENTARIO'')');
 EXECUTE ddl; END IF;
 ddl:=pg_get_functiondef('public.inventario_revertir(text,uuid,integer,text)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_EXCEL_105')=0 THEN
 ddl:=replace(ddl,'BEGIN',E'BEGIN\n -- INVENTARIO_EXCEL_105\n IF EXISTS(SELECT 1 FROM public.inventario_transferencias t JOIN public.items_orden i ON i.id=t.item_id WHERE t.id=p_transferencia AND i.inventario_manual) THEN RAISE EXCEPTION ''Una entrada Excel no tiene OP de origen para revertir''; END IF;');
 EXECUTE ddl; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_detalle(p_cliente text,p_ficha text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE public.inventario_clave(s.cliente)=public.inventario_clave(p_cliente) AND public.inventario_clave(s.ficha)=public.inventario_clave(p_ficha) ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT item_id,libre,reservado,despachado,ficha,cliente FROM public.inventario_saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM (SELECT public.inventario_clave(ficha) ficha,public.inventario_clave(cliente) cliente,descripcion,pendiente_producir,bodega,libre,reservado,despachado FROM componentes) c WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

NOTIFY pgrst, 'reload schema';



-- 106_inventario_solo_ingresadas.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;
-- Solo fichas/clientes que tuvieron una entrada real; incluye saldo reservado, despachado o revertido.
CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT item_id,libre,reservado,despachado,ficha,cliente FROM public.inventario_saldos
 ), fichas_ingresadas AS MATERIALIZED (
 SELECT DISTINCT public.inventario_clave(cliente) cliente,public.inventario_clave(ficha) ficha FROM saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 AND EXISTS(SELECT 1 FROM fichas_ingresadas f
 WHERE f.cliente=public.inventario_clave(o.cliente)
 AND f.ficha=public.inventario_clave(o.nombre_ficha_tecnica))
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM (SELECT public.inventario_clave(ficha) ficha,public.inventario_clave(cliente) cliente,descripcion,pendiente_producir,bodega,libre,reservado,despachado FROM componentes) c WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

NOTIFY pgrst, 'reload schema';



-- 107_inventario_por_talla.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;
-- Solo combinaciones de ficha, cliente y talla con entradas reales al inventario.
CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT s.item_id,s.libre,s.reservado,s.despachado,s.ficha,s.cliente,i.talla FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), fichas_ingresadas AS MATERIALIZED (
 SELECT DISTINCT public.inventario_clave(cliente) cliente,public.inventario_clave(ficha) ficha,public.inventario_clave(talla) talla FROM saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 AND EXISTS(SELECT 1 FROM fichas_ingresadas f
 WHERE f.cliente=public.inventario_clave(o.cliente)
 AND f.ficha=public.inventario_clave(o.nombre_ficha_tecnica)
 AND f.talla IS NOT DISTINCT FROM public.inventario_clave(i.talla))
 ), componentes AS (
 SELECT ficha,cliente,talla,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,s.talla,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,talla,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM (SELECT public.inventario_clave(ficha) ficha,public.inventario_clave(cliente) cliente,public.inventario_clave(talla) talla,descripcion,pendiente_producir,bodega,libre,reservado,despachado FROM componentes) c WHERE concat_ws(' ',ficha,cliente,talla,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente,talla
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha,talla LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_detalle_talla(p_cliente text,p_ficha text,p_talla text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE public.inventario_clave(s.cliente)=public.inventario_clave(p_cliente) AND public.inventario_clave(s.ficha)=public.inventario_clave(p_ficha) AND public.inventario_clave(i.talla) IS NOT DISTINCT FROM public.inventario_clave(p_talla) ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

REVOKE ALL ON FUNCTION public.inventario_detalle_talla(text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_detalle_talla(text,text,text,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';



-- 108_inventario_estante_destino.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;

-- Ledger de ubicación: no crea recepciones o despachos ficticios.
CREATE TABLE IF NOT EXISTS public.inventario_estantes_origen(
 transferencia uuid PRIMARY KEY REFERENCES public.inventario_transferencias(id),
 ubicacion_origen uuid NOT NULL REFERENCES public.ubicaciones(id)
);
ALTER TABLE public.inventario_estantes_origen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_estantes_origen FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.inventario_delta_estante(p_item uuid,p_ubicacion uuid) RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT coalesce(sum((s.cantidad-s.revertido) *
 (CASE WHEN s.ubicacion_id=p_ubicacion THEN 1 ELSE 0 END - CASE WHEN o.ubicacion_origen=p_ubicacion THEN 1 ELSE 0 END)),0)::bigint
 FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia WHERE s.item_id=p_item;
$$;
REVOKE ALL ON FUNCTION public.inventario_delta_estante(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE VIEW public.vista_stock_ubicacion_detalle AS
WITH componentes AS (
 SELECT m.item_orden_id,m.ubicacion_id,
 CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END::bigint cantidad
 FROM public.movimientos m WHERE m.tipo IN ('recepcion','despacho','devolucion_produccion')
 UNION ALL
 SELECT s.item_id,s.ubicacion_id,(s.cantidad-s.revertido)::bigint FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia
 UNION ALL
 SELECT s.item_id,o.ubicacion_origen,-(s.cantidad-s.revertido)::bigint FROM public.inventario_estantes_origen o JOIN public.inventario_saldos s ON s.id=o.transferencia
)
SELECT c.item_orden_id,u.codigo ubicacion_codigo,sum(c.cantidad)::bigint cantidad
FROM componentes c JOIN public.ubicaciones u ON u.id=c.ubicacion_id GROUP BY c.item_orden_id,u.codigo HAVING sum(c.cantidad)>0;
-- Conserva el algoritmo de disponibilidad, sumando solo el cambio neto de ubicación.
DO $$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.inventario_disponible_op(uuid,uuid)'::regprocedure);
 IF strpos(f,'inventario_delta_estante')=0 THEN
 f:=replace(f,'-coalesce((SELECT sum(libre)', '+public.inventario_delta_estante(p_item,p_ubicacion) -coalesce((SELECT sum(libre)');
 EXECUTE f;
 END IF;
END $$;
-- Validaciones existentes de reservas/salidas/ajustes también deben usar stock trasladado.
DO $$ DECLARE f record; ddl text; nuevo text; par text[]; BEGIN
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc LIKE '%INTO%stock%' AND p.prosrc LIKE '%FROM public.movimientos%' LOOP
 ddl:=pg_get_functiondef(f.oid); nuevo:=ddl;
 FOREACH par SLICE 1 IN ARRAY ARRAY[
 ['item_orden_id=r.item_id AND ubicacion_id=ubic;', 'stock','r.item_id','ubic'],
 ['item_orden_id=p_item AND ubicacion_id=r.ubicacion_id;', 'stock','p_item','r.ubicacion_id'],
 ['item_orden_id=ident AND ubicacion_id=ubic;', 'stock','ident','ubic'],
 ['item_orden_id = p_item_id AND ubicacion_id = p_ubicacion_id;', 'v_stock','p_item_id','p_ubicacion_id'],
 ['item_orden_id=p_item_orden_id AND ubicacion_id=p_ubicacion_id;', 'v_stock','p_item_orden_id','p_ubicacion_id']
 ] LOOP
 IF strpos(nuevo,'-- ESTANTE_108')=0 AND strpos(nuevo,par[1])>0 THEN
 nuevo:=replace(nuevo,par[1],par[1]||format(E'
 -- ESTANTE_108
 %s:=%s+public.inventario_delta_estante(%s,%s);',par[2],par[2],par[3],par[4]));
 END IF;
 END LOOP;
 IF nuevo<>ddl THEN EXECUTE nuevo; END IF;
 END LOOP;
END $$;
-- Un ajuste posterior tampoco puede consumir prendas que ya cambiaron de estante.
DO $$ DECLARE f text; BEGIN
 f:=pg_get_functiondef('public.inventario_validar_stock()'::regprocedure);
 IF strpos(f,'ESTANTE_FISICO_108')=0 THEN
 f:=replace(f,' RETURN NULL;', $patch$
 -- ESTANTE_FISICO_108
 FOR r IN SELECT DISTINCT t.item_id,o.ubicacion_origen ubicacion_id FROM public.inventario_estantes_origen o JOIN public.inventario_transferencias t ON t.id=o.transferencia WHERE t.item_id=ANY(afectados) LOOP
 IF coalesce((SELECT sum(CASE m.tipo WHEN 'recepcion' THEN m.cantidad WHEN 'despacho' THEN -m.cantidad WHEN 'devolucion_produccion' THEN -m.cantidad ELSE 0 END) FROM public.movimientos m WHERE m.item_orden_id=r.item_id AND m.ubicacion_id=r.ubicacion_id),0)+public.inventario_delta_estante(r.item_id,r.ubicacion_id)<0 THEN RAISE EXCEPTION 'El ajuste consume prendas trasladadas a otro estante'; END IF;
 END LOOP;
 RETURN NULL;$patch$);
 EXECUTE f;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_transferir_estante(p_solicitud text,p_item uuid,p_ubicacion uuid,p_cantidad integer,p_motivo text,p_estante_destino text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_transferencias%rowtype; f text; c text; nuevo uuid; destino uuid; origen uuid;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 SELECT id INTO destino FROM public.ubicaciones WHERE codigo=p_estante_destino AND activa;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona un estante de destino activo'; END IF;
 SELECT * INTO previo FROM public.inventario_transferencias WHERE solicitud=p_solicitud;
 IF FOUND THEN
 SELECT ubicacion_origen INTO origen FROM public.inventario_estantes_origen WHERE transferencia=previo.id;
 IF origen IS DISTINCT FROM p_ubicacion THEN RAISE EXCEPTION 'Solicitud utilizada con otro origen'; END IF;
 IF (previo.actor,previo.item_id,previo.ubicacion_id,previo.cantidad,previo.motivo) IS DISTINCT FROM (a,p_item,destino,p_cantidad,trim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN previo.id; END IF;
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(p_cantidad,0)<=0 OR coalesce(length(trim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica cantidad y motivo de la transferencia'; END IF;
 SELECT trim(o.nombre_ficha_tecnica),o.cliente INTO f,c FROM public.items_orden i JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE i.id=p_item AND i.admin_eliminado_en IS NULL;
 IF nullif(f,'') IS NULL THEN RAISE EXCEPTION 'La OP no tiene ficha técnica. Importa NOMBRE FICHA TECNICA antes de transferir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ubicaciones WHERE id=p_ubicacion AND activa) THEN RAISE EXCEPTION 'Estante no disponible'; END IF;
 IF p_cantidad>public.inventario_disponible_op(p_item,p_ubicacion) THEN RAISE EXCEPTION 'Cantidad superior al stock libre de la OP en ese estante'; END IF;
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES(p_solicitud,p_item,destino,c,f,p_cantidad,trim(p_motivo),a) RETURNING id INTO nuevo;
 INSERT INTO public.inventario_estantes_origen(transferencia,ubicacion_origen) VALUES(nuevo,p_ubicacion);
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN nuevo;
END $$;


REVOKE ALL ON FUNCTION public.inventario_transferir_estante(text,uuid,uuid,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_transferir_estante(text,uuid,uuid,integer,text,text) TO authenticated;
DROP TRIGGER IF EXISTS inventario_estantes_inmutable ON public.inventario_estantes_origen;
CREATE TRIGGER inventario_estantes_inmutable BEFORE UPDATE OR DELETE ON public.inventario_estantes_origen FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
NOTIFY pgrst, 'reload schema';



-- 109_inventario_historial.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;


DO $$ BEGIN IF to_regclass('public.inventario_estantes_origen') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 108'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.inventario_historial_transferencias() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','logistica']);
 WITH eventos AS (
 SELECT t.id,t.id transferencia,t.fecha,t.actor,t.cantidad,t.motivo,'Transferencia a inventario'::text tipo,false reversion FROM public.inventario_transferencias t JOIN public.items_orden i ON i.id=t.item_id WHERE NOT i.inventario_manual
 UNION ALL
 SELECT r.id,r.transferencia,r.fecha,r.actor,r.cantidad,r.motivo,'Devolución a OP original',true FROM public.inventario_reversiones r
 )
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.fecha DESC,q.id),'[]') INTO resultado FROM (
 SELECT e.*,t.item_id,t.ficha,t.cliente,i.descripcion producto,i.talla,i.codigo,o.numero_op,
 u.nombre responsable,
 CASE WHEN e.reversion THEN destino.codigo ELSE origen.codigo END estante_origen,
 CASE WHEN e.reversion THEN origen.codigo ELSE destino.codigo END estante_destino
 FROM eventos e JOIN public.inventario_transferencias t ON t.id=e.transferencia
 JOIN public.items_orden i ON i.id=t.item_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN public.usuarios u ON u.id=e.actor
 LEFT JOIN public.inventario_estantes_origen eo ON eo.transferencia=t.id
 JOIN public.ubicaciones origen ON origen.id=coalesce(eo.ubicacion_origen,t.ubicacion_id)
 JOIN public.ubicaciones destino ON destino.id=t.ubicacion_id
 ) q;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.inventario_historial_transferencias() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_historial_transferencias() TO authenticated;
NOTIFY pgrst, 'reload schema';



-- 110_inventario_eliminar_excel.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;


DO $$ BEGIN IF to_regclass('public.inventario_estantes_origen') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 108'; END IF; END $$;
CREATE TABLE IF NOT EXISTS public.inventario_excel_eliminaciones (
 transferencia uuid PRIMARY KEY REFERENCES public.inventario_transferencias(id),
 solicitud text UNIQUE NOT NULL, actor uuid NOT NULL REFERENCES public.usuarios(id),
 fecha timestamptz NOT NULL DEFAULT now(), motivo text NOT NULL CHECK(length(btrim(motivo)) BETWEEN 1 AND 500),
 entrada jsonb NOT NULL, movimientos jsonb NOT NULL
);
ALTER TABLE public.inventario_excel_eliminaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_excel_eliminaciones FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS inventario_inmutable ON public.inventario_excel_eliminaciones;
CREATE TRIGGER inventario_inmutable BEFORE UPDATE OR DELETE ON public.inventario_excel_eliminaciones
 FOR EACH ROW EXECUTE FUNCTION public.inventario_auditoria_inmutable();
-- Mantener las entradas originales para auditoría, excluyéndolas de todo saldo operativo.
DO $$ DECLARE ddl text; BEGIN
 ddl:=pg_get_viewdef('public.inventario_saldos'::regclass,true);
 IF strpos(ddl,'inventario_excel_eliminaciones')=0 THEN
 EXECUTE 'CREATE OR REPLACE VIEW public.inventario_saldos AS SELECT original.* FROM ('||rtrim(ddl,E';\n ')||') original WHERE NOT EXISTS (SELECT 1 FROM public.inventario_excel_eliminaciones e WHERE e.transferencia=original.id)';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_eliminar_excel(p_solicitud text,p_transferencia uuid,p_motivo text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; t public.inventario_transferencias%rowtype; e public.inventario_excel_eliminaciones%rowtype; s record; m jsonb;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_motivo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Indica el motivo de eliminación'; END IF;
 SELECT * INTO e FROM public.inventario_excel_eliminaciones WHERE solicitud=p_solicitud;
 IF FOUND THEN
 IF (e.transferencia,e.actor,e.motivo) IS DISTINCT FROM (p_transferencia,a,btrim(p_motivo)) THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN e.transferencia; END IF;
 SELECT * INTO t FROM public.inventario_transferencias WHERE id=p_transferencia;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id=t.item_id AND inventario_manual AND orden_id IS NULL) THEN RAISE EXCEPTION 'Solo se pueden eliminar entradas por Excel'; END IF;
 SELECT * INTO s FROM public.inventario_saldos WHERE id=t.id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Esta entrada ya fue eliminada'; END IF;
 IF s.reservado<>0 OR s.despachado<>0 OR s.libre<>t.cantidad
 OR EXISTS(SELECT 1 FROM public.reservas_despacho WHERE item_id=t.item_id)
 OR EXISTS(SELECT 1 FROM public.inventario_despachos WHERE transferencia=t.id AND NOT cancelado) THEN
 RAISE EXCEPTION 'No se puede eliminar: hay prendas reservadas, despachadas o movimientos posteriores'; END IF;
 -- La fila de importación tiene su propio artículo; no se toca ningún otro ingreso.
 IF (SELECT count(*) FROM public.inventario_transferencias WHERE item_id=t.item_id)<>1
 OR EXISTS(SELECT 1 FROM public.movimientos WHERE item_orden_id=t.item_id AND (tipo<>'recepcion' OR ubicacion_id IS DISTINCT FROM t.ubicacion_id))
 OR (SELECT coalesce(sum(cantidad),0) FROM public.movimientos WHERE item_orden_id=t.item_id)<>t.cantidad THEN RAISE EXCEPTION 'La entrada tiene ajustes posteriores; requiere revisión'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO m FROM public.movimientos x WHERE item_orden_id=t.item_id;
 INSERT INTO public.inventario_excel_eliminaciones(transferencia,solicitud,actor,motivo,entrada,movimientos)
 VALUES(t.id,p_solicitud,a,btrim(p_motivo),to_jsonb(t),m);
 DELETE FROM public.movimientos WHERE item_orden_id=t.item_id;
 UPDATE public.items_orden SET admin_eliminado_en=now() WHERE id=t.item_id;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN t.id;
END $$;
REVOKE ALL ON FUNCTION public.inventario_eliminar_excel(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_eliminar_excel(text,uuid,text) TO authenticated;
NOTIFY pgrst, 'reload schema';



-- 111_inventario_despacho_multiple.sql
-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_clave(text)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 105'; END IF; END $$;


DO $$ BEGIN IF to_regclass('public.inventario_estantes_origen') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 108'; END IF; END $$;
-- Una solicitud/LE puede consumir varias entradas; cada origen queda auditado.
ALTER TABLE public.inventario_despachos DROP CONSTRAINT IF EXISTS inventario_despachos_pkey;
ALTER TABLE public.inventario_despachos ADD PRIMARY KEY(solicitud,transferencia);
ALTER TABLE public.inventario_despachos DROP CONSTRAINT IF EXISTS inventario_despachos_despacho_id_key;
CREATE INDEX IF NOT EXISTS inventario_despachos_le_idx ON public.inventario_despachos(despacho_id);

CREATE OR REPLACE FUNCTION public.inventario_preparar_despacho(p_seleccion jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE q jsonb; s record; cliente_elegido text; faltan integer; tomar integer; resultado jsonb:='[]'; BEGIN
 PERFORM public.inventario_actor(ARRAY['admin','despacho']);
 IF jsonb_typeof(p_seleccion) IS DISTINCT FROM 'array' OR jsonb_array_length(p_seleccion) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Selecciona entre 1 y 100 prendas'; END IF;
 cliente_elegido:=public.inventario_clave(p_seleccion->0->>'cliente');
 IF nullif(cliente_elegido,'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_seleccion) x WHERE public.inventario_clave(x->>'cliente') IS DISTINCT FROM cliente_elegido) THEN RAISE EXCEPTION 'Selecciona prendas de un mismo cliente'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_seleccion) x GROUP BY public.inventario_clave(x->>'ficha'),public.inventario_clave(x->>'talla') HAVING count(*)>1) THEN RAISE EXCEPTION 'Prenda repetida en la selección'; END IF;
 FOR q IN SELECT value FROM jsonb_array_elements(p_seleccion) LOOP
 IF coalesce(q->>'cantidad','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'Indica cantidades enteras positivas'; END IF;
 faltan:=(q->>'cantidad')::integer;
 FOR s IN SELECT v.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel
 FROM public.inventario_saldos v JOIN public.items_orden i ON i.id=v.item_id
 LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=v.ubicacion_id
 WHERE public.inventario_clave(v.cliente)=cliente_elegido AND public.inventario_clave(v.ficha)=public.inventario_clave(q->>'ficha')
 AND public.inventario_clave(i.talla) IS NOT DISTINCT FROM public.inventario_clave(q->>'talla') AND v.libre>0 AND u.activa
 ORDER BY v.fecha,v.id LOOP
 tomar:=least(faltan,s.libre)::integer;
 resultado:=resultado||jsonb_build_array(to_jsonb(s)||jsonb_build_object('libre',tomar));
 faltan:=faltan-tomar; EXIT WHEN faltan=0;
 END LOOP;
 IF faltan>0 THEN RAISE EXCEPTION 'Stock insuficiente para ficha %, talla %. Actualiza la selección',q->>'ficha',q->>'talla'; END IF;
 END LOOP;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_empacar_multiple(p_solicitud text,p_asignaciones jsonb,p_oc text,p_destinatario uuid,p_destinatario_version text,p_empaques jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a uuid; previo public.inventario_despachos%rowtype; pedido jsonb; cliente text; x record; t record; r jsonb; lineas jsonb; BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','despacho']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_oc)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Indica OC y solicitud'; END IF;
 IF jsonb_typeof(p_asignaciones) IS DISTINCT FROM 'array' OR jsonb_array_length(p_asignaciones) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Indica las prendas de origen'; END IF;
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' OR jsonb_array_length(p_empaques)=0 THEN RAISE EXCEPTION 'Indica los empaques'; END IF;
 pedido:=jsonb_build_array('multiple',p_asignaciones,btrim(p_oc),p_destinatario,p_destinatario_version,p_empaques);
 SELECT * INTO previo FROM public.inventario_despachos WHERE solicitud=p_solicitud LIMIT 1;
 IF FOUND THEN
 IF previo.actor<>a OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada con otros datos'; END IF;
 RETURN jsonb_build_object('id',previo.despacho_id,'repetido',true); END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_asignaciones) q WHERE coalesce(q->>'cantidad','') !~ '^[1-9][0-9]{0,5}$')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_asignaciones) q GROUP BY q->>'transferencia' HAVING count(*)>1) THEN RAISE EXCEPTION 'Cantidades u orígenes inválidos'; END IF;
 FOR x IN SELECT * FROM jsonb_to_recordset(p_asignaciones) AS q(transferencia uuid,cantidad integer) LOOP
 SELECT v.*,u.codigo ubicacion INTO t FROM public.inventario_saldos v JOIN public.ubicaciones u ON u.id=v.ubicacion_id WHERE v.id=x.transferencia AND u.activa;
 IF NOT FOUND OR x.cantidad>t.libre THEN RAISE EXCEPTION 'El stock cambió o el estante está inactivo. Actualiza la selección'; END IF;
 IF cliente IS NULL THEN cliente:=t.cliente; END IF;
 IF public.inventario_clave(t.cliente)<>public.inventario_clave(cliente) THEN RAISE EXCEPTION 'No se pueden mezclar clientes'; END IF;
 INSERT INTO public.inventario_despachos(solicitud,transferencia,cantidad,actor,pedido) VALUES(p_solicitud,t.id,x.cantidad,a,pedido);
 END LOOP;
 -- Comparar los totales por artículo: no basta con que coincida el total de prendas.
 IF EXISTS(WITH origen AS (
 SELECT it.item_id,sum(d.cantidad) n FROM public.inventario_despachos d JOIN public.inventario_transferencias it ON it.id=d.transferencia WHERE d.solicitud=p_solicitud GROUP BY it.item_id),
 empaque AS (SELECT (e->>'item_id')::uuid item_id,sum((e->>'cantidad')::bigint) n FROM jsonb_array_elements(p_empaques) e GROUP BY 1)
 SELECT 1 FROM origen o FULL JOIN empaque e USING(item_id) WHERE o.n IS DISTINCT FROM e.n)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e WHERE coalesce(e->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Los empaques no coinciden con las prendas seleccionadas'; END IF;
 SELECT jsonb_agg(to_jsonb(q) ORDER BY item_id,ubicacion) INTO lineas FROM (
 SELECT it.item_id,u.codigo ubicacion,sum(d.cantidad) cantidad FROM public.inventario_despachos d JOIN public.inventario_transferencias it ON it.id=d.transferencia JOIN public.ubicaciones u ON u.id=it.ubicacion_id WHERE d.solicitud=p_solicitud GROUP BY it.item_id,u.codigo) q;
 r:=public.guardar_empaque_destinatario_v92(p_solicitud,cliente,btrim(p_oc),lineas,p_empaques,p_destinatario,p_destinatario_version);
 UPDATE public.inventario_despachos SET despacho_id=(r->>'id')::uuid WHERE solicitud=p_solicitud;
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.inventario_preparar_despacho(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_preparar_despacho(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';



-- 112_inventario_cliente_despacho_mixto.sql
-- Solo DEV. Unificar cliente únicamente para asignaciones autorizadas de inventario.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 111'; END IF;
END $$;
DO $migration$
DECLARE ddl text; anterior text; nueva text;
BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CLIENTE_112')>0 THEN RETURN; END IF;
 anterior:=$old$IF cliente_actual IS DISTINCT FROM p_cliente OR (item.oc IS DISTINCT FROM p_oc AND NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv JOIN public.inventario_transferencias it ON it.id=inv.transferencia WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id AND it.item_id=item.id AND it.cliente=p_cliente AND NOT inv.cancelado)) /* INVENTARIO_V101 */ THEN RAISE EXCEPTION 'Las prendas deben pertenecer al cliente y OC seleccionados.'; END IF;$old$;
 nueva:=$new$
 -- INVENTARIO_CLIENTE_112: el origen mantiene su OC; la LE recibe la OC de destino.
 -- La excepción requiere asignaciones privadas de esta solicitud y de este actor.
 IF EXISTS(SELECT 1 FROM public.inventario_despachos inv
   JOIN public.inventario_transferencias it ON it.id=inv.transferencia
   WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id
     AND it.item_id=item.id AND NOT inv.cancelado) THEN
   IF nullif(public.inventario_clave(p_cliente),'') IS NULL
      OR public.inventario_clave(cliente_actual) IS DISTINCT FROM public.inventario_clave(p_cliente)
      OR EXISTS(SELECT 1 FROM public.inventario_despachos inv
        JOIN public.inventario_transferencias it ON it.id=inv.transferencia
        WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id
          AND it.item_id=item.id AND NOT inv.cancelado
          AND public.inventario_clave(it.cliente) IS DISTINCT FROM public.inventario_clave(p_cliente))
   THEN RAISE EXCEPTION 'La prenda % (talla %) pertenece a un cliente diferente al seleccionado.',item.codigo,item.talla;
   END IF;
 ELSE
   IF item.inventario_manual THEN
     RAISE EXCEPTION 'La prenda % (talla %) no tiene una asignación de inventario válida para este despacho.',item.codigo,item.talla;
   END IF;
   IF cliente_actual IS DISTINCT FROM p_cliente THEN
     RAISE EXCEPTION 'La prenda % (talla %) pertenece a un cliente diferente al seleccionado.',item.codigo,item.talla;
   END IF;
   IF item.oc IS DISTINCT FROM p_oc THEN
     RAISE EXCEPTION 'La prenda % (talla %) pertenece a otra OC. Para despacharla con una nueva OC debe estar transferida y seleccionada desde inventario.',item.codigo,item.talla;
   END IF;
 END IF;
 $new$;
 IF strpos(ddl,anterior)=0 THEN RAISE EXCEPTION 'Validación de despacho inesperada; no se aplicó ningún cambio. Revisar migraciones 101 y 105.'; END IF;
 EXECUTE replace(ddl,anterior,nueva);
END $migration$;
DO $migration$
DECLARE ddl text; anterior text; nueva text;
BEGIN
 ddl:=pg_get_functiondef('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_SALDO_112')>0 THEN RETURN; END IF;
 anterior:=$old$IF NOT FOUND OR x.cantidad>t.libre THEN RAISE EXCEPTION 'El stock cambió o el estante está inactivo. Actualiza la selección'; END IF;$old$;
 nueva:=$new$
 -- INVENTARIO_SALDO_112
 IF NOT FOUND THEN
   RAISE EXCEPTION 'La entrada de inventario % no está disponible o su estante está inactivo. Actualiza la selección.',x.transferencia;
 END IF;
 IF x.cantidad>t.libre THEN
   RAISE EXCEPTION 'Saldo insuficiente en la ficha % (entrada %): solicitadas %, disponibles %. Actualiza la selección.',t.ficha,x.transferencia,x.cantidad,t.libre;
 END IF;
 $new$;
 IF strpos(ddl,anterior)=0 THEN RAISE EXCEPTION 'Validación múltiple inesperada; revisar migración 111.'; END IF;
 EXECUTE replace(ddl,anterior,nueva);
END $migration$;
NOTIFY pgrst, 'reload schema';



-- 113_historial_despacho_completo.sql
-- Solo DEV. Unificar cliente únicamente para asignaciones autorizadas de inventario.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 111'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.despacho_eventos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), despacho_id uuid NOT NULL,
 fecha timestamptz NOT NULL DEFAULT clock_timestamp(), actor text NOT NULL,
 accion text NOT NULL, detalle text NOT NULL DEFAULT '', fuente text NOT NULL,
 antes jsonb, despues jsonb, legado text UNIQUE
);
CREATE INDEX IF NOT EXISTS despacho_eventos_le_fecha ON public.despacho_eventos(despacho_id,fecha,id);
ALTER TABLE public.despacho_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.despacho_eventos FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.despacho_eventos_inmutable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$ BEGIN
 RAISE EXCEPTION 'El historial de despacho es inmutable';
END $$;
DROP TRIGGER IF EXISTS despacho_eventos_inmutable ON public.despacho_eventos;
CREATE TRIGGER despacho_eventos_inmutable BEFORE UPDATE OR DELETE ON public.despacho_eventos
 FOR EACH ROW EXECUTE FUNCTION public.despacho_eventos_inmutable();

CREATE OR REPLACE FUNCTION public.despacho_registrar_evento() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE n jsonb:=to_jsonb(NEW); o jsonb; did uuid; titulo text; texto text:=''; persona text;
BEGIN
 IF TG_OP='UPDATE' THEN o:=to_jsonb(OLD); IF n=o THEN RETURN NEW; END IF; END IF;
 did:=coalesce(n->>'despacho_id',n->>'id')::uuid;
 SELECT nombre INTO persona FROM public.usuarios WHERE auth_id=auth.uid();
 persona:=coalesce(persona,n->>'actor','Sin registrar');
 CASE TG_TABLE_NAME
 WHEN 'despachos_oc' THEN
   IF n->>'ediciones' IS DISTINCT FROM o->>'ediciones' THEN
     titulo:='Despacho corregido';
     SELECT motivo INTO texto FROM public.despacho_revisiones WHERE despacho_id=did ORDER BY edicion DESC LIMIT 1;
   ELSIF n->>'fase' IS DISTINCT FROM o->>'fase' THEN
     titulo:=CASE n->>'fase' WHEN 'empacado' THEN 'Empaque confirmado' WHEN 'cancelado' THEN 'Reserva cancelada' ELSE 'Salida confirmada' END;
     IF n->>'fase'='cancelado' THEN SELECT motivo_cancelacion INTO texto FROM public.inventario_despachos WHERE despacho_id=did AND cancelado LIMIT 1; END IF;
   ELSIF n->>'oc_documento' IS DISTINCT FROM o->>'oc_documento' OR n->>'oc' IS DISTINCT FROM o->>'oc' THEN
     titulo:='OC de despacho actualizada'; texto:=coalesce(n->>'oc_documento',n->>'oc');
   ELSIF n->'destinatario_empaque' IS DISTINCT FROM o->'destinatario_empaque' THEN
     titulo:='Destinatario de despacho actualizado';
   ELSIF n->'empaques' IS DISTINCT FROM o->'empaques' THEN
     titulo:='Contenido o peso de empaques actualizado';
   ELSE RETURN NEW;
   END IF;
 WHEN 'listas_empaque' THEN
   IF n->'datos'->>'pendiente'='true' THEN RETURN NEW; END IF;
   titulo:='Documento LE generado o actualizado'; texto:='LE '||coalesce(n->>'numero','');
 WHEN 'seguimiento_entregas' THEN
   titulo:='Seguimiento actualizado';
   texto:=concat_ws(' · ',n->>'estado',nullif(n->>'transportadora',''),nullif(n->>'placa_guia',''),nullif(n->>'observaciones',''));
 WHEN 'facturacion_le' THEN
   titulo:='Facturación actualizada'; texto:=concat_ws(' · ','Remisión: '||coalesce(n->>'remision',''),'ID OC: '||coalesce(n->>'id_oc',''));
 WHEN 'le_ajustes_admin' THEN
   titulo:='LE ajustada por administrador'; texto:=concat_ws(' · ','Número: '||(n->>'numero_solicitado'),'Fecha: '||(n->>'fecha_solicitada'));
 ELSE RETURN NEW;
 END CASE;
 INSERT INTO public.despacho_eventos(despacho_id,actor,accion,detalle,fuente,antes,despues)
 VALUES(did,persona,titulo,coalesce(texto,''),TG_TABLE_NAME,o,n);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.despacho_registrar_evento(),public.despacho_eventos_inmutable() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS despacho_evento ON public.despachos_oc;
CREATE TRIGGER despacho_evento AFTER UPDATE ON public.despachos_oc FOR EACH ROW EXECUTE FUNCTION public.despacho_registrar_evento();
DO $$ DECLARE tabla text; BEGIN
 FOREACH tabla IN ARRAY ARRAY['listas_empaque','seguimiento_entregas','facturacion_le','le_ajustes_admin'] LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS despacho_evento ON public.%I',tabla);
 EXECUTE format('CREATE TRIGGER despacho_evento AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.despacho_registrar_evento()',tabla);
 END LOOP;
END $$;
-- Los datos anteriores se identifican como tales: no se reconstruyen cambios inexistentes.
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT d.id,d.fecha,d.actor,'Registro previo de despacho',d.fase,'despachos_oc',to_jsonb(d),'despacho:'||d.id
FROM public.despachos_oc d WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=d.id)
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT s.despacho_id,s.actualizado_en,coalesce(u.nombre,'Sin registrar'),'Seguimiento previo disponible',
 concat_ws(' · ',s.estado,s.transportadora,s.placa_guia,s.observaciones),'seguimiento_entregas',to_jsonb(s),'seguimiento:'||s.despacho_id||':'||s.revision
FROM public.seguimiento_entregas s LEFT JOIN public.usuarios u ON u.auth_id=s.actualizado_por
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=s.despacho_id AND e.fuente='seguimiento_entregas')
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT f.despacho_id,f.actualizado_en,coalesce(u.nombre,'Sin registrar'),'Facturación previa disponible',
 concat_ws(' · ',f.remision,f.id_oc),'facturacion_le',to_jsonb(f),'facturacion:'||f.despacho_id||':'||f.revision
FROM public.facturacion_le f LEFT JOIN public.usuarios u ON u.auth_id=f.actualizado_por
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=f.despacho_id AND e.fuente='facturacion_le')
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,antes,legado)
SELECT r.despacho_id,r.fecha,coalesce(u.nombre,'Sin registrar'),'Despacho corregido',r.motivo,'despacho_revisiones',r.anterior,'revision:'||r.id
FROM public.despacho_revisiones r LEFT JOIN public.usuarios u ON u.id=r.actor
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=r.despacho_id AND e.accion='Despacho corregido' AND e.despues->>'ediciones'=r.edicion::text)
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT a.despacho_id,a.fecha_registro,coalesce(u.nombre,'Sin registrar'),'LE ajustada por administrador',
 concat_ws(' · ','Número: '||a.numero_solicitado,'Fecha: '||a.fecha_solicitada),'le_ajustes_admin',to_jsonb(a),'admin:'||a.despacho_id||':'||a.revision
FROM public.le_ajustes_admin a LEFT JOIN public.usuarios u ON u.id=a.actor
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=a.despacho_id AND e.fuente='le_ajustes_admin')
ON CONFLICT(legado) DO NOTHING;
DO $$ BEGIN
 IF to_regprocedure('public.historial_despachos_base_v113(text)') IS NULL THEN
 ALTER FUNCTION public.historial_despachos_empaques(text) RENAME TO historial_despachos_base_v113;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb; BEGIN
 filas:=public.historial_despachos_base_v113(p_despues);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('eventos',coalesce(e.eventos,'[]'::jsonb)) ORDER BY f.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY f
 LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('id',h.id,'fecha',h.fecha,'actor',h.actor,'accion',h.accion,'detalle',h.detalle) ORDER BY h.fecha DESC,h.id) eventos
 FROM public.despacho_eventos h WHERE h.despacho_id=(f.value->>'despacho_oc_id')::uuid) e ON true),'[]');
END $$;
REVOKE ALL ON FUNCTION public.historial_despachos_base_v113(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.historial_despachos_empaques(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.historial_despachos_empaques(text) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 114_conductores.sql

-- Después de 113. Actualizar admin-crear-usuario únicamente en DEV.

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
 CHECK(rol IN('admin','seguimiento','produccion','logistica','despacho','gerencia','conductor'));
CREATE OR REPLACE FUNCTION public.usuario_roles_normalizar(p_roles text[]) RETURNS text[]
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE resultado text[];
BEGIN
 IF p_roles IS NULL OR cardinality(p_roles) NOT BETWEEN 1 AND 7 OR array_ndims(p_roles)<>1
 OR array_position(p_roles,NULL) IS NOT NULL
 OR NOT p_roles <@ ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor']::text[]
 THEN RAISE EXCEPTION 'Selecciona al menos un perfil valido.'; END IF;
 SELECT array_agg(r ORDER BY n) INTO resultado FROM
 unnest(ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia','conductor'])
 WITH ORDINALITY AS t(r,n) WHERE r=ANY(p_roles);
 RETURN resultado;
END $$;

CREATE TABLE public.conductor_vehiculos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 placa text UNIQUE NOT NULL CHECK(length(placa) BETWEEN 3 AND 20),
 descripcion text NOT NULL CHECK(length(descripcion) BETWEEN 1 AND 200),
 conductor_id uuid NOT NULL REFERENCES auth.users(id),
 km integer NOT NULL CHECK(km>=0),
 datos jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(datos)='object'),
 actualizado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.conductor_registros (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 vehiculo_id uuid NOT NULL REFERENCES public.conductor_vehiculos(id),
 actor_id uuid NOT NULL REFERENCES auth.users(id),
 actor_nombre text NOT NULL,
 tipo text NOT NULL CHECK(tipo IN('Inicio de jornada','Fin de jornada','Registro diario',
 'Tanqueo','Lavado','Reposición de fluidos','Mantenimiento preventivo','Mantenimiento correctivo',
 'Siniestro vial','Novedad','Documentos','Asignación')),
 km integer NOT NULL CHECK(km>=0),
 creado timestamptz NOT NULL DEFAULT now(),
 datos jsonb NOT NULL CHECK(jsonb_typeof(datos)='object' AND octet_length(datos::text)<=16000)
);
CREATE INDEX conductor_registros_vehiculo_fecha ON public.conductor_registros(vehiculo_id,creado DESC);
CREATE UNIQUE INDEX conductor_jornada_unica ON public.conductor_registros(vehiculo_id,tipo,(datos->>'fecha'))
 WHERE tipo IN('Inicio de jornada','Fin de jornada');
ALTER TABLE public.conductor_vehiculos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_registros ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION public.conductor_acceso(p_conductor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo
 AND ('admin'=ANY(coalesce(u.roles,ARRAY[u.rol])) OR
 (p_conductor=auth.uid() AND 'conductor'=ANY(coalesce(u.roles,ARRAY[u.rol])))));
$$;
REVOKE ALL ON FUNCTION public.conductor_acceso(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_acceso(uuid) TO authenticated;
CREATE POLICY conductor_vehiculo_lectura ON public.conductor_vehiculos FOR SELECT TO authenticated
 USING(public.conductor_acceso(conductor_id));
CREATE POLICY conductor_registro_lectura ON public.conductor_registros FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.conductor_vehiculos v WHERE v.id=vehiculo_id AND public.conductor_acceso(v.conductor_id)));
REVOKE ALL ON public.conductor_vehiculos,public.conductor_registros FROM anon,authenticated;
GRANT SELECT ON public.conductor_vehiculos,public.conductor_registros TO authenticated;

CREATE FUNCTION public.conductor_asignar_vehiculo(p_placa text,p_descripcion text,p_km integer,p_numero text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE conductor uuid; vehiculo uuid; anterior jsonb; actor text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT auth_id INTO conductor FROM public.usuarios WHERE numero_usuario=p_numero AND activo
 AND 'conductor'=ANY(coalesce(roles,ARRAY[rol]));
 IF conductor IS NULL THEN RAISE EXCEPTION 'Conductor inexistente o inactivo'; END IF;
 IF p_km IS NULL OR p_km<0 THEN RAISE EXCEPTION 'Kilometraje invalido'; END IF;
 SELECT to_jsonb(v) INTO anterior FROM public.conductor_vehiculos v WHERE placa=upper(trim(p_placa)) FOR UPDATE;
 IF anterior IS NOT NULL AND p_km<(anterior->>'km')::integer THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 INSERT INTO public.conductor_vehiculos(placa,descripcion,conductor_id,km)
 VALUES(upper(trim(p_placa)),trim(p_descripcion),conductor,p_km)
 ON CONFLICT(placa) DO UPDATE SET conductor_id=excluded.conductor_id,descripcion=excluded.descripcion,
 km=greatest(conductor_vehiculos.km,excluded.km),
 datos=CASE WHEN conductor_vehiculos.conductor_id<>excluded.conductor_id
 THEN conductor_vehiculos.datos-'Licencia de conducción' ELSE conductor_vehiculos.datos END,actualizado=now()
 RETURNING id INTO vehiculo;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(vehiculo,auth.uid(),actor,'Asignación',p_km,
 jsonb_build_object('conductor_anterior',anterior->>'conductor_id','conductor_nuevo',conductor));
 RETURN vehiculo;
END $$;

CREATE FUNCTION public.conductor_registrar(p_vehiculo uuid,p_tipo text,p_km integer,p_datos jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; actor text; registro uuid; punto text; link text;
 puntos text[]:=ARRAY['Estado frenos','Nivel de aceite','Nivel de refrigerante',
 'Direccionales delanteras','Direccionales traseras','Luces altas','Luces bajas','Luces stop','Luces de parqueo',
 'Llantas delanteras','Llantas traseras','Llanta de repuesto','Limpiabrisas','Espejo lateral izquierdo',
 'Espejo lateral derecho','Vidrio panorámico','Pito','Pito reversa','Cinturón de seguridad','Puertas seguras',
 'Área de cargue','Interior cabina','Techos libres','Botiquín','Herramientas','Kit de derrames','Extintor'];
 hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id)
 THEN RAISE EXCEPTION 'Sin acceso al vehiculo' USING ERRCODE='42501'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN('Inicio de jornada','Fin de jornada','Registro diario','Tanqueo',
 'Lavado','Reposición de fluidos','Mantenimiento preventivo','Mantenimiento correctivo','Siniestro vial','Novedad','Documentos')
 THEN RAISE EXCEPTION 'Tipo invalido'; END IF;
 IF p_km IS NULL OR p_km<v.km THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR octet_length(p_datos::text)>16000
 THEN RAISE EXCEPTION 'Datos invalidos'; END IF;
 FOREACH punto IN ARRAY ARRAY['enlace','evidencia_siniestro'] LOOP
   link:=p_datos->>punto;
   IF coalesce(link,'')<>'' AND link !~ '^https://(drive[.]google[.]com|docs[.]google[.]com)/[^[:space:]]+$'
   THEN RAISE EXCEPTION 'Enlace Drive invalido'; END IF;
 END LOOP;
 IF p_tipo IN('Inicio de jornada','Fin de jornada') THEN
   p_datos:=jsonb_set(p_datos,'{fecha}',to_jsonb(hoy));
   IF jsonb_typeof(p_datos->'respuestas') IS DISTINCT FROM 'object'
   THEN RAISE EXCEPTION 'Checklist requerido'; END IF;
   FOREACH punto IN ARRAY puntos LOOP
     IF coalesce(p_datos->'respuestas'->>punto,'') NOT IN('Buen estado','Con novedad')
     THEN RAISE EXCEPTION 'Punto pendiente: %',punto; END IF;
   END LOOP;
   IF EXISTS(SELECT 1 FROM jsonb_each_text(p_datos->'respuestas') WHERE value='Con novedad') THEN
     IF length(trim(coalesce(p_datos->>'notas','')))=0 THEN RAISE EXCEPTION 'Describe la novedad'; END IF;
     p_datos:=jsonb_set(p_datos,'{resultado}','"Requiere revisión"');
   ELSE
     p_datos:=jsonb_set(p_datos,'{resultado}','"Sin novedades"');
   END IF;
   IF p_tipo='Fin de jornada' AND NOT EXISTS(SELECT 1 FROM public.conductor_registros
     WHERE vehiculo_id=p_vehiculo AND tipo='Inicio de jornada' AND datos->>'fecha'=hoy)
   THEN RAISE EXCEPTION 'Primero registra el inicio'; END IF;
   IF p_tipo='Fin de jornada' AND p_datos->>'siniestro'='true'
     AND (length(trim(coalesce(p_datos->>'hecho','')))=0 OR length(trim(coalesce(p_datos->>'evidencia_siniestro','')))=0)
   THEN RAISE EXCEPTION 'Describe el siniestro y adjunta su enlace'; END IF;
 END IF;
 IF p_tipo IN('Novedad','Siniestro vial') AND length(trim(coalesce(p_datos->>'notas','')))=0
 THEN RAISE EXCEPTION 'Descripcion requerida'; END IF;
 IF p_tipo='Documentos' THEN
   FOREACH punto IN ARRAY ARRAY['SOAT','Revisión tecnicomecánica','Licencia de conducción','Extintor'] LOOP
     IF coalesce(p_datos->>punto,'')<>'' THEN
       IF (p_datos->>punto) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Fecha invalida'; END IF;
       PERFORM (p_datos->>punto)::date;
     END IF;
   END LOOP;
   IF coalesce(p_datos->>'proximo_aceite','')<>'' AND (p_datos->>'proximo_aceite') !~ '^[0-9]+$'
   THEN RAISE EXCEPTION 'Proximo cambio invalido'; END IF;
 END IF;
 IF p_tipo IN('Tanqueo','Mantenimiento preventivo','Mantenimiento correctivo') THEN
   IF coalesce(p_datos->>'valor','') !~ '^[0-9]+([.][0-9]+)?$'
   THEN RAISE EXCEPTION 'Valor invalido'; END IF;
 END IF;
 IF p_tipo='Tanqueo' AND (coalesce(p_datos->>'cantidad','') !~ '^[0-9]+([.][0-9]+)?$'
 OR coalesce(p_datos->>'km_tanqueo','') !~ '^[0-9]+$') THEN RAISE EXCEPTION 'Tanqueo incompleto'; END IF;
 IF p_tipo LIKE 'Mantenimiento%' AND (length(trim(coalesce(p_datos->>'servicio','')))=0
 OR length(trim(coalesce(p_datos->>'taller','')))=0) THEN RAISE EXCEPTION 'Servicio y responsable requeridos'; END IF;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(p_vehiculo,auth.uid(),actor,p_tipo,p_km,p_datos) RETURNING id INTO registro;
 UPDATE public.conductor_vehiculos SET km=p_km,actualizado=now(),
 datos=CASE WHEN p_tipo='Documentos' THEN datos || p_datos ELSE datos END WHERE id=p_vehiculo;
 RETURN registro;
END $$;
REVOKE ALL ON FUNCTION public.conductor_asignar_vehiculo(text,text,integer,text),
 public.conductor_registrar(uuid,text,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_asignar_vehiculo(text,text,integer,text),
 public.conductor_registrar(uuid,text,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 115_conductor_historial_privado.sql

-- Aplicar antes de publicar el cliente que consulta conductor_historial.

SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

CREATE OR REPLACE FUNCTION public.conductor_fecha_registro(p_datos jsonb, p_creado timestamptz)
RETURNS date LANGUAGE plpgsql STABLE SET search_path=pg_catalog,public AS $$
BEGIN
 IF p_datos->>'fecha' ~ '^\d{4}-\d{2}-\d{2}$' THEN
   BEGIN RETURN (p_datos->>'fecha')::date;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN NULL;
   END;
 END IF;
 RETURN (p_creado AT TIME ZONE 'America/Bogota')::date;
END $$;
REVOKE ALL ON FUNCTION public.conductor_fecha_registro(jsonb,timestamptz) FROM PUBLIC,anon,authenticated;

-- El SELECT directo deja de revelar documentos, respuestas y observaciones al conductor.
DROP POLICY IF EXISTS conductor_registro_lectura ON public.conductor_registros;
CREATE POLICY conductor_registro_lectura ON public.conductor_registros
 FOR SELECT TO authenticated USING(public.admin_es_admin());

CREATE OR REPLACE FUNCTION public.conductor_historial(
 p_vehiculo uuid, p_desde date DEFAULT NULL, p_hasta date DEFAULT NULL,
 p_offset integer DEFAULT 0, p_limite integer DEFAULT 200
) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
DECLARE administrador boolean := public.admin_es_admin();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.conductor_vehiculos v
   WHERE v.id=p_vehiculo AND public.conductor_acceso(v.conductor_id))
 THEN RAISE EXCEPTION 'Sin acceso al vehiculo' USING ERRCODE='42501'; END IF;
 IF p_offset IS NULL OR p_offset<0 OR p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 500
 OR (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta)
 THEN RAISE EXCEPTION 'Filtro de historial invalido'; END IF;
 RETURN QUERY
 SELECT CASE WHEN administrador THEN to_jsonb(r)
   ELSE jsonb_build_object('id',r.id,'tipo',r.tipo,
     'datos',jsonb_build_object('fecha',public.conductor_fecha_registro(r.datos,r.creado)))
     -- Solo el estado operativo de hoy: conserva avisos sin exponer su detalle.
     || CASE WHEN public.conductor_fecha_registro(r.datos,r.creado)=(now() AT TIME ZONE 'America/Bogota')::date
       THEN jsonb_build_object('revision_pendiente',coalesce(r.datos->>'resultado'='Requiere revisión',false),
         'evidencia_registrada',EXISTS(SELECT 1 FROM jsonb_each_text(r.datos) e
           WHERE e.key IN('enlace','foto_frontal','foto_lateral','foto_trasera','foto_tablero')
           AND e.value ~ '^https://(drive[.]google[.]com|docs[.]google[.]com)/'))
       ELSE '{}'::jsonb END END
 FROM public.conductor_registros r
 WHERE r.vehiculo_id=p_vehiculo
   AND (p_desde IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)>=p_desde)
   AND (p_hasta IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)<=p_hasta)
 ORDER BY r.creado DESC,r.id DESC OFFSET p_offset LIMIT p_limite;
END $$;
REVOKE ALL ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) TO authenticated;



-- 116_conductor_fotos_laterales.sql


SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 
 
END $$;

CREATE OR REPLACE FUNCTION public.conductor_historial(
 p_vehiculo uuid, p_desde date DEFAULT NULL, p_hasta date DEFAULT NULL,
 p_offset integer DEFAULT 0, p_limite integer DEFAULT 200
) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $$
DECLARE administrador boolean := public.admin_es_admin();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.conductor_vehiculos v
   WHERE v.id=p_vehiculo AND public.conductor_acceso(v.conductor_id))
 THEN RAISE EXCEPTION 'Sin acceso al vehiculo' USING ERRCODE='42501'; END IF;
 IF p_offset IS NULL OR p_offset<0 OR p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 500
 OR (p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta)
 THEN RAISE EXCEPTION 'Filtro de historial invalido'; END IF;
 RETURN QUERY
 SELECT CASE WHEN administrador THEN to_jsonb(r)
   ELSE jsonb_build_object('id',r.id,'tipo',r.tipo,
     'datos',jsonb_build_object('fecha',public.conductor_fecha_registro(r.datos,r.creado)))
     -- Solo el estado operativo de hoy: conserva avisos sin exponer su detalle.
     || CASE WHEN public.conductor_fecha_registro(r.datos,r.creado)=(now() AT TIME ZONE 'America/Bogota')::date
       THEN jsonb_build_object('revision_pendiente',coalesce(r.datos->>'resultado'='Requiere revisión',false),
         'evidencia_registrada',EXISTS(SELECT 1 FROM jsonb_each_text(r.datos) e
           WHERE e.key IN('enlace','foto_frontal','foto_lateral','foto_lateral_derecho','foto_lateral_izquierdo','foto_trasera','foto_tablero')
           AND e.value ~ '^https://(drive[.]google[.]com|docs[.]google[.]com)/'))
       ELSE '{}'::jsonb END END
 FROM public.conductor_registros r
 WHERE r.vehiculo_id=p_vehiculo
   AND (p_desde IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)>=p_desde)
   AND (p_hasta IS NULL OR public.conductor_fecha_registro(r.datos,r.creado)<=p_hasta)
 ORDER BY r.creado DESC,r.id DESC OFFSET p_offset LIMIT p_limite;
END $$;
REVOKE ALL ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_historial(uuid,date,date,integer,integer) TO authenticated;



-- 117_correo_entrega.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE TABLE IF NOT EXISTS public.entrega_correos(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 despacho_id uuid NOT NULL REFERENCES public.despachos_oc(id), revision integer NOT NULL,
 destinatario text NOT NULL, datos jsonb NOT NULL,
 estado text NOT NULL DEFAULT 'pendiente' CHECK(estado IN ('pendiente','enviando','enviado','error','revision_manual')),
 creado_en timestamptz NOT NULL DEFAULT now(), creado_por uuid NOT NULL,
 primer_intento timestamptz, intento_en timestamptz, enviado_en timestamptz,
 proveedor_id text, error text, intentos integer NOT NULL DEFAULT 0,
 envio_iniciado boolean NOT NULL DEFAULT false,
 UNIQUE(despacho_id,revision)
);
ALTER TABLE public.entrega_correos ADD COLUMN IF NOT EXISTS envio_iniciado boolean NOT NULL DEFAULT false;
ALTER TABLE public.entrega_correos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entrega_correos FROM PUBLIC,anon,authenticated;
GRANT SELECT,UPDATE ON public.entrega_correos TO service_role;

CREATE OR REPLACE FUNCTION public.seguimiento_entregas_guardar_v117(p_id uuid,p_revision integer,p_version integer,p_datos jsonb,p_correo text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v integer; c public.entrega_correos%rowtype; s public.seguimiento_entregas%rowtype; snapshot jsonb; email text:=lower(btrim(coalesce(p_correo,'')));
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 IF email<>'' AND (length(email)>254 OR email !~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$') THEN RAISE EXCEPTION 'Correo de la comercial inválido'; END IF;
 v:=public.seguimiento_entregas_guardar_v87(p_id,p_revision,p_version,p_datos);
 SELECT * INTO s FROM public.seguimiento_entregas WHERE despacho_id=p_id AND revision=p_revision;
 SELECT * INTO c FROM public.entrega_correos WHERE despacho_id=p_id AND revision=p_revision;
 IF email<>'' AND c.id IS NOT NULL AND c.destinatario<>email THEN RAISE EXCEPTION 'Esta entrega ya tiene una notificación registrada para otro correo'; END IF;
 IF email<>'' AND c.id IS NULL THEN
  IF s.estado<>'entregado' OR s.recibido IS NULL THEN RAISE EXCEPTION 'Para notificar, selecciona Entregado e indica la fecha de recibido'; END IF;
  SELECT jsonb_build_object('le',l.numero,'cliente',d.cliente,'oc',d.oc,'destinatario',l.datos->'destinatario',
   'recibido',s.recibido,'numero_guia',s.numero_guia,
   'ops',coalesce((SELECT jsonb_agg(x.op ORDER BY x.op) FROM (
     SELECT DISTINCT o.numero_op op FROM jsonb_array_elements(d.detalle) item
     JOIN public.items_orden i ON i.id=(item->>'item_id')::uuid
     JOIN public.ordenes_produccion o ON o.id=i.orden_id WHERE nullif(o.numero_op,'') IS NOT NULL) x),'[]'::jsonb),
   'adjuntos',(SELECT coalesce(jsonb_agg(a),'[]'::jsonb) FROM (VALUES(s.evidencia_le),(s.evidencia_guia)) files(a) WHERE a IS NOT NULL AND a<>'null'::jsonb))
  INTO snapshot FROM public.despachos_oc d JOIN public.listas_empaque l ON l.despacho_id=d.id WHERE d.id=p_id;
  IF snapshot IS NULL THEN RAISE EXCEPTION 'No se encontró la LE'; END IF;
  INSERT INTO public.entrega_correos(despacho_id,revision,destinatario,datos,creado_por)
  VALUES(p_id,p_revision,email,snapshot,auth.uid()) RETURNING * INTO c;
 END IF;
 RETURN jsonb_build_object('version',v,'correo',CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id',c.id,'destinatario',c.destinatario,'estado',c.estado) END);
END $$;

CREATE OR REPLACE FUNCTION public.seguimiento_entregas_listar_v117(p_antes bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.seguimiento_entregas_listar(p_antes);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('correo',CASE WHEN c.id IS NULL THEN NULL ELSE
 jsonb_build_object('id',c.id,'destinatario',c.destinatario,'estado',c.estado,'error',c.error,'enviado_en',c.enviado_en) END) ORDER BY (f.value->>'le')::bigint DESC)
 FROM jsonb_array_elements(filas) f LEFT JOIN public.entrega_correos c ON c.despacho_id=(f.value->>'id')::uuid AND c.revision=(f.value->>'revision')::integer),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.entrega_correo_consultar(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NOT public.seguimiento_acceso() THEN RAISE EXCEPTION 'Sin acceso a Seguimiento' USING ERRCODE='42501'; END IF;
 RETURN (SELECT jsonb_build_object('id',id,'estado',estado,'destinatario',destinatario,'error',error) FROM public.entrega_correos WHERE id=p_id);
END $$;

-- Solo el servidor puede reservar el envío. El bloqueo evita dobles clics concurrentes.
CREATE OR REPLACE FUNCTION public.entrega_correo_reclamar(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE c public.entrega_correos%rowtype;
BEGIN
 SELECT * INTO c FROM public.entrega_correos WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF c.estado IN ('enviado','revision_manual') OR (c.estado='enviando' AND c.intento_en>now()-interval '5 minutes') THEN RETURN NULL; END IF;
 -- Gmail no ofrece clave idempotente: un envío iniciado sin confirmación requiere revisión.
 IF c.envio_iniciado THEN
  UPDATE public.entrega_correos SET estado='revision_manual',error='Comprueba Enviados en Gmail antes de volver a enviar' WHERE id=p_id;
  RETURN NULL;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.despachos_oc d JOIN public.seguimiento_entregas s ON s.despacho_id=d.id AND s.revision=d.ediciones
 WHERE d.id=c.despacho_id AND d.ediciones=c.revision AND d.fase='despachado' AND s.estado='entregado' AND s.recibido IS NOT NULL) THEN
  UPDATE public.entrega_correos SET estado='revision_manual',error='La entrega cambió; revisa el seguimiento' WHERE id=p_id;
  RETURN NULL;
 END IF;
 UPDATE public.entrega_correos SET estado='enviando',primer_intento=coalesce(primer_intento,now()),intento_en=now(),intentos=intentos+1,error=NULL WHERE id=p_id RETURNING * INTO c;
 RETURN to_jsonb(c);
END $$;
REVOKE ALL ON FUNCTION public.entrega_correo_reclamar(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.entrega_correo_reclamar(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.seguimiento_entregas_guardar_v117(uuid,integer,integer,jsonb,text),public.seguimiento_entregas_listar_v117(bigint),public.entrega_correo_consultar(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.seguimiento_entregas_guardar_v117(uuid,integer,integer,jsonb,text),public.seguimiento_entregas_listar_v117(bigint),public.entrega_correo_consultar(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 118_conductor_kit_semanal.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.conductor_historial(uuid,date,date,integer,integer)') IS NULL THEN RAISE EXCEPTION 'Requiere historial privado 115'; END IF;
END $$;
ALTER TABLE public.conductor_registros DROP CONSTRAINT conductor_registros_tipo_check;
ALTER TABLE public.conductor_registros ADD CONSTRAINT conductor_registros_tipo_check CHECK(tipo IN(
 'Inicio de jornada','Fin de jornada','Registro diario','Tanqueo','Lavado','Reposición de fluidos',
 'Mantenimiento preventivo','Mantenimiento correctivo','Siniestro vial','Novedad','Documentos','Asignación','Checklist semanal de carretera'));

CREATE OR REPLACE FUNCTION public.conductor_registrar_kit(p_vehiculo uuid,p_datos jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; actor text; registro uuid; p jsonb; r jsonb; nombre text; estado text;
 fecha date; vencimiento date; hoy date:=(now() AT TIME ZONE 'America/Bogota')::date;
 catalogo jsonb:=$catalogo$[{"nombre": "Gato para elevar el vehículo", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Manivela o mecanismo de accionamiento", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Cruceta para las tuercas de las ruedas", "categoria": "Cruceta", "vencimiento": false, "opcional": false}, {"nombre": "Triángulo reflectivo N.º 1", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Triángulo reflectivo N.º 2", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Soportes de los triángulos", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Lámparas amarillas intermitentes", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Guantes desechables de nitrilo", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Mascarilla de barrera para RCP", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Gasas estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Vendas de gasa", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Venda elástica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Esparadrapo o cinta médica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos adhesivos", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Solución salina estéril", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Toallitas antisépticas", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Compresa estéril para quemaduras", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Tijeras de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Pinzas de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Manta térmica de emergencia", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Bolsas para material contaminado", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Estuche del botiquín", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Extintor adecuado para el vehículo", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Carga y mantenimiento del extintor", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Manómetro, seguro y sello", "categoria": "Extintor", "vencimiento": false, "opcional": true}, {"nombre": "Soporte de fijación del extintor", "categoria": "Extintor", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 1", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 2", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Alicate", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de pala", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de estrella", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llave de expansión", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Juego de llaves fijas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Caja o bolso de herramientas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llanta de repuesto compatible", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Presión y estado de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Fijación de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Linterna funcional", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Pilas o batería con carga", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Chaleco reflectivo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cables de arranque o arrancador portátil", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Compresor o medidor de presión", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Sellador de pinchazos", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Guantes de trabajo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Agua potable", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Impermeable", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cargador portátil para celular", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cuerda de remolque compatible", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Contactos de emergencia", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}]$catalogo$::jsonb;
 novedades integer:=0;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso al vehículo' USING ERRCODE='42501'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR octet_length(p_datos::text)>16000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF length(trim(coalesce(p_datos->>'inspector',''))) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Inspector requerido'; END IF;
 IF length(coalesce(p_datos->>'lugar',''))>160 OR length(coalesce(p_datos->>'notas',''))>1000 THEN RAISE EXCEPTION 'Texto demasiado largo'; END IF;
 IF coalesce(p_datos->>'fecha','') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha requerida'; END IF;
 fecha:=(p_datos->>'fecha')::date;
 IF fecha<date_trunc('week',hoy::timestamp)::date OR fecha>hoy THEN RAISE EXCEPTION 'La inspección debe corresponder a esta semana y no ser futura'; END IF;
 IF jsonb_typeof(p_datos->'respuestas') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Checklist requerido'; END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(p_datos->'respuestas'))<>50 THEN RAISE EXCEPTION 'Se requieren los 50 puntos'; END IF;
 FOR p IN SELECT value FROM jsonb_array_elements(catalogo) LOOP
   nombre:=p->>'nombre'; r:=p_datos->'respuestas'->nombre; estado:=r->>'estado';
   IF r IS NULL OR jsonb_typeof(r)<>'object' OR coalesce(estado,'') NOT IN('Buen estado','Con novedad','No aplica') THEN RAISE EXCEPTION 'Punto pendiente: %',nombre; END IF;
   IF estado='No aplica' AND NOT (p->>'opcional')::boolean THEN RAISE EXCEPTION 'No aplica no permitido: %',nombre; END IF;
   IF length(coalesce(r->>'detalle',''))>120 THEN RAISE EXCEPTION 'Detalle demasiado largo: %',nombre; END IF;
   IF estado='Con novedad' THEN
     IF length(trim(coalesce(r->>'detalle','')))=0 THEN RAISE EXCEPTION 'Describe la novedad: %',nombre; END IF;
     novedades:=novedades+1;
   END IF;
   IF coalesce(r->>'vencimiento','')<>'' THEN
     IF NOT (p->>'vencimiento')::boolean OR estado='No aplica' OR (r->>'vencimiento') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Vencimiento inválido: %',nombre; END IF;
     vencimiento:=(r->>'vencimiento')::date;
     IF vencimiento<fecha AND estado='Buen estado' THEN RAISE EXCEPTION 'Elemento vencido: %',nombre; END IF;
   END IF;
 END LOOP;
 IF (p_datos->'respuestas'->'Lámparas amarillas intermitentes'->>'estado')='No aplica' AND EXISTS(
 SELECT 1 FROM unnest(ARRAY['Triángulo reflectivo N.º 1','Triángulo reflectivo N.º 2','Soportes de los triángulos']) n
 WHERE (p_datos->'respuestas'->n->>'estado')='No aplica') THEN RAISE EXCEPTION 'Revisa ambos triángulos y soportes o las lámparas alternativas'; END IF;
 SELECT u.nombre INTO actor FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo;
 -- Lista blanca de datos: el cliente no puede sustituir el resultado calculado.
 p_datos:=jsonb_build_object('inspector',trim(p_datos->>'inspector'),'fecha',to_char(fecha,'YYYY-MM-DD'),
 'lugar',trim(coalesce(p_datos->>'lugar','')),'notas',trim(coalesce(p_datos->>'notas','')),
 'respuestas',p_datos->'respuestas','resultado',CASE WHEN novedades>0 THEN 'Requiere revisión' ELSE 'Sin novedades' END);
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(p_vehiculo,auth.uid(),actor,'Checklist semanal de carretera',v.km,p_datos) RETURNING id INTO registro;
 RETURN registro;
END $$;
REVOKE ALL ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) TO authenticated;
-- Se calcula desde registros inmutables, no desde los documentos editables del vehículo.
CREATE OR REPLACE FUNCTION public.conductor_resumen_kit(p_vehiculos uuid[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb;
BEGIN
 IF p_vehiculos IS NULL OR cardinality(p_vehiculos)>100 OR array_position(p_vehiculos,NULL) IS NOT NULL THEN RAISE EXCEPTION 'Vehículos inválidos'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_vehiculos) AS solicitados(vehiculo) WHERE NOT EXISTS(SELECT 1 FROM public.conductor_vehiculos v WHERE v.id=solicitados.vehiculo AND public.conductor_acceso(v.conductor_id))) THEN RAISE EXCEPTION 'Sin acceso al vehículo' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_object_agg(v.id::text,jsonb_build_object('fecha',r.datos->>'fecha',
 'novedades',(SELECT count(*) FROM jsonb_each(r.datos->'respuestas') e WHERE e.value->>'estado'='Con novedad'),
 'vencimientos',coalesce((SELECT jsonb_object_agg(e.key,e.value->>'vencimiento') FROM jsonb_each(r.datos->'respuestas') e WHERE e.value->>'estado'<>'No aplica' AND coalesce(e.value->>'vencimiento','')<>''),'{}'::jsonb))),'{}'::jsonb)
 INTO resultado FROM public.conductor_vehiculos v JOIN LATERAL (
  SELECT datos FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Checklist semanal de carretera'
  ORDER BY datos->>'fecha' DESC,creado DESC,id DESC LIMIT 1
 ) r ON true WHERE v.id=ANY(p_vehiculos);
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.conductor_resumen_kit(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_resumen_kit(uuid[]) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 119_conductor_autorizacion_salida.sql
-- SOLO PRUEBAS. Aplicar después de 118. No modifica checklists existentes.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;
CREATE TABLE IF NOT EXISTS public.conductor_autorizaciones (
 registro_id uuid PRIMARY KEY REFERENCES public.conductor_registros(id),
 estado text NOT NULL CHECK(estado IN('Autorizado','No autorizado')),
 observacion text NOT NULL CHECK(length(observacion) BETWEEN 1 AND 1000),
 administrador uuid NOT NULL REFERENCES auth.users(id), actualizado timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.conductor_tareas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), registro_id uuid NOT NULL REFERENCES public.conductor_registros(id),
 punto text NOT NULL, descripcion text NOT NULL CHECK(length(descripcion) BETWEEN 1 AND 1000),
 estado text NOT NULL DEFAULT 'Pendiente' CHECK(estado IN('Pendiente','Por verificar','Cerrada')),
 respuesta text, creador uuid NOT NULL REFERENCES auth.users(id), creado timestamptz NOT NULL DEFAULT now(),
 actualizado timestamptz NOT NULL DEFAULT now(), UNIQUE(registro_id,punto)
);
CREATE TABLE IF NOT EXISTS public.conductor_revision_eventos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), registro_id uuid NOT NULL REFERENCES public.conductor_registros(id),
 actor uuid NOT NULL REFERENCES auth.users(id), creado timestamptz NOT NULL DEFAULT now(), accion text NOT NULL, datos jsonb NOT NULL
);
ALTER TABLE public.conductor_autorizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_tareas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_revision_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.conductor_autorizaciones,public.conductor_tareas,public.conductor_revision_eventos FROM anon,authenticated;
-- Solo RPC: el conductor recibe estado y tareas, nunca las respuestas completas del checklist.
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado<>'Cerrada'),'[]'::jsonb));
 IF p_detalle AND public.admin_es_admin() THEN
  SELECT coalesce(jsonb_agg(q ORDER BY q.creado DESC),'[]'::jsonb) INTO revisiones FROM (
   SELECT r.id,r.tipo,r.creado,r.actor_nombre,r.datos,coalesce(a.estado,'Pendiente de aprobación') AS estado
   FROM public.conductor_registros r LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=r.id
   WHERE r.vehiculo_id=v.id AND r.tipo IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera')
   ORDER BY r.creado DESC LIMIT 100
  ) q;
  resultado:=resultado || jsonb_build_object('checklists',revisiones);
 END IF;
 RETURN resultado;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_revision_accion(p_registro uuid,p_accion text,p_texto text,p_punto text DEFAULT NULL,p_tarea uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; t public.conductor_tareas; es_admin boolean:=public.admin_es_admin(); valor jsonb;
BEGIN
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=r.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Escribe una observación de hasta 1000 caracteres'; END IF;
 IF p_accion IN('Autorizado','No autorizado') THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.tipo<>'Inicio de jornada' OR r.datos->>'fecha'<>to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD') THEN RAISE EXCEPTION 'Solo se autoriza la salida de hoy'; END IF;
  IF p_accion='Autorizado' AND EXISTS(SELECT 1 FROM public.conductor_tareas x JOIN public.conductor_registros y ON y.id=x.registro_id WHERE y.vehiculo_id=v.id AND x.estado<>'Cerrada') THEN RAISE EXCEPTION 'Verifica y cierra las actividades pendientes antes de autorizar'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion='Crear actividad' THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.tipo NOT IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera') THEN RAISE EXCEPTION 'No es un checklist'; END IF;
  valor:=r.datos->'respuestas'->p_punto;
  IF valor IS DISTINCT FROM '"Con novedad"'::jsonb AND valor->>'estado' IS DISTINCT FROM 'Con novedad' THEN RAISE EXCEPTION 'El punto no tiene novedad'; END IF;
  INSERT INTO public.conductor_tareas(registro_id,punto,descripcion,creador) VALUES(r.id,p_punto,trim(p_texto),auth.uid());
  -- Una actividad nueva retira cualquier autorización de hoy hasta verificarla.
  UPDATE public.conductor_autorizaciones a SET estado='No autorizado',observacion='Actividad correctiva pendiente: '||p_punto,administrador=auth.uid(),actualizado=now() FROM public.conductor_registros x WHERE x.id=a.registro_id AND x.vehiculo_id=v.id AND x.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 ELSIF p_accion IN('Por verificar','Cerrada','Pendiente') THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea AND registro_id=r.id FOR UPDATE;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Actividad inexistente'; END IF;
  IF p_accion='Por verificar' THEN
   IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya fue reportada'; END IF;
  ELSE
   IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
   IF t.estado<>'Por verificar' THEN RAISE EXCEPTION 'La actividad no está pendiente de verificación'; END IF;
  END IF;
  UPDATE public.conductor_tareas SET estado=p_accion,respuesta=trim(p_texto),actualizado=now() WHERE id=t.id;
 ELSE RAISE EXCEPTION 'Acción inválida'; END IF;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(r.id,auth.uid(),p_accion,jsonb_build_object('texto',trim(p_texto),'punto',p_punto,'tarea',p_tarea));
END $$;
REVOKE ALL ON FUNCTION public.conductor_revision_resumen(uuid,boolean),public.conductor_revision_accion(uuid,text,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_revision_resumen(uuid,boolean),public.conductor_revision_accion(uuid,text,text,text,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 120_consecutivo_le_manual.sql
  -- SOLO PRUEBAS. Requiere 099. No recupera huecos históricos ni renumera documentos.

  SET LOCAL lock_timeout='5s';
  SET LOCAL client_min_messages=warning;
  DO $$ BEGIN
   
   
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



-- 121_conductor_actividades_agrupadas.sql
-- SOLO PRUEBAS. Aplicar después de 119. Autorización independiente de las actividades.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;

ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS motivos jsonb;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS fecha_limite date;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS evidencia text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS entregado_en timestamptz;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS entregado_por uuid REFERENCES auth.users(id);
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS solucion text;
UPDATE public.conductor_tareas SET motivos=jsonb_build_array(punto) WHERE motivos IS NULL;
ALTER TABLE public.conductor_tareas ALTER COLUMN motivos SET NOT NULL;
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('version',2,'estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND (t.estado<>'Cerrada' OR (p_detalle AND public.admin_es_admin()))),'[]'::jsonb));
 IF p_detalle AND public.admin_es_admin() THEN
  SELECT coalesce(jsonb_agg(q ORDER BY q.creado DESC),'[]'::jsonb) INTO revisiones FROM (
   SELECT r.id,r.tipo,r.creado,r.actor_nombre,r.datos,coalesce(a.estado,'Pendiente de aprobación') AS estado
   FROM public.conductor_registros r LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=r.id
   WHERE r.vehiculo_id=v.id AND r.tipo IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera')
   ORDER BY r.creado DESC LIMIT 100
  ) q;
  resultado:=resultado || jsonb_build_object('checklists',revisiones);
 END IF;
 RETURN resultado;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_revision_accion(p_registro uuid,p_accion text,p_texto text,p_punto text DEFAULT NULL,p_tarea uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; t public.conductor_tareas; es_admin boolean:=public.admin_es_admin(); valor jsonb;
BEGIN
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=r.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Escribe una observación de hasta 1000 caracteres'; END IF;
 IF p_accion IN('Autorizado','No autorizado') THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.tipo<>'Inicio de jornada' OR r.datos->>'fecha'<>to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD') THEN RAISE EXCEPTION 'Solo se autoriza la salida de hoy'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion IN('Crear actividad','Por verificar') THEN
  RAISE EXCEPTION 'Actualiza la aplicación para asignar actividades con fecha y foto';
 ELSIF p_accion IN('Por verificar','Cerrada','Pendiente') THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea AND registro_id=r.id FOR UPDATE;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Actividad inexistente'; END IF;
  IF p_accion='Por verificar' THEN
   IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya fue reportada'; END IF;
  ELSE
   IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
   IF t.estado<>'Por verificar' THEN RAISE EXCEPTION 'La actividad no está pendiente de verificación'; END IF;
  END IF;
  UPDATE public.conductor_tareas SET estado=p_accion,respuesta=trim(p_texto),actualizado=now() WHERE id=t.id;
 ELSE RAISE EXCEPTION 'Acción inválida'; END IF;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(r.id,auth.uid(),p_accion,jsonb_build_object('texto',trim(p_texto),'punto',p_punto,'tarea',p_tarea));
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_crear(p_registro uuid,p_motivos text[],p_descripcion text,p_fecha date) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; v_punto text; valor jsonb; nueva uuid;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=r.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR r.tipo NOT IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera') THEN RAISE EXCEPTION 'Checklist inexistente'; END IF;
 IF p_fecha IS NULL OR p_fecha<(now() AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'La fecha límite no puede estar en el pasado'; END IF;
 IF p_descripcion IS NULL OR length(trim(p_descripcion)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la actividad (máximo 1000 caracteres)'; END IF;
 IF p_motivos IS NULL OR cardinality(p_motivos) NOT BETWEEN 1 AND 50 OR array_ndims(p_motivos)<>1 OR array_position(p_motivos,NULL) IS NOT NULL THEN RAISE EXCEPTION 'Selecciona los motivos de corrección'; END IF;
 IF cardinality(p_motivos)<>(SELECT count(DISTINCT x) FROM unnest(p_motivos) x) THEN RAISE EXCEPTION 'Motivos duplicados'; END IF;
 FOREACH v_punto IN ARRAY p_motivos LOOP
  valor:=r.datos->'respuestas'->v_punto;
  IF valor IS DISTINCT FROM '"Con novedad"'::jsonb AND valor->>'estado' IS DISTINCT FROM 'Con novedad' THEN RAISE EXCEPTION 'Punto sin novedad: %',v_punto; END IF;
  IF EXISTS(SELECT 1 FROM public.conductor_tareas WHERE registro_id=r.id AND estado<>'Cerrada' AND motivos ? v_punto) THEN RAISE EXCEPTION 'Ya existe una actividad abierta para %',v_punto; END IF;
 END LOOP;
 INSERT INTO public.conductor_tareas(registro_id,punto,motivos,descripcion,fecha_limite,creador)
 VALUES(r.id,gen_random_uuid()::text,to_jsonb(p_motivos),trim(p_descripcion),p_fecha,auth.uid()) RETURNING id INTO nueva;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(r.id,auth.uid(),'Crear actividad',jsonb_build_object('tarea',nueva,'motivos',p_motivos,'descripcion',trim(p_descripcion),'fecha_limite',p_fecha));
 RETURN nueva;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_actividad_entregar(p_tarea uuid,p_texto text,p_evidencia text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 SELECT v1.* INTO v FROM public.conductor_vehiculos v1 JOIN public.conductor_registros r ON r.vehiculo_id=v1.id JOIN public.conductor_tareas t1 ON t1.registro_id=r.id WHERE t1.id=p_tarea FOR UPDATE OF v1;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea FOR UPDATE;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la solución'; END IF;
 IF p_evidencia IS NULL OR p_evidencia !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta la foto de la actividad realizada'; END IF;
 IF t.estado='Por verificar' AND t.evidencia=p_evidencia AND t.solucion=trim(p_texto) AND t.entregado_por=auth.uid() THEN RETURN; END IF;
 IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya no está pendiente'; END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=trim(p_texto),evidencia=p_evidencia,entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now() WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(t.registro_id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'solucion',trim(p_texto),'evidencia',p_evidencia));
END $$;
REVOKE ALL ON FUNCTION public.conductor_actividad_crear(uuid,text[],text,date),public.conductor_actividad_entregar(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_actividad_crear(uuid,text[],text,date),public.conductor_actividad_entregar(uuid,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 122_conductor_motivos_atendidos.sql
-- SOLO PRUEBAS. Después de 121. Un motivo se atiende una sola vez por checklist.

SET LOCAL lock_timeout='5s';
DO $$ DECLARE f text; ancla text:=$a$registro_id=r.id AND estado<>'Cerrada' AND motivos ? v_punto$a$; BEGIN
 
 
 SELECT pg_get_functiondef('public.conductor_actividad_crear(uuid,text[],text,date)'::regprocedure) INTO f;
 IF position('MOTIVO_ATENDIDO_V122' IN f)=0 THEN
  IF position(ancla IN f)=0 THEN RAISE EXCEPTION 'Aplicar primero migración 121'; END IF;
  f:=replace(f,ancla,'registro_id=r.id AND motivos ? v_punto /* MOTIVO_ATENDIDO_V122 */');
  f:=replace(f,'Ya existe una actividad abierta para %','Este motivo ya tiene una actividad asignada en el checklist: %');
  EXECUTE f;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';



-- 123_conductor_panel_flota.sql
-- SOLO PRUEBAS. Aplicar después de 122. Panel administrativo de flota y reasignación.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;


ALTER TABLE public.conductor_vehiculos ALTER COLUMN conductor_id DROP NOT NULL;
CREATE OR REPLACE FUNCTION public.conductor_flota_resumen() RETURNS SETOF jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object(
 'conductor_nombre',coalesce(u.nombre,'Sin asignar'),'conductor_numero',u.numero_usuario,
 'inicio',s.id IS NOT NULL,'fin',EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=hoy),
 'autorizacion',CASE WHEN s.id IS NULL THEN 'Sin checklist' ELSE coalesce(a.estado,'Pendiente de aprobación') END,
 'pendientes',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Pendiente'),
 'por_verificar',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Por verificar'),
 'vencidas',(SELECT count(*) FROM public.conductor_tareas t JOIN public.conductor_registros r ON r.id=t.registro_id WHERE r.vehiculo_id=v.id AND t.estado='Pendiente' AND t.fecha_limite<hoy::date))
 FROM public.conductor_vehiculos v LEFT JOIN public.usuarios u ON u.auth_id=v.conductor_id
 LEFT JOIN public.conductor_registros s ON s.vehiculo_id=v.id AND s.tipo='Inicio de jornada' AND s.datos->>'fecha'=hoy
 LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=s.id ORDER BY v.placa;
END $$;
REVOKE ALL ON FUNCTION public.conductor_flota_resumen() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_flota_resumen() TO authenticated;
CREATE OR REPLACE FUNCTION public.conductor_asignar_vehiculo(p_placa text,p_descripcion text,p_km integer,p_numero text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE conductor uuid; vehiculo uuid; anterior jsonb; actor text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT auth_id INTO conductor FROM public.usuarios WHERE numero_usuario=p_numero AND activo
 AND 'conductor'=ANY(coalesce(roles,ARRAY[rol]));
 IF conductor IS NULL THEN RAISE EXCEPTION 'Conductor inexistente o inactivo'; END IF;
 IF p_km IS NULL OR p_km<0 THEN RAISE EXCEPTION 'Kilometraje invalido'; END IF;
 -- Serializa reasignaciones y conserva los registros con su actor original.
 PERFORM pg_advisory_xact_lock(123,1);
 PERFORM 1 FROM public.conductor_vehiculos WHERE conductor_id=conductor OR placa=upper(trim(p_placa)) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.conductor_vehiculos v WHERE (v.conductor_id=conductor OR v.placa=upper(trim(p_placa)))
  AND (v.placa<>upper(trim(p_placa)) OR v.conductor_id IS DISTINCT FROM conductor)
  AND EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Inicio de jornada' AND r.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD'))
  AND NOT EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD')))
 THEN RAISE EXCEPTION 'Finaliza la jornada abierta antes de cambiar la asignación'; END IF;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 SELECT id,auth.uid(),actor,'Asignación',km,jsonb_build_object('conductor_anterior',conductor_id,'conductor_nuevo',NULL,'motivo','Cambio de vehículo entre jornadas')
 FROM public.conductor_vehiculos WHERE conductor_id=conductor AND placa<>upper(trim(p_placa));
 UPDATE public.conductor_vehiculos SET conductor_id=NULL,datos=datos-'Licencia de conducción',actualizado=now() WHERE conductor_id=conductor AND placa<>upper(trim(p_placa));

 SELECT to_jsonb(v) INTO anterior FROM public.conductor_vehiculos v WHERE placa=upper(trim(p_placa)) FOR UPDATE;
 IF anterior IS NOT NULL AND p_km<(anterior->>'km')::integer THEN RAISE EXCEPTION 'El kilometraje no puede disminuir'; END IF;
 INSERT INTO public.conductor_vehiculos(placa,descripcion,conductor_id,km)
 VALUES(upper(trim(p_placa)),trim(p_descripcion),conductor,p_km)
 ON CONFLICT(placa) DO UPDATE SET conductor_id=excluded.conductor_id,descripcion=excluded.descripcion,
 km=greatest(conductor_vehiculos.km,excluded.km),
 datos=CASE WHEN conductor_vehiculos.conductor_id IS DISTINCT FROM excluded.conductor_id
 THEN conductor_vehiculos.datos-'Licencia de conducción' ELSE conductor_vehiculos.datos END,actualizado=now()
 RETURNING id INTO vehiculo;
 SELECT nombre INTO actor FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(vehiculo,auth.uid(),actor,'Asignación',p_km,
 jsonb_build_object('conductor_anterior',anterior->>'conductor_id','conductor_nuevo',conductor));
 RETURN vehiculo;
END $$;

NOTIFY pgrst,'reload schema';



-- 124_conductor_ficha_documentos.sql
-- SOLO PRUEBAS. Aplicar después de 123.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.conductor_limpiar_ficha_reasignada()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
 IF OLD.conductor_id IS DISTINCT FROM NEW.conductor_id THEN
   NEW.datos := coalesce(NEW.datos,'{}'::jsonb) - ARRAY[
     'conductor_documento','foto_conductor','Licencia de conducción','doc_licencia',
     'licencia_desde','licencia_expedido','licencia_valor','licencia_observaciones'];
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.conductor_limpiar_ficha_reasignada() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS conductor_limpiar_ficha_reasignada ON public.conductor_vehiculos;
CREATE TRIGGER conductor_limpiar_ficha_reasignada BEFORE UPDATE OF conductor_id ON public.conductor_vehiculos
FOR EACH ROW EXECUTE FUNCTION public.conductor_limpiar_ficha_reasignada();
NOTIFY pgrst,'reload schema';



-- 125_conductor_periodicidad_mantenimiento.sql
-- SOLO PRUEBAS. Aplicar después de 124.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;
-- El resumen pertenece al vehículo; no expone el historial privado del conductor.
CREATE OR REPLACE FUNCTION public.conductor_actualizar_preventivo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE inicio timestamp; fin timestamp; anterior timestamp; servicio text; dias integer; resumen jsonb; vdatos jsonb;
BEGIN
 IF NEW.tipo NOT IN ('Mantenimiento preventivo','Mantenimiento correctivo') THEN RETURN NEW; END IF;
 -- Compatibilidad con registros anteriores a esta versión.
 IF NOT (NEW.datos ? 'fecha_inicio' OR NEW.datos ? 'fecha_fin' OR NEW.datos ? 'servicio_id') THEN RETURN NEW; END IF;
 IF coalesce(NEW.datos->>'fecha_inicio','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'fecha_fin','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'hora_inicio','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 OR coalesce(NEW.datos->>'hora_fin','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 THEN RAISE EXCEPTION 'Fecha y hora de inicio y fin requeridas'; END IF;
 inicio := ((NEW.datos->>'fecha_inicio')||' '||(NEW.datos->>'hora_inicio'))::timestamp;
 fin := ((NEW.datos->>'fecha_fin')||' '||(NEW.datos->>'hora_fin'))::timestamp;
 IF fin < inicio THEN RAISE EXCEPTION 'El fin no puede ser anterior al inicio'; END IF;
 IF NEW.tipo <> 'Mantenimiento preventivo' THEN RETURN NEW; END IF;
 servicio:=NEW.datos->>'servicio_id';
 IF servicio IS NULL OR servicio NOT IN ('limpieza','limpiabrisas','combustible','aceite','refrigerante','neumaticos','discos','calibracion') THEN RAISE EXCEPTION 'Servicio preventivo invalido'; END IF;
 SELECT datos INTO vdatos FROM public.conductor_vehiculos WHERE id=NEW.vehiculo_id FOR UPDATE;
 resumen:=coalesce(vdatos->'mantenimientos_preventivos','{}'::jsonb);
 anterior:=nullif(resumen->servicio->>'fin','')::timestamp;
 IF anterior IS NOT NULL AND anterior > fin THEN RETURN NEW; END IF;
 resumen:=jsonb_set(resumen,ARRAY[servicio],jsonb_build_object('fin',to_char(fin,'YYYY-MM-DD"T"HH24:MI:SS'),'km',NEW.km));
 UPDATE public.conductor_vehiculos SET datos=jsonb_set(datos,'{mantenimientos_preventivos}',resumen)
   || CASE WHEN servicio='aceite' THEN jsonb_build_object('proximo_aceite',NEW.km+8000) ELSE '{}'::jsonb END
 WHERE id=NEW.vehiculo_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.conductor_actualizar_preventivo() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS conductor_actualizar_preventivo ON public.conductor_registros;
CREATE TRIGGER conductor_actualizar_preventivo AFTER INSERT ON public.conductor_registros
FOR EACH ROW EXECUTE FUNCTION public.conductor_actualizar_preventivo();
NOTIFY pgrst,'reload schema';



-- 126_conductor_revision_preventiva.sql
-- SOLO PRUEBAS. Aplicar después de 125.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;
-- El resumen pertenece al vehículo; no expone el historial privado del conductor.
CREATE OR REPLACE FUNCTION public.conductor_actualizar_preventivo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE inicio timestamp; fin timestamp; anterior timestamp; servicio text; dias integer; resumen jsonb; vdatos jsonb;
BEGIN
 IF NEW.tipo NOT IN ('Mantenimiento preventivo','Mantenimiento correctivo') THEN RETURN NEW; END IF;
 -- Compatibilidad con registros anteriores a esta versión.
 IF NOT (NEW.datos ? 'fecha_inicio' OR NEW.datos ? 'fecha_fin' OR NEW.datos ? 'servicio_id') THEN RETURN NEW; END IF;
 IF coalesce(NEW.datos->>'fecha_inicio','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'fecha_fin','') !~ '^\d{4}-\d{2}-\d{2}$'
 OR coalesce(NEW.datos->>'hora_inicio','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 OR coalesce(NEW.datos->>'hora_fin','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 THEN RAISE EXCEPTION 'Fecha y hora de inicio y fin requeridas'; END IF;
 inicio := ((NEW.datos->>'fecha_inicio')||' '||(NEW.datos->>'hora_inicio'))::timestamp;
 fin := ((NEW.datos->>'fecha_fin')||' '||(NEW.datos->>'hora_fin'))::timestamp;
 IF fin < inicio THEN RAISE EXCEPTION 'El fin no puede ser anterior al inicio'; END IF;
 IF NEW.tipo <> 'Mantenimiento preventivo' THEN RETURN NEW; END IF;
 servicio:=NEW.datos->>'servicio_id';
 IF servicio IS NULL OR servicio NOT IN ('limpieza','limpiabrisas','combustible','aceite','refrigerante','neumaticos','discos','calibracion','revision_preventiva') THEN RAISE EXCEPTION 'Servicio preventivo invalido'; END IF;
 SELECT datos INTO vdatos FROM public.conductor_vehiculos WHERE id=NEW.vehiculo_id FOR UPDATE;
 resumen:=coalesce(vdatos->'mantenimientos_preventivos','{}'::jsonb);
 anterior:=nullif(resumen->servicio->>'fin','')::timestamp;
 IF anterior IS NOT NULL AND anterior > fin THEN RETURN NEW; END IF;
 resumen:=jsonb_set(resumen,ARRAY[servicio],jsonb_build_object('fin',to_char(fin,'YYYY-MM-DD"T"HH24:MI:SS'),'km',NEW.km));
 UPDATE public.conductor_vehiculos SET datos=jsonb_set(datos,'{mantenimientos_preventivos}',resumen)
   || CASE WHEN servicio='aceite' THEN jsonb_build_object('proximo_aceite',NEW.km+8000) ELSE '{}'::jsonb END
 WHERE id=NEW.vehiculo_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.conductor_actualizar_preventivo() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS conductor_actualizar_preventivo ON public.conductor_registros;
CREATE TRIGGER conductor_actualizar_preventivo AFTER INSERT ON public.conductor_registros
FOR EACH ROW EXECUTE FUNCTION public.conductor_actualizar_preventivo();
NOTIFY pgrst,'reload schema';



-- 127_conductor_actividades_mantenimiento.sql
-- SOLO PRUEBAS. Aplicar después de 126. Actividades de mantenimiento asignadas.

SET LOCAL lock_timeout='5s';
SET LOCAL client_min_messages=warning;
DO $$ BEGIN
 
 
END $$;


ALTER TABLE public.conductor_tareas ALTER COLUMN registro_id DROP NOT NULL;
ALTER TABLE public.conductor_revision_eventos ALTER COLUMN registro_id DROP NOT NULL;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS vehiculo_id uuid REFERENCES public.conductor_vehiculos(id);
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_tipo text CHECK(mantenimiento_tipo IN('Mantenimiento preventivo','Mantenimiento correctivo'));
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_trabajo text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS servicio_id text;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_datos jsonb;
ALTER TABLE public.conductor_tareas ADD COLUMN IF NOT EXISTS mantenimiento_registro_id uuid REFERENCES public.conductor_registros(id);
ALTER TABLE public.conductor_revision_eventos ADD COLUMN IF NOT EXISTS vehiculo_id uuid REFERENCES public.conductor_vehiculos(id);
UPDATE public.conductor_tareas t SET vehiculo_id=r.vehiculo_id FROM public.conductor_registros r WHERE t.registro_id=r.id AND t.vehiculo_id IS NULL;
CREATE INDEX IF NOT EXISTS conductor_tareas_vehiculo_idx ON public.conductor_tareas(vehiculo_id,estado);
CREATE OR REPLACE FUNCTION public.conductor_revision_resumen(p_vehiculo uuid,p_detalle boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; salida public.conductor_registros; resultado jsonb; revisiones jsonb;
BEGIN
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO salida FROM public.conductor_registros WHERE vehiculo_id=v.id AND tipo='Inicio de jornada' AND datos->>'fecha'=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
 resultado:=jsonb_build_object('version',2,'estado',CASE WHEN salida.id IS NULL THEN 'Sin checklist de salida' ELSE coalesce((SELECT estado FROM public.conductor_autorizaciones WHERE registro_id=salida.id),'Pendiente de aprobación') END,
 'observacion',(SELECT observacion FROM public.conductor_autorizaciones WHERE registro_id=salida.id));
 resultado:=resultado || jsonb_build_object('tareas',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.creado) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND (t.estado<>'Cerrada' OR (p_detalle AND public.admin_es_admin()))),'[]'::jsonb));
 IF p_detalle AND public.admin_es_admin() THEN
  SELECT coalesce(jsonb_agg(q ORDER BY q.creado DESC),'[]'::jsonb) INTO revisiones FROM (
   SELECT r.id,r.tipo,r.creado,r.actor_nombre,r.datos,coalesce(a.estado,'Pendiente de aprobación') AS estado
   FROM public.conductor_registros r LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=r.id
   WHERE r.vehiculo_id=v.id AND r.tipo IN('Inicio de jornada','Fin de jornada','Checklist semanal de carretera')
   ORDER BY r.creado DESC LIMIT 100
  ) q;
  resultado:=resultado || jsonb_build_object('checklists',revisiones);
 END IF;
 RETURN resultado;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_flota_resumen() RETURNS SETOF jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE hoy text:=to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD');
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT to_jsonb(v)||jsonb_build_object(
 'conductor_nombre',coalesce(u.nombre,'Sin asignar'),'conductor_numero',u.numero_usuario,
 'inicio',s.id IS NOT NULL,'fin',EXISTS(SELECT 1 FROM public.conductor_registros r WHERE r.vehiculo_id=v.id AND r.tipo='Fin de jornada' AND r.datos->>'fecha'=hoy),
 'autorizacion',CASE WHEN s.id IS NULL THEN 'Sin checklist' ELSE coalesce(a.estado,'Pendiente de aprobación') END,
 'pendientes',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Pendiente'),
 'por_verificar',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Por verificar'),
 'vencidas',(SELECT count(*) FROM public.conductor_tareas t LEFT JOIN public.conductor_registros r ON r.id=t.registro_id WHERE coalesce(t.vehiculo_id,r.vehiculo_id)=v.id AND t.estado='Pendiente' AND t.fecha_limite<hoy::date))
 FROM public.conductor_vehiculos v LEFT JOIN public.usuarios u ON u.auth_id=v.conductor_id
 LEFT JOIN public.conductor_registros s ON s.vehiculo_id=v.id AND s.tipo='Inicio de jornada' AND s.datos->>'fecha'=hoy
 LEFT JOIN public.conductor_autorizaciones a ON a.registro_id=s.id ORDER BY v.placa;
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_mantenimiento_crear(
 p_vehiculo uuid,p_registro uuid,p_motivos text[],p_descripcion text,p_fecha date,
 p_tipo text,p_trabajo text,p_servicio text DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; r public.conductor_registros; nueva uuid; trabajo text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL THEN RAISE EXCEPTION 'Vehículo inexistente'; END IF;
 IF p_tipo IS NULL OR p_tipo NOT IN('Mantenimiento preventivo','Mantenimiento correctivo') THEN RAISE EXCEPTION 'Selecciona el tipo de mantenimiento'; END IF;
 IF p_tipo='Mantenimiento preventivo' THEN
  trabajo:=CASE p_servicio
   WHEN 'limpieza' THEN 'Limpieza general del vehículo'
   WHEN 'limpiabrisas' THEN 'Llenado de tanque de agua para limpiabrisas'
   WHEN 'combustible' THEN 'Llenado de tanque de combustible'
   WHEN 'aceite' THEN 'Cambio de aceite'
   WHEN 'refrigerante' THEN 'Llenado de líquido refrigerante'
   WHEN 'neumaticos' THEN 'Cambio de neumáticos'
   WHEN 'discos' THEN 'Cambio de disco de frenos'
   WHEN 'calibracion' THEN 'Calibración de aire en los neumáticos'
   WHEN 'revision_preventiva' THEN 'Revisión preventiva' END;
  IF trabajo IS NULL OR trabajo IS DISTINCT FROM p_trabajo THEN RAISE EXCEPTION 'Mantenimiento preventivo inválido'; END IF;
 ELSE
  trabajo:=trim(p_trabajo);
  IF trabajo IS NULL OR length(trabajo) NOT BETWEEN 1 AND 1000 OR p_servicio IS NOT NULL THEN RAISE EXCEPTION 'Describe el mantenimiento correctivo'; END IF;
 END IF;
 IF p_registro IS NOT NULL THEN
  SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
  IF r.vehiculo_id IS DISTINCT FROM p_vehiculo THEN RAISE EXCEPTION 'El checklist no corresponde al vehículo'; END IF;
  nueva:=public.conductor_actividad_crear(p_registro,p_motivos,p_descripcion,p_fecha);
 ELSE
  IF coalesce(cardinality(p_motivos),0)<>0 THEN RAISE EXCEPTION 'La actividad independiente no tiene motivos del checklist'; END IF;
  IF p_fecha IS NULL OR p_fecha<(now() AT TIME ZONE 'America/Bogota')::date THEN RAISE EXCEPTION 'Fecha límite inválida'; END IF;
  IF p_descripcion IS NULL OR length(trim(p_descripcion)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la actividad'; END IF;
  INSERT INTO public.conductor_tareas(vehiculo_id,punto,motivos,descripcion,fecha_limite,creador)
   VALUES(v.id,gen_random_uuid()::text,'[]',trim(p_descripcion),p_fecha,auth.uid()) RETURNING id INTO nueva;
 END IF;
 UPDATE public.conductor_tareas SET vehiculo_id=v.id,mantenimiento_tipo=p_tipo,mantenimiento_trabajo=trabajo,servicio_id=p_servicio WHERE id=nueva;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos)
  VALUES(p_registro,v.id,auth.uid(),'Asignar mantenimiento',jsonb_build_object('tarea',nueva,'tipo',p_tipo,'trabajo',trabajo,'servicio_id',p_servicio));
 RETURN nueva;
END $$;

-- La entrega y el mantenimiento se guardan en una misma transacción.
CREATE OR REPLACE FUNCTION public.conductor_vincular_mantenimiento() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 IF NEW.datos->>'actividad_id' IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=NEW.vehiculo_id FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=(NEW.datos->>'actividad_id')::uuid FOR UPDATE;
 IF t.id IS NULL OR t.vehiculo_id IS DISTINCT FROM NEW.vehiculo_id OR t.estado<>'Pendiente' THEN RAISE EXCEPTION 'Actividad inexistente o no pendiente'; END IF;
 IF t.mantenimiento_tipo IS NULL OR t.mantenimiento_tipo IS DISTINCT FROM NEW.tipo
  OR t.mantenimiento_trabajo IS DISTINCT FROM NEW.datos->>'servicio'
  OR (NEW.tipo='Mantenimiento preventivo' AND t.servicio_id IS DISTINCT FROM NEW.datos->>'servicio_id') THEN
  RAISE EXCEPTION 'El mantenimiento no coincide con lo asignado por el administrador';
 END IF;
 IF NOT (NEW.datos ?& ARRAY['fecha_inicio','hora_inicio','fecha_fin','hora_fin']) THEN RAISE EXCEPTION 'Completa las fechas y horas del mantenimiento'; END IF;
 IF coalesce(NEW.datos->>'enlace','') !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta evidencia del mantenimiento'; END IF;
 IF NEW.tipo='Mantenimiento preventivo' AND t.servicio_id='combustible' THEN
  IF coalesce(NEW.datos->>'galones','') !~ '^[0-9]+([.][0-9]+)?$' OR (NEW.datos->>'galones')::numeric<=0 THEN RAISE EXCEPTION 'Ingresa los galones del tanqueo'; END IF;
 END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=NEW.datos->>'servicio',
  evidencia=NEW.datos->>'enlace',entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now(),mantenimiento_registro_id=NEW.id,mantenimiento_datos=NEW.datos WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos)
  VALUES(t.registro_id,v.id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'mantenimiento_registro_id',NEW.id));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS conductor_vincular_mantenimiento ON public.conductor_registros;
CREATE TRIGGER conductor_vincular_mantenimiento AFTER INSERT ON public.conductor_registros FOR EACH ROW EXECUTE FUNCTION public.conductor_vincular_mantenimiento();
CREATE OR REPLACE FUNCTION public.conductor_revision_accion(p_registro uuid,p_accion text,p_texto text,p_punto text DEFAULT NULL,p_tarea uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.conductor_registros; v public.conductor_vehiculos; t public.conductor_tareas; es_admin boolean:=public.admin_es_admin(); valor jsonb;
BEGIN
 SELECT * INTO r FROM public.conductor_registros WHERE id=p_registro;
 IF p_tarea IS NOT NULL THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea;
  IF t.registro_id IS DISTINCT FROM p_registro THEN RAISE EXCEPTION 'Actividad incorrecta'; END IF;
 END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=coalesce(t.vehiculo_id,r.vehiculo_id) FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Escribe una observación de hasta 1000 caracteres'; END IF;
 IF p_accion IN('Autorizado','No autorizado') THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
  IF r.id IS NULL OR r.tipo<>'Inicio de jornada' OR r.datos->>'fecha'<>to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD') THEN RAISE EXCEPTION 'Solo se autoriza la salida de hoy'; END IF;
  INSERT INTO public.conductor_autorizaciones VALUES(r.id,p_accion,trim(p_texto),auth.uid(),now()) ON CONFLICT(registro_id) DO UPDATE SET estado=excluded.estado,observacion=excluded.observacion,administrador=excluded.administrador,actualizado=now();
 ELSIF p_accion IN('Crear actividad','Por verificar') THEN
  RAISE EXCEPTION 'Actualiza la aplicación para asignar actividades con fecha y foto';
 ELSIF p_accion IN('Por verificar','Cerrada','Pendiente') THEN
  SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea AND registro_id IS NOT DISTINCT FROM p_registro FOR UPDATE;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Actividad inexistente'; END IF;
  IF p_accion='Por verificar' THEN
   IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya fue reportada'; END IF;
  ELSE
   IF NOT es_admin THEN RAISE EXCEPTION 'Solo administrador' USING ERRCODE='42501'; END IF;
   IF t.estado<>'Por verificar' THEN RAISE EXCEPTION 'La actividad no está pendiente de verificación'; END IF;
  END IF;
  UPDATE public.conductor_tareas SET estado=p_accion,respuesta=trim(p_texto),actualizado=now() WHERE id=t.id;
 ELSE RAISE EXCEPTION 'Acción inválida'; END IF;
 INSERT INTO public.conductor_revision_eventos(registro_id,vehiculo_id,actor,accion,datos) VALUES(r.id,v.id,auth.uid(),p_accion,jsonb_build_object('texto',trim(p_texto),'punto',p_punto,'tarea',p_tarea));
END $$;

CREATE OR REPLACE FUNCTION public.conductor_actividad_entregar(p_tarea uuid,p_texto text,p_evidencia text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t public.conductor_tareas; v public.conductor_vehiculos;
BEGIN
 SELECT v1.* INTO v FROM public.conductor_vehiculos v1 JOIN public.conductor_registros r ON r.vehiculo_id=v1.id JOIN public.conductor_tareas t1 ON t1.registro_id=r.id WHERE t1.id=p_tarea FOR UPDATE OF v1;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.conductor_tareas WHERE id=p_tarea FOR UPDATE;
 IF t.mantenimiento_tipo IS NOT NULL THEN RAISE EXCEPTION 'Completa el formulario de mantenimiento asignado'; END IF;
 IF p_texto IS NULL OR length(trim(p_texto)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Describe la solución'; END IF;
 IF p_evidencia IS NULL OR p_evidencia !~ '^https://drive[.]google[.]com/file/d/[A-Za-z0-9_-]+/view$' THEN RAISE EXCEPTION 'Adjunta la foto de la actividad realizada'; END IF;
 IF t.estado='Por verificar' AND t.evidencia=p_evidencia AND t.solucion=trim(p_texto) AND t.entregado_por=auth.uid() THEN RETURN; END IF;
 IF t.estado<>'Pendiente' THEN RAISE EXCEPTION 'La actividad ya no está pendiente'; END IF;
 UPDATE public.conductor_tareas SET estado='Por verificar',solucion=trim(p_texto),evidencia=p_evidencia,entregado_por=auth.uid(),entregado_en=clock_timestamp(),actualizado=now() WHERE id=t.id;
 INSERT INTO public.conductor_revision_eventos(registro_id,actor,accion,datos) VALUES(t.registro_id,auth.uid(),'Por verificar',jsonb_build_object('tarea',t.id,'solucion',trim(p_texto),'evidencia',p_evidencia));
END $$;

REVOKE ALL ON FUNCTION public.conductor_actividad_mantenimiento_crear(uuid,uuid,text[],text,date,text,text,text),public.conductor_vincular_mantenimiento() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_actividad_mantenimiento_crear(uuid,uuid,text[],text,date,text,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 128_conductor_kit_admin_epp.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.conductor_historial(uuid,date,date,integer,integer)') IS NULL THEN RAISE EXCEPTION 'Requiere historial privado 115'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.conductor_registrar_kit(p_vehiculo uuid,p_datos jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v public.conductor_vehiculos; actor text; registro uuid; p jsonb; r jsonb; nombre text; estado text;
 fecha date; vencimiento date; hoy date:=(now() AT TIME ZONE 'America/Bogota')::date;
 catalogo jsonb:=$catalogo$[{"nombre": "Gato para elevar el vehículo", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Manivela o mecanismo de accionamiento", "categoria": "Gato", "vencimiento": false, "opcional": false}, {"nombre": "Cruceta para las tuercas de las ruedas", "categoria": "Cruceta", "vencimiento": false, "opcional": false}, {"nombre": "Triángulo reflectivo N.º 1", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Triángulo reflectivo N.º 2", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Soportes de los triángulos", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Lámparas amarillas intermitentes", "categoria": "Señalización", "vencimiento": false, "opcional": true}, {"nombre": "Guantes desechables de nitrilo", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Mascarilla de barrera para RCP", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Gasas estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos estériles", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Vendas de gasa", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Venda elástica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Esparadrapo o cinta médica", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Apósitos adhesivos", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Solución salina estéril", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Toallitas antisépticas", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Compresa estéril para quemaduras", "categoria": "Botiquín", "vencimiento": true, "opcional": false}, {"nombre": "Tijeras de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Pinzas de punta roma", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Manta térmica de emergencia", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Bolsas para material contaminado", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Estuche del botiquín", "categoria": "Botiquín", "vencimiento": false, "opcional": false}, {"nombre": "Extintor adecuado para el vehículo", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Carga y mantenimiento del extintor", "categoria": "Extintor", "vencimiento": true, "opcional": false}, {"nombre": "Manómetro, seguro y sello", "categoria": "Extintor", "vencimiento": false, "opcional": true}, {"nombre": "Soporte de fijación del extintor", "categoria": "Extintor", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 1", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Taco de bloqueo N.º 2", "categoria": "Tacos", "vencimiento": false, "opcional": false}, {"nombre": "Alicate", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de pala", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Destornillador de estrella", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llave de expansión", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Juego de llaves fijas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Caja o bolso de herramientas", "categoria": "Caja de herramientas", "vencimiento": false, "opcional": false}, {"nombre": "Llanta de repuesto compatible", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Presión y estado de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Fijación de la llanta", "categoria": "Llanta de repuesto", "vencimiento": false, "opcional": false}, {"nombre": "Linterna funcional", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Pilas o batería con carga", "categoria": "Linterna", "vencimiento": false, "opcional": false}, {"nombre": "Chaleco reflectivo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cables de arranque o arrancador portátil", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Compresor o medidor de presión", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Sellador de pinchazos", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Guantes de trabajo", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Agua potable", "categoria": "Elementos adicionales recomendados", "vencimiento": true, "opcional": true}, {"nombre": "Impermeable", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cargador portátil para celular", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Cuerda de remolque compatible", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Contactos de emergencia", "categoria": "Elementos adicionales recomendados", "vencimiento": false, "opcional": true}, {"nombre": "Kit antiderrames", "categoria": "Kit antiderrames", "vencimiento": false, "opcional": false}]$catalogo$::jsonb;
 novedades integer:=0;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo el administrador puede revisar el kit de carretera' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.conductor_vehiculos WHERE id=p_vehiculo FOR UPDATE;
 IF v.id IS NULL OR NOT public.conductor_acceso(v.conductor_id) THEN RAISE EXCEPTION 'Sin acceso al vehículo' USING ERRCODE='42501'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos) IS DISTINCT FROM 'object' OR octet_length(p_datos::text)>16000 THEN RAISE EXCEPTION 'Datos inválidos'; END IF;
 IF length(trim(coalesce(p_datos->>'inspector',''))) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Inspector requerido'; END IF;
 IF length(coalesce(p_datos->>'lugar',''))>160 OR length(coalesce(p_datos->>'notas',''))>1000 THEN RAISE EXCEPTION 'Texto demasiado largo'; END IF;
 IF coalesce(p_datos->>'fecha','') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Fecha requerida'; END IF;
 fecha:=(p_datos->>'fecha')::date;
 IF fecha<date_trunc('week',hoy::timestamp)::date OR fecha>hoy THEN RAISE EXCEPTION 'La inspección debe corresponder a esta semana y no ser futura'; END IF;
 IF jsonb_typeof(p_datos->'respuestas') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Checklist requerido'; END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(p_datos->'respuestas'))<>jsonb_array_length(catalogo) THEN RAISE EXCEPTION 'Completa todos los puntos del kit de carretera'; END IF;
 FOR p IN SELECT value FROM jsonb_array_elements(catalogo) LOOP
   nombre:=p->>'nombre'; r:=p_datos->'respuestas'->nombre; estado:=r->>'estado';
   IF r IS NULL OR jsonb_typeof(r)<>'object' OR coalesce(estado,'') NOT IN('Buen estado','Con novedad','No aplica') THEN RAISE EXCEPTION 'Punto pendiente: %',nombre; END IF;
   IF estado='No aplica' AND NOT (p->>'opcional')::boolean THEN RAISE EXCEPTION 'No aplica no permitido: %',nombre; END IF;
   IF length(coalesce(r->>'detalle',''))>120 THEN RAISE EXCEPTION 'Detalle demasiado largo: %',nombre; END IF;
   IF estado='Con novedad' THEN
     IF length(trim(coalesce(r->>'detalle','')))=0 THEN RAISE EXCEPTION 'Describe la novedad: %',nombre; END IF;
     novedades:=novedades+1;
   END IF;
   IF coalesce(r->>'vencimiento','')<>'' THEN
     IF NOT (p->>'vencimiento')::boolean OR estado='No aplica' OR (r->>'vencimiento') !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Vencimiento inválido: %',nombre; END IF;
     vencimiento:=(r->>'vencimiento')::date;
     IF vencimiento<fecha AND estado='Buen estado' THEN RAISE EXCEPTION 'Elemento vencido: %',nombre; END IF;
   END IF;
 END LOOP;
 IF (p_datos->'respuestas'->'Lámparas amarillas intermitentes'->>'estado')='No aplica' AND EXISTS(
 SELECT 1 FROM unnest(ARRAY['Triángulo reflectivo N.º 1','Triángulo reflectivo N.º 2','Soportes de los triángulos']) n
 WHERE (p_datos->'respuestas'->n->>'estado')='No aplica') THEN RAISE EXCEPTION 'Revisa ambos triángulos y soportes o las lámparas alternativas'; END IF;
 SELECT u.nombre INTO actor FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo;
 -- Lista blanca de datos: el cliente no puede sustituir el resultado calculado.
 p_datos:=jsonb_build_object('inspector',trim(p_datos->>'inspector'),'fecha',to_char(fecha,'YYYY-MM-DD'),
 'lugar',trim(coalesce(p_datos->>'lugar','')),'notas',trim(coalesce(p_datos->>'notas','')),
 'respuestas',p_datos->'respuestas','resultado',CASE WHEN novedades>0 THEN 'Requiere revisión' ELSE 'Sin novedades' END);
 INSERT INTO public.conductor_registros(vehiculo_id,actor_id,actor_nombre,tipo,km,datos)
 VALUES(p_vehiculo,auth.uid(),actor,'Checklist semanal de carretera',v.km,p_datos) RETURNING id INTO registro;
 RETURN registro;
END $$;
REVOKE ALL ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.conductor_registrar_kit(uuid,jsonb) TO authenticated;
-- Se calcula desde registros inmutables, no desde los documentos editables del vehículo.

-- Conserva los cambios de las migraciones anteriores y los registros históricos.
DO $actualizar$
DECLARE definicion text;
BEGIN
 SELECT pg_get_functiondef('public.conductor_registrar(uuid,text,integer,jsonb)'::regprocedure) INTO definicion;
 IF position('Botas de lluvia' in definicion)=0 THEN
   IF position('''Kit de derrames'',''Extintor'']' in definicion)=0 THEN
     RAISE EXCEPTION 'No se reconoce el catálogo diario; revisar la versión de conductor_registrar';
   END IF;
   definicion:=replace(definicion,'''Kit de derrames'',''Extintor'']','''Kit de derrames'',''Extintor'',''Botas de lluvia'',''Impermeable'',''Guantes de trabajo'',''Chaleco reflectivo'']');
   EXECUTE definicion;
 END IF;
END $actualizar$;
NOTIFY pgrst,'reload schema';



-- Ninguna fila ni columna original puede cambiar; incluye documentos emitidos y Auth.
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
 IF EXISTS(SELECT fila FROM previo_secuencias EXCEPT ALL SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public') THEN RAISE EXCEPTION 'Cambió un consecutivo: rollback'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
