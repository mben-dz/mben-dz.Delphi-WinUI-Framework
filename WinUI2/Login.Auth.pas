unit Login.Auth;

{
  User store on SQLite through FireDAC (no visual components, no VCL/FMX).
    - table users(id, username UNIQUE NOCASE, salt, hash, created_at)
    - passwords are never stored: PBKDF2-HMAC-SHA256 (random 16-byte salt, cIterations rounds)
    - every statement is parameterized
  Raises nothing for "wrong password" (returns False); raises for database problems.
}

interface

uses
  System.SysUtils,
{$REGION '  FireDAC .. '}
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.DApt.Intf,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.VclUI.Wait,
{$ENDREGION}
//
  Data.DB;

type
  TAuthStore = class
  private
    FConn: TFDConnection;
    procedure EnsureSchema;
  public
    constructor Create(const ADatabaseFile: string);
    destructor Destroy; override;
    // '' = created, otherwise the reason it was refused
    function &Register(const AUser, AEmail, APassword, APicture: string): string;
    function Login(const AUser, APassword: string): Boolean;
    function ResetPassword(const AUser, AEmail, ANewPassword: string): string;
    function UserCount: Integer;
    function GetUserEmail(const AUser: string): string;
  end;

implementation

uses
  System.Classes,
  System.Hash;

const
  cIterations = 50000;   // raise for production (and consider Argon2 / scrypt)
  cSaltBytes = 16;

function BytesToHex(const B: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + IntToHex(B[I], 2);
end;

function HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

function RandomSalt: TBytes;
var
  LGuid: TGUID;
begin
  // CoCreateGuid is random (version 4): 16 bytes are enough as a per-user salt
  CreateGUID(LGuid);
  SetLength(Result, SizeOf(LGuid));
  Move(LGuid, Result[0], SizeOf(LGuid));
end;

// PBKDF2-HMAC-SHA256, one 32-byte block
function Pbkdf2(const APassword: string; const ASalt: TBytes; AIterations: Integer): TBytes;
var
  LKey, LMsg, U, T: TBytes;
  I, J: Integer;
begin
  LKey := TEncoding.UTF8.GetBytes(APassword);
  SetLength(LMsg, Length(ASalt) + 4);
  Move(ASalt[0], LMsg[0], Length(ASalt));
  LMsg[Length(ASalt) + 0] := 0;
  LMsg[Length(ASalt) + 1] := 0;
  LMsg[Length(ASalt) + 2] := 0;
  LMsg[Length(ASalt) + 3] := 1;   // block index 1
  U := THashSHA2.GetHMACAsBytes(LMsg, LKey, SHA256);
  T := Copy(U, 0, Length(U));
  for I := 2 to AIterations do
  begin
    U := THashSHA2.GetHMACAsBytes(U, LKey, SHA256);
    for J := 0 to High(T) do
      T[J] := T[J] xor U[J];
  end;
  Result := T;
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I, Diff: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  Diff := 0;
  for I := 0 to High(A) do
    Diff := Diff or (A[I] xor B[I]);   // no early exit
  Result := Diff = 0;
end;

{ TAuthStore }

constructor TAuthStore.Create(const ADatabaseFile: string);
begin inherited Create;

  if not DirectoryExists(ExtractFilePath(ADatabaseFile)) then
    ForceDirectories(ExtractFilePath(ADatabaseFile));

  FConn := TFDConnection.Create(nil);
  FConn.LoginPrompt := False;
  FConn.Params.DriverID := 'SQLite';
  FConn.Params.Database := ADatabaseFile;
  FConn.Params.Add('OpenMode=CreateUTF8');   // create the file on first run
  FConn.Params.Add('LockingMode=Normal');
  FConn.Connected := True;
  EnsureSchema;
end;

destructor TAuthStore.Destroy;
begin
  FConn.Free;
  inherited;
end;

procedure TAuthStore.EnsureSchema;
var
  LQry: TFDQuery;
  LHasEmail, LHasPicture: Boolean;
  LName: string;
begin
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS users (' +
    ' id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    ' username TEXT NOT NULL UNIQUE COLLATE NOCASE,' +
    ' salt TEXT NOT NULL,' +
    ' hash TEXT NOT NULL,' +
    ' email TEXT NOT NULL DEFAULT '''',' +
    ' picture TEXT NOT NULL DEFAULT '''',' +
    ' created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');

  // Upgrade databases created by older versions.
  // Do not use pragma_table_info(...) here: older SQLite engines bundled with
  // some FireDAC installations do not expose PRAGMA table-valued functions,
  // which causes: ERROR: near "(": syntax error.
  LHasEmail := False;
  LHasPicture := False;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConn;
    LQry.SQL.Text := 'PRAGMA table_info(users)';
    LQry.Open;
    while not LQry.Eof do
    begin
      LName := LQry.FieldByName('name').AsString;
      if SameText(LName, 'email') then
        LHasEmail := True
      else if SameText(LName, 'picture') then
        LHasPicture := True;
      LQry.Next;
    end;
  finally
    LQry.Free;
  end;

  if not LHasEmail then
    FConn.ExecSQL('ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ''''');
  if not LHasPicture then
    FConn.ExecSQL('ALTER TABLE users ADD COLUMN picture TEXT NOT NULL DEFAULT ''''');
end;

function TAuthStore.UserCount: Integer;
begin
  Result := FConn.ExecSQLScalar('SELECT COUNT(*) FROM users');
end;

function TAuthStore.&Register(const AUser, AEmail, APassword, APicture: string): string;
var
  LUser, LEmail, LPicture: string;
  LSalt, LHash: TBytes;
begin
  LUser := Trim(AUser);
  LEmail := Trim(AEmail);
  LPicture := Trim(APicture);
  if Length(LUser) < 3 then Exit('Username must have at least 3 characters.');
  if Pos('@', LEmail) < 2 then Exit('Enter a valid recovery email.');
  if Length(APassword) < 6 then Exit('Password must have at least 6 characters.');
  if FConn.ExecSQLScalar('SELECT COUNT(*) FROM users WHERE username = :u', [LUser]) > 0 then
    Exit('This username is already taken.');
  if FConn.ExecSQLScalar('SELECT COUNT(*) FROM users WHERE email = :e', [LEmail]) > 0 then
    Exit('This recovery email is already registered.');

  LSalt := RandomSalt;
  LHash := Pbkdf2(APassword, LSalt, cIterations);
  FConn.ExecSQL('INSERT INTO users (username, salt, hash, email, picture) VALUES (:u, :s, :h, :e, :p)',
    [LUser, BytesToHex(LSalt), BytesToHex(LHash), LEmail, LPicture]);
  Result := '';
end;

function TAuthStore.Login(const AUser, APassword: string): Boolean;
var
  LQry: TFDQuery;
  LSalt, LExpected: TBytes;
begin
  Result := False;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConn;
    LQry.SQL.Text := 'SELECT salt, hash FROM users WHERE username = :u';
    LQry.ParamByName('u').AsString := Trim(AUser);
    LQry.Open;
    if LQry.Eof then
    begin
      // same work as for a real user, so timing does not reveal which usernames exist
      Pbkdf2(APassword, RandomSalt, cIterations);
      Exit;
    end;
    LSalt := HexToBytes(LQry.FieldByName('salt').AsString);
    LExpected := HexToBytes(LQry.FieldByName('hash').AsString);
Result := SameBytes(
      Pbkdf2(APassword, LSalt, cIterations),
      LExpected
    );
  finally
    LQry.Free;
  end;
end;


function TAuthStore.GetUserEmail(const AUser: string): string;
begin
  Result := FConn.ExecSQLScalar('SELECT email FROM users WHERE username = :u', [Trim(AUser)]);
end;

function TAuthStore.ResetPassword(const AUser, AEmail, ANewPassword: string): string;
var
  LSalt, LHash: TBytes;
  LUser, LEmail: string;
begin
  Result := '';
  LUser := Trim(AUser);
  LEmail := Trim(AEmail);
  if Length(ANewPassword) < 6 then
    Exit('Password must have at least 6 characters.');
  if Pos('@', LEmail) < 2 then
    Exit('Enter a valid recovery email.');

  if FConn.ExecSQLScalar(
       'SELECT COUNT(*) FROM users WHERE username = :u AND email = :e',
       [LUser, LEmail]) = 0 then
    Exit('Username and recovery email do not match.');

  LSalt := RandomSalt;
  LHash := Pbkdf2(ANewPassword, LSalt, cIterations);
  FConn.ExecSQL(
    'UPDATE users SET salt = :s, hash = :h WHERE username = :u',
    [BytesToHex(LSalt), BytesToHex(LHash), LUser]);
end;

end.
