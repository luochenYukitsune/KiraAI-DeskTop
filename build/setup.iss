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

; Architecture — app ships x64 only. Installing in 64-bit mode makes {pf}
; resolve to the real "C:\Program Files" so the Program Files guard below
; actually covers it (in 32-bit mode {pf} == {pf32} == Program Files (x86)).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

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
Name: "{autodesktop}\KiraAI 数据目录"; Filename: "{win}\explorer.exe"; Parameters: """{code:GetDataDir}"""; Tasks: datadesktopicon; Comment: "KiraAI Data Directory"

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

{ --- Enforce path validation for silent / command-line installs --- }
{ NextButtonClick never fires in /SILENT or /VERYSILENT mode, so re-run the
  checks here (which runs in both modes) for silent installs only — avoids
  double-prompting interactive users who already passed NextButtonClick. A
  non-empty Result aborts the install with that message. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardSilent and (not ValidateInstallPath(WizardDirValue)) then
    Result :=
      '安装路径无效：请使用纯英文、无空格、且不在 Program Files 下的路径（如 C:\KiraAI）。' + #13#10 +
      'Invalid installation path. Use an English-only, space-free path outside Program Files (e.g. C:\KiraAI).';
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

{ Scan one Uninstall registry root for an entry whose DisplayName matches the
  app AND that has an NSIS-style uninstaller on disk, returning its
  InstallLocation. electron-builder's NSIS target keys the uninstall entry by a
  GUID derived from appId — never the product name — so matching the subkey
  name directly never works; we match on DisplayName instead. The on-disk
  uninstaller check ensures we don't mistake a previous Inno install (same
  DisplayName, no such file) for a legacy NSIS one. }
function FindNsisInstallPath(RootKey: Integer): string;
var
  UninstallRoot: string;
  Names: TArrayOfString;
  I: Integer;
  DisplayName: string;
  InstallLocation: string;
begin
  Result := '';
  UninstallRoot := 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
  if not RegGetSubkeyNames(RootKey, UninstallRoot, Names) then
    Exit;
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    if RegQueryStringValue(RootKey, UninstallRoot + '\' + Names[I], 'DisplayName', DisplayName) and SameText(DisplayName, '{#MyAppName}') then
    begin
      if RegQueryStringValue(RootKey, UninstallRoot + '\' + Names[I], 'InstallLocation', InstallLocation) and (InstallLocation <> '') then
      begin
        if FileExists(InstallLocation + '\Uninstall {#MyAppName}.exe') or FileExists(InstallLocation + '\uninst.exe') then
        begin
          Result := InstallLocation;
          Exit;
        end;
      end;
    end;
  end;
end;

procedure MigrateFromNSIS();
var
  NsisInstallPath: string;
  MigrateResult: Integer;
begin
  { Look for an existing NSIS install across all registry roots/views.
    electron-builder NSIS was perMachine:false, so HKCU is the likely home. }
  NsisInstallPath := FindNsisInstallPath(HKLM64);
  if NsisInstallPath = '' then
    NsisInstallPath := FindNsisInstallPath(HKCU64);
  if NsisInstallPath = '' then
    NsisInstallPath := FindNsisInstallPath(HKLM);
  if NsisInstallPath = '' then
    NsisInstallPath := FindNsisInstallPath(HKCU);

  if (NsisInstallPath <> '') and (not SameText(NsisInstallPath, WizardDirValue)) then
  begin
    { Note: user data lives in %LOCALAPPDATA%\kiraAI-DeskTop and is untouched by
      the old uninstaller, so this is a "remove old version" step, not a config
      copy. }
    MigrateResult := SuppressibleMsgBox(
      '检测到旧版本 NSIS 安装于：' + #13#10 +
      NsisInstallPath + #13#10 + #13#10 +
      '是否要移除旧版本？' + #13#10 +
      '（你的聊天记录和设置保存在 %LOCALAPPDATA%\kiraAI-DeskTop，不会被改动）' + #13#10 + #13#10 +
      'Detected previous NSIS installation at:' + #13#10 +
      NsisInstallPath + #13#10 + #13#10 +
      'Remove the old version?' + #13#10 +
      '(Your chat history and settings in %LOCALAPPDATA%\kiraAI-DeskTop are left untouched)',
      mbConfirmation, MB_YESNO, IDYES);
    if MigrateResult = IDYES then
    begin
      { Run the NSIS uninstaller — try the primary name, then the fallback.
        FindNsisInstallPath already guaranteed one of these exists. }
      if FileExists(NsisInstallPath + '\Uninstall {#MyAppName}.exe') then
      begin
        if not Exec(RemoveQuotes(NsisInstallPath + '\Uninstall {#MyAppName}.exe'), '/S _?=' + NsisInstallPath, '', SW_HIDE, ewWaitUntilTerminated, MigrateResult) then
          SuppressibleMsgBox(
            '无法启动旧版本卸载程序。请手动卸载后再试。' + #13#10 +
            NsisInstallPath + '\Uninstall {#MyAppName}.exe' + #13#10 + #13#10 +
            'Could not launch the legacy uninstaller. Please uninstall manually.',
            mbError, MB_OK, IDOK);
      end
      else if FileExists(NsisInstallPath + '\uninst.exe') then
      begin
        if not Exec(RemoveQuotes(NsisInstallPath + '\uninst.exe'), '/S _?=' + NsisInstallPath, '', SW_HIDE, ewWaitUntilTerminated, MigrateResult) then
          SuppressibleMsgBox(
            '无法启动旧版本卸载程序。请手动卸载后再试。' + #13#10 +
            NsisInstallPath + '\uninst.exe' + #13#10 + #13#10 +
            'Could not launch the legacy uninstaller. Please uninstall manually.',
            mbError, MB_OK, IDOK);
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

function InitializeSetup(): Boolean;
var
  ExistingVersion: string;
begin
  Result := True;

  { 检测已安装版本，仅提示不比较。
    注意：注册表子键用 AppId 的单花括号字面量；不能用 {#SetupSetting("AppId")}，
    它会原样输出 AppId 指令里转义用的双花括号 {{...}，导致键名多一个花括号、永不匹配。 }
  if RegQueryStringValue(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{B2E8D9F1-3A4C-4F6E-9D7B-8C1A2E5F0D3B}_is1', 'DisplayVersion', ExistingVersion) then
  begin
    SuppressibleMsgBox(
      '检测到已安装版本 ' + ExistingVersion + '，将升级到 {#MyAppVersion}。' + #13#10 + #13#10 +
      '你的配置和数据将被保留。' + #13#10 + #13#10 +
      'Existing installation (' + ExistingVersion + ') detected.' + #13#10 +
      'Will upgrade to {#MyAppVersion}.' + #13#10 +
      'Your configuration and data will be preserved.',
      mbInformation, MB_OK, IDOK);
  end;
end;
