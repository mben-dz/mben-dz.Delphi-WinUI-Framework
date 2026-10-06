unit Calc.Engine;

{
  Calculator engine (Standard mode) - no UI dependency.

  Behaves like the Windows Calculator:
    - immediate evaluation:   2 + 3 x 4 =  ->  20
    - repeat equals:          2 + 3 = = =  ->  5, 8, 11
    - "5 + =" uses the displayed value as second operand (10)
    - % is relative to the first operand for + and -, plain /100 for x and /
    - unary operations wrap the operand in the expression: sqrt(9), sqr(9), 1/(9), negate(9)
    - 16 digits of input, 16 significant digits of output, exact decimal math
    - memory is a stack (newest first), history is a list (newest first)
    - Error states need C / CE to recover
}

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
{$IFDEF FPC}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Calc.Decimal;

type
  TCalcNotify = procedure of object;

  TCalcEngine = class
  private
    FEntry: string;          // digits being typed, e.g. '-12.5'
    FEntering: Boolean;      // display shows FEntry
    FValue: TDec;            // display value when not entering
    FAcc: TDec;              // left operand of the pending operation
    FOp: Char;               // pending operator: + - * /  or #0
    FHasOperand: Boolean;    // a right operand was entered / produced since the operator
    FAfterEq: Boolean;       // '=' was just pressed
    FLastOp: Char;           // for repeat equals
    FLastB: TDec;
    FPrefix: string;         // committed part of the expression, e.g. '2 + 3 x'
    FUnaryText: string;      // operand wrapped by unary ops, e.g. 'sqrt(9)'
    FFinalExpr: string;      // expression shown after '=' or on error
    FError: string;
    FMemory: array of TDec;
    FHistText: array of string;
    FHistResult: array of string;
    FHistValue: array of TDec;
    FDecSep: Char;
    FGroupSep: Char;
    FOnChanged: TCalcNotify;

    procedure Changed;
    procedure Fail(const AMessage, AExpr: string);
    function FmtDec(const D: TDec): string;
    function FmtEntry: string;
    function OpSymbol(AOp: Char): string;
    function GetOperand: TDec;
    function OperandText(const X: TDec): string;
    procedure ResetExpression;
    procedure SetOperandValue(const V: TDec);
    function Compute(const A: TDec; AOp: Char; const B: TDec; out R: TDec; const AExpr: string): Boolean;
    function CheckRange(var R: TDec; const AExpr: string): Boolean;
    procedure AddHistory(const AExpr: string; const R: TDec);
    procedure ApplyUnary(AKind: Integer);
    procedure MemoryPush(const V: TDec);
    function EntryDigitCount: Integer;
    function EntryIsZero: Boolean;
    function GetDisplayValue: string;
    function GetExpressionText: string;
    function GetRawText: string;
    function GetIsError: Boolean;
    function GetHasMemory: Boolean;
    function GetMemoryCount: Integer;
    function GetHistoryCount: Integer;
  public
    constructor Create;

    procedure PressDigit(ADigit: Char);
    procedure PressDecimal;
    procedure PressBackspace;
    procedure PressNegate;
    procedure PressOperator(AOp: Char);   // + - * /
    procedure PressEquals;
    procedure PressPercent;
    procedure PressSqrt;
    procedure PressSquare;
    procedure PressReciprocal;
    procedure PressClear;                 // C
    procedure PressClearEntry;            // CE
    // Maps a typed character (keyboard) to a key. Returns False when not used.
    function PressKey(ACh: Char): Boolean;

    procedure MemoryClear;
    procedure MemoryRecall;
    procedure MemoryAdd;
    procedure MemorySubtract;
    procedure MemoryStore;
    procedure RecallMemoryItem(AIndex: Integer);
    function MemoryText(AIndex: Integer): string;

    procedure ClearHistory;
    procedure RecallHistoryItem(AIndex: Integer);
    function HistoryExpression(AIndex: Integer): string;
    function HistoryResult(AIndex: Integer): string;

    // Replaces the current entry with a number pasted from the clipboard.
    function PasteText(const S: string): Boolean;

    property DisplayValue: string read GetDisplayValue;
    property ExpressionText: string read GetExpressionText;
    property RawText: string read GetRawText;   // number without grouping (for copy)
    property IsError: Boolean read GetIsError;
    property HasMemory: Boolean read GetHasMemory;
    property MemoryCount: Integer read GetMemoryCount;
    property HistoryCount: Integer read GetHistoryCount;
    property DecimalSeparator: Char read FDecSep write FDecSep;
    property GroupSeparator: Char read FGroupSep write FGroupSep;
    property OnChanged: TCalcNotify read FOnChanged write FOnChanged;
  end;

implementation

const
  MaxInputDigits = 16;
  MaxHistory = 100;
  ukSqrt = 0;
  ukSquare = 1;
  ukRecip = 2;

constructor TCalcEngine.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FDecSep := DefaultFormatSettings.DecimalSeparator;
  FGroupSep := DefaultFormatSettings.ThousandSeparator;
{$ELSE}
  FDecSep := FormatSettings.DecimalSeparator;
  FGroupSep := FormatSettings.ThousandSeparator;
{$ENDIF}
  if FGroupSep = #0 then FGroupSep := ',';
  FValue := DecZero;
  FAcc := DecZero;
  FLastB := DecZero;
  FEntry := '0';
end;

procedure TCalcEngine.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged();
end;

procedure TCalcEngine.Fail(const AMessage, AExpr: string);
begin
  FError := AMessage;
  FFinalExpr := AExpr;
  FEntering := False;
  Changed;
end;

function TCalcEngine.FmtDec(const D: TDec): string;
begin
  Result := DecFormat(D, MaxInputDigits, FDecSep, FGroupSep);
end;

function TCalcEngine.FmtEntry: string;
var
  S, IntPart, FracPart: string;
  Neg: Boolean;
  P: Integer;
begin
  S := FEntry;
  Neg := (S <> '') and (S[1] = '-');
  if Neg then Delete(S, 1, 1);
  P := Pos('.', S);
  if P > 0 then
  begin
    IntPart := Copy(S, 1, P - 1);
    FracPart := Copy(S, P + 1, Length(S));
  end
  else
    IntPart := S;
  if IntPart = '' then IntPart := '0';
  Result := DecGroupDigits(IntPart, FGroupSep);
  if P > 0 then
    Result := Result + FDecSep + FracPart;
  if Neg then Result := '-' + Result;
end;

function TCalcEngine.OpSymbol(AOp: Char): string;
begin
  case AOp of
    '+': Result := '+';
    '-': Result := WideChar($2212);
    '*': Result := WideChar($00D7);
    '/': Result := WideChar($00F7);
  else
    Result := '';
  end;
end;

function TCalcEngine.GetOperand: TDec;
begin
  if FEntering then
  begin
    if not DecTryParse(FEntry, Result) then
      Result := DecZero;
  end
  else
    Result := FValue;
end;

function TCalcEngine.OperandText(const X: TDec): string;
begin
  if FUnaryText <> '' then
    Result := FUnaryText
  else
    Result := FmtDec(X);
end;

procedure TCalcEngine.ResetExpression;
begin
  FPrefix := '';
  FUnaryText := '';
  FFinalExpr := '';
  FOp := #0;
  FLastOp := #0;
  FAfterEq := False;
  FHasOperand := False;
end;

procedure TCalcEngine.SetOperandValue(const V: TDec);
begin
  if FAfterEq then
    ResetExpression;
  FValue := V;
  FEntering := False;
  FHasOperand := True;
  FUnaryText := '';
end;

function TCalcEngine.CheckRange(var R: TDec; const AExpr: string): Boolean;
begin
  Result := True;
  if DecIsZero(R) then Exit;
  if DecExponent(R) > DecMaxExp then
  begin
    Fail('Overflow', AExpr);
    Result := False;
  end
  else if DecExponent(R) < -DecMaxExp then
    R := DecZero;
end;

function TCalcEngine.Compute(const A: TDec; AOp: Char; const B: TDec; out R: TDec; const AExpr: string): Boolean;
begin
  Result := False;
  R := DecZero;
  case AOp of
    '+': R := DecAdd(A, B);
    '-': R := DecSub(A, B);
    '*': R := DecMul(A, B);
    '/':
      begin
        if DecIsZero(B) then
        begin
          if DecIsZero(A) then
            Fail('Result is undefined', AExpr)
          else
            Fail('Cannot divide by zero', AExpr);
          Exit;
        end;
        R := DecDiv(A, B);
      end;
  else
    R := B;
  end;
  Result := CheckRange(R, AExpr);
end;

procedure TCalcEngine.AddHistory(const AExpr: string; const R: TDec);
var
  I, N: Integer;
begin
  N := Length(FHistText);
  if N >= MaxHistory then
    N := MaxHistory - 1
  else
  begin
    SetLength(FHistText, N + 1);
    SetLength(FHistResult, N + 1);
    SetLength(FHistValue, N + 1);
  end;
  for I := N downto 1 do
  begin
    FHistText[I] := FHistText[I - 1];
    FHistResult[I] := FHistResult[I - 1];
    FHistValue[I] := FHistValue[I - 1];
  end;
  FHistText[0] := AExpr;
  FHistResult[0] := FmtDec(R);
  FHistValue[0] := R;
end;

function TCalcEngine.EntryDigitCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(FEntry) do
    if (FEntry[I] >= '0') and (FEntry[I] <= '9') then
      Inc(Result);
end;

function TCalcEngine.EntryIsZero: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(FEntry) do
    if (FEntry[I] >= '1') and (FEntry[I] <= '9') then
    begin
      Result := False;
      Exit;
    end;
end;

{ ---- input ---- }

procedure TCalcEngine.PressDigit(ADigit: Char);
begin
  if FError <> '' then Exit;
  if (ADigit < '0') or (ADigit > '9') then Exit;
  if FAfterEq then
    ResetExpression;
  if not FEntering then
  begin
    FEntering := True;
    FEntry := '';
    FUnaryText := '';
    FHasOperand := True;
  end;
  if EntryDigitCount >= MaxInputDigits then Exit;
  if (FEntry = '') or (FEntry = '0') then
    FEntry := ADigit
  else if FEntry = '-0' then
    FEntry := '-' + ADigit
  else
    FEntry := FEntry + ADigit;
  Changed;
end;

procedure TCalcEngine.PressDecimal;
begin
  if FError <> '' then Exit;
  if FAfterEq then
    ResetExpression;
  if not FEntering then
  begin
    FEntering := True;
    FEntry := '0';
    FUnaryText := '';
    FHasOperand := True;
  end;
  if Pos('.', FEntry) = 0 then
    FEntry := FEntry + '.';
  Changed;
end;

procedure TCalcEngine.PressBackspace;
begin
  if FError <> '' then Exit;
  if not FEntering then Exit;
  Delete(FEntry, Length(FEntry), 1);
  if (FEntry = '') or (FEntry = '-') or (FEntry = '-0') then
    FEntry := '0';
  Changed;
end;

procedure TCalcEngine.PressNegate;
var
  X: TDec;
  Inner: string;
begin
  if FError <> '' then Exit;
  if FEntering then
  begin
    if EntryIsZero then Exit;
    if FEntry[1] = '-' then Delete(FEntry, 1, 1) else FEntry := '-' + FEntry;
    Changed;
    Exit;
  end;
  if FAfterEq then
    ResetExpression;
  X := GetOperand;
  if DecIsZero(X) then Exit;
  Inner := OperandText(X);
  FValue := DecNegate(X);
  FUnaryText := 'negate(' + Inner + ')';
  FHasOperand := True;
  Changed;
end;

procedure TCalcEngine.PressOperator(AOp: Char);
var
  X, R: TDec;
  Txt, Expr: string;
begin
  if FError <> '' then Exit;
  if (AOp <> '+') and (AOp <> '-') and (AOp <> '*') and (AOp <> '/') then Exit;
  if FAfterEq then
  begin
    // continue from the result
    FPrefix := '';
    FUnaryText := '';
    FFinalExpr := '';
    FOp := #0;
    FLastOp := #0;
    FAfterEq := False;
    FHasOperand := True;
  end;
  if (FOp <> #0) and (not FHasOperand) then
  begin
    // operator pressed twice: replace the previous one
    FPrefix := Copy(FPrefix, 1, Length(FPrefix) - 1) + OpSymbol(AOp);
    FOp := AOp;
    Changed;
    Exit;
  end;
  X := GetOperand;
  Txt := OperandText(X);
  if FOp <> #0 then
  begin
    Expr := FPrefix + ' ' + Txt + ' ' + OpSymbol(AOp);
    if not Compute(FAcc, FOp, X, R, Expr) then Exit;
    FAcc := R;
    FPrefix := Expr;
  end
  else
  begin
    FAcc := X;
    FPrefix := Txt + ' ' + OpSymbol(AOp);
  end;
  FOp := AOp;
  FValue := FAcc;
  FEntering := False;
  FHasOperand := False;
  FUnaryText := '';
  Changed;
end;

procedure TCalcEngine.PressEquals;
var
  A, B, R: TDec;
  Expr: string;
begin
  if FError <> '' then Exit;
  if FOp <> #0 then
  begin
    B := GetOperand;
    Expr := FPrefix + ' ' + OperandText(B) + ' =';
    if not Compute(FAcc, FOp, B, R, Expr) then Exit;
    FLastOp := FOp;
    FLastB := B;
    FValue := R;
    FOp := #0;
    FPrefix := '';
    FUnaryText := '';
    FEntering := False;
    FHasOperand := False;
    FAfterEq := True;
    FFinalExpr := Expr;
    AddHistory(Expr, R);
  end
  else if FAfterEq and (FLastOp <> #0) then
  begin
    A := FValue;
    B := FLastB;
    Expr := FmtDec(A) + ' ' + OpSymbol(FLastOp) + ' ' + FmtDec(B) + ' =';
    if not Compute(A, FLastOp, B, R, Expr) then Exit;
    FValue := R;
    FFinalExpr := Expr;
    AddHistory(Expr, R);
  end
  else
  begin
    A := GetOperand;
    FFinalExpr := OperandText(A) + ' =';
    FValue := A;
    FEntering := False;
    FUnaryText := '';
    FAfterEq := True;
    FLastOp := #0;
  end;
  Changed;
end;

procedure TCalcEngine.PressPercent;
var
  X, R: TDec;
begin
  if FError <> '' then Exit;
  if FAfterEq then
    ResetExpression;
  X := GetOperand;
  case FOp of
    '+', '-': R := DecDiv(DecMul(FAcc, X), DecFromInt(100));
    '*', '/': R := DecDiv(X, DecFromInt(100));
  else
    R := DecZero;
  end;
  FValue := R;
  FEntering := False;
  FHasOperand := True;
  FUnaryText := FmtDec(R);
  Changed;
end;

procedure TCalcEngine.ApplyUnary(AKind: Integer);
var
  X, R: TDec;
  Txt: string;
begin
  if FError <> '' then Exit;
  if FAfterEq then
    ResetExpression;
  X := GetOperand;
  case AKind of
    ukSqrt: Txt := WideChar($221A) + '(' + OperandText(X) + ')';
    ukSquare: Txt := 'sqr(' + OperandText(X) + ')';
  else
    Txt := '1/(' + OperandText(X) + ')';
  end;
  case AKind of
    ukSqrt:
      begin
        if X.Neg then
        begin
          Fail('Invalid input', Txt);
          Exit;
        end;
        R := DecSqrt(X);
      end;
    ukSquare:
      R := DecMul(X, X);
  else
    begin
      if DecIsZero(X) then
      begin
        Fail('Cannot divide by zero', Txt);
        Exit;
      end;
      R := DecDiv(DecFromInt(1), X);
    end;
  end;
  if not CheckRange(R, Txt) then Exit;
  FValue := R;
  FEntering := False;
  FHasOperand := True;
  FUnaryText := Txt;
  Changed;
end;

procedure TCalcEngine.PressSqrt;
begin
  ApplyUnary(ukSqrt);
end;

procedure TCalcEngine.PressSquare;
begin
  ApplyUnary(ukSquare);
end;

procedure TCalcEngine.PressReciprocal;
begin
  ApplyUnary(ukRecip);
end;

procedure TCalcEngine.PressClear;
begin
  FError := '';
  FEntry := '0';
  FEntering := False;
  FValue := DecZero;
  FAcc := DecZero;
  ResetExpression;
  Changed;
end;

procedure TCalcEngine.PressClearEntry;
begin
  if (FError <> '') or FAfterEq then
  begin
    PressClear;
    Exit;
  end;
  FEntry := '0';
  FEntering := True;
  FHasOperand := True;
  FUnaryText := '';
  Changed;
end;

function TCalcEngine.PressKey(ACh: Char): Boolean;
begin
  Result := True;
  case ACh of
    '0'..'9': PressDigit(ACh);
    '.', ',': PressDecimal;
    '+', '-', '*', '/': PressOperator(ACh);
    '=': PressEquals;
    #8: PressBackspace;
    #27: PressClear;
    '%': PressPercent;
    '@': PressSqrt;
    'r', 'R': PressReciprocal;
    'q', 'Q': PressSquare;
    #12: MemoryClear;       // Ctrl+L
    #18: MemoryRecall;      // Ctrl+R
    #16: MemoryAdd;         // Ctrl+P
    #17: MemorySubtract;    // Ctrl+Q
  else
    Result := False;
  end;
end;

{ ---- memory ---- }

procedure TCalcEngine.MemoryPush(const V: TDec);
var
  I, N: Integer;
begin
  N := Length(FMemory);
  SetLength(FMemory, N + 1);
  for I := N downto 1 do
    FMemory[I] := FMemory[I - 1];
  FMemory[0] := V;
end;

procedure TCalcEngine.MemoryClear;
begin
  if FError <> '' then Exit;
  SetLength(FMemory, 0);
  Changed;
end;

procedure TCalcEngine.MemoryRecall;
begin
  if FError <> '' then Exit;
  if Length(FMemory) = 0 then Exit;
  SetOperandValue(FMemory[0]);
  Changed;
end;

procedure TCalcEngine.MemoryStore;
var
  X: TDec;
begin
  if FError <> '' then Exit;
  X := GetOperand;
  MemoryPush(X);
  FValue := X;
  FEntering := False;
  Changed;
end;

procedure TCalcEngine.MemoryAdd;
var
  X: TDec;
begin
  if FError <> '' then Exit;
  X := GetOperand;
  if Length(FMemory) = 0 then
    MemoryPush(X)
  else
    FMemory[0] := DecAdd(FMemory[0], X);
  FValue := X;
  FEntering := False;
  Changed;
end;

procedure TCalcEngine.MemorySubtract;
var
  X: TDec;
begin
  if FError <> '' then Exit;
  X := GetOperand;
  if Length(FMemory) = 0 then
    MemoryPush(DecNegate(X))
  else
    FMemory[0] := DecSub(FMemory[0], X);
  FValue := X;
  FEntering := False;
  Changed;
end;

procedure TCalcEngine.RecallMemoryItem(AIndex: Integer);
begin
  if FError <> '' then Exit;
  if (AIndex < 0) or (AIndex >= Length(FMemory)) then Exit;
  SetOperandValue(FMemory[AIndex]);
  Changed;
end;

function TCalcEngine.MemoryText(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FMemory)) then
    Result := ''
  else
    Result := FmtDec(FMemory[AIndex]);
end;

{ ---- history ---- }

procedure TCalcEngine.ClearHistory;
begin
  SetLength(FHistText, 0);
  SetLength(FHistResult, 0);
  SetLength(FHistValue, 0);
  Changed;
end;

procedure TCalcEngine.RecallHistoryItem(AIndex: Integer);
begin
  if FError <> '' then Exit;
  if (AIndex < 0) or (AIndex >= Length(FHistValue)) then Exit;
  SetOperandValue(FHistValue[AIndex]);
  Changed;
end;

function TCalcEngine.HistoryExpression(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FHistText)) then Result := '' else Result := FHistText[AIndex];
end;

function TCalcEngine.HistoryResult(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FHistResult)) then Result := '' else Result := FHistResult[AIndex];
end;

{ ---- clipboard ---- }

function TCalcEngine.PasteText(const S: string): Boolean;
var
  T, Clean: string;
  I, Digits: Integer;
  D: TDec;
  Ch: Char;
begin
  Result := False;
  if FError <> '' then Exit;
  // drop grouping / spaces, then unify the decimal separator to '.'
  T := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    if (Ch = ' ') or (Ch = #9) or (Ch = #13) or (Ch = #10) or (Ch = WideChar($00A0)) or (Ch = WideChar($202F)) then
      Continue;
    if (Ch = FGroupSep) and (Ch <> FDecSep) then
      Continue;
    if Ch = FDecSep then Ch := '.';
    T := T + Ch;
  end;
  if Pos('.', T) = 0 then
    for I := 1 to Length(T) do
      if T[I] = ',' then
      begin
        T[I] := '.';
        Break;
      end;
  Clean := '';
  Digits := 0;
  for I := 1 to Length(T) do
  begin
    Ch := T[I];
    if (Ch >= '0') and (Ch <= '9') then
    begin
      Inc(Digits);
      Clean := Clean + Ch;
    end
    else if (Ch = '.') or ((Ch = '-') and (I = 1)) then
      Clean := Clean + Ch
    else
      Exit;  // anything else makes the text not a plain number
  end;
  if (Digits = 0) or (Digits > MaxInputDigits) then Exit;
  if not DecTryParse(Clean, D) then Exit;
  // strip redundant leading zeros: '007' -> '7'
  while (Length(Clean) > 1) and (Clean[1] = '0') and (Clean[2] >= '0') and (Clean[2] <= '9') do
    Delete(Clean, 1, 1);
  if FAfterEq then
    ResetExpression;
  FEntry := Clean;
  FEntering := True;
  FUnaryText := '';
  FHasOperand := True;
  Changed;
  Result := True;
end;

{ ---- read-only state ---- }

function TCalcEngine.GetDisplayValue: string;
begin
  if FError <> '' then
    Result := FError
  else if FEntering then
    Result := FmtEntry
  else
    Result := FmtDec(FValue);
end;

function TCalcEngine.GetExpressionText: string;
begin
  if (FError <> '') or FAfterEq then
    Result := FFinalExpr
  else
    Result := Trim(FPrefix + ' ' + FUnaryText);
end;

function TCalcEngine.GetRawText: string;
begin
  if FError <> '' then
    Result := FError
  else if FEntering then
    Result := StringReplace(FEntry, '.', FDecSep, [])   // exactly what was typed
  else
    Result := DecFormat(FValue, MaxInputDigits, FDecSep, #0);
end;

function TCalcEngine.GetIsError: Boolean;
begin
  Result := FError <> '';
end;

function TCalcEngine.GetHasMemory: Boolean;
begin
  Result := Length(FMemory) > 0;
end;

function TCalcEngine.GetMemoryCount: Integer;
begin
  Result := Length(FMemory);
end;

function TCalcEngine.GetHistoryCount: Integer;
begin
  Result := Length(FHistText);
end;

end.
