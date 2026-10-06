program DelphiWinui3Calc;

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
  WinUI.Xaml in 'API\WinUI.Xaml.pas',
  WinUI.Input in 'API\WinUI.Input.pas',
  Calc.Decimal in 'API\Calc.Decimal.pas',
  Calc.Engine in 'API\Calc.Engine.pas',
  Calc.Xaml in 'Calc.Xaml.pas',
  Calc.View in 'Calc.View.pas',
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
      ShutdownMainView;   // unhook the keyboard while the runtime is still loaded
    finally
      TWinUIBootstrap.Shutdown;
    end;
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'Fatal Error', MB_ICONERROR);
  end;
end.
