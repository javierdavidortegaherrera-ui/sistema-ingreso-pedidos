# Pruebas locales de reglas Firestore

Requieren Node.js 20 o superior, pnpm, Java compatible y Firebase CLI. Desde la raíz del proyecto:

```powershell
pnpm --dir test/firebase install --frozen-lockfile
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
firebase emulators:exec --only firestore --project demo-pedidos-facturacion 'C:\nvm4w\nodejs\node.exe --test test/firebase/reglas.test.mjs'
```

Sustituye la ruta del ejecutable Node si fuera distinta. Usar una ruta absoluta evita que algunas distribuciones independientes de Firebase CLI ejecuten su propio Node interno. El proyecto `demo-pedidos-facturacion` es de emulación y no usa servicios remotos. No se requiere desplegar reglas.

Las ocho pruebas comprueban aislamiento de cuentas, contador y comprobante atómicos, consecutivos, documentos inmutables, referencias de pago, importes principales, pedidos cancelados, precios y dos emisiones simultáneas. Los errores `PERMISSION_DENIED` de operaciones que deben rechazarse son esperados. La prueba de concurrencia usa el SDK JavaScript con la misma estrategia de reintento por contador avanzado que el repositorio Dart; no sustituye una prueba de la app Android conectada a Firebase.

Los scripts de instalación de dependencias están deshabilitados en `pnpm-workspace.yaml`; no se necesitan para estas pruebas JavaScript.
