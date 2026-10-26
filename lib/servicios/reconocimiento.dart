import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../modelos/dominio.dart';
import 'analizador_pedido.dart';
import 'analizador_tabla.dart';

class FotoPedido {
  const FotoPedido(this.bytes, this.resultado, this.texto);
  final Uint8List bytes;
  final ResultadoLectura resultado;
  final String texto;
}

class Reconocimiento {
  bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<FotoPedido> analizar(
    XFile archivo,
    List<Producto> productos, {
    FormatoLectura formato = FormatoLectura.automatico,
  }) async {
    final original = await archivo.readAsBytes();
    if (original.length > 10 * 1024 * 1024) {
      throw const ErrorNegocio(
        'La fotografía supera 10 MB. Selecciona una imagen más pequeña.',
      );
    }
    final preparado = await compute(_prepararImagen, original);
    if (preparado == null) {
      throw const ErrorNegocio(
        'Imagen ilegible o formato no compatible. Utiliza JPG o PNG.',
      );
    }
    final bytes = preparado['bytes'] as Uint8List;
    final alertas = <AlertaLectura>[];
    if (preparado['oscura'] == true ||
        preparado['pequena'] == true ||
        preparado['borrosa'] == true) {
      alertas.add(
        const AlertaLectura(
          TipoAlerta.imagenIlegible,
          'La imagen podría estar oscura, desenfocada o tener poca resolución. Revisa toda la lectura o toma una nueva fotografía.',
        ),
      );
    }
    if (!disponible) {
      return FotoPedido(bytes, ResultadoLectura(const [], alertas), '');
    }
    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final lectura = await reconocedor.processImage(
        InputImage.fromFilePath(archivo.path),
      );
      final lineas = lectura.blocks.expand((b) => b.lines).toList();
      final dudosas = <int>{};
      for (var i = 0; i < lineas.length; i++) {
        // Sin confianza disponible, toda la lectura necesita revisión explícita.
        final confianza = lineas[i].confidence;
        if (confianza == null || confianza < 0.90) {
          dudosas.add(i);
        }
      }
      final texto = lineas.map((l) => l.text).join('\n');
      final fragmentos = <FragmentoOcr>[];
      for (final linea in lineas) {
        if (linea.elements.isEmpty) {
          final r = linea.boundingBox;
          fragmentos.add(
            FragmentoOcr(
              linea.text,
              r.left,
              r.top,
              r.right,
              r.bottom,
              confianza: linea.confidence,
            ),
          );
        } else {
          for (final e in linea.elements) {
            final r = e.boundingBox;
            fragmentos.add(
              FragmentoOcr(
                e.text,
                r.left,
                r.top,
                r.right,
                r.bottom,
                confianza: e.confidence ?? linea.confidence,
              ),
            );
          }
        }
      }
      final tabla = AnalizadorTabla();
      final usarTabla =
          formato == FormatoLectura.tabla ||
          (formato == FormatoLectura.automatico &&
              tabla.tieneCabeceras(fragmentos));
      final resultado = usarTabla
          ? tabla.analizar(fragmentos, productos)
          : AnalizadorPedido().analizar(
              texto,
              productos,
              lineasDudosas: dudosas,
            );
      return FotoPedido(
        bytes,
        ResultadoLectura(resultado.lineas, [...alertas, ...resultado.alertas]),
        texto,
      );
    } finally {
      await reconocedor.close();
    }
  }
}

Map<String, Object>? _prepararImagen(Uint8List bytes) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) {
    return null;
  }
  final orientada = img.bakeOrientation(imagen);
  final muestra = img.copyResize(orientada, width: 160);
  var luz = 0.0;
  var suma = 0.0;
  var cuadrados = 0.0;
  var n = 0;
  double gris(int x, int y) =>
      img.getLuminance(muestra.getPixel(x, y)).toDouble();
  for (var y = 1; y < muestra.height - 1; y++) {
    for (var x = 1; x < muestra.width - 1; x++) {
      final centro = gris(x, y);
      luz += centro;
      final lap =
          gris(x - 1, y) +
          gris(x + 1, y) +
          gris(x, y - 1) +
          gris(x, y + 1) -
          4 * centro;
      suma += lap;
      cuadrados += lap * lap;
      n++;
    }
  }
  final varianza = n == 0 ? 0 : cuadrados / n - (suma / n) * (suma / n);
  final reducida = orientada.width > 1600
      ? img.copyResize(orientada, width: 1600)
      : orientada;
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(reducida, quality: 82)),
    'oscura': n == 0 || luz / n < 45,
    'pequena': orientada.width < 600 || orientada.height < 600,
    'borrosa': varianza < 60,
  };
}
