unit Main.View;

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  Winapi.Microsoft.UI.Xaml,
  Winapi.Microsoft.CommonTypes,
  WinUI.Core,
  WinUI.Window,
  WinUI.Controls,
  WinUI.Events,
  Calc.View;

type
  TMainApp = class(TWinUIApp)
  public
    procedure OnLaunched(args: ILaunchActivatedEventArgs); override;
  end;

// Call after TWinUI.Run returned and before the WinUI runtime is shut down.
procedure ShutdownMainView;

implementation

var
  GWindow: TWinUIWindow;
  GView: TCalcView;

procedure TMainApp.OnLaunched(args: ILaunchActivatedEventArgs);
begin
  inherited;

  GWindow := TWinUIWindow.Create;
  GWindow.Title('Calculator').Size(360, 640).MinSize(320, 500).Center;

  GView := TCalcView.Create(GWindow);

  // Content before Activate
  GWindow.SetContent(GView.Root);
  GWindow.Activate;
end;

procedure ShutdownMainView;
begin
  if Assigned(GView) then
    GView.Shutdown;
end;

end.
