program WinUI3LoginDemo;

{$APPTYPE GUI}
{$R *.res}

uses
  Winapi.Windows,
  System.SysUtils,
  WinUI.Bootstrap in 'API\WinUI.Bootstrap.pas',
  WinUI.Core in 'API\WinUI.Core.pas',
  WinUI.Events in 'API\WinUI.Events.pas',
  WinUI.Controls in 'API\WinUI.Controls.pas',
  WinUI.Window in 'API\WinUI.Window.pas',
  WinUI.Inputs in 'API\WinUI.Inputs.pas',
  WinUI.Resources in 'API\WinUI.Resources.pas',
  WinUI.Xaml in 'API\WinUI.Xaml.pas',
  WinUI.Navigation in 'API\WinUI.Navigation.pas',
  WinUI.Icon in 'API\WinUI.Icon.pas',
  WinUI.Preview in 'API\WinUI.Preview.pas',
  Login.Auth in 'Login.Auth.pas',
  Login.Xaml in 'Login.Xaml.pas',
  Login.Pages in 'Login.Pages.pas',
  Login.View in 'Login.View.pas',
  Main.View in 'Main.View.pas';

function IsElevated: Boolean;
const
  TokenElevation = TTokenInformationClass(20);
var
  LTokenHandle: THandle;
  LLen: Cardinal;
  LTokenElevation: TOKEN_ELEVATION;
  LGotToken: Boolean;
begin
  Result := False;
  if CheckWin32Version(6, 0) then
  begin
    LTokenHandle := 0;
    LGotToken := OpenThreadToken(GetCurrentThread, TOKEN_QUERY, True, LTokenHandle);
    if not LGotToken and (GetLastError = ERROR_NO_TOKEN) then
      LGotToken := OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, LTokenHandle);
    if LGotToken then
      try
        LLen := 0;
        if GetTokenInformation(LTokenHandle, TokenElevation, @LTokenElevation, SizeOf(LTokenElevation), LLen) then
          Result := LTokenElevation.TokenIsElevated <> 0
      finally
        CloseHandle(LTokenHandle);
      end
  end
  else
    Result := True;
end;

begin
  if IsElevated then
  begin
    MessageBox(0, 'Please run without elevated privileges. DynamicDependencies doesn''t support elevation.', 'Error', MB_ICONERROR);
    Exit;
  end;

  try
    TWinUIBootstrap.Initialize;
    try
      TWinUI.Run(TMainApp);
    finally
      TWinUIBootstrap.Shutdown;
    end;
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'Fatal Error', MB_ICONERROR);
  end;
end.
