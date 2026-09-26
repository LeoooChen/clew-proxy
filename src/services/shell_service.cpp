#include "services/shell_service.hpp"

#include <string>
#include <iterator>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>

#include "common/api_exception.hpp"

namespace clew {

nlohmann::json shell_service::browse_exe() {
    wchar_t file_path[32768] = {0};
    OPENFILENAMEW ofn = {};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner   = nullptr;
    // Neutral file patterns; Windows supplies localized dialog controls.
    ofn.lpstrFilter = L"*.exe\0*.exe\0*.*\0*.*\0";
    ofn.lpstrFile   = file_path;
    ofn.nMaxFile    = static_cast<DWORD>(std::size(file_path));
    ofn.Flags       = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;

    if (!GetOpenFileNameW(&ofn)) {
        nlohmann::json j;
        j["cancelled"] = true;
        return j;
    }

    const int length = static_cast<int>(wcslen(file_path));
    const int size = WideCharToMultiByte(CP_UTF8, 0, file_path, length, nullptr, 0, nullptr, nullptr);
    std::string full(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, file_path, length, full.data(), size, nullptr, nullptr);
    std::string dir;
    std::string name;
    if (auto last_sep = full.find_last_of("\\/"); last_sep != std::string::npos) {
        dir  = full.substr(0, last_sep + 1);
        name = full.substr(last_sep + 1);
    } else {
        name = full;
    }

    nlohmann::json j;
    j["path"] = full;
    j["dir"]  = dir;
    j["name"] = name;
    return j;
}

void shell_service::reveal(std::string_view path) {
    if (path.empty()) {
        throw api_exception{api_error::invalid_argument, "path is required"};
    }

    std::string utf8{path};
    int needed = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    if (needed <= 0) {
        throw api_exception{api_error::invalid_argument, "invalid UTF-8 path"};
    }
    std::wstring wpath(static_cast<std::size_t>(needed) - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wpath.data(), needed);

    std::wstring wcmd = L"/select,\"" + wpath + L"\"";
    ShellExecuteW(nullptr, L"open", L"explorer.exe", wcmd.c_str(), nullptr, SW_SHOWNORMAL);
}

} // namespace clew
