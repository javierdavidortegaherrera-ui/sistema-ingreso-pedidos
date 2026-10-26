import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/main.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';

void main() {
  testWidgets(
    'busca por nombre, conserva código con ceros y muestra importes en lempiras',
    (tester) async {
      tester.view.physicalSize = const Size(1365, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final repo = RepositorioLocal(await SharedPreferences.getInstance());
      await repo.cargar();
      await repo.guardarCliente(
        const Cliente(codigo: 'C01', nombre: 'Cliente prueba'),
        nuevo: true,
      );
      await repo.guardarProducto(
        const Producto(
          codigo: '0103016',
          nombre: 'Producto de prueba',
          categoria: 'Aseo personal',
          precioCentavos: 18000,
        ),
        nuevo: true,
      );
      await tester.pumpWidget(AplicacionPedidos(local: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingresar pedido'));
      await tester.pumpAndSettle();
      Finder campo(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(campo('Código'));
      await tester.enterText(campo('Código'), 'Producto de prueba');
      await tester.pumpAndSettle();
      await tester.tap(find.text('0103016 · Producto de prueba'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(campo('Código')).controller!.text,
        '0103016',
      );
      await tester.enterText(campo('Cantidad'), '2');
      await tester.pumpAndSettle();
      expect(find.text('Total del pedido: L 360.00'), findsOneWidget);
      expect(find.text('USD 180.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
