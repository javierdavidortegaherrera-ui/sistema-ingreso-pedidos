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
import 'package:sistema_ingreso_pedidos/modelos/facturacion.dart';

class RepositorioFacturaConFallo extends RepositorioLocal {
  RepositorioFacturaConFallo(super.preferencias);
  bool fallar = false;
  @override
  Future<void> emitirFactura(Factura factura) async {
    if (fallar) {
      fallar = false;
      throw const ErrorNegocio('Error de guardado simulado.');
    }
    await super.emitirFactura(factura);
  }
}

void main() {
  Finder campo(String etiqueta) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == etiqueta,
  );
  Future<RepositorioFacturaConFallo> preparar(
    WidgetTester tester,
    Size tamano,
  ) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURAS')) {
      await tester.runAsync(() async {
        for (final fuente in {
          'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
          'MaterialIcons': 'C:/flutter/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        }.entries) {
          final archivo = File(fuente.value);
          if (await archivo.exists()) {
            await (FontLoader(fuente.key)..addFont(
                  Future.value(
                    ByteData.sublistView(await archivo.readAsBytes()),
                  ),
                ))
                .load();
          }
        }
      });
    }
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioFacturaConFallo(
      await SharedPreferences.getInstance(),
    );
    await repo.cargar();
    await repo.guardarCliente(
      const Cliente(codigo: 'C01', nombre: 'Cliente factura'),
      nuevo: true,
    );
    await repo.guardarProducto(
      const Producto(
        codigo: '1001',
        nombre: 'Detergente para ropa',
        categoria: 'Limpieza del hogar',
        precioCentavos: 2550,
      ),
      nuevo: true,
    );
    await repo.guardarPedido(
      Pedido(
        id: 'pedido-factura',
        clienteCodigo: 'C01',
        clienteNombre: 'Cliente factura',
        fecha: DateTime(2026, 10, 25),
        lineas: [
          const LineaPedido(
            codigo: '1001',
            nombre: 'Detergente para ropa',
            cantidad: 2,
          ),
        ],
        origen: 'Manual',
      ),
      null,
    );
    await tester.pumpWidget(AplicacionPedidos(local: repo));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> capturar(WidgetTester tester, String nombre) async {
    if (!const bool.fromEnvironment('CAPTURAS')) {
      return;
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final imagen = await boundary.toImage();
      final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/capturas').create(recursive: true);
      await File('docs/capturas/$nombre.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      imagen.dispose();
    });
  }

  for (final metodo in MetodoPago.values) {
    testWidgets(
      'factura con ${metodo.etiqueta}, confirma y conserva importes en móvil',
      (tester) async {
        final repo = await preparar(tester, const Size(390, 844));
        await tester.tap(find.text('Facturación').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente factura'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(campo('Precio unitario (L)'))
              .controller!
              .text,
          '25.50',
        );
        await tester.ensureVisible(campo('Descuento (L)'));
        await tester.enterText(campo('Descuento (L)'), '1.00');
        if (metodo != MetodoPago.efectivo) {
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<MetodoPago>),
          );
          await tester.tap(find.byType(DropdownButtonFormField<MetodoPago>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(metodo.etiqueta).last);
          await tester.pumpAndSettle();
          final etiqueta = metodo == MetodoPago.transferencia
              ? 'Referencia de transferencia'
              : 'Referencia de autorización';
          await tester.ensureVisible(campo(etiqueta));
          await tester.enterText(campo(etiqueta), 'REF-123');
        } else {
          await tester.ensureVisible(campo('Efectivo recibido (L)'));
          await tester.enterText(campo('Efectivo recibido (L)'), '60.00');
          await tester.pump();
          expect(find.text('Cambio: L 10.00'), findsOneWidget);
        }
        final check = find.text(
          'Confirmo los precios y que recibí el pago completo en lempiras.',
        );
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
        final boton = find.widgetWithText(FilledButton, 'Emitir comprobante');
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await tester.pumpAndSettle();
        expect((await repo.cargar()).facturas, isEmpty);
        await tester.tap(find.text('Emitir y registrar pago'));
        await tester.pumpAndSettle();
        final f = (await repo.cargar()).facturas.single;
        expect(f.totalCentavos, 5000);
        expect(f.metodoPago, metodo);
        expect(find.text('REC-000001'), findsOneWidget);
        if (metodo == MetodoPago.efectivo) {
          await capturar(tester, 'comprobante-movil');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('falla al emitir, conserva datos y reintenta sin duplicar', (
    tester,
  ) async {
    final repo = await preparar(tester, const Size(1365, 960));
    repo.fallar = true;
    await tester.tap(find.text('Facturación').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente factura'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(campo('Efectivo recibido (L)'));
    await tester.enterText(campo('Efectivo recibido (L)'), '60');
    final check = find.text(
      'Confirmo los precios y que recibí el pago completo en lempiras.',
    );
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    await capturar(tester, 'facturar-pedido');
    final boton = find.widgetWithText(FilledButton, 'Emitir comprobante');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emitir y registrar pago'));
    await tester.pumpAndSettle();
    expect(find.text('Error de guardado simulado.'), findsOneWidget);
    expect((await repo.cargar()).facturas, isEmpty);
    expect(
      tester.widget<TextField>(campo('Efectivo recibido (L)')).controller!.text,
      '60',
    );
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emitir y registrar pago'));
    await tester.pumpAndSettle();
    expect((await repo.cargar()).facturas.length, 1);
    await capturar(tester, 'comprobante-escritorio');
    expect(tester.takeException(), isNull);
  });
}
