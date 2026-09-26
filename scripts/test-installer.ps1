# Run only on a disposable GitHub Actions Windows runner; never start the proxy.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) { throw 'Installer smoke tests require a disposable CI runner' }
$root = Split-Path -Parent $PSScriptRoot
$setups = @(Get-ChildItem -LiteralPath (Join-Path $root 'build/installer') -Filter '*-setup.exe')
if ($setups.Count -ne 1) { throw 'Expected exactly one installer' }
$installDir = Join-Path $env:RUNNER_TEMP ('Clew 安装测试 ' + [guid]::NewGuid().ToString('N'))
foreach ($phase in @('install', 'upgrade')) {
    $log = Join-Path $root "build/installer-test-$phase.log"
    $process = Start-Process -FilePath $setups[0].FullName -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/LANG=chinesesimp', "/DIR=`"$installDir`"", "/LOG=`"$log`"") -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "$phase failed: $($process.ExitCode)" }
    foreach ($file in @('clew.exe', 'WinDivert.dll', 'WinDivert64.sys', 'brotlicommon.dll', 'brotlidec.dll', 'brotlienc.dll', 'frontend/dist/index.html', 'licenses/WebView2.txt', 'unins000.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $installDir $file))) { throw "Missing installed file: $file" }
    }
    if ($phase -eq 'install') {
        Set-Content -LiteralPath (Join-Path $installDir 'clew.json') -Value '{"ui":{"language":"zh-CN"}}'
    } elseif ((Get-Content -LiteralPath (Join-Path $installDir 'clew.json') -Raw).Trim() -ne '{"ui":{"language":"zh-CN"}}') {
        throw 'Upgrade changed user configuration'
    }
}
$log = Join-Path $root 'build/installer-test-uninstall.log'
$process = Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$log`"") -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -ne 0) { throw "Uninstall failed: $($process.ExitCode)" }
if (Test-Path -LiteralPath (Join-Path $installDir 'clew.exe')) { throw 'Uninstall left the application executable behind' }
if (-not (Test-Path -LiteralPath (Join-Path $installDir 'clew.json'))) { throw 'Uninstall removed user configuration' }
Write-Host 'Install, upgrade, uninstall and configuration preservation passed.'
