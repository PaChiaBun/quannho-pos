; Script đóng gói Inno Setup cho Quán Nhỏ POS
; Xem hướng dẫn tại: https://jrsoftware.org/ishelp/

#define MyAppName "Quán Nhỏ POS"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Quán Nhỏ"
#define MyAppURL "https://quannho.lpm.vn"
#define MyAppExeName "quannho_pos.exe"

[Setup]
; Ghi chú: AppId xác định duy nhất ứng dụng này. Không thay đổi giá trị này để các bản nâng cấp sau hoạt động đúng.
AppId={{9373D68A-1D4F-4CFD-85B9-DC49E10B3AF1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Nơi lưu tệp .exe sau khi build xong
OutputDir=..\release-builds
OutputBaseFilename=QuanNhoPOS-Setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; ExcludeSpecs: "{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Ghi chú: Không đưa các file tạm thời hoặc file không cần thiết vào đây.

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
