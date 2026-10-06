unit WinUI.Window;

{
  TWinUIWindow - original API (Create / Activate / SetContent / Window) plus
  native-window helpers that need no extra WinRT bindings: they operate on the
  window's HWND (found on the UI thread), so Title / Size / MinSize / Center
  work with any generated binding set. Call them before Activate.
}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.MultiMon,
  System.SysUtils,
  System.Win.WinRT,
  Winapi.WinRT,
  Winapi.Microsoft.UI.Xaml,
  Winapi.Microsoft.CommonTypes,
  WinUI.Controls;

type
  TWinUIWindow = class
  private
    FWindow: IWindow;
    FWinInner: IInspectable;
    FWinOuter: TInspectableObject;
    FHandle: HWND;
    function GetHandle: HWND;
  public
    constructor Create;
    procedure Activate;
    procedure SetContent(AElement: TWinUIElement);
    // Fluent native helpers (sizes are in device-independent pixels, 96 dpi = 1.0)
    function Title(const ATitle: string): TWinUIWindow;
    function Size(AWidth, AHeight: Integer): TWinUIWindow;
    function MinSize(AWidth, AHeight: Integer): TWinUIWindow;
    function Center: TWinUIWindow;
    property Window: IWindow read FWindow;
    property Handle: HWND read GetHandle;
  end;

implementation

type
  TGetDpiForWindow = function(AWnd: HWND): UINT; stdcall;

  TFindInfo = record
    Exact: HWND;
    Fallback: HWND;
  end;
  PFindInfo = ^TFindInfo;

var
  GOldWndProc: TFNWndProc;
  GMinW, GMinH: Integer;   // DIPs

function WindowScale(AWnd: HWND): Double;
var
  M: HMODULE;
  F: TGetDpiForWindow;
  Dpi: UINT;
begin
  Result := 1.0;
  M := GetModuleHandle('user32.dll');
  if M = 0 then Exit;
  F := TGetDpiForWindow(GetProcAddress(M, 'GetDpiForWindow'));
  if not Assigned(F) then Exit;
  Dpi := F(AWnd);
  if Dpi > 0 then
    Result := Dpi / 96.0;
end;

function EnumThreadProc(AWnd: HWND; ALParam: LPARAM): BOOL; stdcall;
var
  Info: PFindInfo;
  Cls: array[0..255] of Char;
begin
  Result := True;
  Info := PFindInfo(ALParam);
  if GetWindow(AWnd, GW_OWNER) <> 0 then Exit;
  if (GetWindowLong(AWnd, GWL_STYLE) and WS_CAPTION) = 0 then Exit;
  GetClassName(AWnd, Cls, Length(Cls));
  if string(Cls) = 'WinUIDesktopWin32WindowClass' then
  begin
    Info^.Exact := AWnd;
    Result := False;
  end
  else if Info^.Fallback = 0 then
    Info^.Fallback := AWnd;
end;

function MinSizeWndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  Scale: Double;
begin
  Result := CallWindowProc(GOldWndProc, AWnd, AMsg, AWParam, ALParam);
  if AMsg = WM_GETMINMAXINFO then
  begin
    Scale := WindowScale(AWnd);
    PMinMaxInfo(ALParam)^.ptMinTrackSize.X := Round(GMinW * Scale);
    PMinMaxInfo(ALParam)^.ptMinTrackSize.Y := Round(GMinH * Scale);
  end;
end;

{ TWinUIWindow }

constructor TWinUIWindow.Create;
begin
  FWindow := TWindow.Current;
  if FWindow = nil then
  begin
    FWinOuter := TInspectableObject.Create;
    FWindow := TWindow.Factory.CreateInstance(FWinOuter, FWinInner);
  end;
end;

procedure TWinUIWindow.Activate;
begin
  if Assigned(FWindow) then
    FWindow.Activate;
end;

procedure TWinUIWindow.SetContent(AElement: TWinUIElement);
begin
  if Assigned(FWindow) and Assigned(AElement) then
    FWindow.Content := AElement.Element;
end;

function TWinUIWindow.GetHandle: HWND;
var
  Info: TFindInfo;
begin
  if FHandle = 0 then
  begin
    Info.Exact := 0;
    Info.Fallback := 0;
    EnumThreadWindows(GetCurrentThreadId, @EnumThreadProc, LPARAM(@Info));
    if Info.Exact <> 0 then
      FHandle := Info.Exact
    else
      FHandle := Info.Fallback;
  end;
  Result := FHandle;
end;

function TWinUIWindow.Title(const ATitle: string): TWinUIWindow;
begin
  if Handle <> 0 then
    SetWindowText(Handle, PChar(ATitle));
  Result := Self;
end;

function TWinUIWindow.Size(AWidth, AHeight: Integer): TWinUIWindow;
var
  Scale: Double;
begin
  if Handle <> 0 then
  begin
    Scale := WindowScale(Handle);
    SetWindowPos(Handle, 0, 0, 0, Round(AWidth * Scale), Round(AHeight * Scale),
      SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
  end;
  Result := Self;
end;

function TWinUIWindow.MinSize(AWidth, AHeight: Integer): TWinUIWindow;
begin
  GMinW := AWidth;
  GMinH := AHeight;
  if (Handle <> 0) and (not Assigned(GOldWndProc)) then
    GOldWndProc := TFNWndProc(SetWindowLongPtr(Handle, GWLP_WNDPROC, LONG_PTR(@MinSizeWndProc)));
  Result := Self;
end;

function TWinUIWindow.Center: TWinUIWindow;
var
  R: TRect;
  Mon: HMONITOR;
  MI: TMonitorInfo;
  W, H: Integer;
begin
  if Handle <> 0 then
  begin
    GetWindowRect(Handle, R);
    W := R.Right - R.Left;
    H := R.Bottom - R.Top;
    Mon := MonitorFromWindow(Handle, MONITOR_DEFAULTTOPRIMARY);
    MI.cbSize := SizeOf(MI);
    if GetMonitorInfo(Mon, @MI) then
      SetWindowPos(Handle, 0,
        MI.rcWork.Left + ((MI.rcWork.Right - MI.rcWork.Left) - W) div 2,
        MI.rcWork.Top + ((MI.rcWork.Bottom - MI.rcWork.Top) - H) div 2,
        0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
  end;
  Result := Self;
end;

end.
