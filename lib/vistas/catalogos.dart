import 'package:flutter/material.dart';

import '../controladores/controlador_sistema.dart';
import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';
import 'componentes.dart';

const categorias = [
  'Limpieza del hogar',
  'Aseo personal',
  'Cuidado de la piel',
  'Cabello',
  'Otros productos domésticos',
];

class Catalogos extends StatefulWidget {
  const Catalogos({
    super.key,
    required this.controlador,
    required this.esProducto,
  });
  final ControladorSistema controlador;
  final bool esProducto;
  @override
  State<Catalogos> createState() => _CatalogosState();
}

class _CatalogosState extends State<Catalogos> {
  String busqueda = '';
  bool mostrarInactivos = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    final productos =
        c.datos.productos
            .where(
              (p) =>
                  (mostrarInactivos || p.activo) &&
                  '${p.codigo} ${p.nombre} ${p.categoria}'
                      .toLowerCase()
                      .contains(busqueda),
            )
            .toList()
          ..sort((a, b) => a.codigo.compareTo(b.codigo));
    final clientes =
        c.datos.clientes
            .where(
              (p) =>
                  (mostrarInactivos || p.activo) &&
                  '${p.codigo} ${p.nombre}'.toLowerCase().contains(busqueda),
            )
            .toList()
          ..sort((a, b) => a.codigo.compareTo(b.codigo));
    final cantidad = widget.esProducto ? productos.length : clientes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: widget.esProducto
                      ? 'Buscar producto o código'
                      : 'Buscar cliente o código',
                ),
                onChanged: (v) =>
                    setState(() => busqueda = v.trim().toLowerCase()),
              ),
            ),
            FilterChip(
              label: const Text('Incluir inactivos'),
              selected: mostrarInactivos,
              onSelected: (v) => setState(() => mostrarInactivos = v),
            ),
            FilledButton.icon(
              onPressed: c.escribiendo || c.error != null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => FormularioCatalogo(
                        controlador: c,
                        esProducto: widget.esProducto,
                      ),
                    ),
              icon: const Icon(Icons.add),
              label: Text(
                widget.esProducto ? 'Nuevo producto' : 'Nuevo cliente',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '$cantidad ${widget.esProducto ? 'productos' : 'clientes'}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        if (cantidad == 0)
          EstadoVacio(
            icono: widget.esProducto
                ? Icons.inventory_2_outlined
                : Icons.people_outline,
            titulo: busqueda.isEmpty
                ? 'Tu catálogo comienza aquí'
                : 'Sin coincidencias',
            detalle: 'Registra códigos únicos. Los códigos conservan los ceros iniciales.',
          )
        else
          Card(
            child: Column(
              children: List.generate(cantidad, (i) {
                final codigo = widget.esProducto
                    ? productos[i].codigo
                    : clientes[i].codigo;
                final nombre = widget.esProducto
                    ? productos[i].nombre
                    : clientes[i].nombre;
                final activo = widget.esProducto
                    ? productos[i].activo
                    : clientes[i].activo;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFEEF0),
                    child: Icon(
                      widget.esProducto
                          ? Icons.local_laundry_service_outlined
                          : Icons.person_outline,
                      color: const Color(0xFFB71C2C),
                    ),
                  ),
                  title: Text(nombre),
                  subtitle: Text(
                    '$codigo${widget.esProducto ? ' · ${productos[i].precioCentavos == null ? 'Precio pendiente' : dinero(productos[i].precioCentavos!, moneda: productos[i].moneda)}${productos[i].moneda != monedaSistema ? ' · Revisar precio en L' : ''}' : ''} · ${widget.esProducto
                        ? productos[i].categoria
                        : clientes[i].telefono.isEmpty
                        ? 'Sin teléfono'
                        : clientes[i].telefono}${activo ? '' : ' · Inactivo'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Editar registro',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: c.escribiendo || c.error != null
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => FormularioCatalogo(
                              controlador: c,
                              esProducto: widget.esProducto,
                              producto: widget.esProducto ? productos[i] : null,
                              cliente: widget.esProducto ? null : clientes[i],
                            ),
                          ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class FormularioCatalogo extends StatefulWidget {
  const FormularioCatalogo({
    super.key,
    required this.controlador,
    required this.esProducto,
    this.producto,
    this.cliente,
  });
  final ControladorSistema controlador;
  final bool esProducto;
  final Producto? producto;
  final Cliente? cliente;
  @override
  State<FormularioCatalogo> createState() => _FormularioCatalogoState();
}

class _FormularioCatalogoState extends State<FormularioCatalogo> {
  final form = GlobalKey<FormState>();
  late final TextEditingController codigo;
  late final TextEditingController nombre;
  late final TextEditingController telefono;
  late final TextEditingController precio;
  late String categoria;
  late bool activo;
  bool ocupado = false;
  String? error;
  bool get nuevo => widget.producto == null && widget.cliente == null;
  @override
  void initState() {
    super.initState();
    codigo = TextEditingController(
      text: widget.producto?.codigo ?? widget.cliente?.codigo,
    );
    nombre = TextEditingController(
      text: widget.producto?.nombre ?? widget.cliente?.nombre,
    );
    telefono = TextEditingController(text: widget.cliente?.telefono);
    precio = TextEditingController(
      text:
          widget.producto?.precioCentavos == null ||
              widget.producto?.moneda != monedaSistema
          ? ''
          : decimalDinero(widget.producto!.precioCentavos!),
    );
    categoria = widget.producto?.categoria ?? categorias.first;
    activo = widget.producto?.activo ?? widget.cliente?.activo ?? true;
  }

  @override
  void dispose() {
    codigo.dispose();
    nombre.dispose();
    telefono.dispose();
    precio.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final eraActivo =
        widget.producto?.activo ?? widget.cliente?.activo ?? false;
    if (!activo &&
        eraActivo &&
        !await confirmar(
          context,
          'Desactivar registro',
          'Ya no se podrá seleccionar en nuevos pedidos. El historial se conservará.',
          accion: 'Desactivar',
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
      if (widget.esProducto) {
        await widget.controlador.guardarProducto(
          Producto(
            codigo: normalizarCodigo(codigo.text),
            nombre: nombre.text.trim(),
            categoria: categoria,
            activo: activo,
            precioCentavos: leerCentavos(precio.text),
          ),
          nuevo: nuevo,
        );
      } else {
        await widget.controlador.guardarCliente(
          Cliente(
            codigo: normalizarCodigo(codigo.text),
            nombre: nombre.text.trim(),
            telefono: telefono.text.trim(),
            activo: activo,
          ),
          nuevo: nuevo,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        avisar(context, 'Registro guardado.');
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
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: AlertDialog(
      title: Text(
        '${nuevo ? 'Nuevo' : 'Editar'} ${widget.esProducto ? 'producto' : 'cliente'}',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codigo,
                  enabled: nuevo && !ocupado,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Código único',
                    helperText: 'Letras, números, guion y guion bajo.',
                  ),
                  validator: (v) =>
                      patronCodigo.hasMatch(normalizarCodigo(v ?? ''))
                      ? null
                      : 'Escribe un código válido.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombre,
                  enabled: !ocupado,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'El nombre es obligatorio.'
                      : null,
                ),
                const SizedBox(height: 12),
                if (widget.esProducto)
                  DropdownButtonFormField<String>(
                    initialValue: categoria,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: ocupado
                        ? null
                        : (v) => setState(() => categoria = v!),
                  )
                else
                  TextFormField(
                    controller: telefono,
                    enabled: !ocupado,
                    maxLength: 25,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                    ),
                  ),
                if (widget.esProducto) ...[
                  if (widget.producto?.precioCentavos != null &&
                      widget.producto?.moneda != monedaSistema)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Precio anterior: ${dinero(widget.producto!.precioCentavos!, moneda: widget.producto!.moneda)}. Escribe el precio en lempiras; no se convirtió automáticamente.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: precio,
                    enabled: !ocupado,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 12,
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario (L)',
                      helperText:
                          'Hasta dos decimales, sin separadores de miles.',
                    ),
                    validator: (v) {
                      final monto = leerCentavos(v ?? '');
                      return monto == null ||
                              monto < 1 ||
                              monto > precioMaximoCentavos
                          ? 'Precio entre 0.01 y 1000000.00.'
                          : null;
                    },
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  subtitle: const Text('Disponible para nuevos pedidos'),
                  value: activo,
                  onChanged: ocupado ? null : (v) => setState(() => activo = v),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: ocupado ? null : guardar,
          child: Text(ocupado ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
