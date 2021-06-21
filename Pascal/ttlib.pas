{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{Misc. routines}
unit TTLib;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses WinTypes, WinProcs, Strings, SysUtils, Types;
{$ELSE}
uses WinTypes, WinProcs, Strings, WinDos, Types;
{$ENDIF}

function GetFileNamePos(PathName: PChar; var DirLen,FNPos: integer): BOOL;
function ExtractFileName(PathName,FileName: PChar): BOOL;
function ExtractDirName(PathName,DirName: PChar): BOOL;
procedure FitFileName(FileName, DefExt: PChar);
procedure AppendSlash(Path: PCHAR);
procedure Str2Hex(Str, Hex: PChar; Len, MaxHexLen: integer; ConvSP: BOOL);
function ConvHexChar(b: byte): byte;
function Hex2Str(Hex, Str: PChar; MaxLen: integer): integer;
function DoesFileExist(FName: PCHAR): BOOL;
function GetFSize(FName: PCHAR): longint;
procedure uint2str(i: uint; StrBuff: PCHAR; len: integer);
procedure remove(FName: PChar);
{$ifdef TERATERM32}
procedure QuoteFName(FName: PChar);
{$endif}

implementation

{$ifndef TERATERM32}
function CharNext(CurrentChar: PChar): PChar;
begin
  CharNext := AnsiNext(CurrentChar);
end;

function CharPrev(Start, CurrentChar: PChar): PChar;
begin
  CharPrev := AnsiPrev(Start, CurrentChar);
end;
{$endif}

function GetFileNamePos(PathName: PChar; var DirLen,FNPos: integer): BOOL;
var
  b: char;
  Ptr, DirPtr, FNPtr, PtrOld: PCHAR;
begin
  GetFileNamePos := FALSE;
  DirLen := 0;
  FNPos := 0;
  if PathName=nil then exit;

  if (strlen(PathName)>=2) and (PathName[1]=':') then
	Ptr := @PathName[2]
  else
	Ptr := PathName;
  if Ptr[0]='\' then Ptr := CharNext(Ptr);

  DirPtr := Ptr;
  FNPtr := Ptr;
  while Ptr[0]<>#0 do
  begin
    b := Ptr[0];
    PtrOld := Ptr;
    Ptr := CharNext(Ptr);
    case b of
      ':': exit;
      '\': begin
          DirPtr := PtrOld;
          FNPtr := Ptr;
        end;
    end;
  end;
  DirLen := DirPtr-PathName;
  FNPos := FNPtr-PathName;
  GetFileNamePos := TRUE;
end;

function ExtractFileName(PathName,FileName: PChar): BOOL;
var
  i, j: integer;
begin
  ExtractFileName := FALSE;
  if FileName=nil then exit;
  if not GetFileNamePos(PathName,i,j) then exit;
  strcopy(FileName,@PathName[j]);
  ExtractFileName := StrLen(FileName)>0;
end;

function ExtractDirName(PathName,DirName: PChar): BOOL;
var
  i, j: integer;
begin
  ExtractDirName := FALSE;
  if DirName=nil then exit;
  if not GetFileNamePos(PathName,i,j) then exit;
  ExtractDirName := TRUE;
  Move(PathName[0],DirName[0],i);
  DirName[i] := #0;
end;

{ fit a given file to the windows-filename format
  FileName must contain filename part only.}
procedure FitFileName(FileName, DefExt: PChar);
var
  i, j, NumOfDots: integer;
  Temp: array[0..MAXPATHLEN-1] of char;
  b: byte;
{$ifndef TEARTERM32}
  NameLen: integer;
{$endif}
begin
  NumOfDots := 0;
  i := 0;
  j := 0;
  { filename started with a dot is illeagal }
  if FileName[0]='.' then
  begin
    Temp[0] := '_'; {insert an underscore char}
    inc(j);
  end;

  repeat
    b := byte(FileName[i]);
    inc(i);
{$IFDEF TERATERM32}
    if b=ord('.') then inc(NumOfDots);
{$ELSE}
    if b=ord('.') then
    begin
      inc(NumOfDots);
      NameLen := j;
    end;
{$ENDIF}
    if (b<>0) and
      (j<MAXPATHLEN-1) then
    begin
      Temp[j] := char(b);
      inc(j);
    end;
  until (b=0);
  Temp[j] := #0;

{$IFDEF TERATERM32}
  if (NumOfDots=0) and (DefExt<> nil) then
    StrCat(Temp,DefExt); // add the default extension

  StrCopy(FileName,Temp);
{$ELSE}
  if NumOfDots=0 then
  begin
    NameLen := j;
    if DefExt<>nil then
      strcat(Temp,DefExt); { add the default extension}
  end;
  for i := 0 to NameLen-1 do
    if Temp[i]='.' then {convert dots in the filename}
      Temp[i] := '_';   {to underscores.}
  strcopy(FileName,Temp);
  if NameLen>8 then
    FileName[8] := #0
  else
    FileName[NameLen] := #0;
  strlcat(FileName,@Temp[NameLen],12);
{$ENDIF}
end;

procedure AppendSlash(Path: PCHAR);
begin
  if (strcomp(CharPrev(Path,@Path[strlen(Path)]),
             '\') <> 0) then
    strcat(Path,'\');
end;

procedure Str2Hex(Str, Hex: PChar; Len, MaxHexLen: integer; ConvSP: bool);
var
  b, low: byte;
  i, j: integer;
begin
  if ConvSP then
    low := $20
  else
    low := $1F;

  j := 0;
  for i := 0 to Len-1 do
  begin
    b := byte(Str[i]);
    if (b<>Ord('$')) and (b>Low) and (b<$7f) then
    begin
      if j < MaxHexLen then
      begin
        Hex[j] := char(b);
        inc(j);
      end;
    end
    else begin
      if j < MaxHexLen-2 then
      begin
        Hex[j] := '$';
        inc(j);
        case b of
          $00..$9F: Hex[j] := char(b shr 4 + $30);
          $A0..$FF: Hex[j] := char(b shr 4 + $37);
        end;
        inc(j);
        case b and $0F of
          $0..$9: Hex[j] := char(b and $0F + $30);
          $A..$F: Hex[j] := char(b and $0F + $37);
        end;
        inc(j);
      end;
    end;
  end;
  Hex[j] := #0;
end;

function ConvHexChar(b: byte): byte;
begin
  case b of
    ord('0')..ord('9'):
      ConvHexChar := b - $30;
    ord('A')..ord('F'):
      ConvHexChar := b - $37;
    ord('a')..ord('f'):
      ConvHexChar := b - $57;
  else
    ConvHexChar := 0;
  end;
end;

function Hex2Str(Hex, Str: PChar; MaxLen: integer): integer;
var
  b, c: byte;
  i, imax, j: integer;
begin
  j := 0;
  imax := strlen(Hex);
  i := 0;
  while (i < imax) and (j<MaxLen)do
  begin
    b := byte(Hex[i]);
    if b=ord('$') then
    begin
      inc(i);
      if i < imax then
        c := byte(Hex[i])
      else
        c := $30;
      b := ConvHexChar(c) shl 4;
      inc(i);
      if i < imax then
        c := byte(Hex[i])
      else
        c := $30;
      b := b + ConvHexChar(c);
    end;

    Str[j] := char(b);
    inc(j);

    inc(i);
  end;
  if j<MaxLen then Str[j] := #0;

  Hex2Str := j;
end;

function DoesFileExist(FName: PCHAR): BOOL;
var
  SearchRec: TSearchRec;
begin
{$ifdef Delphi}
  DoesFileExist :=
    (FindFirst(StrPas(FName),
               faAnyFile,SearchRec) = 0);
{$endif}
{$ifdef TPW}
  FindFirst(FName,faAnyFile,SearchRec);
  DoesFileExist := (DosError=0);
{$endif}
end;

function GetFSize(FName: PCHAR): longint;
var
  SearchRec: TSearchRec;
begin
  GetFSize := 0;
{$ifdef Delphi}
  if FindFirst(StrPas(FName),
               faAnyFile,SearchRec) <> 0
  then exit;
{$endif}
{$ifdef TPW}
  FindFirst(FName,faAnyFile,SearchRec);
  if DosError<>0 then exit;
{$endif}
  GetFSize := SearchRec.Size;
end;

procedure uint2str(i: uint; StrBuff: PCHAR; len: integer);
var
  TempPas: string[20];
  Temp: array[0..19] of char;
begin
  Str(i,TempPas);
  StrPCopy(Temp,TempPas);
  Temp[len] := #0;
  strcopy(StrBuff,Temp);
end;

{$ifdef TERATERM32}
procedure QuoteFName(FName: PChar)
var
  i: integer;
begin
  if FName[0]=#0 then exit;
  if strscan(FName,' ')=nil then exit;
  i := strlen(FName);
  Move(FName[0],FName[1],i);
  FName[0] := '"';
  FName[i+1] := '"';
  FName[i+2] := #0;
end;
{$endif}

procedure remove(FName: PChar);
{delete a file}
var
  f: file;
begin
  assign(f, strpas(FName));
  {$i-}
  erase(f);
  {$i+}
end;

end.
