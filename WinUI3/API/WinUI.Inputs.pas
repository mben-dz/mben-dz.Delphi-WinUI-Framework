unit WinUI.Inputs;

{
  Wrappers for input controls found in XAML (same style as TWinUIButton / TWinUITextBlock):
    TWinUITextBox      Text
    TWinUIPasswordBox  Password
    TWinUICheckBox     Checked
  Usage:  Box := TWinUITextBox.Wrap(Root.FindElement('UserBox'));  S := Box.Text;
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Foundation,
  Winapi.Microsoft.CommonTypes,
  Winapi.Microsoft.UI.Xaml.ControlsRT,
  WinUI.Controls;

type
  TWinUITextBox = class(TWinUIElement)
  private
    FBox: ITextBox;
    function GetText: string;
    procedure SetText(const AValue: string);
  public
    constructor Wrap(AElement: IUIElement);
    property Text: string read GetText write SetText;
  end;

  TWinUIPasswordBox = class(TWinUIElement)
  private
    FBox: IPasswordBox;
    function GetPassword: string;
    procedure SetPassword(const AValue: string);
  public
    constructor Wrap(AElement: IUIElement);
    property Password: string read GetPassword write SetPassword;
  end;

  TWinUICheckBox = class(TWinUIElement)
  private
    FToggle: Primitives_IToggleButton;
    function GetChecked: Boolean;
  public
    constructor Wrap(AElement: IUIElement);
    property Checked: Boolean read GetChecked;
  end;

implementation

// Takes ownership of an HSTRING returned by a WinRT getter.
function TakeString(AHandle: HSTRING): string;
begin
  Result := TWindowsString.HStringToString(AHandle);
  WindowsDeleteString(AHandle);
end;

{ TWinUITextBox }

constructor TWinUITextBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FBox := AElement as ITextBox;
end;

function TWinUITextBox.GetText: string;
begin
  Result := TakeString(FBox.Text);
end;

procedure TWinUITextBox.SetText(const AValue: string);
begin
  FBox.Text := TWindowsString(AValue);
end;

{ TWinUIPasswordBox }

constructor TWinUIPasswordBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FBox := AElement as IPasswordBox;
end;

function TWinUIPasswordBox.GetPassword: string;
begin
  Result := TakeString(FBox.Password);
end;

procedure TWinUIPasswordBox.SetPassword(const AValue: string);
begin
  FBox.Password := TWindowsString(AValue);
end;

{ TWinUICheckBox }

constructor TWinUICheckBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FToggle := AElement as Primitives_IToggleButton;
end;

function TWinUICheckBox.GetChecked: Boolean;
var
  V: IReference_1__Boolean;
begin
  V := FToggle.IsChecked;
  Result := Assigned(V) and V.Value;
end;

end.
