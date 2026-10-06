#define AppName "MARA Image Downloader"
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{0C91D1D8-DA59-4DC1-87DF-3C8749A44A21}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\MaraImageDownloader
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=MaraImageDownloaderSetup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "build\installer-stage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\Pokreni.bat"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\Pokreni.bat"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{cmd}"; Parameters: "/C ""{app}\Pokreni.bat"""; Description: "Launch {#AppName}"; Flags: postinstall nowait skipifsilent
