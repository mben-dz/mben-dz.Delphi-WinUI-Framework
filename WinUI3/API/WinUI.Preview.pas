unit WinUI.Preview;

{
  Runtime XAML preview with hot reload (a poor man's XAML Designer + Hot Reload).

    TWinUIPreview.Show('C:\path\LoginPage.xaml');
    or start the exe with:   WinUI3LoginDemo.exe /preview C:\path\LoginPage.xaml

  The file is polled twice a second; every time it is saved the XAML is parsed again and
  swapped into the preview window. A parse error does NOT kill the window: the last good view
  stays and the error (with line / position when the parser gives it) is shown in a red bar.
  Handlers are not wired in preview mode - it is for layout, colours, styles and templates.
  The marker %LUM% used by Login.Pages is removed automatically.
}

interface

type
  TWinUIPreview = class
  public
    class procedure Show(const AXamlFile: string);
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  WinUI.Controls,
  WinUI.Window,
  WinUI.Xaml,
  WinUI.Icon;

const
  cShell = '''
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Background="#FF202020">
  <ContentControl x:Name="View" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"/>
  <ContentControl x:Name="ErrBar" Width="0" HorizontalAlignment="Stretch" VerticalAlignment="Bottom"
                  HorizontalContentAlignment="Stretch" Background="#F0B00020" Padding="12,8">
    <TextBlock x:Name="ErrText" Foreground="White" FontSize="12" TextWrapping="Wrap" IsTextSelectionEnabled="True"/>
  </ContentControl>
  <TextBlock x:Name="Stamp" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,6,12,0"
             Foreground="#99FFFFFF" FontSize="11" IsHitTestVisible="False"/>
</Grid>
''';

type
  TPreviewState = class
    Window: TWinUIWindow;
    Root: TWinUIFrameworkElement;
    Host: TWinUIContentHost;
    ErrBar: TWinUIContentHost;
    ErrText: TWinUITextBlock;
    Stamp: TWinUITextBlock;
    FileName: string;
    LastWrite: TDateTime;
    Busy: Boolean;
    procedure Reload;
  end;

var
  GState: TPreviewState;

function ReadSharedText(const AFile: string): string;
var
  FS: TFileStream;
  SS: TStringStream;
begin
  // the editor may still hold the file: open with full sharing
  FS := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SS := TStringStream.Create('', TEncoding.UTF8);
    try
      SS.CopyFrom(FS, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  finally
    FS.Free;
  end;
end;

procedure TPreviewState.Reload;
var
  Xml: string;
  Page: TWinUIElement;
begin
  try
    Xml := StringReplace(ReadSharedText(FileName), '%LUM%', '', [rfReplaceAll]);
    Page := TWinUIXaml.Load(Xml);
    Host.SetContent(Page.Element);
    ErrBar.Width(0);
    Stamp.Text('reloaded ' + FormatDateTime('hh:nn:ss', Now));
  except
    on E: Exception do
    begin
      ErrText.Text(E.Message);
      ErrBar.Width(NaN);
      Stamp.Text('error ' + FormatDateTime('hh:nn:ss', Now));
    end;
  end;
end;

procedure TimerProc(AWnd: HWND; AMsg: UINT; AId: UINT_PTR; ATime: DWORD); stdcall;
var
  T: TDateTime;
begin
  if (GState = nil) or GState.Busy then Exit;
  GState.Busy := True;
  try
    if FileExists(GState.FileName) then
    begin
      T := TFile.GetLastWriteTime(GState.FileName);
      if T <> GState.LastWrite then
      begin
        GState.LastWrite := T;
        Sleep(60);               // let the editor finish writing
        GState.Reload;
      end;
    end;
  finally
    GState.Busy := False;
  end;
end;

class procedure TWinUIPreview.Show(const AXamlFile: string);
begin
  if not FileExists(AXamlFile) then
    raise EFileNotFoundException.CreateFmt('XAML file not found: %s', [AXamlFile]);
  GState := TPreviewState.Create;
  with GState do
  begin
    FileName := ExpandFileName(AXamlFile);
    Window := TWinUIWindow.Create;
    Window.Title('XAML Preview - ' + ExtractFileName(FileName));
    Root := TWinUIXaml.LoadRoot(cShell);
    Host := Root.FindContentHost('View');
    ErrBar := Root.FindContentHost('ErrBar');
    ErrText := Root.FindTextBlock('ErrText');
    Stamp := Root.FindTextBlock('Stamp');
    Window.SetContent(Root);
    Window.ClientSize(1000, 700).MinSize(320, 240).Center.Mica;
    Window.Activate;
    SetWindowIcon(Window.Handle);
    LastWrite := 0;
  end;
  // WM_TIMER is delivered on the UI thread by WinUI's own message loop
  SetTimer(0, 0, 500, @TimerProc);
end;

end.
