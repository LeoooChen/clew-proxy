# Run from the repository root. Downloads stay in the ignored build directory.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $root 'build/dependencies'
New-Item -ItemType Directory -Force $cache | Out-Null
if (-not (Test-Path (Join-Path $root 'WinDivert-2.2.2-A/x64/WinDivert.lib'))) {
    $zip = Join-Path $cache 'WinDivert-2.2.2-A.zip'
    Invoke-WebRequest 'https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip' -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne '63CB41763BB4B20F600B6DE04E991A9C2BE73279E317D4D82F237B150C5F3F15') {
        throw 'WinDivert checksum mismatch'
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $cache -Force
    Copy-Item -LiteralPath (Join-Path $cache 'WinDivert-2.2.2-A/x64') -Destination (Join-Path $root 'WinDivert-2.2.2-A/x64') -Recurse -Force
}
# Git ignores every build/ directory, including the SDK headers. Restore both
# headers and loaders from the checked-in NuGet archive on fresh checkouts.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $root 'src/ui/third_party/webview2.nupkg'))
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '^build/native/(include/[^/]+\.h|(x64|x86|arm64)/WebView2Loader(Static\.lib|\.dll|\.dll\.lib))$') {
            $dest = Join-Path $root ('src/ui/third_party/WebView2/' + $entry.FullName)
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        }
    }
} finally { $archive.Dispose() }
foreach ($required in @('include/WebView2.h', 'x64/WebView2LoaderStatic.lib')) {
    if (-not (Test-Path (Join-Path $root "src/ui/third_party/WebView2/build/native/$required"))) {
        throw "WebView2 SDK extraction incomplete: $required"
    }
}
