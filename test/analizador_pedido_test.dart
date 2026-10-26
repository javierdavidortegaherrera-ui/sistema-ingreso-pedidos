import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/servicios/analizador_pedido.dart';

void main() {
  const productos = [
    Producto(codigo: '0012', nombre: 'Jabón', categoria: 'Aseo personal'),
    Producto(codigo: 'A-3', nombre: 'Champú', categoria: 'Cabello'),
  ];
  final analizador = AnalizadorPedido();
  test('reconoce pares explícitos sin perder ceros iniciales', () {
    final r = analizador.analizar(
      'Código Cantidad\n0012 2\nA-3 x 4',
      productos,
    );
    expect(r.alertas, isEmpty);
    expect(r.lineas.map((l) => l.codigo), ['0012', 'A-3']);
    expect(r.lineas.map((l) => l.cantidad), [2, 4]);
  });
  test('no sustituye letras parecidas ni inventa cantidades', () {
    final r = analizador.analizar('OO12\n0012 ?\nA-3 0', productos);
    expect(r.lineas.first.codigo, 'OO12');
    expect(r.lineas.every((l) => l.cantidad == null), isTrue);
    expect(
      r.alertas.any((a) => a.tipo == TipoAlerta.codigoNoReconocido),
      isTrue,
    );
    expect(
      r.alertas
          .where((a) => a.tipo == TipoAlerta.cantidadNoIdentificada)
          .length,
      3,
    );
  });
  test('no acepta números extra, cantidades negativas o decimales', () {
    for (final texto in [
      '0012 2 3',
      '0012 -1',
      '0012 1.5',
      '0012 1,5',
      '0012 10000',
    ]) {
      final r = analizador.analizar(texto, productos);
      expect(r.lineas.single.cantidad, isNull, reason: texto);
    }
  });
  test('señala confianza baja, duplicados y ausencia de códigos', () {
    final r = analizador.analizar(
      '0012 2\n0012 3',
      productos,
      lineasDudosas: {0},
    );
    expect(
      r.lineas.every(
        (l) => l.alertas.any((a) => a.tipo == TipoAlerta.codigoDudoso),
      ),
      isTrue,
    );
    expect(
      analizador.analizar('', productos).alertas.single.tipo,
      TipoAlerta.imagenSinCodigos,
    );
    expect(
      analizador
          .analizar('9999 3', productos)
          .alertas
          .any((a) => a.tipo == TipoAlerta.imagenSinCodigos),
      isTrue,
    );
  });
}
