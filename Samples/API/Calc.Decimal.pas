unit Calc.Decimal;

{
  Exact decimal arithmetic for the calculator engine (no binary floating point).

  A number is  (-1)^Neg * Mag * 10^Sc  where Mag is a string of decimal digits.
  Intermediate results are rounded to DecPrecision (32) significant digits,
  the display is rounded to 16 - the same idea as Windows Calculator.
  The exponent range is +-DecMaxExp, like the Windows one (about 1e10000).

  Pure Pascal, no Windows / WinRT dependency (compiles with Delphi and FPC).
}

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

type
  TDec = record
    Neg: Boolean;
    Mag: string;   // digits only, no leading zeros, '0' for zero
    Sc: Integer;   // power of ten
  end;

const
  DecPrecision = 32;
  DecMaxExp = 10000;

function DecZero: TDec;
function DecFromInt(AValue: Int64): TDec;
function DecTryParse(const S: string; out D: TDec): Boolean;
function DecIsZero(const D: TDec): Boolean;
function DecSign(const D: TDec): Integer;
function DecCompare(const A, B: TDec): Integer;
function DecNegate(const D: TDec): TDec;
function DecAdd(const A, B: TDec): TDec;
function DecSub(const A, B: TDec): TDec;
function DecMul(const A, B: TDec): TDec;
function DecDiv(const A, B: TDec): TDec;      // B must not be zero
function DecSqrt(const A: TDec): TDec;        // A must not be negative
function DecRound(const D: TDec; ADigits: Integer): TDec;
function DecExponent(const D: TDec): Integer; // number of integer digits (Length(Mag) + Sc)

function DecGroupDigits(const ADigits: string; AGroupSep: Char): string;
// Display text: rounded to ADigits significant digits, scientific form
// (1.5e+25) when too large or too small. AGroupSep = #0 means no grouping.
function DecFormat(const D: TDec; ADigits: Integer; ADecSep, AGroupSep: Char): string;

implementation

uses
{$IFDEF FPC}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

{ ---- digit-string helpers (operands are normalized: no leading zeros) ---- }

function TrimZeros(const S: string): string;
var
  I: Integer;
begin
  if S = '' then
  begin
    Result := '0';
    Exit;
  end;
  I := 1;
  while (I < Length(S)) and (S[I] = '0') do
    Inc(I);
  Result := Copy(S, I, Length(S));
end;

function CmpMag(const A, B: string): Integer;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
  begin
    if Length(A) > Length(B) then Result := 1 else Result := -1;
    Exit;
  end;
  for I := 1 to Length(A) do
    if A[I] <> B[I] then
    begin
      if A[I] > B[I] then Result := 1 else Result := -1;
      Exit;
    end;
  Result := 0;
end;

function AddMag(const A, B: string): string;
var
  I, J, K, Carry, T: Integer;
  R: string;
begin
  SetLength(R, Length(A) + Length(B) + 1);
  I := Length(A);
  J := Length(B);
  K := Length(R);
  Carry := 0;
  while (I > 0) or (J > 0) or (Carry > 0) do
  begin
    T := Carry;
    if I > 0 then begin T := T + Ord(A[I]) - 48; Dec(I); end;
    if J > 0 then begin T := T + Ord(B[J]) - 48; Dec(J); end;
    R[K] := Char(48 + T mod 10);
    Carry := T div 10;
    Dec(K);
  end;
  Result := TrimZeros(Copy(R, K + 1, Length(R)));
end;

// A >= B required
function SubMag(const A, B: string): string;
var
  I, J, K, Borrow, T: Integer;
  R: string;
begin
  SetLength(R, Length(A));
  I := Length(A);
  J := Length(B);
  K := Length(R);
  Borrow := 0;
  while I > 0 do
  begin
    T := Ord(A[I]) - 48 - Borrow;
    Dec(I);
    if J > 0 then begin T := T - (Ord(B[J]) - 48); Dec(J); end;
    if T < 0 then
    begin
      T := T + 10;
      Borrow := 1;
    end
    else
      Borrow := 0;
    R[K] := Char(48 + T);
    Dec(K);
  end;
  Result := TrimZeros(R);
end;

function MulMag(const A, B: string): string;
var
  LA, LB, I, J, Carry, T: Integer;
  Acc: array of Integer;
  R: string;
begin
  LA := Length(A);
  LB := Length(B);
  SetLength(Acc, LA + LB);
  for I := 0 to LA + LB - 1 do
    Acc[I] := 0;
  for I := LA downto 1 do
    for J := LB downto 1 do
      Acc[I + J - 1] := Acc[I + J - 1] + (Ord(A[I]) - 48) * (Ord(B[J]) - 48);
  Carry := 0;
  for I := LA + LB - 1 downto 0 do
  begin
    T := Acc[I] + Carry;
    Acc[I] := T mod 10;
    Carry := T div 10;
  end;
  SetLength(R, LA + LB);
  for I := 0 to LA + LB - 1 do
    R[I + 1] := Char(48 + Acc[I]);
  Result := TrimZeros(R);
end;

// Integer quotient N div D (schoolbook long division). D must not be '0'.
function DivMag(const N, D: string): string;
var
  I, Q: Integer;
  R: string;
begin
  Result := '';
  R := '0';
  for I := 1 to Length(N) do
  begin
    if R = '0' then R := N[I] else R := R + N[I];
    Q := 0;
    while CmpMag(R, D) >= 0 do
    begin
      R := SubMag(R, D);
      Inc(Q);
    end;
    Result := Result + Char(48 + Q);
  end;
  Result := TrimZeros(Result);
end;

procedure Normalize(var D: TDec);
begin
  D.Mag := TrimZeros(D.Mag);
  if D.Mag = '0' then
  begin
    D.Neg := False;
    D.Sc := 0;
    Exit;
  end;
  while (Length(D.Mag) > 1) and (D.Mag[Length(D.Mag)] = '0') do
  begin
    SetLength(D.Mag, Length(D.Mag) - 1);
    Inc(D.Sc);
  end;
end;

{ ---- public API ---- }

function DecZero: TDec;
begin
  Result.Neg := False;
  Result.Mag := '0';
  Result.Sc := 0;
end;

function DecFromInt(AValue: Int64): TDec;
begin
  Result.Neg := AValue < 0;
  Result.Mag := IntToStr(AValue);
  if Result.Neg then
    Delete(Result.Mag, 1, 1);
  Result.Sc := 0;
  Normalize(Result);
end;

function DecTryParse(const S: string; out D: TDec): Boolean;
var
  I: Integer;
  IntPart, FracPart: string;
  SeenDot, SeenDigit: Boolean;
begin
  D := DecZero;
  Result := False;
  I := 1;
  IntPart := '';
  FracPart := '';
  SeenDot := False;
  SeenDigit := False;
  if (Length(S) > 0) and (S[1] = '-') then
  begin
    D.Neg := True;
    I := 2;
  end;
  while I <= Length(S) do
  begin
    if (S[I] >= '0') and (S[I] <= '9') then
    begin
      SeenDigit := True;
      if SeenDot then FracPart := FracPart + S[I] else IntPart := IntPart + S[I];
    end
    else if (S[I] = '.') and (not SeenDot) then
      SeenDot := True
    else
    begin
      D := DecZero;
      Exit;
    end;
    Inc(I);
  end;
  if not SeenDigit then
  begin
    D := DecZero;
    Exit;
  end;
  D.Mag := IntPart + FracPart;
  D.Sc := -Length(FracPart);
  Normalize(D);
  Result := True;
end;

function DecIsZero(const D: TDec): Boolean;
begin
  Result := D.Mag = '0';
end;

function DecSign(const D: TDec): Integer;
begin
  if DecIsZero(D) then Result := 0
  else if D.Neg then Result := -1
  else Result := 1;
end;

function DecExponent(const D: TDec): Integer;
begin
  Result := Length(D.Mag) + D.Sc;
end;

function DecCompare(const A, B: TDec): Integer;
var
  SA, SB, EA, EB, L: Integer;
  MA, MB: string;
begin
  SA := DecSign(A);
  SB := DecSign(B);
  if SA <> SB then
  begin
    if SA > SB then Result := 1 else Result := -1;
    Exit;
  end;
  if SA = 0 then
  begin
    Result := 0;
    Exit;
  end;
  EA := DecExponent(A);
  EB := DecExponent(B);
  if EA <> EB then
  begin
    if EA > EB then Result := SA else Result := -SA;
    Exit;
  end;
  L := Length(A.Mag);
  if Length(B.Mag) > L then L := Length(B.Mag);
  MA := A.Mag + StringOfChar('0', L - Length(A.Mag));
  MB := B.Mag + StringOfChar('0', L - Length(B.Mag));
  Result := CmpMag(MA, MB) * SA;
end;

function DecNegate(const D: TDec): TDec;
begin
  Result := D;
  if not DecIsZero(Result) then
    Result.Neg := not Result.Neg;
end;

function DecRound(const D: TDec; ADigits: Integer): TDec;
var
  Head: string;
  Drop: Integer;
begin
  Result := D;
  if Length(D.Mag) <= ADigits then
    Exit;
  Drop := Length(D.Mag) - ADigits;
  Head := Copy(D.Mag, 1, ADigits);
  if D.Mag[ADigits + 1] >= '5' then
    Head := AddMag(Head, '1');
  Result.Mag := Head;
  Result.Sc := D.Sc + Drop;
  Normalize(Result);
end;

function DecAdd(const A, B: TDec): TDec;
var
  EA, EB, Sc, C: Integer;
  MA, MB: string;
begin
  if DecIsZero(A) then
  begin
    Result := DecRound(B, DecPrecision);
    Exit;
  end;
  if DecIsZero(B) then
  begin
    Result := DecRound(A, DecPrecision);
    Exit;
  end;
  EA := DecExponent(A);
  EB := DecExponent(B);
  // the smaller operand is below the rounding threshold
  if EA - EB > DecPrecision + 8 then
  begin
    Result := DecRound(A, DecPrecision);
    Exit;
  end;
  if EB - EA > DecPrecision + 8 then
  begin
    Result := DecRound(B, DecPrecision);
    Exit;
  end;
  Sc := A.Sc;
  if B.Sc < Sc then Sc := B.Sc;
  MA := A.Mag + StringOfChar('0', A.Sc - Sc);
  MB := B.Mag + StringOfChar('0', B.Sc - Sc);
  if A.Neg = B.Neg then
  begin
    Result.Mag := AddMag(MA, MB);
    Result.Neg := A.Neg;
  end
  else
  begin
    C := CmpMag(MA, MB);
    if C = 0 then
    begin
      Result := DecZero;
      Exit;
    end
    else if C > 0 then
    begin
      Result.Mag := SubMag(MA, MB);
      Result.Neg := A.Neg;
    end
    else
    begin
      Result.Mag := SubMag(MB, MA);
      Result.Neg := B.Neg;
    end;
  end;
  Result.Sc := Sc;
  Normalize(Result);
  Result := DecRound(Result, DecPrecision);
end;

function DecSub(const A, B: TDec): TDec;
begin
  Result := DecAdd(A, DecNegate(B));
end;

function DecMul(const A, B: TDec): TDec;
begin
  if DecIsZero(A) or DecIsZero(B) then
  begin
    Result := DecZero;
    Exit;
  end;
  Result.Mag := MulMag(A.Mag, B.Mag);
  Result.Sc := A.Sc + B.Sc;
  Result.Neg := A.Neg <> B.Neg;
  Normalize(Result);
  Result := DecRound(Result, DecPrecision);
end;

function DecDiv(const A, B: TDec): TDec;
var
  K: Integer;
begin
  if DecIsZero(A) or DecIsZero(B) then
  begin
    Result := DecZero;
    Exit;
  end;
  // scale the dividend so the integer quotient has at least DecPrecision + 3 digits
  K := DecPrecision + 4 + Length(B.Mag) - Length(A.Mag);
  if K < 0 then K := 0;
  Result.Mag := DivMag(A.Mag + StringOfChar('0', K), B.Mag);
  Result.Sc := A.Sc - B.Sc - K;
  Result.Neg := A.Neg <> B.Neg;
  Normalize(Result);
  Result := DecRound(Result, DecPrecision);
end;

function DecSqrt(const A: TDec): TDec;
var
  X, Y, Two: TDec;
  E, I: Integer;
begin
  if DecIsZero(A) or A.Neg then
  begin
    Result := DecZero;
    Exit;
  end;
  Two := DecFromInt(2);
  // start above the root: 10^ceil(E/2); Newton then decreases monotonically
  E := DecExponent(A);
  X.Neg := False;
  X.Mag := '1';
  if E >= 0 then X.Sc := (E + 1) div 2 else X.Sc := -((-E) div 2);
  for I := 1 to 500 do
  begin
    Y := DecDiv(DecAdd(X, DecDiv(A, X)), Two);
    if DecCompare(Y, X) >= 0 then
      Break;
    X := Y;
  end;
  Result := X;
end;

function DecGroupDigits(const ADigits: string; AGroupSep: Char): string;
var
  I, Cnt: Integer;
begin
  Result := '';
  Cnt := 0;
  for I := Length(ADigits) downto 1 do
  begin
    if (AGroupSep <> #0) and (Cnt > 0) and (Cnt mod 3 = 0) then
      Result := AGroupSep + Result;
    Result := ADigits[I] + Result;
    Inc(Cnt);
  end;
end;

function DecFormat(const D: TDec; ADigits: Integer; ADecSep, AGroupSep: Char): string;
var
  R: TDec;
  E, L: Integer;
  M, IntPart, FracPart, ExpStr: string;
begin
  R := DecRound(D, ADigits);
  if DecIsZero(R) then
  begin
    Result := '0';
    Exit;
  end;
  M := R.Mag;
  L := Length(M);
  E := L + R.Sc;
  if (E > ADigits) or (E < -15) then
  begin
    Result := M[1];
    if L > 1 then
      Result := Result + ADecSep + Copy(M, 2, L - 1);
    if E - 1 >= 0 then ExpStr := '+' + IntToStr(E - 1) else ExpStr := '-' + IntToStr(1 - E);
    Result := Result + 'e' + ExpStr;
    if R.Neg then Result := '-' + Result;
    Exit;
  end;
  if E <= 0 then
  begin
    IntPart := '0';
    FracPart := StringOfChar('0', -E) + M;
  end
  else if E >= L then
  begin
    IntPart := M + StringOfChar('0', E - L);
    FracPart := '';
  end
  else
  begin
    IntPart := Copy(M, 1, E);
    FracPart := Copy(M, E + 1, L - E);
  end;
  Result := DecGroupDigits(IntPart, AGroupSep);
  if FracPart <> '' then
    Result := Result + ADecSep + FracPart;
  if R.Neg then
    Result := '-' + Result;
end;

end.
