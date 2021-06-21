{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{Routines for dialog boxes}
unit DlgLib;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, Strings;
{$ELSE}
uses WinTypes, WinProcs, Strings;
{$ENDIF}

type
  TList = array[0..20] of PChar;
  PList = ^TList;

procedure EnableDlgItem(HDlg:HWnd; FirstId, LastId: word);
procedure DisableDlgItem(HDlg:HWnd; FirstId, LastId: word);
procedure ShowDlgItem(HDlg:HWnd; FirstId, LastId: word);
procedure SetRB(HDlg: HWnd; R, FirstID, LastID: word);
procedure GetRB(HDlg: HWnd; var R: word; FirstID, LastID: word);
procedure SetDlgNum(HDlg: HWnd; id_Item: integer; Num: longint);
procedure SetDlgPercent(HDlg: HWnd; id_Item: integer; a,b: longint);
procedure SetDropDownList(HDlg: HWND; Id_Item: integer; List: PList; nsel: integer);
function GetCurSel(HDlg: HWND; Id_Item: integer): longint;

implementation

procedure EnableDlgItem(HDlg:HWnd; FirstId, LastId: word);
var
  i: integer;
  HControl: HWnd;
begin
  for i := FirstId to LastId do
  begin
    HControl := GetDlgItem(HDlg, i);
    EnableWindow(HControl,TRUE);
  end;
end;

procedure DisableDlgItem(HDlg:HWnd; FirstId, LastId: word);
var
  i: integer;
  HControl: HWnd;
begin
  for i := FirstId to LastId do
  begin
    HControl := GetDlgItem(HDlg, i);
    EnableWindow(HControl,FALSE);
  end;
end;

procedure ShowDlgItem(HDlg:HWnd; FirstId, LastId: word);
var
  i: integer;
  HControl: HWnd;
begin
  for i := FirstId to LastId do
  begin
    HControl := GetDlgItem(HDlg, i);
    ShowWindow(HControl,SW_Show);
  end;
end;

procedure SetRB(HDlg: HWnd; R, FirstID, LastID: word);
var
  HControl: HWnd;
{$ifdef TERATERM32}
  Style: DWORD;
{$else}
  Style: WORD;
{$endif}
begin
  if R<1 then exit;
  if FirstID+R-1 > LastID then exit;
  HControl := GetDlgItem(HDlg, FirstID + R - 1);
  SendMessage(HControl, bm_SetCheck, 1, 0);
{$ifdef TERATERM32}
  Style := GetClassLong(HControl, GCL_STYLE);
  SetClassLong(HControl, GCL_STYLE, Style or WS_TABSTOP);
{$else}
  Style := GetClassWord(HControl, GCW_STYLE);
  SetClassWord(HControl, GCW_STYLE, Style or WS_TABSTOP);
{$endif}
end;

procedure GetRB(HDlg: HWnd; var R: word; FirstID, LastID: word);
var
  i: integer;
begin
  R := 0;
  for i := FirstID to LastId do
    if SendDlgItemMessage(HDlg, i, bm_GetCheck, 0, 0) <> 0 then
    begin
      R := i - FirstID + 1;
      exit;
    end;
end;

procedure SetDlgNum(HDlg: HWnd; id_Item: integer; Num: longint);
var
  NumStr: string[15];
  Temp: array[0..15] of char;
begin
  {In Win16, SetDlgItemInt can not be used to display long integer.}
  Str(Num,NumStr);
  StrPCopy(Temp,NumStr);
  SetDlgItemText(HDlg,id_Item,Temp);
end;

procedure SetDlgPercent(HDlg: HWnd; id_Item: integer; a,b: longint);
var
  Num: longint;
  NumPStr: string[10];
  NumStr: array[0..12] of char;
begin
  if b=0 then
    Num := 100
  else
    Num := 100 * a div b;
  Str(Num,NumPStr);
  StrPCopy(NumStr,NumPStr);
  StrCat(NumStr,'%');
  SetDlgItemText(HDlg, id_Item, NumStr);
end;

procedure SetDropDownList(HDlg: HWND; Id_Item: integer; List: PList; nsel: integer);
var
  i: integer;
begin
  i := 0;
  while List^[i] <> nil do
  begin
    SendDlgItemMessage(HDlg, Id_Item, CB_ADDSTRING,
                       0, longint(List^[i]));
    inc(i);
  end;
  SendDlgItemMessage(HDlg, Id_Item, CB_SETCURSEL,nsel-1,0);
end;

function GetCurSel(HDlg: HWND; Id_Item: integer): longint;
var
  n: longint;
begin
  n := SendDlgItemMessage(HDlg, Id_Item, CB_GETCURSEL, 0, 0);
  if n=CB_ERR then
    n := 0
  else
    inc(n);

  GetCurSel := n;
end;

end.