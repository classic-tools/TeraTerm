unit Types;

interface
{$i teraterm.inc}

uses
  WinTypes;

{$ifdef TERATERM32}
const
  MAXPATHLEN = 256;
{$else}
const
  MAXPATHLEN = 144;
{$endif}

{$ifdef TERATERM32}
type
  UINT = integer;
{$else}
type
  UINT = word;
  DWORD = longint;
{$endif}

{$ifndef TERATERM32}
  { The 'Win31' unit of TPW 1.5 defines
    the GetTextExtentPoint function incorrectly.}
  type
    PSize = ^TSize;
    TSize = record
      cX: Integer;
      cY: Integer;
    end;

  function GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer;
    var Size: TSize): Bool;

  function GetTabbedTextExtent(DC: HDC; Str: PChar; Count: Integer;
    TabPostions: Integer; TabStopPostions: PInteger): LongInt;
{$endif}

const
  HINSTANCE_ERROR = 32;

implementation

{$ifndef TERATERM32}
function GetTextExtentPoint;            external 'GDI'  index 471;
function GetTabbedTextExtent;           external 'USER' index 197;
{$endif}

end.
