# Verificación · 25 de octubre de 2026

Entorno local: Windows, Flutter 3.47.8 estable y Dart 3.13.7. Dependencias fijadas en `pubspec.lock`.

## Preparación para portafolio

- `flutter analyze --no-pub`: sin problemas, después del ajuste visual.
- Suite normal: **39 pruebas aprobadas** y una prueba de generación de medios omitida por diseño.
- Demostración optativa: **una prueba aprobada**, con pedido de ocho unidades y comprobante de L 420.00 verificados.
- Video de 27 segundos, 1920 × 1080, H.264: generado y decodificado correctamente. Fotogramas con datos ficticios y rótulo permanente de OCR simulado.
- Auditoría estática de candidatos Git: sin coincidencias de los patrones de credenciales ni rutas personales revisados. Comprueba exclusiones de APK, cachés, dependencias y configuración local.
- Sintaxis YAML y estructura básica de los dos workflows revisadas localmente; enlaces locales de Markdown comprobados.
- APK release recompilado correctamente con el ajuste del selector de pagos. Gradle conserva avisos de compatibilidad futura de los plugins Firebase con Kotlin, sin impedir esta compilación.
- Licencia MIT del código y avisos de 103 paquetes Dart/Flutter recopilados, incluidas licencias del SDK donde corresponden.
- Capturas y fotogramas revisados visualmente; solo contienen información ficticia.

La suite sin fuentes de captura detectó un desbordamiento en el filtro de métodos de pago. Se ajustó el selector al ancho disponible y se limitaron sus etiquetas con elipsis. Las 39 pruebas pasaron después del ajuste.

Los workflows aún **no se han ejecutado en GitHub**. El repositorio remoto y la Release no se han creado durante esta preparación. Los APK y herramientas locales están excluidos del código.

## Cobertura funcional

Las pruebas cubren interpretación de pares y tablas de uno/dos bloques, ceros iniciales, dígitos separados por casillas, cantidades ausentes, números ambiguos, confianza baja, códigos desconocidos, duplicados, conservación de precios, validaciones y errores de guardado con reintento.

La facturación incluye importes exactos en centavos, descuentos, pagos insuficientes, efectivo/débito/crédito/transferencia, referencia obligatoria, numeración local consecutiva, comprobantes inmutables, idempotencia y compatibilidad con registros anteriores. Los precios antiguos sin moneda se conservan como USD; no hay conversión automática.

Se probaron formularios en 390 × 844 y 1365 × 960. Las capturas son de pruebas de widgets, no fotografías de un teléfono. El OCR nativo se simula; los casos de tabla usan geometría sintética. **No se midió precisión sobre escritura manuscrita real.**

## Comprobaciones anteriores conservadas

- Compilaciones Android debug/release y web correctas.
- Ocho pruebas de reglas Firestore aprobadas con emuladores y proyecto de demostración local: aislamiento, escrituras atómicas, consecutivos, documentos inmutables, importes principales y concurrencia. No se usó Firebase remoto. [Reproducción](../test/firebase/README.md).
- PDF sencillo y comprobante de 100 productos en ocho páginas: códigos y total L 2070.00 comprobados por extracción de texto; páginas inicial y final inspeccionadas. Los PDF de verificación quedan excluidos del código.
- APK release: firma v2 de desarrollo y manifiesto revisados, paquete `hn.javier.sistema_ingreso_pedidos`, versión 1.0.0, Android mínimo API 24; arquitecturas arm64-v8a, armeabi-v7a y x86_64.

El APK de entrega se prepara en `dist/release/`, con SHA-256 de la copia y originales coincidentes. Consulta `SHA256.txt` para el hash de la compilación entregada. La firma sigue siendo de desarrollo. La optimización R8 permanece activa; las reglas específicas solo cubren clases de modelos opcionales no latinos de ML Kit.

## Pendiente de validación real

- Instalar la compilación release en Android físico y comprobar cámara, galería, permisos, OCR, icono e impresión/compartir PDF.
- Evaluar fotografías originales de hojas y precisión de escritura manuscrita; mantener la revisión humana.
- Configurar Firebase del propietario y probar la app completa con dos cuentas. No se desplegaron reglas ni datos remotos.
- Definir respaldo/migración y firma de distribución antes de uso operativo o comercial.

El modo predeterminado sigue siendo local, sin respaldo remoto. No se realizaron cobros bancarios ni se emitieron facturas fiscales.
