# Fork development workflow

This fork preserves the upstream MIT license and attribution. `origin` is
`LeoooChen/clew-proxy`; `upstream` is `ymonster/clew-proxy`.

1. Fetch `upstream` and review incoming changes before updating your fork's `main`.
2. Create a `codex/<feature>` branch from the chosen base.
3. Make focused commits, build, and run the relevant tests.
4. Push the feature branch to `origin` and open a PR **against your fork's main**.
5. Review the diff and CI results before merging. Publish a release separately.
   Propose changes to upstream through a separate PR when you choose to contribute.

## Build from a fresh Windows checkout

Requirements: Visual Studio 2022 C++ build tools and Windows SDK, CMake, Node.js 24,
vcpkg and the WebView2 runtime. Use a VS developer shell. The CI workflow pins the
vcpkg ports revision to `617ef1c0c422737d117eda00a471ea1be5bad088`.

```powershell
# Set VCPKG_ROOT to your vcpkg installation first.
& "$env:VCPKG_ROOT/vcpkg.exe" install quill nlohmann-json cpp-httplib asio --triplet x64-windows
./scripts/bootstrap-windows.ps1
cmake --preset windows-vcpkg
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
cd frontend
npm ci
npm run build
npx playwright install chromium
npm test -- --workers=2
```

`bootstrap-windows.ps1` restores WinDivert binaries from the official release
with SHA-256 verification and extracts WebView2 headers and loaders from the checked-in
NuGet archive. It does not replace tracked SDK source files. Run CMake before
building the frontend because it generates `frontend/src/version.ts`.

The native UI regression executable does not load WinDivert or require elevation.
It checks the embedded PerMonitorV2 manifest, config compatibility, initial window
scaling, work-area clamping, the DPI-change suggested rectangle, minimum dimensions
and logical-size persistence. Browser tests mock the backend, so they cannot change
system DNS, proxies, rules or autostart settings.

## Language and DPI behavior

Settings → Language offers Follow system, 简体中文 and English. The choice is
stored in `clew.json` under `ui.language`; older configs default to `system`.
Changing language refreshes the web UI (including Monaco's built-in labels), returns
to Settings, and leaves the proxy engine running. Unsaved JSON edits require an
explicit discard confirmation. Chinese UI strings live in
`frontend/src/i18n/zh-CN.json`; English source strings are the fallback keys.
Process names, addresses, config property names and diagnostic details are data,
not translated labels. System file dialogs use the Windows display language.

The executable declares PerMonitorV2 DPI awareness. WebView2 renders at the monitor's
native DPI without CSS zoom or a forced browser scale. Window width/height are stored
in 96-DPI logical pixels; position is stored in desktop pixels. Negative monitor
coordinates are supported and stale/off-screen positions are clamped to the work
area. Process icons now retain 32 source pixels for a 16-CSS-pixel display at 200%.

For physical-monitor acceptance, launch at 100%, 125%, 150% and 200%; drag between
monitors with different scaling; change Windows scaling while running; then check
text, icons, resize edges, maximize/restore, tray restore and restart geometry.
Browser device-scale tests and a synthetic WM_DPICHANGED test do not replace this
physical multi-monitor check.

## Windows installer releases

CI restores the ignored WebView2 `build/native` headers as well as loader binaries;
missing SDK components fail during CMake configuration. Every PR builds an Inno
Setup EXE and tests install, upgrade and uninstall in a Chinese path on a disposable
runner, including preservation of user configuration. These tests never start the
proxy engine. Preview installers use version `0.0.0`.

To package locally after building, set `VCPKG_ROOT` and run
`./scripts/package-windows.ps1 -Version 0.10.1`. The script downloads a SHA-256-pinned
Inno Setup 6.4.3 compiler and verifies Microsoft's signatures on runtime installers.
Output is `build/installer/clew-0.10.1-windows-x64-setup.exe`. Installer translation
comes from Inno Setup's `is-6_4_3/Files/Languages/Unofficial/ChineseSimplified.isl`;
its original translator credits are retained.

After reviewing the branch and checking CI, run `python scripts/release.py v0.10.1`
(`--dry-run` previews repository, commit and tag). This pushes to **origin**, without
hard-coding the upstream repository. A `vMAJOR.MINOR.PATCH` tag triggers the full
Windows pipeline; only after all tests pass does the separate release job upload
the EXE to that repository. No application ZIP is published. GitHub's automatic
source-code archives are not application packages. Application and installer
executables are currently unsigned.

The installer requires x64 Windows 10 2004+ and admin rights. It includes the C++
redistributable and the WebView2 bootstrapper (Internet required if WebView2 is
missing), dependency licenses, shortcuts, and an uninstaller. Exit Clew before
upgrading/uninstalling. User data is retained; an autostart task is removed only if
its executable belongs to this installation.

DPI implementation references: [Microsoft WM_DPICHANGED](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged)
and [WebView2 controller scaling](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2controller3).
