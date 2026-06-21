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
Source: "..\build\windows\x64\runner\Release\*"; Excludes: "{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Ghi chú: Không đưa các file tạm thời hoặc file không cần thiết vào đây.

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Cài đặt VC++ Runtime nếu chưa có trước khi khởi chạy ứng dụng
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: VCRedistNeedsInstall; StatusMsg: "Đang cài đặt thư viện Microsoft Visual C++ Redistributable (x64)..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Hàm kiểm tra máy tính đã cài đặt VC++ 2015-2022 Redistributable (x64) chưa
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
  RegKey: String;
begin
  Result := True;
  RegKey := 'SOFTWARE\Microsoft\DevDiv\vc\Servicing\14.0\RuntimeMinimum';
  
  // Kiểm tra key Registry của VC++ Runtime
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, RegKey, 'Version', Version) then
  begin
    // Nếu phiên bản đã cài lớn hơn hoặc bằng 14.0.23026 (VC++ 2015) thì không cần cài thêm
    if CompareStr(Version, '14.0.23026') >= 0 then
    begin
      Result := False;
    end;
  end;
end;

// Sự kiện tải các thư viện bổ sung trước khi cài đặt
procedure InitializeWizard;
var
  DownloadPage: TDownloadWizardPage;
begin
  if VCRedistNeedsInstall then
  begin
    DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), 'Ứng dụng cần tải và cài đặt thư viện bổ sung từ Microsoft để hoạt động.', @InitializeWizard);
    DownloadPage.Clear;
    // Tải trực tiếp file redistributable từ link chính thức của Microsoft vào thư mục tạm {tmp}
    DownloadPage.Add('https://aka.ms/vs/17/release/vc_redist.x64.exe', 'vc_redist.x64.exe', '');
    DownloadPage.Show;
    try
      DownloadPage.Download;
    finally
      DownloadPage.Hide;
    end;
  end;
end;

