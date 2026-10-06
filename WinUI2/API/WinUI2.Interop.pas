unit WinUI2.Interop;

{
  COM interop that the generated WinRT bindings may or may not declare.
  Everything here has its OWN name (IXamlIsland...) so it can never clash with an
  IDesktopWindowXamlSourceNative that one of your generated units might already contain.
  Interface identity in COM is the IID, not the Delphi type name, so QueryInterface works.

  Declared with plain stdcall + HRESULT on purpose: no dependency on safecall mapping.
}

interface

uses
  Winapi.Windows;

type
  // xamlhostingsurface.h  (Windows 10 1903+)
  IXamlIslandNative = interface(IUnknown)
    ['{3CBCF1BF-2F76-4E9C-96AB-E84B37972554}']
    function AttachToWindow(AParentWnd: HWND): HRESULT; stdcall;
    function get_WindowHandle(out AWnd: HWND): HRESULT; stdcall;
  end;

  // Needed for Tab / arrow-key focus navigation inside the island.
  IXamlIslandNative2 = interface(IUnknown)
    ['{E3DCD8C7-3057-4692-99C3-7B7720AFDA31}']
    function PreTranslateMessage(const AMsg: PMsg; out AHandled: BOOL): HRESULT; stdcall;
  end;

implementation

end.
