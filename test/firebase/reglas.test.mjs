import { before, beforeEach, after, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, runTransaction, serverTimestamp } from 'firebase/firestore';

let entorno;
const pedido1 = '00000000-0000-4000-8000-000000000001';
const pedido2 = '00000000-0000-4000-8000-000000000002';
const ruta = (coleccion, id) => `usuarios/ana/${coleccion}/${id}`;
before(async () => {
  const [host, puerto] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  entorno = await initializeTestEnvironment({projectId: 'demo-pedidos-facturacion', firestore: {host, port: Number(puerto), rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => {
  await entorno.clearFirestore();
  await entorno.withSecurityRulesDisabled(async contexto => {
    const db = contexto.firestore();
    await setDoc(doc(db, ruta('clientes', 'C01')), {codigo: 'C01', nombre: 'Cliente', telefono: '', activo: true});
    for (const id of [pedido1, pedido2]) {
      await setDoc(doc(db, ruta('pedidos', id)), {id, clienteCodigo: 'C01', clienteNombre: 'Cliente', fecha: new Date().toISOString(), lineas: [{codigo: '1001', nombre: 'Jabón', cantidad: 2}], origen: 'Manual', notas: '', estado: 'Registrado', confirmado: true, fotoBase64: null, fotoRuta: null, creadoEn: serverTimestamp()});
    }
  });
});
after(async () => { if (entorno) await entorno.cleanup(); });
function factura(id = pedido1, numero = 1, extra = {}) {
  return {pedidoId: id, numero, fecha: new Date().toISOString(), clienteCodigo: 'C01', clienteNombre: 'Cliente', lineas: [{codigo: '1001', nombre: 'Jabón', cantidad: 2, precioCentavos: 1000}], metodoPago: 'efectivo', recibidoCentavos: 2500, descuentoCentavos: 0, referencia: '', moneda: 'HNL', subtotalCentavos: 2000, totalCentavos: 2000, cambioCentavos: 500, pagoConfirmado: true, creadoEn: serverTimestamp(), ...extra};
}
function emitir(db, datos) {
  const batch = writeBatch(db);
  batch.set(doc(db, ruta('contadores', 'comprobantes')), {ultimoNumero: datos.numero, ultimoPedidoId: datos.pedidoId});
  batch.set(doc(db, ruta('facturas', datos.pedidoId)), datos);
  return batch.commit();
}
test('emite comprobante y contador juntos, y aísla las cuentas', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertSucceeds(emitir(db, factura()));
  await assertSucceeds(getDoc(doc(db, ruta('facturas', pedido1))));
  await assertFails(getDoc(doc(entorno.authenticatedContext('otra').firestore(), ruta('facturas', pedido1))));
  await assertFails(getDoc(doc(entorno.unauthenticatedContext().firestore(), ruta('facturas', pedido1))));
});
test('no emite sin actualizar el contador ni deja avanzar el contador solo', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertFails(setDoc(doc(db, ruta('facturas', pedido1)), factura()));
  await assertFails(setDoc(doc(db, ruta('contadores', 'comprobantes')), {ultimoNumero: 1, ultimoPedidoId: pedido1}));
});
test('exige numeración consecutiva y no permite editar o borrar comprobantes', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertSucceeds(emitir(db, factura()));
  await assertFails(emitir(db, factura(pedido2, 1)));
  await assertSucceeds(emitir(db, factura(pedido2, 2)));
  await assertFails(updateDoc(doc(db, ruta('facturas', pedido1)), {totalCentavos: 1}));
  await assertFails(deleteDoc(doc(db, ruta('facturas', pedido1))));
});
test('rechaza tarjeta sin referencia o con monto distinto al total', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertFails(emitir(db, factura(pedido1, 1, {metodoPago: 'credito', recibidoCentavos: 2000, cambioCentavos: 0})));
  await assertFails(emitir(db, factura(pedido1, 1, {metodoPago: 'debito', referencia: 'REF', cambioCentavos: 0})));
  await assertSucceeds(emitir(db, factura(pedido1, 1, {metodoPago: 'transferencia', referencia: 'REF-PRUEBA', recibidoCentavos: 2000, cambioCentavos: 0})));
});
test('rechaza totales inconsistentes, pagos insuficientes y otra moneda', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertFails(emitir(db, factura(pedido1, 1, {totalCentavos: 100})));
  await assertFails(emitir(db, factura(pedido1, 1, {recibidoCentavos: 100})));
  await assertFails(emitir(db, factura(pedido1, 1, {moneda: 'EUR'})));
});
test('impide facturar un pedido cancelado o cancelar uno facturado', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  await assertSucceeds(updateDoc(doc(db, ruta('pedidos', pedido1)), {estado: 'Cancelado'}));
  await assertFails(emitir(db, factura()));
  await assertSucceeds(emitir(db, factura(pedido2)));
  await assertFails(updateDoc(doc(db, ruta('pedidos', pedido2)), {estado: 'Cancelado'}));
});
test('admite productos antiguos sin precio y valida los precios nuevos', async () => {
  const db = entorno.authenticatedContext('ana').firestore(); const ref = doc(db, ruta('productos', '1001'));
  const producto = {codigo: '1001', nombre: 'Jabón', categoria: 'Aseo personal', activo: true};
  await assertSucceeds(setDoc(ref, producto));
  await assertSucceeds(setDoc(ref, {...producto, precioCentavos: 1250}));
  await assertFails(updateDoc(ref, {precioCentavos: -1}));
  await assertFails(updateDoc(ref, {precioCentavos: 12.5}));
});
test('dos emisiones concurrentes reciben números diferentes', async () => {
  const db = entorno.authenticatedContext('ana').firestore();
  async function emitirTransaccion(id) {
    const ref = doc(db, ruta('facturas', id)); const contador = doc(db, ruta('contadores', 'comprobantes'));
    for (let intento = 0; intento < 4; intento++) {
      let numeroIntentado;
      try {
        await runTransaction(db, async t => {
      const existente = await t.get(ref); if (existente.exists()) return;
      const secuencia = await t.get(contador); const numero = (secuencia.data()?.ultimoNumero ?? 0) + 1;
      numeroIntentado = numero;
      t.set(contador, {ultimoNumero: numero, ultimoPedidoId: id}); t.set(ref, factura(id, numero));
        });
        return;
      } catch (e) {
        if (e.code !== 'permission-denied' || !numeroIntentado || intento === 3) throw e;
        const actual = await getDoc(contador);
        if ((actual.data()?.ultimoNumero ?? 0) < numeroIntentado) throw e;
      }
    }
  }
  await Promise.all([emitirTransaccion(pedido1), emitirTransaccion(pedido2)]);
  const numeros = [(await getDoc(doc(db, ruta('facturas', pedido1)))).data().numero, (await getDoc(doc(db, ruta('facturas', pedido2)))).data().numero];
  if (numeros.sort().join(',') !== '1,2') throw Error('Numeración concurrente incorrecta');
});
