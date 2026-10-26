import 'dart:math' as math;

import '../modelos/dominio.dart';
import 'analizador_pedido.dart';

enum FormatoLectura { automatico, tabla, renglones }

/// Coordenadas entregadas por el OCR, independientes de Flutter y de ML Kit.
class FragmentoOcr {
  const FragmentoOcr(
    this.texto,
    this.izquierda,
    this.arriba,
    this.derecha,
    this.abajo, {
    this.confianza,
  });
  final String texto;
  final double izquierda, arriba, derecha, abajo;
  final double? confianza;
  double get x => (izquierda + derecha) / 2;
  double get y => (arriba + abajo) / 2;
  double get alto => math.max(1, abajo - arriba);
}

String _cabecera(String t) =>
    t.toUpperCase().replaceAll('Ó', 'O').replaceAll(RegExp(r'[^A-Z]'), '');

class _Bloque {
  _Bloque(this.codigo, this.cantidad, this.total);
  final FragmentoOcr codigo, cantidad, total;
  double get margen => math.max(2, cantidad.alto * .3);
  double get inicioCantidad => cantidad.izquierda - margen;
  double get finCantidad =>
      math.min(cantidad.derecha + margen, (cantidad.x + total.x) / 2);
  double get inicioCodigo =>
      codigo.izquierda - (cantidad.izquierda - codigo.izquierda) * .5;
  double get inicioDatos =>
      math.max(codigo.abajo, math.max(cantidad.abajo, total.abajo));
}

class _Renglon {
  _Renglon(FragmentoOcr f) : piezas = [f];
  final List<FragmentoOcr> piezas;
  double get y =>
      piezas.map((f) => f.y).reduce((a, b) => a + b) / piezas.length;
  double get alto => piezas.map((f) => f.alto).reduce(math.max);
}

class AnalizadorTabla {
  bool tieneCabeceras(List<FragmentoOcr> piezas) => piezas.any(
    (f) =>
        _cabecera(f.texto).contains('CODIGO') ||
        _cabecera(f.texto).startsWith('CANT'),
  );

  ResultadoLectura analizar(
    List<FragmentoOcr> piezas,
    List<Producto> productos,
  ) {
    final bloques = <_Bloque>[];
    final codigos =
        piezas.where((f) => _cabecera(f.texto).contains('CODIGO')).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    for (final codigo in codigos) {
      bool mismaBanda(FragmentoOcr f) =>
          (f.y - codigo.y).abs() <= math.max(f.alto, codigo.alto) * 1.4;
      final cantidades =
          piezas
              .where(
                (f) =>
                    _cabecera(f.texto).startsWith('CANT') &&
                    f.x > codigo.x &&
                    mismaBanda(f),
              )
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));
      if (cantidades.isEmpty) {
        continue;
      }
      final cantidad = cantidades.first;
      final totales =
          piezas
              .where(
                (f) =>
                    _cabecera(f.texto) == 'TOTAL' &&
                    f.x > cantidad.x &&
                    mismaBanda(f),
              )
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));
      if (totales.isEmpty ||
          codigos.any(
            (otro) => otro.x > codigo.x && otro.x < totales.first.x,
          )) {
        continue;
      }
      if (bloques.any(
        (b) => (b.cantidad.x - cantidad.x).abs() < cantidad.alto,
      )) {
        continue;
      }
      bloques.add(_Bloque(codigo, cantidad, totales.first));
    }
    if (bloques.isEmpty || bloques.length > 2) {
      return const ResultadoLectura([], [
        AlertaLectura(
          TipoAlerta.imagenSinCodigos,
          'No se pudieron ubicar las columnas Código, Cant. y Total. Fotografía solo la hoja, incluyendo los encabezados, o usa ingreso manual.',
        ),
      ]);
    }
    final catalogo = {
      for (final p in productos.where((p) => p.activo)) p.codigo,
    };
    final lineas = <LecturaLinea>[];
    final alertas = <AlertaLectura>[];
    final vistos = <String>{};
    if (codigos.length > bloques.length) {
      alertas.add(
        const AlertaLectura(
          TipoAlerta.codigoDudoso,
          'Hay un bloque sin encabezados completos. Revisa los productos que pudieron quedar sin leer.',
        ),
      );
    }
    for (var n = 0; n < bloques.length; n++) {
      final b = bloques[n];
      final izquierda = n == 0
          ? b.inicioCodigo
          : math.max(b.inicioCodigo, bloques[n - 1].total.derecha);
      final finales =
          piezas
              .where(
                (f) =>
                    f.arriba > b.inicioDatos + b.cantidad.alto &&
                    ((_cabecera(f.texto) == 'TOTAL' &&
                            f.x >= izquierda &&
                            f.x < b.inicioCantidad) ||
                        _cabecera(f.texto).contains('FLUSHING')),
              )
              .toList()
            ..sort((a, c) => a.arriba.compareTo(c.arriba));
      final fin = finales.isEmpty ? double.infinity : finales.first.arriba;
      final datos =
          piezas
              .where(
                (f) =>
                    f.y > b.inicioDatos &&
                    f.y < fin &&
                    f.x >= izquierda &&
                    f.x <= b.finCantidad,
              )
              .toList()
            ..sort((a, c) => a.y.compareTo(c.y));
      final renglones = <_Renglon>[];
      for (final f in datos) {
        final cercanos =
            renglones
                .where(
                  (r) => (f.y - r.y).abs() <= math.min(f.alto, r.alto) * .55,
                )
                .toList()
              ..sort((a, c) => (f.y - a.y).abs().compareTo((f.y - c.y).abs()));
        if (cercanos.isEmpty) {
          renglones.add(_Renglon(f));
        } else {
          cercanos.first.piezas.add(f);
        }
      }
      for (var i = 0; i < renglones.length; i++) {
        final r = renglones[i];
        final codigoPartes =
            r.piezas.where((f) => f.x < b.inicioCantidad).toList()
              ..sort((a, c) => a.x.compareTo(c.x));
        final cantidadPartes =
            r.piezas.where((f) => f.x >= b.inicioCantidad).toList()
              ..sort((a, c) => a.x.compareTo(c.x));
        final codigo = normalizarCodigo(
          codigoPartes.map((f) => f.texto).join().replaceAll(RegExp(r'\s'), ''),
        );
        final cantidadTexto = cantidadPartes
            .map((f) => f.texto)
            .join()
            .replaceAll(RegExp(r'\s'), '');
        if (codigo.isEmpty && cantidadTexto.isEmpty) {
          continue;
        }
        final incidencias = <AlertaLectura>[];
        final etiqueta = 'Bloque ${n + 1}, renglón ${i + 1}';
        if (!catalogo.contains(codigo)) {
          incidencias.add(
            AlertaLectura(
              TipoAlerta.codigoNoReconocido,
              '$etiqueta: código «$codigo» ausente o fuera del catálogo.',
            ),
          );
        }
        final cruzaColumna = r.piezas.any(
          (f) =>
              (f.izquierda < b.inicioCantidad &&
                  f.derecha > b.inicioCantidad) ||
              f.derecha > b.finCantidad + b.margen,
        );
        final confianzaBaja = r.piezas.any(
          (f) => f.confianza == null || f.confianza! < .90,
        );
        final repetido = !vistos.add(codigo);
        if (cruzaColumna ||
            confianzaBaja ||
            repetido ||
            !patronCodigo.hasMatch(codigo)) {
          incidencias.add(
            AlertaLectura(
              TipoAlerta.codigoDudoso,
              '$etiqueta: lectura dudosa, repetida o entre columnas. Compárala con la foto.',
            ),
          );
        }
        final cantidad =
            !cruzaColumna && RegExp(r'^\d{1,4}$').hasMatch(cantidadTexto)
            ? int.tryParse(cantidadTexto)
            : null;
        if (cantidad == null || cantidad < 1) {
          incidencias.add(
            AlertaLectura(
              TipoAlerta.cantidadNoIdentificada,
              '$etiqueta: cantidad ausente o ilegible. La columna Total no se usó como cantidad.',
            ),
          );
        }
        lineas.add(
          LecturaLinea(
            original: '$etiqueta: $codigo | $cantidadTexto',
            codigo: codigo,
            cantidad: cantidad != null && cantidad > 0 ? cantidad : null,
            alertas: incidencias,
          ),
        );
        alertas.addAll(incidencias);
      }
    }
    if (lineas.isEmpty || !lineas.any((l) => catalogo.contains(l.codigo))) {
      alertas.add(
        const AlertaLectura(
          TipoAlerta.imagenSinCodigos,
          'No se reconocieron códigos del catálogo en la tabla. Revisa los dos bloques y completa los faltantes manualmente.',
        ),
      );
    }
    return ResultadoLectura(lineas, alertas);
  }
}
