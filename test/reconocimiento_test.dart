import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sistema_ingreso_pedidos/modelos/dominio.dart';
import 'package:sistema_ingreso_pedidos/servicios/analizador_pedido.dart';
import 'package:sistema_ingreso_pedidos/servicios/reconocimiento.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('google_mlkit_text_recognizer');
  const productos = [
    Producto(codigo: '0012', nombre: 'Jabón', categoria: 'Aseo personal'),
  ];
  var cerrado = false;
  var fallar = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    cerrado = false;
    fallar = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          if (llamada.method == 'vision#closeTextRecognizer') {
            cerrado = true;
            return null;
          }
          if (fallar) {
            throw PlatformException(code: 'error-prueba');
          }
          final rect = {
            'left': 0.0,
            'top': 0.0,
            'right': 100.0,
            'bottom': 20.0,
          };
          final linea = {
            'text': '0012 2',
            'rect': rect,
            'recognizedLanguages': <String>[],
            'points': [],
            'elements': [],
            'confidence': 0.40,
            'angle': 0.0,
          };
          return {
            'text': '0012 2',
            'blocks': [
              {
                'text': '0012 2',
                'rect': rect,
                'recognizedLanguages': <String>[],
                'points': [],
                'lines': [linea],
              },
            ],
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });
  XFile fotoNegra() => XFile.fromData(
    Uint8List.fromList(img.encodePng(img.Image(width: 100, height: 100))),
    name: 'oscura.png',
    path: 'foto-prueba.png',
  );
  test(
    'imagen oscura y baja confianza generan alertas sin corregir el código',
    () async {
      final foto = await Reconocimiento().analizar(fotoNegra(), productos);
      expect(
        foto.resultado.alertas.any((a) => a.tipo == TipoAlerta.imagenIlegible),
        isTrue,
      );
      expect(
        foto.resultado.alertas.any((a) => a.tipo == TipoAlerta.codigoDudoso),
        isTrue,
      );
      expect(foto.resultado.lineas.single.codigo, '0012');
      expect(img.decodeJpg(foto.bytes), isNotNull);
      expect(cerrado, isTrue);
    },
  );
  test(
    'libera el reconocedor incluso si el procesamiento nativo falla',
    () async {
      fallar = true;
      await expectLater(
        Reconocimiento().analizar(fotoNegra(), productos),
        throwsA(isA<PlatformException>()),
      );
      expect(cerrado, isTrue);
    },
  );
  test('modo automático usa las coordenadas de la tabla y no el total como cantidad', () async {
    Map<String, Object?> pieza(String texto, double x, double y, double ancho) {
      final rect = {'left': x, 'top': y, 'right': x + ancho, 'bottom': y + 12};
      final e = {
        'text': texto,
        'rect': rect,
        'recognizedLanguages': <String>[],
        'points': [],
        'symbols': [],
        'confidence': .99,
        'angle': 0.0,
      };
      return {
        ...e,
        'elements': [e],
      };
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          if (llamada.method == 'vision#closeTextRecognizer') {
            cerrado = true;
            return null;
          }
          return {
            'text': 'CODIGO CANT TOTAL\n0012 02 180',
            'blocks': [
              {
                'text': '',
                'rect': {
                  'left': 0.0,
                  'top': 0.0,
                  'right': 300.0,
                  'bottom': 200.0,
                },
                'recognizedLanguages': <String>[],
                'points': [],
                'lines': [
                  pieza('CODIGO', 40, 100, 100),
                  pieza('CANT', 190, 100, 24),
                  pieza('TOTAL', 235, 100, 40),
                  pieza('0012', 45, 130, 90),
                  pieza('02', 195, 130, 16),
                  pieza('180', 235, 130, 35),
                ],
              },
            ],
          };
        });
    final foto = await Reconocimiento().analizar(fotoNegra(), productos);
    expect(foto.resultado.lineas.single.codigo, '0012');
    expect(foto.resultado.lineas.single.cantidad, 2);
    expect(cerrado, isTrue);
  });
  test('rechaza imágenes corruptas y archivos que superan el límite', () async {
    await expectLater(
      Reconocimiento().analizar(
        XFile.fromData(Uint8List.fromList([1, 2, 3])),
        productos,
      ),
      throwsA(isA<ErrorNegocio>()),
    );
    await expectLater(
      Reconocimiento().analizar(
        XFile.fromData(Uint8List(10 * 1024 * 1024 + 1)),
        productos,
      ),
      throwsA(isA<ErrorNegocio>()),
    );
  });
}
