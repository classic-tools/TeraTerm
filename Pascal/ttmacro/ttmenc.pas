{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, password encryption}
unit TTMEnc;
{$i teraterm.inc}
interface

{$ifdef Delphi}
uses WinTypes, SysUtils;
{$else}
uses WinTypes, Strings;
{$endif}

procedure Encrypt(InStr, OutStr: PCHAR);
procedure Decrypt(InStr, OutStr: PCHAR);

implementation

function EncSeparate(Str: PCHAR; var i: integer; var b: BYTE): BOOL;
var
  cptr, bptr: integer;
  d: word;
begin
  EncSeparate := FALSE;
  cptr := i div 8;
  if Str[cptr]=#0 then exit;
  bptr := i mod 8;
  d := (BYTE(Str[cptr]) shl 8) or
        BYTE(Str[cptr+1]);
  b := BYTE((d shr (10-bptr)) and $3f);

  i := i + 6;

  EncSeparate := TRUE;
end;

function EncCharacterize(c: byte; var b: byte): byte;
var
  d: BYTE;
begin
  d := c + b;
  if d > $7e then d := d - $5e;
  if b<$30 then
    b := $30
  else if b<$40 then
    b := $40
  else if b<$50 then
    b := $50
  else if b<$60 then
    b := $60
  else if b<$70 then
    b := $70
  else
    b := $21;

  EncCharacterize :=  d;
end;

procedure Encrypt(InStr, OutStr: PCHAR);
var
  i, j: integer;
  b, r, r2: byte;
begin
  OutStr[0] := #0;
  if InStr[0]=#0 then exit;
  Randomize;
  r := Random(64) and $3f;
  r2 := (not r) and $3f;
  OutStr[0] := char(r);
  i := 0;
  j := 1;
  while EncSeparate(InStr,i,b) do
  begin
    r := Random(64) and $3f;
    OutStr[j] := char((b + r) and $3f);
    inc(j);
    OutStr[j] := char(r);
    inc(j);
  end;
  OutStr[j] := char(r2);
  inc(j);
  OutStr[j] := #0;
  i := 0;
  b := $21;
  while i < j do
  begin
    OutStr[i]
      := char(EncCharacterize(byte(OutStr[i]),b));
    inc(i);
  end;
end;

procedure DecCombine(Str: PCHAR; var i: integer; b: BYTE);
var
  cptr, bptr: integer;
  d: word;
begin
  cptr := i div 8;
  bptr := i mod 8;
  if bptr=0 then Str[cptr] := #0;

  d := (BYTE(Str[cptr]) shl 8) or
       (b shl (10 - bptr));

  Str[cptr] := char(d shr 8);
  Str[cptr+1] := char(d and $ff);
  i := i + 6;
end;

function DecCharacter(c: byte; var b: byte): BYTE;
var
  d: BYTE;
begin
  if c < b then
    d := $5e + c - b
  else
    d := c - b;
  d := d and $3f;

  if b<$30 then
    b := $30
  else if b<$40 then
    b := $40
  else if b<$50 then
    b := $50
  else if b<$60 then
    b := $60
  else if b<$70 then
    b := $70
  else
    b := $21;

  DecCharacter := d;
end;

procedure Decrypt(InStr, OutStr: PCHAR);
var
  i, j, k: integer;
  b: BYTE;
  Temp: array[0..511] of char;
begin
  OutStr[0] := #0;
  j := strlen(InStr);
  if j=0 then exit;
  b := $21;
  for i:=0 to j-1 do
    Temp[i]
      := char(DecCharacter(byte(InStr[i]),b));
  if (byte(Temp[0]) xor
      byte(Temp[j-1])) <> $3f then exit;
  i := 1;
  k := 0;
  while i < j-2 do
  begin
    Temp[i]
      := char((BYTE(Temp[i]) - BYTE(Temp[i+1])) and $3f);
    DecCombine(OutStr,k,byte(Temp[i]));
    i := i + 2;
  end;
end;

end.
