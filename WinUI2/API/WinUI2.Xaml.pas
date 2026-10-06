unit WinUI2.Xaml;

{
  XamlReader front end. System XAML knows every inbox type (Button, AcrylicBrush, ...), so unlike
  WinUI 3 there is NO IXamlMetadataProvider and NO XamlControlsResources to set up.
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.UI.Xaml,
  Winapi.CommonTypes,
  WinUI2.Controls;

type
  TWinUI2Xaml = class
  public
    // Parse XAML, get the root as a plain element.
    class function Load(const AXaml: string): TWinUI2Element;
    // Parse XAML and get a root that can look up its x:Name children.
    class function LoadRoot(const AXaml: string): TWinUI2FrameworkElement;
  end;

implementation

class function TWinUI2Xaml.Load(const AXaml: string): TWinUI2Element;
var
  LUiElmnt: IUIElement;
begin
  LUiElmnt := TMarkup_XamlReader.Load(TWindowsString(AXaml)) as IUIElement;
  Result := TWinUI2Element.Create(LUiElmnt);
end;

class function TWinUI2Xaml.LoadRoot(const AXaml: string): TWinUI2FrameworkElement;
var
  LUiElmnt: IUIElement;
begin
  LUiElmnt := TMarkup_XamlReader.Load(TWindowsString(AXaml)) as IUIElement;
  Result := TWinUI2FrameworkElement.Create(LUiElmnt);
end;

end.
