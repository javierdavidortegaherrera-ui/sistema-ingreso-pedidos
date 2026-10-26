import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controladores/controlador_sistema.dart';
import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';
import 'catalogos.dart';
import 'componentes.dart';
import 'nuevo_pedido.dart';
import 'facturacion.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.controlador});
  final ControladorSistema controlador;
  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int pagina = 0;
  String busqueda = '';
  String estado = 'Todos';
  static const titulos = [
    'Resumen',
    'Pedidos',
    'Clientes',
    'Productos',
    'Facturación',
  ];
  static const iconos = [
    Icons.space_dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.inventory_2_outlined,
    Icons.payments_outlined,
  ];
  Future<void> nuevo() async {
    final datos = widget.controlador.datos;
    if (!datos.clientes.any((c) => c.activo) ||
        !datos.productos.any((p) => p.activo)) {
      final destino = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prepara tu primer pedido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El pedido necesita un cliente y productos del catálogo. Registra uno nuevo o activa un registro existente.',
              ),
              const SizedBox(height: 20),
              if (!datos.clientes.any((c) => c.activo))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Falta un cliente activo'),
                  subtitle: const Text(
                    'Abre Clientes para registrarlo o activarlo.',
                  ),
                  onTap: () => Navigator.pop(ctx, 2),
                ),
              if (!datos.productos.any((p) => p.activo))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Falta un producto activo'),
                  subtitle: const Text(
                    'Abre Productos para registrar el código de la hoja.',
                  ),
                  onTap: () => Navigator.pop(ctx, 3),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                !datos.clientes.any((c) => c.activo) ? 2 : 3,
              ),
              child: Text(
                !datos.clientes.any((c) => c.activo)
                    ? 'Abrir clientes'
                    : 'Abrir productos',
              ),
            ),
          ],
        ),
      );
      if (mounted && destino != null) {
        setState(() => pagina = destino);
      }
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevoPedido(controlador: widget.controlador),
      ),
    );
  }

  Widget accesosGuiados() {
    final c = widget.controlador;
    final clientesListos = c.datos.clientes.any((p) => p.activo);
    final productosListos = c.datos.productos.any((p) => p.activo);
    final pendientes = c.datos.pedidos
        .where(
          (p) =>
              p.estado != 'Cancelado' &&
              !c.datos.facturas.any((f) => f.pedidoId == p.id),
        )
        .length;
    final habilitado = !c.cargando && !c.escribiendo && c.error == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tu trabajo, paso a paso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              !clientesListos
                  ? 'Empieza agregando tu primer cliente.'
                  : !productosListos
                  ? 'Ahora registra los códigos de tus productos.'
                  : pendientes > 0
                  ? 'Tienes $pendientes pedidos listos para revisar precios y facturar.'
                  : 'Tu catálogo está listo. Ya puedes registrar un pedido.',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, caja) {
                final ancho = caja.maxWidth >= 950
                    ? (caja.maxWidth - 36) / 4
                    : caja.maxWidth >= 600
                    ? (caja.maxWidth - 12) / 2
                    : caja.maxWidth;
                Widget paso(
                  int n,
                  IconData icono,
                  String titulo,
                  String detalle,
                  String boton,
                  VoidCallback accion, {
                  bool listo = false,
                }) => SizedBox(
                  width: ancho,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              icono,
                              color: const Color(0xFFB71C2C),
                              size: 23,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$n. $titulo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (listo)
                              const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                semanticLabel: 'Configurado',
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Text(detalle),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: habilitado ? accion : null,
                          child: Text(boton),
                        ),
                      ],
                    ),
                  ),
                );
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    paso(
                      1,
                      Icons.people_outline,
                      'Clientes',
                      'Selecciona quién hace el pedido.',
                      clientesListos ? 'Ver clientes' : 'Agregar cliente',
                      () {
                        if (clientesListos) {
                          setState(() => pagina = 2);
                        } else {
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => FormularioCatalogo(
                              controlador: c,
                              esProducto: false,
                            ),
                          );
                        }
                      },
                      listo: clientesListos,
                    ),
                    paso(
                      2,
                      Icons.inventory_2_outlined,
                      'Productos',
                      'Registra códigos y precios en lempiras.',
                      productosListos ? 'Ver productos' : 'Agregar producto',
                      () {
                        if (productosListos) {
                          setState(() => pagina = 3);
                        } else {
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => FormularioCatalogo(
                              controlador: c,
                              esProducto: true,
                            ),
                          );
                        }
                      },
                      listo: productosListos,
                    ),
                    paso(
                      3,
                      Icons.add_photo_alternate_outlined,
                      'Pedido',
                      'Usa una foto o escribe los códigos.',
                      'Crear pedido',
                      nuevo,
                    ),
                    paso(
                      4,
                      Icons.payments_outlined,
                      'Facturación',
                      'Revisa precios y registra el pago.',
                      pendientes > 0
                          ? 'Facturar ($pendientes)'
                          : 'Ver comprobantes',
                      () => setState(() => pagina = 4),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget metrica(String titulo, String valor, IconData icono) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: const Color(0xFFB71C2C), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(titulo)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
  Widget resumen() {
    final c = widget.controlador;
    final pedidos = c.datos.pedidos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF8F1424),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MENOS TRANSCRIPCIÓN. MÁS CONTROL.',
                style: TextStyle(
                  color: Color(0xFFFFDCE1),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tus pedidos,\nen orden.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Convierte una fotografía en un pedido revisado.\nCada código claro, cada cantidad confirmada.',
                style: TextStyle(color: Color(0xFFFFE8EC), height: 1.7),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFFFF),
                  foregroundColor: const Color(0xFF8F1424),
                ),
                onPressed: c.cargando || c.escribiendo || c.error != null
                    ? null
                    : nuevo,
                icon: const Icon(Icons.add),
                label: const Text('Ingresar pedido'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        accesosGuiados(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            metrica(
              'Pedidos registrados',
              '${pedidos.length}',
              Icons.receipt_long_outlined,
            ),
            metrica(
              'Por preparar',
              '${pedidos.where((p) => p.estado == 'Registrado' || p.estado == 'Preparando').length}',
              Icons.pending_actions_outlined,
            ),
            metrica(
              'Clientes activos',
              '${c.datos.clientes.where((p) => p.activo).length}',
              Icons.people_outline,
            ),
            metrica(
              'Productos activos',
              '${c.datos.productos.where((p) => p.activo).length}',
              Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pedidos recientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => pagina = 1),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pedidos.isEmpty)
          EstadoVacio(
            icono: Icons.receipt_long_outlined,
            titulo: 'El primer pedido empieza contigo',
            detalle: 'Registra tus clientes y productos; luego carga una fotografía o ingresa los códigos manualmente.',
            accion: OutlinedButton(
              onPressed: () => setState(() => pagina = 3),
              child: const Text('Abrir catálogo de productos'),
            ),
          )
        else
          ...pedidos.take(5).map(tarjetaPedido),
        if (c.datos.clientes.isEmpty &&
            c.datos.productos.isEmpty &&
            c.error == null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: TextButton.icon(
              onPressed: c.escribiendo || c.cargando
                  ? null
                  : () => ejecutar(
                      context,
                      c.cargarEjemplos,
                      'Se cargaron un cliente y cuatro productos de ejemplo.',
                    ),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Probar con datos de ejemplo'),
            ),
          ),
      ],
    );
  }

  Widget tarjetaPedido(Pedido p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetallePedido(controlador: widget.controlador, id: p.id),
          ),
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEEF0),
          child: Icon(Icons.receipt_long_outlined, color: Color(0xFFB71C2C)),
        ),
        title: Text(
          p.clienteNombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${fechaCorta(p.fecha)}\n${p.lineas.length} productos · ${p.unidades} unidades · ${p.origen}',
        ),
        isThreeLine: true,
        trailing: EtiquetaEstado(p.estado),
      ),
    ),
  );
  Widget pedidos() {
    final lista = widget.controlador.datos.pedidos
        .where(
          (p) =>
              (estado == 'Todos' || p.estado == estado) &&
              '${p.id} ${p.clienteCodigo} ${p.clienteNombre}'
                  .toLowerCase()
                  .contains(busqueda),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar cliente o número de pedido',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => busqueda = v.toLowerCase().trim()),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                initialValue: estado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items:
                    [
                          'Todos',
                          'Registrado',
                          'Preparando',
                          'Entregado',
                          'Cancelado',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) => setState(() => estado = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${lista.length} pedidos',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          const EstadoVacio(
            icono: Icons.manage_search,
            titulo: 'No hay pedidos para mostrar',
            detalle:
                'Ingresa un nuevo pedido o cambia la búsqueda y el estado.',
          )
        else
          ...lista.map(tarjetaPedido),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controlador,
    builder: (context, _) {
      final c = widget.controlador;
      final ancho = MediaQuery.sizeOf(context).width >= 1000;
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/branding/icono-pedidos-rojo-blanco.png',
                  width: 34,
                  height: 34,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(ancho ? 'Ingreso de pedidos' : titulos[pagina]),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar datos',
              onPressed: c.cargando || c.escribiendo ? null : c.cargar,
              icon: const Icon(Icons.refresh),
            ),
            if (c.enNube)
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: c.escribiendo
                    ? null
                    : () async {
                        if (await confirmar(
                          context,
                          'Cerrar sesión',
                          'Se cerrará tu espacio de trabajo.',
                          accion: 'Salir',
                        )) {
                          try {
                            await FirebaseAuth.instance.signOut();
                          } catch (e) {
                            if (context.mounted) {
                              avisar(context, mensajeError(e));
                            }
                          }
                        }
                      },
                icon: const Icon(Icons.logout),
              ),
            const SizedBox(width: 12),
          ],
        ),
        bottomNavigationBar: ancho
            ? null
            : NavigationBar(
                selectedIndex: pagina,
                onDestinationSelected: (v) => setState(() => pagina = v),
                destinations: List.generate(
                  titulos.length,
                  (i) => NavigationDestination(
                    icon: Icon(iconos[i]),
                    label: titulos[i],
                  ),
                ),
              ),
        floatingActionButton: pagina == 1
            ? FloatingActionButton.extended(
                onPressed: c.cargando || c.escribiendo || c.error != null
                    ? null
                    : nuevo,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo pedido'),
              )
            : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ancho)
              Container(
                width: 224,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Color(0xFFE9E9ED))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 20),
                      child: Text(
                        'ESPACIO DE TRABAJO',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF71717A),
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    ...List.generate(
                      titulos.length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            selected: pagina == i,
                            selectedTileColor: const Color(0xFFFFE9ED),
                            leading: Icon(iconos[i]),
                            title: Text(titulos[i]),
                            onTap: () => setState(() => pagina = i),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        c.enNube
                            ? 'Firebase conectado\nEspacio privado por usuario'
                            : 'Modo local de prueba\nDatos en este dispositivo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF62626B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (c.cargando || c.escribiendo)
                    const LinearProgressIndicator(minHeight: 3),
                  if (!c.enNube)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFF4F4F5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: const Text(
                        'Modo local · Los datos se guardan en este dispositivo. Firebase aún no está configurado.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF52525B),
                        ),
                      ),
                    ),
                  if (c.error != null)
                    MaterialBanner(
                      content: Text(c.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: c.cargando || c.escribiendo
                              ? null
                              : c.cargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  Expanded(
                    child:
                        c.cargando &&
                            c.datos.clientes.isEmpty &&
                            c.datos.productos.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: EdgeInsets.all(ancho ? 32 : 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1240,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (pagina != 0) ...[
                                      Text(
                                        titulos[pagina],
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(switch (pagina) {
                                        1 => 'Consulta y organiza los pedidos confirmados.',
                                        2 => 'Cada cliente, un código único.',
                                        3 => 'El catálogo es la referencia de cada lectura.',
                                        _ => 'Precios, comprobantes y pagos en lempiras.',
                                      }),
                                      const SizedBox(height: 24),
                                    ],
                                    switch (pagina) {
                                      0 => resumen(),
                                      1 => pedidos(),
                                      2 => Catalogos(
                                        key: const ValueKey('clientes'),
                                        controlador: c,
                                        esProducto: false,
                                      ),
                                      3 => Catalogos(
                                        key: const ValueKey('productos'),
                                        controlador: c,
                                        esProducto: true,
                                      ),
                                      _ => Facturacion(controlador: c),
                                    },
                                    const SizedBox(height: 90),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DetallePedido extends StatefulWidget {
  const DetallePedido({super.key, required this.controlador, required this.id});
  final ControladorSistema controlador;
  final String id;
  @override
  State<DetallePedido> createState() => _DetallePedidoState();
}

class _DetallePedidoState extends State<DetallePedido> {
  Future<Uint8List?>? imagen;
  @override
  void initState() {
    super.initState();
    cargarFoto();
  }

  void cargarFoto() {
    final p = widget.controlador.datos.pedidos.firstWhere(
      (p) => p.id == widget.id,
    );
    imagen = widget.controlador.repositorio.cargarFoto(p);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controlador,
    builder: (context, _) {
      final c = widget.controlador;
      final p = c.datos.pedidos.firstWhere((p) => p.id == widget.id);
      final facturado = c.datos.facturas.any((f) => f.pedidoId == p.id);
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del pedido')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.clienteNombre,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      EtiquetaEstado(p.estado),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Pedido ${p.id}\nCliente ${p.clienteCodigo} · ${fechaCorta(p.fecha)}\n${p.origen} · Confirmado manualmente',
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: p.lineas
                          .map(
                            (l) => ListTile(
                              title: Text(l.nombre),
                              subtitle: Text(l.codigo),
                              trailing: Text(
                                '× ${l.cantidad}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${p.lineas.length} productos · ${p.unidades} unidades',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.totalCentavos == null
                        ? 'Total pendiente de precios de venta.'
                        : 'Total del pedido: ${dinero(p.totalCentavos!, moneda: p.moneda)}',
                  ),
                  if (p.notas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: SelectableText('Notas: ${p.notas}'),
                    ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            c.escribiendo ||
                                c.error != null ||
                                p.estado == 'Cancelado'
                            ? null
                            : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => facturado
                                      ? DetalleComprobante(
                                          controlador: c,
                                          pedidoId: p.id,
                                        )
                                      : EmitirComprobante(
                                          controlador: c,
                                          pedidoId: p.id,
                                        ),
                                ),
                              ),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          facturado ? 'Ver comprobante' : 'Facturar pedido',
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar resumen'),
                        onPressed: () => ejecutar(
                          context,
                          () => Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Pedido ${p.id}\n${p.clienteCodigo} · ${p.clienteNombre}\n${fechaCorta(p.fecha)}\n${p.lineas.map((l) => '${l.codigo} · ${l.nombre} · ${l.cantidad}').join('\n')}\nEstado: ${p.estado}\n${p.notas}',
                            ),
                          ),
                          'Resumen copiado.',
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !c.escribiendo && c.error == null,
                        tooltip: 'Cambiar estado',
                        onSelected: (estado) async {
                          if (await confirmar(
                            context,
                            'Cambiar estado',
                            'El pedido pasará de ${p.estado} a $estado.',
                            accion: 'Actualizar',
                          )) {
                            if (context.mounted) {
                              await ejecutar(
                                context,
                                () => c.cambiarEstado(p, estado),
                                'Estado actualizado.',
                              );
                            }
                          }
                        },
                        itemBuilder: (_) =>
                            [
                                  'Registrado',
                                  'Preparando',
                                  'Entregado',
                                  'Cancelado',
                                ]
                                .where((e) => e != p.estado)
                                .map(
                                  (e) =>
                                      PopupMenuItem(value: e, child: Text(e)),
                                )
                                .toList(),
                        child: const Chip(
                          avatar: Icon(Icons.edit_outlined, size: 18),
                          label: Text('Cambiar estado'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (p.fotoBase64 != null || p.fotoRuta != null)
                    FutureBuilder<Uint8List?>(
                      future: imagen,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return EstadoVacio(
                            icono: Icons.broken_image_outlined,
                            titulo: 'No se pudo cargar la fotografía',
                            detalle: mensajeError(snapshot.error!),
                            accion: TextButton(
                              onPressed: () => setState(cargarFoto),
                              child: const Text('Reintentar'),
                            ),
                          );
                        }
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.data == null) {
                          return const Text(
                            'La fotografía no está disponible.',
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fotografía del pedido',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 450,
                              child: InteractiveViewer(
                                maxScale: 5,
                                child: Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
