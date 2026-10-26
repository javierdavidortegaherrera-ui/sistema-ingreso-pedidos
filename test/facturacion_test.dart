import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/modelos/facturacion.dart';
import 'package:sistema_ingreso_pedidos/servicios/comprobante_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cliente = Cliente(codigo: 'C01', nombre: 'Cliente de prueba');
  const producto = Producto(
    codigo: '1001',
    nombre: 'Detergente para ropa',
    categoria: 'Limpieza del hogar',
    precioCentavos: 1035,
  );
  Pedido pedido([String id = 'pedido-1']) => Pedido(
    id: id,
    clienteCodigo: cliente.codigo,
    clienteNombre: cliente.nombre,
    fecha: DateTime(2026, 10, 25),
    lineas: [
      const LineaPedido(
        codigo: '1001',
        nombre: 'Detergente para ropa',
        cantidad: 3,
      ),
    ],
    origen: 'Manual',
  );
  Factura factura({
    String id = 'pedido-1',
    MetodoPago metodo = MetodoPago.efectivo,
    int recibido = 4000,
    int descuento = 105,
    String referencia = '',
    int precio = 1035,
  }) => Factura(
    pedidoId: id,
    numero: 0,
    fecha: DateTime(2026, 10, 25, 10, 30),
    clienteCodigo: cliente.codigo,
    clienteNombre: cliente.nombre,
    lineas: [
      LineaFactura(
        codigo: '1001',
        nombre: 'Detergente para ropa',
        cantidad: 3,
        precioCentavos: precio,
      ),
    ],
    metodoPago: metodo,
    recibidoCentavos: recibido,
    descuentoCentavos: descuento,
    referencia: referencia,
  );
  late RepositorioLocal repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = RepositorioLocal(await SharedPreferences.getInstance());
    await repo.cargar();
    await repo.guardarCliente(cliente, nuevo: true);
    await repo.guardarProducto(producto, nuevo: true);
    await repo.guardarPedido(pedido(), null);
  });
  test('convierte dinero exactamente y rechaza formatos ambiguos', () {
    expect(leerCentavos('0.10'), 10);
    expect(leerCentavos('10,35'), 1035);
    expect(leerCentavos('12.3'), 1230);
    expect(leerCentavos('12'), 1200);
    for (final entrada in [
      '-1',
      'NaN',
      '1e3',
      '1.234',
      '1,000.00',
      '',
      '9999999999999',
    ]) {
      expect(leerCentavos(entrada), isNull, reason: entrada);
    }
    expect(dinero(10), 'L 0.10');
  });
  test(
    'efectivo calcula subtotal, descuento y cambio sin errores de redondeo',
    () async {
      final f = factura();
      validarFactura(f, pedido());
      expect(f.subtotalCentavos, 3105);
      expect(f.totalCentavos, 3000);
      expect(f.cambioCentavos, 1000);
      await repo.emitirFactura(f);
      final guardada = (await repo.cargar()).facturas.single;
      expect(guardada.folio, 'REC-000001');
      expect(guardada.moneda, 'HNL');
      expect(guardada.totalCentavos, 3000);
    },
  );
  test('acepta los cuatro métodos y exige referencia y monto exacto en pagos no efectivos', () {
    for (final metodo in MetodoPago.values) {
      validarFactura(
        factura(metodo: metodo, recibido: 3000, referencia: 'REF-PRUEBA'),
        pedido(),
      );
      if (metodo != MetodoPago.efectivo) {
        expect(
          () =>
              validarFactura(factura(metodo: metodo, recibido: 3000), pedido()),
          throwsA(isA<ErrorNegocio>()),
        );
        expect(
          () => validarFactura(
            factura(metodo: metodo, recibido: 4000, referencia: 'REF'),
            pedido(),
          ),
          throwsA(isA<ErrorNegocio>()),
        );
      }
    }
  });
  test('rechaza falta de pago, descuentos excesivos, precios inválidos y pedidos cancelados', () async {
    for (final f in [
      factura(recibido: 2999),
      factura(descuento: 3105),
      factura(descuento: -1),
      factura(precio: 0),
      factura(precio: -10),
      factura(precio: precioMaximoCentavos + 1),
    ]) {
      await expectLater(repo.emitirFactura(f), throwsA(isA<ErrorNegocio>()));
    }
    await repo.cambiarEstado(pedido(), 'Cancelado');
    await expectLater(
      repo.emitirFactura(factura()),
      throwsA(isA<ErrorNegocio>()),
    );
    expect((await repo.cargar()).facturas, isEmpty);
  });
  test('emisión idempotente, numeración consecutiva y conservación después de editar catálogos', () async {
    await repo.emitirFactura(factura());
    await repo.emitirFactura(factura());
    await expectLater(
      repo.emitirFactura(factura(recibido: 5000)),
      throwsA(isA<ErrorNegocio>()),
    );
    await repo.guardarProducto(
      const Producto(
        codigo: '1001',
        nombre: 'Nombre nuevo',
        categoria: 'Limpieza del hogar',
        precioCentavos: 9999,
      ),
      nuevo: false,
    );
    await repo.guardarCliente(
      const Cliente(codigo: 'C01', nombre: 'Cliente actualizado'),
      nuevo: false,
    );
    await repo.cambiarEstado(pedido(), 'Entregado');
    await repo.guardarPedido(pedido('pedido-2'), null);
    await repo.emitirFactura(factura(id: 'pedido-2'));
    final recargado = RepositorioLocal(await SharedPreferences.getInstance());
    final datos = await recargado.cargar();
    expect(datos.facturas.map((f) => f.numero).toList()..sort(), [1, 2]);
    expect(datos.facturas.last.lineas.single.precioCentavos, 1035);
    expect(datos.facturas.last.clienteNombre, cliente.nombre);
    await expectLater(
      recargado.cambiarEstado(pedido(), 'Cancelado'),
      throwsA(isA<ErrorNegocio>()),
    );
  });
  test(
    'lee almacenamiento anterior sin inventar precios ni borrar pedidos',
    () {
      final j =
          jsonDecode(const DatosSistema().codificar()) as Map<String, dynamic>;
      j.remove('facturas');
      final p = producto.toJson()..remove('precioCentavos');
      j['productos'] = [p];
      j['clientes'] = [cliente.toJson()];
      j['pedidos'] = [pedido().toJson()];
      final datos = DatosSistema.decodificar(jsonEncode(j));
      expect(datos.facturas, isEmpty);
      expect(datos.productos.single.precioCentavos, isNull);
      expect(datos.pedidos.single.id, 'pedido-1');
    },
  );
  test('no permite cambiar cantidades ni falsificar totales persistidos', () {
    final j = factura().numerada(1).toJson();
    j['totalCentavos'] = 1;
    expect(() => Factura.fromJson(j), throwsFormatException);
    final incompleta = Factura(
      pedidoId: 'pedido-1',
      numero: 0,
      fecha: DateTime.now(),
      clienteCodigo: cliente.codigo,
      clienteNombre: cliente.nombre,
      lineas: [],
      metodoPago: MetodoPago.efectivo,
      recibidoCentavos: 100,
    );
    expect(
      () => validarFactura(incompleta, pedido()),
      throwsA(isA<ErrorNegocio>()),
    );
  });
  test('genera PDF con una venta y con cien renglones sin perder productos', () async {
    final f = factura().numerada(1);
    final bytes = await crearComprobantePdf(f);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    final grande = Factura(
      pedidoId: 'pedido-largo',
      numero: 2,
      fecha: f.fecha,
      clienteCodigo: f.clienteCodigo,
      clienteNombre: f.clienteNombre,
      lineas: List.generate(
        100,
        (i) => LineaFactura(
          codigo: 'PROD-$i',
          nombre:
              'Producto de limpieza con descripción extensa para verificar el salto de página número $i',
          cantidad: 2,
          precioCentavos: 1035,
        ),
      ),
      metodoPago: MetodoPago.transferencia,
      recibidoCentavos: 207000,
      referencia: 'TRANSFERENCIA-PRUEBA',
    );
    final pdfGrande = await crearComprobantePdf(grande);
    expect(pdfGrande.length, greaterThan(bytes.length));
    if (const bool.fromEnvironment('CAPTURAS')) {
      await Directory('docs/pruebas').create(recursive: true);
      await File('docs/pruebas/comprobante-ejemplo.pdf').writeAsBytes(bytes);
      await File('docs/pruebas/comprobante-100-productos.pdf')
          .writeAsBytes(pdfGrande);
    }
    expect(textoComprobante(f), contains('Total: L 30.00'));
  });
}
