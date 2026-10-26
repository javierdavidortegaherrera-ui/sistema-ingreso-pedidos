# Demostración del flujo de pedidos

[Reproducir MP4](flujo-pedidos.mp4) · [Portada](portada.png)

Video sin audio de 27 segundos, 1920 × 1080, H.264. Montaje de capturas de la interfaz producidas por una prueba de widgets; no es una grabación de un dispositivo físico. Todos los datos son ficticios y **la respuesta de ML Kit está simulada**. El rótulo permanece visible en todas las escenas.

Se muestra una cantidad no reconocida, corrección manual, revisión de cuatro renglones, confirmación del pedido, pago en efectivo de prueba y comprobante por L 420.00. No acredita precisión de OCR, cobros reales ni ejecución nativa de cámara/compartir PDF.

## Regenerar

Desde la raíz, con las dependencias Flutter resueltas y Python disponible:

```powershell
flutter test test/demo_portafolio_test.dart --dart-define=DEMO_PORTAFOLIO=true --reporter expanded
python -m pip install -r scripts/requirements-demo.txt
python scripts/crear_demo_video.py
```

La prueba optativa usa almacenamiento y selector de imágenes simulados. Comprueba el pedido y comprobante resultantes antes de escribir el manifiesto de escenas en `build/demo_portafolio/`. La suite normal omite esta generación de medios. El script añade títulos y rótulos, crea MP4 y comprueba su decodificación. Los fotogramas intermedios, herramientas y binarios FFmpeg no se publican.

La hoja fue generada para pruebas ([procedencia](../ATRIBUCIONES.md)); la transición foto → revisión no es una evaluación de lectura manuscrita real.
