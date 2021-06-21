{ Teraterm extension mechanism
   Robert O'Callahan (roc+tt@cs.cmu.edu)
   
   Teraterm by Takashi Teranishi (teranishi@rikaxp.riken.go.jp)
}
library TTXTest;
{$i teraterm.inc}

uses
  WinTypes, WinProcs, Win31, Strings, TTTypes, TTXTypes;

const
  ORDER = 4000;

var
  hInst: THandle; {hInstance of TTXTEST.DLL}
  Exp: TTXExports;

type
  PInstVar = ^TInstVar;
  TInstVar = record
    ts: PTTSet;
    cv: PComVar;
    SetupMenu: HMENU;
  end;

var {pointer to InstVar}
  pvar: PInstVar;

{$ifdef TERATERM32}
  {WIN32 allows multiple instances of a DLL}
  InstVar: TInstVar;
{$else}
const
  {WIN16 does not allow multiple instances}

  {maximum number of Tera Term instances}
  MAXNUMINST = 32;
var
  TaskList: array[0..MAXNUMINST-1] of THandle;
  InstVar: array[0..MAXNUMINST-1] of TInstVar;

function NewVar: BOOL;
var
  i: integer;
  Task: THandle;
begin
  NewVar := FALSE;
  Task := GetCurrentTask;
  if Task=0 then exit;
  i := 0;
  while (i<MAXNUMINST) and (TaskList[i]<>0) do
    inc(i);
  if i>=MAXNUMINST then exit;
  pvar := @InstVar[i];
  TaskList[i] := Task;
  NewVar := TRUE;
end;

procedure DelVar;
var
  i: integer;
  Task: THandle;
begin
  Task := GetCurrentTask;
  if Task=0 then exit;
  i := 0;
  while (i<MAXNUMINST) and (TaskList[i]<>Task) do
    inc(i);
  if i>=MAXNUMINST then exit;
  TaskList[i] := 0;
end;

function GetVar: BOOL;
var
  i: integer;
  Task: THandle;
begin
  GetVar := FALSE;
  Task := GetCurrentTask;
  if Task=0 then exit;
  i := 0;
  while (i<MAXNUMINST) and (TaskList[i]<>Task) do
    inc(i);
  if i>=MAXNUMINST then exit;

  pvar := @InstVar[i];
  GetVar := TRUE;
end; 
{$endif}

procedure TTXInit(ts: PTTSet; cv: PComVar); export;
begin
{$ifndef TERATERM32}
  if not NewVar then exit; {should be called first}
{$endif}
  pvar^.ts := ts;
  pvar^.cv := cv;
end;

procedure TTXOpenTCP(hooks: PTTXSockHooks); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
end;

procedure TTXCloseTCP(hooks: PTTXSockHooks); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
end;

procedure TTXGetUIHooks(hooks: PTTXUIHooks); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
end;

procedure TTXGetSetupHooks(hooks: PTTXSetupHooks); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
end;

procedure TTXSetWinSize(rows, cols: integer); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
end;

const
  ID_MENUITEM = 6000;

procedure TTXModifyMenu(menu: HMENU); export;
var
  flag: integer;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
  flag := MF_ENABLED;

  pvar^.SetupMenu := GetSubMenu(menu,2);
  AppendMenu(pvar^.SetupMenu,MF_SEPARATOR,0,nil);
  if pvar^.ts^.Debug>0 then flag := flag or MF_CHECKED;
  AppendMenu(pvar^.SetupMenu,flag, ID_MENUITEM,'&Debug mode');
end;  

procedure TTXModifyPopupMenu(menu: HMENU); export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
  if menu=pvar^.SetupMenu then
  begin
    if pvar^.cv^.Ready then
      EnableMenuItem(pvar^.SetupMenu,ID_MENUITEM,MF_BYCOMMAND or MF_ENABLED)
    else
      EnableMenuItem(pvar^.SetupMenu,ID_MENUITEM,MF_BYCOMMAND or MF_GRAYED);
  end;
end;

function TTXProcessCommand(hWin: HWND; cmd: WORD): integer; export;
begin
{$ifndef TERATERM32}
  if not GetVar then exit; {should be called first}
{$endif}
  if cmd=ID_MENUITEM then
  begin
    if pvar^.ts^.Debug=0 then
    begin
      pvar^.ts^.Debug:=1;
      CheckMenuItem(pvar^.SetupMenu,ID_MENUITEM,MF_BYCOMMAND or MF_CHECKED);
    end
    else begin
      pvar^.ts^.Debug:=0;
      CheckMenuItem(pvar^.SetupMenu,ID_MENUITEM,MF_BYCOMMAND or MF_UNCHECKED);
    end; 
    TTXProcessCommand := 1;
    exit;
  end;
  TTXProcessCommand := 0;
end;

procedure TTXEnd; export;
begin
{$ifndef TERATERM32}
  DelVar; {should be called last}
{$endif}
end;

function TTXBind(Version: WORD; _exports: PTTXExports): BOOL; export;
var
  size: integer;
begin
  TTXBind := FALSE;
  if Version<>TTVERSION then exit;
  size := sizeof(Exp) - sizeof(_exports^.size);

  if size > _exports^.size then
    size := _exports^.size;

  move(Exp.loadOrder,_exports^.loadOrder,size);
  TTXBind := TRUE;
end;

exports
  TTXBind       index 1;

{$ifndef TERATERM32}
var
  i: integer;
{$endif}
begin
{$ifdef TERATERM32}
  pvar := @InstVar;
{$else}
  for i := 0 to MAXNUMINST-1 do
    TaskList[i] := 0;
{$endif}
  hInst := hInstance;

  Exp.size := sizeof(TTXExports);
  Exp.loadOrder := ORDER;
  @Exp.TTXInit := @TTXInit;
  @Exp.TTXGetUIHooks := @TTXGetUIHooks;
  @Exp.TTXGetSetupHooks := @TTXGetSetupHooks;
  @Exp.TTXOpenTCP := @TTXOpenTCP;
  @Exp.TTXCloseTCP := @TTXCloseTCP;
  @Exp.TTXSetWinSize := @TTXSetWinSize;
  @Exp.TTXModifyMenu := @TTXModifyMenu;
  @Exp.TTXModifyPopupMenu := @TTXModifyPopupMenu;
  @Exp.TTXProcessCommand := @TTXProcessCommand;
  @Exp.TTXEnd := @TTXEnd;
end.
