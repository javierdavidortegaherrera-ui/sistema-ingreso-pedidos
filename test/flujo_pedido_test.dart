import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/main.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';

class RepositorioConFallo extends RepositorioLocal {
  RepositorioConFallo(super.preferencias);
  bool pendiente = true;
  @override
  Future<void> guardarPedido(Pedido pedido, Uint8List? foto) async {
    if (pendiente) {
      pendiente = false;
      throw const ErrorNegocio(
        'Fallo de guardado simulado. Vuelve a intentar.',
      );
    }
    await super.guardarPedido(pedido, foto);
  }
}

void main() {
  Future<RepositorioLocal> preparar(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioConFallo(await SharedPreferences.getInstance());
    await repo.cargar();
    await repo.guardarCliente(
      const Cliente(codigo: 'CLI-001', nombre: 'Cliente de ejemplo'),
      nuevo: true,
    );
    await repo.guardarProducto(
      const Producto(
        codigo: '0103016',
        nombre: 'Detergente para ropa · 1 L',
        categoria: 'Limpieza del hogar',
        precioCentavos: 18000,
      ),
      nuevo: true,
    );
    await tester.pumpWidget(AplicacionPedidos(local: repo));
    await tester.pumpAndSettle();
    return repo;
  }

  Finder campo(String etiqueta) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == etiqueta,
  );
  Future<void> capturar(WidgetTester tester, String nombre) async {
    if (!const bool.fromEnvironment('CAPTURAS')) {
      return;
    }
    await tester.runAsync(() async {
      final fuente = File('C:/Windows/Fonts/segoeui.ttf');
      if (await fuente.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await fuente.readAsBytes())),
          );
        await loader.load();
      }
      final iconos = File(
        'C:/flutter/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      if (await iconos.exists()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await iconos.readAsBytes())),
          );
        await loader.load();
      }
    });
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final imagen = await boundary.toImage(pixelRatio: 1);
      final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/capturas').create(recursive: true);
      await File('docs/capturas/$nombre.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      imagen.dispose();
    });
  }

  testWidgets(
    'registra un pedido solo tras revisar y confirmar, conserva el historial',
    (tester) async {
      final repo = await preparar(tester, const Size(1365, 960));
      await capturar(tester, 'resumen');
      await tester.tap(find.text('Ingresar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLI-001 · Cliente de ejemplo').last);
      await tester.pumpAndSettle();
      await tester.enterText(campo('Código'), '0103016');
      await tester.enterText(campo('Cantidad'), '2');
      await tester.pumpAndSettle();
      final guardar = find.widgetWithText(
        FilledButton,
        'Confirmar y guardar pedido',
      );
      expect(tester.widget<FilledButton>(guardar).onPressed, isNull);
      await tester.ensureVisible(find.text('Código y cantidad revisados'));
      await tester.tap(find.text('Código y cantidad revisados'));
      await tester.ensureVisible(
        find.text(
          'Confirmo que el cliente, los códigos y las cantidades son correctos.',
        ),
      );
      await tester.tap(
        find.text(
          'Confirmo que el cliente, los códigos y las cantidades son correctos.',
        ),
      );
      await tester.pumpAndSettle();
      await capturar(tester, 'nuevo-pedido');
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar pedido'), findsOneWidget);
      expect((await repo.cargar()).pedidos, isEmpty);
      await tester.tap(find.text('Guardar pedido'));
      await tester.pumpAndSettle();
      expect((await repo.cargar()).pedidos, isEmpty);
      expect(
        find.text('Fallo de guardado simulado. Vuelve a intentar.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(campo('Código')).controller!.text,
        '0103016',
      );
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar pedido'));
      await tester.pumpAndSettle();
      expect((await repo.cargar()).pedidos.single.unidades, 2);
      expect(find.text('Pedido registrado correctamente.'), findsOneWidget);
      expect(find.text('Cliente de ejemplo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('navegación y formulario se adaptan a un teléfono', (
    tester,
  ) async {
    await preparar(tester, const Size(390, 844));
    await capturar(tester, 'resumen-movil');
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Ingresar pedido'));
    await tester.pumpAndSettle();
    await capturar(tester, 'pedido-movil');
    await tester.ensureVisible(campo('Cantidad'));
    await tester.enterText(campo('Cantidad'), '0');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Descartar borrador'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo pedido'), findsOneWidget);
  });
}
