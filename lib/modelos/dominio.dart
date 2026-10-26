import 'dart:convert';

import 'facturacion.dart';

String normalizarCodigo(String valor) => valor.trim().toUpperCase();
final patronCodigo = RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,29}$');

class Cliente {
  const Cliente({
    required this.codigo,
    required this.nombre,
    this.telefono = '',
    this.activo = true,
  });
  final String codigo;
  final String nombre;
  final String telefono;
  final bool activo;
  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nombre': nombre,
    'telefono': telefono,
    'activo': activo,
  };
  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    telefono: j['telefono'] as String,
    activo: j['activo'] as bool,
  );
}

class Producto {
  const Producto({
    required this.codigo,
    required this.nombre,
    required this.categoria,
    this.activo = true,
    this.precioCentavos,
    this.moneda = monedaSistema,
  });
  final String codigo;
  final String nombre;
  final String categoria;
  final bool activo;
  final int? precioCentavos;
  final String moneda;
  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nombre': nombre,
    'categoria': categoria,
    'activo': activo,
    'precioCentavos': precioCentavos,
    'moneda': moneda,
  };
  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    categoria: j['categoria'] as String,
    activo: j['activo'] as bool,
    precioCentavos: j['precioCentavos'] as int?,
    moneda:
        j['moneda'] as String? ??
        (j['precioCentavos'] == null ? monedaSistema : 'USD'),
  );
}

class LineaPedido {
  const LineaPedido({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    this.precioCentavos,
  });
  final String codigo;
  final String nombre;
  final int cantidad;
  final int? precioCentavos;
  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nombre': nombre,
    'cantidad': cantidad,
    'precioCentavos': precioCentavos,
  };
  factory LineaPedido.fromJson(Map<String, dynamic> j) => LineaPedido(
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    cantidad: j['cantidad'] as int,
    precioCentavos: j['precioCentavos'] as int?,
  );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.clienteCodigo,
    required this.clienteNombre,
    required this.fecha,
    required this.lineas,
    required this.origen,
    this.notas = '',
    this.estado = 'Registrado',
    this.fotoBase64,
    this.fotoRuta,
    this.moneda = monedaSistema,
  });
  final String id;
  final String clienteCodigo;
  final String clienteNombre;
  final DateTime fecha;
  final List<LineaPedido> lineas;
  final String origen;
  final String notas;
  final String estado;
  final String? fotoBase64;
  final String? fotoRuta;
  final String moneda;
  int? get totalCentavos => lineas.every((l) => l.precioCentavos != null)
      ? lineas.fold<int>(0, (s, l) => s + l.precioCentavos! * l.cantidad)
      : null;
  int get unidades => lineas.fold(0, (n, l) => n + l.cantidad);
  Pedido conEstado(String nuevo) => Pedido(
    id: id,
    clienteCodigo: clienteCodigo,
    clienteNombre: clienteNombre,
    fecha: fecha,
    lineas: lineas,
    origen: origen,
    notas: notas,
    estado: nuevo,
    fotoBase64: fotoBase64,
    fotoRuta: fotoRuta,
    moneda: moneda,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteCodigo': clienteCodigo,
    'clienteNombre': clienteNombre,
    'fecha': fecha.toUtc().toIso8601String(),
    'lineas': lineas.map((l) => l.toJson()).toList(),
    'origen': origen,
    'notas': notas,
    'estado': estado,
    'confirmado': true,
    'fotoBase64': fotoBase64,
    'fotoRuta': fotoRuta,
    'moneda': moneda,
  };
  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
    id: j['id'] as String,
    clienteCodigo: j['clienteCodigo'] as String,
    clienteNombre: j['clienteNombre'] as String,
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
    lineas: (j['lineas'] as List)
        .map((l) => LineaPedido.fromJson(Map<String, dynamic>.from(l as Map)))
        .toList(),
    origen: j['origen'] as String,
    notas: j['notas'] as String,
    estado: j['estado'] as String,
    fotoBase64: j['fotoBase64'] as String?,
    fotoRuta: j['fotoRuta'] as String?,
    moneda: j['moneda'] as String? ?? monedaSistema,
  );
}

class DatosSistema {
  const DatosSistema({
    this.clientes = const [],
    this.productos = const [],
    this.pedidos = const [],
    this.facturas = const [],
  });
  final List<Cliente> clientes;
  final List<Producto> productos;
  final List<Pedido> pedidos;
  final List<Factura> facturas;
  DatosSistema copiar({
    List<Cliente>? clientes,
    List<Producto>? productos,
    List<Pedido>? pedidos,
    List<Factura>? facturas,
  }) => DatosSistema(
    clientes: clientes ?? this.clientes,
    productos: productos ?? this.productos,
    pedidos: pedidos ?? this.pedidos,
    facturas: facturas ?? this.facturas,
  );
  String codificar() => jsonEncode({
    'version': 1,
    'clientes': clientes.map((c) => c.toJson()).toList(),
    'productos': productos.map((p) => p.toJson()).toList(),
    'pedidos': pedidos.map((p) => p.toJson()).toList(),
    'facturas': facturas.map((f) => f.toJson()).toList(),
  });
  factory DatosSistema.decodificar(String texto) {
    final j = jsonDecode(texto) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Versión de datos no compatible.');
    }
    return DatosSistema(
      clientes: (j['clientes'] as List)
          .map((c) => Cliente.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      productos: (j['productos'] as List)
          .map((p) => Producto.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      pedidos: (j['pedidos'] as List)
          .map((p) => Pedido.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      facturas: ((j['facturas'] as List?) ?? [])
          .map((f) => Factura.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
    );
  }
}

class ErrorNegocio implements Exception {
  const ErrorNegocio(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

void validarPedido(Pedido pedido, DatosSistema datos) {
  if (!datos.clientes.any(
    (c) => c.codigo == pedido.clienteCodigo && c.activo,
  )) {
    throw const ErrorNegocio('Selecciona un cliente activo.');
  }
  if (pedido.lineas.isEmpty || pedido.lineas.length > 100) {
    throw const ErrorNegocio(
      'El pedido debe contener entre 1 y 100 productos.',
    );
  }
  final codigos = <String>{};
  for (final linea in pedido.lineas) {
    if (!datos.productos.any((p) => p.codigo == linea.codigo && p.activo)) {
      throw ErrorNegocio(
        'El producto ${linea.codigo} no existe o está inactivo.',
      );
    }
    if (!codigos.add(linea.codigo)) {
      throw ErrorNegocio(
        'El código ${linea.codigo} está repetido. Unifica sus cantidades.',
      );
    }
    if (linea.cantidad < 1 || linea.cantidad > 9999) {
      throw const ErrorNegocio(
        'Las cantidades deben ser enteros entre 1 y 9999.',
      );
    }
    if (linea.precioCentavos != null &&
        (linea.precioCentavos! < 1 ||
            linea.precioCentavos! > precioMaximoCentavos)) {
      throw const ErrorNegocio('Precio de pedido inválido.');
    }
  }
  if (pedido.notas.length > 1000) {
    throw const ErrorNegocio('Las notas no pueden superar 1000 caracteres.');
  }
}
