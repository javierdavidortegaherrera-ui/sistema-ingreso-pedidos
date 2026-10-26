import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/servicios/analizador_pedido.dart';
import 'package:sistema_ingreso_pedidos/servicios/analizador_tabla.dart';

void main() {
  const productos = [
    Producto(
      codigo: '0103016',
      nombre: 'Producto A',
      categoria: 'Aseo personal',
    ),
    Producto(
      codigo: '0500748',
      nombre: 'Producto B',
      categoria: 'Aseo personal',
    ),
    Producto(
      codigo: '0414102',
      nombre: 'Producto C',
      categoria: 'Aseo personal',
    ),
  ];
  FragmentoOcr f(
    String t,
    double x,
    double y,
    double ancho, {
    double confianza = .99,
  }) => FragmentoOcr(t, x, y, x + ancho, y + 12, confianza: confianza);
  List<FragmentoOcr> encabezados(double x) => [
    f('CÓDIGO DEL PRODUCTO', x + 40, 100, 130),
    f('CANT.', x + 190, 100, 24),
    f('TOTAL', x + 235, 100, 40),
  ];
  final analizador = AnalizadorTabla();
  test('separa dos bloques e ignora totales, datos superiores y pie', () {
    final piezas = [
      f('99887766', 60, 20, 120),
      ...encabezados(0),
      ...encabezados(310),
      f('0414102', 350, 130, 110),
      f('02', 505, 130, 16),
      f('160.00', 550, 130, 40),
      f('0103016', 45, 130, 120),
      f('01', 195, 130, 14),
      f('180.00', 235, 130, 40),
      f('TOTAL', 45, 250, 50),
      f('4320', 550, 250, 40),
      f('1234567', 45, 290, 110),
    ];
    final r = analizador.analizar(piezas, productos);
    expect(r.alertas, isEmpty);
    expect(r.lineas.map((l) => l.codigo), ['0103016', '0414102']);
    expect(r.lineas.map((l) => l.cantidad), [1, 2]);
  });
  test('reúne dígitos separados por casillas sin perder ceros iniciales', () {
    final piezas = [
      ...encabezados(0),
      for (var i = 0; i < 7; i++) f('0500748'[i], 45 + i * 17, 130, 10),
      f('0', 194, 130, 8),
      f('2', 204, 130, 8),
      f('460', 235, 130, 35),
    ];
    final r = analizador.analizar(piezas.reversed.toList(), productos);
    expect(r.lineas.single.codigo, '0500748');
    expect(r.lineas.single.cantidad, 2);
    expect(r.alertas, isEmpty);
  });
  test('cantidad vacía no usa el total como sustituto', () {
    final r = analizador.analizar([
      ...encabezados(0),
      f('0103016', 45, 130, 120),
      f('180', 235, 130, 35),
    ], productos);
    expect(r.lineas.single.cantidad, isNull);
    expect(
      r.alertas.any((a) => a.tipo == TipoAlerta.cantidadNoIdentificada),
      isTrue,
    );
  });
  test('no repara letras, avisa duplicados entre bloques y baja confianza', () {
    final r = analizador.analizar([
      ...encabezados(0),
      ...encabezados(310),
      f('O103016', 45, 130, 120),
      f('01', 195, 130, 14),
      f('0103016', 45, 155, 120),
      f('01', 195, 155, 14),
      f('0103016', 355, 130, 120, confianza: .3),
      f('02', 505, 130, 14),
    ], productos);
    expect(r.lineas.first.codigo, 'O103016');
    expect(
      r.alertas.any((a) => a.tipo == TipoAlerta.codigoNoReconocido),
      isTrue,
    );
    expect(
      r.lineas.last.alertas.any((a) => a.tipo == TipoAlerta.codigoDudoso),
      isTrue,
    );
  });
  test('sin encabezados no adivina columnas y fragmentos cruzados no inventan cantidad', () {
    expect(
      analizador.analizar([
        f('0103016 01 180', 45, 130, 230),
      ], productos).lineas,
      isEmpty,
    );
    final r = analizador.analizar([
      ...encabezados(0),
      f('0103016 01', 45, 130, 160),
    ], productos);
    expect(r.lineas.single.cantidad, isNull);
    expect(r.alertas.any((a) => a.tipo == TipoAlerta.codigoDudoso), isTrue);
  });
  test(
    'entrada manual permite total final explícito pero no deduce el precio',
    () {
      final r = AnalizadorPedido().analizar(
        '0103016 01 180.00\n0414102 02 160,00',
        productos,
        incluyeTotal: true,
      );
      expect(r.lineas.map((l) => l.cantidad), [1, 2]);
      expect(r.alertas, isEmpty);
    },
  );
}
