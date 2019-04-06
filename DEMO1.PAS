Program Demo1;

(* The DGI uses a 386 intruction set so we can enable the 286
   instruction set for the compiler by using the {$G} compiler
   directive *)

{$G+}

(* In the program the mouse will be showed and to animate it press
     the CTRL key on the keyboard.
*)

Uses DGI, VMouse, CPUType;

Const
{ The speed in wich we draw the screen }
  Max_Random = $FFF;
{ Aviabe drivers are :
   MCGA   - 320x200, fast Put/Get image, fast pixel
   SVGA   - 640x400, great resolution (twice MCGA )
   XMODE  - 240x240, fast ClearScreen, pixel ratio 1:1 (rectangular)
   VESALO - 640x480, VESA mode
   VESAHI = 600x800, VESA mode}

  Driver     = 'SVGA';

{Size of the BigImg, MaxX*MaxY must be less then 64K }
  MaxX = 256;
  MaxY = 150;

{Grid}
  GridColor = 2;
  GridX     = 10;
  GridY     = 10;


Function Str( i: Integer ): String;
Var
  Strng: String[3];
Begin
  System.Str( i:3, Strng );
  Str:= Strng;
End;

Procedure LoadBuffer( FileName: String; HeaderSize: Word;
 Bytes: Word; Var Buf );
Var
  F: File;
Begin
  Assign( F, FileName );
  Reset( F , 1 );
  If (HeaderSize<>0) Then BlockRead( F, Buf, HeaderSize );
  BlockRead( F, Buf, Bytes );
  Close( F )
End;

Function GetKey: Word; Assembler;
Asm
        XOR     AX,     AX
        MOV     ES,     SEG0040
        MOV     BL,     ES:[1AH]
        MOV     BH,     ES:[1CH]
        CMP     BL,     BH
        JE      @NO_KEY
        XOR     AX,     AX
        INT     16H
@NO_KEY:
End;


Var
  BigImg    : array[ 0..MaxY-1, 0..MaxX-1] of Byte;
  Img       : array[0..8] of array[0..15,0..15] of Byte;
  DriverName: String[50];
  DosFont8x8: T8x8Font;
  x, y      : word;
Begin
  If CPU < CPU_80386 Then
    Begin
      WriteLn( 'The DGI needs a 386 instruction set to run.');
      WriteLn( 'A lower machine was detecte, so if you will try');
      WriteLn( 'to continue executing the program the computer will crush.');
      WriteLn;
      WriteLn( 'You can try and write a driver that uses a lower instruction');
      WriteLn( 'set by looking at the DGI sources.' );
      Halt(1);
    End;

  Randomize;
  For y:= 0 to MaxY-1 do
    For x:= 0 to MaxX-1 do
      BigImg[y,x]:= y*x;

  LoadBuffer( 'FONT1.FNT' , 0, SizeOf(T8x8Font), DosFont8x8 );
  LoadBuffer( 'MOUSES.PIX', 2, 16*16*9, Img );

  LoadDriver( Driver+'.DGI' );
  If DGIError<>deNoError Then Halt;

  Font8x8:= @DosFont8x8;
  FontColor:= 10;
  FontBack:= 27;
  DriverName:= GetDGIName;
  For x:= 0 to 8 do MouseCursor[x]:= @Img[x];


  SetMode;
  UseVMouseInt:= False;
  InitVMouse;
  MouseWindow( 0, 0, GetMaxX*2, GetMaxY );
  ClearScreen( 27 );

{Draw a pointer}
  PutImage2( 10, 10, 16, 16, MouseCursor[0]^ );  {MouseCursor[0]^}
  PutImage ( 10, 30, 16, 16, MouseCursor[0]^ );  {MouseCursor[0]^}
{Draw a variable}
  PutImage( (GetMaxX-MaxX) div 2, (GetMaxY-MaxY) div 2,
             MaxX, MaxY,
             BigImg );  {BigImg}

  Box( 0, GetMaxY div 2, GetMaxX div 3, GetMaxY div 3, 9 );
  WriteStr1( GetMaxX-9*3, 53, 'Test string longer then a line.'#10'New line.');

  For y:= 0 to GetMaxY div GridY do
    HLine(       0, y*GridY, GetMaxX, GridColor );
  For x:= 0 to GetMaxX div GridX do
    VLine( x*GridX,       0, GetMaxY, GridColor );

  ShowVMouse;
  Repeat
    VMouseHandler;
    If Random(Max_Random)=Random(Max_Random) Then
      Begin
        HideVMouse;
        ClearScreen( Random( 256 ));

        PutImage2( 10, 10, 16, 16, MouseCursor[0]^ );
        PutImage ( 10, 30, 16, 16, MouseCursor[0]^ );
        PutImage( (GetMaxX-MaxX) div 2, (GetMaxY-MaxY) div 2, MaxX, MaxY, BigImg );
        Box( 0, GetMaxY div 2, GetMaxX div 3, GetMaxY div 3, 9 );
        WriteStr1( GetMaxX-9*3, 53, 'Test string longer then a line.'#10+'New line.' );

        For y:= 0 to GetMaxY div GridY do
          HLine(       0, y*GridY, GetMaxX, GridColor );
        For x:= 0 to GetMaxX div GridX do
          VLine( x*GridY,       0, GetMaxY, GridColor );
        FontBack:= GetPixel( GetMaxX-1, GetMaxY-1 );

        ShowVMouse
      End;

    If (Port[$60]=$1D)
      Then Begin If Not Animating Then StartAnimation( 4, 7, 3 ) End
      Else StopAnimation( 0 );

    WriteStr1( GetMaxX div 2, 10, Str(GetMouseX shr 1) );
    WriteStr1( GetMaxX div 2, 30, Str(GetMouseY) );
  Until (GetKey<>0) or (GetButton<>0);

{  HideVMouse;
  Circle    ( GetMaxX div 2, GetMaxY div 2, GetMaxX div 4, Random(256));
  FillCircle( GetMaxX div 2, GetMaxY div 2, GetMaxX div 4, Random(256));
  ShowVMouse;
  While (GetKey=kbEsc) or (GetButton=mbLeftButton) do VMouseHandler;}

  DoneVMouse;
  ClearScreen( 0 );
  UnLoadDriver;
  WaitRetrace;
  SetVGAMode( TextMode );
  WriteLn( 'Driver name was : ', DriverName );
End.
