import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../datos/repositorio.dart';
import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';

String mensajeError(Object error) {
  if (error is ErrorNegocio) {
    return error.mensaje;
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthorized' =>
        'No tienes permiso. Comprueba la sesión y las reglas de Firebase.',
      'unavailable' || 'network-request-failed' => 'No hay conexión con Firebase. Tus cambios siguen en el formulario; vuelve a intentar.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Correo o contraseña incorrectos.',
      'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
      _ =>
        'No se pudo completar la operación (${error.code}). Inténtalo de nuevo.',
    };
  }
  if (error is FormatException || error is TypeError) {
    return 'Los datos almacenados no tienen el formato esperado. No se sobrescribieron. Revisa la copia de seguridad.';
  }
  return 'No se pudo completar la operación. Revisa el almacenamiento, la conexión o los permisos e inténtalo de nuevo.';
}

class ControladorSistema extends ChangeNotifier {
  ControladorSistema(this.repositorio, {required this.enNube});
  final Repositorio repositorio;
  final bool enNube;
  DatosSistema datos = const DatosSistema();
  bool cargando = false;
  bool escribiendo = false;
  String? error;
  bool _cerrado = false;
  void _avisar() {
    if (!_cerrado) {
      notifyListeners();
    }
  }

  Future<void> cargar() async {
    cargando = true;
    error = null;
    _avisar();
    try {
      datos = await repositorio.cargar();
    } catch (e) {
      error = mensajeError(e);
    } finally {
      cargando = false;
      _avisar();
    }
  }

  Future<void> _escribir(Future<void> Function() accion) async {
    if (escribiendo || cargando) {
      throw const ErrorNegocio('Espera a que termine la operación actual.');
    }
    if (error != null) {
      throw const ErrorNegocio(
        'Actualiza los datos antes de realizar cambios.',
      );
    }
    escribiendo = true;
    _avisar();
    try {
      await accion();
      await cargar();
    } finally {
      escribiendo = false;
      _avisar();
    }
  }

  Future<void> guardarCliente(Cliente c, {required bool nuevo}) =>
      _escribir(() => repositorio.guardarCliente(c, nuevo: nuevo));
  Future<void> guardarProducto(Producto p, {required bool nuevo}) => _escribir(
    () async {
      if (p.precioCentavos != null &&
          (p.precioCentavos! < 1 || p.precioCentavos! > precioMaximoCentavos)) {
        throw const ErrorNegocio(
          'El precio debe ser mayor que cero y no superar L 1000000.00.',
        );
      }
      await repositorio.guardarProducto(p, nuevo: nuevo);
    },
  );
  Future<void> emitirFactura(Factura factura) => _escribir(() async {
    final pedido = datos.pedidos
        .where((p) => p.id == factura.pedidoId)
        .firstOrNull;
    if (pedido == null) {
      throw const ErrorNegocio('Selecciona un pedido registrado.');
    }
    validarFactura(factura, pedido);
    await repositorio.emitirFactura(factura);
  });
  Future<void> guardarPedido(Pedido p, Uint8List? foto) => _escribir(() async {
    validarPedido(p, datos);
    await repositorio.guardarPedido(p, foto);
  });
  Future<void> cambiarEstado(Pedido p, String estado) => _escribir(() async {
    if (estado == 'Cancelado' &&
        datos.facturas.any((f) => f.pedidoId == p.id)) {
      throw const ErrorNegocio(
        'El pedido tiene un pago registrado y no puede cancelarse desde este flujo.',
      );
    }
    if (![
      'Registrado',
      'Preparando',
      'Entregado',
      'Cancelado',
    ].contains(estado)) {
      throw const ErrorNegocio('Estado de pedido inválido.');
    }
    await repositorio.cambiarEstado(p, estado);
  });
  Future<void> cargarEjemplos() async {
    if (datos.clientes.isNotEmpty ||
        datos.productos.isNotEmpty ||
        datos.pedidos.isNotEmpty) {
      throw const ErrorNegocio(
        'Los ejemplos solo se pueden cargar en un espacio vacío.',
      );
    }
    await _escribir(() async {
      await repositorio.guardarCliente(
        const Cliente(codigo: 'CLI-001', nombre: 'Cliente de ejemplo'),
        nuevo: true,
      );
      for (final p in const [
        Producto(
          codigo: '1001',
          nombre: 'Detergente para ropa · 1 L',
          categoria: 'Limpieza del hogar',
        ),
        Producto(
          codigo: '1002',
          nombre: 'Jabón líquido · 500 ml',
          categoria: 'Aseo personal',
        ),
        Producto(
          codigo: '2001',
          nombre: 'Crema humectante · 200 ml',
          categoria: 'Cuidado de la piel',
        ),
        Producto(
          codigo: '3001',
          nombre: 'Champú · 400 ml',
          categoria: 'Cabello',
        ),
      ]) {
        await repositorio.guardarProducto(p, nuevo: true);
      }
    });
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
