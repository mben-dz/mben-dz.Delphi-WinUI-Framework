unit WinUI2.Window;

{
  WinUI 2 / inbox UWP XAML host window (XAML Islands). Windows 10 1903+ (build 18362).
  Uses Winapi.UI.Xaml (Windows.UI.Xaml)  -  NOT Winapi.Microsoft.UI.Xaml (that is WinUI 3).

    Win32 window (CreateWindowEx)
      -> WindowsXamlManager.InitializeForCurrentThread
      -> DesktopWindowXamlSource
      -> IXamlIslandNative.AttachToWindow(host HWND)      (child HWND owned by XAML)
      -> XamlSource.Content := your UIElement

  Changes compared with your original unit (all marked  // FIX / // +ADDED):
    FIX    IDesktopWindowXamlSourceNative -> own IXamlIslandNative (WinUI2.Interop), plain HRESULT.
    FIX    WS_EX_NOREDIRECTIONBITMAP removed: not needed for an island host and it disables the
           GDI background of the host window.
    FIX    XAML source / manager are closed in WM_DESTROY (before the HWND is gone), not afterwards.
    FIX    WM_SETFOCUS forwarded to the island; PreTranslateMessage hook for Tab / arrow keys.
    FIX    exceptions never leave WndProc.
    +ADDED Title, ClientSize, MinSize, Center, DarkFrame, OnClientResize, WM_DPICHANGED, QuitOnClose.
    No custom title bar: the standard caption is used (dark via DWM). WinUI 3 ExtendIntoTitleBar
    has no XAML-Islands equivalent without owner-drawn non-client area.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Win.WinRT,
  Winapi.WinRT,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.MultiMon,
  Winapi.UI.Xaml,
  Winapi.SystemRT,
  Winapi.CommonTypes,
  WinUI2.Controls,
  WinUI2.Interop;

type
  TWinUI2SizeProc = reference to procedure(AWidth, AHeight: Integer);

  TWinUI2Window = class
  private
    FHostHwnd: HWND;
    FXamlHwnd: HWND;
    FClassName: string;
    FTitle: string;
    FBrush: HBRUSH;
    FMinW, FMinH: Integer;          // client DIPs
    FQuitOnClose: Boolean;
    FOnResize: TWinUI2SizeProc;
    FXamlManager: Hosting_IWindowsXamlManager;
    FXamlSource: Hosting_IDesktopWindowXamlSource;
    FNative: IXamlIslandNative;
    FNative2: IXamlIslandNative2;
    FDispQueueCtrl: IDispatcherQueueController;
    class function WndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall; static;
    function HandleMessage(AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM; var AResult: LRESULT): Boolean;
    procedure EnsureDispatcherQueue;
    procedure RegisterHostClass;
    procedure CreateHostWindow;
    procedure InitXamlIsland;
    procedure ResizeXamlChild;
    procedure ShutdownXaml;
    function Scale: Double;
    procedure FrameExtra(out ADx, ADy: Integer);
  public
    constructor Create(const ATitle: string = 'WinUI 2 Window'; AWidth: Integer = 800; AHeight: Integer = 600);
    destructor Destroy; override;

    procedure Activate;
    procedure Close;
    procedure SetContent(AElement: TWinUI2Element);
    procedure LoadXaml(const AXaml: string);

    // fluent helpers (sizes in device-independent pixels, 96 dpi = 1.0)
    function Title(const ATitle: string): TWinUI2Window;
    function ClientSize(AWidth, AHeight: Integer): TWinUI2Window;
    function MinSize(AWidth, AHeight: Integer): TWinUI2Window;
    function Center: TWinUI2Window;
    function DarkFrame(AValue: Boolean = True): TWinUI2Window;
    function OnClientResize(const AProc: TWinUI2SizeProc): TWinUI2Window;

    // Call from the message loop before TranslateMessage/DispatchMessage.
    class function PreTranslate(var AMsg: TMsg): Boolean;

    property HostHandle: HWND read FHostHwnd;
    property XamlHandle: HWND read FXamlHwnd;
    property QuitOnClose: Boolean read FQuitOnClose write FQuitOnClose;
  end;

implementation

uses
  Winapi.ActiveX,
  Winapi.Foundation,
  Winapi.Dwmapi;

const
  cHostBackColor = $00463B1B;      // COLORREF (BGR) of #1B3B46: no white flash before XAML paints
  cDwmDarkModeOld = 19;            // Win10 1903 / 1909
  cDwmDarkMode = 20;               // Win10 20H1+ / Win11

var
  GWindows: TList<TWinUI2Window>;

{ -- DispatcherQueue (coremessaging.dll, loaded dynamically) --------------- }
type
  TDispatcherQueueOptions = record
    dwSize: DWORD;
    threadType: DWORD;     // 2 = DQTYPE_THREAD_CURRENT
    apartmentType: DWORD;  // 0 = DQTAT_COM_NONE
  end;

  // The native signature takes the 12-byte struct BY VALUE. Do NOT declare it 'const' or 'var':
  // Delphi passes const records by reference on Win32 -> E_INVALIDARG (0x80070057).
  TCreateDispatcherQueueController = function(AOptions: TDispatcherQueueOptions;
    out AController: IDispatcherQueueController): HRESULT; stdcall;

var
  GCreateDQC: TCreateDispatcherQueueController;

procedure LoadDQC;
var
  LMod: HMODULE;
begin
  if Assigned(GCreateDQC) then Exit;
  LMod := LoadLibrary('coremessaging.dll');
  if LMod = 0 then
    raise Exception.Create('Cannot load coremessaging.dll (Windows 10 1903+ required).');
  GCreateDQC := TCreateDispatcherQueueController(GetProcAddress(LMod, 'CreateDispatcherQueueController'));
  if not Assigned(GCreateDQC) then
    raise Exception.Create('CreateDispatcherQueueController not found in coremessaging.dll.');
end;

type
  TGetDpiForWindow = function(AWnd: HWND): UINT; stdcall;

{ -- TWinUI2Window --------------------------------------------------------- }

constructor TWinUI2Window.Create(const ATitle: string; AWidth, AHeight: Integer);
begin
  inherited Create;
  FTitle := ATitle;
  FQuitOnClose := True;
  FClassName := 'WinUI2Host_' + IntToHex(NativeUInt(Self), SizeOf(NativeUInt) * 2);

  // Order matters (COM must already be STA-initialised: TWinUI2App.Initialize):
  //   1 DispatcherQueue   2 host window (needs an HWND for AttachToWindow)   3 XAML island
  EnsureDispatcherQueue;
  RegisterHostClass;
  CreateHostWindow;
  GWindows.Add(Self);
  try
    InitXamlIsland;
  except
    on E: Exception do
      raise Exception.Create('XAML Islands could not start: ' + E.Message + sLineBreak +
        'Check: Windows 10 1903+ (build 18362), and that the exe manifest declares ' +
        'supportedOS Windows 10 + maxversiontested 10.0.18362.0 (WinUI2LoginDemo.manifest).');
  end;
  ClientSize(AWidth, AHeight);
end;

destructor TWinUI2Window.Destroy;
begin
  GWindows.Remove(Self);
  ShutdownXaml;
  if FHostHwnd <> 0 then
  begin
    SetWindowLongPtr(FHostHwnd, GWLP_USERDATA, 0);
    DestroyWindow(FHostHwnd);
    FHostHwnd := 0;
  end;
  UnregisterClass(PChar(FClassName), HInstance);
  if FBrush <> 0 then
    DeleteObject(FBrush);
  FDispQueueCtrl := nil;
  inherited;
end;

procedure TWinUI2Window.EnsureDispatcherQueue;
var
  LOpts: TDispatcherQueueOptions;
  LCtrl: IDispatcherQueueController;
  HR: HRESULT;
begin
  LoadDQC;
  FillChar(LOpts, SizeOf(LOpts), 0);
  LOpts.dwSize := SizeOf(LOpts);
  LOpts.threadType := 2;
  LOpts.apartmentType := 0;
  HR := GCreateDQC(LOpts, LCtrl);
  // E_ACCESSDENIED: a queue already exists on this thread, which is fine
  if Succeeded(HR) then
    FDispQueueCtrl := LCtrl
  else if HR <> E_ACCESSDENIED then
    raise Exception.CreateFmt('CreateDispatcherQueueController failed 0x%.8x', [Cardinal(HR)]);
end;

{ -- Win32 host window ----------------------------------------------------- }

class function TWinUI2Window.WndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT;
var
  LSelf: TWinUI2Window;
begin
  LSelf := TWinUI2Window(Pointer(GetWindowLongPtr(AWnd, GWLP_USERDATA)));
  if LSelf <> nil then
  begin
    try
      if LSelf.HandleMessage(AMsg, AWParam, ALParam, Result) then Exit;
    except
      on E: Exception do
        OutputDebugString(PChar('WinUI2.Window WndProc: ' + E.Message));
    end;
  end;
  Result := DefWindowProc(AWnd, AMsg, AWParam, ALParam);
end;

function TWinUI2Window.HandleMessage(AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM; var AResult: LRESULT): Boolean;
var
  LS: Double;
  Dx, Dy: Integer;
  LRect: PRect;
begin
  Result := False;
  case AMsg of
    WM_SIZE:
      if AWParam <> SIZE_MINIMIZED then
      begin
        ResizeXamlChild;
        if Assigned(FOnResize) then
        begin
          LS := Scale;
          FOnResize(Round(LoWord(ALParam) / LS), Round(HiWord(ALParam) / LS));
        end;
      end;

    WM_GETMINMAXINFO:
      if (FMinW > 0) and (FMinH > 0) then
      begin
        LS := Scale;
        FrameExtra(Dx, Dy);
        PMinMaxInfo(ALParam)^.ptMinTrackSize.X := Round(FMinW * LS) + Dx;
        PMinMaxInfo(ALParam)^.ptMinTrackSize.Y := Round(FMinH * LS) + Dy;
        AResult := 0;
        Result := True;
      end;

    WM_SETFOCUS:
      if FXamlHwnd <> 0 then
      begin
        Winapi.Windows.SetFocus(FXamlHwnd);
        AResult := 0;
        Result := True;
      end;

    WM_DPICHANGED:
      begin
        LRect := PRect(ALParam);
        SetWindowPos(FHostHwnd, 0, LRect^.Left, LRect^.Top, LRect^.Right - LRect^.Left,
          LRect^.Bottom - LRect^.Top, SWP_NOZORDER or SWP_NOACTIVATE);
        AResult := 0;
        Result := True;
      end;

    WM_DESTROY:
      begin
        ShutdownXaml;                    // close the island while its parent HWND still exists
        if FQuitOnClose then
          PostQuitMessage(0);
        AResult := 0;
        Result := True;
      end;

    WM_NCDESTROY:
      begin
        SetWindowLongPtr(FHostHwnd, GWLP_USERDATA, 0);
        FHostHwnd := 0;
        FXamlHwnd := 0;
      end;
  end;
end;

procedure TWinUI2Window.RegisterHostClass;
var
  LWC: WNDCLASSEX;
begin
  FBrush := CreateSolidBrush(cHostBackColor);
  FillChar(LWC, SizeOf(LWC), 0);
  LWC.cbSize := SizeOf(LWC);
  LWC.style := 0;
  LWC.lpfnWndProc := @WndProc;
  LWC.hInstance := HInstance;
  LWC.hCursor := LoadCursor(0, IDC_ARROW);
  LWC.hbrBackground := FBrush;
  LWC.lpszClassName := PChar(FClassName);
  if RegisterClassEx(LWC) = 0 then
    RaiseLastOSError;
end;

procedure TWinUI2Window.CreateHostWindow;
begin
  FHostHwnd := CreateWindowEx(0, PChar(FClassName), PChar(FTitle), WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, 800, 600, 0, 0, HInstance, nil);
  if FHostHwnd = 0 then
    RaiseLastOSError;
  SetWindowLongPtr(FHostHwnd, GWLP_USERDATA, LONG_PTR(Self));
end;

{ -- XAML Islands ---------------------------------------------------------- }

procedure TWinUI2Window.InitXamlIsland;
var
  HR: HRESULT;
begin
  FXamlManager := THosting_WindowsXamlManager.InitializeForCurrentThread;
  if FXamlManager = nil then
    raise Exception.Create('WindowsXamlManager.InitializeForCurrentThread returned nil');

  FXamlSource := THosting_DesktopWindowXamlSource.Create;

  if not Supports(FXamlSource, IXamlIslandNative, FNative) then
    raise Exception.Create('IDesktopWindowXamlSourceNative not supported by the XAML source');
  Supports(FXamlSource, IXamlIslandNative2, FNative2);   // optional (keyboard navigation)

  HR := FNative.AttachToWindow(FHostHwnd);
  if Failed(HR) then
    raise Exception.CreateFmt('AttachToWindow failed 0x%.8x', [Cardinal(HR)]);
  HR := FNative.get_WindowHandle(FXamlHwnd);
  if Failed(HR) or (FXamlHwnd = 0) then
    raise Exception.CreateFmt('XAML window handle not available (0x%.8x)', [Cardinal(HR)]);

  ResizeXamlChild;
end;

procedure TWinUI2Window.ResizeXamlChild;
var
  LRect: TRect;
begin
  if (FXamlHwnd = 0) or (FHostHwnd = 0) then Exit;
  GetClientRect(FHostHwnd, LRect);
  SetWindowPos(FXamlHwnd, 0, 0, 0, LRect.Right - LRect.Left, LRect.Bottom - LRect.Top,
    SWP_SHOWWINDOW or SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TWinUI2Window.ShutdownXaml;
var
  LClosable: IClosable;
begin
  FNative2 := nil;
  FNative := nil;
  if Assigned(FXamlSource) then
  begin
    try
      FXamlSource.Content := nil;
      if Supports(FXamlSource, IClosable, LClosable) then
        LClosable.Close;
    except
      on E: Exception do OutputDebugString(PChar('WinUI2.Window close source: ' + E.Message));
    end;
    FXamlSource := nil;
    FXamlHwnd := 0;
  end;
  LClosable := nil;
  if Assigned(FXamlManager) then
  begin
    try
      if Supports(FXamlManager, IClosable, LClosable) then
        LClosable.Close;
    except
      on E: Exception do OutputDebugString(PChar('WinUI2.Window close manager: ' + E.Message));
    end;
    FXamlManager := nil;
  end;
end;

class function TWinUI2Window.PreTranslate(var AMsg: TMsg): Boolean;
var
  LWinui2Wnd: TWinUI2Window;
  LHandled: BOOL;
begin
  Result := False;
  if GWindows = nil then Exit;
  for LWinui2Wnd in GWindows do
    if Assigned(LWinui2Wnd.FNative2) then
    begin
      LHandled := False;
      if Succeeded(LWinui2Wnd.FNative2.PreTranslateMessage(@AMsg, LHandled)) and
         LHandled then
        Exit(True);
    end;
end;

{ -- content --------------------------------------------------------------- }

procedure TWinUI2Window.SetContent(AElement: TWinUI2Element);
begin
  if Assigned(FXamlSource) and Assigned(AElement) then
    FXamlSource.Content := AElement.Element;
end;

procedure TWinUI2Window.LoadXaml(const AXaml: string);
begin
  if not Assigned(FXamlSource) then Exit;
  FXamlSource.Content := TMarkup_XamlReader.Load(TWindowsString(AXaml)) as Winapi.CommonTypes.IUIElement;
end;

{ -- show / close ---------------------------------------------------------- }

procedure TWinUI2Window.Activate;
begin
  if FHostHwnd = 0 then Exit;
  ShowWindow(FHostHwnd, SW_SHOWNORMAL);
  UpdateWindow(FHostHwnd);
  SetForegroundWindow(FHostHwnd);
end;

procedure TWinUI2Window.Close;
begin
  if FHostHwnd <> 0 then
    PostMessage(FHostHwnd, WM_CLOSE, 0, 0);
end;

{ -- fluent helpers -------------------------------------------------------- }

function TWinUI2Window.Scale: Double;
var
  LDpiForWnd: TGetDpiForWindow;
  LDpi: UINT;
begin
  Result := 1.0;
  LDpiForWnd := TGetDpiForWindow(GetProcAddress(GetModuleHandle('user32.dll'), 'GetDpiForWindow'));
  if Assigned(LDpiForWnd) and (FHostHwnd <> 0) then
  begin
    LDpi := LDpiForWnd(FHostHwnd);
    if LDpi > 0 then
      Result := LDpi / 96.0;
  end;
end;

procedure TWinUI2Window.FrameExtra(out ADx, ADy: Integer);
var
  R, C: TRect;
begin
  GetWindowRect(FHostHwnd, R);
  GetClientRect(FHostHwnd, C);
  ADx := (R.Right - R.Left) - (C.Right - C.Left);
  ADy := (R.Bottom - R.Top) - (C.Bottom - C.Top);
end;

function TWinUI2Window.Title(const ATitle: string): TWinUI2Window;
begin
  FTitle := ATitle;
  if FHostHwnd <> 0 then
    SetWindowText(FHostHwnd, PChar(ATitle));
  Result := Self;
end;

function TWinUI2Window.ClientSize(AWidth, AHeight: Integer): TWinUI2Window;
var
  LScale: Double;
  Dx, Dy: Integer;
begin
  if FHostHwnd <> 0 then
  begin
    LScale := Scale;
    FrameExtra(Dx, Dy);
    SetWindowPos(FHostHwnd, 0, 0, 0, Round(AWidth * LScale) + Dx, Round(AHeight * LScale) + Dy,
      SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
  end;
  Result := Self;
end;

function TWinUI2Window.MinSize(AWidth, AHeight: Integer): TWinUI2Window;
begin
  FMinW := AWidth;
  FMinH := AHeight;
  Result := Self;
end;

function TWinUI2Window.Center: TWinUI2Window;
var
  R: TRect;
  LMonInfo: TMonitorInfo;
  W, H: Integer;
begin
  if FHostHwnd <> 0 then
  begin
    GetWindowRect(FHostHwnd, R);
    W := R.Right - R.Left;
    H := R.Bottom - R.Top;
    LMonInfo.cbSize := SizeOf(LMonInfo);
    if GetMonitorInfo(MonitorFromWindow(FHostHwnd, MONITOR_DEFAULTTOPRIMARY), @LMonInfo) then
      SetWindowPos(FHostHwnd, 0,
        LMonInfo.rcWork.Left + ((LMonInfo.rcWork.Right - LMonInfo.rcWork.Left) - W) div 2,
        LMonInfo.rcWork.Top + ((LMonInfo.rcWork.Bottom - LMonInfo.rcWork.Top) - H) div 2,
        0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
  end;
  Result := Self;
end;

function TWinUI2Window.DarkFrame(AValue: Boolean): TWinUI2Window;
var
  LBool: BOOL;
begin
  if FHostHwnd <> 0 then
  begin
    LBool := AValue;
    // attribute 20 on newer builds; 19 on the first 1903/1909 builds. The unsupported one just fails.
    if Failed(DwmSetWindowAttribute(FHostHwnd, cDwmDarkMode, @LBool, SizeOf(LBool))) then
      DwmSetWindowAttribute(FHostHwnd, cDwmDarkModeOld, @LBool, SizeOf(LBool));
  end;
  Result := Self;
end;

function TWinUI2Window.OnClientResize(const AProc: TWinUI2SizeProc): TWinUI2Window;
begin
  FOnResize := AProc;
  Result := Self;
end;

initialization
  GWindows := TList<TWinUI2Window>.Create;

finalization
  FreeAndNil(GWindows);

end.
