unit WinUI.Controls;

{
  Fluent wrappers around the generated WinUI 3 bindings.

  Everything from the original framework is unchanged (TWinUIElement, TWinUIStackPanel,
  TWinUIButton, TWinUITextBlock and their fluent methods). Added:
    - Wrap constructors  : wrap an element that already exists (for example one found in XAML)
    - TWinUIContentHost  : get / set the Content of any ContentControl (swap views, ScrollViewer content)
    - TWinUIFrameworkElement : FindName / FindButton / FindTextBlock / FindContentHost

  Optional: define WINUI_CONTROL_ENABLED (project options > Conditional defines) to enable
  TWinUIButton.Enabled. It uses IControl.IsEnabled from the generated bindings; if your
  generated unit names that member differently, adjust the single line marked below.
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Foundation,
  Winapi.Microsoft.CommonTypes,
  Winapi.Microsoft.UI.Xaml.ControlsRT,
  WinUI.Events;

type
  IUIElement = Winapi.Microsoft.CommonTypes.IUIElement;
  IFrameworkElement = Winapi.Microsoft.CommonTypes.IFrameworkElement;
  HorizontalAlignment = Winapi.Microsoft.CommonTypes.HorizontalAlignment;
  VerticalAlignment = Winapi.Microsoft.CommonTypes.VerticalAlignment;
  Orientation = Winapi.Microsoft.UI.Xaml.ControlsRT.Orientation;

  TWinUIElement = class
  protected
    FElement: IUIElement;
  public
    constructor Create; overload; virtual;
    constructor Create(AElement: IUIElement); overload; virtual;
    property Element: IUIElement read FElement;
  end;

  TWinUIStackPanel = class(TWinUIElement)
  private
    FPanel: IStackPanel;
  public
    constructor Create; override;
    function Orientation(AValue: Orientation): TWinUIStackPanel;
    function HorizontalAlignment(AValue: HorizontalAlignment): TWinUIStackPanel;
    function VerticalAlignment(AValue: VerticalAlignment): TWinUIStackPanel;
    function Spacing(AValue: Double): TWinUIStackPanel;
    function Add(AChild: TWinUIElement): TWinUIStackPanel;
  end;

  TWinUIButton = class(TWinUIElement)
  private
    FButton: IButton;
  public
    constructor Create; override;
    // Wraps an existing Button (for example one created by XAML).
    constructor Wrap(AElement: IUIElement);
    function Content(const AText: string): TWinUIButton;
    function OnClick(AProc: TRoutedEventProc): TWinUIButton;
    {$IFDEF WINUI_CONTROL_ENABLED}
    function Enabled(AValue: Boolean): TWinUIButton;
    {$ENDIF}
  end;

  TWinUITextBlock = class(TWinUIElement)
  private
    FTextBlock: ITextBlock;
  public
    constructor Create; override;
    // Wraps an existing TextBlock (for example one created by XAML).
    constructor Wrap(AElement: IUIElement);
    function Text(const AText: string): TWinUITextBlock;
    function FontSize(AValue: Double): TWinUITextBlock;
  end;

  // Any ContentControl (ContentControl, ScrollViewer, Button, ...): read / replace its Content.
  TWinUIContentHost = class(TWinUIElement)
  private
    FHost: IContentControl;
  public
    constructor Wrap(AElement: IUIElement);
    procedure SetContent(const AContent: IInspectable);
    function GetContent: IInspectable;
    // FrameworkElement.Width in DIPs (0 collapses the host, used to dock / hide a side panel).
    function Width(AValue: Double): TWinUIContentHost;
  end;

  // A FrameworkElement that can look up named children (x:Name in XAML).
  TWinUIFrameworkElement = class(TWinUIElement)
  public
    function FindName(const AName: string): IInspectable;
    function FindElement(const AName: string): IUIElement;
    function FindButton(const AName: string): TWinUIButton;
    function FindTextBlock(const AName: string): TWinUITextBlock;
    function FindContentHost(const AName: string): TWinUIContentHost;
  end;

implementation

uses Winapi.Windows;

function CreateString(const AStr: string): IInspectable;
begin
  Result := TPropertyValue.CreateString(TWindowsString(AStr)) as IInspectable;
end;

{ TWinUIElement }

constructor TWinUIElement.Create;
begin
end;

constructor TWinUIElement.Create(AElement: IUIElement);
begin
  FElement := AElement;
end;

{ TWinUIStackPanel }

constructor TWinUIStackPanel.Create;
begin
  inherited Create;
  FPanel := TStackPanel.Create;
  FElement := FPanel as IUIElement;
end;

function TWinUIStackPanel.Orientation(AValue: Orientation): TWinUIStackPanel;
begin
  FPanel.Orientation_ := AValue;
  Result := Self;
end;

function TWinUIStackPanel.HorizontalAlignment(AValue: HorizontalAlignment): TWinUIStackPanel;
begin
  (FPanel as IFrameworkElement).HorizontalAlignment_ := AValue;
  Result := Self;
end;

function TWinUIStackPanel.VerticalAlignment(AValue: VerticalAlignment): TWinUIStackPanel;
begin
  (FPanel as IFrameworkElement).VerticalAlignment_ := AValue;
  Result := Self;
end;

function TWinUIStackPanel.Spacing(AValue: Double): TWinUIStackPanel;
begin
  FPanel.Spacing := AValue;
  Result := Self;
end;

function TWinUIStackPanel.Add(AChild: TWinUIElement): TWinUIStackPanel;
var
  Children: Winapi.Microsoft.CommonTypes.IVector_1__IUIElement;
begin
  Children := (FPanel as IPanel)
    .Children as Winapi.Microsoft.CommonTypes.IVector_1__IUIElement; //IVector_1__IUIElement_Base;
  Children.Append(AChild.Element);
  Result := Self;
end;

{ TWinUIButton }

constructor TWinUIButton.Create;
begin
  inherited Create;
  FButton := TButton.Create;
  FElement := FButton as IUIElement;
end;

constructor TWinUIButton.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FButton := AElement as IButton;
end;

function TWinUIButton.Content(const AText: string): TWinUIButton;
begin
  (FButton as IContentControl).Content := CreateString(AText);
  Result := Self;
end;

function TWinUIButton.OnClick(AProc: TRoutedEventProc): TWinUIButton;
begin
  (FButton as Primitives_IButtonBase).add_Click(TClickEventHandler.Create(AProc));
  Result := Self;
end;

{$IFDEF WINUI_CONTROL_ENABLED}
function TWinUIButton.Enabled(AValue: Boolean): TWinUIButton;
begin
  (FButton as IControl).IsEnabled := AValue;   // <- adjust if your binding names it differently
  Result := Self;
end;
{$ENDIF}

{ TWinUITextBlock }

constructor TWinUITextBlock.Create;
begin
  inherited Create;
  FTextBlock := TTextBlock.Create;
  FElement := FTextBlock as IUIElement;
end;

constructor TWinUITextBlock.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FTextBlock := AElement as ITextBlock;
end;

function TWinUITextBlock.Text(const AText: string): TWinUITextBlock;
begin
  FTextBlock.Text := TWindowsString(AText);
  Result := Self;
end;

function TWinUITextBlock.FontSize(AValue: Double): TWinUITextBlock;
begin
  FTextBlock.FontSize := AValue;
  Result := Self;
end;

{ TWinUIContentHost }

constructor TWinUIContentHost.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FHost := AElement as IContentControl;
end;

procedure TWinUIContentHost.SetContent(const AContent: IInspectable);
begin
  FHost.Content := AContent;
end;

function TWinUIContentHost.GetContent: IInspectable;
begin
  Result := FHost.Content;
end;

function TWinUIContentHost.Width(AValue: Double): TWinUIContentHost;
begin
  (FElement as IFrameworkElement).Width := AValue;
  Result := Self;
end;

{ TWinUIFrameworkElement }

function TWinUIFrameworkElement.FindName(const AName: string): IInspectable;
begin
  Result := (FElement as IFrameworkElement).FindName(TWindowsString(AName));
end;

function TWinUIFrameworkElement.FindElement(const AName: string): IUIElement;
var
  Obj: IInspectable;
begin
  Obj := FindName(AName);
  if Obj = nil then
    raise Exception.CreateFmt('XAML element "%s" was not found.', [AName]);
  Result := Obj as IUIElement;
end;

function TWinUIFrameworkElement.FindButton(const AName: string): TWinUIButton;
begin
  Result := TWinUIButton.Wrap(FindElement(AName));
end;

function TWinUIFrameworkElement.FindTextBlock(const AName: string): TWinUITextBlock;
begin
  Result := TWinUITextBlock.Wrap(FindElement(AName));
end;

function TWinUIFrameworkElement.FindContentHost(const AName: string): TWinUIContentHost;
begin
  Result := TWinUIContentHost.Wrap(FindElement(AName));
end;

end.
