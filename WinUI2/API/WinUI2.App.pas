unit WinUI2.App;

{
  Process / thread plumbing for a windowed XAML-Islands exe that uses no VCL/FMX.

    TWinUI2App.Initialize;   // DPI awareness + STA (XAML requires a single-threaded apartment)
    ... create TWinUI2Window(s) ...
    TWinUI2App.Run;          // message loop with the XAML keyboard-navigation hook
    TWinUI2App.Shutdown;
}

interface

type
  TWinUI2App = class
  public
    class procedure Initialize;
    class procedure Run;
    class procedure Quit;
    class procedure Shutdown;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.SysUtils,
  WinUI2.Window;

var
  GComInitialised: Boolean;

type
  TSetProcessDpiAwarenessContext = function(AValue: THandle): BOOL; stdcall;

class procedure TWinUI2App.Initialize;
const
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = THandle(-4);
var
  LDpiCntx: TSetProcessDpiAwarenessContext;
  HR: HRESULT;
begin
  // The manifest already requests PerMonitorV2; this is only the safety net (fails harmlessly if set).
  LDpiCntx := TSetProcessDpiAwarenessContext(GetProcAddress(GetModuleHandle('user32.dll'), 'SetProcessDpiAwarenessContext'));
  if Assigned(LDpiCntx) then
    LDpiCntx(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

  HR := CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE);
  if (HR = S_OK) or (HR = S_FALSE) then
    GComInitialised := True
  else
    raise Exception.CreateFmt('CoInitializeEx(STA) failed 0x%.8x. XAML needs the UI thread to be ' +
      'single-threaded; something initialised it as MTA first.', [Cardinal(HR)]);
end;

class procedure TWinUI2App.Run;
var
  LMsg: TMsg;
begin
  while Integer(GetMessage(LMsg, 0, 0, 0)) > 0 do
    if not TWinUI2Window.PreTranslate(LMsg) then
    begin
      TranslateMessage(LMsg);
      DispatchMessage(LMsg);
    end;
end;

class procedure TWinUI2App.Quit;
begin
  PostQuitMessage(0);
end;

class procedure TWinUI2App.Shutdown;
begin
  if GComInitialised then
  begin
    GComInitialised := False;
    CoUninitialize;
  end;
end;

end.
