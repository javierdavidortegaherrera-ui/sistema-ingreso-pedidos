import 'dart:convert';

import 'dominio.dart';

const monedaSistema = 'HNL';
const precioMaximoCentavos = 100000000;
const montoMaximoCentavos = 99999999999999;

/// Los importes se guardan como centavos enteros para evitar errores binarios.
int? leerCentavos(String texto) {
  final limpio = texto.trim();
  if (!RegExp(r'^\d{1,12}([.,]\d{1,2})?$').hasMatch(limpio)) {
    return null;
  }
  final partes = limpio.replaceAll(',', '.').split('.');
  final centavos =
      int.parse(partes.first) * 100 +
      (partes.length == 2 ? int.parse(partes[1].padRight(2, '0')) : 0);
  return centavos <= montoMaximoCentavos ? centavos : null;
}

String decimalDinero(int centavos) =>
    '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';
String dinero(int centavos, {String moneda = monedaSistema}) =>
    '${moneda == 'HNL' ? 'L' : moneda} ${decimalDinero(centavos)}';

enum MetodoPago {
  efectivo('Efectivo'),
  debito('Tarjeta de débito'),
  credito('Tarjeta de crédito'),
  transferencia('Transferencia');

  const MetodoPago(this.etiqueta);
  final String etiqueta;
}

class LineaFactura {
  const LineaFactura({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precioCentavos,
  });
  final String codigo;
  final String nombre;
  final int cantidad;
  final int precioCentavos;
  int get importeCentavos => cantidad * precioCentavos;
  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nombre': nombre,
    'cantidad': cantidad,
    'precioCentavos': precioCentavos,
  };
  factory LineaFactura.fromJson(Map<String, dynamic> j) => LineaFactura(
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    cantidad: j['cantidad'] as int,
    precioCentavos: j['precioCentavos'] as int,
  );
}

class Factura {
  const Factura({
    required this.pedidoId,
    required this.numero,
    required this.fecha,
    required this.clienteCodigo,
    required this.clienteNombre,
    required this.lineas,
    required this.metodoPago,
    required this.recibidoCentavos,
    this.descuentoCentavos = 0,
    this.referencia = '',
    this.moneda = monedaSistema,
  });
  final String pedidoId;
  final int numero;
  final DateTime fecha;
  final String clienteCodigo;
  final String clienteNombre;
  final List<LineaFactura> lineas;
  final MetodoPago metodoPago;
  final int recibidoCentavos;
  final int descuentoCentavos;
  final String referencia;
  final String moneda;
  String get folio => 'REC-${numero.toString().padLeft(6, '0')}';
  int get subtotalCentavos => lineas.fold(0, (s, l) => s + l.importeCentavos);
  int get totalCentavos => subtotalCentavos - descuentoCentavos;
  int get cambioCentavos =>
      metodoPago == MetodoPago.efectivo ? recibidoCentavos - totalCentavos : 0;
  Factura numerada(int valor) => Factura(
    pedidoId: pedidoId,
    numero: valor,
    fecha: fecha,
    clienteCodigo: clienteCodigo,
    clienteNombre: clienteNombre,
    lineas: lineas,
    metodoPago: metodoPago,
    recibidoCentavos: recibidoCentavos,
    descuentoCentavos: descuentoCentavos,
    referencia: referencia,
    moneda: moneda,
  );
  Map<String, dynamic> toJson() => {
    'pedidoId': pedidoId,
    'numero': numero,
    'fecha': fecha.toUtc().toIso8601String(),
    'clienteCodigo': clienteCodigo,
    'clienteNombre': clienteNombre,
    'lineas': lineas.map((l) => l.toJson()).toList(),
    'metodoPago': metodoPago.name,
    'recibidoCentavos': recibidoCentavos,
    'descuentoCentavos': descuentoCentavos,
    'referencia': referencia,
    'moneda': moneda,
    'subtotalCentavos': subtotalCentavos,
    'totalCentavos': totalCentavos,
    'cambioCentavos': cambioCentavos,
    'pagoConfirmado': true,
  };
  factory Factura.fromJson(Map<String, dynamic> j) {
    final f = Factura(
      pedidoId: j['pedidoId'] as String,
      numero: j['numero'] as int,
      fecha: DateTime.parse(j['fecha'] as String).toLocal(),
      clienteCodigo: j['clienteCodigo'] as String,
      clienteNombre: j['clienteNombre'] as String,
      lineas: (j['lineas'] as List)
          .map(
            (l) => LineaFactura.fromJson(Map<String, dynamic>.from(l as Map)),
          )
          .toList(),
      metodoPago: MetodoPago.values.byName(j['metodoPago'] as String),
      recibidoCentavos: j['recibidoCentavos'] as int,
      descuentoCentavos: j['descuentoCentavos'] as int,
      referencia: j['referencia'] as String,
      moneda: j['moneda'] as String,
    );
    if (f.numero < 1 ||
        j['pagoConfirmado'] != true ||
        j['subtotalCentavos'] != f.subtotalCentavos ||
        j['totalCentavos'] != f.totalCentavos ||
        j['cambioCentavos'] != f.cambioCentavos) {
      throw const FormatException('Comprobante inconsistente.');
    }
    return f;
  }
}

void validarFactura(Factura f, Pedido pedido) {
  if (pedido.estado == 'Cancelado') {
    throw const ErrorNegocio('No se puede facturar un pedido cancelado.');
  }
  if (f.pedidoId != pedido.id ||
      f.clienteCodigo != pedido.clienteCodigo ||
      f.clienteNombre != pedido.clienteNombre ||
      f.moneda != monedaSistema) {
    throw const ErrorNegocio(
      'El comprobante no corresponde al pedido o a su moneda.',
    );
  }
  if (f.lineas.length != pedido.lineas.length ||
      f.lineas.isEmpty ||
      f.lineas.length > 100) {
    throw const ErrorNegocio(
      'El comprobante debe incluir todos los productos del pedido.',
    );
  }
  final vistos = <String>{};
  for (final l in f.lineas) {
    final original = pedido.lineas
        .where((p) => p.codigo == l.codigo)
        .firstOrNull;
    if (!vistos.add(l.codigo) ||
        original == null ||
        original.cantidad != l.cantidad ||
        original.nombre != l.nombre ||
        l.cantidad < 1 ||
        l.cantidad > 9999) {
      throw const ErrorNegocio(
        'Los códigos y cantidades deben coincidir con el pedido.',
      );
    }
    if (l.precioCentavos < 1 || l.precioCentavos > precioMaximoCentavos) {
      throw ErrorNegocio('Indica un precio válido para ${l.codigo}.');
    }
  }
  if (f.descuentoCentavos < 0 ||
      f.descuentoCentavos >= f.subtotalCentavos ||
      f.totalCentavos > montoMaximoCentavos) {
    throw const ErrorNegocio('El descuento debe ser menor que el subtotal.');
  }
  if (f.recibidoCentavos < f.totalCentavos ||
      f.recibidoCentavos > montoMaximoCentavos) {
    throw const ErrorNegocio('El monto recibido no cubre el total.');
  }
  if (f.metodoPago != MetodoPago.efectivo &&
      (f.recibidoCentavos != f.totalCentavos || f.referencia.trim().isEmpty)) {
    throw const ErrorNegocio(
      'Registra la referencia del pago y el importe exacto del total.',
    );
  }
  if (f.referencia.length > 80) {
    throw const ErrorNegocio('La referencia admite hasta 80 caracteres.');
  }
}

bool mismoComprobante(Factura a, Factura b) {
  final ja = a.toJson()
    ..remove('numero')
    ..remove('fecha');
  final jb = b.toJson()
    ..remove('numero')
    ..remove('fecha');
  return jsonEncode(ja) == jsonEncode(jb);
}
