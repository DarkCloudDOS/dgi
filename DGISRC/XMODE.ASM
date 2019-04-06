	     .386
Code    Segment Para 'Code' use16

Assume  cs:Code
Org 100h

Procs     DW      SetMode, ClearScreen, PutPixel, GetPixel
          DW      Box, PutImage, GetImage, PutImage2
	  DW	  HLine, VLine, 0
Signature DB      'DGI DRIVER',26
DrvName   DB      'UnChained mode 320x240x256',0,0,0,0,0,0,0,0,0,0,0,0,0,0
MaxX      DW      320
MaxY      DW      240


VGA       DW      0A000H
SAVEBP 	  EQU     WORD PTR CS:[00]
SAVEDS    EQU     WORD PTR CS:[02]
DDI       EQU     WORD PTR CS:[04]
SSI	  EQU	  WORD PTR CS:[06]


SetMode:
	MOV 	AX, 	13h     ; Set MCGA
	INT 	10h

	MOV 	DX, 	03C4h   ; UnChain screen
	MOV 	AX, 	0604h
	OUT 	DX, 	AX

	MOV 	AX, 	0100h
	OUT 	DX, 	AX

	MOV 	DX, 	03C2h
	MOV 	AL, 	0E3h
	OUT 	DX, 	AL

	MOV 	DX, 	03C4h
	MOV 	AX, 	0300h
	OUT 	DX, 	AX

	MOV 	DX, 	03D4h
	MOV 	AL, 	11H
	OUT 	DX, 	AL       ; PORT[$3D4]:= $11

	INC 	DX
	IN  	AL,	DX
	AND	AL,	7FH
	OUT	DX, 	AL       ; PORT[$3D5]:= PORT[$3D4] AND $7F
	DEC	DX
	CLD
	MOV	AX, 	0D06h
	OUT	DX, 	AX       ; PORTW[$3D4]:= $0D06
	MOV	AX, 	3E07h
	OUT	DX, 	AX       ; PORTW[$3D4]:= $3E07
	MOV	AX, 	4109h
	OUT	DX, 	AX       ; PORTW[$3D4]:= $4109
	MOV	AX, 	0EA10h
	OUT	DX, 	AX       ; PORTW[$3D4]:= $EA10
	MOV	AX, 	0AC11h
	OUT	DX, 	AX       ; PORTW[$3D4]:= $AC11
	MOV	AX, 	0DF12h
	OUT	DX, 	AX	 ; PORTW[$3D4]:= $DF12
	MOV	AX, 	0014h
	OUT	DX, 	AX	 ; PORTW[$3D4]:= $0014
	MOV	AX, 	0E715h
	OUT	DX, 	AX	 ; PORTW[$3D4]:= $E715
	MOV	AX, 	0616h
	OUT	DX, 	AX	 ; PORTW[$3D4]:= $0616
	MOV	AX,	0E317h
	OUT	DX,	AX	 ; PORTW[$3D4]:= $E317

	MOV     DX,     03C4H
	MOV     AX,     0F02H
	OUT     DX,     AX       ; PORTW[$3C4]:= $0F02

	MOV	ES, 	CS:VGA	; FILLCHAR(PTR(SEGA000,0)^,$FFFF,0)
	XOR 	DI, 	DI
	MOV 	CX, 	0FFFFh/4
	XOR 	EAX, 	EAX
	REP 	STOSD
	RETF

ClearScreen:
	MOV	SI,	BP	; Save BP in SI
	MOV	BP,	SP
        MOV	BX,	ES      ; Save ES (If called between an object)

        MOV	DX,	03C4H
        MOV	AX,	0F02H	; Selecet all planes
        OUT	DX,	AX

        MOV	AL,	[BP+4]
        MOV	AH,	AL
        MOV     DX,     AX
        SHL	EAX,	16
        MOV     AX,     DX      ; Choose color
	MOV	ES,	CS:VGA
	XOR	DI,	DI	; Start at 0A000:0000
	MOV	CX,	320*240/16
        REP	STOSD

        MOV	ES,	BX	; Restore ES
        MOV	BP,	SI	; Restore BP
	RETF 	2

PutPixel:
        MOV	SI,	BP	; Save BP
	MOV	BP,	SP

        MOV	BX,	[BP+8]
  ; Each address accesses four neighboring pixels, so set
  ; Write Plane Enable according to which pixel we want
  ; to modify.  The plane is determined by the two least
  ; significant bits of the x-coordinate:
	MOV	CX,	BX
	AND	CX,	3
	MOV	AL,	1
	SHL	AX,	CL
	MOV	DX,	03C5H
	OUT	DX,	AL

  ; The offset of the pixel into the video segment is
  ; offset = (width * y + x) / 4, and write the given
  ; color to the plane we selected above.  Heed the active
  ; page start selection.
	MOV	DI,	[BP+6]
	MOV	DX,	DI
	SHL	DI,	6
	SHL	DX,	4
	ADD	DI,	DX	; Y*80

	MOV	AX,	BX	; BX = x
	SHR	AX,	2       ; X/4
	ADD	DI,	AX

	MOV	ES,	CS:VGA
	MOV	AL,	[BP+4]
	MOV	ES:[DI],AL

        MOV	BP,	SI
	RETF	6

GetPixel:
	MOV	SI,	BP      ; Save BP
        MOV	BP,	SP
        MOV	BX,	[BP+6]	; [BP+6] = X

	MOV	AL,	04
	MOV	DX,	03C5H
	OUT	DX,	AL

	MOV	AX,	BX	; BX = x
	ADD	AL,	3
	MOV	DX,	03C5H
	OUT	DX,	AL

	MOV	DI,	[BP+4]	; [BP+4] = Y
	MOV	DX,	DI
	SHL	DI,	6
	SHL	DX,	4
	ADD	DI,	DX	; Y*80

	MOV	AX,	BX	; BX = x
	SHR	AX,	2       ; X/4
	ADD	DI,	AX

	MOV	ES,	CS:VGA
	MOV	AL,	ES:[DI]

	MOV	BP,	SI	; Restore BP
	RETF	4

Box:
	MOV	SAVEBP,	BP
	MOV	BP,	SP

	;Calculate first point offset and store it in DDI
	MOV	ES,	CS:VGA
	MOV	DI,	[BP+10]	; [BP+10] = y
	MOV	DX,	DI
	SHL	DI,	4
	SHL	DX,	6
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
	ADD	DI,	320/4
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

        MOV	DS,	[BP+6]	; LDS	DI, Image
        MOV	SI,	[BP+4]

	;Calculate first point offset and store it in DDI
	MOV	ES,	CS:VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	4
	SHL	DX,	6
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
	MOV	AX,	0102H
	SHL	AH,	CL
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
	ADD	DI,	320/4
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

        MOV	DS,	[BP+6]	; LDS	DI, Image
        MOV	SI,	[BP+4]

	;Calculate first point offsetand store it in DDI
	MOV	ES,	CS:VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	4
	SHL	DX,	6
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
	ADD	DI,	320/4
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
	MOV	ES,	CS:VGA
	MOV	DI,	[BP+12]	; [BP+12] = y
	MOV	DX,	DI
	SHL	DI,	4
	SHL	DX,	6
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
	MOV	AX,	0102H
	SHL	AH,	CL
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
	ADD	DI,	320/4
	ADD	SI,	[BP+10]	; [BP+10] = SizeX
	LOOP	PUTIMAGE2_LOOPY	; End For y

	INC	SSI
	INC	BX
	CMP	BX,	[BP+10]	; [BP+10] = SizeX
	JNE	PUTIMAGE2_LOOPX	; End For x

	MOV	BP,	SAVEBP
	RETF	12

; Procedure HLine( x , y, XLen , Color );
;                  10  8   6       4
HLine:
	MOV	SAVEBP,	BP
	MOV	BP,	SP

	MOV	DI,	[BP+8]	; [BP+8] = y
        MOV	DX,	DI
        SHL	DI,	4
        SHL	DX,	6
        ADD	DI,	DX
        MOV	DDI,	DI

        MOV	BL,	[BP+4]	; [BP+4] = Color
        MOV	ES,	CS:VGA
        MOV	DX,	03C4H
        MOV	SI,	[BP+6]	; [BP+6] = XLen
HLINE_LOOPX:
	MOV 	DI,	SI
        ADD	DI,	[BP+10]	; [BP+10] = x
;       SET PORTS
	MOV	CX,	DI
        AND     CL,	3
        MOV	AX,	0102H
        SHL	AH,	CL
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
	MOV	ES,	CS:VGA
	MOV	DI,	[BP+8]	; [BP+8] = Color
	MOV	DX,	DI
	SHL	DI,	6
	SHL	DX,	4
	ADD	DI,	DX
	MOV	BX,	DI

	;Write to plane
	MOV	CX,	[BP+10]	; [BP+10] = x
	AND	CX,	3
	MOV	AX,	0102H
	SHL	AH,	CL
	MOV	DX,	03C4H
	OUT	DX,	AX

	;Calculate point
	MOV	DI,	BX	; DDI = 160*y
	MOV	AX,	[BP+10]	; [BP+10] = x
	SHR     AX,	2
	ADD	DI,	AX

	;For yy:= 0 to SizeY-1 do
	MOV	AL,	[BP+4]	; [BP+4]  = Color
	MOV	CX,	[BP+6]	; [BP+6] = SizeY
VLINE_LOOPY:
	MOV	ES:[DI],AL
	ADD	DI,	320/4
	LOOP	VLINE_LOOPY	; End For y

        MOV	BP,	SI
        RETF	8

Code    Ends

End Procs
