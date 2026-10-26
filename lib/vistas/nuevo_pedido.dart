import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../controladores/controlador_sistema.dart';
import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';
import '../servicios/analizador_pedido.dart';
import '../servicios/reconocimiento.dart';
import '../servicios/analizador_tabla.dart';
import 'buscador_producto.dart';
import 'componentes.dart';

class FilaEditable {
  FilaEditable({
    String codigo = '',
    String cantidad = '',
    this.original,
    this.alertas = const [],
  }) : codigo = TextEditingController(text: codigo),
       cantidad = TextEditingController(text: cantidad);
  final TextEditingController codigo;
  final TextEditingController cantidad;
  final FocusNode focoCodigo = FocusNode();
  final String? original;
  final List<AlertaLectura> alertas;
  bool revisada = false;
  void dispose() {
    codigo.dispose();
    cantidad.dispose();
    focoCodigo.dispose();
  }
}

class NuevoPedido extends StatefulWidget {
  const NuevoPedido({super.key, required this.controlador});
  final ControladorSistema controlador;
  @override
  State<NuevoPedido> createState() => _NuevoPedidoState();
}

class _NuevoPedidoState extends State<NuevoPedido> {
  final formulario = GlobalKey<FormState>();
  final notas = TextEditingController();
  final filas = <FilaEditable>[FilaEditable()];
  final reconocimiento = Reconocimiento();
  final id = const Uuid().v4();
  String? cliente;
  Uint8List? foto;
  bool ocupado = false;
  bool confirmado = false;
  bool modificado = false;
  bool permitirSalida = false;
  String? error;
  String paso = '';
  FormatoLectura formato = FormatoLectura.automatico;
  @override
  void initState() {
    super.initState();
    if (reconocimiento.disponible) {
      recuperarFotografia();
    }
  }

  Future<void> recuperarFotografia() async {
    try {
      final perdida = await ImagePicker().retrieveLostData();
      if (!mounted) {
        return;
      }
      if (perdida.files?.isNotEmpty ?? false) {
        await procesar(perdida.files!.first);
      } else if (perdida.exception != null) {
        avisar(
          context,
          'No se pudo recuperar la captura anterior. Vuelve a seleccionar la imagen.',
        );
      }
    } catch (_) {
      /* La recuperación no debe bloquear el ingreso manual. */
    }
  }

  @override
  void dispose() {
    notas.dispose();
    for (final f in filas) {
      f.dispose();
    }
    super.dispose();
  }

  void cambio([FilaEditable? fila]) => setState(() {
    modificado = true;
    confirmado = false;
    fila?.revisada = false;
    error = null;
  });
  Future<void> salir() async {
    if (ocupado) {
      return;
    }
    if (!modificado ||
        await confirmar(
          context,
          'Descartar borrador',
          'Los cambios de este pedido todavía no se han guardado.',
          accion: 'Descartar',
        )) {
      if (mounted) {
        setState(() => permitirSalida = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> elegir(ImageSource origen) async {
    if (modificado &&
        !await confirmar(
          context,
          'Cargar otra fotografía',
          'La nueva lectura reemplazará los renglones del borrador. El cliente y las notas se conservarán.',
          accion: 'Continuar',
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      ocupado = true;
      paso = 'Abriendo ${origen == ImageSource.camera ? 'cámara' : 'galería'}…';
      error = null;
    });
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 2000,
        maxHeight: 2500,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (archivo != null && mounted) {
        await procesar(archivo);
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No se pudo abrir la imagen'),
            content: const Text(
              'Comprueba los permisos de cámara o galería. Selecciona una imagen JPG/PNG o registra el pedido manualmente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => ocupado = false);
      }
    }
  }

  Future<void> procesar(XFile archivo) async {
    if (!mounted) {
      return;
    }
    setState(() {
      ocupado = true;
      paso = 'Analizando fotografía…';
    });
    try {
      final resultado = await reconocimiento.analizar(
        archivo,
        widget.controlador.datos.productos,
        formato: formato,
      );
      if (!mounted) {
        return;
      }
      for (final f in filas) {
        f.dispose();
      }
      setState(() {
        foto = resultado.bytes;
        filas.clear();
        filas.addAll(
          resultado.resultado.lineas.map(
            (l) => FilaEditable(
              codigo: l.codigo,
              cantidad: l.cantidad?.toString() ?? '',
              original: l.original,
              alertas: l.alertas,
            ),
          ),
        );
        if (filas.isEmpty) {
          filas.add(FilaEditable());
        }
        confirmado = false;
        modificado = true;
      });
      if (!reconocimiento.disponible) {
        await mostrarAlertas([
          const AlertaLectura(
            TipoAlerta.imagenSinCodigos,
            'El reconocimiento automático está disponible en Android. En este navegador, compara la foto e ingresa los códigos y cantidades manualmente.',
          ),
          ...resultado.resultado.alertas,
        ]);
      } else if (resultado.resultado.alertas.isNotEmpty) {
        await mostrarAlertas(resultado.resultado.alertas);
      } else {
        avisar(
          context,
          'Lectura terminada. Revisa cada renglón antes de confirmar.',
        );
      }
    } catch (e) {
      if (mounted) {
        await mostrarAlertas([
          AlertaLectura(
            TipoAlerta.imagenIlegible,
            e is ErrorNegocio ? e.mensaje : 'No se pudo leer la fotografía. Selecciona otra imagen o ingresa los datos manualmente.',
          ),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => ocupado = false);
      }
    }
  }

  Future<void> mostrarAlertas(List<AlertaLectura> alertas) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFAE6500)),
      title: const Text('La lectura necesita revisión'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se completaron datos ausentes ni se sustituyeron códigos. Puedes corregir los campos, eliminar renglones irrelevantes o cargar otra imagen.',
              ),
              const SizedBox(height: 16),
              ...alertas
                  .take(30)
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('• ${a.mensaje}'),
                    ),
                  ),
              if (alertas.length > 30)
                Text(
                  'Y ${alertas.length - 30} incidencias más. Revisa todos los renglones.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Revisar pedido'),
        ),
      ],
    ),
  );
  Future<void> transcribir() async {
    final texto = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresar varios renglones'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: texto,
            minLines: 6,
            maxLines: 12,
            maxLength: 10000,
            decoration: const InputDecoration(
              labelText: 'Un código y una cantidad por línea',
              hintText: '0103016 1\n0500748 2\n0414102 2 160.00',
              helperText: 'Código y cantidad; puedes incluir un total al final, que se ignorará. No analiza fotografías.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, texto.text),
            child: const Text('Agregar renglones'),
          ),
        ],
      ),
    );
    // El campo del diálogo puede seguir animándose durante un frame al cerrarse.
    Future<void>.delayed(const Duration(milliseconds: 300), texto.dispose);
    if (valor == null || valor.trim().isEmpty || !mounted) {
      return;
    }
    final resultado = AnalizadorPedido().analizar(
      valor,
      widget.controlador.datos.productos,
      incluyeTotal: true,
    );
    if (filas.length + resultado.lineas.length > 100) {
      avisar(context, 'El pedido admite hasta 100 renglones.');
      return;
    }
    setState(() {
      if (filas.length == 1 &&
          filas.first.codigo.text.isEmpty &&
          filas.first.cantidad.text.isEmpty) {
        filas.removeLast().dispose();
      }
      filas.addAll(
        resultado.lineas.map(
          (l) => FilaEditable(
            codigo: l.codigo,
            cantidad: l.cantidad?.toString() ?? '',
            original: l.original,
            alertas: l.alertas,
          ),
        ),
      );
      modificado = true;
      confirmado = false;
    });
    if (resultado.alertas.isNotEmpty) {
      await mostrarAlertas(resultado.alertas);
    }
  }

  Future<void> guardar() async {
    if (!formulario.currentState!.validate()) {
      avisar(context, 'Revisa los campos señalados.');
      return;
    }
    if (!confirmado || filas.any((f) => !f.revisada)) {
      avisar(
        context,
        'Marca cada renglón como revisado y confirma la información del pedido.',
      );
      return;
    }
    final c = widget.controlador.datos.clientes
        .where((c) => c.codigo == cliente)
        .firstOrNull;
    if (c == null) {
      return;
    }
    final pedido = Pedido(
      id: id,
      clienteCodigo: c.codigo,
      clienteNombre: c.nombre,
      fecha: DateTime.now(),
      origen: foto == null ? 'Manual' : 'Fotografía revisada',
      notas: notas.text.trim(),
      lineas: filas.map((f) {
        final codigo = normalizarCodigo(f.codigo.text);
        final p = widget.controlador.datos.productos.firstWhere(
          (p) => p.codigo == codigo,
        );
        return LineaPedido(
          codigo: codigo,
          nombre: p.nombre,
          cantidad: int.parse(f.cantidad.text.trim()),
          precioCentavos: p.moneda == monedaSistema ? p.precioCentavos : null,
        );
      }).toList(),
    );
    try {
      validarPedido(pedido, widget.controlador.datos);
    } catch (e) {
      avisar(context, mensajeError(e));
      return;
    }
    if (!await confirmar(
      context,
      'Confirmar pedido',
      '${c.nombre}\n${pedido.lineas.length} productos · ${pedido.unidades} unidades\n\n¿Confirmas que los códigos y las cantidades son correctos?',
      accion: 'Guardar pedido',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      ocupado = true;
      paso = 'Guardando pedido…';
      error = null;
    });
    try {
      await widget.controlador.guardarPedido(pedido, foto);
      if (mounted) {
        setState(() => permitirSalida = true);
        Navigator.pop(context);
        avisar(context, 'Pedido registrado correctamente.');
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

  Widget imagen() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paso 2 · Fotografía (opcional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Fotografía solo la hoja, con buena luz y los encabezados visibles. La tabla puede tener uno o dos bloques de Código, Cant. y Total.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<FormatoLectura>(
            initialValue: formato,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Formato de la hoja'),
            items: const [
              DropdownMenuItem(
                value: FormatoLectura.automatico,
                child: Text('Detectar automáticamente'),
              ),
              DropdownMenuItem(
                value: FormatoLectura.tabla,
                child: Text('Tabla: código, cant. y total'),
              ),
              DropdownMenuItem(
                value: FormatoLectura.renglones,
                child: Text('Líneas: código y cantidad'),
              ),
            ],
            onChanged: (v) => setState(() => formato = v!),
          ),
          const SizedBox(height: 16),
          if (foto != null) ...[
            Container(
              height: 350,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Image.memory(foto!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Amplía la imagen para comparar los números.',
              style: TextStyle(fontSize: 12),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                foto = null;
                cambio();
              }),
              icon: const Icon(Icons.hide_image_outlined),
              label: const Text('Quitar imagen del pedido'),
            ),
          ] else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEACDD1)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 44,
                    color: Color(0xFFB71C2C),
                  ),
                  SizedBox(height: 12),
                  Text('Carga una foto o ingresa el pedido a mano'),
                  SizedBox(height: 6),
                  Text(
                    'JPG / PNG · hasta 10 MB',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (reconocimiento.disponible)
                FilledButton.tonalIcon(
                  onPressed: () => elegir(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Tomar foto'),
                ),
              OutlinedButton.icon(
                onPressed: () => elegir(ImageSource.gallery),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Seleccionar imagen'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            reconocimiento.disponible
                ? 'El total escrito en la hoja no se toma como cantidad ni como precio. Revisa ambos bloques y agrega los renglones que no se hayan reconocido.'
                : 'Vista web: adjunta una imagen y transcribe los datos. El OCR funciona en la aplicación Android.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF62626B)),
          ),
        ],
      ),
    ),
  );
  Widget fila(FilaEditable f, int i) {
    final producto = widget.controlador.datos.productos
        .where((p) => p.codigo == normalizarCodigo(f.codigo.text) && p.activo)
        .firstOrNull;
    return Container(
      key: ObjectKey(f),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: f.revisada ? const Color(0xFFFFF1F3) : const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: f.alertas.isNotEmpty && !f.revisada
              ? const Color(0xFFE7C588)
              : const Color(0xFFE5E5EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Renglón ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Eliminar renglón',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  if (!await confirmar(
                    context,
                    'Eliminar renglón',
                    'Se quitará este renglón del borrador.',
                    accion: 'Eliminar',
                  )) {
                    return;
                  }
                  if (mounted) {
                    setState(() {
                      filas.remove(f);
                      f.dispose();
                      confirmado = false;
                      modificado = true;
                    });
                  }
                },
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          if (f.original != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Lectura original: ${f.original}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: BuscadorProducto(
                  controlador: f.codigo,
                  foco: f.focoCodigo,
                  productos: widget.controlador.datos.productos,
                  onChanged: (_) => cambio(f),
                  onSelected: (p) {
                    f.codigo.text = p.codigo;
                    f.focoCodigo.unfocus();
                    cambio(f);
                  },
                  validator: (v) {
                    final codigo = normalizarCodigo(v ?? '');
                    if (!widget.controlador.datos.productos.any(
                      (p) => p.codigo == codigo && p.activo,
                    )) {
                      return 'Código inexistente o inactivo.';
                    }
                    if (filas
                            .where(
                              (otra) =>
                                  normalizarCodigo(otra.codigo.text) == codigo,
                            )
                            .length >
                        1) {
                      return 'Código repetido.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: f.cantidad,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  onChanged: (_) => cambio(f),
                  validator: (v) =>
                      RegExp(r'^\d{1,4}$').hasMatch((v ?? '').trim()) &&
                          (int.tryParse(v!.trim()) ?? 0) > 0
                      ? null
                      : 'Entre 1 y 9999.',
                ),
              ),
            ],
          ),
          if (producto != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                producto.nombre,
                style: const TextStyle(color: Color(0xFFB71C2C)),
              ),
            ),
          if (f.alertas.isNotEmpty && !f.revisada)
            const Text(
              'Lectura con incidencias: verifica el código y la cantidad.',
              style: TextStyle(fontSize: 12, color: Color(0xFF936000)),
            ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Código y cantidad revisados'),
              value: f.revisada,
              onChanged: (v) => setState(() {
                f.revisada = v!;
                confirmado = false;
                modificado = true;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget resumenPedido() {
    final renglones = filas
        .where(
          (f) =>
              f.codigo.text.trim().isNotEmpty ||
              f.cantidad.text.trim().isNotEmpty,
        )
        .toList();
    var suma = 0;
    var unidades = 0;
    var pendiente = false;
    final datos = <DataRow>[];
    for (final f in renglones) {
      final codigo = normalizarCodigo(f.codigo.text);
      final producto = widget.controlador.datos.productos
          .where((p) => p.codigo == codigo && p.activo)
          .firstOrNull;
      final cantidad = int.tryParse(f.cantidad.text.trim());
      final precio = producto?.moneda == monedaSistema
          ? producto?.precioCentavos
          : null;
      final valido = cantidad != null && cantidad > 0 && cantidad <= 9999;
      final importe = valido && precio != null ? cantidad * precio : null;
      if (importe == null) {
        pendiente = true;
      } else {
        suma += importe;
      }
      if (valido) {
        unidades += cantidad;
      }
      datos.add(
        DataRow(
          cells: [
            DataCell(Text(codigo.isEmpty ? 'Pendiente' : codigo)),
            DataCell(
              SizedBox(
                width: 165,
                child: Text(producto?.nombre ?? 'Código por revisar'),
              ),
            ),
            DataCell(Text(valido ? '$cantidad' : 'Pendiente')),
            DataCell(Text(precio == null ? 'Pendiente' : dinero(precio))),
            DataCell(Text(importe == null ? 'Pendiente' : dinero(importe))),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Resumen del pedido',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Precios de venta del catálogo en lempiras. Los totales escritos en la foto no fijan estos precios.',
          style: TextStyle(fontSize: 12),
        ),
        if (datos.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 90,
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Producto')),
                DataColumn(label: Text('Cant.')),
                DataColumn(label: Text('Precio')),
                DataColumn(label: Text('Importe')),
              ],
              rows: datos,
            ),
          ),
        const SizedBox(height: 12),
        Text('${renglones.length} productos · $unidades unidades'),
        const SizedBox(height: 6),
        Text(
          pendiente
              ? 'Total pendiente: revisa códigos, cantidades o precios en L.'
              : 'Total del pedido: ${dinero(suma)}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (datos.isNotEmpty)
          const Text(
            'Desliza la tabla para ver todas las columnas. El comprobante se confirma al facturar.',
            style: TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  Widget detalle() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paso 3 · Revisa y confirma',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Corrige cualquier lectura dudosa. No se guardará nada hasta tu confirmación.',
          ),
          const SizedBox(height: 20),
          ...filas.asMap().entries.map((e) => fila(e.value, e.key)),
          resumenPedido(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: filas.length >= 100
                    ? null
                    : () => setState(() {
                        filas.add(FilaEditable());
                        modificado = true;
                        confirmado = false;
                      }),
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
              TextButton.icon(
                onPressed: transcribir,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Ingresar varios'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: notas,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Notas del pedido (opcional)',
            ),
            onChanged: (_) => cambio(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Confirmo que el cliente, los códigos y las cantidades son correctos.',
            ),
            value: confirmado,
            onChanged: (v) => setState(() {
              confirmado = v!;
              modificado = true;
            }),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                confirmado && filas.isNotEmpty && filas.every((f) => f.revisada)
                ? guardar
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Confirmar y guardar pedido'),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final clientes =
        widget.controlador.datos.clientes.where((c) => c.activo).toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return PopScope(
      canPop: permitirSalida || (!modificado && !ocupado),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !ocupado) {
          salir();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: ocupado ? null : salir,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Nuevo pedido'),
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: ocupado,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Form(
                      key: formulario,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'De la hoja al pedido.',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Selecciona un cliente, agrega los productos y confirma la información.',
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Paso 1 · Cliente del pedido',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: cliente,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cliente del pedido',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: clientes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.codigo,
                                    child: Text(
                                      '${c.codigo} · ${c.nombre}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (v) =>
                                v == null ? 'Selecciona un cliente.' : null,
                            onChanged: (v) {
                              cliente = v;
                              cambio();
                            },
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, restricciones) =>
                                restricciones.maxWidth >= 900
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: imagen()),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 6, child: detalle()),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      imagen(),
                                      const SizedBox(height: 20),
                                      detalle(),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (ocupado)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: .85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(paso),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
