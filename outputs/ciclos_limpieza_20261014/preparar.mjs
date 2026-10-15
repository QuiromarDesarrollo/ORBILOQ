import fs from 'node:fs/promises';
import {Workbook, SpreadsheetFile} from '@oai/artifact-tool';
const dir = new URL('./', import.meta.url);
const datos = JSON.parse(await fs.readFile(new URL('reorganizado.json',dir),'utf8'));
const validas = datos.rows;

const wb = Workbook.create();
const headers=['N° DE ORDEN','CLIENTE','CANTIDAD','FECHA DE INICIO','COMPRAS','TRAZO','CORTE','SEPARADO','ALIADOS','TERMINADO','LOGISTICA','FECHA COMPROMETIDA ENTREGA','FILA ORIGINAL'];
function fecha(v){return v ? (Date.parse(v+'T00:00:00Z')-Date.UTC(1899,11,30))/86400000 : null;}
function fila(r){return r.values.map((v,i)=>i>=3?fecha(v):v);}
function tabla(nombre,head,rows){
 const s=wb.worksheets.add(nombre);
 s.getRangeByIndexes(0,0,rows.length+1,head.length).values=[head,...rows];
 const all=s.getRangeByIndexes(0,0,rows.length+1,head.length);
 all.format.font.name='Arial';all.format.font.size=10;all.format.rowHeight=20;
 all.format.columnWidth=17;
 const h=s.getRangeByIndexes(0,0,1,head.length);
 h.format.fill='#153E50';h.format.font.color='#FFFFFF';h.format.font.bold=true;h.format.wrapText=true;h.format.rowHeight=42;
 s.showGridLines=false;s.freezePanes.freezeRows(1);
 return s;
}
const hist=tabla('Historicos',headers,validas.map(r=>[...fila(r),r.source_row]));
hist.getRange(`D2:L${validas.length+1}`).setNumberFormat('yyyy-mm-dd');
hist.getRange(`B1:B${validas.length+1}`).format.columnWidth=38;
const cambios=tabla('Cambios',['FILA ORIGINAL','OP','COLUMNA','VALOR ORIGINAL','FECHA RESULTANTE','REGLA'],datos.changes);
cambios.getRange(`D1:D${datos.changes.length+1}`).format.columnWidth=40;
cambios.getRange(`F1:F${datos.changes.length+1}`).format.columnWidth=56;
const notas=[
 ['CRITERIOS DEL HISTÓRICO REORGANIZADO',''],
 ['Cobertura',`${datos.stats.original_rows} filas originales consolidadas en ${datos.stats.import_rows} OP. No se excluyeron OP.`],
 ['Unidades conservadas',datos.stats.quantity],
 ['Duplicadas','OP 20637: 2 unidades; OP 21793: 71 unidades. Cantidades sumadas; cierre más reciente por proceso.'],
 ['Aliados futuro',`${datos.stats.aliados_terminado} fechas sustituidas por Terminado y ${datos.stats.aliados_anterior} por la última fecha válida anterior. Referencia: 14/10/2026.`],
 ['Fechas invertidas',`${datos.stats.ordenadas} OP con fechas ordenadas cronológicamente, después de ajustar Aliados y consolidar duplicados. Se conservaron las casillas vacías.`],
 ['Orden de las reglas','Ceros/textos → Aliados futuro → consolidación de duplicados → orden cronológico. El último paso puede intercambiar fechas corregidas en los pasos anteriores.'],
 ['Naturaleza de los datos','Las fechas sustituidas e intercambiadas son ajustes autorizados para importación; no son cierres reales verificados. Los indicadores se calcularán con estas fechas ajustadas.'],
 ['LOGISTICA','Conserva entrega al cliente como cierre histórico. No equivale a salida de bodega.'],
 ['Ceros y textos','Ceros convertidos a vacíos. Textos en procesos sustituidos por la última fecha válida anterior de la misma fila.'],
 ['Fecha comprometida','Conservada como columna adicional, fuera del ordenamiento. El importador actual no la utiliza.'],
 ['Auditoría','Cambios registra las operaciones en orden de aplicación. FILA ORIGINAL permite volver al archivo fuente.'],
 ['Fuente','D:/DESCARGAS/plantilla_ciclos EJEMPLO REAL.xlsx · Historicos · filas 4–7744. Fuente sin modificar.'],
 ['Importación','Historicos contiene todas las OP y es la única hoja reconocida por el dashboard.'],
 ['Fechas sin hora','Se conserva el día calendario; las horas se omiten para el cálculo diario.'],
];
const instrucciones=tabla('Instrucciones',['CAMPO','DETALLE'],notas);
instrucciones.getRange('A1:A16').format.columnWidth=28;
instrucciones.getRange('B1:B16').format.columnWidth=108;
instrucciones.getRange('A2:B16').format.wrapText=true;
instrucciones.getRange('A2:B16').format.rowHeight=46;
const output=await SpreadsheetFile.exportXlsx(wb);
await output.save(new URL('plantilla_ciclos_reorganizada.xlsx',dir).pathname.replace(/^\/([A-Za-z]:)/,'$1'));
console.log(JSON.stringify(datos.stats));
for(const [name,range] of [['Historicos','A1:F7'],['Instrucciones','A1:B9'],['Cambios','A1:F6']]){
 const blob=await wb.render({sheetName:name,range,scale:1});
 await fs.writeFile(new URL('reorganizada_'+name+'.png',dir),new Uint8Array(await blob.arrayBuffer()));
}
