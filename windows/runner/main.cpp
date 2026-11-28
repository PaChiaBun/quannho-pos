#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Two running copies are two print servers with separate "already printed"
// caches, so every kitchen ticket prints twice.
bool IsAnotherInstanceRunning() {
  // Held until the process exits; Windows releases it even after a crash.
  // If it cannot be created, keep starting: a shop without printing is worse.
  HANDLE mutex =
      ::CreateMutexW(nullptr, FALSE, L"Local\\QuanNhoPOS_SingleInstance");
  return mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS;
}

void ShowRunningInstance() {
  // The first copy may still be creating its window (double-click on the icon).
  for (int i = 0; i < 30; i++) {
    HWND window =
        ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"quannho_pos");
    if (window != nullptr) {
      if (::IsIconic(window)) {
        ::ShowWindow(window, SW_RESTORE);
      }
      ::SetForegroundWindow(window);
      return;
    }
    ::Sleep(100);
  }
  // A copy stuck in the background has no window; tell staff instead of
  // silently doing nothing. Escapes keep this file ASCII (MSVC /WX, C4819).
  ::MessageBoxW(
      nullptr,
      L"Qu\u00E1n Nh\u1ECF POS \u0111ang ch\u1EA1y ng\u1EA7m nh\u01B0ng "
      L"kh\u00F4ng hi\u1EC7n c\u1EEDa s\u1ED5.\n"
      L"H\u00E3y kh\u1EDFi \u0111\u1ED9ng l\u1EA1i m\u00E1y t\u00EDnh "
      L"r\u1ED3i m\u1EDF l\u1EA1i app.",
      L"Qu\u00E1n Nh\u1ECF POS", MB_OK | MB_ICONWARNING);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (IsAnotherInstanceRunning()) {
    ShowRunningInstance();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"quannho_pos", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
