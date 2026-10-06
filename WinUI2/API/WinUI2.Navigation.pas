unit WinUI2.Navigation;

{
  Minimal page navigation: a ContentControl whose Content is swapped, with a back stack.
  (Frame/Page needs registered Page types, which a plain Delphi exe does not have.)
}

interface

uses
  Winapi.WinRT,
  System.Generics.Collections,
  Winapi.CommonTypes,
  WinUI2.Controls;

type
  TWinUI2PageHost = class
  private
    FHost: TWinUI2ContentHost;
    FHistory: TStack<IUIElement>;
    FCurrent: IUIElement;
  public
    constructor Wrap(AElement: IUIElement);
    destructor Destroy; override;
    procedure Navigate(const APage: IUIElement);   // remembers the previous page
    procedure Reset(const APage: IUIElement);      // clears the back stack
    function GoBack: Boolean;
    function CanGoBack: Boolean;
  end;

implementation

uses
  System.SysUtils;

constructor TWinUI2PageHost.Wrap(AElement: IUIElement);
begin
  inherited Create;
  if AElement = nil then
    raise EArgumentNilException.Create('Page host element is nil.');
  FHost := TWinUI2ContentHost.Wrap(AElement);
  FHistory := TStack<IUIElement>.Create;
end;

destructor TWinUI2PageHost.Destroy;
begin
  FHistory.Free;
  FHost.Free;
  inherited;
end;

procedure TWinUI2PageHost.Navigate(const APage: IUIElement);
begin
  if (APage = nil) or (APage = FCurrent) then Exit;
  if FCurrent <> nil then FHistory.Push(FCurrent);
  FCurrent := APage;
  FHost.SetContent(APage);
end;

procedure TWinUI2PageHost.Reset(const APage: IUIElement);
begin
  FHistory.Clear;
  FCurrent := nil;
  Navigate(APage);
end;

function TWinUI2PageHost.CanGoBack: Boolean;
begin
  Result := FHistory.Count > 0;
end;

function TWinUI2PageHost.GoBack: Boolean;
begin
  Result := FHistory.Count > 0;
  if not Result then Exit;
  FCurrent := FHistory.Pop;
  FHost.SetContent(FCurrent);
end;

end.
