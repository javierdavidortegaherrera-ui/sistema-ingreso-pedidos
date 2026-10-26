import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../controladores/controlador_sistema.dart';
import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';
import '../servicios/comprobante_pdf.dart';
import 'componentes.dart';

class Facturacion extends StatefulWidget {
  const Facturacion({super.key, required this.controlador});
  final ControladorSistema controlador;
  @override
  State<Facturacion> createState() => _FacturacionState();
}

class _FacturacionState extends State<Facturacion> {
  String busqueda = '';
  String filtro = 'Todos';
  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    final facturados = c.datos.facturas.map((f) => f.pedidoId).toSet();
    final pendientes = c.datos.pedidos
        .where(
          (p) =>
              p.estado != 'Cancelado' &&
              !facturados.contains(p.id) &&
              '${p.clienteNombre} ${p.clienteCodigo} ${p.id}'
                  .toLowerCase()
                  .contains(busqueda),
        )
        .toList();
    final facturas =
        c.datos.facturas
            .where(
              (f) =>
                  (filtro == 'Todos' || f.metodoPago.name == filtro) &&
                  '${f.folio} ${f.clienteNombre} ${f.clienteCodigo} ${f.pedidoId}'
                      .toLowerCase()
                      .contains(busqueda),
            )
            .toList()
          ..sort((a, b) => b.numero.compareTo(a.numero));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Comprobantes internos de venta en lempiras. Registra únicamente pagos ya recibidos.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar cliente, pedido o comprobante',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => busqueda = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: filtro,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: [
                  const DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                  ...MetodoPago.values.map(
                    (m) => DropdownMenuItem(
                      value: m.name,
                      child: Text(
                        m.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => filtro = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Pedidos por facturar (${pendientes.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (pendientes.isEmpty)
          const EstadoVacio(
            icono: Icons.task_alt,
            titulo: 'Sin pedidos pendientes de facturar',
            detalle: 'Los pedidos guardados y no cancelados aparecerán aquí.',
          )
        else
          ...pendientes.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(p.clienteNombre),
                  subtitle: Text(
                    '${p.clienteCodigo} · ${p.lineas.length} productos · ${fechaCorta(p.fecha)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: c.escribiendo || c.error != null
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmitirComprobante(
                              controlador: c,
                              pedidoId: p.id,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text(
          'Comprobantes emitidos (${facturas.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (facturas.isEmpty)
          const EstadoVacio(
            icono: Icons.receipt_outlined,
            titulo: 'Todavía no hay comprobantes',
            detalle: 'Selecciona un pedido para revisar sus precios y registrar el pago.',
          )
        else
          ...facturas.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text('${f.folio} · ${f.clienteNombre}'),
                  subtitle: Text(
                    '${f.metodoPago.etiqueta}\n${fechaCorta(f.fecha)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    dinero(f.totalCentavos, moneda: f.moneda),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleComprobante(
                        controlador: c,
                        pedidoId: f.pedidoId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EmitirComprobante extends StatefulWidget {
  const EmitirComprobante({
    super.key,
    required this.controlador,
    required this.pedidoId,
  });
  final ControladorSistema controlador;
  final String pedidoId;
  @override
  State<EmitirComprobante> createState() => _EmitirComprobanteState();
}

class _EmitirComprobanteState extends State<EmitirComprobante> {
  final form = GlobalKey<FormState>();
  final descuento = TextEditingController(text: '0.00');
  final recibido = TextEditingController();
  final referencia = TextEditingController();
  late final Pedido pedido;
  late final List<TextEditingController> precios;
  MetodoPago metodo = MetodoPago.efectivo;
  bool confirmado = false;
  bool ocupado = false;
  bool sucio = false;
  bool salir = false;
  String? error;
  @override
  void initState() {
    super.initState();
    pedido = widget.controlador.datos.pedidos.firstWhere(
      (p) => p.id == widget.pedidoId,
    );
    precios = pedido.lineas.map((l) {
      final p = widget.controlador.datos.productos
          .where((p) => p.codigo == l.codigo)
          .firstOrNull;
      return TextEditingController(
        text: l.precioCentavos != null && pedido.moneda == monedaSistema
            ? decimalDinero(l.precioCentavos!)
            : p?.precioCentavos == null || p?.moneda != monedaSistema
            ? ''
            : decimalDinero(p!.precioCentavos!),
      );
    }).toList();
  }

  @override
  void dispose() {
    descuento.dispose();
    recibido.dispose();
    referencia.dispose();
    for (final p in precios) {
      p.dispose();
    }
    super.dispose();
  }

  void cambiar() => setState(() {
    sucio = true;
    confirmado = false;
    error = null;
  });
  int? get subtotal {
    var suma = 0;
    for (var i = 0; i < precios.length; i++) {
      final precio = leerCentavos(precios[i].text);
      if (precio == null || precio < 1 || precio > precioMaximoCentavos) {
        return null;
      }
      suma += pedido.lineas[i].cantidad * precio;
    }
    return suma;
  }

  int? get total {
    final sub = subtotal;
    final rebaja = leerCentavos(descuento.text);
    return sub == null || rebaja == null || rebaja >= sub ? null : sub - rebaja;
  }

  Future<void> volver() async {
    if (ocupado) {
      return;
    }
    if (!sucio ||
        await confirmar(
          context,
          'Descartar comprobante',
          'Los datos de este comprobante aún no se han guardado.',
          accion: 'Descartar',
        )) {
      if (mounted) {
        setState(() => salir = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> emitir() async {
    if (!form.currentState!.validate() || !confirmado) {
      return;
    }
    final factura = Factura(
      pedidoId: pedido.id,
      numero: 0,
      fecha: DateTime.now(),
      clienteCodigo: pedido.clienteCodigo,
      clienteNombre: pedido.clienteNombre,
      lineas: [
        for (var i = 0; i < precios.length; i++)
          LineaFactura(
            codigo: pedido.lineas[i].codigo,
            nombre: pedido.lineas[i].nombre,
            cantidad: pedido.lineas[i].cantidad,
            precioCentavos: leerCentavos(precios[i].text)!,
          ),
      ],
      metodoPago: metodo,
      recibidoCentavos: metodo == MetodoPago.efectivo
          ? leerCentavos(recibido.text)!
          : total!,
      descuentoCentavos: leerCentavos(descuento.text)!,
      referencia: metodo == MetodoPago.efectivo ? '' : referencia.text.trim(),
    );
    try {
      validarFactura(factura, pedido);
    } catch (e) {
      setState(() => error = mensajeError(e));
      return;
    }
    if (!await confirmar(
      context,
      'Emitir comprobante',
      '${pedido.clienteNombre}\nTotal: ${dinero(factura.totalCentavos)}\nPago: ${metodo.etiqueta}\n\nSe guardarán los precios y el pago confirmado. El comprobante emitido no podrá editarse.',
      accion: 'Emitir y registrar pago',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await widget.controlador.emitirFactura(factura);
      if (mounted) {
        setState(() => salir = true);
        Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleComprobante(
              controlador: widget.controlador,
              pedidoId: pedido.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = mensajeError(e));
      }
    } finally {
      if (mounted) {
        setState(() => ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalActual = total;
    final entregado = leerCentavos(recibido.text);
    return PopScope(
      canPop: salir || (!sucio && !ocupado),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          volver();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Facturar pedido'),
          leading: IconButton(
            onPressed: ocupado ? null : volver,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AbsorbPointer(
          absorbing: ocupado,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Comprobante de venta',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('${pedido.clienteCodigo} · ${pedido.clienteNombre}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Moneda: HNL (L) · Comprobante interno. Sin cálculo de impuestos.',
                      ),
                      const SizedBox(height: 24),
                      ...pedido.lineas.asMap().entries.map((e) {
                        final i = e.key;
                        final l = e.value;
                        final monto = leerCentavos(precios[i].text);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l.nombre,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${l.codigo} · Cantidad: ${l.cantidad}'),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: ValueKey('precio-${l.codigo}'),
                                    controller: precios[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    maxLength: 12,
                                    decoration: const InputDecoration(
                                      labelText: 'Precio unitario (L)',
                                    ),
                                    onChanged: (_) => cambiar(),
                                    validator: (v) {
                                      final n = leerCentavos(v ?? '');
                                      return n == null ||
                                              n < 1 ||
                                              n > precioMaximoCentavos
                                          ? 'Precio entre 0.01 y 1000000.00.'
                                          : null;
                                    },
                                  ),
                                  Text(
                                    'Importe: ${monto == null ? 'Pendiente' : dinero(monto * l.cantidad)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descuento,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Descuento (L)',
                        ),
                        onChanged: (_) => cambiar(),
                        validator: (v) {
                          final n = leerCentavos(v ?? '');
                          return n == null || subtotal == null || n >= subtotal!
                              ? 'El descuento debe ser menor que el subtotal.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subtotal: ${subtotal == null ? 'Precios pendientes' : dinero(subtotal!)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${totalActual == null ? 'Revisa precios y descuento' : dinero(totalActual)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Registro del pago',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MetodoPago>(
                        initialValue: metodo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Método de pago',
                        ),
                        items: MetodoPago.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.etiqueta),
                              ),
                            )
                            .toList(),
                        onChanged: (m) {
                          metodo = m!;
                          cambiar();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (metodo == MetodoPago.efectivo) ...[
                        TextFormField(
                          controller: recibido,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Efectivo recibido (L)',
                          ),
                          onChanged: (_) => cambiar(),
                          validator: (v) {
                            final n = leerCentavos(v ?? '');
                            return n == null || total == null || n < total!
                                ? 'El efectivo recibido debe cubrir el total.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cambio: ${totalActual != null && entregado != null && entregado >= totalActual ? dinero(entregado - totalActual) : 'Pendiente'}',
                        ),
                      ] else ...[
                        const Text(
                          'Verifica el pago en tu terminal o banco antes de registrarlo.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: referencia,
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: metodo == MetodoPago.transferencia
                                ? 'Referencia de transferencia'
                                : 'Referencia de autorización',
                            helperText: 'Solo la referencia; no ingreses números de tarjeta ni CVV.',
                          ),
                          onChanged: (_) => cambiar(),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'La referencia del pago es obligatoria.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Confirmo los precios y que recibí el pago completo en lempiras.',
                        ),
                        value: confirmado,
                        onChanged: (v) => setState(() {
                          confirmado = v!;
                          sucio = true;
                        }),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: ocupado || !confirmado ? null : emitir,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            ocupado
                                ? 'Emitiendo comprobante…'
                                : 'Emitir comprobante',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DetalleComprobante extends StatefulWidget {
  const DetalleComprobante({
    super.key,
    required this.controlador,
    required this.pedidoId,
  });
  final ControladorSistema controlador;
  final String pedidoId;
  @override
  State<DetalleComprobante> createState() => _DetalleComprobanteState();
}

class _DetalleComprobanteState extends State<DetalleComprobante> {
  bool ocupado = false;
  Future<void> exportar(Factura f, bool imprimir) async {
    setState(() => ocupado = true);
    try {
      final bytes = await crearComprobantePdf(f);
      if (imprimir) {
        await Printing.layoutPdf(name: f.folio, onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: '${f.folio}.pdf');
      }
    } catch (e) {
      if (mounted) {
        avisar(
          context,
          'No se pudo abrir el PDF. Puedes reintentar o copiar el comprobante.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controlador,
    builder: (context, _) {
      final f = widget.controlador.datos.facturas
          .where((f) => f.pedidoId == widget.pedidoId)
          .firstOrNull;
      if (f == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Comprobante')),
          body: EstadoVacio(
            icono: Icons.refresh,
            titulo: 'Actualiza para consultar el comprobante',
            detalle:
                widget.controlador.error ??
                'El comprobante aún no está en la lista local.',
            accion: TextButton(
              onPressed: widget.controlador.cargando
                  ? null
                  : widget.controlador.cargar,
              child: const Text('Actualizar'),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(f.folio)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Comprobante interno de venta',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${f.folio}\n${fechaCorta(f.fecha)}\n${f.clienteCodigo} · ${f.clienteNombre}\nPedido: ${f.pedidoId}',
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: f.lineas
                          .map(
                            (l) => ListTile(
                              title: Text(l.nombre),
                              subtitle: Text(
                                '${l.codigo} · ${l.cantidad} × ${dinero(l.precioCentavos, moneda: f.moneda)}',
                              ),
                              trailing: Text(
                                dinero(l.importeCentavos, moneda: f.moneda),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Subtotal: ${dinero(f.subtotalCentavos, moneda: f.moneda)}',
                  ),
                  Text(
                    'Descuento: ${dinero(f.descuentoCentavos, moneda: f.moneda)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${dinero(f.totalCentavos, moneda: f.moneda)}',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('Pago registrado: ${f.metodoPago.etiqueta}'),
                  if (f.metodoPago == MetodoPago.efectivo) ...[
                    Text(
                      'Recibido: ${dinero(f.recibidoCentavos, moneda: f.moneda)}',
                    ),
                    Text(
                      'Cambio: ${dinero(f.cambioCentavos, moneda: f.moneda)}',
                    ),
                  ] else
                    SelectableText('Referencia: ${f.referencia}'),
                  const SizedBox(height: 12),
                  const Text('Comprobante interno. Sin cálculo de impuestos.'),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: ocupado ? null : () => exportar(f, false),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Compartir / guardar PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: ocupado ? null : () => exportar(f, true),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Imprimir'),
                      ),
                      TextButton.icon(
                        onPressed: () => ejecutar(
                          context,
                          () => Clipboard.setData(
                            ClipboardData(text: textoComprobante(f)),
                          ),
                          'Comprobante copiado.',
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                  if (ocupado)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: LinearProgressIndicator(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
