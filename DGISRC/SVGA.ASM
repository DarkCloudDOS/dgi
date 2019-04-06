	     .386
Code    Segment Para 'Code' use16

Assume  cs:Code
Org 100h

Procs     DW      SetMode, ClearScreen, PutPixel, GetPixel
          DW      Box, PutImage, GetImage, PutImage2
	  DW      HLine, VLine, 0
Signature DB      'DGI DRIVER',26
DrvName   DB      'UnChained VESA mode 640x400x256',0,0,0,0,0,0,0,0,0
MaxX      DW      640
MaxY      DW      400


VGA       DW      0A000H
SAVEBP 	  EQU     WORD PTR CS:[00]
SAVEDS    EQU     WORD PTR CS:[02]
DDI       EQU     WORD PTR CS:[04]
SSI	  EQU	  WORD PTR CS:[06]


SetMode:
	MOV     AX,     04F02H
	MOV     BX,     00100H
	INT     10H		; Ask VESA for a chanined 640x400x256 mode

	MOV     DX,     03C4H
	MOV     AL,     1
	OUT     DX,     AL
	INC     DX
	IN      AL,     DX
	OR      AL,     020h
	OUT     DX,     AL	; Turn screen off

	MOV     DX,     03C4H
	MOV     AX,     0604H
	OUT     DX,     AX	; Unchain it...

	MOV     DX,     03D4H
	MOV     AX,     0E317H
	OUT     DX,     AX	; Word mode off
	MOV     DX,     03D4H
	MOV     AX,     0014H
	OUT     DX,     AX	; Doble-word mode off

        PUSH    ES
	MOV     DX,     03C4H
	MOV     AX,     0F02H
	OUT     DX,     AX	; Select all planes
	MOV     ES,     VGA
	XOR     DI,     DI
	XOR     EAX,    EAX
	MOV     CX,     0FFFFH/4
	REP     STOSD           ; Clear the screen
        POP     ES

	MOV     DX,     03DAH
RETRACE:IN      AL,     DX
	TEST    AL,     08H
	JNZ     RETRACE		; Wait for a vertical retrace

	MOV     DX,     03C4H
	MOV     AL,     1
	OUT     DX,     AL
	INC     DX
	IN      AL,     DX
	AND     AL,     0DFH
	OUT     DX,     AL	; Then turn screen on again

        PUSH    ES
        PUSH    0040H
        POP     ES
        MOV     BYTE PTR ES:[49H],6h	; if the mouse driver (MOUSE.COM)
        POP	ES			; does not recognize this mode as
					; a graphic he will now
	RETF

ClearScreen:
	MOV	BX,	BP	; Save BP in SI
	MOV	BP,	SP

        MOV	DX,	03C4H
        MOV	AX,	0F02H	; Selecet all planes
        OUT	DX,	AX

        MOV	AL,	[BP+4]
        MOV	AH,	AL
        MOV     DX,     AX
        SHL	EAX,	16
        MOV     AX,     DX      ; Choose color
	MOV	ES,	VGA
	XOR	DI,	DI	; Start at 0A000:0000
	MOV	CX,	640*400/16
        REP	STOSD

        MOV	BP,	BX	; Restore BP
	RETF 	2

PutPixel:
        MOV	SAVEBP,	BP	; Save BP
	MOV	BP,	SP

        MOV	CX,     [BP+8]
        AND     CL,	3
        MOV	AH,	1
        SHL	AH,	CL
        MOV     AL,     2
        MOV	DX,	03C4H
        OUT	DX,	AX      ; Select plane to write to

	MOV	DI,	[BP+6]
        MOV	CX,	DI
        SHL	DI,	7
        SHL	CX,	5
	ADD  	DI,     CX	; y*(128+32) = 160*y


        MOV	BX,	[BP+8]
	SHR  	BX,     2	; x mod 4 (BX = X)
	ADD  	DI,     BX
	MOV  	AL,	[BP+4]  ; Color
	MOV  	GS,     VGA
	MOV  	GS:[DI],AL      ; (y*160) + (x mod 4)

        MOV	BP,	SAVEBP
	RETF	6

GetPixel:
	MOV	SI,	BP      ; Save BP
        MOV	BP,	SP

        MOV	CX,     [BP+6]
        AND     CL,	3 	; x mod 4
        MOV	AL,	1
        SHL	AL,	CL
        MOV	DX,	03C5H
        OUT	DX,	AL      ; Select plane to write to

	MOV	DI,	[BP+4]
        MOV	CX,	DI
	SHL	DI,	7
        SHL	CX,	5
	ADD  	DI,     CX	; y*(128+32) = 160*y


	MOV	AX,	[BP+6]
	SHR  	AX,     2	; x/4
	ADD  	DI,     AX
	MOV  	ES,     VGA
	MOV  	AL,     ES:[DI] ; (y*160) + (x/4)

	MOV	BP,	SI	; Restore BP
	RETF	4

; BOX( X, Y, DX, DY, COLOR )
;     12  10  8   6    4
Box:
	MOV	SAVEBP,	BP
	MOV	BP,	SP

	;Calculate first point offset and store it in DDI
	MOV	ES,	VGA
	MOV	DI,	[BP+10]	; [BP+10] = y
	MOV	DX,	DI
	SHL	DI,	5
	SHL	DX,	7
	ADD	DI,	DX
	MOV	DDI,	DI	; Save DI, in i

	;For xx:= 0 to DX-1 do
	XOR	BX,	BX
BOX_LOOPX:
	;Write to plane
	MOV	CX,	[BP+12]	; [BP+12] = x
	ADD	CX,	BX
	AND	CX,	3
	MOV	AX,	0100H
	SHL	AH,	CL
	ADD	AL,	2
	MOV	DX,	03C4H
	OUT	DX,	AX
	;Calculate point
	MOV	DI,	DDI
	MOV	AX,	[BP+12]	; [BP+12] = x
	ADD	AX,	BX
	SHR     AX,	2
	ADD	DI,	AX

	MOV	AL,	[BP+4]	; [BP+4] = Color
	MOV	CX,	[BP+6]	; [BP+6] = SizeY
	;For yy:= 0 to DX-1 do
BOX_LOOPY:
	MOV	ES:[DI],AL
	ADD	DI,	640/4
	LOOP	BOX_LOOPY	; End For y

	INC	BX
	CMP	BX,	[BP+8]	; [BP+8] = SizeX
	JNE	BOX_LOOPX	; End For x

	MOV	BP,	SAVEBP
	RETF	10


PutImage:
	MOV	SAVEDS,	DS
	MOV	SAVEBP,	BP
	MOV	BP,	SP

        MOV	DS,	[BP+6]	; LES	DI, Image
        MOV	SI,	[BP+4]

	;Calculate first point offsetand store it in DDI
	MOV	ES,	VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	5
	SHL	DX,	7
	ADD	DI,	DX

	MOV	DDI,	DI	; Save DI, in i
	MOV	SSI,	SI	; Save SI, in j

	;For xx:= 0 to DX-1 do
	XOR	BX,	BX
PUTIMAGE_LOOPX:
	;Write to plane
	MOV     SI,	SSI
	MOV	CX,	[BP+14]	; [BP+14] = x
	ADD	CX,	BX
	AND	CX,	3
	MOV	AX,	0100H
	SHL	AX,	CL
	ADD	AX,	2
	MOV	DX,	03C4H
	OUT	DX,	AX
	;Calculate point
	MOV	DI,	DDI
	MOV	AX,	[BP+14]	; [BP+14] = x
	ADD	AX,	BX
	SHR     AX,	2
	ADD	DI,	AX
	;For yy:= 0 to DX-1 do
	;   If Color<>0 then DrawIt
	MOV	CX,	[BP+8]	; [BP+8] = SizeY
PUTIMAGE_LOOPY:
	MOV	AL,	[SI]
	MOV	ES:[DI],AL
	ADD	DI,	160
	ADD	SI,	[BP+10]	; [BP+10] = SizeX
	LOOP	PUTIMAGE_LOOPY	; End For y

	INC	SSI
	INC	BX
	CMP	BX,	[BP+10]	; [BP+10] = SizeX
	JNE	PUTIMAGE_LOOPX	; End For x

	MOV	DS,	SAVEDS
	MOV	BP,	SAVEBP
	RETF	12

GetImage:
        MOV	SAVEDS,	DS
	MOV	SAVEBP,	BP
	MOV	BP,	SP

        MOV	DS,	[BP+6]	; LES	DI, Image
        MOV	SI,	[BP+4]

	;Calculate first point offsetand store it in DDI
	MOV	ES,	VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	5
	SHL	DX,	7
	ADD	DI,	DX

	MOV	DDI,	DI	; Save DI, in i
	MOV	SSI,	SI	; Save SI, in j

	;For xx:= 0 to DX-1 do
	XOR	BX,	BX
GETIMAGE_LOOPX:
	;Read plane and select plane
	MOV	SI,	SSI
	MOV	DX,     03CEH
	MOV	AL,     04
	OUT	DX,     AL
	MOV	AX,     [BP+14]	; [BP+14] = x
	ADD	AX,	BX
	AND	AX,     03
	INC	DX
	OUT	DX,     AX

	;Calculate point
	MOV	DI,	DDI
	MOV	AX,	[BP+14]	; [BP+14] = x
	ADD	AX,	BX
	SHR     AX,	2
	ADD	DI,	AX
	;For yy:= 0 to DX-1 do
	;   If Color<>0 then DrawIt
	MOV	CX,	[BP+8]	; [BP+8] = SizeY
GETIMAGE_LOOPY:
	MOV	AL,	ES:[DI]
	MOV	[SI],	AL
	ADD	DI,	160
	ADD	SI,	[BP+10] ; [BP+10] = SizeX
	LOOP	GETIMAGE_LOOPY	; End For y

	INC	SSI
	INC	BX
	CMP	BX,	[BP+10]	; [BP+10] = SizeX
	JNE	GETIMAGE_LOOPX	; End For x

        MOV	DS,	SAVEDS
	MOV	BP,	SAVEBP
	RETF	12

PutImage2:
	MOV	SAVEBP,	BP
	MOV	BP,	SP

        MOV	DS,	[BP+6]	; LES	DI, Image
        MOV	SI,	[BP+4]

	;Calculate first point offsetand store it in DDI
	MOV	ES,	VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	5
	SHL	DX,	7
	ADD	DI,	DX

	MOV	DDI,	DI	; Save DI, in i
	MOV	SSI,	SI	; Save SI, in j

	;For xx:= 0 to DX-1 do
	XOR	BX,	BX
PUTIMAGE2_LOOPX:
	;Write to plane
	MOV     SI,	SSI
	MOV	CX,	[BP+14]	; [BP+14] = x
	ADD	CX,	BX
	AND	CX,	3
	MOV	AX,	0100H
	SHL	AX,	CL
	ADD	AX,	2
	MOV	DX,	03C4H
	OUT	DX,	AX
	;Calculate point
	MOV	DI,	DDI
	MOV	AX,	[BP+14]	; [BP+14] = x
	ADD	AX,	BX
	SHR     AX,	2
	ADD	DI,	AX
	;For yy:= 0 to DX-1 do
	;   If Color<>0 then DrawIt
	MOV	CX,	[BP+8]	; [BP+8] = SizeY
PUTIMAGE2_LOOPY:
	MOV	AL,	[SI]
	OR	AL,	AL
	JZ	PUTIMAGE2_DONT_PUT
	MOV	ES:[DI],AL
PUTIMAGE2_DONT_PUT:
	ADD	DI,	160
	ADD	SI,	[BP+10]	; [BP+10] = SizeX
	LOOP	PUTIMAGE2_LOOPY	; End For y

	INC	SSI
	INC	BX
	CMP	BX,	[BP+10]	; [BP+10] = SizeX
	JNE	PUTIMAGE2_LOOPX	; End For x

	MOV	BP,	SAVEBP
	RETF	12

; Procedure HLine( x , y, XLen , Color );
;                  10  8   6      4
HLine:
	MOV	SAVEBP,	BP
	MOV	BP,	SP

	MOV	DI,	[BP+8]	; [BP+8] = y
        MOV	DX,	DI
        SHL	DI,	5
        SHL	DX,	7
        ADD	DI,	DX
        MOV	DDI,	DI

        MOV	BL,	[BP+4]	; [BP+4] = Color
        MOV	ES,	VGA
        MOV	DX,	03C4H
        MOV	SI,	[BP+6]	; [BP+6] = XLen
HLINE_LOOPX:
	MOV 	DI,	SI
        ADD	DI,	[BP+10]	; [BP+10] = x
;       SET PORTS
	MOV	CX,	DI
        AND     CL,	3
        MOV	AH,	1
        SHL	AH,	CL
        MOV     AL,     2
        OUT	DX,	AX      ; Select plane to write to

        SHR	DI,	2
        ADD    	DI,	DDI
        MOV	ES:[DI],BL
        DEC	SI
        JNZ	HLINE_LOOPX

        MOV	BP,	SAVEBP
	RETF    8

; Procedure VLine( x ,y, YLen, Color )
;                  10 8    6     4
VLine:
	MOV	SI,	BP
	MOV	BP,	SP

	;Calculate first point offset and store it in DDI
	MOV	ES,	VGA
	MOV	DI,	[BP+8]	; [BP+8] = Color
	MOV	DX,	DI
	SHL	DI,	5
	SHL	DX,	7
	ADD	DI,	DX
	MOV	BX,	DI

	;Write to plane
	MOV	CX,	[BP+10]	; [BP+10] = x
	AND	CX,	3
	MOV	AX,	0100H
	SHL	AX,	CL
	ADD	AX,	2
	MOV	DX,	03C4H
	OUT	DX,	AX

	;Calculate point
	MOV	DI,	BX	; DDI = 160*y
	MOV	AX,	[BP+10]	; [BP+10] = x
	SHR     AX,	2
	ADD	DI,	AX

	;For yy:= 0 to SizeY-1 do
	MOV	AL,	[BP+4]	; [BP+4] = Color
	MOV	CX,	[BP+6]	; [BP+6] = SizeY
VLINE_LOOPY:
	MOV	ES:[DI],AL
	ADD	DI,	640/4
	LOOP	VLINE_LOOPY	; End For y

        MOV	BP,	SI
        RETF	8


Code    Ends

End Procs
