Program Demo4;

(* Compare between DGI and GVision *)
(* They are somehow faster big deal . . . *)

Uses DGI,
   GraphDrv,
   DrawLat, DrawNum, DrawSpc, DrawRus; { Fonts }


Const
(* How mush time do the testing *)
  Seconds = 4;

(* Vars for graph *)
  Graph_Drv: String  = 'VESA256.DRV';       {Graph driver for GVision}

  ModeToTest_DGI   = 'VESALO.DGI';          {DGI Driver to test}

(* Size of the image for the putimage test *)
  BMMaxX = 180;
  BMMaxY = 100;


Var
  GVisionTimes,
  DGITimes : Record
    PutPixel    : LongInt;
    ClearScreen : LongInt;
    Box         : LongInt;
    PutImage	: LongInt;
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
Begin
  Randomize;
  For y:= 0 to BMMaxY-1 do
    For x:= 0 to BMMaxX-1 do
      BitMap.Buffer[y,x]:= y*x;
  BitMap.SizeX:= BMMaxX;  { The unit graph somehow needs the size to  }
  BitMap.SizeY:= BMMaxY;  { be bigger by 1				}

(* Test the unit graph *)
  if (GraphDrv.LoadDriver(Graph_Drv)<>gdOk) then halt;

  InitDriver(257);
  SetGraphMode;

  T:= Timer;
  Repeat
    GraphDrv.PutPixel( Random(GraphDrv.GetMaxX), Random(GraphDrv.GetMaxY), Random(256) );
    Inc( GVisionTimes.PutPixel );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    GraphDRV.ClearDevice(Random(256));
    Inc( GVisionTimes.ClearScreen);
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    GraphDRV.Bar( Random(GraphDRV.GetMaxX), Random(GraphDRV.GetMaxY),
                  Random(GraphDRV.GetMaxX), Random(GraphDRV.GetMaxY),
                  Random(256) );
    Inc( GVisionTimes.Box );
  Until Timer>=T+18.2*Seconds;

  T:= Timer;
  Repeat
    GraphDRV.PutImage( Random(GraphDRV.GetMaxX-BitMap.SizeX), Random(GraphDRV.GetMaxY-BitMap.SizeY),
    	      @BitMap );
    Inc( GVisionTimes.PutImage );
  Until Timer>=T+18.2*Seconds;
  CloseGraph;

(* Test BGI *)
  DGI.LoadDriver( ModeToTest_DGI );
  DGI.SetMode;

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
    	      BitMap.SizeX, BitMap.SizeY, BitMap.Buffer );
    Inc( DGITimes.PutImage );
  Until Timer>=T+18.2*Seconds;

  UnLoadDriver;
  SetVGAMode( TextMode );

  WriteLn( '               Graph             DGI' );
  WriteLn( 'PutPixel   ':10, GVisionTimes.PutPixel   /Seconds:10:2, '     ', DGITimes.PutPixel   /Seconds:10:2 );
  WriteLn( 'ClearScreen':10, GVisionTimes.ClearSCreen/Seconds:10:2, '     ', DGITimes.ClearScreen/Seconds:10:2 );
  WriteLn( 'Box        ':10, GVisionTimes.Box        /Seconds:10:2, '     ', DGITimes.Box        /Seconds:10:2 );
  WriteLn( 'PutImage   ':10, GVisionTimes.PutImage   /Seconds:10:2, '     ', DGITimes.PutImage   /Seconds:10:2 );

  WriteLn;
  WriteLn( 'DGI.PutPixel    is ',DGITimes.PutPixel   /GVisionTimes.PutPixel   :5:2, ' times faster then GVision.' );
  WriteLn( 'DGI.ClearScreen is ',DGITimes.ClearScreen/GVisionTimes.ClearScreen:5:2, ' times faster then GVision.' );
  WriteLn( 'DGI.Box         is ',DGITimes.Box        /GVisionTimes.Box        :5:2, ' times faster then GVision.' );
  WriteLn( 'DGI.PutImage    is ',DGITimes.PutImage   /GVisionTimes.PutImage   :5:2, ' times faster then GVision.' );
End.
