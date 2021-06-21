{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{KEYCODE.EXE, main}
program KeyCode;
{$R keycode.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses OWindows, KCodeWin;
{$ELSE}
uses WObjects, KCodeWin;
{$ENDIF}

type

  KCodeAppli = object(TApplication)
    procedure InitMainWindow; virtual;
  end;

procedure KCodeAppli.InitMainWindow;
begin
  MainWindow := New(PKCodeWindow, Init(nil,'Key code for Tera Term'));
end;

var
  KCode: KCodeAppli;

begin
  KCode.Init('Key code for Tera Term');
  KCode.Run;
  KCode.Done;
end.