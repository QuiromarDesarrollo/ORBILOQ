-- RECUPERACION PUNTUAL GI GROUP. SOLO PRODUCCION cxrflhgnxvomcvxzugda.
-- Fuente: CARGUE 23-10-26.xlsx. 12 OP (25637 a 25648), 44 lineas, 426 unidades.
-- Conserva las cabeceras y solo inserta tallas; no registra entregas ni recepciones.
-- Ejecutar COMPLETO en SQL Editor. Si falla, ninguna insercion se confirma.
-- Una segunda ejecucion se rechaza para evitar duplicados.
-- SHA256 del Excel: b9db67ed811dedf84c2318f2aa8812c6dd8fd8dad615b5e7fbccae846abe3a56
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
 AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda'
 THEN RAISE EXCEPTION 'Proyecto incorrecto. Usar PRODUCCION cxrflhgnxvomcvxzugda'; END IF;
END $$;
CREATE TEMP TABLE recuperacion_gi_group ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset($datos$
[
  {
    "op": "25637",
    "orden_id": "a20a3090-d919-41bf-9071-38726621dec2",
    "codigo": "2026770640",
    "descripcion": "BORDADO SERVICIO N/A T. U",
    "talla": "U",
    "cantidad": 221,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "SE SOLICITA BORDAR EL LOGO GI GROUP SEGUN LA FT DEL BORDADO GI GROUP BOLS 8 CM V0 OM 7622 EN LADO DERECHO CAMISAS ALINEADO AL LOGO DE ENEL \n\nSE SOLICITA BORDAR 127 CAMISAS EN TWILL Y OXFORD DE ACUERDO AL LISTADO EN EXCEL QUE SE ENCUENTRA EN LA ORDEN DE COMPRA\n\nSE SOLICTA REMARQUILLAR 96 PRENDAS DE ACUERDO AL LISTADO EN EXCEL QUE SE ENCUENTRA EN LA ORDEN DE COMPRA\n",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25638",
    "orden_id": "446d8000-037c-4cc4-afce-c3c7fe333db4",
    "codigo": "2026770720",
    "descripcion": "PANTALON DAMA N/A T. 6",
    "talla": "6",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT 2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25638",
    "orden_id": "446d8000-037c-4cc4-afce-c3c7fe333db4",
    "codigo": "2026770721",
    "descripcion": "PANTALON DAMA N/A T. 8",
    "talla": "8",
    "cantidad": 7,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT 2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25638",
    "orden_id": "446d8000-037c-4cc4-afce-c3c7fe333db4",
    "codigo": "2026770722",
    "descripcion": "PANTALON DAMA N/A T. 10",
    "talla": "10",
    "cantidad": 7,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT 2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25638",
    "orden_id": "446d8000-037c-4cc4-afce-c3c7fe333db4",
    "codigo": "2026770724",
    "descripcion": "PANTALON DAMA N/A T. 14",
    "talla": "14",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT 2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25639",
    "orden_id": "969534cd-23d2-461a-928c-851bb860690e",
    "codigo": "2026770827",
    "descripcion": "PANTALON HOMBRE N/A T. 28",
    "talla": "28",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT-2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25639",
    "orden_id": "969534cd-23d2-461a-928c-851bb860690e",
    "codigo": "2026770829",
    "descripcion": "PANTALON HOMBRE N/A T. 32",
    "talla": "32",
    "cantidad": 5,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT-2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25640",
    "orden_id": "8ce373c2-0d16-456f-9de1-8d3a2b485061",
    "codigo": "2026771916",
    "descripcion": "CAMIBUZO N/A T. M",
    "talla": "M",
    "cantidad": 3,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCO",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25641",
    "orden_id": "80f757a1-adcb-485a-b499-0ffbd741cf6e",
    "codigo": "202677188",
    "descripcion": "CAMIBUZO N/A T. XS/6",
    "talla": "XS/6",
    "cantidad": 5,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25641",
    "orden_id": "80f757a1-adcb-485a-b499-0ffbd741cf6e",
    "codigo": "202677189",
    "descripcion": "CAMIBUZO N/A T. S/8",
    "talla": "S/8",
    "cantidad": 12,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25641",
    "orden_id": "80f757a1-adcb-485a-b499-0ffbd741cf6e",
    "codigo": "2026771810",
    "descripcion": "CAMIBUZO N/A T. M/10",
    "talla": "M/10",
    "cantidad": 11,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25641",
    "orden_id": "80f757a1-adcb-485a-b499-0ffbd741cf6e",
    "codigo": "2026771811",
    "descripcion": "CAMIBUZO N/A T. L/12",
    "talla": "L/12",
    "cantidad": 3,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25641",
    "orden_id": "80f757a1-adcb-485a-b499-0ffbd741cf6e",
    "codigo": "2026771812",
    "descripcion": "CAMIBUZO N/A T. XL/14",
    "talla": "XL/14",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25642",
    "orden_id": "5556c162-f919-4e54-bde0-54f07f0a3a4b",
    "codigo": "2026771916",
    "descripcion": "CAMIBUZO N/A T. M",
    "talla": "M",
    "cantidad": 17,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25642",
    "orden_id": "5556c162-f919-4e54-bde0-54f07f0a3a4b",
    "codigo": "2026771917",
    "descripcion": "CAMIBUZO N/A T. L",
    "talla": "L",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25643",
    "orden_id": "9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09",
    "codigo": "202677218",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. XS/6",
    "talla": "XS/6",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25643",
    "orden_id": "9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09",
    "codigo": "202677219",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. S/8",
    "talla": "S/8",
    "cantidad": 10,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25643",
    "orden_id": "9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09",
    "codigo": "2026772110",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. M/10",
    "talla": "M/10",
    "cantidad": 6,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25643",
    "orden_id": "9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09",
    "codigo": "2026772111",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. L/12",
    "talla": "L/12",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25643",
    "orden_id": "9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09",
    "codigo": "2026772112",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. XL/14",
    "talla": "XL/14",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25644",
    "orden_id": "c33080cd-c066-44e0-936d-3a50df2acbe1",
    "codigo": "2026771716",
    "descripcion": "CAMISA HOMBRE MANGA LARGA N/A T. M",
    "talla": "M",
    "cantidad": 10,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25644",
    "orden_id": "c33080cd-c066-44e0-936d-3a50df2acbe1",
    "codigo": "2026771717",
    "descripcion": "CAMISA HOMBRE MANGA LARGA N/A T. L",
    "talla": "L",
    "cantidad": 3,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25644",
    "orden_id": "c33080cd-c066-44e0-936d-3a50df2acbe1",
    "codigo": "2026771718",
    "descripcion": "CAMISA HOMBRE MANGA LARGA N/A T. XL",
    "talla": "XL",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR BLANCA",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25645",
    "orden_id": "6c15eb4f-ff54-466f-9a45-649bdf74a992",
    "codigo": "202677218",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. XS/6",
    "talla": "XS/6",
    "cantidad": 3,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25645",
    "orden_id": "6c15eb4f-ff54-466f-9a45-649bdf74a992",
    "codigo": "202677219",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. S/8",
    "talla": "S/8",
    "cantidad": 13,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25645",
    "orden_id": "6c15eb4f-ff54-466f-9a45-649bdf74a992",
    "codigo": "2026772110",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. M/10",
    "talla": "M/10",
    "cantidad": 9,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25645",
    "orden_id": "6c15eb4f-ff54-466f-9a45-649bdf74a992",
    "codigo": "2026772111",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. L/12",
    "talla": "L/12",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25645",
    "orden_id": "6c15eb4f-ff54-466f-9a45-649bdf74a992",
    "codigo": "2026772112",
    "descripcion": "BLUSA MUJER MANGA LARGA N/A T. XL/14",
    "talla": "XL/14",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026\n\nCONFECCIONAR EN COLOR AZUL",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25646",
    "orden_id": "7e98a1fb-8d8f-472e-b3e7-b7e6b3330d40",
    "codigo": "202677139",
    "descripcion": "CHAQUETA COMBINADA MUJER N/A T. S/8",
    "talla": "S/8",
    "cantidad": 4,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770920",
    "descripcion": "JEAN MUJER N/A T. 6",
    "talla": "6",
    "cantidad": 2,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770921",
    "descripcion": "JEAN MUJER N/A T. 8",
    "talla": "8",
    "cantidad": 10,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770922",
    "descripcion": "JEAN MUJER N/A T. 10",
    "talla": "10",
    "cantidad": 16,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770923",
    "descripcion": "JEAN MUJER N/A T. 12",
    "talla": "12",
    "cantidad": 9,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770924",
    "descripcion": "JEAN MUJER N/A T. 14",
    "talla": "14",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770925",
    "descripcion": "JEAN MUJER N/A T. 16",
    "talla": "16",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770926",
    "descripcion": "JEAN MUJER N/A T. 18",
    "talla": "18",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25647",
    "orden_id": "9e8fbc87-c6e4-44a6-957c-e355278816d6",
    "codigo": "2026770942",
    "descripcion": "JEAN MUJER N/A T. 20",
    "talla": "20",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771027",
    "descripcion": "JEAN HOMBRE N/A T. 28",
    "talla": "28",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771028",
    "descripcion": "JEAN HOMBRE N/A T. 30",
    "talla": "30",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771029",
    "descripcion": "JEAN HOMBRE N/A T. 32",
    "talla": "32",
    "cantidad": 9,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771030",
    "descripcion": "JEAN HOMBRE N/A T. 34",
    "talla": "34",
    "cantidad": 6,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771031",
    "descripcion": "JEAN HOMBRE N/A T. 36",
    "talla": "36",
    "cantidad": 6,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771032",
    "descripcion": "JEAN HOMBRE N/A T. 38",
    "talla": "38",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  },
  {
    "op": "25648",
    "orden_id": "04f80421-33c8-42ad-bcc0-f73f940f419f",
    "codigo": "2026771034",
    "descripcion": "JEAN HOMBRE N/A T. 40",
    "talla": "40",
    "cantidad": 1,
    "oc": "ORDEN DE COMPRA 273 Y 274",
    "oc_id_erp": 3588,
    "observacion": "MARQUILLA DOT -2026",
    "cliente": "GI GROUP STAFFING S.A.S"
  }
]
$datos$::jsonb)
 AS x(op text,orden_id uuid,codigo text,descripcion text,talla text,cantidad integer,
      oc text,oc_id_erp bigint,observacion text,cliente text);
-- Evita cambios concurrentes durante la comprobacion y la insercion.
LOCK TABLE public.ordenes_produccion, public.items_orden IN SHARE ROW EXCLUSIVE MODE;
DO $validar$
BEGIN
 IF (SELECT count(*) FROM recuperacion_gi_group)<>44
 OR (SELECT count(DISTINCT orden_id) FROM recuperacion_gi_group)<>12
 OR (SELECT sum(cantidad) FROM recuperacion_gi_group)<>426
 THEN RAISE EXCEPTION 'El contenido del archivo de recuperacion no coincide'; END IF;
 IF EXISTS(SELECT 1 FROM recuperacion_gi_group WHERE cantidad<=0 OR nullif(codigo,'') IS NULL OR nullif(talla,'') IS NULL)
 OR EXISTS(SELECT 1 FROM recuperacion_gi_group GROUP BY orden_id,codigo,talla HAVING count(*)>1)
 THEN RAISE EXCEPTION 'Lineas invalidas o duplicadas'; END IF;
 IF EXISTS(SELECT 1 FROM recuperacion_gi_group r
 LEFT JOIN public.ordenes_produccion o ON o.id=r.orden_id AND o.numero_op=r.op
 WHERE o.id IS NULL)
 THEN RAISE EXCEPTION 'No coinciden los ID de las OP. Verifica la base de datos'; END IF;
 IF EXISTS(SELECT 1 FROM recuperacion_gi_group r JOIN public.ordenes_produccion o ON o.id=r.orden_id
 WHERE btrim(coalesce(o.cliente,'')) IS DISTINCT FROM r.cliente
 OR btrim(coalesce(o.oc_cabecera,'')) IS DISTINCT FROM r.oc)
 THEN RAISE EXCEPTION 'Cliente u OC no coincide con el diagnostico. Revisar antes de continuar'; END IF;
 IF EXISTS(SELECT 1 FROM public.items_orden i JOIN recuperacion_gi_group r ON r.orden_id=i.orden_id)
 THEN RAISE EXCEPTION 'Una OP ya tiene lineas. No se modifico nada; actualizar el diagnostico'; END IF;
END $validar$;
INSERT INTO public.items_orden(orden_id,codigo,descripcion,talla,cantidad_pedida,oc,oc_id_erp,observacion)
SELECT orden_id,codigo,descripcion,talla,cantidad,oc,oc_id_erp,observacion
FROM recuperacion_gi_group;
DO $verificar$
BEGIN
 IF (SELECT count(*) FROM public.items_orden WHERE orden_id IN (SELECT orden_id FROM recuperacion_gi_group))<>44
 OR (SELECT sum(cantidad_pedida) FROM public.items_orden WHERE orden_id IN (SELECT orden_id FROM recuperacion_gi_group))<>426
 THEN RAISE EXCEPTION 'Los totales finales no coinciden: se revierte la recuperacion'; END IF;
 IF EXISTS(SELECT 1 FROM recuperacion_gi_group r
 LEFT JOIN public.items_orden i ON i.orden_id=r.orden_id AND i.codigo=r.codigo AND i.talla=r.talla
 WHERE i.id IS NULL OR i.cantidad_pedida IS DISTINCT FROM r.cantidad OR i.admin_eliminado_en IS NOT NULL
 OR i.descripcion IS DISTINCT FROM r.descripcion
 OR i.oc IS DISTINCT FROM r.oc OR i.oc_id_erp IS DISTINCT FROM r.oc_id_erp
 OR i.observacion IS DISTINCT FROM r.observacion)
 THEN RAISE EXCEPTION 'Una linea no coincide: se revierte la recuperacion'; END IF;
END $verificar$;
COMMIT;
-- Resultado esperado: 12 filas; 44 lineas y 426 unidades en total.
SELECT o.numero_op AS op,o.cliente,count(i.id) AS tallas,sum(i.cantidad_pedida) AS unidades
FROM public.ordenes_produccion o JOIN public.items_orden i ON i.orden_id=o.id
WHERE o.id IN ('a20a3090-d919-41bf-9071-38726621dec2','446d8000-037c-4cc4-afce-c3c7fe333db4','969534cd-23d2-461a-928c-851bb860690e','8ce373c2-0d16-456f-9de1-8d3a2b485061','80f757a1-adcb-485a-b499-0ffbd741cf6e','5556c162-f919-4e54-bde0-54f07f0a3a4b','9b2d4562-6f09-47bb-8bab-4fd7aa6bdc09','c33080cd-c066-44e0-936d-3a50df2acbe1','6c15eb4f-ff54-466f-9a45-649bdf74a992','7e98a1fb-8d8f-472e-b3e7-b7e6b3330d40','9e8fbc87-c6e4-44a6-957c-e355278816d6','04f80421-33c8-42ad-bcc0-f73f940f419f')
GROUP BY o.numero_op,o.cliente ORDER BY o.numero_op;
