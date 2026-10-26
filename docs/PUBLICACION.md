# Preparación y publicación en GitHub

Repositorio nuevo propuesto: `sistema-ingreso-pedidos`, en la cuenta del autor `javierdavidortegaherrera-ui`. Todavía no se creó un repositorio remoto ni se publicó el APK.

## Revisar el código

Desde la raíz del proyecto:

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
python scripts/auditar_publicacion.py
git status --short
```

La auditoría revisa archivos candidatos, exclusiones y algunos patrones de credenciales/rutas personales. No sustituye revisar fotos, video, datos y configuración. Las capturas y el video incluidos usan datos ficticios; el OCR de la demostración está simulado.

No agregues `build/`, `.dart_tool/`, `node_modules/`, `.tools/`, `dist/`, `entregas/`, configuración local, claves de firma ni datos reales. No uses `git add -f` para saltar estas exclusiones. Un archivo ya seguido por Git no deja de estarlo por añadirlo a `.gitignore`; vuelve a auditar tras preparar el commit.

## Crear el repositorio

En GitHub crea un repositorio vacío, elige su visibilidad y usa el nombre acordado. No generes otro README, licencia ni gitignore. Desde la carpeta local:

```powershell
git add .
python scripts/auditar_publicacion.py
git diff --cached --stat
git commit -m "Prepara prototipo Flutter para portafolio"
git remote add origin URL_DEL_REPOSITORIO
git push -u origin HEAD:main
```

Sustituye la URL por la que te entregue GitHub. El último comando publica el código. Configura tu identidad Git antes del commit si fuera necesario. La rama local preparada es `codex/portafolio`; el comando publica su contenido en `main`.

Después del primer push, revisa Actions. Los workflows incluidos no se han ejecutado en GitHub durante la preparación local. Actualiza el README con el enlace real de Releases cuando exista.

## Entregar el APK por Releases

```powershell
flutter build apk --release
powershell -ExecutionPolicy Bypass -File scripts/preparar_release.ps1
Get-FileHash dist/release/Pedidos-Prototipo-Cliente.apk -Algorithm SHA256
```

En GitHub abre **Releases → Draft a new release**, crea `v1.0.0-prototipo.1` sobre `main` y copia [las notas](releases/v1.0.0-prototipo.1.md). Adjunta los archivos de `dist/release/`: APK, SHA256, LEEME, LICENSE, LICENSE-Roboto, ATRIBUCIONES y LICENCIAS_DEPENDENCIAS. Márcalo como **pre-release**, revisa el borrador y publícalo cuando esté listo para el cliente. No subas el APK mediante “Add file” al código.

Para actualizar el prototipo, conserva la misma clave de firma y aumenta el número de compilación. Las claves son privadas: respáldalas fuera del repositorio. Cambiar de firma puede obligar a desinstalar y perder datos locales. Este proyecto usa firma de desarrollo; para una entrega comercial debe configurarse una firma de distribución.

## Borrador mediante Actions, opcional

El workflow **Preparar borrador de Release Android** es manual. Compila, verifica y crea un borrador marcado como pre-release; no lo publica automáticamente. Necesita permisos de escritura en Contents para ese trabajo.

Antes de ejecutarlo, configura el secreto de Actions `PROTOTYPE_DEBUG_KEYSTORE_BASE64` con la codificación Base64 de la clave de desarrollo **que ya firma tu prototipo**. No la pegues en issues, documentación, commits ni mensajes. El workflow restaura la clave en el runner para conservar la firma entre compilaciones. Si falta el secreto, falla antes de compilar; no genera una firma diferente silenciosamente.

Si no deseas configurar secretos en Actions, compila localmente con tu clave existente y adjunta los archivos al borrador desde la web. No hace falta compartir la clave para subir un APK ya firmado.

## Video del portafolio

El video se incluye en `docs/demo/` y se enlaza desde el README. También puedes adjuntarlo al editar el README en GitHub y reemplazar el enlace por el adjunto generado. Conserva el aviso de datos ficticios y OCR simulado. [Reproducción y generación](demo/README.md).
