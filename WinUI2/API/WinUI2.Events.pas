unit WinUI2.Events;

{
  Same API as your original unit. FIX: handler exceptions no longer travel back into XAML
  (a Delphi safecall exception becomes a failing HRESULT inside the XAML dispatcher,
  which can fail-fast the process), and Detach added (same as the WinUI 3 unit).
}

interface

uses
  System.SysUtils,
  Winapi.WinRT,
  Winapi.CommonTypes;

type
  Input_IPointerRoutedEventArgs = Winapi.CommonTypes.Input_IPointerRoutedEventArgs;
  IRoutedEventArgs = Winapi.CommonTypes.IRoutedEventArgs;

  TPointerEventProc = reference to procedure(sender: IInspectable; e: Input_IPointerRoutedEventArgs);
  TRoutedEventProc = reference to procedure(sender: IInspectable; e: IRoutedEventArgs);

  TPointerEventHandler = class(TInterfacedObject, Input_PointerEventHandler)
  private
    FProc: TPointerEventProc;
  public
    constructor Create(AProc: TPointerEventProc);
    procedure Invoke(sender: IInspectable; e: Input_IPointerRoutedEventArgs); safecall;
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

procedure ReportHandlerError(E: Exception);
begin
  OutputDebugString(PChar('WinUI2 handler error: ' + E.ClassName + ': ' + E.Message));
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
