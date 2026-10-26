import '../modelos/dominio.dart';

enum TipoAlerta {
  imagenIlegible,
  codigoNoReconocido,
  codigoDudoso,
  cantidadNoIdentificada,
  imagenSinCodigos,
}

class AlertaLectura {
  const AlertaLectura(this.tipo, this.mensaje);
  final TipoAlerta tipo;
  final String mensaje;
}

class LecturaLinea {
  const LecturaLinea({
    required this.original,
    required this.codigo,
    this.cantidad,
    required this.alertas,
  });
  final String original;
  final String codigo;
  final int? cantidad;
  final List<AlertaLectura> alertas;
}

class ResultadoLectura {
  const ResultadoLectura(this.lineas, this.alertas);
  final List<LecturaLinea> lineas;
  final List<AlertaLectura> alertas;
}

/// Solo acepta pares explícitos por renglón: CÓDIGO CANTIDAD,
/// CÓDIGO x CANTIDAD o CÓDIGO;CANTIDAD. Nunca repara dígitos por similitud.
class AnalizadorPedido {
  ResultadoLectura analizar(
    String texto,
    List<Producto> productos, {
    Set<int> lineasDudosas = const {},
    bool incluyeTotal = false,
  }) {
    final lineas = <LecturaLinea>[];
    final alertas = <AlertaLectura>[];
    final catalogo = {
      for (final p in productos.where((p) => p.activo)) p.codigo,
    };
    final vistos = <String>{};
    final renglones = texto.split(RegExp(r'\r?\n'));
    for (var i = 0; i < renglones.length; i++) {
      final original = renglones[i].trim();
      if (original.isEmpty ||
          RegExp(
            r'^(c[oó]digo\s*([;|,\t ]|x)*\s*cantidad|pedido)$',
            caseSensitive: false,
          ).hasMatch(original)) {
        continue;
      }
      final tokens = original
          .split(
            incluyeTotal
                ? RegExp(r'\s*[;|\t]\s*|\s+[xX×]\s+|\s+')
                : RegExp(r'\s*[;|,\t]\s*|\s+[xX×]\s+|\s+'),
          )
          .where((t) => t.isNotEmpty)
          .toList();
      final codigo = normalizarCodigo(tokens.first);
      final problemas = <AlertaLectura>[];
      if (!catalogo.contains(codigo)) {
        problemas.add(
          AlertaLectura(
            TipoAlerta.codigoNoReconocido,
            'Renglón ${i + 1}: el código «$codigo» no está en el catálogo activo.',
          ),
        );
      }
      final repetido = !vistos.add(codigo);
      final formatoValido =
          tokens.length == 2 ||
          (incluyeTotal &&
              tokens.length == 3 &&
              RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(tokens[2]));
      if (lineasDudosas.contains(i) ||
          !patronCodigo.hasMatch(codigo) ||
          !formatoValido ||
          repetido) {
        problemas.add(
          AlertaLectura(
            TipoAlerta.codigoDudoso,
            'Renglón ${i + 1}: lectura dudosa, formato ambiguo o código repetido. Compáralo con la fotografía.',
          ),
        );
      }
      final cantidad = formatoValido && RegExp(r'^\d{1,4}$').hasMatch(tokens[1])
          ? int.tryParse(tokens[1])
          : null;
      if (cantidad == null || cantidad < 1) {
        problemas.add(
          AlertaLectura(
            TipoAlerta.cantidadNoIdentificada,
            'Renglón ${i + 1}: cantidad ausente o inválida. No se completó automáticamente.',
          ),
        );
      }
      lineas.add(
        LecturaLinea(
          original: original,
          codigo: codigo,
          cantidad: cantidad != null && cantidad > 0 ? cantidad : null,
          alertas: problemas,
        ),
      );
      alertas.addAll(problemas);
    }
    if (lineas.isEmpty || !lineas.any((l) => catalogo.contains(l.codigo))) {
      alertas.add(
        const AlertaLectura(
          TipoAlerta.imagenSinCodigos,
          'No se encontraron códigos del catálogo. Revisa la imagen, ingresa los datos manualmente o carga otra fotografía.',
        ),
      );
    }
    return ResultadoLectura(lineas, alertas);
  }
}
