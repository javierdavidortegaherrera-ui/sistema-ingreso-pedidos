import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/main.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';

void main() {
  Future<void> abrir(WidgetTester tester, {bool clienteActivo = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioLocal(await SharedPreferences.getInstance());
    await repo.cargar();
    if (clienteActivo) {
      await repo.guardarCliente(
        const Cliente(codigo: 'C01', nombre: 'Cliente'),
        nuevo: true,
      );
    }
    await tester.pumpWidget(AplicacionPedidos(local: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('el aviso inicial indica ambos requisitos y abre Clientes', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Ingresar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Falta un cliente activo'), findsOneWidget);
    expect(find.text('Falta un producto activo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir clientes'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo cliente'), findsOneWidget);
    expect(find.text('Prepara tu primer pedido'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('si ya hay cliente, guía únicamente al producto faltante', (
    tester,
  ) async {
    await abrir(tester, clienteActivo: true);
    await tester.tap(find.text('Ingresar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Falta un cliente activo'), findsNothing);
    expect(find.text('Falta un producto activo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir productos'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
