; Inno Setup script for Habit Tracker. Built by build.ps1, which passes /DAppVersion.
; Installs per-user by default (no admin rights needed); the user can choose all-users.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "Habit Tracker"
#define AppExe "HabitTracker.exe"

[Setup]
AppId={{8F3C2A51-6B7E-4D2A-9C1F-3E5A7B9D0C11}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Lab
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=HabitTrackerSetup-{#AppVersion}
SetupIconFile=..\src\habit_tracker\assets\icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Lets Setup/Uninstall detect the running app (see system.MUTEX_NAME) and ask to close it.
AppMutex=Lab.HabitTracker

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "Start Habit Tracker when I sign in to Windows (runs in the tray)"; GroupDescription: "Startup:"

[Files]
Source: "..\build\dist\HabitTracker\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; Same value the in-app "Start with Windows" switch writes (system.RUN_VALUE).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "HabitTracker"; ValueData: """{app}\{#AppExe}"" --background"; Tasks: autostart
; Remove it on uninstall even if it was turned on from inside the app.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "HabitTracker"; Flags: uninsdeletevalue

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Habit data lives in %APPDATA%\HabitTracker and is intentionally kept on uninstall.
