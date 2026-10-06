unit WinUI.Core;

interface

uses
  System.SysUtils,
  System.Win.WinRT,
  Winapi.WinRT,
  Winapi.Microsoft.UI.Xaml,
  Winapi.ApplicationModel;

type
  TWinUIApp = class(TInspectableObject, IApplicationOverrides)
  private
    FInner: IApplicationOverrides;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnLaunched(args: ILaunchActivatedEventArgs); virtual; safecall;
    property Inner: IApplicationOverrides read FInner write FInner;
  end;

  TWinUIAppClass = class of TWinUIApp;

  TWinUI = class
  public
    class procedure Run(AAppClass: TWinUIAppClass);
    // The Application instance created by Run (valid from OnLaunched on).
    class function Application: IApplication;
  end;

implementation

var
  GAppInner: IInspectable;
  GAppOuter: IApplicationOverrides;
  GAppWrapper: IApplication;

type
  TCallbackProc = reference to procedure (p: IApplicationInitializationCallbackParams) safecall;

{ TWinUIApp }

constructor TWinUIApp.Create;
begin
  inherited;
end;

destructor TWinUIApp.Destroy;
begin
  inherited;
end;

procedure TWinUIApp.OnLaunched(args: ILaunchActivatedEventArgs);
begin
  if Assigned(FInner) then
    FInner.OnLaunched(args);
end;

{ TWinUI }

class function TWinUI.Application: IApplication;
begin
  Result := GAppWrapper;
end;

class procedure TWinUI.Run(AAppClass: TWinUIAppClass);
begin
  var LCallbackProc: TCallbackProc :=
  procedure (p: IApplicationInitializationCallbackParams) safecall
    var
      Outer: TWinUIApp;
      Factory: IApplicationFactory;
    begin
      Outer := AAppClass.Create;
      GAppOuter := Outer as IApplicationOverrides;
      Factory := TApplication.Factory;
      GAppWrapper := Factory.CreateInstance(GAppOuter, GAppInner);
      Outer.Inner := GAppInner as IApplicationOverrides;
    end;

  var AppInitCallback := ApplicationInitializationCallback(LCallbackProc);
  TApplication.Start(AppInitCallback);
  GAppWrapper := nil;
end;

end.
