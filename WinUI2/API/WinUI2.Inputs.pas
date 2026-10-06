unit WinUI2.Inputs;

{
  Input-control wrappers for controls found in XAML (same style as TWinUI2Button):
    TWinUI2TextBox      Text
    TWinUI2PasswordBox  Password
    TWinUI2CheckBox     Checked
  Usage:  Box := TWinUI2TextBox.Wrap(Root.FindElement('UserBox'));  S := Box.Text;
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Foundation,
  Winapi.CommonTypes,
  Winapi.UI.Xaml.ControlsRT,
  WinUI2.Controls;

type
  TWinUI2TextBox = class(TWinUI2Element)
  private
    FBox: ITextBox;
    function GetText: string;
    procedure SetText(const AValue: string);
  public
    constructor Wrap(AElement: IUIElement);
    property Text: string read GetText write SetText;
  end;

  TWinUI2PasswordBox = class(TWinUI2Element)
  private
    FBox: IPasswordBox;
    function GetPassword: string;
    procedure SetPassword(const AValue: string);
  public
    constructor Wrap(AElement: IUIElement);
    property Password: string read GetPassword write SetPassword;
  end;

  TWinUI2CheckBox = class(TWinUI2Element)
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

{ TWinUI2TextBox }

constructor TWinUI2TextBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FBox := AElement as ITextBox;
end;

function TWinUI2TextBox.GetText: string;
begin
  Result := TakeString(FBox.Text);
end;

procedure TWinUI2TextBox.SetText(const AValue: string);
begin
  FBox.Text := TWindowsString(AValue);
end;

{ TWinUI2PasswordBox }

constructor TWinUI2PasswordBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FBox := AElement as IPasswordBox;
end;

function TWinUI2PasswordBox.GetPassword: string;
begin
  Result := TakeString(FBox.Password);
end;

procedure TWinUI2PasswordBox.SetPassword(const AValue: string);
begin
  FBox.Password := TWindowsString(AValue);
end;

{ TWinUI2CheckBox }

constructor TWinUI2CheckBox.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FToggle := AElement as Primitives_IToggleButton;
end;

function TWinUI2CheckBox.GetChecked: Boolean;
var
  LRefBoolean: IReference_1__Boolean;
begin
  LRefBoolean := FToggle.IsChecked;
  Result := Assigned(LRefBoolean) and LRefBoolean.Value;
end;

end.
