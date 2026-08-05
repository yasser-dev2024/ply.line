$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$secretDirectory = Join-Path $root '.secrets'
$propertiesPath = Join-Path $secretDirectory 'release.properties'
$keystorePath = Join-Path $secretDirectory 'lion-battle-3d-release.keystore'
$keytoolPath = Join-Path $root '..\tools\java17\jdk-17.0.20+8\bin\keytool.exe'

if (Test-Path -LiteralPath $keystorePath) {
    Write-Output 'Release keystore already exists; it was left unchanged.'
    exit 0
}
if (-not (Test-Path -LiteralPath $keytoolPath)) {
    throw 'JDK 17 keytool was not found.'
}

New-Item -ItemType Directory -Path $secretDirectory -Force | Out-Null
$randomBytes = New-Object byte[] 30
$randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$randomGenerator.GetBytes($randomBytes)
$randomGenerator.Dispose()
$password = [Convert]::ToBase64String($randomBytes).Replace('+', 'A').Replace('/', 'B').TrimEnd('=')
$alias = 'lionbattle3d'

& $keytoolPath -genkeypair -keystore $keystorePath -storepass $password -alias $alias -keypass $password -keyalg RSA -keysize 4096 -validity 9125 -dname 'CN=Lion Battle 3D, OU=Mobile Games, O=Savanna Studio, L=Riyadh, ST=Riyadh, C=SA' | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $keystorePath)) {
    throw 'Release keystore generation failed.'
}

$lines = @(
    "KEYSTORE_PATH=$keystorePath"
    "KEYSTORE_ALIAS=$alias"
    "KEYSTORE_PASSWORD=$password"
)
[System.IO.File]::WriteAllLines($propertiesPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Output 'Release keystore and local signing configuration created successfully.'
