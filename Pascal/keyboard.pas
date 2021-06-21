{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, keyboard routines}
unit Keyboard;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, Strings,
  TTTypes, Types, TTWinMan, TTLib, TTSetup, TTCommon, TTDDE;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings,
  TTTypes, Types, TTWinMan, TTLib, TTSetup, TTCommon, TTDDE;
{$ENDIF}

procedure SetKeyMap;
procedure ClearUserKey;
procedure DefineUserKey(NewKeyId: integer; NewKeyStr: PChar; NewKeyLen: integer);
function KeyDown(HWin: HWnd; VKey, Count, Scan: WORD): bool;
procedure KeyCodeSend(KCode, Count: WORD);
procedure KeyUp(VKey: WORD);
function ShiftKey: BOOL;
function ControlKey: BOOL;
function AltKey: BOOL;
procedure InitKeyboard;
procedure EndKeyboard;

const
  FuncKeyStrMax = 32;

var
  AutoRepeatMode: bool;
  AppliKeyMode, AppliCursorMode: bool;
  DebugFlag: bool;

implementation

var
  FuncKeyStr: array[0..IdUDK20-IdUDK6, 0..FuncKeyStrMax-1] of char;
  FuncKeyLen: array[0..IdUDK20-IdUDK6] of integer;

  {keyboard status}
  PreviousKey: integer;

  {key code map}
  KeyMap: PKeyMap;

  {Ctrl-\ support for NEC-PC98}
  VKBackslash: word;

const
  VK_PROCESSKEY = $E5;

procedure SetKeyMap;
var
 TempDir: array[0..MAXPATHLEN-1] of char;
 TempName: array[0..MAXPATHLEN-1] of char;
begin
  if StrLen(ts.KeyCnfFN)=0 then exit;
  ExtractFileName(ts.KeyCnfFN,TempName);
  ExtractDirName(ts.KeyCnfFN,TempDir);
  if TempDir[0]=#0 then
    strcopy(TempDir,ts.HomeDir);
  FitFileName(TempName,'.CNF');

  strcopy(ts.KeyCnfFN,TempDir);
  AppendSlash(ts.KeyCnfFN);
  strcat(ts.KeyCnfFN,TempName);

  if KeyMap=nil then
    New(KeyMap);
  if KeyMap<>nil then
  begin
    if LoadTTSet then
      ReadKeyboardCnf(ts.KeyCnfFN, KeyMap, TRUE);
    FreeTTSet;
  end;
  if (stricomp(TempDir,ts.HomeDir)=0) and
     (stricomp(TempName,'KEYBOARD.CNF')=0) then
  begin
    ChangeDefaultSet(nil,KeyMap);
    Dispose(KeyMap);
    KeyMap := nil;
  end;
end;

procedure ClearUserKey;
var
  i: integer;
begin
  for i := 0 to IdUDK20-IdUDK6 do
  begin
    FuncKeyLen[i] := 0;
  end; 
end;

procedure DefineUserKey(NewKeyId: integer; NewKeyStr: PChar; NewKeyLen: integer);
begin
  if (NewKeyLen=0) or (NewKeyLen>FuncKeyStrMax) then exit;

  case NewKeyId of
    17..21: NewKeyId := NewKeyId-17;
    23..26: NewKeyId := NewKeyId-18;
    28..29: NewKeyId := NewKeyId-19;
    31..34: NewKeyId := NewKeyId-20;
  else
    exit;
  end;

  Move(NewKeyStr[0], FuncKeyStr[NewKeyId,0], NewKeyLen);
  FuncKeyLen[NewKeyId] := NewKeyLen;

end;

function KeyDown(HWin: HWnd; VKey, Count, Scan: WORD): bool;
var
  Key : word;
  M :TMsg;
  KeyState: array[0..255] of byte;
  Single, Control: bool;
  i: integer;
  CodeCount: integer;
  CodeLength: integer;
  Code: array[0..MAXPATHLEN-1] of char;
  CodeType: word;
  wId: WORD;
  c: integer;
begin
  KeyDown := TRUE;
  if VKey=VK_PROCESSKEY then exit;

  if (VKey=VK_SHIFT) or
     (VKey=VK_CONTROL) or
     (VKey=VK_MENU) then exit;

  {debug mode}
  if (ts.Debug>0) and (VKey = VK_ESCAPE) and
     ShiftKey then
  begin
    MessageBeep(0);
    DebugFlag := not DebugFlag;
    CodeCount := 0;
    PeekMessage(M,HWin,WM_CHAR,WM_CHAR,PM_REMOVE);
    exit;
  end;

  if not AutoRepeatMode and (PreviousKey=VKey) then
  begin
    PeekMessage(M,HWin,WM_CHAR,WM_CHAR,PM_REMOVE);
    exit;
  end;

  PreviousKey := VKey;

  if Scan=0 then
    Scan := MapVirtualKey(VKey,0);

  Single := TRUE;
  Control := TRUE;

  if ShiftKey then
  begin
    Scan := Scan or $200;
    Single := FALSE;
    Control := FALSE;
  end;

  if ControlKey then
  begin
    Scan := Scan or $400;
    Single := FALSE;
  end
  else
    Control := FALSE;

  if AltKey then
  begin
    Scan := Scan or $800;
    if ts.MetaKey=0 then
    begin
      Single := FALSE;
      Control := FALSE;
    end;
  end;
 
  CodeCount := Count;
  CodeLength := 0;
  CodeType := IdBinary;

  if (VKey<>VK_DELETE) or (ts.DelKey=0) then
    {Windows keycode -> Tera Term keycode}
    Key := GetKeyCode(KeyMap,Scan)
  else
    Key := 0;

  if Key=0 then
  begin
    case VKey of
      VK_BACK:
        if Control then
        begin
          CodeLength := 1;
          if ts.BSKey=IdDel then Code[0] := #$08
                            else Code[0] := #$7F
        end
        else if Single then
        begin
          CodeLength := 1;
          if ts.BSKey=IdDel then Code[0] := #$7F
                            else Code[0] := #$08;
        end;
      VK_RETURN: {CR Key}
        if Single then
        begin
          CodeType := IdText; {do new-line conversion}
          CodeLength := 1;
          Code[0] := #$0D;
        end;
      VK_SPACE:
        if Control then
        begin {Ctrl-Space -> NUL}
          CodeLength := 1;
          Code[0] := #0;
        end;
      VK_DELETE:
        if Single and (ts.DelKey>0) then
        begin {DEL character}
          CodeLength := 1;
          Code[0] := #$7F;
        end;
    else
      if (VKey=VKBackslash) and Control then
      begin {Ctrl-\ support for NEC-PC98}
        CodeLength := 1;
        Code[0] := #$1C;
      end;
    end;
    if (ts.MetaKey>0) and (CodeLength=1) and
       AltKey then
    begin
      Code[1] := Code[0];
      Code[0] := #$1B;
      CodeLength := 2;
      PeekMessage(M,HWin,WM_SYSCHAR,WM_SYSCHAR,PM_REMOVE);
    end;
  end
  else if (IdUDK6<=Key) and (Key<=IdUDK20) and
          (FuncKeyLen[Key-IdUDK6]>0) then
  begin
    Move(FuncKeyStr[Key-IdUDK6,0], Code[0], FuncKeyLen[Key-IdUDK6]);
    CodeLength := FuncKeyLen[Key-IdUDK6];
    CodeType := IdBinary;
  end
  else
    GetKeyStr(HWin,KeyMap,Key,AppliKeyMode,AppliCursorMode,
              Code,@CodeLength,@CodeType);

  if CodeLength=0 then
  begin
    KeyDown := FALSE;
    exit;
  end;

  if VKey=VK_NUMLOCK then
  begin
    {keep NumLock LED status}
    GetKeyboardState(TKeyboardState(KeyState));
    KeyState[VK_NUMLOCK] := KeyState[VK_NUMLOCK] xor 1;
    SetKeyboardState(TKeyboardState(KeyState));
  end;

  PeekMessage(M,HWin,WM_CHAR,WM_CHAR,PM_REMOVE);

  if KeybEnabled then
  begin
    case CodeType of
      IdBinary:
        if TalkStatus=IdTalkKeyb then
        begin
          for i := 1 to  CodeCount do
          begin
            CommBinaryOut(@cv,Code,CodeLength);
            if ts.LocalEcho>0 then
              CommBinaryEcho(@cv,Code,CodeLength);
          end;
        end;
      IdText:
        if TalkStatus=IdTalkKeyb then
        begin
          for i := 1 to  CodeCount do
          begin
            if ts.LocalEcho>0 then
              CommTextEcho(@cv,Code,CodeLength);
            CommTextOut(@cv,Code,CodeLength);
          end;
        end;
      IdMacro: begin
          Code[CodeLength] := #0;
          RunMacro(Code,FALSE);
        end;
      IdCommand: begin
          Code[CodeLength] := #0;
          Val(StrPas(Code),wId,c);
          if c=0 then
{$ifdef TERATERM32}
            PostMessage(HWin,WM_COMMAND,MAKELONG(wId,0),0);
{$else}
            PostMessage(HWin,WM_COMMAND,wId,0);
{$endif}
        end;
    end;
  end;
end;

procedure KeyCodeSend(KCode, Count: WORD);
var
  Key : word;
  i: integer;
  CodeLength: integer;
  Code: array[0..MAXPATHLEN-1] of char;
  CodeType: word;
  Scan, VKey, State: word;
  Single, Control: bool;
  dw: DWORD;
  Ok: bool;
  HWin: HWND;
begin
  if ActiveWin=IdTEK then
    HWin := HTEKWin
  else
    HWin := HVTWin;

  CodeLength := 0;
  CodeType := IdBinary;
  Key := GetKeyCode(KeyMap,KCode);
  if Key=0 then
  begin
    Scan := KCode and $1FF;
    VKey := MapVirtualKey(Scan,1);
    State := 0;
    Single := TRUE;
    Control := TRUE;
    if (KCode and 512) <> 0 then
    begin {shift}
      State := State or 2; {bit 1}
      Single := FALSE;
      Control := FALSE;
    end; 

    if (KCode and 1024) <> 0 then
    begin {control}
      State := State or 4; {bit 2}
      Single := FALSE;
    end
    else
      Control := FALSE;

    if (KCode and 2048) <> 0 then
    begin {alt}
      State := State or 16; {bit 4}
      Single := FALSE;
      Control := FALSE;
    end;

    case VKey of
      VK_BACK:
        if Control then
        begin
          CodeLength := 1;
          if ts.BSKey=IdDel then Code[0] := #$08
                            else Code[0] := #$7F
        end
        else if Single then
        begin
          CodeLength := 1;
          if ts.BSKey=IdDel then Code[0] := #$7F
                            else Code[0] := #$08;
        end;
      VK_RETURN: {CR Key}
        if Single then
        begin
          CodeType := IdText; {do new-line conversion}
          CodeLength := 1;
          Code[0] := #$0D;
        end;
      VK_SPACE:
        if Control then
        begin {Ctrl-Space -> NUL}
          CodeLength := 1;
          Code[0] := #0;
        end;      
      VK_DELETE:
        if Single and (ts.DelKey>0) then
        begin {DEL character}
          CodeLength := 1;
          Code[0] := #$7F;
        end;
    else
      if (VKey=VKBackslash) and Control then
      begin {Ctrl-\ support for NEC-PC98}
        CodeLength := 1;
        Code[0] := #$1C;
      end;
    end;

    if CodeLength=0 then
    begin
      i := -1;
      repeat
        inc(i);
        dw := OemKeyScan(i);
        Ok := (LOWORD(dw)=Scan) and
              (HIWORD(dw)=State);
      until (i=255) or Ok;
      if Ok then
      begin
        CodeType := IdText;
        CodeLength := 1;
        Code[0] := char(i);
      end;
    end;
  end
  else if (IdUDK6<=Key) and (Key<=IdUDK20) and
          (FuncKeyLen[Key-IdUDK6]>0) then
  begin
    Move(FuncKeyStr[Key-IdUDK6,0], Code[0], FuncKeyLen[Key-IdUDK6]);
    CodeLength := FuncKeyLen[Key-IdUDK6];
    CodeType := IdBinary;
  end
  else
    GetKeyStr(HWin,KeyMap,Key,AppliKeyMode,AppliCursorMode,
              Code,@CodeLength,@CodeType);

  if CodeLength=0 then exit;
  if (TalkStatus=IdTalkKeyb) then
    case CodeType of
      IdBinary:
        for i := 1 to  Count do
        begin
          CommBinaryOut(@cv,Code,CodeLength);
          if ts.LocalEcho>0 then
            CommBinaryEcho(@cv,Code,CodeLength);
        end;
      IdText:
        for i := 1 to  Count do
        begin
          if ts.LocalEcho>0 then
            CommTextEcho(@cv,Code,CodeLength);
          CommTextOut(@cv,Code,CodeLength);
        end;
      IdMacro: begin
          Code[CodeLength] := #0;
          RunMacro(Code,FALSE);
        end;
    end;
end;

procedure KeyUp(VKey: WORD);
begin
  if PreviousKey = VKey then PreviousKey := 0;
end;

function ShiftKey: BOOL;
begin
  ShiftKey := GetAsyncKeyState(VK_SHIFT) and $FFFFFF80 <> 0;
end;

function ControlKey: BOOL;
begin
  ControlKey := GetAsyncKeyState(VK_CONTROL) and $FFFFFF80 <> 0;
end;

function AltKey: BOOL;
begin
  AltKey := GetAsyncKeyState(VK_MENU) and $FFFFFF80 <> 0;
end;

procedure InitKeyboard;
begin
  KeyMap := nil;
  ClearUserKey;
  PreviousKey := 0;
  VKBackslash := LO(VkKeyScan(WORD('\')));
end;

procedure EndKeyboard;
begin
  if KeyMap <> nil then
    Dispose(KeyMap);
end;

begin
  DebugFlag := FALSE;
  KeyMap := nil;
end.
