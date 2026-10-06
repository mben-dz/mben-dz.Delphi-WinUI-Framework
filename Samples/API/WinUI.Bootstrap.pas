unit WinUI.Bootstrap;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Winapi.WinRT;

type
  TWinUIBootstrap = class
  public
    class procedure Initialize;
    class procedure Shutdown;
  end;

implementation

type
  PACKAGE_VERSION = record
    union: record
      case Integer of
        0: (Version: UInt64);
        1: (Revision: UInt16; Build: UInt16; Minor: UInt16; Major: UInt16);
    end;
  end;

  MddBootstrapInitializeOptions = Integer;

const
  MddBootstrapInitializeOptions_None = 0;

var
  BootstrapModule: HMODULE = 0;
  _MddBootstrapInitialize2: function(majorMinorVersion: UInt32; versionTag: PCWSTR; minPackageVersion: PACKAGE_VERSION; options: MddBootstrapInitializeOptions): HRESULT; stdcall;
  _MddBootstrapShutdown: procedure; stdcall;

class procedure TWinUIBootstrap.Initialize;
var
  HR: HRESULT;
  Ver: PACKAGE_VERSION;
  VersionsToTry: array[0..6] of UInt32;
  I: Integer;
  Success: Boolean;
begin
  if BootstrapModule <> 0 then Exit;

  BootstrapModule := LoadLibrary('Microsoft.WindowsAppRuntime.Bootstrap.dll');
  if BootstrapModule = 0 then
    raise Exception.Create('Failed to load Microsoft.WindowsAppRuntime.Bootstrap.dll. Please ensure the Windows App SDK is installed and the DLL is in the application folder.');

  @_MddBootstrapInitialize2 := GetProcAddress(BootstrapModule, 'MddBootstrapInitialize2');
  @_MddBootstrapShutdown := GetProcAddress(BootstrapModule, 'MddBootstrapShutdown');

  if not Assigned(_MddBootstrapInitialize2) then
    raise Exception.Create('MddBootstrapInitialize2 not found in Bootstrap DLL.');

  Ver.union.Version := 0;
  VersionsToTry[0] := $00010006; // 1.6
  VersionsToTry[1] := $00010005; // 1.5
  VersionsToTry[2] := $00010004; // 1.4
  VersionsToTry[3] := $00010003; // 1.3
  VersionsToTry[4] := $00010002; // 1.2
  VersionsToTry[5] := $00010001; // 1.1
  VersionsToTry[6] := $00010000; // 1.0

  Success := False;
  for I := Low(VersionsToTry) to High(VersionsToTry) do
  begin
    HR := _MddBootstrapInitialize2(VersionsToTry[I], nil, Ver, MddBootstrapInitializeOptions_None);
    if HR = S_OK then
    begin
      Success := True;
      Break;
    end;
  end;

  if not Success then
    raise Exception.CreateFmt('Failed to initialize Windows App SDK. HRESULT: 0x%x', [HR]);
end;

class procedure TWinUIBootstrap.Shutdown;
begin
  if Assigned(_MddBootstrapShutdown) then
    _MddBootstrapShutdown;

  if BootstrapModule <> 0 then
  begin
    FreeLibrary(BootstrapModule);
    BootstrapModule := 0;
  end;
end;

end.
