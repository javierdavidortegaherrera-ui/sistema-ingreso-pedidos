import 'package:flutter/material.dart';

import '../modelos/dominio.dart';
import '../modelos/facturacion.dart';

class BuscadorProducto extends StatelessWidget {
  const BuscadorProducto({
    super.key,
    required this.controlador,
    required this.foco,
    required this.productos,
    required this.onChanged,
    required this.onSelected,
    required this.validator,
  });
  final TextEditingController controlador;
  final FocusNode foco;
  final List<Producto> productos;
  final ValueChanged<String> onChanged;
  final ValueChanged<Producto> onSelected;
  final FormFieldValidator<String> validator;
  @override
  Widget build(BuildContext context) => RawAutocomplete<Producto>(
    textEditingController: controlador,
    focusNode: foco,
    displayStringForOption: (p) => p.codigo,
    optionsBuilder: (valor) {
      final q = valor.text.trim().toLowerCase();
      if (q.isEmpty) {
        return const Iterable<Producto>.empty();
      }
      return productos
          .where(
            (p) =>
                p.activo && '${p.codigo} ${p.nombre}'.toLowerCase().contains(q),
          )
          .take(12);
    },
    onSelected: onSelected,
    fieldViewBuilder: (context, texto, focus, seleccionar) => TextFormField(
      controller: texto,
      focusNode: focus,
      decoration: const InputDecoration(
        labelText: 'Código',
        hintText: 'Código o nombre',
        isDense: true,
        suffixIcon: Icon(Icons.search, size: 20),
      ),
      maxLength: 100,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: (_) => seleccionar(),
    ),
    optionsViewBuilder: (context, seleccionar, opciones) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width < 600
              ? MediaQuery.sizeOf(context).width - 72
              : 420,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: opciones
                  .map(
                    (p) => ListTile(
                      title: Text('${p.codigo} · ${p.nombre}'),
                      subtitle: Text(
                        p.precioCentavos != null && p.moneda == monedaSistema
                            ? dinero(p.precioCentavos!)
                            : 'Precio en L pendiente',
                      ),
                      onTap: () => seleccionar(p),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    ),
  );
}
