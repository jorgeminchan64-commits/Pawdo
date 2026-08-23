param(
  [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..")
)

$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$androidRoot = Join-Path $resolvedRoot 'android'
$keystorePath = Join-Path $androidRoot 'app\pawdo-release.jks'
$propertiesPath = Join-Path $androidRoot 'key.properties'

if (-not $keystorePath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not $propertiesPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Signing targets must stay inside the Pawdo workspace.'
}
if ((Test-Path -LiteralPath $keystorePath) -or
    (Test-Path -LiteralPath $propertiesPath)) {
  throw 'Release signing already exists. Nothing was overwritten.'
}

$keytool = (Get-Command keytool -ErrorAction Stop).Source
$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$password = -join (1..40 | ForEach-Object {
    $alphabet[[Security.Cryptography.RandomNumberGenerator]::GetInt32($alphabet.Length)]
  })
$keytoolArgs = @(
  '-genkeypair',
  '-v',
  '-keystore', $keystorePath,
  '-storetype', 'PKCS12',
  '-storepass', $password,
  '-keypass', $password,
  '-alias', 'pawdo',
  '-keyalg', 'RSA',
  '-keysize', '4096',
  '-validity', '10000',
  '-dname', 'CN=Jorge Luis Minchan Huaman, OU=Pawdo, O=Pawdo, L=Lima, ST=Lima, C=PE'
)
& $keytool @keytoolArgs
if ($LASTEXITCODE -ne 0) {
  throw 'keytool could not create the Pawdo release keystore.'
}

$properties = @(
  "storePassword=$password"
  "keyPassword=$password"
  'keyAlias=pawdo'
  'storeFile=pawdo-release.jks'
) -join [Environment]::NewLine
[IO.File]::WriteAllText(
  $propertiesPath,
  $properties + [Environment]::NewLine,
  [Text.UTF8Encoding]::new($false)
)

Write-Output "Release keystore created: $keystorePath"
Write-Output "Ignored Gradle credentials created: $propertiesPath"
Write-Output 'Back up both files together. The password is intentionally not printed.'
