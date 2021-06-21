{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{$define TPW} {<-- Compiler you are using, TPW or Delphi}

{$define TERATERM16} {only 16-bit Windows is supported}
                     {TERATERM32 does not work}
{$ifdef TTCONST}
{$ifdef TERATERM32}
const
  MAXPATHLEN = 256;
  {version 2.3}
  TTVERSION = 23;
{$else}
const
  MAXPATHLEN = 144;
  {version 1.4}
  TTVERSION = 14;
{$endif}
{$else}
{$define TTCONST}
{$endif}