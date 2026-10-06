unit Main.View;

{
  TMainApp also implements IXamlMetadataProvider (what a normal WinUI app's App class does).
  Without it XamlReader cannot resolve types that live in the WinUI controls library, e.g.
  AcrylicBrush or XamlControlsResources: "The type 'AcrylicBrush' was not found".
  All requests are forwarded to the framework's XamlControlsXamlMetaDataProvider.
}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Winapi.WinRT,
  Winapi.CommonTypes,
  Winapi.Microsoft.UI.Xaml,
  Winapi.Microsoft.CommonTypes,
  WinUI.Core,
  WinUI.Resources,
  WinUI.Preview,
  Login.View;

type
  TMainApp = class(TWinUIApp, Markup_IXamlMetadataProvider)
  private
    FProvider: Markup_IXamlMetadataProvider;
    function Provider: Markup_IXamlMetadataProvider;
  public
    procedure OnLaunched(args: ILaunchActivatedEventArgs); override;
    // Markup_IXamlMetadataProvider
    function GetXamlType(&type: Interop_TypeName): Markup_IXamlType; overload; safecall;
    function GetXamlType(fullName: HSTRING): Markup_IXamlType; overload; safecall;
    function GetXmlnsDefinitions(resultSize: Cardinal; resultValue: PMarkup_XmlnsDefinition): HRESULT; stdcall;
  end;

implementation

var
  GView: TLoginView;

function TMainApp.Provider: Markup_IXamlMetadataProvider;
begin
  if FProvider = nil then
    FProvider := TXamlTypeInfo_XamlControlsXamlMetaDataProvider.Create as Markup_IXamlMetadataProvider;
  Result := FProvider;
end;

function TMainApp.GetXamlType(&type: Interop_TypeName): Markup_IXamlType;
begin
  Result := Provider.GetXamlType(&type);
end;

function TMainApp.GetXamlType(fullName: HSTRING): Markup_IXamlType;
begin
  Result := Provider.GetXamlType(fullName);
end;

function TMainApp.GetXmlnsDefinitions(resultSize: Cardinal; resultValue: PMarkup_XmlnsDefinition): HRESULT;
begin
  Result := Provider.GetXmlnsDefinitions(resultSize, resultValue);
end;

procedure TMainApp.OnLaunched(args: ILaunchActivatedEventArgs);
begin
  inherited;
  // Right-click menus (Cut/Copy/Paste/Select all) are TextCommandBarFlyout, whose template lives in
  // XamlControlsResources. Without it the flyout cannot be built and the app raises an exception.
  try
    TWinUIResources.UseFluentControls;
  except
    on E: Exception do
      OutputDebugString(PChar('UseFluentControls: ' + E.Message));
  end;
  // WinUI3LoginDemo.exe /preview <file.xaml>  -> live XAML preview with hot reload
  if (ParamCount >= 2) and SameText(ParamStr(1), '/preview') then
    TWinUIPreview.Show(ParamStr(2))
  else
    GView := TLoginView.Create;
end;

end.
