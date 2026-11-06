; Inno Setup script for the SizeCheck Windows installer.
; Built by .github/workflows/release.yml:
;   iscc /DAppVersion=1.2.3 /DSourceDir=<Release folder> /DOutputDir=<out> sizecheck.iss
; Installs for the current user only, so no administrator rights are needed.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
AppId={{5D4C6F1E-3B7A-4E8F-9C21-6A0B7D2E1F43}
AppName=SizeCheck
AppVersion={#AppVersion}
AppPublisher=SizeCheck contributors
AppPublisherURL=https://github.com/MohammedAnasAsif/SizeCheck
AppSupportURL=https://github.com/MohammedAnasAsif/SizeCheck/issues
DefaultDirName={localappdata}\Programs\SizeCheck
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=SizeCheck-{#AppVersion}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\sizecheck.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SizeCheck"; Filename: "{app}\sizecheck.exe"
Name: "{autodesktop}\SizeCheck"; Filename: "{app}\sizecheck.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sizecheck.exe"; Description: "Open SizeCheck"; Flags: nowait postinstall skipifsilent
