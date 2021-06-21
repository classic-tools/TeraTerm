{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTDLG.DLL, dialog boxes}
library TTDlg;
{$R TTDlg.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, WinDos, Strings,
     TTTypes, TTCommon, DlgLib, CommDlg, TTLib;
{$ELSE}
uses WinTypes, WinProcs, WinDos, Win31, Strings,
     TTTypes, Types, TTCommon, DlgLib, CommDlg, TTLib;
{$ENDIF}

const
  IDD_TERMDLGJ        = 100;
  IDI_TTERM           = 100;
  IDC_TERMWIDTH       = 101;
  IDC_TERMHEIGHT      = 102;
  IDC_TERMISWIN       = 103;
  IDC_TERMRESIZE      = 104;
  IDC_TERMCRRCV       = 105;
  IDC_TERMCRSEND      = 106;
  IDC_TERMID          = 107;
  IDC_TERMLOCALECHO   = 108;
  IDC_TERMANSBACKTEXT = 109;
  IDC_TERMANSBACK     = 110;
  IDC_TERMAUTOSWITCH  = 111;
  IDC_TERMKANJI       = 112;
  IDC_TERMKANA        = 113;
  IDC_TERMKANJISEND   = 114;
  IDC_TERMKANASEND    = 115;
  IDC_TERMKINTEXT     = 116;
  IDC_TERMKIN         = 117;
  IDC_TERMKOUTTEXT    = 118;
  IDC_TERMKOUT        = 119;
  IDC_TERMRUSSHOST    = 120;
  IDC_TERMRUSSCLIENT  = 121;
  IDC_TERMHELP        = 199;
  IDD_WINDLG          = 200;
  IDC_WINTITLE        = 201;
  IDC_WINBLOCK        = 202;
  IDC_WINVERT         = 203;
  IDC_WINHORZ         = 204;
  IDC_WINHIDEMENU     = 205;
  IDC_WINHIDETITLE    = 206;
  IDC_WINCOLOREMU     = 207;
  IDC_WINSCROLL1      = 208;
  IDC_WINSCROLL2      = 209;
  IDC_WINSCROLL3      = 210;
  IDC_WINTEXT         = 211;
  IDC_WINBACK         = 212;
  IDC_WINREV          = 213;
  IDC_WINRED          = 214;
  IDC_WINGREEN        = 215;
  IDC_WINBLUE         = 216;
  IDC_WINREDBAR       = 217;
  IDC_WINGREENBAR     = 218;
  IDC_WINBLUEBAR      = 219;
  IDC_WINATTRTEXT     = 220;
  IDC_WINATTR         = 221;
  IDC_WINHELP         = 299;
  IDD_KEYBDLG         = 300;
  IDC_KEYBBS          = 301;
  IDC_KEYBDEL         = 302;
  IDC_KEYBMETA        = 303;
  IDC_KEYBKEYBTEXT    = 304;
  IDC_KEYBKEYB        = 305;
  IDC_KEYBHELP        = 399;
  IDD_SERIALDLG       = 400;
  IDC_SERIALPORT      = 401;
  IDC_SERIALBAUD      = 402;
  IDC_SERIALDATA      = 403;
  IDC_SERIALPARITY    = 404;
  IDC_SERIALSTOP      = 405;
  IDC_SERIALFLOW      = 406;
  IDC_SERIALDELAYCHAR = 407;
  IDC_SERIALDELAYLINE = 408;
  IDC_SERIALHELP      = 499;
  IDD_TCPIPDLG        = 500;
  IDC_TCPIPHOST       = 501;
  IDC_TCPIPADD        = 502;
  IDC_TCPIPLIST       = 503;
  IDC_TCPIPUP         = 504;
  IDC_TCPIPREMOVE     = 505;
  IDC_TCPIPDOWN       = 506;
  IDC_TCPIPHISTORY    = 507;
  IDC_TCPIPAUTOCLOSE  = 508;
  IDC_TCPIPPORT       = 509;
  IDC_TCPIPTELNET     = 510;
  IDC_TCPIPTERMTYPELABEL = 511;
  IDC_TCPIPTERMTYPE   = 512;
  IDC_TCPIPHELP       = 599;
  IDD_HOSTDLG         = 600;
  IDC_HOSTTCPIP       = 601;
  IDC_HOSTSERIAL      = 602;
  IDC_HOSTNAMELABEL   = 603;
  IDC_HOSTNAME        = 604;
  IDC_HOSTTELNET      = 605;
  IDC_HOSTTCPPORTLABEL = 606;
  IDC_HOSTTCPPORT     = 607;
  IDC_HOSTCOMLABEL    = 608;
  IDC_HOSTCOM         = 609;
  IDC_HOSTHELP        = 699;
  IDD_DIRDLG          = 700;
  IDC_DIRCURRENT      = 701;
  IDC_DIRNEW          = 702;
  IDC_DIRHELP         = 799;
  IDD_ABOUTDLG        = 800;
  IDD_FONTDLG         = 900;
  IDC_FONTBOLD        = 901;
  IDC_FONTCHARSET1    = 902;
  IDC_FONTCHARSET2    = 903;
  IDD_GENDLG          = 1000;
  IDC_GENPORT         = 1001;
  IDC_GENLANGLABEL    = 1002;
  IDC_GENLANG         = 1003;
  IDC_GENHELP         = 1099;
  IDD_TERMDLG         = 1100;
  IDD_WINLISTDLG      = 1200;
  IDC_WINLISTLIST     = 1201;
  IDC_WINLISTCLOSE    = 1202;
  IDC_WINLISTHELP     = 1299;
  IDD_TERMDLGR        = 1300;

const
  NLList: array[0..2] of PChar = (
    'CR','CR+LF',nil);
  TermList: array[0..6] of PChar = (
    'VT100','VT101','VT102','VT282','VT320','VT382',nil);
  TermJ_Term: array[0..8] of word = (1,1,2,3,3,4,4,5,6);
  Term_TermJ: array[0..5] of word = (1,3,4,7,8,9);
  TermListJ: array[0..9] of PChar = (
    'VT100','VT100J','VT101','VT102','VT102J','VT220J',
    'VT282','VT320','VT382',nil);
  KanjiList: array[0..3] of PChar = ('SJIS','EUC','JIS',nil);
  KanjiInList: array[0..2] of PChar = ('^[$@','^[$B',nil);
  KanjiOutList: array[0..2] of PChar = ('^[(B','^[(J',nil);
  KanjiOutList2: array[0..3] of PChar = ('^[(B','^[(J','^[(H',nil);
  RussList: array[0..4] of PChar = ('Windows','KOI8-R','CP 866','ISO 8859-5',nil);
  RussList2: array[0..2] of PChar = ('Windows','KOI8-R',nil);

function TermDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  w: word;
  Temp: array[0..80] of char;
begin
  TermDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        ts := PTTSet(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        SetDlgItemInt(Dialog,IDC_TERMWIDTH,ts^.TerminalWidth,FALSE);
        SendDlgItemMessage(Dialog, IDC_TERMWIDTH, EM_LIMITTEXT, 3, 0);

        SetDlgItemInt(Dialog,IDC_TERMHEIGHT,ts^.TerminalHeight,FALSE);
        SendDlgItemMessage(Dialog, IDC_TERMHEIGHT, EM_LIMITTEXT,3, 0);

        SetRB(Dialog,ts^.TermIsWin,IDC_TERMISWIN,IDC_TERMISWIN);
        SetRB(Dialog,ts^.AutoWinResize,IDC_TERMRESIZE,IDC_TERMRESIZE);
        if ts^.TermIsWin>0 then
          DisableDlgItem(Dialog,IDC_TERMRESIZE,IDC_TERMRESIZE);

        SetDropDownList(Dialog, IDC_TERMCRRCV, @NLList,  ts^.CRReceive);
        SetDropDownList(Dialog, IDC_TERMCRSEND, @NLList, ts^.CRSend);

        if ts^.Language<>IdJapanese then {non Japanese mode}
        begin
          if (ts^.TerminalID>=1) and
             (ts^.TerminalID<=9) then
            w := TermJ_Term[ts^.TerminalID-1]
          else
            w := 1;
          SetDropDownList(Dialog, IDC_TERMID, @TermList, w);
        end
        else
          SetDropDownList(Dialog, IDC_TERMID, @TermListJ, ts^.TerminalID);

        SetRB(Dialog,ts^.LocalEcho,IDC_TERMLOCALECHO,IDC_TERMLOCALECHO);

        if ts^.FTFlag and FT_BPAUTO <>0 then
          DisableDlgItem(Dialog,IDC_TERMANSBACKTEXT,IDC_TERMANSBACK)
        else begin
          Str2Hex(ts^.Answerback,Temp,ts^.AnswerbackLen,
                  SizeOf(Temp)-1,FALSE);
          SetDlgItemText(Dialog, IDC_TERMANSBACK, Temp);
          SendDlgItemMessage(Dialog, IDC_TERMANSBACK, EM_LIMITTEXT,
                           SizeOf(Temp) - 1, 0);
        end;

        SetRB(Dialog,ts^.AutoWinSwitch,IDC_TERMAUTOSWITCH,IDC_TERMAUTOSWITCH);

        if ts^.Language=IdJapanese then
        begin
	  SetDropDownList(Dialog, IDC_TERMKANJI, @KanjiList, ts^.KanjiCode);
	  if ts^.KanjiCode<>IdJIS then
	    DisableDlgItem(Dialog,IDC_TERMKANA,IDC_TERMKANA);
	  SetRB(Dialog,ts^.JIS7Katakana,IDC_TERMKANA,IDC_TERMKANA);
	  SetDropDownList(Dialog, IDC_TERMKANJISEND, @KanjiList, ts^.KanjiCodeSend);
	  if ts^.KanjiCodeSend<>IdJIS then
	    DisableDlgItem(Dialog,IDC_TERMKANASEND,IDC_TERMKOUT);
	  SetRB(Dialog,ts^.JIS7KatakanaSend,IDC_TERMKANASEND,IDC_TERMKANASEND);
	  SetDropDownList(Dialog,IDC_TERMKIN,@KanjiInList,ts^.KanjiIn);
	  if ts^.TermFlag and TF_ALLOWWRONGSEQUENCE <> 0 then
	    SetDropDownList(Dialog,IDC_TERMKOUT,@KanjiOutList2,ts^.KanjiOut)
	  else
	    SetDropDownList(Dialog,IDC_TERMKOUT,@KanjiOutList,ts^.KanjiOut);
	end
	else if ts^.Language=IdRussian then
	begin
	  SetDropDownList(Dialog,IDC_TERMRUSSHOST,@RussList,ts^.RussHost);
	  SetDropDownList(Dialog,IDC_TERMRUSSCLIENT,@RussList,ts^.RussClient);
	end;

        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
          if ts<>nil then
          begin
            ts^.TerminalWidth := GetDlgItemInt(Dialog,IDC_TERMWIDTH,nil,FALSE);
            if ts^.TerminalWidth<1 then ts^.TerminalWidth := 1;
            if ts^.TerminalWidth>500 then ts^.TerminalWidth := 500;

            ts^.TerminalHeight := GetDlgItemInt(Dialog,IDC_TERMHEIGHT,nil,FALSE);
            if ts^.TerminalHeight<1 then ts^.TerminalHeight := 1;
            if ts^.TerminalHeight>500 then ts^.TerminalHeight := 500;

            GetRB(Dialog,ts^.TermIsWin,IDC_TERMISWIN,IDC_TERMISWIN);
            GetRB(Dialog,ts^.AutoWinResize,IDC_TERMRESIZE,IDC_TERMRESIZE);

            ts^.CRReceive := word(GetCurSel(Dialog, IDC_TERMCRRCV));
            ts^.CRSend := word(GetCurSel(Dialog, IDC_TERMCRSEND));

	    w := word(GetCurSel(Dialog, IDC_TERMID));
	    if ts^.Language<>IdJapanese then {non-Japanese mode}
            begin
	      if (w=0) or (w>6) then w := 1;
	      w := Term_TermJ[w-1];
	    end;
	    ts^.TerminalID := w;

            GetRB(Dialog,ts^.LocalEcho,IDC_TERMLOCALECHO,IDC_TERMLOCALECHO);

            if ts^.FTFlag and FT_BPAUTO = 0 then
            begin
              GetDlgItemText(Dialog, IDC_TERMANSBACK,Temp,SizeOf(Temp));
              ts^.AnswerbackLen :=
                Hex2Str(Temp,ts^.Answerback,SizeOf(ts^.Answerback));
            end;

            GetRB(Dialog,ts^.AutoWinSwitch,IDC_TERMAUTOSWITCH,IDC_TERMAUTOSWITCH);

	    if ts^.Language=IdJapanese then
	    begin
	      ts^.KanjiCode := word(GetCurSel(Dialog, IDC_TERMKANJI));
	      GetRB(Dialog,ts^.JIS7Katakana,IDC_TERMKANA,IDC_TERMKANA);
	      ts^.KanjiCodeSend := word(GetCurSel(Dialog, IDC_TERMKANJISEND));
	      GetRB(Dialog,ts^.JIS7KatakanaSend,IDC_TERMKANASEND,IDC_TERMKANASEND);
	      ts^.KanjiIn := word(GetCurSel(Dialog, IDC_TERMKIN));
	      ts^.KanjiOut := word(GetCurSel(Dialog, IDC_TERMKOUT));
	    end
	    else if ts^.Language=IdRussian then
	    begin
	      ts^.RussHost := word(GetCurSel(Dialog, IDC_TERMRUSSHOST));
	      ts^.RussClient := word(GetCurSel(Dialog, IDC_TERMRUSSCLIENT));
	    end;
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_TERMISWIN: begin
          GetRB(Dialog,w,IDC_TERMISWIN,IDC_TERMISWIN);
          if w=0 then
            EnableDlgItem(Dialog,IDC_TERMRESIZE,IDC_TERMRESIZE)
          else
            DisableDlgItem(Dialog,IDC_TERMRESIZE,IDC_TERMRESIZE);
        end;
        IDC_TERMKANJI: begin
	  w := word(GetCurSel(Dialog, IDC_TERMKANJI));
	  if w=IdJIS then
	    EnableDlgItem(Dialog,IDC_TERMKANA,IDC_TERMKANA)
	  else
	    DisableDlgItem(Dialog,IDC_TERMKANA,IDC_TERMKANA);
        end;
        IDC_TERMKANJISEND: begin
	  w := word(GetCurSel(Dialog, IDC_TERMKANJISEND));
	  if w=IdJIS then
	    EnableDlgItem(Dialog,IDC_TERMKANASEND,IDC_TERMKOUT)
	  else
	    DisableDlgItem(Dialog,IDC_TERMKANASEND,IDC_TERMKOUT);
        end;
        IDC_TERMHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  TermDlg := FALSE;
end;

function WinDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  Wnd, HRed, HGreen, HBlue: HWnd;
  IAttr, IOffset: integer;
  i, pos, ScrollCode, NewPos: word;
  FN: array[0..160] of char;
  DC: HDC;

  procedure DispSample;
  var
    i,x,y: integer;
    Text, Back: TColorRef;
    DX: array[0..2] of integer;
    Metrics: TTextMetric;
    Rect, TestRect: TRect;
    FW,FH: integer;
  begin
    DC := GetDC(Dialog);
    Text := RGB(ts^.TmpColor[IAttr,0],
                ts^.TmpColor[IAttr,1],
                ts^.TmpColor[IAttr,2]);
    Text := GetNearestColor(DC, Text);
    Back := RGB(ts^.TmpColor[IAttr,3],
                ts^.TmpColor[IAttr,4],
                ts^.TmpColor[IAttr,5]);
    Back := GetNearestColor(DC, Back);
    SetTextColor(DC, Text);
    SetBkColor(DC, Back);
    SelectObject(DC,ts^.SampleFont);
    GetTextMetrics(DC, Metrics);
    FW := Metrics.tmAveCharWidth;
    FH := Metrics.tmHeight;
    for i := 0 to 2 do DX[i] := FW;
    GetClientRect(Dialog,Rect);
    TestRect.left := Rect.left + round((Rect.right-Rect.left)*0.65);
    TestRect.right := Rect.left + round((Rect.right-Rect.left)*0.93);
    TestRect.top := Rect.top + round((Rect.bottom-Rect.top)*0.54);
    TestRect.bottom := Rect.top + round((Rect.bottom-Rect.top)*0.94);
    x := round((TestRect.left+TestRect.right) / 2 - FW * 1.5);
    y := (TestRect.top+TestRect.bottom-FH) div 2;
    ExtTextOut(DC, x,y, 6, @TestRect, 'ABC', 3, @DX);
    ReleaseDC(Dialog,DC);
  end;

  procedure ChangeColor;
  begin
    SetDlgItemInt(Dialog,IDC_WINRED,ts^.TmpColor[IAttr,IOffset],FALSE);
    SetDlgItemInt(Dialog,IDC_WINGREEN,ts^.TmpColor[IAttr,IOffset+1],FALSE);
    SetDlgItemInt(Dialog,IDC_WINBLUE,ts^.TmpColor[IAttr,IOffset+2],FALSE);

    DispSample;
  end;

  procedure ChangeSB;
  begin
    HRed := GetDlgItem(Dialog, IDC_WINREDBAR);
    HGreen := GetDlgItem(Dialog, IDC_WINGREENBAR);
    HBlue := GetDlgItem(Dialog, IDC_WINBLUEBAR);

    SetScrollPos(HRed,SB_CTL,ts^.TmpColor[IAttr,IOffset+0],TRUE);
    SetScrollPos(HGreen,SB_CTL,ts^.TmpColor[IAttr,IOffset+1],TRUE);
    SetScrollPos(HBlue,SB_CTL,ts^.TmpColor[IAttr,IOffset+2],TRUE);
    ChangeColor;
  end;

  procedure RestoreVar;
  var
    w: word;
  begin
    GetRB(Dialog,word(i),IDC_WINText,IDC_WINBACK);
    if i=2 then IOffset := 3
           else IOffset := 0;
    if (ts<>nil) and (ts^.VTFlag>0) then
    begin
      IAttr := GetCurSel(Dialog,IDC_WINATTR);
      if IAttr>0 then dec(IAttr);
    end
    else
      IAttr := 0;
  end;

begin
  WinDlg := TRUE;
  case Message of
    WM_INITDIALOG: begin
      ts := PTTSet(lParam);
      SetWindowLong(Dialog, DWL_USER, lParam);
      with ts^ do begin
        SetDlgItemText(Dialog, IDC_WINTITLE, Title);
        SendDlgItemMessage(Dialog, IDC_WINTITLE, EM_LIMITTEXT,
                           SizeOf(Title)-1, 0);

        SetRB(Dialog,HideTitle,IDC_WINHIDETITLE,IDC_WINHIDETITLE);
        SetRB(Dialog,PopupMenu,IDC_WINHIDEMENU,IDC_WINHIDEMENU);
        if HideTitle>0 then
          DisableDlgItem(Dialog,IDC_WINHIDEMENU,IDC_WINHIDEMENU);

        if VTFlag>0 then
        begin
          SetDlgItemText(Dialog, IDC_WINCOLOREMU,'Full &color');
          if (ColorFlag and CF_FULLCOLOR)<>0 then
            i := 1
          else
            i := 0;
          SetRB(Dialog,i,IDC_WINCOLOREMU,IDC_WINCOLOREMU);
          ShowDlgItem(Dialog,IDC_WINSCROLL1,IDC_WINSCROLL3);
          SetRB(Dialog,EnableScrollBuff,IDC_WINSCROLL1,IDC_WINSCROLL1);
          SetDlgItemInt(Dialog,IDC_WINSCROLL2,ScrollBuffSize,FALSE);
          SendDlgItemMessage(Dialog, IDC_WINSCROLL2, EM_LIMITTEXT,5, 0);
          if EnableScrollBuff=0 then          
            DisableDlgItem(Dialog,IDC_WINSCROLL2,IDC_WINSCROLL3);
          for i := 0 to 1 do
          begin
            TmpColor[0,i*3]   := GetRValue(VTColor[i]);
            TmpColor[0,i*3+1] := GetGValue(VTColor[i]);
            TmpColor[0,i*3+2] := GetBValue(VTColor[i]);
            TmpColor[1,i*3]   := GetRValue(VTBoldColor[i]);
            TmpColor[1,i*3+1] := GetGValue(VTBoldColor[i]);
            TmpColor[1,i*3+2] := GetBValue(VTBoldColor[i]);
            TmpColor[2,i*3]   := GetRValue(VTBlinkColor[i]);
            TmpColor[2,i*3+1] := GetGValue(VTBlinkColor[i]);
            TmpColor[2,i*3+2] := GetBValue(VTBlinkColor[i]);
          end;
          ShowDlgItem(Dialog,IDC_WINATTRTEXT,IDC_WINATTR);
          SendDlgItemMessage(Dialog, IDC_WINATTR, CB_ADDSTRING,
                             0, longint(PChar('Normal')));
          SendDlgItemMessage(Dialog, IDC_WINAttr, CB_ADDSTRING,
                             0, longint(PChar('Bold')));
          SendDlgItemMessage(Dialog, IDC_WINAttr, CB_ADDSTRING,
                             0, longint(PChar('Blink')));
          SendDlgItemMessage(Dialog, IDC_WINAttr, CB_SETCURSEL,
                             0,0);
        end
        else begin
          for i := 0 to 1 do
          begin
            TmpColor[0,i*3]   := GetRValue(TEKColor[i]);
            TmpColor[0,i*3+1] := GetGValue(TEKColor[i]);
            TmpColor[0,i*3+2] := GetBValue(TEKColor[i]);
          end;
          SetRB(Dialog,TEKColorEmu,IDC_WINCOLOREMU,IDC_WINCOLOREMU);
        end;
        SetRB(Dialog,1,IDC_WINTEXT,IDC_WINBACK);

        SetRB(Dialog,CursorShape,IDC_WINBLOCK,IDC_WINHORZ);

        IAttr := 0;
        IOffset := 0;

        HRed := GetDlgItem(Dialog, IDC_WINREDBAR);
        SetScrollRange(HRed,SB_CTL,0,255,TRUE);

        HGreen := GetDlgItem(Dialog, IDC_WINGREENBAR);
        SetScrollRange(HGreen,SB_CTL,0,255,TRUE);

        HBlue := GetDlgItem(Dialog, IDC_WINBLUEBAR);
        SetScrollRange(HBlue,SB_CTL,0,255,TRUE);

        ChangeSB;

        end;
        exit;
      end;
    WM_COMMAND:
      begin
        ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
        RestoreVar;
        case LOWORD(wParam) of
          IDOK: begin
            if ts<>nil then
            begin
            with ts^ do begin
              GetDlgItemText(Dialog,IDC_WINTITLE,Title,SizeOf(Title));
              GetRB(Dialog,HideTitle,IDC_WINHIDETITLE,IDC_WINHIDETITLE);
              GetRB(Dialog,PopupMenu,IDC_WINHIDEMENU,IDC_WINHIDEMENU);
              DC := GetDC(Dialog);
              if VTFlag>0 then
              begin
                GetRB(Dialog,i,IDC_WINCOLOREMU,IDC_WINCOLOREMU);
                if i<>0 then
                  ColorFlag := ColorFlag or CF_FULLCOLOR
                else
                  ColorFlag := ColorFlag and word(not CF_FULLCOLOR);
                GetRB(Dialog,EnableScrollBuff,IDC_WINSCROLL1,IDC_WINSCROLL1);
                if EnableScrollBuff>0 then
                begin
                  ScrollBuffSize :=
                    GetDlgItemInt(Dialog,IDC_WINSCROLL2,nil,FALSE);
                end;
                for i := 0 to 1 do
                begin
                  VTColor[i] :=
                    RGB(TmpColor[0,i*3],
                        TmpColor[0,i*3+1],
                        TmpColor[0,i*3+2]);
                  VTBoldColor[i] :=
                    RGB(TmpColor[1,i*3],
                        TmpColor[1,i*3+1],
                        TmpColor[1,i*3+2]);
                  VTBlinkColor[i] :=
                    RGB(TmpColor[2,i*3],
                        TmpColor[2,i*3+1],
                        TmpColor[2,i*3+2]);
                  VTColor[i] := GetNearestColor(DC,VTColor[i]);
                  VTBoldColor[i] := GetNearestColor(DC,VTBoldColor[i]);
                  VTBlinkColor[i] := GetNearestColor(DC,VTBlinkColor[i]);
                end;
              end
              else begin
                for i := 0 to 1 do
                begin
                  TEKColor[i] :=
                    RGB(TmpColor[0,i*3],
                        TmpColor[0,i*3+1],
                        TmpColor[0,i*3+2]);
                  TEKColor[i] := GetNearestColor(DC,TEKColor[i]);
                end;
                GetRB(Dialog,TEKColorEmu,IDC_WINCOLOREMU,IDC_WINCOLOREMU);
              end;
              ReleaseDC(Dialog,DC);

              GetRB(Dialog,ts^.CursorShape,IDC_WINBLOCK,IDC_WINHORZ);

            end;
            end;
            EndDialog(Dialog, 1);
            exit;
          end;
          IDCANCEL: begin
            EndDialog(Dialog, 0);
            exit;
          end;
          IDC_WINHIDETITLE: begin
            GetRB(Dialog,i,IDC_WINHIDETITLE,IDC_WINHIDETITLE);
	    if i>0 then
	      DisableDlgItem(Dialog,IDC_WINHIDEMENU,IDC_WINHIDEMENU)
	    else
	      EnableDlgItem(Dialog,IDC_WINHIDEMENU,IDC_WINHIDEMENU);
          end;
          IDC_WINSCROLL1: begin
            if ts=nil then exit;
            GetRB(Dialog,i,IDC_WINSCROLL1,IDC_WINSCROLL1);
            if i>0 then
              EnableDlgItem(Dialog,IDC_WINSCROLL2,IDC_WINSCROLL3)
            else
              DisableDlgItem(Dialog,IDC_WINSCROLL2,IDC_WINSCROLL3);
          end;
          IDC_WINTEXT: begin
            if ts=nil then exit;
            IOffset := 0;
            ChangeSB;
          end;
          IDC_WINBACK: begin
            if ts=nil then exit;
            IOffset := 3;
            ChangeSB;
          end;
          IDC_WINREV: begin
            if ts=nil then exit;
            with ts^ do begin
              i := TmpColor[IAttr,0];
              TmpColor[IAttr,0] := TmpColor[IAttr,3];
              TmpColor[IAttr,3] := i;
              i := TmpColor[IAttr,1];
              TmpColor[IAttr,1] := TmpColor[IAttr,4];
              TmpColor[IAttr,4] := i;
              i := TmpColor[IAttr,2];
              TmpColor[IAttr,2] := TmpColor[IAttr,5];
              TmpColor[IAttr,5] := i;
            end;
            ChangeSB;
          end;
          IDC_WINATTR: if ts<>nil then ChangeSB;
          IDC_WINHELP: PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
        end;
      end;

    WM_PAINT: begin
      ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
      if ts=nil then exit;
      RestoreVar;
      DispSample;
    end;

    WM_HSCROLL: begin
      ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
      if ts=nil then exit;
      RestoreVar;
      HRed := GetDlgItem(Dialog, IDC_WINREDBAR);
      HGreen := GetDlgItem(Dialog, IDC_WINGREENBAR);
      HBlue := GetDlgItem(Dialog, IDC_WINBLUEBAR);
      with ts^ do begin
{$ifdef TERATERM32}
      Wnd := HWnd(lParam);
      ScrollCode := LOWORD(wParam);
      NewPos := HIWORD(wParam);
{$else}
      Wnd := HWnd(HIWORD(lParam));
      ScrollCode := wParam;
      NewPos := LOWORD(lParam);
{$endif}
      if Wnd = HRed then i := IOffset
      else if Wnd = HGreen then i := IOffset + 1
      else if Wnd = HBlue then i := IOffset + 2
      else exit;

      pos := TmpColor[IAttr,i];
      case ScrollCode of
        SB_BOTTOM:        pos := 255;
        SB_LINEDOWN:      if pos<255 then inc(pos);
        SB_LINEUP:        if pos>0 then dec(pos);
        SB_PAGEDOWN:      pos := pos + 16;
        SB_PAGEUP:        pos := pos - 16;
        SB_THUMBPOSITION: pos := NewPos;
        SB_THUMBTRACK:    pos := NewPos;
        SB_TOP:           pos := 0;
      end;
      if pos>255 then pos := 255;
      TmpColor[IAttr,i] := pos;
      SetScrollPos(Wnd,SB_CTL,TmpColor[IAttr,i],TRUE);

      end;

      ChangeColor;
      exit;
    end;

  end;
  WinDlg := FALSE;
end;

function KeybDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  w: word;
begin
  KeybDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        ts := PTTSet(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        SetRB(Dialog,ts^.BSKey-1,IDC_KEYBBS,IDC_KEYBBS);
        SetRB(Dialog,ts^.DelKey,IDC_KEYBDEL,IDC_KEYBDEL);
        SetRB(Dialog,ts^.MetaKey,IDC_KEYBMETA,IDC_KEYBMETA);
        if ts^.Language=IdRussian then
        begin
	  ShowDlgItem(Dialog,IDC_KEYBKEYBTEXT,IDC_KEYBKEYB);
          SetDropDownList(Dialog, IDC_KEYBKEYB, @RussList2, ts^.RussKeyb);
	end;
        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
          if ts<>nil then
          begin
            GetRB(Dialog,ts^.BSKey,IDC_KEYBBS,IDC_KEYBBS);
            inc(ts^.BSKey);
            GetRB(Dialog,ts^.DelKey,IDC_KEYBDEL,IDC_KEYBDEL);
            GetRB(Dialog,ts^.MetaKey,IDC_KEYBMETA,IDC_KEYBMETA);
            if ts^.Language=IdRussian then
              ts^.RussKeyb := word(GetCurSel(Dialog, IDC_KEYBKEYB));
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_KEYBHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  KeybDlg := FALSE;
end;

const
  BaudList: array[0..12] of PChar = (
    '110','300','600','1200','2400','4800','9600',
    '14400','19200','38400','57600','115200',nil);
  DataList: array[0..2] of PChar = (
    '7 bit','8 bit',nil);
  ParityList: array[0..3] of PChar = (
    'even','odd','none',nil);
  StopList: array[0..2] of PChar = (
    '1 bit','2 bit',nil);
  FlowList: array[0..3] of PChar = (
    'Xon/Xoff','hardware','none',nil);

function SerialDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  i: integer;
  Temp: array[0..5] of char;
begin
  SerialDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        ts := PTTSet(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        strcopy(Temp,'COM');
        for i := 1 to ts^.MaxComPort do
        begin
          uint2str(i,@Temp[3],2);
          SendDlgItemMessage(Dialog, IDC_SERIALPORT, CB_ADDSTRING,
                             0, longint(@Temp[0]));
        end;
        if ts^.ComPort <= ts^.MaxComPort then
          i := ts^.ComPort-1
        else
          i := 0;
        SendDlgItemMessage(Dialog, IDC_SERIALPORT, CB_SETCURSEL,i,0);

        SetDropDownList(Dialog, IDC_SERIALBAUD, @BaudList, ts^.Baud);
        SetDropDownList(Dialog, IDC_SERIALDATA, @DataList, ts^.DataBit);
        SetDropDownList(Dialog, IDC_SERIALPARITY, @ParityList, ts^.Parity);
        SetDropDownList(Dialog, IDC_SERIALSTOP, @StopList, ts^.StopBit);
        SetDropDownList(Dialog, IDC_SERIALFLOW, @FlowList, ts^.Flow);

        SetDlgItemInt(Dialog,IDC_SERIALDELAYCHAR,ts^.DelayPerChar,FALSE);
        SendDlgItemMessage(Dialog, IDC_SERIALDELAYCHAR, EM_LIMITTEXT,4, 0);

        SetDlgItemInt(Dialog,IDC_SERIALDELAYLINE,ts^.DelayPerLine,FALSE);
        SendDlgItemMessage(Dialog, IDC_SERIALDELAYLINE, EM_LIMITTEXT,4, 0);

        Exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
          if ts<>nil then
          begin
	    ts^.ComPort := word(GetCurSel(Dialog, IDC_SERIALPORT));
	    ts^.Baud := word(GetCurSel(Dialog, IDC_SERIALBAUD));
	    ts^.DataBit := word(GetCurSel(Dialog, IDC_SERIALDATA));
	    ts^.Parity := word(GetCurSel(Dialog, IDC_SERIALPARITY));
	    ts^.StopBit := word(GetCurSel(Dialog, IDC_SERIALSTOP));
	    ts^.Flow := word(GetCurSel(Dialog, IDC_SERIALFLOW));

            ts^.DelayPerChar := GetDlgItemInt(Dialog,IDC_SERIALDELAYCHAR,nil,FALSE);

            ts^.DelayPerLine := GetDlgItemInt(Dialog,IDC_SERIALDELAYLINE,nil,FALSE);

            ts^.PortType := IdSerial;
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_SERIALHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  SerialDlg := FALSE;
end;

function TCPIPDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  EntName: array[0..6] of char;
  TempHost: array[0..HostNameMaxLength] of char;
  i, Index: integer;
  w: word;
  Ok: bool;
begin
  TCPIPDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        ts := PTTSet(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        SendDlgItemMessage(Dialog, IDC_TCPIPHOST, EM_LIMITTEXT,
                           HostNameMaxLength-1, 0);

        StrCopy(EntName,'Host');

        i := 1;
        repeat
          uint2str(i,@EntName[4],2);
          GetPrivateProfileString('Hosts',EntName,'',
                                  TempHost,SizeOf(TempHost),ts^.SetupFName);
          if StrLen(TempHost) > 0 then
            SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_ADDSTRING,
                               0, longint(@TempHost[0]));
          inc(i)
        until (i > 99) or (StrLen(TempHost)=0);

        {append a blank item to the bottom}
        TempHost[0] := #0;
        SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_ADDSTRING,
                           0, longint(@TempHost[0]));

        SetRB(Dialog,ts^.HistoryList,IDC_TCPIPHISTORY,IDC_TCPIPHISTORY);

        SetRB(Dialog,ts^.AutoWinClose,IDC_TCPIPAUTOCLOSE,IDC_TCPIPAUTOCLOSE);

        SetDlgItemInt(Dialog,IDC_TCPIPPORT,ts^.TCPPort,FALSE);

        SetRB(Dialog,ts^.Telnet,IDC_TCPIPTELNET,IDC_TCPIPTELNET);

        SetDlgItemText(Dialog, IDC_TCPIPTERMTYPE, ts^.TermType);

        SendDlgItemMessage(Dialog, IDC_TCPIPTERMTYPE, EM_LIMITTEXT,
                           SizeOf(ts^.TermType)-1, 0);

        if ts^.Telnet=0 then
          DisableDlgItem(Dialog,IDC_TCPIPTERMTYPELABEL,IDC_TCPIPTERMTYPE);

        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
          if ts<>nil then
          begin
            WritePrivateProfileString('Hosts',nil,nil,ts^.SetupFName);

            Index := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCOUNT,0,0);
            if Index=integer(LB_ERR) then
              Index := 0
            else
              dec(Index);
            if Index>99 then Index := 99;

            StrCopy(EntName,'Host');
            for i := 1 to Index do
            begin
              SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_GETTEXT,
                                 i-1, longint(@TempHost[0]));
              uint2str(i,@EntName[4],2);
              WritePrivateProfileString('Hosts',EntName,TempHost,ts^.SetupFName);
            end;

            GetRB(Dialog,ts^.HistoryList,IDC_TCPIPHISTORY,IDC_TCPIPHISTORY);

            GetRB(Dialog,ts^.AutoWinClose,IDC_TCPIPAUTOCLOSE,IDC_TCPIPAUTOCLOSE);

            ts^.TCPPort := GetDlgItemInt(Dialog,IDC_TCPIPPORT,@Ok,FALSE);
            if not Ok then ts^.TCPPort := ts^.TelPort;

            GetRB(Dialog,ts^.Telnet,IDC_TCPIPTELNET,IDC_TCPIPTELNET);

            GetDlgItemText(Dialog, IDC_TCPIPTERMTYPE, ts^.TermType,
                         SizeOf(ts^.TermType));
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_TCPIPHOST:
{$ifdef TERATERM32}
          if HIWORD(wParam)=EN_CHANGE then
          begin
{$else}
          if HIWORD(lParam)=EN_CHANGE then
          begin
{$endif}
            GetDlgItemText(Dialog, IDC_TCPIPHOST, TempHost, SizeOf(TempHost));
            if StrLen(TempHost)=0 then
              DisableDlgItem(Dialog,IDC_TCPIPADD,IDC_TCPIPADD)
            else
              EnableDlgItem(Dialog,IDC_TCPIPADD,IDC_TCPIPADD);
          end;
        IDC_TCPIPADD: begin
          GetDlgItemText(Dialog, IDC_TCPIPHOST, TempHost, SizeOf(TempHost));
          if StrLen(TempHost)>0 then
          begin
            Index := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCURSEL,0,0);
            if Index=integer(LB_ERR) then Index:=0;

            SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_INSERTSTRING,
                               Index, longint(@TempHost[0]));
            
            SetDlgItemText(Dialog, IDC_TCPIPHOST, #0);
            SetFocus(GetDlgItem(Dialog, IDC_TCPIPHOST));
          end;
        end;
        IDC_TCPIPLIST:
{$ifdef TERATERM32}
          if HIWORD(wParam)=LBN_SELCHANGE then
{$else}
          if HIWORD(lParam)=LBN_SELCHANGE then
{$endif}
          begin
	    i := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCOUNT,0,0);
	    Index := SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_GETCURSEL, 0, 0);
	    if (i<=1) or (Index=integer(LB_ERR)) or
	       (Index=i-1) then
	      DisableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPDOWN)
	    else begin
	      EnableDlgItem(Dialog,IDC_TCPIPREMOVE,IDC_TCPIPREMOVE);
	      if Index=0 then
		DisableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPUP)
	      else
		EnableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPUP);
	      if Index>=i-2 then
		DisableDlgItem(Dialog,IDC_TCPIPDOWN,IDC_TCPIPDOWN)
	      else
		EnableDlgItem(Dialog,IDC_TCPIPDOWN,IDC_TCPIPDOWN);
	    end;
	  end;
	IDC_TCPIPUP,
	IDC_TCPIPDOWN: begin
	  i := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCOUNT,0,0);
	  Index := SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_GETCURSEL, 0, 0);
	  if Index=integer(LB_ERR) then exit;
	  if LOWORD(wParam)=IDC_TCPIPDOWN then inc(Index);
	  if (Index=0) or (Index>=i-1) then exit;
	  SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_GETTEXT,
			     Index, longint(@TempHost[0]));
	  SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_DELETESTRING,
			     Index, 0);
	  SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_INSERTSTRING,
			     Index-1, longint(@TempHost[0]));
	  if LOWORD(wParam)=IDC_TCPIPUP then dec(Index);
	  SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_SETCURSEL,Index,0);
	  if Index=0 then
	    DisableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPUP)
	  else
	    EnableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPUP);
	  if Index>=i-2 then
	    DisableDlgItem(Dialog,IDC_TCPIPDOWN,IDC_TCPIPDOWN)
	  else
	    EnableDlgItem(Dialog,IDC_TCPIPDOWN,IDC_TCPIPDOWN);
          SetFocus(GetDlgItem(Dialog, IDC_TCPIPLIST));
        end;
        IDC_TCPIPREMOVE: begin
	  i := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCOUNT,0,0);
	  Index := SendDlgItemMessage(Dialog,IDC_TCPIPLIST,LB_GETCURSEL, 0, 0);
	  if (Index=integer(LB_ERR)) or
	     (Index=i-1) then exit;
          SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_GETTEXT,
                             Index, longint(@TempHost[0]));
          SendDlgItemMessage(Dialog, IDC_TCPIPLIST, LB_DELETESTRING,
                             Index, 0);
          SetDlgItemText(Dialog, IDC_TCPIPHOST, TempHost);
          DisableDlgItem(Dialog,IDC_TCPIPUP,IDC_TCPIPDOWN);
	  SetFocus(GetDlgItem(Dialog, IDC_TCPIPHOST));
        end;
        IDC_TCPIPTELNET: begin
          GetRB(Dialog,w,IDC_TCPIPTELNET,IDC_TCPIPTELNET);
          if w=1 then
          begin
            EnableDlgItem(Dialog,IDC_TCPIPTERMTYPELABEL,IDC_TCPIPTERMTYPE);
            ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
            if ts<>nil then
              SetDlgItemInt(Dialog,IDC_TCPIPPORT,ts^.TelPort,FALSE);
          end
          else
            DisableDlgItem(Dialog,IDC_TCPIPTERMTYPELABEL,IDC_TCPIPTERMTYPE);
        end;

        IDC_TCPIPHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  TCPIPDlg := FALSE;
end;

function HostDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  GetHNRec: PGetHNRec;
  EntName: array[0..6] of char;
  TempHost: array[0..HostNameMaxLength] of char;
  i, j, w: word;
  Ok: bool;
begin
  HostDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        GetHNRec := PGetHNRec(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        if GetHNRec^.PortType=IdFile then
          GetHNRec^.PortType := IdTCPIP;
        SetRB(Dialog,GetHNRec^.PortType,IDC_HOSTTCPIP,IDC_HOSTSERIAL);

        StrCopy(EntName,'Host');

        i := 1;
        repeat
          uint2str(i,@EntName[4],2);
          GetPrivateProfileString('Hosts',EntName,'',
                                  TempHost,SizeOf(TempHost),GetHNRec^.SetupFN);
          if StrLen(TempHost) > 0 then
            SendDlgItemMessage(Dialog, IDC_HOSTNAME, CB_ADDSTRING,
                               0, longint(@TempHost[0]));
          inc(i)
        until (i > 99) or (StrLen(TempHost)=0);

        SendDlgItemMessage(Dialog, IDC_HOSTNAME, EM_LIMITTEXT,
                           HostNameMaxLength-1, 0);

        SendDlgItemMessage(Dialog, IDC_HOSTNAME, CB_SETCURSEL,0,0);

        SetRB(Dialog,GetHNRec^.Telnet,IDC_HOSTTELNET,IDC_HOSTTELNET);
        SendDlgItemMessage(Dialog, IDC_HOSTTCPPORT, EM_LIMITTEXT,5,0);
        SetDlgItemInt(Dialog,IDC_HOSTTCPPORT,GetHNRec^.TCPPort,FALSE);

        j := 0;
        w := 1;
        strcopy(EntName,'COM');
        for i := 1 to GetHNRec^.MaxComPort do
        begin
	  if ((GetCOMFlag shr (i-1)) and 1) = 0 then
          begin
            uint2str(i,@EntName[3],2);
            SendDlgItemMessage(Dialog, IDC_HOSTCOM, CB_ADDSTRING,
                               0, longint(@EntName[0]));
	    inc(j);
	    if GetHNRec^.ComPort=i then w := j;
	  end;
        end;
        if j>0 then
          SendDlgItemMessage(Dialog, IDC_HOSTCOM, CB_SETCURSEL,w-1,0)
        else {All com ports are already used}
          GetHNRec^.PortType := IdTCPIP;

        if GetHNRec^.PortType=IdTCPIP then
          DisableDlgItem(Dialog,IDC_HOSTCOMLABEL,IDC_HOSTCOM)
        else
          DisableDlgItem(Dialog,IDC_HOSTNAMELABEL,IDC_HOSTTCPPORT);

        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          GetHNRec := PGetHNRec(GetWindowLong(Dialog,DWL_USER));
          if GetHNRec<>nil then
          begin
            GetRB(Dialog,GetHNRec^.PortType,IDC_HOSTTCPIP,IDC_HOSTSERIAL);
            if GetHNRec^.PortType=IdTCPIP then
              GetDlgItemText(Dialog, IDC_HOSTNAME, GetHNRec^.HostName, HostNameMaxLength)
            else
              GetHNRec^.HostName[0] := #0;
            GetRB(Dialog,GetHNRec^.Telnet,IDC_HOSTTELNET,IDC_HOSTTELNET);
            i := GetDlgItemInt(Dialog,IDC_HOSTTCPPort,@Ok,FALSE);
            if Ok then GetHNRec^.TCPPort := i;
            FillChar(EntName,SizeOf(EntName),0);
            GetDlgItemText(Dialog, IDC_HOSTCom, EntName, SizeOf(EntName)-1);
            GetHNRec^.COMPort := byte(EntName[3])-$30;
            if strlen(EntName)>4 then
              GetHNRec^.COMPort := GetHNRec^.ComPort*10 + byte(EntName[4])-$30
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_HOSTTCPIP: begin
          EnableDlgItem(Dialog,IDC_HOSTNAMELABEL,IDC_HOSTTCPPORT);
          DisableDlgItem(Dialog,IDC_HOSTCOMLABEL,IDC_HOSTCOM);
        end;
        IDC_HOSTSERIAL: begin
          EnableDlgItem(Dialog,IDC_HOSTCOMLABEL,IDC_HOSTCOM);
          DisableDlgItem(Dialog,IDC_HOSTNAMELABEL,IDC_HOSTTCPPORT);
        end;
        IDC_HOSTTELNET: begin
          GetRB(Dialog,i,IDC_HOSTTELNET,IDC_HOSTTELNET);
          if i=1 then
          begin
            GetHNRec := PGetHNRec(GetWindowLong(Dialog,DWL_USER));
            if GetHNRec<>nil then
              SetDlgItemInt(Dialog,IDC_HOSTTCPPort,GetHNRec^.TelPort,FALSE);
          end;
        end;
        IDC_HOSTHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  HostDlg := FALSE;
end;

function DirDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  CurDir: PChar;
  HomeDir, TmpDir: array[0..MAXPATHLEN-1] of char;
  R: TRect;
  TmpDC: HDC;
  s: TSize;
  HDir, HOk, HCancel, HHelp: HWND;
  D, B: TPoint;
  WX, WY, WW, WH, CW, DW, DH, BW, BH: integer;
begin
  DirDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        CurDir := PCHAR(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        SetDlgItemText(Dialog, IDC_DIRCURRENT, CurDir);
        SendDlgItemMessage(Dialog, IDC_DIRNEW, EM_LIMITTEXT,
                           MAXPATHLEN-1, 0);

        {adjust dialog size}
	{get size of current dir text}
	HDir := GetDlgItem(Dialog, IDC_DIRCURRENT);
	GetWindowRect(HDir,R);
	D.x := R.left;
	D.y := R.top;
	ScreenToClient(Dialog,D);
	DH := R.bottom-R.top;  
	TmpDC := GetDC(Dialog);
{$ifdef TERATERM32}
        GetTextExtentPoint32(TmpDC,CurDir,strlen(CurDir),s);
{$else}
        GetTextExtentPoint(TmpDC,CurDir,strlen(CurDir),s);
{$endif}
        ReleaseDC(Dialog,TmpDC);
	DW := s.cx + s.cx div 10;

	{get button size}
	HOk := GetDlgItem(Dialog, IDOK);
	HCancel := GetDlgItem(Dialog, IDCANCEL);
	HHelp := GetDlgItem(Dialog, IDC_DIRHELP);
	GetWindowRect(HHelp,R);
	B.x := R.left;
	B.y := R.top;
	ScreenToClient(Dialog,B);
	BW := R.right-R.left;
	BH := R.bottom-R.top;

	{calc new dialog size}
	GetWindowRect(Dialog,R);
	WX := R.left;
	WY := R.top;
	WW := R.right-R.left;
	WH := R.bottom-R.top;
	GetClientRect(Dialog,R);
	CW := R.right-R.left;
	if D.x+DW < CW then DW := CW-D.x;
	WW := WW + D.x+DW - CW;

	{resize current dir text}
	MoveWindow(HDir,D.x,D.y,DW,DH,TRUE);
	{move buttons}
	MoveWindow(HOk,(D.x+DW-4*BW) div 2,B.y,BW,BH,TRUE);
	MoveWindow(HCancel,(D.x+DW-BW) div 2,B.y,BW,BH,TRUE);
	MoveWindow(HHelp,(D.x+DW+2*BW) div 2,B.y,BW,BH,TRUE);
	{resize edit box}
	HDir := GetDlgItem(Dialog, IDC_DIRNEW);
	GetWindowRect(HDir,R);
	D.x := R.left;
	D.y := R.top;
	ScreenToClient(Dialog,D);
	DW := R.right-R.left;
	if DW<s.cx then DW := s.cx;
	MoveWindow(HDir,D.x,D.y,DW,R.bottom-R.top,TRUE);
	{resize dialog}
	MoveWindow(Dialog,WX,WY,WW,WH,TRUE);

        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
	  CurDir := PCHAR(GetWindowLong(Dialog,DWL_USER));
          if CurDir<>nil then
          begin
            GetCurDir(HomeDir,0);
            SetCurDir(CurDir);
            GetDlgItemText(Dialog, IDC_DIRNEW, TmpDir,
                         SizeOf(TmpDir));
            if StrLen(TmpDir)>0 then
            begin
              SetCurDir(TmpDir);
              if DosError>0 then
              begin
                messagebox(Dialog,'Cannot find directory',
                  'Tera Term: Error',MB_ICONEXCLAMATION);
                SetCurDir(HomeDir);
                exit;
              end;
              GetCurDir(CurDir,0);
            end;
            SetCurDir(HomeDir);
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_DIRHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  DirDlg := FALSE;
end;

function AboutDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
begin
  AboutDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      exit;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
      end;
  end;
  AboutDlg := FALSE;
end;

const
  LangList: array[0..3] of PChar = (
    'English','Japanese','Russian',nil);

function GenDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  ts: PTTSet;
  w: word;
  Temp: array[0..5] of char;
begin
  GenDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        ts := PTTSet(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);

        SendDlgItemMessage(Dialog, IDC_GENPORT, CB_ADDSTRING,
                           0, longint(PChar('TCP/IP')));
        strcopy(Temp,'COM');
        for w := 1 to ts^.MaxComPort do
        begin
          uint2str(w,@Temp[3],2);
          SendDlgItemMessage(Dialog, IDC_GENPORT, CB_ADDSTRING,
                             0, longint(@Temp[0]));
        end;
        if ts^.PortType=IdSerial then
        begin
          if ts^.ComPort <= ts^.MaxComPort then
            w := ts^.ComPort
          else
            w := 1; {COM1}
        end
        else
          w := 0; {TCPIP}
        SendDlgItemMessage(Dialog, IDC_GENPORT, CB_SETCURSEL,w,0);

        if (ts^.MenuFlag and MF_NOLANGUAGE)=0 then
        begin
	  ShowDlgItem(Dialog,IDC_GENLANGLABEL,IDC_GENLANG);
	  SetDropDownList(Dialog, IDC_GENLANG, @LangList, ts^.Language);
        end;
        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
	  ts := PTTSet(GetWindowLong(Dialog,DWL_USER));
          if ts<>nil then
          begin
            w := word(GetCurSel(Dialog, IDC_GENPORT));
            if (w>1) then
            begin
              ts^.PortType := IdSerial;
              ts^.ComPort := w-1;
            end
            else
              ts^.PortType := IdTCPIP;
            if (ts^.MenuFlag and MF_NOLANGUAGE)=0 then
              ts^.Language := word(GetCurSel(Dialog, IDC_GENLANG));   
          end;
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_GENHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  GenDlg := FALSE;
end;


function WinListDlg(Dialog: HWnd; Message, WParam: Word;
  LParam: Longint): Bool; export;
var
  Close: PBOOL;
  n: integer;
  Hw: HWND;
begin
  WinListDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        Close := PBOOL(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);
        SetWinList(GetParent(Dialog),Dialog,IDC_WINLISTLIST);
        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          n := SendDlgItemMessage(Dialog,IDC_WINLISTLIST,
            LB_GETCURSEL, 0, 0);
          if n<>CB_ERR then SelectWin(n);
          EndDialog(Dialog, 1);
          exit;
        end;
        IDCANCEL: begin
          EndDialog(Dialog, 0);
          exit;
        end;
        IDC_WINLISTLIST: begin
{$ifdef TERATERM32}
          if HIWORD(wParam)=LBN_DBLCLK then
{$else}
          if HIWORD(lParam)=LBN_DBLCLK then
{$endif}
            PostMessage(Dialog,WM_COMMAND,IDOK,0);
          exit;
        end;
        IDC_WINLISTCLOSE: begin
          n := SendDlgItemMessage(Dialog,IDC_WINLISTLIST,
            LB_GETCURSEL, 0, 0);
          if n=CB_ERR then exit;
          Hw := GetNthWin(n);
          if Hw<>GetParent(Dialog) then
          begin
            if not IsWindowEnabled(Hw) then
            begin
              MessageBeep(0);
              exit;
            end;
            SendDlgItemMessage(Dialog,IDC_WINLISTLIST,
              LB_DELETESTRING,n,0);
            PostMessage(Hw,WM_SYSCOMMAND,SC_CLOSE,0);
          end
          else begin
            Close := PBOOL(GetWindowLong(Dialog,DWL_USER));
            if Close<>nil then Close^ := TRUE;
            EndDialog(Dialog,1);
            exit;
          end;
        end;              
        IDC_WINLISTHELP:
          PostMessage(GetParent(Dialog),WM_USER_DLGHELP2,0,0);
      end;
  end;
  WinListDlg := FALSE;
end;

function SetupTerminal(WndParent: HWnd; ts: PTTSet): Bool; export;
var
{$ifndef TERATERM32}
  TermProc: TFarProc;
{$endif}
  i: integer;
begin
  if ts^.Language=IdJapanese then {Japanese mode}
    i := IDD_TERMDLGJ
  else if ts^.Language=IdRussian then {Russian mode}
    i := IDD_TERMDLGR
  else
    i := IDD_TERMDLG;

{$ifdef TERATERM32}
  SetupTerminal := BOOL(DialogBoxParam(hInstance,
    PChar(i), WndParent, @TermDlg, longint(ts)));
{$else} 
  TermProc := MakeProcInstance(@TermDlg, HInstance);
  SetupTerminal := BOOL(DialogBoxParam(hInstance,
    PChar(i), WndParent, TermProc, longint(ts)));
  FreeProcInstance(TermProc);
{$endif}
end;

function SetupWin(WndParent: HWnd; ts: PTTSet): Bool; export;
{$ifndef TERATERM32}
var
  WinProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  SetupWin := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_WINDLG), WndParent, @WinDlg, longint(ts)));
{$else}
  WinProc := MakeProcInstance(@WinDlg, hInstance);
  SetupWin := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_WINDLG), WndParent, WinProc, longint(ts)));
  FreeProcInstance(WinProc);
{$endif}
end;

function SetupKeyboard(WndParent: HWnd; ts: PTTSet): Bool; export;
{$ifndef TERATERM32}
var
  KeybProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  SetupKeyboard := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_KEYBDLG), WndParent, @KeybDlg, longint(ts)));
{$else}
  KeybProc := MakeProcInstance(@KeybDlg, hInstance);
  SetupKeyboard := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_KEYBDLG), WndParent, KeybProc, longint(ts)));
  FreeProcInstance(KeybProc);
{$endif}
end;

function SetupSerialPort(WndParent: HWnd; ts: PTTSet): Bool; export;
{$ifndef TERATERM32}
var
  SerialProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  SetupSerialPort := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_SERIALDLG), WndParent, @SerialDlg, longint(ts)));
{$else}
  SerialProc := MakeProcInstance(@SerialDlg, hInstance);
  SetupSerialPort := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_SERIALDLG), WndParent, SerialProc, longint(ts)));
  FreeProcInstance(SerialProc);
{$endif}
end;

function SetupTCPIP(WndParent: HWnd; ts: PTTSet): Bool; export;
{$ifndef TERATERM32}
var
  TCPIPProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  SetupTCPIP := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_TCPIPDLG), WndParent, @TCPIPDlg, longint(ts)));
{$else}
  TCPIPProc := MakeProcInstance(@TCPIPDlg, hInstance);
  SetupTCPIP := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_TCPIPDLG), WndParent, TCPIPProc, longint(ts)));
  FreeProcInstance(TCPIPProc);
{$endif}
end;

function GetHostName(WndParent: HWnd; GetHNRec: PGetHNRec): Bool; export;
{$ifndef TERATERM32}
var
  HostProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  GetHostName := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_HOSTDLG), WndParent, @HostDlg, longint(GetHNRec)));
{$else}
  HostProc := MakeProcInstance(@HostDlg, hInstance);
  GetHostName := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_HOSTDLG), WndParent, HostProc, longint(GetHNRec)));
  FreeProcInstance(HostProc);
{$endif}
end;

function ChangeDirectory(WndParent: HWnd; CurDir: PChar): Bool; export;
{$ifndef TERATERM32}
var
  DirProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  ChangeDirectory := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_DIRDLG), WndParent, @DirDlg, longint(CurDir)));
{$else}
  DirProc := MakeProcInstance(@DirDlg, hInstance);
  ChangeDirectory := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_DIRDLG), WndParent, DirProc, longint(CurDir)));
  FreeProcInstance(DirProc);
{$endif}
end;

function AboutDialog(WndParent: HWnd): Bool; export;
{$ifndef TERATERM32}
var
  AboutProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  AboutDialog := BOOL(DialogBox(hInstance,
    PChar(IDD_ABOUTDLG), WndParent, @AboutDlg));
{$else}
  AboutProc := MakeProcInstance(@AboutDlg, hInstance);
  AboutDialog := BOOL(DialogBox(hInstance,
    PChar(IDD_ABOUTDLG), WndParent, AboutProc));
  FreeProcInstance(AboutProc);
{$endif}
end;

function TFontHook(Dialog: HWnd; Message, wParam: Word; lParam: Longint): Bool; export;
var
  cf: PChooseFont;
  ts: PTTSet;
begin
  case Message of
    WM_INITDIALOG:
      begin
        cf := PCHOOSEFONT(lParam);
        ts := PTTSet(cf^.lCustData);
        SetWindowLong(Dialog, DWL_USER, longint(ts));
        ShowDlgItem(Dialog,IDC_FONTBOLD,IDC_FONTBOLD);
        SetRB(Dialog,ts^.EnableBold,IDC_FONTBOLD,IDC_FONTBOLD);
        if ts^.Language=IdRussian then
        begin
	  ShowDlgItem(Dialog,IDC_FONTCHARSET1,IDC_FONTCHARSET2);
          SetDropDownList(Dialog,IDC_FONTCHARSET2,@RussList,ts^.RussFont);
        end;
        SetFocus(GetDlgItem(Dialog,1136));
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          ts := PTTSet(GetWindowLong(Dialog, DWL_USER));
          if ts<>nil then
          begin
            GetRB(Dialog,ts^.EnableBold,IDC_FONTBOLD,IDC_FONTBOLD);
            if ts^.Language=IdRussian then
              ts^.RussFont := word(GetCurSel(Dialog, IDC_FONTCHARSET2));
          end;
        end;
        IDCANCEL: ;
      end;
  end;
  TFontHook := FALSE;
end;

function ChooseFontDlg(WndParent: HWnd; LogFont: PLogFont; ts: PTTSet): bool; export;
var
  cf: TChooseFont;
begin
  FillChar(cf, SizeOf(cf), #0);
  with cf do
  begin
    lStructSize:= SizeOf(TChooseFont);
    hwndOwner  := WndParent;
    lpLogFont  := LogFont;
    Flags      := CF_SCREENFONTS or CF_INITTOLOGFONTSTRUCT or
                  CF_FIXEDPITCHONLY or CF_SHOWHELP or CF_ENABLETEMPLATE;
    if ts<>nil then
    begin
      Flags := Flags or CF_ENABLEHOOK;
{$ifdef TERATERM32}
      @lpfnHook := @TFontHook;
{$else}  
      @lpfnHook := MakeProcInstance(@TFontHook, hInstance);
{$endif}
      lCustData := longint(ts);
    end;
    lpTemplateName := PChar(IDD_FONTDLG);
    nFontType := REGULAR_FONTTYPE;
  end;
  cf.hInstance := hInstance;
  ChooseFontDlg := ChooseFont(cf);
{$ifndef TERATERM32}
  FreeProcInstance(@cf.lpfnHook);
{$endif}

end;

function SetupGeneral(WndParent: HWnd; ts: PTTSet): Bool; export;
{$ifndef TERATERM32}
var
  GenProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  SetupGeneral := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_GENDLG), WndParent, @GenDlg, longint(ts)));
{$else}
  GenProc := MakeProcInstance(@GenDlg, hInstance);
  SetupGeneral := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_GENDLG), WndParent, GenProc, longint(ts)));
  FreeProcInstance(GenProc);
{$endif}
end;

function WindowWindow(WndParent: HWnd; Close: PBOOL): Bool; export;
{$ifndef TERATERM32}
var
  WinListProc: TFarProc;
{$endif}
begin
  Close^ := FALSE;
{$ifdef TERATERM32}
  WindowWindow := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_WINLISTDLG), WndParent, @WinListDlg, longint(Close)));
{$else}
  WinListProc := MakeProcInstance(@WinListDlg, hInstance);
  WindowWindow := BOOL(DialogBoxParam(hInstance,
    PChar(IDD_WINLISTDLG), WndParent, WinListProc, longint(Close)));
  FreeProcInstance(WinListProc);
{$endif}
end;

exports

  SetupTerminal   index 1,
  SetupWin        index 2,
  SetupKeyboard   index 3,
  SetupSerialPort index 4,
  SetupTCPIP      index 5,
  GetHostName     index 6,
  ChangeDirectory index 7,
  AboutDialog     index 8,
  ChooseFontDlg   index 9,
  SetupGeneral    index 10,
  WindowWindow    index 11;

begin
end.