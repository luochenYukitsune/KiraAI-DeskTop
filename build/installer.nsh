!macro customHeader
  RequestExecutionLevel admin
!macroend

; --- Force per-user install mode, skip "Install for all users" page ---
!macro customInstallMode
  StrCpy $isForceCurrentInstall "1"
!macroend

; --- Path validation before installation ---
!macro customInit
  Push $0
  Push $1

  ; 1) Check for spaces in the install path
  StrCpy $0 "$INSTDIR"
  _check_space_loop:
    StrCpy $1 $0 1
    StrCmp $1 "" _check_space_done
    StrCmp $1 " " _check_space_fail
    StrCpy $0 $0 "" 1
    Goto _check_space_loop
  _check_space_fail:
    MessageBox MB_OK|MB_ICONSTOP "安装路径不能包含空格，请选择其他路径（如 C:\KiraAI）。$\n$\nInstallation path cannot contain spaces. Choose a simple path like C:\KiraAI."
    Abort
  _check_space_done:

  ; 2) Reject Program Files directory
  StrLen $0 "$PROGRAMFILES"
  StrCpy $1 "$INSTDIR" $0
  StrCmp $1 "$PROGRAMFILES" _check_pf_fail
  StrLen $0 "$PROGRAMFILES(x86)"
  StrCpy $1 "$INSTDIR" $0
  StrCmp $1 "$PROGRAMFILES(x86)" _check_pf_fail _check_pf_done
  _check_pf_fail:
    MessageBox MB_OK|MB_ICONSTOP "请不要安装到 Program Files 目录，这可能导致权限问题。$\n建议使用 C:\KiraAI 之类的路径。$\n$\nDo not install into Program Files.$\nUse a path like C:\KiraAI instead."
    Abort
  _check_pf_done:

  ; 3) Advisory warning about non-ASCII characters
  ;    Show a confirmation dialog reminding users to use English-only paths.
  ;    This covers Chinese, Japanese, Korean, and other non-ASCII characters.
  MessageBox MB_YESNO|MB_ICONINFORMATION "提示：安装路径请使用纯英文、无空格的路径（如 C:\KiraAI）。$\n包含中文或特殊字符可能导致程序无法正常启动。$\n$\nTip: Use an English-only path without spaces (e.g. C:\KiraAI).$\nPaths with Chinese or special characters may cause startup failures.$\n$\n确认路径无误，继续安装？ Continue?" IDYES _check_ascii_done
  Abort
  _check_ascii_done:

  Pop $1
  Pop $0
!macroend

; --- Post-install: create data directory shortcut on desktop ---
!macro customInstall
  DetailPrint "Installing kiraAI-DeskTop..."

  ; Create a desktop shortcut to the data directory
  ; In per-user install, data dir is at %LOCALAPPDATA%\kiraAI-DeskTop
  Push $0
  Push $1

  ReadEnvStr $0 "LOCALAPPDATA"
  StrCmp $0 "" _skip_data_shortcut
  StrCpy $1 "$0\kiraAI-DeskTop"

  ; Ensure the data directory exists
  CreateDirectory "$1"

  ; Create a .url shortcut on desktop pointing to the data folder
  ; file:/// requires three slashes and forward slashes for Windows .url files
  ; NSIS doesn't have a built-in backslash-to-forward-slash, so we use the
  ; Windows shell to resolve the path via ExpandEnvironmentStrings
  WriteIniStr "$DESKTOP\KiraAI 数据目录.url" "InternetShortcut" "URL" "file:///$1"
  WriteIniStr "$DESKTOP\KiraAI 数据目录.url" "InternetShortcut" "IconFile" "$INSTDIR\kiraAI-DeskTop.exe"
  WriteIniStr "$DESKTOP\KiraAI 数据目录.url" "InternetShortcut" "IconIndex" "0"
  DetailPrint "Created desktop shortcut: KiraAI 数据目录 -> $1"

  _skip_data_shortcut:
  Pop $1
  Pop $0
!macroend

; --- Uninstall: clean up data directory shortcut ---
!macro customUnInstall
  DetailPrint "Uninstalling kiraAI-DeskTop..."
  Delete "$DESKTOP\KiraAI 数据目录.url"
  DetailPrint "Removed desktop shortcut: KiraAI 数据目录"
!macroend
