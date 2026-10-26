"""Revisa archivos candidatos de Git sin mostrar valores de posibles secretos."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SECRET_PATTERNS = [
    re.compile(r"AIza[0-9A-Za-z_-]{30,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{25,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{25,}"),
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r'"private_key"\s*:\s*"[^"\s]{20,}'),
]
TEXT = {'.dart', '.md', '.txt', '.json', '.yaml', '.yml', '.xml', '.kts', '.gradle', '.properties', '.py', '.ps1', '.mjs', '.bat', '.html', '.svg', '.gitignore', '.gitattributes'}
BANNED = {'.apk', '.aab', '.zip', '.exe', '.dll', '.jar', '.jks', '.keystore', '.pem', '.p12', '.pfx', '.sqlite', '.sqlite3', '.db', '.mdb', '.accdb'}

def run_git(git, *args):
    return subprocess.check_output([git, '-C', str(ROOT), *args], stderr=subprocess.STDOUT)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--git', default=os.environ.get('GIT_EXECUTABLE') or shutil.which('git'))
    args = parser.parse_args()
    if not args.git:
        parser.error('Instala Git o indica --git RUTA_DEL_EJECUTABLE.')
    try:
        raw = run_git(args.git, 'ls-files', '--cached', '--others', '--exclude-standard', '-z')
    except subprocess.CalledProcessError:
        parser.error('Ejecuta git init dentro de este proyecto antes de auditar.')
    candidates = sorted(set(p.decode('utf-8') for p in raw.split(b'\0') if p))
    findings = []
    total = 0
    for name in candidates:
        path = ROOT / name
        if not path.is_file():
            continue
        total += path.stat().st_size
        parts = {p.lower() for p in Path(name).parts}
        lower = path.name.lower()
        if path.suffix.lower() in BANNED or parts & {'build', '.dart_tool', 'node_modules', '.tools', 'backups', 'private', 'entregas'}:
            findings.append(f'{name}: archivo operativo, secreto o binario de distribución')
        if lower in {'local.properties', 'key.properties', 'google-services.json', 'googleservice-info.plist', 'credentials.json', '.firebaserc'} or lower.startswith('firebase.local'):
            findings.append(f'{name}: configuración local o credenciales')
        if path.stat().st_size > 20 * 1024 * 1024:
            findings.append(f'{name}: supera 20 MiB; revisa si corresponde a Releases')
        if path.suffix.lower() in TEXT or lower in {'license', '.gitignore', '.gitattributes', '.metadata'}:
            try:
                content = path.read_text(encoding='utf-8-sig')
            except UnicodeError:
                findings.append(f'{name}: archivo de texto con codificación no revisable')
                continue
            for line, text in enumerate(content.splitlines(), 1):
                if any(pattern.search(text) for pattern in SECRET_PATTERNS):
                    findings.append(f'{name}:{line}: posible credencial; valor omitido')
                if re.search(r'C:[\\/]Users[\\/][A-Za-z0-9_.-]+', text, re.I):
                    findings.append(f'{name}:{line}: ruta personal del equipo')
    exclusions = ['build/app/outputs/flutter-apk/app-release.apk', '.dart_tool/package_config.json', 'test/firebase/node_modules/example/index.js', 'firebase.local.android.json', 'android/local.properties', 'android/key.properties', 'private/clientes.json', 'entregas/prototipo-cliente/app.apk', '.env', 'debug.log']
    for name in exclusions:
        result = subprocess.run([args.git, '-C', str(ROOT), 'check-ignore', '--no-index', '-q', name])
        if result.returncode != 0:
            findings.append(f'.gitignore: falta excluir {name}')
    if findings:
        print('REVISAR ANTES DE PUBLICAR:')
        for finding in findings:
            print('- ' + finding)
        return 1
    print(f'Auditoría estática correcta: {len(candidates)} archivos candidatos, {total / 1048576:.2f} MiB.')
    print('Sin coincidencias de credenciales ni rutas personales en los textos revisados.')
    print('La revisión visual de imágenes y video sigue siendo necesaria.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
