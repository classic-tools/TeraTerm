{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTCMN.DLL, character code conversion}
unit Language;

interface

uses WinTypes, TTTypes;

function SJIS2JIS(KCode: word): word; export;
function SJIS2EUC(KCode: word): word; export;
function JIS2SJIS(KCode: word): word; export;
function RussConv(cin, cout: integer; b: byte): byte; export;
procedure RussConvStr
  (cin, cout: integer; Str: PChar; count: integer); export;

implementation

function SJIS2JIS(KCode: word): word;
var
  x0,x1,x2,y0: word;
begin
  case Lo(KCode) of
    $40..$7f:
      begin
        x0 := $8140;
        y0 := $2121;
      end;
    $80..$9e:
      begin
        x0 := $8180;
        y0 := $2160;
      end;
    else
      begin
        x0 := $819f;
        y0 := $2221;
      end;
  end;
  if Hi(KCode) >= $e0 then
  begin
    x0 := x0 + $5f00;
    y0 := y0 + $3e00;
  end;
  x1 := (KCode-x0) div $100;
  x2 := (KCode-x0) mod $100;
  SJIS2JIS := y0 + x1*$200 + x2;
end;

function SJIS2EUC(KCode: word): word;
begin
  SJIS2EUC := SJIS2JIS(KCode) or $8080;
end;

function JIS2SJIS(KCode: word): word;
var
  n1,n2, SJIS: word;
begin
  n1 := (KCode-$2121) div $200;
  n2 := (KCode-$2121) mod $200;

  case n1 of
    0..$1e: SJIS := $8100 + n1*256;
    else    SJIS := $C100 + n1*256;
  end;
  case n2 of
    0..$3e:    JIS2SJIS := SJIS + n2 + $40;
    $3f..$5d: JIS2SJIS := SJIS + n2 + $41;
    else       JIS2SJIS := SJIS + n2 - $61;
  end;
end;

{ Russian charset conversion table by Andrey Nikiforov 19971114 }
const
  cpconv: array[0..3,0..3,0..127] of byte =
(
  (
    (
{ 1251 -> 1251 = dummy }
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{192-207}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{208-223}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    ),
{ 1251 -> KOI8-R }
    (
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,164,165,166,167,168,179,169,170,171,172,173,174,175,
{176-191}  176,177,178,180,181,182,183,184,163,185,186,187,188,189,190,191,
{192-207}  225,226,247,231,228,229,246,250,233,234,235,236,237,238,239,240,
{208-223}  242,243,244,245,230,232,227,254,251,253,255,249,248,252,224,241,
{224-239}  193,194,215,199,196,197,214,218,201,202,203,204,205,206,207,208,
{240-255}  210,211,212,213,198,200,195,222,219,221,223,217,216,220,192,209
    ),
{ 1251 -> 866 }
    (
{128-143}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{144-159}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{160-175}  208,246,247,209,253,210,211,212,240,213,242,214,215,216,217,244,
{176-191}  248,218,219,220,221,222,223,249,241,252,243,250,251,254,255,245,
{192-207}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{208-223}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{224-239}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{240-255}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
    ),
{ 1251 -> ISO }
    (
{128-143}  162,163,128,243,129,130,131,132,133,134,169,135,170,172,171,175,
{144-159}  242,136,137,138,139,140,141,142,143,144,249,145,250,252,251,255,
{160-175}  146,174,254,168,147,148,149,150,161,151,164,152,153,154,155,167,
{176-191}  156,157,166,246,158,159,160,173,241,240,244,253,248,165,245,247,
{192-207}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{208-223}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{224-239}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{240-255}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
    )
  ),
  (
{ koi8-r -> 1251 }
    (
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,184,163,164,165,166,167,169,170,171,172,173,174,175,
{176-191}  176,177,178,168,179,180,181,182,183,185,186,187,188,189,190,191,
{192-207}  254,224,225,246,228,229,244,227,245,232,233,234,235,236,237,238,
{208-223}  239,255,240,241,242,243,230,226,252,251,231,248,253,249,247,250,
{224-239}  222,192,193,214,196,197,212,195,213,200,201,202,203,204,205,206,
{240-255}  207,223,208,209,210,211,198,194,220,219,199,216,221,217,215,218
    ),
{ koi8-r -> koi8-r = dummy }
    (  
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{192-207}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{208-223}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    ),
{ koi8-r -> 866 }
    (
{128-143}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{144-159}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{160-175}  208,209,210,241,211,212,213,214,215,216,217,218,219,220,221,222,
{176-191}  223,242,243,240,244,245,246,247,248,249,250,251,252,253,254,255,
{192-207}  238,160,161,230,164,165,228,163,229,168,169,170,171,172,173,174,
{208-223}  175,239,224,225,226,227,166,162,236,235,167,232,237,233,231,234,
{224-239}  158,128,129,150,132,133,148,131,149,136,137,138,139,140,141,142,
{240-255}  143,159,144,145,146,147,134,130,156,155,135,152,157,153,151,154
    ),
{ koi8-r -> ISO }
    (
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,162,163,241,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  240,242,243,161,244,245,246,247,248,249,250,251,252,253,254,255,
{192-207}  238,208,209,230,212,213,228,211,229,216,217,218,219,220,221,222,
{208-223}  223,239,224,225,226,227,214,210,236,235,215,232,237,233,231,234,
{224-239}  206,176,177,198,180,181,196,179,197,184,185,186,187,188,189,190,
{240-255}  191,207,192,193,194,195,182,178,204,203,183,200,205,201,199,202
    )
  ),
  (
{ 866 -> 1251 }
    (
{128-143}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{144-159}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{160-175}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{176-191}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{192-207}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{208-223}  160,163,165,166,167,169,171,172,173,174,177,178,179,180,181,182,
{224-239}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,
{240-255}  168,184,170,186,175,191,161,162,176,183,187,188,185,164,189,190
    ),
{ 866 -> koi8-r }
    (
{128-143}  225,226,247,231,228,229,246,250,233,234,235,236,237,238,239,240,
{144-159}  242,243,244,245,230,232,227,254,251,253,255,249,248,252,224,241,
{160-175}  193,194,215,199,196,197,214,218,201,202,203,204,205,206,207,208,
{176-191}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{192-207}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{208-223}  160,161,162,164,165,166,167,168,169,170,171,172,173,174,175,176,
{224-239}  210,211,212,213,198,200,195,222,219,221,223,217,216,220,192,209,
{240-255}  179,163,177,178,180,181,182,183,184,185,186,187,188,189,190,191
    ),
{ 866 -> 866 = dummy }
    (        
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{192-207}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{208-223}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    ),
{ 866 -> ISO }
    (
{128-143}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{144-159}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{160-175}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{176-191}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{192-207}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{208-223}  160,162,163,165,166,168,169,170,171,172,173,175,240,242,243,245,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  161,241,164,244,167,247,174,254,246,248,249,250,251,252,253,255
    )
  ),
  (
{ ISO -> 1251 }
    (
{128-143}  130,132,133,134,135,136,137,139,145,146,147,148,149,150,151,152,
{144-159}  153,155,160,164,165,166,167,169,171,172,173,174,176,177,180,181,
{160-175}  182,168,128,129,170,189,178,175,163,138,140,142,141,183,161,143,
{176-191}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{192-207}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{208-223}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{224-239}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,
{240-255}  185,184,144,131,186,190,179,191,188,154,156,158,157,187,162,159
    ),
{ ISO -> koi8-r }
    (
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,179,161,162,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  225,226,247,231,228,229,246,250,233,234,235,236,237,238,239,240,
{192-207}  242,243,244,245,230,232,227,254,251,253,255,249,248,252,224,241,
{208-223}  193,194,215,199,196,197,214,218,201,202,203,204,205,206,207,208,
{224-239}  210,211,212,213,198,200,195,222,219,221,223,217,216,220,192,209,
{240-255}  176,163,177,178,180,181,182,183,184,185,186,187,188,189,190,191
    ),
{ ISO -> 866 }
    (
{128-143}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{144-159}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{160-175}  208,240,209,210,242,211,212,244,213,214,215,216,217,218,246,219,
{176-191}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{192-207}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{208-223}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  220,241,221,222,243,223,248,245,249,250,251,252,253,254,247,255
    ),
{ iso -> iso = dummy }
    (
{128-143}  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
{144-159}  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
{160-175}  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
{176-191}  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
{192-207}  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
{208-223}  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
{224-239}  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
{240-255}  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    )
  ) 
);

{Russian character set conversion}
function RussConv(cin, cout: integer; b: byte): byte;
{ cin: input character set (IdWindows/IdKOI8/Id866/IdISO)
  cin: output character set (IdWindows/IdKOI8/Id866/IdISO) }
begin
  RussConv := b;
  if b<128 then exit;
  RussConv := cpconv[cin-1, cout-1, b-128];
end;

{ Russian character set conversion for a character string }
procedure RussConvStr
  (cin, cout: integer; Str: PChar; count: integer);
{ cin: input character set (IdWindows/IdKOI8/Id866/IdISO)
  cin: output character set (IdWindows/IdKOI8/Id866/IdISO) }
var
  i: integer;
begin
  if count<=0 then exit;

  for i := 0 to count-1 do
   if byte(Str[i]) >= 128 then
      Str[i] := char(cpconv[cin-1, cout-1, byte(Str[i])-128]);
end;

end.
