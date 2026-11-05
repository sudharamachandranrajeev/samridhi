; Samridhi for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\samridhi.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Samridhi alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{5B1E7A52-3C0D-4F7B-9A44-2D6E8C1F90A3}
AppName=Samridhi
AppVersion={#AppVersion}
AppVerName=Samridhi {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Samridhi
DefaultGroupName=Samridhi
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Samridhi-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\samridhi.exe
UninstallDisplayName=Samridhi
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
; Windows 10 1809 or later (and Windows 11)
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Samridhi"; Filename: "{app}\samridhi.exe"; Comment: "Wealth planning"
Name: "{autodesktop}\Samridhi"; Filename: "{app}\samridhi.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\samridhi.exe"; Description: "{cm:LaunchProgram,Samridhi}"; Flags: nowait postinstall skipifsilent
