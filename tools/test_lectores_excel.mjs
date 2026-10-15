// Ejecutar primero: dart run tools/benchmark_importacion_erp.dart
import { Worker } from 'node:worker_threads';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

async function leer(script, entrada) {
  const w = new Worker(`
    const { parentPort } = require('node:worker_threads');
    globalThis.self = globalThis;
    globalThis.postMessage = value => parentPort.postMessage(value);
    parentPort.on('message', data => globalThis.onmessage({data}));
    require(${JSON.stringify(resolve('web', script))});
  `, { eval: true });
  try {
    return await new Promise((ok, fail) => {
      const timer = setTimeout(() => fail(new Error('Worker excedió 30 s')), 30000);
      w.once('message', value => { clearTimeout(timer); ok(value); });
      w.once('error', error => { clearTimeout(timer); fail(error); });
      w.postMessage(entrada);
    });
  } finally { await w.terminate(); }
}
const erp = new Uint8Array(readFileSync('.dart_tool/erp-benchmark.xlsx'));
const kardex = new Uint8Array(readFileSync('.dart_tool/kardex-benchmark.xlsx'));
for (const [script, entrada, esperado] of [
  ['ordenes_excel_worker.js', erp, 'erp'],
  ['operativo_excel_worker.js', {bytes: erp, tipo: 'fechas'}, 'fechas'],
  ['operativo_excel_worker.js', {bytes: kardex, tipo: 'kardex', vista: 'produccion'}, 'kardex'],
]) {
  assert.deepEqual(await leer(script, entrada), JSON.parse(readFileSync(`.dart_tool/${esperado}-benchmark.json`, 'utf8')));
  console.log(`${esperado}: worker idéntico al lector Dart`);
}
for (const [script, entrada] of [
  ['ordenes_excel_worker.js', new Uint8Array([1, 2])],
  ['operativo_excel_worker.js', {bytes: new Uint8Array([1, 2]), tipo: 'fechas'}],
  ['operativo_excel_worker.js', {bytes: kardex, tipo: 'kardex', vista: 'logistica'}],
]) {
  assert.equal(typeof (await leer(script, entrada)).error, 'string');
}
console.log('Archivos inválidos y vista incorrecta devuelven error sin bloquear');
