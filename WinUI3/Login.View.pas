unit Login.View;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.StrUtils,
  Winapi.WinRT,
  WinUI.Controls,
  WinUI.Inputs,
  WinUI.Events,
  WinUI.Window,
  WinUI.Xaml,
  WinUI.Navigation,
  WinUI.Icon,
  Login.Auth,
  Login.Xaml,
  Login.Pages;

type
  TLoginView = class
  private
    FWindow: TWinUIWindow;
    FRoot: TWinUIFrameworkElement;
    FPages: TWinUIPageHost;
    FAuth: TAuthStore;
    FLoginPage: TWinUIFrameworkElement;
    FRegisterPage: TWinUIFrameworkElement;
    FForgotPage: TWinUIFrameworkElement;
    procedure Say(APage: TWinUIFrameworkElement; const AText: string);
    procedure Wire(APage: TWinUIFrameworkElement; const AName: string; const AAction: TProc);
    function LoadPage(const AXaml: string): TWinUIFrameworkElement;
    procedure ShowLogin;
    procedure ShowRegister;
    procedure ShowForgot;
    procedure DoLogin;
    procedure DoRegister;
    procedure DoResetPassword;
    procedure BackToLogin;
    function GetAppDataPath: string;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TLoginView.Create;
begin
  inherited Create;
  FWindow := TWinUIWindow.Create;
  FWindow.Title('WinUI 3 Login Demo').DarkFrame(True);

  FRoot := TWinUIXaml.LoadRoot(cLoginXaml);
  FPages := TWinUIPageHost.Wrap(FRoot.FindElement('PageHost'));

  try
    FAuth := TAuthStore.Create(TPath.Combine(GetAppDataPath, 'login_demo.db'));
  except
    on E: Exception do
      FAuth := nil;
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
  FWindow.ExtendIntoTitleBar(TWinUIElement.Create(FRoot.FindElement('TitleBar')));
  FWindow.ClientSize(900, 640).MinSize(420, 600).Center;
  FWindow.Activate;
  SetWindowIcon(FWindow.Handle);

  ShowLogin;
end;

destructor TLoginView.Destroy;
begin
  FPages.Free;
  FRoot.Free;
  FAuth.Free;
  FWindow.Free;
  inherited;
end;

function TLoginView.LoadPage(const AXaml: string): TWinUIFrameworkElement;
begin
  try
    Result := TWinUIFrameworkElement.Create(TWinUIXaml.Load(PageXaml(AXaml, True)).Element);
  except
    // runtime refused TintLuminosityOpacity: same glass without it
    Result := TWinUIFrameworkElement.Create(TWinUIXaml.Load(PageXaml(AXaml, False)).Element);
  end;
end;

procedure TLoginView.Say(APage: TWinUIFrameworkElement; const AText: string);
begin
  if APage <> nil then
    APage.FindTextBlock('StatusText').Text(AText);
end;

procedure TLoginView.Wire(APage: TWinUIFrameworkElement; const AName: string; const AAction: TProc);
var
  B: TWinUIButton;
begin
  B := APage.FindButton(AName);
  B.OnClick(
    procedure(sender: IInspectable; e: IRoutedEventArgs)
    begin
      AAction();
    end);
end;

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

procedure TLoginView.DoLogin;
var
  User: string;
  Pass: string;
  Remember: Boolean;
begin
  if FAuth = nil then begin Say(FLoginPage, 'Database not available.'); Exit; end;
  User := Trim(TWinUITextBox.Wrap(FLoginPage.FindElement('UserBox')).Text);
  Pass := TWinUIPasswordBox.Wrap(FLoginPage.FindElement('PassBox')).Password;
  Remember := TWinUICheckBox.Wrap(FLoginPage.FindElement('RememberCheck')).Checked;
  try
    if FAuth.Login(User, Pass) then
    begin
      Say(FLoginPage, 'Welcome, ' + User + IfThen(Remember, ' (remembered)', '') + '.');
      TWinUIPasswordBox.Wrap(FLoginPage.FindElement('PassBox')).Password := '';
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
  User := Trim(TWinUITextBox.Wrap(FRegisterPage.FindElement('UserBox')).Text);
  Email := Trim(TWinUITextBox.Wrap(FRegisterPage.FindElement('EmailBox')).Text);
  Picture := Trim(TWinUITextBox.Wrap(FRegisterPage.FindElement('PictureBox')).Text);
  Pass := TWinUIPasswordBox.Wrap(FRegisterPage.FindElement('PassBox')).Password;
  Confirm := TWinUIPasswordBox.Wrap(FRegisterPage.FindElement('ConfirmBox')).Password;
  if Pass <> Confirm then begin Say(FRegisterPage, 'Passwords do not match.'); Exit; end;
  try
    Err := FAuth.Register(User, Email, Pass, Picture);
    if Err = '' then
    begin
      Say(FRegisterPage, 'Account created successfully. Returning to login...');
      TWinUITextBox.Wrap(FLoginPage.FindElement('UserBox')).Text := User;
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
  User := Trim(TWinUITextBox.Wrap(FForgotPage.FindElement('UserBox')).Text);
  Email := Trim(TWinUITextBox.Wrap(FForgotPage.FindElement('EmailBox')).Text);
  Pass := TWinUIPasswordBox.Wrap(FForgotPage.FindElement('PassBox')).Password;
  Confirm := TWinUIPasswordBox.Wrap(FForgotPage.FindElement('ConfirmBox')).Password;
  if Pass <> Confirm then begin Say(FForgotPage, 'Passwords do not match.'); Exit; end;
  try
    Err := FAuth.ResetPassword(User, Email, Pass);
    if Err = '' then
    begin
      ShowLogin;
      TWinUITextBox.Wrap(FLoginPage.FindElement('UserBox')).Text := User;
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
  Result := TPath.Combine(Result, 'WinUI3LoginDemo');
  if not ForceDirectories(Result) and not DirectoryExists(Result) then
    raise EInOutError.CreateFmt('Cannot create application data directory: %s', [Result]);
end;

end.
