Program Demo3;

Uses Graph, DGI;

Const
(* How mush time do the testing *)
  Seconds = 4;

(* Vars for graph *)
  GD: Integer = 0;                                {Graph driver, MCGA}
  GM: Integer = 0;                                {Graph Mode}
  GP: String  = 'C:\BP\BGI';                      {Graph Path}

  ModeToTest_DGI   = 'XMODE.DGI'; {DGI Driver to test}
  { Aviable modes:
  0) 320x200x256
  1) 640x400x256
  2) 640x480x256
  3) 800x600x256
  4) 1024x768x256 }
  ModeToTest_Graph = 0;

(* Size of the image for the putimage test *)
  BMMaxX = 180;
  BMMaxY = 100;


(* SVGA detection function *)
Function DetectSVGA: Integer; Far;
Begin
  DetectSVGA:= ModeToTest_Graph;
End;

Var
  GraphTimes,
  DGITimes : Record
    PutPixel    : LongInt;
    ClearScreen : LongInt;
    Box         : LongInt;
    PutImage    : LongInt;
  End;

  BitMap : Record
    SizeX, SizeY: Integer;
    Reserved: Integer;
    Buffer: Array[0..BMMaxY-1, 0..BMMaxX-1] of Byte;
  End;

  T                   : LongInt;
  Timer               : LongInt absolute $40:$6C;
  MaxX, MaxY, MaxColor: Integer;
  Error               : Integer;
  x, y                : Integer;
  Pattern             : FillPatternType;
Begin
  Randomize;
  For y:= 0 to BMMaxY-1 do
    For x:= 0 to BMMaxX-1 do
      BitMap.Buffer[y,x]:= y*x;
  BitMap.SizeX:= BMMaxX-1;  { The unit graph somehow needs the size to  }
  BitMap.SizeY:= BMMaxY-1;  { be bigger by 1                            }

(* Test the unit graph *)
  GD:= InstallUserDriver('SVGA256',@DetectSVGA);
  GD:= Detect;
  InitGraph( GD, GM, GP );

  MaxColor:= GetMaxColor;
  MaxX    := Graph.GetMaxX;
  MaxY    := Graph.GetMaxY;

  T:= Timer;
  Repeat
    Graph.PutPixel( Random(Graph.GetMaxX), Random(Graph.GetMaxY), Random(256) );
    Inc( GraphTimes.PutPixel );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    SetBKColor( Random(256) );
    Graph.ClearDevice;
    Inc( GraphTimes.ClearScreen);
  Until Timer>=T+18.2*Seconds;

  GetFillPattern(Pattern);
  T:= Timer;
  Repeat
    SetFillPattern(Pattern, Random(256) );
    Bar( Random(Graph.GetMaxX), Random(Graph.GetMaxY),
         Random(Graph.GetMaxX), Random(Graph.GetMaxY) );
    Inc( GraphTimes.Box );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    Graph.PutImage( Random(Graph.GetMaxX-BitMap.SizeX), Random(Graph.GetMaxY-BitMap.SizeY),
              BitMap, NormalPut );
    Inc( GraphTimes.PutImage );
  Until Timer>=T+18.2*Seconds;
  CloseGraph;

(* Test BGI *)
  LoadDriver( ModeToTest_DGI );
  SetMode;

  If DGIError<>0 Then Halt;

  T:= Timer;
  Repeat
    DGI.PutPixel( Random(DGI.GetMaxX), Random(DGI.GetMaxY), Random(256) );
    Inc( DGITimes.PutPixel );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    DGI.ClearScreen( Random(256) );
    Inc( DGITimes.ClearScreen);
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    x:= Random(DGI.GetMaxX);
    y:= Random(DGI.GetMaxY);
    DGI.Box( x, y,
             Random(DGI.GetMaxX-x)+1, Random(DGI.GetMaxY-y)+1,
             Random(256) );
    Inc( DGITimes.Box );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    DGI.PutImage( Random(DGI.GetMaxX-BitMap.SizeX), Random(DGI.GetMaxY-BitMap.SizeY),
              BitMap.SizeX+1, BitMap.SizeY+1, BitMap.Buffer );
    Inc( DGITimes.PutImage );
  Until Timer>=T+18.2*Seconds;

  UnLoadDriver;
  SetVGAMode( TextMode );

  WriteLn( '               Graph             DGI' );
  WriteLn( 'PutPixel   ':10, GraphTimes.PutPixel   /Seconds:10:2, '     ', DGITimes.PutPixel   /Seconds:10:2 );
  WriteLn( 'ClearScreen':10, GraphTimes.ClearScreen/Seconds:10:2, '     ', DGITimes.ClearScreen/Seconds:10:2 );
  WriteLn( 'Box        ':10, GraphTimes.Box        /Seconds:10:2, '     ', DGITimes.Box        /Seconds:10:2 );
  WriteLn( 'PutImage   ':10, GraphTimes.PutImage   /Seconds:10:2, '     ', DGITimes.PutImage   /Seconds:10:2 );

  WriteLn;
  WriteLn( 'DGI.PutPixel    is ',DGITimes.PutPixel   /GraphTimes.PutPixel   :5:2, ' times faster then graph unit.' );
  WriteLn( 'DGI.ClearScreen is ',DGITimes.ClearScreen/GraphTimes.ClearScreen:5:2, ' times faster then graph unit.' );
  WriteLn( 'DGI.Box         is ',DGITimes.Box        /GraphTimes.Box        :5:2, ' times faster then graph unit.' );
  WriteLn( 'DGI.PutImage    is ',DGITimes.PutImage   /GraphTimes.PutImage   :5:2, ' times faster then graph unit.' );
End.
