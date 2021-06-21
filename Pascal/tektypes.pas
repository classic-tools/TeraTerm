{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{Constants and types for TEK window}
unit TEKTypes;

interface

uses WinTypes;

const
  ViewSizeX = 4096;
  ViewSizeY = 3120;

  CurWidth = 2;

  IdAlphaMode = 0;
  IdVectorMode = 1;
  IdMarkerMode = 2;
  IdPlotMode = 3;
  IdUnknownMode = 4;

  ModeFirst = 0;
  ModeEscape = 1;
  ModeCS = 2;
  ModeSelectCode = 3;
  Mode2OC = 4;
  ModeGT = 5;

{"LF"}
  IdMove = $4C46;
{"LG"}
  IdDraw = $4C47;
{"LH"}
  IdDrawMarker = $4C48;
{"LT"}
  IdGraphText = $4C54;
{"LV"}
  IdSetDialogVisibility = $4C56;
{"MC"}
  IdSetGraphTextSize = $4D43;
{"MG"}
  IdSetWriteMode = $4D47;
{"ML"}
  IdSetLineIndex = $4D4C;
{"MM"}
  IdSetMarkerType = $4D4D;
{"MN"}
  IdSetCharPath = $4D4E;
{"MQ"}
  IdSetPrecision = $4D51;
{"MR"}
  IdSetRotation = $4D52;
{"MT"}
  IdSetTextIndex = $4D54;
{"MV"}
  IdSetLineStyle = $4D56;

  NParamMax = 16;
  NParam2OCMax = 16;

type

  PTEKVar = ^TTEKVar;
  TTEKVar = record
    HWin: HWnd;

    Drawing: BOOL;
    ParseMode: integer;
    SelectCodeFlag: integer;

    TEKlf: TLogFont;
    TEKFont: array[0..3] of HFont;
    OldMemFont: HFont;
    AdjustSize, ScaleFont: BOOL;
    ScreenWidth, ScreenHeight: integer;
    FontWidth, FontHeight: integer;
    FW, FH: array[0..3] of integer;
    CaretX, CaretY: integer;
    CaretOffset: integer;
    TextSize: integer;
    DispMode: integer;
    MemDC : HDC;
    HBits, OldMemBmp: HBitmap;
    Active, Minimized, MoveFlag: BOOL;
    TextColor, PenColor: TColorRef;
    MemForeColor, MemBackColor, MemTextColor, MemPenColor: TColorRef;
    BackGround, MemBackGround: HBrush;
    Pen, MemPen, OldMemPen: HPen;
    ps: integer;
    ChangeEmu: integer;
    CaretStatus: integer;


    ButtonDown, Select, RubberBand: BOOL;
    SelectStart, SelectEnd: TPoint;

    GIN, CrossHair: BOOL;
    IgnoreCount: integer;
    GINX, GINY: integer;

    {flags for Drawing}
    LoXReceive: BOOL;
    LoCount: integer;
    LoA, LoB: byte;

    {variables for 2OC mode}
    OpCount, PrmCount, PrmCountMax: integer;
    Op2OC: word;
    Prm2OC: array[0..NParam2OCMax] of word;

    {plot mode}
    JustAfterRS, PenDown: BOOL;
    PlotX, PlotY: integer;

    {variables for control sequences}
    CSCount: integer;
    CSBuff: array[0..255] of byte;
    NParam: integer;
    Param: array[0..NParamMax] of integer;

    {variables for graphtext}
    GTWidth, GTHeight, GTSpacing: integer;
    GTCount, GTLen, GTAngle: integer;
    GTBuff: array[0..79] of char;

    {variables for marker}
    MarkerType, MarkerW, MarkerH: integer;
    MarkerFont: HFont;
    MarkerFlag: BOOL;

    HiY, Extra, LoY, HiX, LoX: byte;
  end;

implementation

end.