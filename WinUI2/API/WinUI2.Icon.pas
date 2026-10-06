unit WinUI2.Icon;

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
  LBig, LSmall: HICON;
begin
  if AWnd = 0 then Exit;
  LBig := LoadImage(HInstance, PChar(AResourceName), IMAGE_ICON,
    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR);
  LSmall := LoadImage(HInstance, PChar(AResourceName), IMAGE_ICON,
    GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
  if LBig <> 0 then SendMessage(AWnd, WM_SETICON, ICON_BIG, LPARAM(LBig));
  if LSmall <> 0 then SendMessage(AWnd, WM_SETICON, ICON_SMALL, LPARAM(LSmall));
end;

end.
