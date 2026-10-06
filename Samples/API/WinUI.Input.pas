unit WinUI.Input;

{
  Keyboard and clipboard helpers that need no WinRT bindings.

  Keyboard: a thread-level WH_GETMESSAGE hook on the UI thread sees every WM_CHAR /
  WM_KEYDOWN before XAML does. WM_CHAR carries the *character* the user typed, so
  shortcuts are independent of the keyboard layout (AZERTY digits need Shift:
  the hook still receives '1'). Handled messages are turned into WM_NULL.

  Clipboard: plain Win32 CF_UNICODETEXT. The window handle is required as owner,
  otherwise SetClipboardData fails after EmptyClipboard.
}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils;

type
  // Return True when the character / key was handled (the message is then swallowed).
  TWinUICharProc = reference to function(ACh: WideChar): Boolean;
  TWinUIKeyProc = reference to function(AVirtualKey: Word): Boolean;

  TWinUIInput = class
  public
    // Call on the UI thread (for example from OnLaunched).
    class procedure Install(const AOnChar: TWinUICharProc; const AOnKey: TWinUIKeyProc);
    class procedure Uninstall;
    class function GetClipboardText(AOwner: HWND): string;
    class procedure SetClipboardText(AOwner: HWND; const AText: string);
  end;

implementation

var
  GHook: HHOOK;
  GOnChar: TWinUICharProc;
  GOnKey: TWinUIKeyProc;

function GetMsgHook(ACode: Integer; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  M: PMsg;
begin
  if (ACode = HC_ACTION) and (AWParam = PM_REMOVE) then
  begin
    M := PMsg(ALParam);
    try
      case M^.message of
        WM_CHAR:
          if Assigned(GOnChar) and GOnChar(WideChar(M^.wParam)) then
            M^.message := WM_NULL;
        WM_KEYDOWN:
          if Assigned(GOnKey) and GOnKey(Word(M^.wParam)) then
            M^.message := WM_NULL;
        WM_KEYUP:
          // Enter / Space would otherwise "click" a focused button on key-up
          if (M^.wParam = VK_RETURN) or (M^.wParam = VK_SPACE) then
            M^.message := WM_NULL;
      end;
    except
      // never let a Delphi exception cross the hook boundary
    end;
  end;
  Result := CallNextHookEx(GHook, ACode, AWParam, ALParam);
end;

{ TWinUIInput }

class procedure TWinUIInput.Install(const AOnChar: TWinUICharProc; const AOnKey: TWinUIKeyProc);
begin
  GOnChar := AOnChar;
  GOnKey := AOnKey;
  if GHook = 0 then
    GHook := SetWindowsHookEx(WH_GETMESSAGE, @GetMsgHook, 0, GetCurrentThreadId);
end;

class procedure TWinUIInput.Uninstall;
begin
  if GHook <> 0 then
  begin
    UnhookWindowsHookEx(GHook);
    GHook := 0;
  end;
  GOnChar := nil;
  GOnKey := nil;
end;

class function TWinUIInput.GetClipboardText(AOwner: HWND): string;
var
  H: THandle;
  P: PWideChar;
begin
  Result := '';
  if not OpenClipboard(AOwner) then Exit;
  try
    H := GetClipboardData(CF_UNICODETEXT);
    if H <> 0 then
    begin
      P := GlobalLock(H);
      if P <> nil then
        try
          Result := P;
        finally
          GlobalUnlock(H);
        end;
    end;
  finally
    CloseClipboard;
  end;
end;

class procedure TWinUIInput.SetClipboardText(AOwner: HWND; const AText: string);
var
  H: HGLOBAL;
  P: PWideChar;
  Bytes: NativeInt;
begin
  Bytes := (Length(AText) + 1) * SizeOf(WideChar);
  H := GlobalAlloc(GMEM_MOVEABLE, Bytes);
  if H = 0 then Exit;
  P := GlobalLock(H);
  if P = nil then
  begin
    GlobalFree(H);
    Exit;
  end;
  Move(PWideChar(AText)^, P^, Bytes);   // includes the terminating #0
  GlobalUnlock(H);
  if OpenClipboard(AOwner) then
  begin
    try
      EmptyClipboard;
      if SetClipboardData(CF_UNICODETEXT, H) = 0 then
        GlobalFree(H);
    finally
      CloseClipboard;
    end;
  end
  else
    GlobalFree(H);
end;

end.
