unit WinUI.Window;

{
  TWinUIWindow - original API (Create / Activate / SetContent / Window) plus helpers.

  Native helpers work on the window's HWND (found on the UI thread) and need no extra
  WinRT bindings: Title, Size, ClientSize, MinSize, Center, DarkFrame, Mica, OnClientResize.
  ExtendIntoTitleBar uses IWindow.ExtendsContentIntoTitleBar / IWindow.SetTitleBar.

  Equivalent of the C# snippet
      ExtendsContentIntoTitleBar = true;  SystemBackdrop = new MicaBackdrop();
      AppWindow.ResizeClient(new SizeInt32(w, h));
  is
      Window.ExtendIntoTitleBar(TitleBarElement);   // after SetContent
      Window.Mica;                                  // DWM system backdrop (Windows 11 22H2+)
      Window.ClientSize(w, h);

  Mica goes through DWM (DWMWA_SYSTEMBACKDROP_TYPE) instead of Window.SystemBackdrop, so it
  works even when your generated bindings have no MicaBackdrop. Call these before Activate.
  All sizes are device-independent pixels (96 dpi = 1.0).
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
  // Called on the UI thread whenever the client area size changes.
  TWinUISizeProc = reference to procedure(AWidth, AHeight: Integer);

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
    function Title(const ATitle: string): TWinUIWindow;
    // Outer window size.
    function Size(AWidth, AHeight: Integer): TWinUIWindow;
    // Client area size (what AppWindow.ResizeClient does). Call after ExtendIntoTitleBar.
    function ClientSize(AWidth, AHeight: Integer): TWinUIWindow;
    // Smallest client area the user can resize to.
    function MinSize(AWidth, AHeight: Integer): TWinUIWindow;
    function Center: TWinUIWindow;
    // Hides the system title bar; ATitleBar becomes the drag region and the system draws the
    // caption buttons (minimize / maximize / close) over its right end.
    function ExtendIntoTitleBar(ATitleBar: TWinUIElement): TWinUIWindow;
    // Dark caption buttons / dark system backdrop (even when Windows itself is in light mode).
    function DarkFrame(AValue: Boolean = True): TWinUIWindow;
    // Mica backdrop. Returns False when not available (before Windows 11 22H2): the caller
    // should then paint a solid background.
    function Mica: Boolean;
    function OnClientResize(const AProc: TWinUISizeProc): TWinUIWindow;
    function ClientWidth: Integer;
    function ClientHeight: Integer;
    property Window: IWindow read FWindow;
    property Handle: HWND read GetHandle;
  end;

implementation

uses
  Winapi.Dwmapi,
  Winapi.UxTheme;

const
  cDwmUseImmersiveDarkMode = 20;   // DWMWA_USE_IMMERSIVE_DARK_MODE
  cDwmSystemBackdropType = 38;     // DWMWA_SYSTEMBACKDROP_TYPE
  cDwmSbtMainWindow = 2;           // DWMSBT_MAINWINDOW = Mica
  cMicaMinBuild = 22621;           // Windows 11 22H2

type
  TGetDpiForWindow = function(AWnd: HWND): UINT; stdcall;

  TFindInfo = record
    Exact: HWND;
    Fallback: HWND;
  end;
  PFindInfo = ^TFindInfo;

var
  GOldWndProc: TFNWndProc;
  GMinW, GMinH: Integer;   // client DIPs
  GOnResize: TWinUISizeProc;

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

// Pixels the window frame adds around the client area.
procedure FrameExtra(AWnd: HWND; out ADx, ADy: Integer);
var
  R, C: TRect;
begin
  GetWindowRect(AWnd, R);
  GetClientRect(AWnd, C);
  ADx := (R.Right - R.Left) - (C.Right - C.Left);
  ADy := (R.Bottom - R.Top) - (C.Bottom - C.Top);
end;

function EnumThreadProc(AWnd: HWND; ALParam: LPARAM): BOOL; stdcall;
var
  Info: PFindInfo;
  Cls: array[0..255] of Char;
begin
  Result := True;
  Info := PFindInfo(ALParam);
  if GetWindow(AWnd, GW_OWNER) <> 0 then Exit;
  GetClassName(AWnd, Cls, Length(Cls));
  if string(Cls) = 'WinUIDesktopWin32WindowClass' then
  begin
    Info^.Exact := AWnd;
    Result := False;
  end
  else if (Info^.Fallback = 0) and ((GetWindowLong(AWnd, GWL_STYLE) and WS_CAPTION) <> 0) then
    Info^.Fallback := AWnd;
end;

// One subclass serves min size and size notifications.
function WindowSubclassProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  Scale: Double;
  Dx, Dy: Integer;
begin
  Result := CallWindowProc(GOldWndProc, AWnd, AMsg, AWParam, ALParam);
  case AMsg of
    WM_GETMINMAXINFO:
      if (GMinW > 0) and (GMinH > 0) then
      begin
        Scale := WindowScale(AWnd);
        FrameExtra(AWnd, Dx, Dy);
        PMinMaxInfo(ALParam)^.ptMinTrackSize.X := Round(GMinW * Scale) + Dx;
        PMinMaxInfo(ALParam)^.ptMinTrackSize.Y := Round(GMinH * Scale) + Dy;
      end;
    WM_SIZE:
      if (AWParam <> SIZE_MINIMIZED) and Assigned(GOnResize) then
      begin
        Scale := WindowScale(AWnd);
        try
          GOnResize(Round(LoWord(ALParam) / Scale), Round(HiWord(ALParam) / Scale));
        except
          // never let a Delphi exception travel back into the window procedure
        end;
      end;
  end;
end;

procedure EnsureSubclass(AWnd: HWND);
begin
  if (AWnd <> 0) and (not Assigned(GOldWndProc)) then
    GOldWndProc := TFNWndProc(SetWindowLongPtr(AWnd, GWLP_WNDPROC, LONG_PTR(@WindowSubclassProc)));
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

function TWinUIWindow.ClientSize(AWidth, AHeight: Integer): TWinUIWindow;
var
  Scale: Double;
  Dx, Dy: Integer;
begin
  if Handle <> 0 then
  begin
    Scale := WindowScale(Handle);
    FrameExtra(Handle, Dx, Dy);
    SetWindowPos(Handle, 0, 0, 0, Round(AWidth * Scale) + Dx, Round(AHeight * Scale) + Dy,
      SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
  end;
  Result := Self;
end;

function TWinUIWindow.MinSize(AWidth, AHeight: Integer): TWinUIWindow;
begin
  GMinW := AWidth;
  GMinH := AHeight;
  EnsureSubclass(Handle);
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

function TWinUIWindow.ExtendIntoTitleBar(ATitleBar: TWinUIElement): TWinUIWindow;
begin
  FWindow.ExtendsContentIntoTitleBar := True;
  if Assigned(ATitleBar) then
    FWindow.SetTitleBar(ATitleBar.Element);
  Result := Self;
end;

function TWinUIWindow.DarkFrame(AValue: Boolean): TWinUIWindow;
var
  V: BOOL;
begin
  if Handle <> 0 then
  begin
    V := AValue;
    DwmSetWindowAttribute(Handle, cDwmUseImmersiveDarkMode, @V, SizeOf(V));
  end;
  Result := Self;
end;

function TWinUIWindow.Mica: Boolean;
var
  Margins: TMargins;
  BackdropType: Integer;
begin
  Result := False;
  if (Handle = 0) or (TOSVersion.Build < cMicaMinBuild) then Exit;
  Margins.cxLeftWidth := -1;
  Margins.cxRightWidth := -1;
  Margins.cyTopHeight := -1;
  Margins.cyBottomHeight := -1;
  DwmExtendFrameIntoClientArea(Handle, Margins);   // let the backdrop reach the whole client area
  BackdropType := cDwmSbtMainWindow;
  Result := Succeeded(DwmSetWindowAttribute(Handle, cDwmSystemBackdropType, @BackdropType, SizeOf(BackdropType)));
end;

function TWinUIWindow.OnClientResize(const AProc: TWinUISizeProc): TWinUIWindow;
begin
  GOnResize := AProc;
  EnsureSubclass(Handle);
  Result := Self;
end;

function TWinUIWindow.ClientWidth: Integer;
var
  C: TRect;
begin
  Result := 0;
  if Handle <> 0 then
  begin
    GetClientRect(Handle, C);
    Result := Round((C.Right - C.Left) / WindowScale(Handle));
  end;
end;

function TWinUIWindow.ClientHeight: Integer;
var
  C: TRect;
begin
  Result := 0;
  if Handle <> 0 then
  begin
    GetClientRect(Handle, C);
    Result := Round((C.Bottom - C.Top) / WindowScale(Handle));
  end;
end;

end.
