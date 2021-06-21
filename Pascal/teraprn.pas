{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, Printing routines}
unit TeraPrn;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, ODialogs, Strings, CommDlg,
  TTTypes, Types, TTWinMan, CommLib, PrnAbort, TTLib, TTCommon;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings, CommDlg, Win31,
  TTTypes, Types, TTWinMan, CommLib, PrnAbort, TTLib, TTCommon;
{$ENDIF}

const
  IdPrnNormal = 100;

  function PrnBox(HWin: HWnd; Sel: PBOOL): HDC;
  function PrnStart(DocumentName: PChar): BOOL;
  procedure PrnStop;

const
  IdPrnCancel = 0;
  IdPrnScreen = 1;
  IdPrnSelectedText = 2;
  IdPrnScrollRegion = 4;
  IdPrnFile = 8;

  function VTPrintInit(PrnFlag: integer): integer;
  procedure PrnSetAttr(Attr, Attr2: byte);
  procedure PrnOutText(Buff: PChar; Count: integer);
  procedure PrnNewLine;
  procedure VTPrintEnd;

  procedure PrnFileDirectProc;
  procedure PrnFileStart;
  procedure OpenPrnFile;
  procedure ClosePrnFile;
  procedure WriteToPrnFile(b: byte; Write: bool);

implementation

var
  PrnDlg: TPrintDlg;
  PrintDC: HDC;
  Prnlf: TLogFont;
  PrnFont: array[0..AttrFontMask] of HFont;
  PrnFW, PrnFH: integer;
  Margin: TRect;
  White, Black: TColorRef;
  PrnX, PrnY: integer;
  PrnDx: array[0..255] of integer;
  PrnAttr, PrnAttr2: byte;

  Printing: bool;
  PrintAbortFlag: bool;

  {pass-thru printing}
  PrnFName: array[0..MAXPATHLEN-1] of char;
  HPrnFile: integer;
  PrnBuff: array[0..299] of char;
  PrnBuffCount: integer;

  PrnAbortDlg: PPrnAbortDlg;
  HPrnAbortDlg: HWnd;
{$ifndef TERATERM32}
  PPrnAbort: TFarProc;
{$endif}

{Print Abortion Call Back Function}
function PrnAbortProc(PDC: HDC; Code: integer): bool; export;
var
  Msg: TMsg;
begin
  while (not PrintAbortFlag) and PeekMessage(Msg, 0,0,0, PM_REMOVE) do
  if (HPrnAbortDlg=0) or (not IsDialogMessage(HPrnAbortDlg, Msg)) then
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

  if PrintAbortFlag then
  begin
    HPrnAbortDlg := 0;
    PrnAbortDlg := nil;
{$ifndef TERATERM32}
    FreeProcInstance(PPrnAbort);
{$endif}
    PrnAbortProc := FALSE;
  end
  else
    PrnAbortProc := TRUE;
end;

function PrnBox(HWin: HWnd; Sel: PBOOL): HDC;
begin
  PrnBox := 0;
  {initialize PrnDlg record}
  FillChar(PrnDlg, SizeOf(TPrintDlg), #0);
  with PrnDlg do
  begin
    lStructSize := SizeOf(TPrintDlg);
    hWndOwner := HWin;
    Flags := PD_RETURNDC or PD_NOPAGENUMS or PD_SHOWHELP;
    if not Sel^ then
      Flags := Flags or PD_NOSELECTION;
    nCopies := 1;
  end;

  {'Print' dialog box}
  if not PrintDlg(PrnDlg) then exit; {if 'Cancel' button, exit}
  if PrnDlg.hDC = 0 then exit;
  PrintDC := PrnDlg.hDC;
  Sel^ := (PrnDlg.Flags and PD_SELECTION) <> 0;

  PrnBox := PrintDC;
end;

function PrnStart(DocumentName: PChar): BOOL;
var
  Doc: TDocInfo;
  DocName: array[0..49] of char;
  AParent: PWindowsObject;
begin
  PrnStart := FALSE;
  Printing := FALSE;
  PrintAbortFlag := FALSE;

  if ActiveWin=IdVT then
    AParent := PWindowsObject(pVTWin)
  else
    AParent := PWindowsObject(pTEKWin);
  PrnAbortDlg := PPrnAbortDlg(Application^.MakeWindow(New(PPrnAbortDlg,
                      Init(AParent, @PrintAbortFlag))));
  if PrnAbortDlg = nil then exit;
  HPrnAbortDlg := PrnAbortDlg^.HWindow;

{$ifdef TERATERM32}
  SetAbortProc(PrintDC,PrnAbortProc);
{$else}
  PPrnAbort := MakeProcInstance(@PrnAbortProc, HInstance);
  SetAbortProc(PrintDC,TAbortProc(PPrnAbort));
{$endif}

  Doc.cbSize := SizeOf(TDocInfo);
  StrLCopy(DocName,DocumentName,sizeof(DocName)-1);
  Doc.lpszDocName := DocName;
  Doc.lpszOutput := nil;
{$ifdef TERATERM32}
  Doc.lpszDatatype := nil;
  Doc.fwType := 0;
{$endif}
  if StartDoc(PrintDC, Doc) > 0 then
    Printing := TRUE
  else
    if PrnAbortDlg <> nil then
    begin
      PrnAbortDlg^.CloseWindow;
      PrnAbortDlg := nil;
      HPrnAbortDlg := 0;
    end;

  PrnStart := Printing;
end;

procedure PrnStop;
begin
  if Printing then
  begin
    EndDoc(PrintDC);
    DeleteDC(PrintDC);
    Printing := FALSE;
  end;
  if PrnAbortDlg <> nil then
  begin
    PrnAbortDlg^.CloseWindow;
    PrnAbortDlg := nil;
    HPrnAbortDlg := 0;
  end;
end;

function VTPrintInit(PrnFlag: integer): integer;
{ Initialize printing of VT window
   PrnFlag: specifies object to be printed
	= IdPrnScreen		Current screen
	= IdPrnSelectedText	Selected text
	= IdPrnScrollRegion	Scroll region
	= IdPrnFile		Spooled file (printer sequence)
   Return: print object ID specified by user
	= IdPrnCancel		(user clicks "Cancel" button)
	= IdPrnScreen		(user don't select "print selection" option)
	= IdPrnSelectedText	(user selects "print selection")
	= IdPrnScrollRegion	(always when PrnFlag=IdPrnScrollRegion)
	= IdPrnFile		(always when PrnFlag=IdPrnFile) }
var	
  Sel: BOOL;
  Metrics: TTEXTMETRIC;
  PPI, PPI2: TPoint;
  DC: HDC;
  i: integer;
begin
  VTPrintInit := IdPrnCancel;

  Sel := (PrnFlag and IdPrnSelectedText)<>0;
  if PrnBox(HVTWin,@Sel)=0 then exit;
  if PrintDC=0 then exit;

  {start printing}
  if not PrnStart(ts.Title) then exit;

  {initialization}
  StartPage(PrintDC);

  {pixels per inch}
  if (ts.VTPPI.x>0) and (ts.VTPPI.y>0) then
    PPI := ts.VTPPI
  else begin
    PPI.x := GetDeviceCaps(PrintDC,LOGPIXELSX);
    PPI.y := GetDeviceCaps(PrintDC,LOGPIXELSY);
  end;

  Margin.left := {left margin}
    round(ts.PrnMargin[0] / 100 * PPI.x);
  Margin.right := {right margin}
    GetDeviceCaps(PrintDC,HORZRES) -
      round(ts.PrnMargin[1] / 100 * PPI.x);
  Margin.top := {top margin}
    round(ts.PrnMargin[2] / 100 * PPI.y);
  Margin.bottom := {bottom margin}
    GetDeviceCaps(PrintDC,VERTRES) -
      round(ts.PrnMargin[3] / 100 * PPI.y);

  {create test font}
  FillChar(Prnlf, SizeOf(TLogFont), #0);

  if ts.PrnFont[0]=#0 then
  begin
    Prnlf.lfHeight := ts.VTFontSize.y;
    Prnlf.lfWidth := ts.VTFontSize.x;
    Prnlf.lfCharSet := ts.VTFontCharSet;
    strcopy(Prnlf.lfFaceName, ts.VTFont);
  end
  else begin
    Prnlf.lfHeight := ts.PrnFontSize.y;
    Prnlf.lfWidth := ts.PrnFontSize.x;
    Prnlf.lfCharSet := ts.PrnFontCharSet;
    strcopy(Prnlf.lfFaceName, ts.PrnFont);
  end;
  Prnlf.lfWeight := FW_NORMAL;
  Prnlf.lfItalic := 0;
  Prnlf.lfUnderline := 0;
  Prnlf.lfStrikeOut := 0;
  Prnlf.lfOutPrecision  := OUT_CHARACTER_PRECIS;
  Prnlf.lfClipPrecision := CLIP_CHARACTER_PRECIS;
  Prnlf.lfQuality       := DEFAULT_QUALITY;
  Prnlf.lfPitchAndFamily := FIXED_PITCH or FF_DONTCARE;

  PrnFont[0] := CreateFontIndirect(Prnlf);

  DC := GetDC(HVTWin);
  SelectObject(DC, PrnFont[0]);
  GetTextMetrics(DC, Metrics);
  PPI2.x := GetDeviceCaps(DC,LOGPIXELSX);
  PPI2.y := GetDeviceCaps(DC,LOGPIXELSY);
  ReleaseDC(HVTWin,DC);
  DeleteObject(PrnFont[0]); {Delete test font}

  {Adjust font size}
  Prnlf.lfHeight :=
    round(Metrics.tmHeight * PPI.y / PPI2.y);
  Prnlf.lfWidth :=
    round(Metrics.tmAveCharWidth * PPI.x / PPI2.x);

  {Create New Fonts}

  {Normal Font}
  Prnlf.lfWeight := FW_NORMAL;
  Prnlf.lfUnderline := 0;
  PrnFont[0] := CreateFontIndirect(Prnlf);
  SelectObject(PrintDC,PrnFont[0]);
  GetTextMetrics(PrintDC, Metrics);
  PrnFW := Metrics.tmAveCharWidth;
  PrnFH := Metrics.tmHeight;
  {Under line}
  Prnlf.lfUnderline := 1;
  PrnFont[AttrUnder] := CreateFontIndirect(Prnlf);

  if ts.EnableBold > 0 then
  begin
    {Bold}
    Prnlf.lfUnderline := 0;
    Prnlf.lfWeight := FW_BOLD;
    PrnFont[AttrBold] := CreateFontIndirect(Prnlf);
    {Bold + Underline}
    Prnlf.lfUnderline := 1;
    PrnFont[AttrBold or AttrUnder] := CreateFontIndirect(Prnlf);
  end
  else begin
    PrnFont[AttrBold] := PrnFont[AttrDefault];
    PrnFont[AttrBold or AttrUnder] := PrnFont[AttrUnder];
  end;
  {Special font}
  Prnlf.lfWeight := FW_NORMAL;
  Prnlf.lfUnderline := 0;
  Prnlf.lfWidth := PrnFW; {adjust width}
  Prnlf.lfHeight := PrnFH;
  Prnlf.lfCharSet := SYMBOL_CHARSET;

  strcopy(Prnlf.lfFaceName,'Tera Special');
  PrnFont[AttrSpecial] := CreateFontIndirect(Prnlf);
  PrnFont[AttrSpecial or AttrBold] := PrnFont[AttrSpecial];
  PrnFont[AttrSpecial or AttrUnder] := PrnFont[AttrSpecial];
  PrnFont[AttrSpecial or AttrBold or AttrUnder] := PrnFont[AttrSpecial];

  Black := RGB(0,0,0);
  White := RGB(255,255,255);
  for i := 0 to 255 do
    PrnDx[i] := PrnFW;
  PrnSetAttr(AttrDefault,AttrDefault2);

  PrnY := Margin.top;
  PrnX := Margin.left;

  if PrnFlag = IdPrnScrollRegion then
    VTPrintInit := IdPrnScrollRegion
  else if PrnFlag = IdPrnFile then
    VTPrintInit := IdPrnFile
  else if Sel then
    VTPrintInit := IdPrnSelectedText
  else
    VTPrintInit := IdPrnScreen;
end;

procedure PrnSetAttr(Attr, Attr2: byte);
{Set text attribute of printing}
begin
  PrnAttr := Attr;
  PrnAttr2 := Attr2;
  SelectObject(PrintDC, PrnFont[Attr and AttrFontMask]);

  if (Attr and AttrReverse) <> 0 then
  begin
    SetTextColor(PrintDC,White);
    SetBkColor(  PrintDC,Black);
  end
  else begin
    SetTextColor(PrintDC,Black);
    SetBkColor(  PrintDC,White);
  end;
end;

procedure PrnOutText(Buff: PChar; Count: integer);
{  Print out text
    Buff: points text buffer
    Count: number of characters to be printed }
var
  i: integer;
  RText: TRECT;
  Ptr, Ptr1, Ptr2: PChar;
  Buff2: array[0..255] of char;
begin
  if Count<=0 then exit;
  if Count>(sizeof(Buff2)-1) then Count := sizeof(Buff2)-1;
  Move(Buff[0],Buff2[0],Count);
  Buff2[Count] := #0;
  Ptr := Buff2;

  if ts.Language=IdRussian then
  begin
    if ts.PrnFont[0]=#0 then
      RussConvStr(ts.RussClient,ts.RussFont,Buff2,Count)
    else
      RussConvStr(ts.RussClient,ts.RussPrint,Buff2,Count)
  end;

  repeat
    if PrnX+PrnFW > Margin.right then
    begin
      {new line}
      PrnX := Margin.left;
      PrnY := PrnY + PrnFH;
    end;
    if PrnY+PrnFH > Margin.bottom then
    begin
      {next page}
      EndPage(PrintDC);
      StartPage(PrintDC);
      PrnSetAttr(PrnAttr,PrnAttr2);
      PrnY := Margin.top;
    end;

    i := (Margin.right-PrnX) div PrnFW;
    if i=0 then i:=1;
    if i>Count then i:=Count;

    if i<Count then
    begin
      Ptr2 := Ptr;
      repeat
        Ptr1 := Ptr2;
{$ifdef TERATERM32}
	Ptr2 := CharNext(Ptr1);
{$else}
        Ptr2 := ANSINext(Ptr1);
{$endif}
      until (Ptr2=nil) or ((Ptr2-Ptr)>i);
      i := Ptr1-Ptr;
      if i<=0 then i:=1;
    end;

    RText.left := PrnX;
    RText.right := PrnX + i*PrnFW;
    RText.top := PrnY;
    RText.bottom := PrnY+PrnFH;
    ExtTextOut(PrintDC,PrnX,PrnY,6,@RText,Ptr,
      i,@PrnDx[0]);
    PrnX := RText.right;
    Count := Count-i;
    Ptr := Ptr + i;
  until Count<=0;
end;

procedure PrnNewLine;
{Moves to the next line in printing}
begin
  PrnX := Margin.left;
  PrnY := PrnY + PrnFH;
end;

procedure VTPrintEnd;
var
  i, j: integer;
begin
  EndPage(PrintDC);

  for i := 0 to AttrFontMask do
  begin
    for j := i+1 to AttrFontMask do
      if PrnFont[j]=PrnFont[i] then
        PrnFont[j] := 0;
    if PrnFont[i] <> 0 then DeleteObject(PrnFont[i]);
  end;

  PrnStop;
end;

{printer emulation routines}
procedure OpenPrnFile;
{$ifdef TERATERM32}
var
  Temp: array[0..MAXPATHLEN-1] of char;
{$endif}
begin
  KillTimer(HVTWin,IdPrnStartTimer);
  if HPrnFile > 0 then exit;
  if PrnFName[0]=#0 then
  begin
{$ifdef TERATERM32}
    GetTempPath(sizeof(Temp),Temp);
    if GetTempFileName(Temp,'tmp',0,PrnFName)=0 then exit;
{$else}
    if GetTempFileName(#0,'tmp',0,PrnFName)=0 then exit;
{$endif}
    HPrnFile := _lcreat(PrnFName,0);
  end
  else begin
    HPrnFile := _lopen(PrnFName,OF_WRITE);
    if HPrnFile<=0 then
      HPrnFIle := _lcreat(PrnFName,0);
  end;
  if HPrnFile > 0 then
    _llseek(HPrnFile,0,2);
end;

procedure PrintFile;
var
  Buff: array[0..255] of char;
  CRFlag: BOOL;
  c, i: integer;
  b: byte;
begin
  CRFlag := FALSE;

  if VTPrintInit(IdPrnFile)=IdPrnFile then
  begin
    HPrnFile := _lopen(PrnFName,OF_READ);
    if HPrnFile>0 then
    begin
      repeat
        i := 0;
	repeat
	  c := _lread(HPrnFile,@b,1);
	  if c=1 then
	  begin
	    case b of
	      HT: begin
                FillChar(Buff[i],8,$20);
		i := i + 8;
		CRFlag := FALSE;
		end;
	      LF: CRFlag := not CRFlag;
	      FF: CRFlag := TRUE;
              CR: CRFlag := TRUE;
	    else begin
	        if b >= $20 then
	        begin
	          Buff[i] := char(b);
		  inc(i);
	        end;
	        CRFlag := FALSE;
              end;
	    end;
	  end;
	  if i>=(sizeof(Buff)-7) then CRFlag := TRUE;
	until (c<=0) or CRFlag;
	if i>0 then PrnOutText(Buff, i);
	if CRFlag then
	begin
	  PrnX := Margin.left;
	  if (b=FF) and (ts.PrnConvFF=0) then {new page}
	    PrnY := Margin.bottom
	  else {new line}
	    PrnY := PrnY + PrnFH;
	end;
	CRFlag := (b=CR);
      until c<=0;
      _lclose(HPrnFile);
    end;
    HPrnFile := 0;
    VTPrintEnd;
  end;
  remove(PrnFName);
  PrnFName[0] := #0;
end;

procedure PrintFileDirect;
var
  AParent: PWindowsObject;
begin
  if ActiveWin=IdVT then
    AParent := PWindowsObject(pVTWin)
  else
    AParent := PWindowsObject(pTEKWin);
  PrnAbortDlg := PPrnAbortDlg(Application^.MakeWindow(New(PPrnAbortDlg,
                      Init(AParent, @PrintAbortFlag))));
  if PrnAbortDlg = nil then
  begin
    remove(PrnFName);
    PrnFName[0] := #0;
    exit;
  end;
  HPrnAbortDlg := PrnAbortDlg^.HWindow;

  HPrnFile := _lopen(PrnFName,OF_READ);
  PrintAbortFlag := (HPrnFile<=0) or not PrnOpen(ts.PrnDev);
  PrnBuffCount := 0;
  SetTimer(HVTWin,IdPrnProcTimer,0,nil);
end;

procedure PrnFileDirectProc;
var
  c: integer;
begin
  if HPrnFile=0 then exit;
  if PrintAbortFlag then
  begin
    HPrnAbortDlg := 0;
    PrnAbortDlg := nil;
    PrnCancel;
  end;

  if not PrintAbortFlag and (HPrnFile>0) then
  begin
    repeat
      if PrnBuffCount=0 then
      begin
        PrnBuffCount := _lread(HPrnFile,PrnBuff,1);
        if ts.Language=IdRussian then
          RussConvStr(ts.RussClient,ts.RussPrint,PrnBuff,PrnBuffCount);
      end;

      if PrnBuffCount=1 then
      begin
        c := PrnWrite(PrnBuff,1);
        if c=0 then
        begin
          SetTimer(HVTWin,IdPrnProcTimer,10,nil);
          exit;
        end;
        PrnBuffCount := 0;
      end
      else
        c := 0;
    until c<=0;
  end;
  if HPrnFile>0 then
    _lclose(HPrnFile);
  HPrnFile := 0;
  PrnClose;
  remove(PrnFName);
  PrnFName[0] := #0;
  if PrnAbortDlg <> nil then
  begin
    PrnAbortDlg^.CloseWindow;
    PrnAbortDlg := nil;
    HPrnAbortDlg := 0;
  end;
end;

procedure PrnFileStart;
begin
  if HPrnFile>0 then exit;
  if PrnFName[0]=#0 then exit;
  if ts.PrnDev[0]<>#0 then
    PrintFileDirect {send file directly to printer port}
  else {print file by using Windows API}
    PrintFile;
end;

procedure ClosePrnFile;
begin
  PrnBuffCount := 0;
  if HPrnFile > 0 then
    _lclose(HPrnFile);
  HPrnFile := 0;
  SetTimer(HVTWin,IdPrnStartTimer,ts.PassThruDelay*1000,nil);
end;

procedure WriteToPrnFile(b: byte; Write: bool);
{  (b,Write) =
    (0,FALSE): clear buffer
    (0,TRUE):  write buffer to file
    (b,FALSE): put b in buff
    (b,TRUE):  put b in buff and
               write buffer to file}
begin
  if (b>0) and (PrnBuffCount<sizeof(PrnBuff)) then
  begin
    PrnBuff[PrnBuffCount] := char(b);
    inc(PrnBuffCount);
  end;
  if Write then
  begin
    _lwrite(HPrnFile,PrnBuff,PrnBuffCount);
    PrnBuffCount := 0;
  end;
  if (b=0) and (not Write) then PrnBuffCount := 0;
end;

begin
  Printing := FALSE;
  PrintAbortFlag := FALSE;
  HPrnFile := 0;
  PrnBuffCount := 0;
end.
