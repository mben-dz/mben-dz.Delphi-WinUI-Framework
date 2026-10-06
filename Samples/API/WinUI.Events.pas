unit WinUI.Events;

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  Winapi.Microsoft.CommonTypes;

type
  Input_IPointerRoutedEventArgs = Winapi.Microsoft.CommonTypes.Input_IPointerRoutedEventArgs;
  IRoutedEventArgs = Winapi.Microsoft.CommonTypes.IRoutedEventArgs;

  TPointerEventProc = reference to procedure(sender: IInspectable; e: Input_IPointerRoutedEventArgs);
  TRoutedEventProc = reference to procedure(sender: IInspectable; e: IRoutedEventArgs);

  TPointerEventHandler = class(TInterfacedObject, Input_PointerEventHandler)
  private
    FProc: TPointerEventProc;
  public
    constructor Create(AProc: TPointerEventProc);
    procedure Invoke(sender: IInspectable; e: Input_IPointerRoutedEventArgs); safecall;
    // Drops the Delphi closure; the handler stays registered in XAML but does nothing.
    procedure Detach;
  end;

  TClickEventHandler = class(TInterfacedObject, RoutedEventHandler)
  private
    FProc: TRoutedEventProc;
  public
    constructor Create(AProc: TRoutedEventProc);
    procedure Invoke(sender: IInspectable; e: IRoutedEventArgs); safecall;
    procedure Detach;
  end;

implementation

uses
  Winapi.Windows;

// An exception must never travel back into XAML from a handler:
// it would surface as a fail-fast. Report it to the debugger instead.
procedure ReportHandlerError(E: Exception);
begin
  OutputDebugString(PChar('WinUI handler error: ' + E.ClassName + ': ' + E.Message));
end;

{ TPointerEventHandler }

constructor TPointerEventHandler.Create(AProc: TPointerEventProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TPointerEventHandler.Detach;
begin
  FProc := nil;
end;

procedure TPointerEventHandler.Invoke(sender: IInspectable; e: Input_IPointerRoutedEventArgs);
begin
  try
    if Assigned(FProc) then FProc(sender, e);
  except
    on E: Exception do ReportHandlerError(E);
  end;
end;

{ TClickEventHandler }

constructor TClickEventHandler.Create(AProc: TRoutedEventProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TClickEventHandler.Detach;
begin
  FProc := nil;
end;

procedure TClickEventHandler.Invoke(sender: IInspectable; e: IRoutedEventArgs);
begin
  try
    if Assigned(FProc) then FProc(sender, e);
  except
    on E: Exception do ReportHandlerError(E);
  end;
end;

end.
