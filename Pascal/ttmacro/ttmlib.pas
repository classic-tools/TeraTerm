{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, misc routines}
unit TTMLib;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, WinDos, Strings, Types, TTLib;
{$ELSE}
uses
  WinTypes, WinProcs, Win31, WinDos, Strings, Types, TTLib;
{$ENDIF}

procedure CalcTextExtent(DC: HDC; Text: PCHAR; var s: TSize);
procedure TTMGetDir(Dir: PChar);
procedure TTMSetDir(Dir: PChar);
procedure GetAbsPath(FName: PChar);

implementation

var
  CurrentDir: array[0..MAXPATHLEN-1] of char;

procedure CalcTextExtent(DC: HDC; Text: PCHAR; var s: TSize);
var
  W, H, i, i0: integer;
  Temp: array[0..255] of char;
  dwExt: dword;
begin
  W := 0;
  H := 0;
  i := 0;
  repeat
    i0 := i;
    while (Text[i]<>#0) and
	  (Text[i]<>#$0d) and
	  (Text[i]<>#$0a) do
      inc(i);
    move(Text[i0],Temp[0],i-i0);
    Temp[i-i0] := #0;
    if Temp[0]=#0 then
    begin
     Temp[0] := #$20;
     Temp[1] := #0;
    end;
    dwExt := GetTabbedTextExtent(DC,Temp,strlen(Temp),0,nil);
    s.cx := LOWORD(dwExt);
    s.cy := HIWORD(dwExt);
    if s.cx > W then W := s.cx;
    H := H + s.cy;
    if Text[i]<>#0 then
    begin
      inc(i);
      if (Text[i]=#$0a) and
         (Text[i-1]=#$0d) then
	inc(i);
    end;
  until Text[i]=#0;
  if (i-i0 = 0) and (H > s.cy) then H := H - s.cy;
  s.cx := W;
  s.cy := H;
end;

procedure TTMGetDir(Dir: PChar);
begin
  strcopy(Dir,CurrentDir);
end;

procedure TTMSetDir(Dir: PChar);
var
  Temp: array[0..MAXPATHLEN-1] of char;
begin
  GetCurDir(Temp,0);
  SetCurDir(CurrentDir);
  SetCurDir(Dir);
  GetCurDir(CurrentDir,0);
  SetCurDir(Temp);
end;

procedure GetAbsPath(FName: PChar);
var
  i, j: integer;
  Temp: array[0..MAXPATHLEN-1] of char;
begin
  if not GetFileNamePos(FName,i,j) or
     (i>0) then exit;
  strcopy(Temp,FName);
  strcopy(FName,CurrentDir);
  AppendSlash(FName);
  strcat(FName,Temp);
end;

end.
