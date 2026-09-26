param([string]$Version = '0.0.0')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be MAJOR.MINOR.PATCH' }
$root = Split-Path -Parent $PSScriptRoot
$deps = Join-Path $root 'build/installer-dependencies'
New-Item -ItemType Directory -Force $deps | Out-Null

function Get-Dependency($Url, $Name, $Hash = '') {
    $file = Join-Path $deps $Name
    if (-not (Test-Path -LiteralPath $file)) {
        Invoke-WebRequest $Url -OutFile $file
    }
    if ($Hash) {
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $Hash) {
            throw "Checksum mismatch: $Name"
        }
    } else {
        $signature = Get-AuthenticodeSignature -LiteralPath $file
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw "Invalid Microsoft signature: $Name"
        }
    }
    return $file
}

# Pin the compiler; verify before executing the development-tool installer.
$innoSetup = Get-Dependency 'https://github.com/jrsoftware/issrc/releases/download/is-6_4_3/innosetup-6.4.3.exe' 'innosetup-6.4.3.exe' 'f3c42116542c4cc57263c5ba6c4feabfc49fe771f2f98a79d2f7628b8762723b'
$innoDir = Join-Path $deps 'InnoSetup'
$compiler = Join-Path $innoDir 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $process = Start-Process -FilePath $innoSetup -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/NOICONS', "/DIR=`"$innoDir`"") -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed: $($process.ExitCode)" }
}
Get-Dependency 'https://aka.ms/vs/17/release/vc_redist.x64.exe' 'vc_redist.x64.exe' | Out-Null
Get-Dependency 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' 'MicrosoftEdgeWebview2Setup.exe' | Out-Null

# Include dependency license texts in the installed application.
if (-not $env:VCPKG_ROOT) { throw 'VCPKG_ROOT is required to package dependency licenses' }
$licenses = Join-Path $deps 'licenses'
New-Item -ItemType Directory -Force $licenses | Out-Null
foreach ($port in @('quill', 'nlohmann-json', 'cpp-httplib', 'asio', 'brotli')) {
    Copy-Item -LiteralPath "$env:VCPKG_ROOT/installed/x64-windows/share/$port/copyright" -Destination (Join-Path $licenses "$port.txt") -Force
}
& $compiler "/DAppVersion=$Version" (Join-Path $root 'installer/clew.iss')
if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed: $LASTEXITCODE" }
Write-Host "Installer: build/installer/clew-$Version-windows-x64-setup.exe"
