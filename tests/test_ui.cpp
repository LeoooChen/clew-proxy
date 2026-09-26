// Native UI regression tests: no driver, elevation or proxy server needed.
#include "config/types.hpp"
#include "ui/webview_app.hpp"
#include <iostream>
#include <stdexcept>

static void check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    try {
        check(AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),
              DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2), "PerMonitorV2 manifest missing");
        auto legacy = nlohmann::json::object().get<clew::UiConfig>();
        check(legacy.language == "system", "old configs must follow the system language");
        legacy.language = "zh-CN";
        auto restored = nlohmann::json(legacy).get<clew::UiConfig>();
        check(restored.language == "zh-CN", "language must survive config serialization");

        quill::Backend::start();
        clew::g_logger = quill::Frontend::create_or_get_logger("ui-test",
            quill::Frontend::create_or_get_sink<quill::ConsoleSink>("console"));
        clew::webview_app app(L"about:blank", 1000, 650);
        app.set_start_minimized(true);
        app.set_initial_rect(-100000, -100000, 1000, 650);
        check(app.create(GetModuleHandleW(nullptr)), "window creation failed");
        const auto hwnd = app.get_hwnd();
        const auto dpi = GetDpiForWindow(hwnd);
        MONITORINFO mi{sizeof(mi)};
        GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi);
        RECT rect{};
        GetWindowRect(hwnd, &rect);
        check(rect.left >= mi.rcWork.left && rect.top >= mi.rcWork.top &&
              rect.right <= mi.rcWork.right && rect.bottom <= mi.rcWork.bottom,
              "restored window must fit the current work area");
        check(rect.right - rect.left == std::min(MulDiv(1000, dpi, 96),
              static_cast<int>(mi.rcWork.right - mi.rcWork.left)), "initial DIP scaling incorrect");

        MINMAXINFO sizes{};
        SendMessageW(hwnd, WM_GETMINMAXINFO, 0, reinterpret_cast<LPARAM>(&sizes));
        check(sizes.ptMinTrackSize.x == std::min(static_cast<LONG>(MulDiv(900, dpi, 96)),
              mi.rcWork.right - mi.rcWork.left), "minimum size must scale with DPI");

        RECT suggested = rect;
        suggested.right -= 10;
        SendMessageW(hwnd, WM_DPICHANGED, MAKELONG(dpi, dpi), reinterpret_cast<LPARAM>(&suggested));
        GetWindowRect(hwnd, &rect);
        check(EqualRect(&suggested, &rect), "WM_DPICHANGED must use the suggested rectangle");
        bool persisted = false;
        app.set_on_move_resize([&](int x, int y, int w, int h) {
            persisted = x == rect.left && y == rect.top &&
                w == MulDiv(rect.right - rect.left, 96, dpi) &&
                h == MulDiv(rect.bottom - rect.top, 96, dpi);
        });
        SendMessageW(hwnd, WM_EXITSIZEMOVE, 0, 0);
        check(persisted, "saved dimensions must be DIPs");
        std::cout << "UI config and native DPI checks passed at " << dpi << " DPI\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
