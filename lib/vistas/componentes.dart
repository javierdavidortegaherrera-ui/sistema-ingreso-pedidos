import 'package:flutter/material.dart';

import '../controladores/controlador_sistema.dart';

void avisar(BuildContext context, String mensaje) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
Future<bool> confirmar(
  BuildContext context,
  String titulo,
  String mensaje, {
  String accion = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    ) ??
    false;
Future<void> ejecutar(
  BuildContext context,
  Future<void> Function() accion,
  String exito,
) async {
  try {
    await accion();
    if (context.mounted) {
      avisar(context, exito);
    }
  } catch (e) {
    if (context.mounted) {
      avisar(context, mensajeError(e));
    }
  }
}

String fechaCorta(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });
  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
            if (accion != null)
              Padding(padding: const EdgeInsets.only(top: 20), child: accion),
          ],
        ),
      ),
    ),
  );
}

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});
  final String estado;
  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'Entregado' => Colors.green.shade700,
      'Cancelado' => Colors.red.shade700,
      'Preparando' => Colors.orange.shade900,
      _ => const Color(0xFFB71C2C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
