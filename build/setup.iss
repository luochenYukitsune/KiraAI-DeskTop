; Inno Setup Script for kiraAI-DeskTop
; Replaces legacy NSIS installer (build/installer.nsh)
;
; Build flow:
;   1. electron-builder --win --dir   (produces app in dist\win-x64-unpacked\)
;   2. iscc build\setup.iss           (produces installer in dist\)
;   Combined: npm run build:win
;
; Inno Setup 6+ required. Install via:
;   winget install InnoSetup
;   choco install innosetup

#define MyAppName "kiraAI-DeskTop"
; Version — override at compile time: iscc /dMyAppVersion=X.Y.Z build\setup.iss
#ifndef MyAppVersion
  #define MyAppVersion "2.17.0"
#endif
#define MyAppPublisher "KiraAI Team"
#define MyAppURL "https://github.com/xxynet/KiraAI"
#define MyAppExeName "kiraAI-DeskTop.exe"

; electron-builder --dir output path (varies by electron-builder version)
#ifndef ElectronBuilderOutDir
  #define ElectronBuilderOutDir "..\dist\win-unpacked"
#endif

[Setup]
; Identity
AppId={{B2E8D9F1-3A4C-4F6E-9D7B-8C1A2E5F0D3B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppVerName={#MyAppName} {#MyAppVersion}

; Install directory — avoid Program Files per NSIS legacy behavior
DefaultDirName=C:\{#MyAppName}
DisableDirPage=no
DirExistsWarning=no

; Start Menu
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output
OutputDir=..\dist
OutputBaseFilename=kiraAI-DeskTop Setup {#MyAppVersion}
SetupIconFile=..\assets\KD-LOGO.ico

; Compression
Compression=lzma2/max
SolidCompression=yes
InternalCompressLevel=max

; UI
WizardStyle=modern
DisableWelcomePage=no

; Privileges: require admin to write to C:\ and create all-users Start Menu
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline

; Uninstall
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Version handling — auto-detect previous install for upgrades
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousSetupType=yes
UsePreviousTasks=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "zh"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "Create desktop shortcut"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkablealone
Name: "datadesktopicon"; Description: "Create data directory shortcut on desktop"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ElectronBuilderOutDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs uninsremovereadonly

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autodesktop}\KiraAI 数据目录"; Filename: "{win}\explorer.exe"; Parameters: "{code:GetDataDir}"; Tasks: datadesktopicon; Comment: "KiraAI Data Directory"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent unchecked

[UninstallRun]
; 卸载前强制关闭正在运行的程序
Filename: "taskkill"; Parameters: "/F /IM kiraAI-DeskTop.exe"; Flags: runhidden; RunOnceId: KillApp

; ---------------------------------------------------------------------------
; [Code] — Pascal logic for path validation, data dir, and NSIS migration
; ---------------------------------------------------------------------------
[Code]

{ --- Path validation helpers --- }

function HasSpaces(const S: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = ' ' then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function IsProgramFiles(const Path: string): Boolean;
var
  Normalized: string;
  Pf, Pf86: string;
  PfLen, Pf86Len: Integer;
begin
  Result := False;
  Normalized := LowerCase(Path);
  Pf := LowerCase(ExpandConstant('{pf}'));
  Pf86 := LowerCase(ExpandConstant('{pf32}'));
  PfLen := Length(Pf);
  Pf86Len := Length(Pf86);

  { Check {pf}: must be at start, followed by '\' or end-of-string }
  if (Pos(Pf, Normalized) = 1) then
  begin
    if (Length(Normalized) = PfLen) or (Normalized[PfLen + 1] = '\') then
    begin
      Result := True;
      Exit;
    end;
  end;

  { Check {pf32}: same boundary logic }
  if (Pos(Pf86, Normalized) = 1) then
  begin
    if (Length(Normalized) = Pf86Len) or (Normalized[Pf86Len + 1] = '\') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function ContainsNonASCII(const S: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
  begin
    if Ord(S[I]) > 127 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ --- Data directory path (exposed to [Icons] via {code:GetDataDir}) --- }

function GetDataDir(Param: string): string;
begin
  Result := ExpandConstant('{localappdata}') + '\{#MyAppName}';
end;

{ --- Install path validation (runs on "Next" click from directory page) --- }

function ValidateInstallPath(const Path: string): Boolean;
begin
  Result := True;

  { 1) Reject spaces in path (matches NSIS customInit behavior) }
  if HasSpaces(Path) then
  begin
    SuppressibleMsgBox(
      '安装路径不能包含空格，请选择其他路径（如 C:\KiraAI）。' + #13#10 + #13#10 +
      'Installation path cannot contain spaces. Choose a simple path like C:\KiraAI.',
      mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;

  { 2) Reject Program Files directories (matches NSIS customInit behavior) }
  if IsProgramFiles(Path) then
  begin
    SuppressibleMsgBox(
      '请不要安装到 Program Files 目录，这可能导致权限问题。' + #13#10 +
      '建议使用 C:\KiraAI 之类的路径。' + #13#10 + #13#10 +
      'Do not install into Program Files.' + #13#10 +
      'Use a path like C:\KiraAI instead.',
      mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;

  { 3) Warn about non-ASCII characters (matches NSIS customInit behavior) }
  if ContainsNonASCII(Path) then
  begin
    Result := SuppressibleMsgBox(
      '提示：安装路径请使用纯英文、无空格的路径（如 C:\KiraAI）。' + #13#10 +
      '包含中文或特殊字符可能导致程序无法正常启动。' + #13#10 + #13#10 +
      'Tip: Use an English-only path without spaces (e.g. C:\KiraAI).' + #13#10 +
      'Paths with Chinese or special characters may cause startup failures.' + #13#10 + #13#10 +
      '确认路径无误，继续安装？ Continue?',
      mbConfirmation, MB_YESNO, IDYES) = IDYES;
    if not Result then
      Exit;
  end;
end;

{ --- Called when user clicks Next on any wizard page --- }

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    Result := ValidateInstallPath(WizardDirValue);
  end;
end;

{ --- Post-install: create data directory --- }

procedure CreateDataDir();
var
  DataPath: string;
begin
  DataPath := GetDataDir('');
  if not DirExists(DataPath) then
  begin
    ForceDirectories(DataPath);
  end;
end;

{ --- Migrate configuration from NSIS installation --- }

procedure MigrateFromNSIS();
var
  NsisUninstallPath: string;
  NsisInstallPath: string;
  OldDataDir: string;
  NewDataDir: string;
  OldWebuiJson: string;
  NewWebuiJson: string;
  MigrateResult: Integer;
begin
  { Check for NSIS uninstaller in all registry views (64-bit + 32-bit) }
  NsisInstallPath := '';
  if RegQueryStringValue(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}', 'InstallLocation', NsisInstallPath) then
  begin
    { Found NSIS install in HKLM 64-bit }
  end
  else if RegQueryStringValue(HKCU64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}', 'InstallLocation', NsisInstallPath) then
  begin
    { Found NSIS install in HKCU 64-bit }
  end
  else if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}', 'InstallLocation', NsisInstallPath) then
  begin
    { Found NSIS install in HKLM 32-bit view }
  end
  else if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}', 'InstallLocation', NsisInstallPath) then
  begin
    { Found NSIS install in HKCU 32-bit view }
  end
  else if RegQueryStringValue(HKLM64, 'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}', 'InstallLocation', NsisInstallPath) then
  begin
    { Found NSIS install in Wow6432Node fallback }
  end;

  if NsisInstallPath <> '' then
  begin
    { Check if NSIS install is different from current install }
    if not SameText(NsisInstallPath, WizardDirValue) then
    begin
      MigrateResult := SuppressibleMsgBox(
        '检测到旧版本 NSIS 安装于：' + #13#10 +
        NsisInstallPath + #13#10 + #13#10 +
        '是否要迁移配置并移除旧版本？' + #13#10 +
        '（你的聊天记录和设置将保留在 %LOCALAPPDATA%\kiraAI-DeskTop）' + #13#10 + #13#10 +
        'Detected previous NSIS installation at:' + #13#10 +
        NsisInstallPath + #13#10 + #13#10 +
        'Migrate config and remove old version?' + #13#10 +
        '(Your chat history and settings in %LOCALAPPDATA%\kiraAI-DeskTop will be preserved)',
        mbConfirmation, MB_YESNO, IDYES);
      if MigrateResult = IDYES then
      begin
        { Attempt to run the NSIS uninstaller — try primary name first }
        if FileExists(NsisInstallPath + '\Uninstall {#MyAppName}.exe') then
        begin
          if not Exec(RemoveQuotes(NsisInstallPath + '\Uninstall {#MyAppName}.exe'), '/S _?=' + NsisInstallPath, '', SW_HIDE, ewWaitUntilTerminated, MigrateResult) then
          begin
            SuppressibleMsgBox(
              '无法启动旧版本卸载程序。请手动卸载后再试。' + #13#10 +
              NsisInstallPath + '\Uninstall {#MyAppName}.exe' + #13#10 + #13#10 +
              'Could not launch the legacy uninstaller. Please uninstall manually.',
              mbError, MB_OK, IDOK);
          end;
        end
        { Fallback: try alternative NSIS uninstaller naming }
        else if FileExists(NsisInstallPath + '\uninst.exe') then
        begin
          if not Exec(RemoveQuotes(NsisInstallPath + '\uninst.exe'), '/S _?=' + NsisInstallPath, '', SW_HIDE, ewWaitUntilTerminated, MigrateResult) then
          begin
            SuppressibleMsgBox(
              '无法启动旧版本卸载程序。请手动卸载后再试。' + #13#10 +
              NsisInstallPath + '\uninst.exe' + #13#10 + #13#10 +
              'Could not launch the legacy uninstaller. Please uninstall manually.',
              mbError, MB_OK, IDOK);
          end;
        end
        else
        begin
          SuppressibleMsgBox(
            '未找到旧版本卸载程序，将继续安装。' + #13#10 +
            'If the old version still exists, please uninstall it manually.' + #13#10 +
            NsisInstallPath,
            mbInformation, MB_OK, IDOK);
        end;
      end;
    end;
  end;
end;

{ --- Wizard lifecycle hooks --- }

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    { Pre-install: migrate from NSIS before writing new files }
    MigrateFromNSIS();
  end;
  if CurStep = ssPostInstall then
  begin
    { Post-install: ensure data directory exists }
    CreateDataDir();
  end;
end;

{ --- Uninstall: offer to preserve or clean user data --- }

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataPath: string;
  CleanResult: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataPath := GetDataDir('');
    if DirExists(DataPath) then
    begin
      CleanResult := SuppressibleMsgBox(
        '是否同时删除用户数据目录？' + #13#10 +
        DataPath + #13#10 + #13#10 +
        '如果计划重新安装，建议保留。' + #13#10 +
        '如果不再使用，可以选择删除。' + #13#10 + #13#10 +
        'Also delete user data directory?' + #13#10 +
        DataPath + #13#10 + #13#10 +
        'Keep if you plan to reinstall. Delete if you no longer need it.',
        mbConfirmation, MB_YESNO, IDNO);
      if CleanResult = IDYES then
      begin
        DelTree(DataPath, True, True, True);
      end;
    end;
  end;
end;

{ --- Pre-install validation (early abort, before wizard pages) --- }

{ CompareVersion helper — 逐段数字比较，不依赖 packed version 类型 }
function CompareVersion(const Version1, Version2: string): Integer;
var
  V1, V2: string;
  P1, P2: Integer;
  Num1, Num2: Integer;
begin
  Result := 0;
  V1 := Version1;
  V2 := Version2;

  while (Result = 0) and ((V1 <> '') or (V2 <> '')) do
  begin
    { 获取 V1 的第一段 }
    P1 := Pos('.', V1);
    if P1 = 0 then
    begin
      if V1 <> '' then
      begin
        Num1 := StrToIntDef(V1, 0);
        V1 := '';
      end
      else
        Num1 := 0;
    end
    else
    begin
      Num1 := StrToIntDef(Copy(V1, 1, P1 - 1), 0);
      Delete(V1, 1, P1);
    end;

    { 获取 V2 的第一段 }
    P2 := Pos('.', V2);
    if P2 = 0 then
    begin
      if V2 <> '' then
      begin
        Num2 := StrToIntDef(V2, 0);
        V2 := '';
      end
      else
        Num2 := 0;
    end
    else
    begin
      Num2 := StrToIntDef(Copy(V2, 1, P2 - 1), 0);
      Delete(V2, 1, P2);
    end;

    if Num1 > Num2 then
      Result := 1
    else if Num1 < Num2 then
      Result := -1;
  end;
end;

function InitializeSetup(): Boolean;
var
  ExistingVersion: string;
  CurrentVersion: string;
  UpgradeResult: Integer;
begin
  Result := True;

  { Detect existing Inno Setup installation and warn about upgrade }
  CurrentVersion := '{#MyAppVersion}';
  if RegQueryStringValue(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#emit SetupSetting("AppId")}_is1', 'DisplayVersion', ExistingVersion) then
  begin
    if CompareVersion(ExistingVersion, CurrentVersion) < 0 then
    begin
      UpgradeResult := SuppressibleMsgBox(
        '检测到旧版本 (' + ExistingVersion + ')，将升级到 ' + CurrentVersion + '。' + #13#10 + #13#10 +
        '你的配置和数据将被保留。' + #13#10 + #13#10 +
        'Existing installation (' + ExistingVersion + ') detected.' + #13#10 +
        'Will upgrade to ' + CurrentVersion + '.' + #13#10 +
        'Your configuration and data will be preserved.',
        mbInformation, MB_OK, IDOK);
    end;
  end;
end;
