Unit DGI;

{$A+,B-,D+,E+,F+,G+,I-,L+,N+,O-,P-,Q-,R-,S-,T-,V+,X+}
{$M 16384,0,655360}

Interface

Const
  deNoError             = 0;
  deMemory              = 1;
  deFileNotFound        = 2;
  deNotDGIFile          = 3;

(* VGA Screen modes *)
  TextMode              = 3;

  Pi  = 3.1415926535897932385;
  Deg = Pi/180;

Type
  T8x8Letter  = array[0..7] of Byte;
  T8x16Letter = array[0..15] of Byte;

  T8x8Font  = array[char] of T8x8Letter;
  T8x16Font = array[char] of T8x16Letter;
  P8x8Font    = ^T8x8Font;
  P8x16Font   = ^T8x16Font;


Var
  _SetMode	: Pointer;
  _ClearScreen	: Pointer;
  _PutPixel	: Pointer;
  _GetPixel	: Pointer;
  _Box		: Pointer;
  _PutImage	: Pointer;
  _GetImage     : Pointer;
  _PutImage2	: Pointer;
  _HLine	: Pointer;
  _VLine	: Pointer;

Procedure SetVGAMode( VGAMode: Word ); InLine( $58/$CD/$10);
Function  MemAlloc( Size: Word ): Pointer;

Procedure LoadDriver( Name: String );
Procedure UnLoadDriver;

  { This procedures are in the driver file which you load }
Procedure SetMode;                                         InLine( $FF/$1E/>_SetMode     );
Procedure ClearScreen( Color: Word );                      InLine( $FF/$1E/>_ClearScreen );
Procedure PutPixel( x,y,Color: Word );                     InLine( $FF/$1E/>_PutPixel    );
Function  GetPixel( x,y: Word ): Word;                     InLine( $FF/$1E/>_GetPixel    );
Procedure Box( x,y,dx,dy,Color: Word );                    InLine( $FF/$1E/>_Box         );
Procedure PutImage( x,y,XLen,YLen: Word; Var Image );      InLine( $FF/$1E/>_PutImage    );
Procedure GetImage( x,y,XLen,YLen: Word; Var Image );      InLine( $FF/$1E/>_GetImage    );
Procedure PutImage2( x,y,XLen,YLen: Word; Var Image );     InLine( $FF/$1E/>_PutImage2   );
Procedure HLine( x, y, XLen, Color: Word );                InLine( $FF/$1E/>_HLine);
Procedure VLine( x, y, YLen, Color: Word );                InLine( $FF/$1E/>_VLine);

Procedure Line( x1,y1,x2,y2 : Word; Color: Word );
Procedure Circle(x1, y1, rad: Integer; Col: Word  );
Procedure FillCircle(x1, y1, rad : Integer; Col: Word  );

Procedure WriteChar1( x, y: Word; AChar: Char );
Procedure WriteChar2( x, y: Word; AChar: Char );
Procedure WriteStr1( x, y: Word; s: String );
Procedure WriteStr2( x, y: Word; s: String );


  { The is the data that from the driver }
Function GetMaxX: Word;
Function GetMaxY: Word;
Function GetDGIName: String;

  { bla bla bla? }
Procedure WaitRetrace;
Procedure WaitVRetrace;

Var
  DGIError: Word;
  Font8x8 : P8x8Font;
  Font8x16: P8x16Font;

  FontColor: Word ;
  FontBack : Word ;

Const
  ControlChars: set of Char =  [ #7, #8, #9, #10, #13, #26, #27 ];

  PixelsPerLine_8x8 : Byte = 9;
  PixelsPerChar_8x8 : Byte = 9;
  PixelsPerLine_8x16: Byte = 17;
  PixelsPerChar_8x16: Byte = 9;


Implementation

Type
  TDGIRec = Record
    LocalVars   : array[0..$FF] of Byte;
    Main        : Record End;
    SetModeOfs  : Word;
    ClrScrOfs   : Word;
    PutPixelOfs : Word;
    GetPixelOfs : Word;
    BoxOfs      : Word;
    PutImgOfs	: Word;
    GetImgOfs   : Word;
    PutImg2Ofs	: Word;
    HLineOfs	: Word;
    VLineOfs    : Word;
    EndProcs    : Word;

    DGISignature: Array[0..10] of Char;
    DGIName     : Array[0..39] of Char;
{    Manufacturer: array[0..59] of Char;}
    MaxX        : Word;
    MaxY        : Word;
 End;

  Bytes = array[0..$FFFF-1] of Byte;

Const
  DGISignature = 'DGI DRIVER'#26;

Var
  DriverSize: Word;
  Link      : Pointer;


Function MemAlloc( Size: Word ): Pointer;
Var
  P: Pointer;
Begin
  If MaxAvail >= Size
    Then GetMem( P, Size )
    Else P:= nil;
  MemAlloc:= p;
End;

  (* Driver loading *)
Procedure LoadDriver( Name: String );
Var
  S      : array[0..18] of char;
  F      : File;
  Driver : ^TDGIRec;
Begin
  Assign( F, Name );
  Reset( F, 1 );

  If IOResult<>0 Then
    Begin
      DGIError:= deFileNotFound;
      Exit;
    End;

  DriverSize:= FileSize(F) + $100;
  Link:= MemAlloc ( DriverSize );

  If Link = nil Then
    Begin
      DGIError:= deMemory;
      Close( F );
      Exit;
    End;

  Driver:= Link;  { Just points to it }
  BlockRead( F, Driver^.Main, FileSize(F)  );
  Close( F );

  If Driver^.DGISignature <> DGISignature Then
    Begin
      DGIError:= deNotDGIFile;
      Close( F );
      Exit;
    End;

  With TDGIRec(Link^) do
    Begin
       { These procedures muest be in the driver }
     _SetMode	  := Ptr( Seg(Link^), SetModeOfs  );
     _ClearScreen := Ptr( Seg(Link^), ClrScrOfs	  );
     _PutPixel	  := Ptr( Seg(Link^), PutPixelOfs );
     _GetPixel	  := Ptr( Seg(Link^), GetPixelOfs );
     _Box         := Ptr( Seg(Link^), BoxOfs      );
     _PutImage    := Ptr( Seg(Link^), PutImgOfs   );
     _GetImage    := Ptr( Seg(Link^), GetImgOfs   );
     _PutImage2   := Ptr( Seg(Link^), PutImg2Ofs  );
     _HLine	  := Ptr( Seg(Link^), HLineOfs    );
     _VLine       := Ptr( Seg(Link^), VLineOfs    );
   End;

  DGIError:= 0;
End;

Procedure UnLoadDriver;
Begin
  FreeMem( Link, DriverSize );
  _SetMode   := nil;
  _PutPixel  := nil;
  _GetPixel  := nil;
  _Box       := nil;
  _PutImage  := nil;
  _GetImage  := nil;
  _PutImage2 := nil;
  _HLine     := nil;
  _VLine     := nil;
  Link       := nil;
  DriverSize := 0;
End;

  (* Extra drawing procedures *)
Procedure Line( x1,y1,x2,y2 : Word; Color: Word );
Var
  i, DeltaX, DeltaY, NumPixels,
  d, dInc1, dInc2,
  x, xInc1, xInc2,
  y, yInc1, yInc2 : integer;
Begin
  DeltaX := x2 - x1;
  DeltaY := y2 - y1;

  DeltaY := abs(DeltaY);
  DeltaX := abs(DeltaX);

  If DeltaX >= DeltaY
    Then Begin
      	   NumPixels := DeltaX + 1;
      	   d := (DeltaY shl 2) - DeltaX;
      	   dInc1 := DeltaY shl 1;
           dInc2 := (DeltaY - DeltaX) shl 1;
           xInc1 := 1;
           xInc2 := 1;
           yInc1 := 0;
           yInc2 := 1;
         End
    Else Begin
           NumPixels := DeltaY + 1;
           d := (DeltaX shl 2) - DeltaY;
           dInc1 := DeltaX shl 1;
           dInc2 := (DeltaX - DeltaY) shl 1;
           xInc1 := 0;
           xInc2 := 1;
           yInc1 := 1;
           yInc2 := 1;
         End;

  If x1 > x2 Then
    Begin
      xInc1 := - xInc1;
      xInc2 := - xInc2;
    End;
  If y1 > y2 Then
    Begin
      yInc1 := - yInc1;
      yInc2 := - yInc2;
    End;

  x := x1;
  y := y1;

  For i := 1 to NumPixels do
    Begin
      PutPixel(x, y, color);
      If d < 0
        Then Begin
               d := d + dinc1;
               x := x + xInc1;
               y := y + yInc1;
             End
        Else Begin
               d := d + dInc2;
               x := x + xInc2;
               y := y + yInc2;
             End;
    End;
End;

Procedure Circle(x1, y1, rad: Integer; Col: Word );
Var
  I, x, y: Integer;
  Degs: Real;
Begin
  Degs:= 0.0;
  For I:= 0 to 45 Do
    Begin
      x:= Round(rad*Cos(Degs));
      y:= Round(rad*Sin(Degs));
      Degs:= Degs + deg;
      PutPixel(x1+x, y1+y, Col);
      PutPixel(x1-x, y1+y, Col);
      PutPixel(x1+x, y1-y, Col);
      PutPixel(x1-x, y1-y, Col);
      PutPixel(x1+y, y1+x, Col);
      PutPixel(x1-y, y1+x, Col);
      PutPixel(x1+y, y1-x, Col);
      PutPixel(x1-y, y1-x, Col);
    End;
End;

Procedure FillCircle(x1, y1, rad : Integer; Col: Word );
Var
  I, J, x, y: Integer;
  degs: Real;
Begin
  Degs:= 0.0;
  For I:= 0 to 45 Do Begin
    x:= Round(rad*Cos(Degs));
    y:= Round(rad*Sin(Degs));
    Degs:= Degs + Deg;
    For J:= x1-x to x1+x Do Begin
      PutPixel(J, y1+y, Col);
      PutPixel(J, y1-y, Col);
    End;
    For J:= x1-y to x1+y Do Begin
      PutPixel(J, y1+x, Col);
      PutPixel(J, y1-x, Col);
    End;
  End;
End;

Procedure WriteChar1( x, y: Word; AChar: Char );
Var
  xx, yy: Word;
Begin
  For yy:= 0 to 7 do
    For xx:= 0 to 7 do
      If Font8x8^[AChar][yy] and (1 shl (7-xx)) <> 0
        Then PutPixel( x+xx, y+yy, FontColor )
        Else PutPixel( x+xx, y+yy, FontBack );
End;

Procedure WriteChar2( x, y: Word; AChar: Char );
Var
  xx, yy: Word;
Begin
  For xx:= 0 to 7 do
    For yy:= 0 to 15 do
      If Font8x16^[AChar][yy] and (1 shl (15-xx)) <> 0
        Then PutPixel( x+xx, y+yy, FontColor )
        Else PutPixel( x+xx, y+yy, FontBack )
End;

Procedure WriteStr1( x, y: Word; s: String );
Var
  xx, yy: Word;
  i     : Byte;
  SLen  : Byte absolute S;
Begin
  If SLen = 0 Then Exit;

  xx:= x;
  yy:= y;
  For i:= 1 to SLen do
    Begin
      If not (S[i] in ControlChars) Then WriteChar1( xx, yy, S[i] );
      Case s[i] of
        #10: Inc( yy, PixelsPerLine_8x8 );
        #13: xx:= 0;
         #8: Dec( xx, PixelsPerChar_8x8 );
        Else Inc( xx, PixelsPerLine_8x8 );
      End;

      If xx+PixelsPerLine_8x8>GetMaxX Then
        Begin
          xx:= 0;
          Inc( yy, PixelsPerLine_8x8 );
        End;
    End;
End;

Procedure WriteStr2( x, y: Word; s: String );
Var
  xx, yy: Word;
  i     : Byte;
  SLen  : Byte absolute S;
Begin
  If SLen = 0 Then Exit;

  xx:= x;
  yy:= y;
  For i:= 1 to SLen do
    Begin
      If not (S[i] in ControlChars) Then WriteChar2( xx, yy, S[i] );
      Case s[i] of
        #10: Inc( yy, PixelsPerLine_8x16 );
        #13: xx:= 0;
         #8: Dec( xx, PixelsPerChar_8x16 );
        Else Inc( xx, PixelsPerLine_8x16 );
      End;

      If xx+PixelsPerLine_8x16>GetMaxX Then
        Begin
          xx:= 0;
          Inc( yy, PixelsPerLine_8x16 );
        End;
    End
End;

   (* Other driver functions *)
Function GetMaxX: Word;
Begin
  GetMaxX:= TDGIRec(Link^).MaxX
End;

Function GetMaxY: Word;
Begin
  GetMaxY:= TDGIRec(Link^).MaxY
End;

Function GetDGIName: String;
Var
  S: String[39];
  SLen : Byte absolute S;
  i: Byte;
Begin
  S:= '';
  i:= 0;
  While (TDGIRec(Link^).DGIName[i]<>#0) and (i<40) do
    Begin
      Inc( i );
      S[i]:= TDGIRec(Link^).DGIName[i-1]
    End;
  SLen:= i;
  GetDGIName:= S;
End;

Procedure WaitRetrace; Assembler;
Asm
     MOV  DX,3DAh
@L1: IN   AL,DX
     TEST AL,08h
     JNZ  @L1
@L2: IN   AL,DX
     TEST AL,08h
     JZ   @L2
End;

Procedure WaitVRetrace; Assembler;
Asm
     MOV  DX,3DAh
@L1: IN   AL,DX
     TEST AL,08h
     JNZ  @L1
End;


End.
