param([switch]$Compilar)
$ErrorActionPreference = 'Stop'
$raizProyecto = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $raizProyecto
try {
    if ($Compilar) {
        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación Android.' }
    }
    $apkOrigen = Join-Path $raizProyecto 'build/app/outputs/flutter-apk/app-release.apk'
    if (-not (Test-Path -LiteralPath $apkOrigen)) {
        throw 'Compila primero con flutter build apk --release o utiliza -Compilar.'
    }
    $destinoRelease = Join-Path $raizProyecto 'dist/release'
    New-Item -ItemType Directory -Path $destinoRelease -Force | Out-Null
    $apkDestino = Join-Path $destinoRelease 'Pedidos-Prototipo-Cliente.apk'
    Copy-Item -LiteralPath $apkOrigen -Destination $apkDestino -Force
    foreach ($archivo in @('docs/LEEME-CLIENTE.txt', 'LICENSE', 'docs/ATRIBUCIONES.md', 'docs/LICENCIAS_DEPENDENCIAS.txt', 'assets/fonts/LICENSE-Roboto.txt')) {
        Copy-Item -LiteralPath (Join-Path $raizProyecto $archivo) -Destination $destinoRelease -Force
    }
    $hashApk = (Get-FileHash -LiteralPath $apkDestino -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hashApk  Pedidos-Prototipo-Cliente.apk" | Set-Content -LiteralPath (Join-Path $destinoRelease 'SHA256.txt') -Encoding ascii
    Write-Output "Entrega preparada en $destinoRelease"
    Write-Output "SHA-256: $hashApk"
    Write-Output 'Los archivos son locales. No se creó ni publicó un Release remoto.'
} finally {
    Pop-Location
}
