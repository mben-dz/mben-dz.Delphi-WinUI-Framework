program WinUI2LoginDemo;

{$APPTYPE GUI}
{$R *.res}

// No Vcl.* / FMX.* unit anywhere. XAML comes from Windows 10 itself (XAML Islands):
// no Windows App SDK, no bootstrap DLL. Build with runtime packages OFF.

uses
  Winapi.Windows,
  System.SysUtils,
  WinUI2.Interop in 'API\WinUI2.Interop.pas',
  WinUI2.Events in 'API\WinUI2.Events.pas',
  WinUI2.Controls in 'API\WinUI2.Controls.pas',
  WinUI2.Inputs in 'API\WinUI2.Inputs.pas',
  WinUI2.Window in 'API\WinUI2.Window.pas',
  WinUI2.App in 'API\WinUI2.App.pas',
  WinUI2.Xaml in 'API\WinUI2.Xaml.pas',
  WinUI2.Navigation in 'API\WinUI2.Navigation.pas',
  WinUI2.Icon in 'API\WinUI2.Icon.pas',
  Login.Auth in 'Login.Auth.pas',
  Login.Xaml in 'Login.Xaml.pas',
  Login.Pages in 'Login.Pages.pas',
  Login.View in 'Login.View.pas';

var
  WinUI2_View: TLoginView;
begin
  try
    TWinUI2App.Initialize;
    try
      WinUI2_View := TLoginView.Create;
      try
        TWinUI2App.Run;
      finally
        WinUI2_View.Free;
      end;
    finally
      TWinUI2App.Shutdown;
    end;
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'WinUI2LoginDemo', MB_ICONERROR or MB_OK);
  end;
end.
