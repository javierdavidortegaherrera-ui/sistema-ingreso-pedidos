@echo off
chcp 65001 >nul
pushd "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter no está en PATH. Consulta README.md.
  pause
  popd
  exit /b 1
)
call flutter pub get
if errorlevel 1 (
  echo No se pudieron resolver las dependencias.
  pause
  popd
  exit /b 1
)
echo Iniciando Sistema de Ingreso de Pedidos en modo local...
call flutter run -d chrome --web-port=8787
popd
pause
