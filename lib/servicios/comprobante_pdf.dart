import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modelos/facturacion.dart';

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
String textoComprobante(Factura f) =>
    'COMPROBANTE INTERNO DE VENTA\n${f.folio} · ${_fecha(f.fecha)}\nCliente: ${f.clienteCodigo} · ${f.clienteNombre}\nPedido: ${f.pedidoId}\n\n${f.lineas.map((l) => '${l.codigo} · ${l.nombre}\n${l.cantidad} x ${dinero(l.precioCentavos, moneda: f.moneda)} = ${dinero(l.importeCentavos, moneda: f.moneda)}').join('\n')}\n\nSubtotal: ${dinero(f.subtotalCentavos, moneda: f.moneda)}\nDescuento: ${dinero(f.descuentoCentavos, moneda: f.moneda)}\nTotal: ${dinero(f.totalCentavos, moneda: f.moneda)}\nPago registrado: ${f.metodoPago.etiqueta}\n${f.metodoPago == MetodoPago.efectivo ? 'Recibido: ${dinero(f.recibidoCentavos, moneda: f.moneda)}\nCambio: ${dinero(f.cambioCentavos, moneda: f.moneda)}' : 'Referencia: ${f.referencia}'}\nComprobante interno. Sin cálculo de impuestos.';

Future<Uint8List> crearComprobantePdf(Factura f) async {
  final fuenteBase = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final fuenteNegrita = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final doc = pw.Document(
    title: f.folio,
    author: 'Sistema de Ingreso de Pedidos',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(fuenteBase),
      bold: pw.Font.ttf(fuenteNegrita),
    ),
  );
  final acento = PdfColor.fromHex('#B71C2C');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      maxPages: 30,
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Comprobante interno. Sin cálculo de impuestos.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '${c.pageNumber} / ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
      build: (_) => [
        pw.Text(
          'COMPROBANTE DE VENTA',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: acento,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          f.folio,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(_fecha(f.fecha)),
        pw.SizedBox(height: 18),
        pw.Text('Cliente: ${f.clienteNombre}'),
        pw.Text('Código: ${f.clienteCodigo}'),
        pw.Text(
          'Pedido: ${f.pedidoId}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            'Código / producto',
            'Cantidad',
            'Precio (${f.moneda})',
            'Importe (${f.moneda})',
          ],
          data: f.lineas
              .map(
                (l) => [
                  '${l.codigo}\n${l.nombre}',
                  '${l.cantidad}',
                  decimalDinero(l.precioCentavos),
                  decimalDinero(l.importeCentavos),
                ],
              )
              .toList(),
          headerDecoration: pw.BoxDecoration(color: acento),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.all(8),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Subtotal: ${dinero(f.subtotalCentavos, moneda: f.moneda)}',
              ),
              pw.Text(
                'Descuento: ${dinero(f.descuentoCentavos, moneda: f.moneda)}',
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'TOTAL: ${dinero(f.totalCentavos, moneda: f.moneda)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: acento,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text('Pago registrado: ${f.metodoPago.etiqueta}'),
        if (f.metodoPago == MetodoPago.efectivo) ...[
          pw.Text('Recibido: ${dinero(f.recibidoCentavos, moneda: f.moneda)}'),
          pw.Text('Cambio: ${dinero(f.cambioCentavos, moneda: f.moneda)}'),
        ] else
          pw.Text('Referencia: ${f.referencia}'),
      ],
    ),
  );
  return doc.save();
}
