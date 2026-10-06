unit WinUI.Xaml;

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Microsoft.UI.Xaml,
  Winapi.Microsoft.CommonTypes,
  WinUI.Controls;

type
  TWinUIXaml = class
  public
    // Original API: parse XAML, get the root as a plain element.
    class function Load(const AXaml: string): TWinUIElement;
    // Parse XAML and get a root that can look up its x:Name children.
    class function LoadRoot(const AXaml: string): TWinUIFrameworkElement;
  end;

implementation

class function TWinUIXaml.Load(const AXaml: string): TWinUIElement;
var
  LUIElement: IUIElement;
begin
  LUIElement := TMarkup_XamlReader.Load(TWindowsString(AXaml)) as IUIElement;
  Result := TWinUIElement.Create(LUIElement);
end;

class function TWinUIXaml.LoadRoot(const AXaml: string): TWinUIFrameworkElement;
var
  LUIElement: IUIElement;
begin
  LUIElement := TMarkup_XamlReader.Load(TWindowsString(AXaml)) as IUIElement;
  Result := TWinUIFrameworkElement.Create(LUIElement);
end;

end.
