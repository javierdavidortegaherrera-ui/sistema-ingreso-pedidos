import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/controladores/controlador_sistema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RepositorioLocal repo;
  const cliente = Cliente(codigo: 'C01', nombre: 'Cliente de prueba');
  const producto = Producto(
    codigo: '0012',
    nombre: 'Jabón',
    categoria: 'Aseo personal',
  );
  Pedido pedido({List<LineaPedido>? lineas, String codigoCliente = 'C01'}) =>
      Pedido(
        id: 'pedido-prueba',
        clienteCodigo: codigoCliente,
        clienteNombre: cliente.nombre,
        fecha: DateTime(2026, 10, 25),
        origen: 'Manual',
        lineas:
            lineas ??
            [const LineaPedido(codigo: '0012', nombre: 'Jabón', cantidad: 2)],
      );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = RepositorioLocal(await SharedPreferences.getInstance());
    await repo.cargar();
    await repo.guardarCliente(cliente, nuevo: true);
    await repo.guardarProducto(producto, nuevo: true);
  });
  test('rechaza duplicados sin sobrescribir el registro original', () async {
    await expectLater(
      repo.guardarCliente(
        const Cliente(codigo: 'C01', nombre: 'Otro'),
        nuevo: true,
      ),
      throwsA(isA<ErrorNegocio>()),
    );
    await expectLater(
      repo.guardarProducto(producto, nuevo: true),
      throwsA(isA<ErrorNegocio>()),
    );
    expect((await repo.cargar()).clientes.single.nombre, cliente.nombre);
  });
  test(
    'guarda pedido y foto, persiste al reabrir y evita doble registro',
    () async {
      final foto = Uint8List.fromList([1, 2, 3]);
      await repo.guardarPedido(pedido(), foto);
      await repo.guardarPedido(pedido(), foto);
      final nuevo = RepositorioLocal(await SharedPreferences.getInstance());
      final datos = await nuevo.cargar();
      expect(datos.pedidos.length, 1);
      expect(datos.pedidos.single.unidades, 2);
      expect(await nuevo.cargarFoto(datos.pedidos.single), foto);
      await nuevo.cambiarEstado(datos.pedidos.single, 'Entregado');
      expect((await nuevo.cargar()).pedidos.single.estado, 'Entregado');
    },
  );
  test('rechaza pedidos vacíos, códigos inexistentes, duplicados y cantidades inválidas', () async {
    for (final lineas in <List<LineaPedido>>[
      [],
      [const LineaPedido(codigo: '999', nombre: '?', cantidad: 1)],
      [const LineaPedido(codigo: '0012', nombre: 'Jabón', cantidad: 0)],
      [const LineaPedido(codigo: '0012', nombre: 'Jabón', cantidad: 10000)],
      [
        const LineaPedido(codigo: '0012', nombre: 'Jabón', cantidad: 1),
        const LineaPedido(codigo: '0012', nombre: 'Jabón', cantidad: 2),
      ],
    ]) {
      await expectLater(
        repo.guardarPedido(pedido(lineas: lineas), null),
        throwsA(isA<ErrorNegocio>()),
      );
    }
    await expectLater(
      repo.guardarPedido(pedido(codigoCliente: 'NO-EXISTE'), null),
      throwsA(isA<ErrorNegocio>()),
    );
    expect((await repo.cargar()).pedidos, isEmpty);
  });
  test('desactivación impide nuevos pedidos y conserva el historial', () async {
    await repo.guardarPedido(pedido(), null);
    await repo.guardarProducto(
      const Producto(
        codigo: '0012',
        nombre: 'Jabón',
        categoria: 'Aseo personal',
        activo: false,
      ),
      nuevo: false,
    );
    await expectLater(
      repo.guardarPedido(pedido(), null),
      throwsA(isA<ErrorNegocio>()),
    );
    expect((await repo.cargar()).pedidos.length, 1);
  });
  test('datos corruptos producen error y bloquean nuevas escrituras', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RepositorioLocal.clave, '{invalido');
    final controlador = ControladorSistema(repo, enNube: false);
    await controlador.cargar();
    expect(controlador.error, isNotNull);
    await expectLater(
      controlador.guardarCliente(cliente, nuevo: true),
      throwsA(isA<ErrorNegocio>()),
    );
    expect(prefs.getString(RepositorioLocal.clave), '{invalido');
    controlador.dispose();
  });
}
