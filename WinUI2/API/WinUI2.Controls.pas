unit WinUI2.Controls;

{
  Fluent wrappers around the generated Windows.UI.Xaml (WinUI 2 / inbox UWP XAML) bindings.

  Everything from your original unit is kept as it was (TWinUI2Element, TWinUI2StackPanel,
  TWinUI2Button, TWinUI2TextBlock, TWinUI2XamlContainer). Marked  // +ADDED  :
    - Wrap constructors for Button / TextBlock (elements that already exist, e.g. from XAML)
    - TWinUI2ContentHost       : get / set Content of any ContentControl (page swapping)
    - TWinUI2FrameworkElement  : FindName / FindElement / FindButton / FindTextBlock / FindContentHost
    - TWinUI2Button.Enabled    : IControl.IsEnabled
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  System.Win.WinRT,
  Winapi.Foundation,
  Winapi.CommonTypes,
  Winapi.UI.Xaml.ControlsRT,
  WinUI2.Events;

type
  IUIElement          = Winapi.CommonTypes.IUIElement;
  IFrameworkElement   = Winapi.CommonTypes.IFrameworkElement;
  HorizontalAlignment = Winapi.CommonTypes.HorizontalAlignment;
  VerticalAlignment   = Winapi.CommonTypes.VerticalAlignment;
  Orientation         = Winapi.UI.Xaml.ControlsRT.Orientation;

  { -- Base element wrapper ------------------------------------------- }
  TWinUI2Element = class
  protected
    FElement: IUIElement;
  public
    constructor Create; overload; virtual;
    constructor Create(AElement: IUIElement); overload; virtual;
    property Element: IUIElement read FElement;
  end;

  { -- StackPanel ----------------------------------------------------- }
  TWinUI2StackPanel = class(TWinUI2Element)
  private
    FPanel: IStackPanel;
  public
    constructor Create; override;
    function Orientation(AValue: Orientation): TWinUI2StackPanel;
    function HorizontalAlignment(AValue: HorizontalAlignment): TWinUI2StackPanel;
    function VerticalAlignment(AValue: VerticalAlignment): TWinUI2StackPanel;
    function Spacing(AValue: Double): TWinUI2StackPanel;
    function Add(AChild: TWinUI2Element): TWinUI2StackPanel;
  end;

  { -- Button --------------------------------------------------------- }
  TWinUI2Button = class(TWinUI2Element)
  private
    FButton: IButton;
  public
    constructor Create; override;
    constructor Wrap(AElement: IUIElement);                       // +ADDED
    function Content(const AText: string): TWinUI2Button;
    function OnClick(AProc: TRoutedEventProc): TWinUI2Button;
    function Enabled(AValue: Boolean): TWinUI2Button;             // +ADDED
  end;

  { -- TextBlock (extended with pointer hover) ------------------------ }
  TWinUI2TextBlock = class(TWinUI2Element)
  private
    FTextBlock: ITextBlock;
  public
    constructor Create; override;
    constructor Wrap(AElement: IUIElement);                       // +ADDED
    function Text(const AText: string): TWinUI2TextBlock;
    function FontSize(AValue: Double): TWinUI2TextBlock;
    function OnPointerEntered(AProc: TPointerEventProc): TWinUI2TextBlock;
    function OnPointerExited(AProc: TPointerEventProc): TWinUI2TextBlock;
  end;

  { Any ContentControl: read / replace its Content --------- }
  TWinUI2ContentHost = class(TWinUI2Element)
  private
    FHost: IContentControl;
  public
    constructor Wrap(AElement: IUIElement);
    procedure SetContent(const AContent: IInspectable);
    function GetContent: IInspectable;
  end;

  { FrameworkElement that can look up x:Name children ------ }
  TWinUI2FrameworkElement = class(TWinUI2Element)
  public
    function FindName(const AName: string): IInspectable;
    function FindElement(const AName: string): IUIElement;
    function FindButton(const AName: string): TWinUI2Button;
    function FindTextBlock(const AName: string): TWinUI2TextBlock;
    function FindContentHost(const AName: string): TWinUI2ContentHost;
  end;

  { -- XAML container - wraps a XAML-loaded root element ------------- }
  TWinUI2XamlContainer = class(TWinUI2Element)
  private
    FRoot: IFrameworkElement;
  public
    constructor Create(AElement: IUIElement); override;
    procedure WireButton(const AName: string; AProc: TRoutedEventProc);
    procedure SetText(const AName, AText: string);
    function FindElement(const AName: string): IInspectable;
  end;

implementation

uses Winapi.Windows;

function MakeString(const S: string): IInspectable;
begin
  Result := TPropertyValue.CreateString(TWindowsString(S)) as IInspectable;
end;

{ TWinUI2Element }

constructor TWinUI2Element.Create;
begin
end;

constructor TWinUI2Element.Create(AElement: IUIElement);
begin
  FElement := AElement;
end;

{ TWinUI2StackPanel }

constructor TWinUI2StackPanel.Create;
begin
  inherited Create;
  FPanel   := TStackPanel.Create;
  FElement := FPanel as IUIElement;
end;

function TWinUI2StackPanel.Orientation(AValue: Orientation): TWinUI2StackPanel;
begin
  FPanel.Orientation_ := AValue;
  Result := Self;
end;

function TWinUI2StackPanel.HorizontalAlignment(AValue: HorizontalAlignment): TWinUI2StackPanel;
begin
  (FPanel as IFrameworkElement).HorizontalAlignment_ := AValue;
  Result := Self;
end;

function TWinUI2StackPanel.VerticalAlignment(AValue: VerticalAlignment): TWinUI2StackPanel;
begin
  (FPanel as IFrameworkElement).VerticalAlignment_ := AValue;
  Result := Self;
end;

function TWinUI2StackPanel.Spacing(AValue: Double): TWinUI2StackPanel;
begin
  (FPanel as IStackPanel4).Spacing := AValue;   // StackPanel.Spacing: Windows 10 1703+
  Result := Self;
end;

function TWinUI2StackPanel.Add(AChild: TWinUI2Element): TWinUI2StackPanel;
var
  LVectorUIElmnt: Winapi.CommonTypes.IVector_1__IUIElement;
begin
  LVectorUIElmnt := (FPanel as IPanel).Children as Winapi.CommonTypes.IVector_1__IUIElement;
  LVectorUIElmnt.Append(AChild.Element);
  Result := Self;
end;

{ TWinUI2Button }

constructor TWinUI2Button.Create;
begin
  inherited Create;
  FButton  := TButton.Create;
  FElement := FButton as IUIElement;
end;

constructor TWinUI2Button.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FButton := AElement as IButton;
end;

function TWinUI2Button.Content(const AText: string): TWinUI2Button;
begin
  (FButton as IContentControl).Content := MakeString(AText);
  Result := Self;
end;

function TWinUI2Button.OnClick(AProc: TRoutedEventProc): TWinUI2Button;
begin
  (FButton as Primitives_IButtonBase).add_Click(TClickEventHandler.Create(AProc));
  Result := Self;
end;

function TWinUI2Button.Enabled(AValue: Boolean): TWinUI2Button;
begin
  (FButton as IControl).IsEnabled := AValue;   // adjust here if your binding names it differently
  Result := Self;
end;

{ TWinUI2TextBlock }

constructor TWinUI2TextBlock.Create;
begin
  inherited Create;
  FTextBlock := TTextBlock.Create;
  FElement   := FTextBlock as IUIElement;
end;

constructor TWinUI2TextBlock.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FTextBlock := AElement as ITextBlock;
end;

function TWinUI2TextBlock.Text(const AText: string): TWinUI2TextBlock;
begin
  FTextBlock.Text := TWindowsString(AText);
  Result := Self;
end;

function TWinUI2TextBlock.FontSize(AValue: Double): TWinUI2TextBlock;
begin
  FTextBlock.FontSize := AValue;
  Result := Self;
end;

function TWinUI2TextBlock.OnPointerEntered(AProc: TPointerEventProc): TWinUI2TextBlock;
begin
  FElement.add_PointerEntered(TPointerEventHandler.Create(AProc));
  Result := Self;
end;

function TWinUI2TextBlock.OnPointerExited(AProc: TPointerEventProc): TWinUI2TextBlock;
begin
  FElement.add_PointerExited(TPointerEventHandler.Create(AProc));
  Result := Self;
end;

{ TWinUI2ContentHost }

constructor TWinUI2ContentHost.Wrap(AElement: IUIElement);
begin
  inherited Create(AElement);
  FHost := AElement as IContentControl;
end;

procedure TWinUI2ContentHost.SetContent(const AContent: IInspectable);
begin
  FHost.Content := AContent;
end;

function TWinUI2ContentHost.GetContent: IInspectable;
begin
  Result := FHost.Content;
end;

{ TWinUI2FrameworkElement }

function TWinUI2FrameworkElement.FindName(const AName: string): IInspectable;
begin
  Result := (FElement as IFrameworkElement).FindName(TWindowsString(AName));
end;

function TWinUI2FrameworkElement.FindElement(const AName: string): IUIElement;
var
  LInspObj: IInspectable;
begin
  LInspObj := FindName(AName);
  if LInspObj = nil then
    raise Exception.CreateFmt('XAML element "%s" was not found.', [AName]);
  Result := LInspObj as IUIElement;
end;

function TWinUI2FrameworkElement.FindButton(const AName: string): TWinUI2Button;
begin
  Result := TWinUI2Button.Wrap(FindElement(AName));
end;

function TWinUI2FrameworkElement.FindTextBlock(const AName: string): TWinUI2TextBlock;
begin
  Result := TWinUI2TextBlock.Wrap(FindElement(AName));
end;

function TWinUI2FrameworkElement.FindContentHost(const AName: string): TWinUI2ContentHost;
begin
  Result := TWinUI2ContentHost.Wrap(FindElement(AName));
end;

{ TWinUI2XamlContainer }

constructor TWinUI2XamlContainer.Create(AElement: IUIElement);
begin
  inherited Create(AElement);
  FRoot := AElement as IFrameworkElement;
end;

procedure TWinUI2XamlContainer.WireButton(const AName: string; AProc: TRoutedEventProc);
var
  LInsp: IInspectable;
begin
  LInsp := FRoot.FindName(TWindowsString(AName));
  if LInsp = nil then
    Exit;
  (LInsp as Primitives_IButtonBase).add_Click(TClickEventHandler.Create(AProc));
end;

procedure TWinUI2XamlContainer.SetText(const AName, AText: string);
var
  LInsp: IInspectable;
begin
  LInsp := FRoot.FindName(TWindowsString(AName));
  if LInsp <> nil then
    (LInsp as ITextBlock).Text := TWindowsString(AText);
end;

function TWinUI2XamlContainer.FindElement(const AName: string): IInspectable;
begin
  Result := FRoot.FindName(TWindowsString(AName));
end;

end.
