"""Copia avisos de paquetes resueltos; no publica rutas de la caché local."""
from pathlib import Path
from urllib.parse import urlparse, unquote
from urllib.request import url2pathname
import json

ROOT = Path(__file__).resolve().parents[1]
config_path = ROOT / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text(encoding='utf-8'))
notices = ['AVISOS DE DEPENDENCIAS DART / FLUTTER', '', 'Recopilados de los paquetes resueltos en pubspec.lock. Cada dependencia conserva su licencia; la licencia MIT del proyecto no las sustituye.', 'Las rutas de instalación del equipo no se incluyen.', '']
missing = []
for package in sorted(config['packages'], key=lambda p: p['name']):
    if package['name'] == 'sistema_ingreso_pedidos':
        continue
    uri = urlparse(package['rootUri'])
    path = Path(url2pathname(unquote(uri.path))) if uri.scheme == 'file' else (config_path.parent / unquote(package['rootUri'])).resolve()
    if path.as_posix().startswith('/C:'):
        path = Path(path.as_posix()[1:])
    license_path = next((path / name for name in ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENCE'] if (path / name).is_file()), None)
    if license_path is None and package['name'] in {'flutter_localizations', 'flutter_test', 'flutter_web_plugins'}:
        sdk_license = path.parent.parent / 'LICENSE'
        if sdk_license.is_file():
            license_path = sdk_license
    version = 'SDK'
    pubspec = path / 'pubspec.yaml'
    if pubspec.exists():
        for line in pubspec.read_text(encoding='utf-8').splitlines():
            if line.startswith('version:'):
                version = line.split(':', 1)[1].strip().strip('"\'')
                break
    notices.extend(['=' * 72, f"{package['name']} {version}", '=' * 72, ''])
    if license_path:
        notices.extend([license_path.read_text(encoding='utf-8-sig'), ''])
    else:
        missing.append(package['name'])
        notices.extend(['No se encontró LICENSE en el paquete resuelto; consultar el SDK o la documentación del proveedor.', ''])
out = ROOT / 'docs/LICENCIAS_DEPENDENCIAS.txt'
out.write_text('\n'.join(notices), encoding='utf-8')
print(f'Avisos recopilados: {len(config["packages"]) - 1}; sin archivo propio: {", ".join(missing) or "ninguno"}.')
