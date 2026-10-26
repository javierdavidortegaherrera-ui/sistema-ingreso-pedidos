import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';

abstract class Repositorio {
  Future<DatosSistema> cargar();
  Future<void> guardarCliente(Cliente cliente, {required bool nuevo});
  Future<void> guardarProducto(Producto producto, {required bool nuevo});
  Future<void> guardarPedido(Pedido pedido, Uint8List? foto);
  Future<void> cambiarEstado(Pedido pedido, String estado);
  Future<Uint8List?> cargarFoto(Pedido pedido);
  Future<void> emitirFactura(Factura factura);
}

class RepositorioLocal implements Repositorio {
  RepositorioLocal(this.preferencias);
  final SharedPreferences preferencias;
  static const clave = 'sistema_pedidos_v1';
  DatosSistema _datos = const DatosSistema();
  Future<void> _persistir(DatosSistema datos) async {
    if (!await preferencias.setString(clave, datos.codificar())) {
      throw const ErrorNegocio(
        'No se pudieron guardar los datos en este dispositivo.',
      );
    }
    _datos = datos;
  }

  @override
  Future<DatosSistema> cargar() async {
    await preferencias.reload();
    final texto = preferencias.getString(clave);
    _datos = texto == null
        ? const DatosSistema()
        : DatosSistema.decodificar(texto);
    return _datos;
  }

  @override
  Future<void> guardarCliente(Cliente cliente, {required bool nuevo}) async {
    if (nuevo && _datos.clientes.any((c) => c.codigo == cliente.codigo)) {
      throw const ErrorNegocio('Ese código de cliente ya existe.');
    }
    await _persistir(
      DatosSistema(
        facturas: _datos.facturas,
        clientes: [
          ..._datos.clientes.where((c) => c.codigo != cliente.codigo),
          cliente,
        ],
        productos: _datos.productos,
        pedidos: _datos.pedidos,
      ),
    );
  }

  @override
  Future<void> guardarProducto(Producto producto, {required bool nuevo}) async {
    if (nuevo && _datos.productos.any((p) => p.codigo == producto.codigo)) {
      throw const ErrorNegocio('Ese código de producto ya existe.');
    }
    await _persistir(
      DatosSistema(
        facturas: _datos.facturas,
        clientes: _datos.clientes,
        productos: [
          ..._datos.productos.where((p) => p.codigo != producto.codigo),
          producto,
        ],
        pedidos: _datos.pedidos,
      ),
    );
  }

  @override
  Future<void> guardarPedido(Pedido pedido, Uint8List? foto) async {
    validarPedido(pedido, _datos);
    if (_datos.pedidos.any((p) => p.id == pedido.id)) {
      return;
    }
    if (foto != null && foto.length > 2 * 1024 * 1024) {
      throw const ErrorNegocio(
        'En modo local la fotografía debe pesar menos de 2 MB.',
      );
    }
    final j = pedido.toJson()
      ..['fotoBase64'] = foto == null ? null : base64Encode(foto);
    await _persistir(
      DatosSistema(
        facturas: _datos.facturas,
        clientes: _datos.clientes,
        productos: _datos.productos,
        pedidos: [Pedido.fromJson(j), ..._datos.pedidos],
      ),
    );
  }

  @override
  Future<void> cambiarEstado(Pedido pedido, String estado) async {
    if (estado == 'Cancelado' &&
        _datos.facturas.any((f) => f.pedidoId == pedido.id)) {
      throw const ErrorNegocio(
        'El pedido ya tiene un comprobante y un pago registrado.',
      );
    }
    await _persistir(
      DatosSistema(
        facturas: _datos.facturas,
        clientes: _datos.clientes,
        productos: _datos.productos,
        pedidos: _datos.pedidos
            .map((p) => p.id == pedido.id ? p.conEstado(estado) : p)
            .toList(),
      ),
    );
  }

  @override
  Future<Uint8List?> cargarFoto(Pedido pedido) async =>
      pedido.fotoBase64 == null ? null : base64Decode(pedido.fotoBase64!);

  @override
  Future<void> emitirFactura(Factura factura) async {
    final existente = _datos.facturas
        .where((f) => f.pedidoId == factura.pedidoId)
        .firstOrNull;
    if (existente != null) {
      if (mismoComprobante(existente, factura)) {
        return;
      }
      throw const ErrorNegocio(
        'El pedido ya tiene un comprobante. Consulta Facturación.',
      );
    }
    final pedido = _datos.pedidos
        .where((p) => p.id == factura.pedidoId)
        .firstOrNull;
    if (pedido == null) {
      throw const ErrorNegocio('El pedido ya no está disponible.');
    }
    validarFactura(factura, pedido);
    final numero =
        _datos.facturas.fold(
          0,
          (mayor, f) => f.numero > mayor ? f.numero : mayor,
        ) +
        1;
    await _persistir(
      _datos.copiar(facturas: [factura.numerada(numero), ..._datos.facturas]),
    );
  }
}

class RepositorioFirebase implements Repositorio {
  RepositorioFirebase(this.uid);
  final String uid;
  DocumentReference<Map<String, dynamic>> get _raiz =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid);
  @override
  Future<DatosSistema> cargar() async {
    final resultados = await Future.wait(
      ['clientes', 'productos', 'pedidos', 'facturas'].map(
        (c) => _raiz.collection(c).get(const GetOptions(source: Source.server)),
      ),
    );
    return DatosSistema(
      facturas:
          resultados[3].docs.map((d) => Factura.fromJson(d.data())).toList()
            ..sort((a, b) => b.numero.compareTo(a.numero)),
      clientes: resultados[0].docs
          .map((d) => Cliente.fromJson(d.data()))
          .toList(),
      productos: resultados[1].docs
          .map((d) => Producto.fromJson(d.data()))
          .toList(),
      pedidos: resultados[2].docs.map((d) => Pedido.fromJson(d.data())).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha)),
    );
  }

  Future<void> _guardarUnico(
    String coleccion,
    String codigo,
    Map<String, dynamic> datos,
    bool nuevo,
  ) => FirebaseFirestore.instance.runTransaction((t) async {
    final ref = _raiz.collection(coleccion).doc(codigo);
    final actual = await t.get(ref);
    if (nuevo && actual.exists) {
      throw const ErrorNegocio('Ese código ya existe. Utiliza otro código.');
    }
    if (!nuevo && !actual.exists) {
      throw const ErrorNegocio(
        'El registro ya no está disponible. Actualiza los datos.',
      );
    }
    t.set(ref, datos);
  });
  @override
  Future<void> guardarCliente(Cliente cliente, {required bool nuevo}) =>
      _guardarUnico('clientes', cliente.codigo, cliente.toJson(), nuevo);
  @override
  Future<void> guardarProducto(Producto producto, {required bool nuevo}) =>
      _guardarUnico('productos', producto.codigo, producto.toJson(), nuevo);
  @override
  Future<void> guardarPedido(Pedido pedido, Uint8List? foto) async {
    final ref = _raiz.collection('pedidos').doc(pedido.id);
    if ((await ref.get(const GetOptions(source: Source.server))).exists) {
      return;
    }
    String? ruta;
    if (foto != null) {
      ruta = 'usuarios/$uid/pedidos/${pedido.id}/original.jpg';
      await FirebaseStorage.instance
          .ref(ruta)
          .putData(foto, SettableMetadata(contentType: 'image/jpeg'));
    }
    // Se conserva la foto al fallar Firestore para reintentar con el mismo ID.
    await FirebaseFirestore.instance.runTransaction((t) async {
      final existente = await t.get(ref);
      if (existente.exists) {
        return;
      }
      final clienteDoc = await t.get(
        _raiz.collection('clientes').doc(pedido.clienteCodigo),
      );
      final productos = <Producto>[];
      for (final linea in pedido.lineas) {
        final doc = await t.get(
          _raiz.collection('productos').doc(linea.codigo),
        );
        if (doc.exists) {
          productos.add(Producto.fromJson(doc.data()!));
        }
      }
      validarPedido(
        pedido,
        DatosSistema(
          clientes: clienteDoc.exists
              ? [Cliente.fromJson(clienteDoc.data()!)]
              : [],
          productos: productos,
        ),
      );
      final datos = pedido.toJson()
        ..['fotoRuta'] = ruta
        ..['creadoEn'] = FieldValue.serverTimestamp();
      t.set(ref, datos);
    });
  }

  @override
  Future<void> cambiarEstado(Pedido pedido, String estado) =>
      _raiz.collection('pedidos').doc(pedido.id).update({'estado': estado});
  @override
  Future<Uint8List?> cargarFoto(Pedido pedido) async => pedido.fotoRuta == null
      ? null
      : FirebaseStorage.instance.ref(pedido.fotoRuta).getData(10 * 1024 * 1024);

  @override
  Future<void> emitirFactura(Factura factura) async {
    final ref = _raiz.collection('facturas').doc(factura.pedidoId);
    final contador = _raiz.collection('contadores').doc('comprobantes');
    for (var intento = 0; intento < 4; intento++) {
      int? numeroIntentado;
      try {
        await FirebaseFirestore.instance.runTransaction((t) async {
          final existente = await t.get(ref);
          if (existente.exists) {
            if (mismoComprobante(
              Factura.fromJson(existente.data()!),
              factura,
            )) {
              return;
            }
            throw const ErrorNegocio(
              'El pedido ya tiene un comprobante. Consulta Facturación.',
            );
          }
          final pedidoDoc = await t.get(
            _raiz.collection('pedidos').doc(factura.pedidoId),
          );
          final secuencia = await t.get(contador);
          if (!pedidoDoc.exists) {
            throw const ErrorNegocio('El pedido ya no está disponible.');
          }
          validarFactura(factura, Pedido.fromJson(pedidoDoc.data()!));
          final numero = (secuencia.data()?['ultimoNumero'] as int? ?? 0) + 1;
          numeroIntentado = numero;
          t.set(contador, {
            'ultimoNumero': numero,
            'ultimoPedidoId': factura.pedidoId,
          });
          t.set(
            ref,
            factura.numerada(numero).toJson()
              ..['creadoEn'] = FieldValue.serverTimestamp(),
          );
        });
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' ||
            numeroIntentado == null ||
            intento == 3) {
          rethrow;
        }
        // Las reglas pueden rechazar un contador obsoleto antes de que el SDK
        // reciba un conflicto de transacción. Solo reintentar si otro emisor avanzó.
        final actual = await contador.get(
          const GetOptions(source: Source.server),
        );
        if ((actual.data()?['ultimoNumero'] as int? ?? 0) < numeroIntentado!) {
          rethrow;
        }
      }
    }
  }
}
