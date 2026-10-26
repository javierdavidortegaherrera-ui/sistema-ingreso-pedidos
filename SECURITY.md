# Privacidad y reporte de problemas

Este repositorio de portafolio debe contener únicamente código, recursos propios o licenciados y datos ficticios de demostración. No adjuntes registros de clientes, teléfonos, pedidos reales, fotos de formularios, credenciales ni respaldos a issues o pull requests públicos.

Para informar un problema, describe el comportamiento y los pasos mínimos para reproducirlo con datos inventados. Si implica una credencial expuesta, revócala en el proveedor y comunica el incidente por un canal privado con el propietario del proyecto. No publiques el valor afectado.

## Alcance actual

- El modo predeterminado es local con SharedPreferences; no ofrece respaldo remoto ni cifrado propio. Desinstalar o limpiar datos puede perder registros.
- Firebase requiere configuración del propietario. Las reglas aíslan cuentas, pero la integridad completa de los renglones se valida en el cliente. Para uso operativo frente a clientes modificados, la emisión debe trasladarse a un servicio de confianza.
- Los pagos se registran manualmente; no hay pasarela bancaria ni almacenamiento de números de tarjeta o CVV.
- Los comprobantes son internos y no tienen autorización fiscal.
- El OCR necesita revisión humana; las pruebas con respuestas simuladas no acreditan precisión manuscrita en dispositivos reales.

## Revisión antes de publicar

Ejecuta `python scripts/auditar_publicacion.py` desde la raíz del repositorio y revisa visualmente las imágenes/video que se vayan a publicar. El script revisa archivos candidatos de Git, patrones de credenciales, rutas personales, archivos operativos y exclusiones; no constituye una auditoría exhaustiva ni detecta información personal dentro de imágenes.
