const {Worker} = require('node:worker_threads');
const fs = require('node:fs');
const path = require('node:path');
const start = Date.now();
let ticks=0;
const timer = setInterval(()=>ticks++,20);
const worker = new Worker(`
const {parentPort,workerData} = require('node:worker_threads');
globalThis.self=globalThis;
globalThis.postMessage=(data)=>parentPort.postMessage(data);
require(workerData);
parentPort.on('message',data=>globalThis.onmessage({data}));
`, {eval:true, workerData:path.resolve('web/ciclos_excel_worker.js')});
worker.on('message', raw=>{
  const data=JSON.parse(raw);
  if(data.error) throw new Error(data.error);
  if(data.filas.length!==7739) throw new Error('Conteo incorrecto');
  if(!data.filas.every(r=>'fila_original' in r && 'fecha_comprometida_entrega' in r)) throw new Error('Referencias ausentes');
  console.log(JSON.stringify({op:data.filas.length,ms:Date.now()-start,eventLoopTicks:ticks}));
  clearInterval(timer);worker.terminate();
});
worker.on('error',e=>{console.error(e);clearInterval(timer);process.exitCode=1;worker.terminate();});
worker.postMessage(new Uint8Array(fs.readFileSync('outputs/ciclos_limpieza_20261014/plantilla_ciclos_reorganizada.xlsx')));
