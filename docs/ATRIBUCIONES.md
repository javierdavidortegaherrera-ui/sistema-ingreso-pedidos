# Licencia, recursos y atribuciones

## Código del proyecto

Copyright © 2026 Javier David Ortega Herrera. El código propio se distribuye bajo [MIT](../LICENSE), igual que otros proyectos del portafolio del autor. Las dependencias, fuentes y servicios conservan sus condiciones independientes.

El proyecto se desarrolló de forma iterativa con asistencia de IA. La presentación no atribuye a este repositorio autoría sobre Flutter, Firebase, ML Kit, bibliotecas o marcas de terceros.

## Recursos incluidos

| Recurso | Procedencia y condiciones |
|---|---|
| Icono rojo y blanco | Generado con imagegen para este proyecto; [prompt](../assets/branding/prompt-icono.txt). No representa una marca comercial ajena. |
| Hoja de pedido de prueba | Imagen generada con IA, números ficticios; [prompt](pruebas/prompt-imagen.txt). No es una fotografía de un cliente real. |
| Capturas y video | Generados desde la interfaz del proyecto con datos ficticios. La respuesta OCR del video está simulada y así se rotula. |
| Roboto Regular y Bold | Fuentes obtenidas de los recursos del SDK de Flutter; licencia Apache 2.0 conservada en [LICENSE-Roboto.txt](../assets/fonts/LICENSE-Roboto.txt). |
| Material Icons y plantillas de Flutter | Recursos del SDK sujetos a sus avisos y licencias. Se conservan los encabezados de copyright de los archivos generados. |

## Dependencias

Los textos de licencia encontrados en los paquetes Dart/Flutter resueltos están en [LICENCIAS_DEPENDENCIAS.txt](LICENCIAS_DEPENDENCIAS.txt). Se regeneran con `python scripts/recopilar_licencias.py` después de `flutter pub get`. No se incluye la caché de dependencias en el repositorio.

Firebase y Google ML Kit son servicios/SDK de terceros sujetos a sus propias condiciones. Los plugins Flutter que los conectan no transfieren derechos sobre esos servicios ni implican patrocinio. Referencias: [Firebase](https://firebase.google.com/terms), [ML Kit](https://developers.google.com/ml-kit/terms), [plugins ML Kit](https://pub.dev/packages/google_mlkit_text_recognition).

Las dependencias JavaScript de pruebas se instalan desde `test/firebase/package.json` y su lockfile; no se redistribuye `node_modules`. Las herramientas de codificación de video se instalan aparte y sus binarios tampoco forman parte del código publicado.
