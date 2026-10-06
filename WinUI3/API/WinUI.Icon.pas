unit WinUI.Icon;

{
  Gives a WinUI window the application icon (title bar + taskbar + Alt-Tab).
  The icon comes from the MAINICON resource that Delphi links from
  Project > Options > Application > Icons. WinUI windows do not pick it up by themselves.
}

interface

uses
  Winapi.Windows,
  Winapi.Messages;

procedure SetWindowIcon(AWnd: HWND; const AResourceName: string = 'MAINICON');

implementation

procedure SetWindowIcon(AWnd: HWND; const AResourceName: string);
var
  Big, Small: HICON;
begin
  if AWnd = 0 then Exit;
  Big := LoadImage(HInstance, PChar(AResourceName), IMAGE_ICON,
    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR);
  Small := LoadImage(HInstance, PChar(AResourceName), IMAGE_ICON,
    GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
  if Big <> 0 then SendMessage(AWnd, WM_SETICON, ICON_BIG, LPARAM(Big));
  if Small <> 0 then SendMessage(AWnd, WM_SETICON, ICON_SMALL, LPARAM(Small));
end;

end.
