Unit VMouse;

{$A+,B-,D+,E+,F+,G+,I-,L+,N+,O-,P-,Q-,R-,S-,T-,V+,X+}
{$M 16384,0,655360}

Interface

Const
  CursorSizeX: Word = 16;
  CursorSizeY: Word = 16;

Var
  MouseCursor  : array[0..20] of Pointer;
  MouseButtons : Byte;

{ Mouse driver }
Function  InitMouse( Var ButtonCount: Byte ): Boolean;
Procedure MouseInfo( Var Buttons: Byte; Var x,y: Integer );
Procedure MouseXY( x,y: Word );
Procedure MouseWindow( x1, y1, x2, y2:word);
Procedure SetSpeed( x,y : Word );
Procedure InstallHandler( NewHandler: Pointer );

Function  GetMouseX: Word; InLine($B8/$03/$00/$CD/$33/$89/$C8);
Function  GetMouseY: Word; InLine($B8/$03/$00/$CD/$33/$89/$D0);
Function  GetButton: Word; InLine($B8/$03/$00/$CD/$33/$89/$D8);



{Virtual mouse }
Procedure InitVMouse;
Procedure DoneVMouse;
Procedure ShowVMouse;
Procedure HideVMouse;
Procedure BoundsHide( x1, y1, x2, y2: Integer );

Procedure ShowCursor( AFrame: Byte );
Procedure StartAnimation( FisrtFrame, LastFrame, Speed: Byte );
Procedure StopAnimation( AFrame: Byte );

Procedure VMouseHandler;

Var
  MouseAviable: Boolean;
  Animating   : Boolean;

Const
  UseVMouseInt: Boolean = True;

Implementation

Uses DGI;

Const
  VMouseIntNumber = $8;

  CurFrame    : Byte      = 0;
  MouseShowed : Boolean   = False;
  LastInt1C   : Pointer   = nil;

Var
  UnderMouse  : Pointer;
  LastX       : Integer;
  LastY       : Integer;

  Time, Count : Byte;
  Frame_1     : Byte;
  Frame_n     : Byte;

   (* Interrupts *)

Procedure PUSHF;  InLine($9C);
Procedure STI;    InLine($FB);
Procedure CLI;    InLine($FA);


Procedure GetIntVec(IntNo: Byte; var Vector: Pointer); Assembler;
Asm
        CLI
	MOV	AL,	IntNo
	MOV	AH,	35H
	INT	21H
	MOV	AX,	ES
	LES	DI,	Vector
	CLD
	XCHG	AX,	BX
	STOSW
	XCHG	AX,	BX
	STOSW
        STI
End;

Procedure SetIntVec(IntNo: Byte; Vector: Pointer); Assembler;
Asm
        CLI
	PUSH	DS
	LDS	DX,	Vector
	MOV	AL,	IntNo
	MOV	AH,	25H
	INT	21H
	POP	DS
        STI
End;

   (* Drawing procedures for the mouse handler *)

Procedure NewPutImage( x, y: Integer; Var Image  );
Var
  xx, yy : Integer;
  _x, _y : Integer;
  ImgLink: array[0..$FFFF-1] of Byte absolute Image;
Begin
  _y:= CursorSizeY-1;
  _x:= CursorSizeX-1;

  If _x+x>=GetMaxX Then _x:= GetMaxX - x;
  If _y+y>=GetMaxY Then _y:= GetMaxY - y;

  For yy:= 0 to _y-1 do
    For xx:= 0 to _x-1 do
      PutPixel( x+xx, y+yy, ImgLink[yy*CursorSizeX+xx] );
End;

Procedure NewPutImage2( x, y: Integer; Var Image  );
Var
  xx, yy : Integer;
  _x, _y : Integer;
  ImgLink: array[0..$FFFF-1] of Byte absolute Image;
Begin
  _y:= CursorSizeY-1;
  _x:= CursorSizeX-1;

  If _x+x>=GetMaxX Then _x:= _x - ((x+_x) - GetMaxX);
  If _y+y>=GetMaxY Then _y:= _y - ((y+_y) - GetMaxY);

  For yy:= 0 to _y-1 do
    For xx:= 0 to _x-1 do
      if ImgLink[yy*CursorSizeX+xx]<>0 Then
        PutPixel( x+xx, y+yy, ImgLink[yy*CursorSizeX+xx] );
End;

Procedure NewGetImage( MouseX, MouseY: Integer; Var Image );
Var
  xx, yy : Integer;
  _x, _y : Integer;
  ImgLink: array[0..$FFFF-1] of Byte absolute Image;
Begin
  _y:= CursorSizeY-1;
  _x:= CursorSizeX-1;

  If _x+MouseX>=GetMaxX Then _x:= _x - ((MouseX+_x) - GetMaxX);
  If _y+MouseY>=GetMaxY Then _y:= _y - ((MouseY+_y) - GetMaxY);

  For yy:= 0 to _y-1 do
    For xx:= 0 to _x-1 do
      ImgLink[yy*CursorSizeX+xx]:= GetPixel( MouseX+xx, MouseY+yy );
End;

Procedure PrintUnder( x,y: Integer );
Begin
  If (x+CursorSizeX>GetMaxX) or (y+CursorSizeY>GetMaxY)
    Then NewPutImage( x, y, UnderMouse^ )
    Else PutImage   ( x, y, CursorSizeX, CursorSizeY, UnderMouse^ );
End;

Procedure SaveUnder( x,y: Integer );
Begin
 { If (x+CursorSizeX>GetMaxX) or (y+CursorSizeY>GetMaxY)
    Then NewGetImage( x, y, UnderMouse^ )
    Else }GetImage   ( x, y, CursorSizeX, CursorSizeY, UnderMouse^ );
End;

Procedure PrintMouse( x,y: Integer );
Begin
  If (x+CursorSizeX>GetMaxX) or (y+CursorSizeY>GetMaxY)
    Then NewPutImage2( x, y, MouseCursor[CurFrame]^ )
    Else PutImage2   ( x, y, CursorSizeX, CursorSizeY, MouseCursor[CurFrame]^ );
End;

Procedure VMouseInt; Interrupt;
Type
  Call = Procedure;
Var
  Buttons: Byte;
  x,y : Integer;
  DontWrite: Boolean;
Begin
  PUSHF;
  Call(LastInt1C);

  If Not MouseShowed Then Begin Port[$20]:= $20; Exit; End;

{*** Animation **************************************************************}
  DontWrite:= True;
  If Animating Then
    Begin
      Dec( Count );
      If Count = 0 Then
        Begin
          DontWrite:= False;
          Count:= Time;
          Inc( CurFrame );
          If CurFrame > Frame_n Then CurFrame:= Frame_1;
        End;
   End;
{****************************************************************************}

  MouseInfo( Buttons, x, y );
  If (x=LastX) and (y=LastY) and DontWrite
    Then Begin Port[$20]:= $20; Exit; End;

  PrintUnder( LastX, LastY );
  SaveUnder( x, y );
  PrintMouse( x, y );

  LastX:= x;
  LastY:= y;

  Port[$20]:= $20;
End;


  (* Interface implemantation *)

{ Mouse driver (MOUSE.COM) }
Function InitMouse( Var ButtonCount: Byte ): Boolean; Assembler;
Asm
        PUSH    ES
        XOR     AX,     AX
        INT     33H
        LES     DI,     ButtonCount
        MOV     ES:[DI],BX
        POP     ES
End;

Procedure MouseInfo( Var Buttons: Byte; Var x,y: Integer ); Assembler;
Asm
	MOV	AX,	3
        INT	33H

        LES	DI,	Buttons
        MOV	ES:[DI],BL

        LES	DI,	X
        SHR	CX,	1
        MOV	ES:[DI],CX

        LES	DI,	y
        MOV	ES:[DI],DX
End;


Procedure MouseXY( x,y: Word ); Assembler;
Asm
	MOV 	AX,      4
	MOV 	DX,      Y
	MOV 	CX,      X
	INT 	33h
END;

Procedure MouseWindow( x1, y1, x2, y2:word) ; assembler;
asm
	MOV  	AX,     7
	MOV  	CX,     x1
	MOV  	DX,     x2
	INT  	33h
	MOV  	AX,     8
	MOV  	CX,     y1
	MOV  	DX,     y2
	INT  	33h
end;

Procedure SetSpeed( x,y : Word ); Assembler;
Asm
	MOV  	AX,     1Ah
	MOV  	BX,     X
	MOV  	CX,     Y
	XOR  	DX,     DX
	INT  	33h
End;

Procedure InstallHandler( NewHandler: Pointer ); Assembler;
Asm
	LES	DX,	NewHandler
	MOV 	AX, 	12
	MOV 	CX, 	$1F
	INT 	33H
End;

{ Virtual mouse }
Procedure InitVMouse;
Begin
  MouseAviable:= InitMouse( MouseButtons );
  If Not MouseAviable Then Exit;

  Frame_1  := 0;
  Frame_n  := 0;
  Time     := $FF;
  Count	   := $FF;
  Animating:= False;

  MouseXY( 0,0 );
  GetMem( UnderMouse, CursorSizeX*CursorSizeY );

  If UseVMouseInt Then
    Begin
      GetIntVec( VMouseIntNumber, LastInt1C  );
      SetIntVec( VMouseIntNumber, @VMouseInt );
    End;
End;

Procedure DoneVMouse;
Begin
  If Not MouseAviable Then Exit;
  HideVMouse;

  FreeMem( UnderMouse, CursorSizeX*CursorSizeY );
  If UseVMouseInt Then
    SetIntVec( VMouseIntNumber, LastInt1C );
End;

Procedure ShowVMouse;
Begin
  If MouseShowed Then Exit;

  If UseVMouseInt Then
    SetIntVec( VMouseIntNumber, @VMouseInt );

  MouseShowed:= True;
  LastX:= GetMouseX shr 1;
  LastY:= GetMouseY;
  SaveUnder( LastX, LastY );
  PrintMouse( LastX, LastY );
End;

Procedure HideVMouse;
Begin
  If Not MouseShowed Then Exit;

  If UseVMouseInt Then
    SetIntVec( VMouseIntNumber, LastInt1C );

  MouseShowed:= False;
  Animating:= False;
  PrintUnder( LastX, LastY );
End;

Procedure BoundsHide( x1, y1, x2, y2: Integer );
Var
  x, y: Integer;
  B: Byte;
Begin
  MouseInfo( b, x, y );

  If (x>=x1) and (y>=y1) and
     (x< x2) and (y< y2) Then HideVMouse;
End;

Procedure ShowCursor( AFrame: Byte );
Begin
  CurFrame:= AFrame;

  If MouseShowed Then
    Begin
      PrintUnder( LastX, LastY );
      SaveUnder ( LastX, LastY );
      PrintMouse( LastX, LastY );
    End;
End;

Procedure StartAnimation( FisrtFrame, LastFrame, Speed: Byte );
Begin
  Animating:= True;

  Frame_1  := FisrtFrame;
  Frame_n  := LastFrame;
  CurFrame := Frame_1;
  Time     := Speed;
  Count	   := Speed;
End;

Procedure StopAnimation( AFrame: Byte );
Begin
  If Not Animating Then Exit;

  Animating:= False;
  CurFrame := AFrame;

  If MouseShowed Then
    Begin
      PrintUnder( LastX, LastY );
      SaveUnder ( LastX, LastY );
      PrintMouse( LastX, LastY );
    End;
End;

Procedure VMouseHandler;
Var
  Buttons: Byte;
  x,y : Integer;
  DontWrite: Boolean;
Begin
  If Not MouseShowed Then Exit;

{*** Animation **************************************************************}
  DontWrite:= True;
  If Animating Then
    Begin
      Dec( Count );
      If Count = 0 Then
        Begin
          DontWrite:= False;
          Count:= Time;
          Inc( CurFrame );
          If CurFrame > Frame_n Then CurFrame:= Frame_1;
        End;
   End;
{****************************************************************************}

  MouseInfo( Buttons, x, y );
  If (x=LastX) and (y=LastY) and DontWrite
    Then Exit;

  PrintUnder( LastX, LastY );
  SaveUnder( x, y );
  PrintMouse( x, y );

  LastX:= x;
  LastY:= y;
End;

End.
