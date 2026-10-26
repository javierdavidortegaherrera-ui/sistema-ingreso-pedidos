import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/modelos/facturacion.dart';

void main() {
  test(
    'un precio antiguo sin moneda se identifica como USD y no como lempiras',
    () {
      final p = Producto.fromJson({
        'codigo': '0103016',
        'nombre': 'Producto',
        'categoria': 'Aseo personal',
        'activo': true,
        'precioCentavos': 1250,
      });
      expect(p.moneda, 'USD');
      expect(dinero(p.precioCentavos!, moneda: p.moneda), 'USD 12.50');
      expect(monedaSistema, 'HNL');
    },
  );
  test(
    'conserva comprobantes USD y calcula pedidos HNL con instantánea de precio',
    () {
      final anterior = Factura(
        pedidoId: 'anterior',
        numero: 1,
        fecha: DateTime(2026),
        clienteCodigo: 'C01',
        clienteNombre: 'Cliente',
        lineas: [
          const LineaFactura(
            codigo: '0103016',
            nombre: 'Producto',
            cantidad: 2,
            precioCentavos: 1250,
          ),
        ],
        metodoPago: MetodoPago.efectivo,
        recibidoCentavos: 3000,
        moneda: 'USD',
      );
      final leida = Factura.fromJson(anterior.toJson());
      expect(dinero(leida.totalCentavos, moneda: leida.moneda), 'USD 25.00');
      final pedido = Pedido(
        id: 'nuevo',
        clienteCodigo: 'C01',
        clienteNombre: 'Cliente',
        fecha: DateTime(2026),
        lineas: [
          const LineaPedido(
            codigo: '0103016',
            nombre: 'Producto',
            cantidad: 2,
            precioCentavos: 18000,
          ),
        ],
        origen: 'Manual',
      );
      final guardado = Pedido.fromJson(pedido.toJson());
      expect(guardado.totalCentavos, 36000);
      expect(dinero(guardado.totalCentavos!), 'L 360.00');
      expect(guardado.conEstado('Preparando').moneda, 'HNL');
    },
  );
}
