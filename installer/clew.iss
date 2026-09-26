#ifndef AppVersion
  #error AppVersion must be supplied by scripts/package-windows.ps1
#endif
#define Root ".."
#define Dependencies Root + "\build\installer-dependencies"

[Setup]
AppId={{B4030D7C-ED32-4DA1-936E-944411E77496}
AppName=Clew
AppVersion={#AppVersion}
AppPublisher=Clew contributors
AppPublisherURL=https://github.com/LeoooChen/clew-proxy
AppSupportURL=https://github.com/LeoooChen/clew-proxy/issues
AppUpdatesURL=https://github.com/LeoooChen/clew-proxy/releases
DefaultDirName={autopf}\Clew
DefaultGroupName=Clew
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.19041
PrivilegesRequired=admin
OutputDir={#Root}\build\installer
OutputBaseFilename=clew-{#AppVersion}-windows-x64-setup
SetupIconFile={#Root}\assets\clew.ico
UninstallDisplayIcon={app}\clew.exe
LicenseFile={#Root}\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
AppMutex=Global\Clew_SingleInstance
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[CustomMessages]
english.PrerequisiteError=Could not install %1 (error %2). Check your Internet connection and retry.
chinesesimp.PrerequisiteError=无法安装 %1（错误 %2）。请检查网络连接后重试。
english.PrerequisiteInfo=Setup installs Microsoft Visual C++ and WebView2 runtimes if needed. An Internet connection is required if WebView2 is missing.
chinesesimp.PrerequisiteInfo=安装程序会按需安装 Microsoft Visual C++ 和 WebView2 运行库。如果未安装 WebView2，需要连接互联网。

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Root}\build\Release\clew.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\build\Release\WinDivert.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\build\Release\WinDivert64.sys"; DestDir: "{app}"; Flags: ignoreversion restartreplace uninsrestartdelete
Source: "{#Root}\build\Release\brotli*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\frontend\dist\*"; DestDir: "{app}\frontend\dist"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Root}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\README*.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\WinDivert-2.2.2-A\LICENSE"; DestDir: "{app}\licenses"; DestName: "WinDivert.txt"; Flags: ignoreversion
Source: "{#Root}\src\ui\third_party\WebView2\LICENSE.txt"; DestDir: "{app}\licenses"; DestName: "WebView2.txt"; Flags: ignoreversion
Source: "{#Root}\src\ui\third_party\WebView2\NOTICE.txt"; DestDir: "{app}\licenses"; DestName: "WebView2-NOTICE.txt"; Flags: ignoreversion
Source: "{#Dependencies}\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "{#Dependencies}\vc_redist.x64.exe"; Flags: dontcopy
Source: "{#Dependencies}\MicrosoftEdgeWebview2Setup.exe"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\Clew"; Filename: "{app}\clew.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Clew"; Filename: "{app}\clew.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
function HasWebView2: Boolean;
var Version: String;
begin
  Result := RegQueryStringValue(HKLM32, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version);
  Result := Result and (Version <> '') and (Version <> '0.0.0.0');
  if not Result then begin
    Result := RegQueryStringValue(HKCU, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version);
    Result := Result and (Version <> '') and (Version <> '0.0.0.0');
  end;
end;

function HasVCRuntime: Boolean;
var Major, Minor, Build, Installed: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM64, 'Software\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed);
  Result := Result and (Installed = 1);
  if Result then begin
    Result := RegQueryDWordValue(HKLM64, 'Software\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Major', Major) and
      RegQueryDWordValue(HKLM64, 'Software\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Minor', Minor) and
      RegQueryDWordValue(HKLM64, 'Software\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Bld', Build);
    Result := Result and ((Major > 14) or ((Major = 14) and ((Minor > 44) or ((Minor = 44) and (Build >= 35207)))));
  end;
end;

procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption := WizardForm.WelcomeLabel2.Caption + #13#10#13#10 + CustomMessage('PrerequisiteInfo');
end;

function InstallPrerequisite(FileName, Parameters: String; var NeedsRestart: Boolean): String;
var Code: Integer;
begin
  Result := '';
  ExtractTemporaryFile(FileName);
  if not Exec(ExpandConstant('{tmp}\') + FileName, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := FmtMessage(CustomMessage('PrerequisiteError'), [FileName, IntToStr(Code)])
  else if Code = 3010 then NeedsRestart := True
  else if Code <> 0 then Result := FmtMessage(CustomMessage('PrerequisiteError'), [FileName, IntToStr(Code)]);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not HasVCRuntime then
    Result := InstallPrerequisite('vc_redist.x64.exe', '/install /quiet /norestart', NeedsRestart);
  if (Result = '') and not HasWebView2 then
    Result := InstallPrerequisite('MicrosoftEdgeWebview2Setup.exe', '/silent /install', NeedsRestart);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Scheduler, Folder, Task: Variant;
begin
  if CurUninstallStep = usUninstall then begin
    // Remove autostart only when it belongs to this installation. Keep user data.
    try
      Scheduler := CreateOleObject('Schedule.Service');
      Scheduler.Connect;
      Folder := Scheduler.GetFolder('\');
      Task := Folder.GetTask('ClewAutoStart');
      if CompareText(Task.Definition.Actions.Item(1).Path, ExpandConstant('{app}\clew.exe')) = 0 then
        Folder.DeleteTask('ClewAutoStart', 0);
    except
      Log('No matching ClewAutoStart task to remove: ' + GetExceptionMessage);
    end;
  end;
end;
