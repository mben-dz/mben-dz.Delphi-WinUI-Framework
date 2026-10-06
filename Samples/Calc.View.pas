unit Calc.View;

{
  Calculator view: maps buttons / keyboard to TCalcEngine and engine state to the XAML.
  All logic lives in Calc.Engine; all layout and styling lives in Calc.Xaml.

  Views that share the area under the memory row (swapped into the "Host"):
    keypad   - the default
    panel    - history or memory list (History button / M-list button toggle it)
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.WinRT,
  WinUI.Controls,
  WinUI.Events,
  WinUI.Window,
  WinUI.Xaml,
  WinUI.Input,
  Calc.Engine,
  Calc.Xaml;

type
  TPanelMode = (pmNone, pmHistory, pmMemory);

  TCalcView = class
  private
    FWindow: TWinUIWindow;
    FEngine: TCalcEngine;
    FRoot: TWinUIFrameworkElement;
    FPanelRoot: TWinUIFrameworkElement;
    FItemTree: TWinUIFrameworkElement;
    FDisplay: TWinUITextBlock;
    FExpr: TWinUITextBlock;
    FPanelTitle: TWinUITextBlock;
    FHost: TWinUIContentHost;
    FListHost: TWinUIContentHost;
    FKeypad: IInspectable;     // kept alive while the panel is shown
    FPanel: IInspectable;
    FButtons: TObjectList<TWinUIButton>;   // keeps the wrappers alive for the window's lifetime
    FItems: TObjectList<TWinUIButton>;
    FSwitchButton: TWinUIButton;
    FMode: TPanelMode;
    FBusy: Boolean;
    function ElementOf(AObj: TWinUIFrameworkElement): IInspectable;
    procedure Wire(const AName: string; const AAction: TProc);
    procedure WireKey(const AName: string; AKey: Char);
    procedure WireItem(AIndex: Integer; AMode: TPanelMode);
    procedure BuildUI;
    procedure EngineChanged;
    procedure TogglePanel(AMode: TPanelMode);
    procedure OpenPanel(AMode: TPanelMode);
    procedure RefreshList;
    function HandleChar(ACh: WideChar): Boolean;
    function HandleKey(AVirtualKey: Word): Boolean;
    function GetRoot: TWinUIElement;
  public
    constructor Create(AWindow: TWinUIWindow);
    // Unhooks the keyboard and detaches the engine. The WinUI objects themselves are
    // deliberately not released here: the process ends right after the window closes.
    procedure Shutdown;
    property Root: TWinUIElement read GetRoot;
    property Engine: TCalcEngine read FEngine;
  end;

implementation

const
  cNumKeys = '0123456789';

constructor TCalcView.Create(AWindow: TWinUIWindow);
begin
  inherited Create;
  FWindow := AWindow;
  FEngine := TCalcEngine.Create;
  FButtons := TObjectList<TWinUIButton>.Create(True);
  FItems := TObjectList<TWinUIButton>.Create(True);
  BuildUI;
  FEngine.OnChanged := EngineChanged;
  EngineChanged;
  TWinUIInput.Install(HandleChar, HandleKey);
end;

procedure TCalcView.Shutdown;
begin
  TWinUIInput.Uninstall;
  FEngine.OnChanged := nil;
end;

function TCalcView.GetRoot: TWinUIElement;
begin
  Result := FRoot;
end;

function TCalcView.ElementOf(AObj: TWinUIFrameworkElement): IInspectable;
begin
  Result := AObj.Element;
end;

{ ---- wiring ---- }

procedure TCalcView.Wire(const AName: string; const AAction: TProc);
var
  B: TWinUIButton;
begin
  B := FRoot.FindButton(AName);
  FButtons.Add(B);
  B.OnClick(
    procedure(sender: IInspectable; e: IRoutedEventArgs)
    begin
      AAction();
    end);
end;

// A separate method so every closure captures its own AKey (not a shared loop variable).
procedure TCalcView.WireKey(const AName: string; AKey: Char);
begin
  Wire(AName,
    procedure
    begin
      FEngine.PressKey(AKey);
    end);
end;

procedure TCalcView.WireItem(AIndex: Integer; AMode: TPanelMode);
var
  B: TWinUIButton;
begin
  B := FItemTree.FindButton('I' + IntToStr(AIndex));
  FItems.Add(B);
  B.OnClick(
    procedure(sender: IInspectable; e: IRoutedEventArgs)
    begin
      // The list is not rebuilt while this handler runs (FBusy), then the keypad comes back.
      FBusy := True;
      try
        if AMode = pmHistory then
          FEngine.RecallHistoryItem(AIndex)
        else
          FEngine.RecallMemoryItem(AIndex);
      finally
        FBusy := False;
      end;
      OpenPanel(pmNone);
    end);
end;

procedure TCalcView.BuildUI;
var
  I: Integer;
begin
  FRoot := TWinUIXaml.LoadRoot(cMainXaml);
  FPanelRoot := TWinUIXaml.LoadRoot(cPanelXaml);

  FDisplay := FRoot.FindTextBlock('DisplayText');
  FExpr := FRoot.FindTextBlock('ExprText');
  FHost := FRoot.FindContentHost('Host');
  FKeypad := FRoot.FindName('KeypadGrid');
  FPanel := ElementOf(FPanelRoot);
  FPanelTitle := FPanelRoot.FindTextBlock('PanelTitle');
  FListHost := FPanelRoot.FindContentHost('ListHost');

  // digits and the decimal point
  for I := 1 to Length(cNumKeys) do
    WireKey('Btn' + cNumKeys[I], cNumKeys[I]);
  WireKey('BtnDot', '.');

  // operators
  WireKey('BtnAdd', '+');
  WireKey('BtnSub', '-');
  WireKey('BtnMul', '*');
  WireKey('BtnDiv', '/');
  WireKey('BtnEq', '=');

  // editing
  WireKey('BtnBack', #8);
  WireKey('BtnC', #27);
  Wire('BtnCE', procedure begin FEngine.PressClearEntry; end);
  Wire('BtnNeg', procedure begin FEngine.PressNegate; end);

  // other operations
  Wire('BtnPercent', procedure begin FEngine.PressPercent; end);
  Wire('BtnSqrt', procedure begin FEngine.PressSqrt; end);
  Wire('BtnSqr', procedure begin FEngine.PressSquare; end);
  Wire('BtnRecip', procedure begin FEngine.PressReciprocal; end);

  // memory row
  Wire('BtnMC', procedure begin FEngine.MemoryClear; end);
  Wire('BtnMR', procedure begin FEngine.MemoryRecall; end);
  Wire('BtnMPlus', procedure begin FEngine.MemoryAdd; end);
  Wire('BtnMMinus', procedure begin FEngine.MemorySubtract; end);
  Wire('BtnMS', procedure begin FEngine.MemoryStore; end);
  Wire('BtnMList', procedure begin TogglePanel(pmMemory); end);
  Wire('BtnHistory', procedure begin TogglePanel(pmHistory); end);

  // history / memory panel (separate XAML tree, so wired on FPanelRoot)
  FSwitchButton := FPanelRoot.FindButton('BtnSwitch');
  FSwitchButton.OnClick(
    procedure(sender: IInspectable; e: IRoutedEventArgs)
    begin
      if FMode = pmHistory then OpenPanel(pmMemory) else OpenPanel(pmHistory);
    end);
  FPanelRoot.FindButton('BtnClearList').OnClick(
    procedure(sender: IInspectable; e: IRoutedEventArgs)
    begin
      if FMode = pmHistory then FEngine.ClearHistory else FEngine.MemoryClear;
      RefreshList;
    end);
end;

{ ---- engine -> XAML ---- }

procedure TCalcView.EngineChanged;
begin
  FDisplay.Text(FEngine.DisplayValue);
  FExpr.Text(FEngine.ExpressionText);
  if (FMode <> pmNone) and (not FBusy) then
    RefreshList;
end;

procedure TCalcView.TogglePanel(AMode: TPanelMode);
begin
  if FMode = AMode then
    OpenPanel(pmNone)
  else
    OpenPanel(AMode);
end;

procedure TCalcView.OpenPanel(AMode: TPanelMode);
begin
  FMode := AMode;
  if AMode = pmNone then
    FHost.SetContent(FKeypad)
  else
  begin
    RefreshList;
    FHost.SetContent(FPanel);
  end;
end;

procedure TCalcView.RefreshList;
var
  Xaml: string;
  I, N: Integer;
  Primary, Secondary: string;
begin
  if FMode = pmNone then Exit;

  if FMode = pmHistory then
  begin
    FPanelTitle.Text('History');
    N := FEngine.HistoryCount;
  end
  else
  begin
    FPanelTitle.Text('Memory');
    N := FEngine.MemoryCount;
  end;

  Xaml := cListHead;
  if N = 0 then
  begin
    if FMode = pmHistory then
      Xaml := Xaml + '<TextBlock Text="There''s no history yet" Margin="12,8,12,0" Foreground="#C0C0C0" TextWrapping="Wrap"/>'
    else
      Xaml := Xaml + '<TextBlock Text="There''s nothing saved in memory" Margin="12,8,12,0" Foreground="#C0C0C0" TextWrapping="Wrap"/>';
  end
  else
    for I := 0 to N - 1 do
    begin
      if FMode = pmHistory then
      begin
        Primary := FEngine.HistoryExpression(I);
        Secondary := FEngine.HistoryResult(I);
      end
      else
      begin
        Primary := '';
        Secondary := FEngine.MemoryText(I);
      end;
      Xaml := Xaml + '<Button x:Name="I' + IntToStr(I) + '" Style="{StaticResource ItemKey}"><StackPanel>';
      if Primary <> '' then
        Xaml := Xaml + '<TextBlock Text="' + XmlEscape(Primary) + '" FontSize="13" Foreground="#C0C0C0" HorizontalAlignment="Right"/>';
      Xaml := Xaml + '<TextBlock Text="' + XmlEscape(Secondary) + '" FontSize="26" Foreground="#FFFFFF" HorizontalAlignment="Right"/>' +
        '</StackPanel></Button>';
    end;
  Xaml := Xaml + cListTail;

  // Replace the list. Old wrappers go first; XAML frees the old tree once Content changes.
  FItems.Clear;
  FreeAndNil(FItemTree);
  FItemTree := TWinUIXaml.LoadRoot(Xaml);
  FListHost.SetContent(ElementOf(FItemTree));
  for I := 0 to N - 1 do
    WireItem(I, FMode);

  if FMode = pmHistory then
    FSwitchButton.Content('Memory')
  else
    FSwitchButton.Content('History');
end;

{ ---- keyboard ---- }

function TCalcView.HandleChar(ACh: WideChar): Boolean;
begin
  Result := True;
  case ACh of
    #3: TWinUIInput.SetClipboardText(FWindow.Handle, FEngine.RawText);              // Ctrl+C
    #22: FEngine.PasteText(TWinUIInput.GetClipboardText(FWindow.Handle));           // Ctrl+V
  else
    Result := FEngine.PressKey(ACh);
  end;
end;

function TCalcView.HandleKey(AVirtualKey: Word): Boolean;
begin
  Result := True;
  case AVirtualKey of
    VK_RETURN: FEngine.PressEquals;
    VK_DELETE: FEngine.PressClearEntry;
    VK_ESCAPE: FEngine.PressClear;
    VK_F9: FEngine.PressNegate;
    VK_SPACE: ;   // swallowed so it cannot "click" a focused button
  else
    Result := False;
  end;
end;

end.
