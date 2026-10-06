unit WinUI.Navigation;

{
  Minimal page navigation: a ContentControl whose Content is swapped, with a back stack.
  (A real Microsoft.UI.Xaml.Controls.Frame needs registered Page types, which an unpackaged
  Delphi app does not have - that was the source of the navigation failures.)
}

interface

uses
  Winapi.WinRT,
  System.Generics.Collections,
  Winapi.Microsoft.CommonTypes,
  WinUI.Controls;

type
  TWinUIPageHost = class
  private
    FHost: TWinUIContentHost;
    FHistory: TStack<IUIElement>;
    FCurrent: IUIElement;
  public
    constructor Wrap(AElement: IUIElement);
    destructor Destroy; override;
    // Shows APage and remembers the previous page for GoBack.
    procedure Navigate(const APage: IUIElement);
    // Shows APage without touching the back stack and clears it.
    procedure Reset(const APage: IUIElement);
    // Returns to the previous page; False if there is none.
    function GoBack: Boolean;
    function CanGoBack: Boolean;
  end;

implementation

uses
  System.SysUtils;

constructor TWinUIPageHost.Wrap(AElement: IUIElement);
begin
  inherited Create;
  if AElement = nil then
    raise EArgumentNilException.Create('Page host element is nil.');
  FHost := TWinUIContentHost.Wrap(AElement);
  FHistory := TStack<IUIElement>.Create;
end;

destructor TWinUIPageHost.Destroy;
begin
  FHistory.Free;
  FHost.Free;
  inherited;
end;

procedure TWinUIPageHost.Navigate(const APage: IUIElement);
begin
  if (APage = nil) or (APage = FCurrent) then Exit;
  if FCurrent <> nil then FHistory.Push(FCurrent);
  FCurrent := APage;
  FHost.SetContent(APage);
end;

procedure TWinUIPageHost.Reset(const APage: IUIElement);
begin
  FHistory.Clear;
  FCurrent := nil;
  Navigate(APage);
end;

function TWinUIPageHost.CanGoBack: Boolean;
begin
  Result := FHistory.Count > 0;
end;

function TWinUIPageHost.GoBack: Boolean;
begin
  Result := FHistory.Count > 0;
  if not Result then Exit;
  FCurrent := FHistory.Pop;
  FHost.SetContent(FCurrent);
end;

end.
