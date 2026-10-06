unit WinUI.Resources;

{
  An unpackaged WinUI 3 app has NO default control styles until XamlControlsResources is merged
  into Application.Resources (what App.xaml does in a normal project). Without it, controls that
  use their default template (TextBox, PasswordBox, CheckBox, ScrollViewer ...) can fail while
  XamlReader.Load builds them. Call TWinUIResources.UseFluentControls once, in OnLaunched,
  BEFORE loading any XAML. Every step reports its own name if it fails.
}

interface

type
  TWinUIResources = class
  public
    class procedure UseFluentControls;
  end;

implementation

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Microsoft.UI.Xaml,
  Winapi.Microsoft.CommonTypes,
  WinUI.Core;

const
  cControlsResourcesXaml =
    '<XamlControlsResources xmlns="using:Microsoft.UI.Xaml.Controls"/>';

class procedure TWinUIResources.UseFluentControls;
var
  App: IApplication;
  Res: IResourceDictionary;
  Controls: IResourceDictionary;
  Step: string;
begin
  try
    Step := 'get Application';
    App := TWinUI.Application;
    if App = nil then
      raise Exception.Create('TWinUI.Application is nil');

    Step := 'Application.Resources';
    Res := App.Resources;
    if Res = nil then
    begin
      Step := 'create ResourceDictionary';
      Res := TResourceDictionary.Create;
      App.Resources := Res;
    end;

    // the same thing App.xaml does: <XamlControlsResources/> (parsed, no binding cast needed)
    Step := 'load XamlControlsResources';
    Controls := TMarkup_XamlReader.Load(TWindowsString(cControlsResourcesXaml)) as IResourceDictionary;

    Step := 'MergedDictionaries.Append';
    Res.MergedDictionaries.Append(Controls);
  except
    on E: Exception do
      raise Exception.CreateFmt('UseFluentControls failed at "%s": %s: %s', [Step, E.ClassName, E.Message]);
  end;
end;

end.
