# Diseño del sistema

Aplicación Flutter Material 3 para Android. Web permite ingreso manual y adjuntar imágenes. Kotlin se limita al punto de entrada Android generado por Flutter.

## Organización

- `lib/modelos/dominio.dart`: entidades y reglas de negocio.
- `lib/controladores/controlador_sistema.dart`: carga, exclusión de escrituras simultáneas y errores.
- `lib/datos/repositorio.dart`: contrato de persistencia, adaptadores local y Firebase.
- `lib/servicios/analizador_pedido.dart`: interpretación conservadora de renglones.
- `lib/servicios/reconocimiento.dart`: ML Kit, heurísticas de calidad y compresión de la imagen sin EXIF.
- `lib/vistas/`: resumen, catálogos, formulario, comparación con la imagen e historial.

## Reconocimiento

1. Capturar o seleccionar JPG/PNG (hasta 10 MB).
2. Decodificar en un isolate. Detectar posibles problemas de luz, resolución y enfoque con heurísticas.
3. En Android, ML Kit lee la imagen original. La copia conservada se orienta y comprime a JPEG sin metadatos.
4. Aceptar únicamente pares explícitos por renglón. No convertir O en 0, no buscar códigos similares, no asociar columnas por conjeturas ni asignar cantidades por defecto.
5. Alertar códigos desconocidos, cantidades ausentes o inválidas, confianza ausente/baja, formatos ambiguos, duplicados y ausencia de códigos del catálogo.
6. Editar o eliminar renglones. Se conserva la lectura original como referencia durante la revisión.
7. Revisar cada renglón, confirmar el formulario y aceptar el diálogo final antes de guardar.

La confianza de ML Kit puede faltar o ser engañosa, especialmente con escritura manuscrita. Todas las lecturas necesitan revisión humana. Umbrales iniciales: confianza 0.90, luz media 45, varianza del laplaciano 60 en muestra de 160 px. Necesitan calibración con fotografías reales. No hay garantía de detectar todos los errores.

## Consistencia y seguridad

Códigos como cadenas en mayúsculas, preservando ceros iniciales. Máximo 30 caracteres (letras, números, guiones y guiones bajos). Pedidos de 1–100 códigos distintos y cantidades enteras 1–9999. Se conservan nombres como instantánea. Desactivar registros conserva el historial; los pedidos confirmados solo permiten cambiar estado.

Firebase separa cada cuenta en `usuarios/{uid}/{clientes,productos,pedidos}`. Fotos: `usuarios/{uid}/pedidos/{id}/original.jpg`, recuperadas autenticadas sin URLs públicas persistidas. La creación de catálogos usa transacciones para evitar códigos duplicados. El pedido relee la vigencia de clientes y productos en una transacción. El UUID se conserva al reintentar durante la sesión del borrador.

Storage y Firestore no comparten transacción: primero se sube la imagen y luego se registra el pedido. Si falla Firestore, se conserva la imagen para reintentar la misma ruta. Una sesión abandonada puede dejar fotos huérfanas. La limpieza requiere una tarea administrativa que contraste rutas con documentos; no se ejecuta automáticamente.

Las reglas aíslan usuarios, validan campos principales y bloquean modificaciones al contenido de pedidos confirmados. La validación completa de cada renglón y su relación con productos está en Dart/transacción del cliente; las reglas no recorren toda la lista. Si se exige integridad de negocio frente a clientes modificados, trasladar la creación de pedidos a una función autenticada de servidor y validar allí cada renglón. Esta versión no se presenta como sistema de auditoría o facturación fiscal.

## Límites del modo local

Sirve para desarrollo y evaluación. Guarda JSON y fotos Base64 (hasta 2 MB por foto) en SharedPreferences. No ofrece cifrado, sincronización, escrituras concurrentes entre pestañas ni garantías de una base transaccional. Los datos pueden perderse al limpiar almacenamiento o desinstalar. Para uso operativo configurar Firebase; para uso local prolongado reemplazar el adaptador por SQLite/IndexedDB con respaldo.

Los datos corruptos producen error y bloquean nuevas escrituras; no se reinician silenciosamente. El borrador se conserva ante errores recuperables, pero vive en memoria: terminar el proceso puede perderlo. Se intenta recuperar la imagen pendiente mediante `retrieveLostData` en Android al abrir un pedido; no recupera los campos previos.

## Validación manual pendiente

- Android físico: cámara, permisos, galería, recuperación tras cierre y fotografías manuscritas reales.
- App Android con Firebase propio: sesión, aislamiento entre usuarios, desconexión, fotos, pagos y reintentos. Las reglas de facturación ya cuentan con pruebas locales en emulador.
- Calibrar el OCR con las hojas reales, incluyendo desenfoque, oscuridad y columnas separadas.
- No se incluyen pasarelas de cobro, inventario, envío de mensajes ni reconocimiento del cliente desde la foto.

## Facturación interna y pagos

El módulo usa HNL y centavos enteros. `Producto.precioCentavos` admite ausencia de precio para leer catálogos anteriores. Los comprobantes exigen precios positivos; conservan una instantánea del cliente, códigos, nombres, cantidades y precios. Total = subtotal - descuento. Sin cálculo de impuestos ni conversión monetaria.

Un único comprobante por pedido guardado y no cancelado. El efectivo debe cubrir el total y produce cambio; débito, crédito y transferencia requieren referencia y monto exacto. El operador confirma un pago previamente recibido; no se ejecutan operaciones bancarias. No se guardan datos de tarjeta ni credenciales bancarias. No se implementaron pagos parciales, devoluciones ni anulación de comprobantes.

`DatosSistema.facturas` se carga vacía cuando no existe en el JSON anterior. Las escrituras locales conservan esta lista. Un pedido facturado no puede cancelarse. Reintentos idénticos son idempotentes; contenido diferente para un pedido ya facturado se rechaza para evitar sobrescrituras.

Firestore escribe `facturas/{pedidoId}` y `contadores/comprobantes` en una transacción. La numeración es consecutiva por usuario. Las reglas verifican aislamiento, relación con pedido, numeración conjunta, totales principales, moneda y condiciones del método de pago. Bloquean edición y borrado de comprobantes y cancelación de pedidos facturados. La suma completa de renglones y su correspondencia con el pedido siguen validadas en Dart. Para resistir manipulación por el propio cliente autenticado, migrar la emisión a un servicio de confianza. El modo local no admite numeración concurrente entre pestañas.

El PDF usa `pdf` y `printing`, con fuentes Roboto incluidas bajo su licencia en `assets/fonts/`. Se genera a partir del comprobante guardado; abre el diálogo del sistema para compartir/guardar o imprimir. La app no envía documentos automáticamente.

## Lector de tablas e importes en HNL

`analizador_tabla.dart` consume fragmentos OCR y coordenadas. Reconoce tripletes de encabezados Código/Cant./Total para uno o dos bloques, agrupa elementos por altura y posición horizontal, concatena dígitos observados dentro de una celda y mantiene ceros iniciales. No sustituye letras por números ni toma el total como cantidad. Un elemento que cruza límites se marca dudoso; la cantidad queda pendiente. Se intenta detener la lectura antes del total de pie o la marca del formulario. El diseño requiere encabezados legibles; no es un detector universal de tablas ni rectifica perspectiva pronunciada.

`reconocimiento.dart` adapta los elementos de ML Kit al analizador de tabla. El modo automático usa geometría si reconoce encabezados; el modo de renglones conserva el parser anterior. La interfaz permite elegir el formato. El catálogo nunca se completa desde la foto ni se toma un total escrito como precio.

Productos nuevos: HNL. Productos persistidos con precio sin campo moneda: USD legado. Se exige revisión explícita del precio en L para usarlos monetariamente. Pedidos nuevos conservan moneda y precio unitario por renglón si está disponible. Los comprobantes emitidos en USD mantienen su moneda y montos. No hay conversión de divisas. La facturación precarga primero la instantánea del pedido; si no existe, usa un precio de catálogo en HNL o solicita completarlo.
