import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_ingreso_pedidos/main.dart';
import 'package:sistema_ingreso_pedidos/datos/repositorio.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';

class _SelectorFotoDemo extends ImagePickerPlatform {
  _SelectorFotoDemo(this.archivo);
  final String archivo;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(archivo);
  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

void main() {
  testWidgets(
    'captura el flujo de portafolio con fotografía ficticia y OCR simulado',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selectorAnterior = ImagePickerPlatform.instance;
      final temporal = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('pedidos-demo-'),
      ))!;
      addTearDown(() async {
        ImagePickerPlatform.instance = selectorAnterior;
        await temporal.delete(recursive: true);
      });
      final hoja = File('docs/pruebas/hoja-pedido-ejemplo.png').absolute;
      final copia = (await tester.runAsync(
        () => hoja.copy('${temporal.path}/hoja-demo.png'),
      ))!;
      ImagePickerPlatform.instance = _SelectorFotoDemo(copia.path);
      await tester.runAsync(() async {
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
                ),
              ),
            ))
            .load();
        final flutterPackage = jsonDecode(
          await File('.dart_tool/package_config.json').readAsString(),
        ) as Map<String, dynamic>;
        final paquete = (flutterPackage['packages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['name'] == 'flutter');
        final rutaFlutter = Directory.fromUri(
          Uri.parse(paquete['rootUri'] as String),
        );
        final iconos = File(
          '${rutaFlutter.parent.parent.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
        if (await iconos.exists()) {
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(await iconos.readAsBytes())),
              ))
              .load();
        }
      });
      const canal = MethodChannel('google_mlkit_text_recognizer');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            if (call.method == 'vision#closeTextRecognizer') return null;
            final lineas = <Map<String, Object?>>[];
            final textos = ['1001 ?', '1002 1', '2001 3', '3001 2'];
            for (var i = 0; i < textos.length; i++) {
              lineas.add({
                'text': textos[i],
                'rect': {
                  'left': 10.0,
                  'top': 30.0 + i * 30,
                  'right': 180.0,
                  'bottom': 50.0 + i * 30,
                },
                'recognizedLanguages': <String>[],
                'points': [],
                'elements': [],
                'confidence': i == 0 ? .4 : .99,
                'angle': 0.0,
              });
            }
            return {
              'text': textos.join('\n'),
              'blocks': [
                {
                  'text': textos.join('\n'),
                  'rect': {
                    'left': 10.0,
                    'top': 30.0,
                    'right': 180.0,
                    'bottom': 200.0,
                  },
                  'recognizedLanguages': <String>[],
                  'points': [],
                  'lines': lineas,
                },
              ],
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(canal, null),
      );
      SharedPreferences.setMockInitialValues({});
      final repo = RepositorioLocal(await SharedPreferences.getInstance());
      await repo.cargar();
      await repo.guardarCliente(
        const Cliente(codigo: 'DEMO-001', nombre: 'Cliente de demostración'),
        nuevo: true,
      );
      for (final p in const [
        Producto(
          codigo: '1001',
          nombre: 'Detergente de demostración',
          categoria: 'Limpieza del hogar',
          precioCentavos: 5000,
        ),
        Producto(
          codigo: '1002',
          nombre: 'Jabón de demostración',
          categoria: 'Aseo personal',
          precioCentavos: 3000,
        ),
        Producto(
          codigo: '2001',
          nombre: 'Crema de demostración',
          categoria: 'Cuidado de la piel',
          precioCentavos: 7000,
        ),
        Producto(
          codigo: '3001',
          nombre: 'Champú de demostración',
          categoria: 'Cabello',
          precioCentavos: 4000,
        ),
      ]) {
        await repo.guardarProducto(p, nuevo: true);
      }
      final escenas = <Map<String, Object>>[
        {
          'file': 'docs/pruebas/hoja-pedido-ejemplo.png',
          'title': '1. Fotografía del pedido',
          'subtitle': 'Hoja generada y catálogo ficticio; no contiene datos de clientes.',
          'seconds': 3,
        },
      ];
      await tester.runAsync(
        () => Directory('build/demo_portafolio').create(recursive: true),
      );
      Future<void> capturar(
        String nombre,
        String titulo,
        String detalle,
        int segundos,
      ) async {
        await tester.pump(const Duration(milliseconds: 500));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final ruta = 'build/demo_portafolio/$nombre.png';
        await tester.runAsync(() async {
          final im = await boundary.toImage(pixelRatio: 1);
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          await File(ruta).writeAsBytes(bytes!.buffer.asUint8List());
          im.dispose();
        });
        escenas.add({
          'file': ruta,
          'title': titulo,
          'subtitle': detalle,
          'seconds': segundos,
        });
      }

      await tester.pumpWidget(AplicacionPedidos(local: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingresar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEMO-001 · Cliente de demostración').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar imagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      for (
        var i = 0;
        i < 150 && find.text('Revisar pedido').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('Revisar pedido'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await capturar(
        '01-alerta',
        '2. Detectar una lectura dudosa',
        'Respuesta OCR simulada: el primer renglón no tiene cantidad reconocible.',
        4,
      );
      await tester.tap(find.text('Revisar pedido'));
      await tester.pumpAndSettle();
      final cantidades = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Cantidad',
      );
      await tester.ensureVisible(cantidades.first);
      await tester.enterText(cantidades.first, '2');
      await tester.pumpAndSettle();
      await capturar(
        '02-correccion',
        '3. Corregir y comparar',
        'El usuario escribe la cantidad observada en la imagen; no se completa por defecto.',
        4,
      );
      final revisiones = find.text('Código y cantidad revisados');
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(revisiones.at(i));
        await tester.tap(revisiones.at(i));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Resumen del pedido'));
      await capturar(
        '03-resumen',
        '4. Revisar productos y total',
        'Cuatro productos, ocho unidades y total de prueba L 420.00.',
        4,
      );
      final confirmar = find.text(
        'Confirmo que el cliente, los códigos y las cantidades son correctos.',
      );
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      final guardar = find.widgetWithText(
        FilledButton,
        'Confirmar y guardar pedido',
      );
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      await capturar(
        '04-confirmar',
        '5. Confirmar el pedido',
        'La información se guarda únicamente después de la confirmación final.',
        3,
      );
      await tester.tap(find.text('Guardar pedido'));
      await tester.pumpAndSettle();
      expect((await repo.cargar()).pedidos.single.unidades, 8);
      await tester.ensureVisible(find.text('Cliente de demostración'));
      await tester.tap(find.text('Cliente de demostración'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Facturar pedido'));
      await tester.tap(find.text('Facturar pedido'));
      await tester.pumpAndSettle();
      final efectivo = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Efectivo recibido (L)',
      );
      await tester.ensureVisible(efectivo);
      await tester.enterText(efectivo, '500.00');
      await tester.pumpAndSettle();
      await capturar(
        '05-pago',
        '6. Registrar un pago recibido',
        'Efectivo de prueba: L 500.00; cambio: L 80.00. No se realiza un cobro real.',
        4,
      );
      final pago = find.text(
        'Confirmo los precios y que recibí el pago completo en lempiras.',
      );
      await tester.ensureVisible(pago);
      await tester.tap(pago);
      await tester.pumpAndSettle();
      final emitir = find.widgetWithText(FilledButton, 'Emitir comprobante');
      await tester.ensureVisible(emitir);
      await tester.tap(emitir);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir y registrar pago'));
      await tester.pumpAndSettle();
      expect((await repo.cargar()).facturas.single.totalCentavos, 42000);
      await capturar(
        '06-comprobante',
        '7. Comprobante interno',
        'Precios conservados, pago registrado y opción para compartir o imprimir PDF.',
        5,
      );
      await tester.runAsync(
        () =>
            File('build/demo_portafolio/escenas.json')
                .writeAsString(jsonEncode(escenas)),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('DEMO_PORTAFOLIO'),
  );
}
