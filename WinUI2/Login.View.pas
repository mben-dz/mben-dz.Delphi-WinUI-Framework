unit Login.View;

{
  Login / register / reset-password flow on top of the WinUI2 wrappers.
  Same behaviour as WinUI3LoginDemo. Differences:
    - TWinUI2Window (XAML Islands) instead of the WinUI 3 window; no custom title bar
    - wrapper objects created by Find*/Wrap are always freed (the WinUI 3 view leaked one per lookup)
    - pages are freed in the destructor
}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.StrUtils,
  Winapi.WinRT,
  WinUI2.Controls,
  WinUI2.Inputs,
  WinUI2.Events,
  WinUI2.Window,
  WinUI2.Xaml,
  WinUI2.Navigation,
  WinUI2.Icon,
  Login.Auth,
  Login.Xaml,
  Login.Pages;

type
  TLoginView = class
  private
    FWindow: TWinUI2Window;
    FRoot: TWinUI2FrameworkElement;
    FPages: TWinUI2PageHost;
    FAuth: TAuthStore;
    FLoginPage: TWinUI2FrameworkElement;
    FRegisterPage: TWinUI2FrameworkElement;
    FForgotPage: TWinUI2FrameworkElement;
    // control access (every helper frees its temporary wrapper)
    function GetText(APage: TWinUI2FrameworkElement; const AName: string): string;
    procedure SetText(APage: TWinUI2FrameworkElement; const AName, AValue: string);
    function GetPassword(APage: TWinUI2FrameworkElement; const AName: string): string;
    procedure ClearPassword(APage: TWinUI2FrameworkElement; const AName: string);
    function IsChecked(APage: TWinUI2FrameworkElement; const AName: string): Boolean;
    procedure Say(APage: TWinUI2FrameworkElement; const AText: string);
    procedure Wire(APage: TWinUI2FrameworkElement; const AName: string; const AAction: TProc);
    function LoadPage(const AXaml: string): TWinUI2FrameworkElement;
    // navigation
    procedure ShowLogin;
    procedure ShowRegister;
    procedure ShowForgot;
    procedure BackToLogin;
    // actions
    procedure DoLogin;
    procedure DoRegister;
    procedure DoResetPassword;
    function GetAppDataPath: string;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

const
  cAppTitle = 'WinUI 2 Login Demo';

constructor TLoginView.Create;
begin
  inherited Create;
  FWindow := TWinUI2Window.Create(cAppTitle, 900, 640);
  FWindow.DarkFrame(True).MinSize(420, 600);

  FRoot := TWinUI2Xaml.LoadRoot(cLoginXaml);
  FPages := TWinUI2PageHost.Wrap(FRoot.FindElement('PageHost'));

  try
    FAuth := TAuthStore.Create(TPath.Combine(GetAppDataPath, 'login_demo.db'));
  except
    on E: Exception do
      FAuth := nil;   // pages report "Database unavailable"
  end;

  FLoginPage := LoadPage(cLoginPageXaml);
  FRegisterPage := LoadPage(cRegisterPageXaml);
  FForgotPage := LoadPage(cForgotPageXaml);

  Wire(FLoginPage, 'LoginButton', DoLogin);
  Wire(FLoginPage, 'RegisterButton', ShowRegister);
  Wire(FLoginPage, 'ForgotButton', ShowForgot);

  Wire(FRegisterPage, 'RegisterButton', DoRegister);
  Wire(FRegisterPage, 'BackButton', BackToLogin);

  Wire(FForgotPage, 'ResetButton', DoResetPassword);
  Wire(FForgotPage, 'BackButton', BackToLogin);

  if FAuth = nil then
    Say(FLoginPage, 'Database unavailable.');

  FWindow.SetContent(FRoot);
  FWindow.Center;
  FWindow.Activate;
  SetWindowIcon(FWindow.HostHandle);

  ShowLogin;
end;

destructor TLoginView.Destroy;
begin
  FPages.Free;
  FLoginPage.Free;
  FRegisterPage.Free;
  FForgotPage.Free;
  FRoot.Free;
  FAuth.Free;
  FWindow.Free;
  inherited;
end;

{ -- page loading / wiring ------------------------------------------------- }

function TLoginView.LoadPage(const AXaml: string): TWinUI2FrameworkElement;
begin
  try
    Result := TWinUI2Xaml.LoadRoot(PageXaml(AXaml, True));
  except
    // runtime refused AcrylicBrush.TintLuminosityOpacity: same glass without it
    Result := TWinUI2Xaml.LoadRoot(PageXaml(AXaml, False));
  end;
end;

procedure TLoginView.Wire(APage: TWinUI2FrameworkElement; const AName: string; const AAction: TProc);
var
  B: TWinUI2Button;
begin
  B := APage.FindButton(AName);
  try
    B.OnClick(
      procedure(sender: IInspectable; e: IRoutedEventArgs)
      begin
        AAction();
      end);
  finally
    B.Free;
  end;
end;

{ -- control helpers ------------------------------------------------------- }

function TLoginView.GetText(APage: TWinUI2FrameworkElement; const AName: string): string;
var
  Box: TWinUI2TextBox;
begin
  Box := TWinUI2TextBox.Wrap(APage.FindElement(AName));
  try
    Result := Trim(Box.Text);
  finally
    Box.Free;
  end;
end;

procedure TLoginView.SetText(APage: TWinUI2FrameworkElement; const AName, AValue: string);
var
  Box: TWinUI2TextBox;
begin
  Box := TWinUI2TextBox.Wrap(APage.FindElement(AName));
  try
    Box.Text := AValue;
  finally
    Box.Free;
  end;
end;

function TLoginView.GetPassword(APage: TWinUI2FrameworkElement; const AName: string): string;
var
  Box: TWinUI2PasswordBox;
begin
  Box := TWinUI2PasswordBox.Wrap(APage.FindElement(AName));
  try
    Result := Box.Password;
  finally
    Box.Free;
  end;
end;

procedure TLoginView.ClearPassword(APage: TWinUI2FrameworkElement; const AName: string);
var
  Box: TWinUI2PasswordBox;
begin
  Box := TWinUI2PasswordBox.Wrap(APage.FindElement(AName));
  try
    Box.Password := '';
  finally
    Box.Free;
  end;
end;

function TLoginView.IsChecked(APage: TWinUI2FrameworkElement; const AName: string): Boolean;
var
  Chk: TWinUI2CheckBox;
begin
  Chk := TWinUI2CheckBox.Wrap(APage.FindElement(AName));
  try
    Result := Chk.Checked;
  finally
    Chk.Free;
  end;
end;

procedure TLoginView.Say(APage: TWinUI2FrameworkElement; const AText: string);
var
  T: TWinUI2TextBlock;
begin
  if APage = nil then Exit;
  T := APage.FindTextBlock('StatusText');
  try
    T.Text(AText);
  finally
    T.Free;
  end;
end;

{ -- navigation ------------------------------------------------------------ }

procedure TLoginView.ShowLogin;
begin
  FPages.Reset(FLoginPage.Element);
end;

procedure TLoginView.ShowRegister;
begin
  FPages.Navigate(FRegisterPage.Element);
end;

procedure TLoginView.ShowForgot;
begin
  FPages.Navigate(FForgotPage.Element);
end;

procedure TLoginView.BackToLogin;
begin
  if not FPages.GoBack then
    ShowLogin;
end;

{ -- actions --------------------------------------------------------------- }

procedure TLoginView.DoLogin;
var
  User, Pass: string;
  Remember: Boolean;
begin
  if FAuth = nil then begin Say(FLoginPage, 'Database not available.'); Exit; end;
  User := GetText(FLoginPage, 'UserBox');
  Pass := GetPassword(FLoginPage, 'PassBox');
  Remember := IsChecked(FLoginPage, 'RememberCheck');
  try
    if FAuth.Login(User, Pass) then
    begin
      Say(FLoginPage, 'Welcome, ' + User + IfThen(Remember, ' (remembered)', '') + '.');
      ClearPassword(FLoginPage, 'PassBox');
    end
    else
      Say(FLoginPage, 'Invalid username or password.');
  except
    on E: Exception do Say(FLoginPage, 'Error: ' + E.Message);
  end;
end;

procedure TLoginView.DoRegister;
var
  User, Email, Picture, Pass, Confirm, Err: string;
begin
  if FAuth = nil then begin Say(FRegisterPage, 'Database not available.'); Exit; end;
  User := GetText(FRegisterPage, 'UserBox');
  Email := GetText(FRegisterPage, 'EmailBox');
  Picture := GetText(FRegisterPage, 'PictureBox');
  Pass := GetPassword(FRegisterPage, 'PassBox');
  Confirm := GetPassword(FRegisterPage, 'ConfirmBox');
  if Pass <> Confirm then begin Say(FRegisterPage, 'Passwords do not match.'); Exit; end;
  try
    Err := FAuth.Register(User, Email, Pass, Picture);
    if Err = '' then
    begin
      ClearPassword(FRegisterPage, 'PassBox');
      ClearPassword(FRegisterPage, 'ConfirmBox');
      SetText(FLoginPage, 'UserBox', User);
      ShowLogin;
      Say(FLoginPage, 'Account created. Enter your password to sign in.');
    end
    else
      Say(FRegisterPage, Err);
  except
    on E: Exception do Say(FRegisterPage, 'Error: ' + E.Message);
  end;
end;

procedure TLoginView.DoResetPassword;
var
  User, Email, Pass, Confirm, Err: string;
begin
  if FAuth = nil then begin Say(FForgotPage, 'Database not available.'); Exit; end;
  User := GetText(FForgotPage, 'UserBox');
  Email := GetText(FForgotPage, 'EmailBox');
  Pass := GetPassword(FForgotPage, 'PassBox');
  Confirm := GetPassword(FForgotPage, 'ConfirmBox');
  if Pass <> Confirm then begin Say(FForgotPage, 'Passwords do not match.'); Exit; end;
  try
    Err := FAuth.ResetPassword(User, Email, Pass);
    if Err = '' then
    begin
      ClearPassword(FForgotPage, 'PassBox');
      ClearPassword(FForgotPage, 'ConfirmBox');
      ShowLogin;
      SetText(FLoginPage, 'UserBox', User);
      Say(FLoginPage, 'Password reset successfully. You can sign in now.');
    end
    else
      Say(FForgotPage, Err);
  except
    on E: Exception do Say(FForgotPage, 'Error: ' + E.Message);
  end;
end;

function TLoginView.GetAppDataPath: string;
begin
  Result := GetEnvironmentVariable('LOCALAPPDATA');
  if Result = '' then
    raise EInOutError.Create('LOCALAPPDATA is not available.');
  Result := TPath.Combine(Result, 'WinUI2LoginDemo');
  if not ForceDirectories(Result) and not DirectoryExists(Result) then
    raise EInOutError.CreateFmt('Cannot create application data directory: %s', [Result]);
end;

end.
