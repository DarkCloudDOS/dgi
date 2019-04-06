             .386
Code    Segment Para 'Code' use16

Assume  cs:Code
Org 100h

Procs     DW      SetMode, ClearScreen, PutPixel, GetPixel
          DW      Box, PutImage, GetImage, PutImage2
	  DW	  HLine, VLine, 0
Signature DB      'DGI DRIVER',26
DrvName   DB      'Fast Standard MCGA 320x200x256',0,0,0,0,0,0,0,0,0,0
; Manufacturer DB  60  DUP ('dark-cloud GRPHICS DRIVERS.' )
MaxX      DW      320
MaxY      DW      200

VGA       DW      0A000H

SAVEDS    EQU     CS:[00]
SAVEBP    EQU     CS:[02]


SetMode:
	MOV	AX,	13H
        INT	10H
	RETF

ClearScreen:
;
; ClearScreen( Color: word )
;

	MOV	BX,	BP	; Save BP in DX
	MOV	BP,	SP

        MOV	ES,	VGA
        XOR	DI,	DI
        MOV	CX,	320*200/4
	MOV	AL,	[BP+4]	; First parameter in stack, Color
        			; First a double-word for the return address
        MOV	AH,	AL
        MOV     DX,     AX
        SHL     EAX,    16
        MOV     AX,     DX
        REP	STOSD

        MOV	BP,	BX	; Restore BP
	RETF 	2

PutPixel:
;
; Procedure PutPixel( x: word; y: word; Color: word )
;
;ARG     x: word, y: word, color: word = Return_Addres

;EQU X:WORD =
;EQU Y:WORD  = [BP+6]
;LOCAL COLOR:WORD  = [BP+6]
	MOV	SI,	BP	; Save BP in SI
        MOV	BP,	SP

	MOV	ES,	VGA
        MOV	DI,	[BP+6] ; y*320
        LEA 	DI,	[EDI+EDI*4]
        SHL	DI,	6
        ADD	DI,	[BP+8]	; y*320+x

	MOV	AL,	[BP+4]	; [BP+4]=Color
        MOV	ES:[DI],AL

        MOV	BP,	SI	; Restore BP from SI
	RETF	6

GetPixel:
;
; Function GetPixel( x: word; y: word ): word
;

	MOV	SI,	BP      ; Save BP
        MOV	BP,	SP

	MOV	ES,	VGA
        MOV	DI,	[BP+4] ; y*320
        LEA 	DI,	[EDI+EDI*4]
        SHL	DI,	6
        ADD	DI,	[BP+6]	; y*320+x

	SUB	AH,	AH
        MOV	AL,	ES:[DI]

        MOV	BP,	SI	; Restore BP
	RETF	4

Box:
;
; Procedure Box( x: word; y: word; dx: word; dy: word; Color: word );
;

 	MOV	SAVEBP,	BP	; Save BP
        MOV	BP,	SP

        MOV	ES,	VGA	; Draw to screen
        MOV	DI,	[BP+10]	; First point ofsset 320*y+x
        MOV	DX,	DI
        SHL	DI,	8
        SHL	DX,	6
	ADD	DI,	DX
        ADD	DI,	[BP+12]

        MOV	AL,	[BP+4]
	MOV	BX,     [BP+8]	; BX = width
	MOV	DX,	[BP+6]  ; DX = hiegth
        MOV	SI,	320
        SUB	SI,	BX
FOR_Y:
	MOV	CX,	[BP+8]
	REP     STOSB
	ADD	DI,	SI
	DEC     DX
	JNZ	FOR_Y

        MOV	BP,	SAVEBP	; Restore BP
	RETF	10

PutImage:
;
; Procedure PutImage( x: word; y: word; xlen: word; ylen: word; pic: pointer )
;                      14       12         10         8       SEG:6   OFS:4

	MOV	SAVEDS,	DS	; Need to save DS because MOVSB needs it
	MOV	SAVEBP,	BP	; Save BP in the fisrt word of driver
        MOV	BP,	SP      ; Save ES

  	MOV	DI,	[BP+12]	; First Point
 	MOV	DX,	DI
  	SHL	DI,	8
  	SHL	DX,	6
 	ADD	DI,	DX
  	ADD	DI,	[BP+14]	; 320*y+x
  	MOV	ES,	VGA	; ES:DI = screen

  	MOV  	DX,	MaxX	; How much add to DI every loop?
  	SUB	DX,	[BP+10]

  	MOV	DS,	[BP+6]	; DS:SI = pic
        MOV	SI,	[BP+4]
  	MOV	AX,	[BP+8]	; AX = hiegth

PUT_LOOP:
	MOV	CX,	[BP+10]	; CX = width
	REP	MOVSB
	ADD	DI,	DX
	DEC	AX
  	JNZ     PUT_LOOP

        MOV	DS,	SAVEDS	; Restore DS
	MOV	BP,	SAVEBP	; Restore BP
	RETF	12

GetImage:
;
; Procedure GetImage( x: word; y: word; xlen: word; ylen: word; pic: pointer )
;                      14       12         10         8       SEG:6   OFS:4

	MOV	SAVEDS,	DS	; Need to save DS because MOVSB needs it
	MOV	SAVEBP,	BP	; Save BP in the fisrt word of driver
        MOV	BP,	SP

	MOV	SI,	[BP+12]	; First Point
	MOV	AX,	SI
	SHL	SI,	8
	SHL	AX,	6
	ADD	SI,	AX
	ADD	SI,	[BP+14]
	MOV	DS,	VGA	; DS:SI = screen

	MOV  	DX,	320     ; How much add to DI every loop?
	MOV	BX,	[BP+10] ; 320 - width
	SUB	DX,	BX


	MOV	ES,	[BP+6]	; ES:DI = pic
	MOV	DI,	[BP+4]
	MOV	AX,	[BP+8]	; AX = hiegth

GET_LOOP:
	MOV	CX,	[BP+10]	; CX = width
	REP	MOVSB
	ADD	SI,	DX
	DEC	AX
  	JNZ     GET_LOOP

        MOV	DS,	SAVEDS	; Restore DS
	MOV	BP,	SAVEBP	; Restore BP
	RETF	12

PutImage2:
;
; Procedure PutImage2( x: word; y: word; xlen: word; ylen: word; pic: pointer )
;                      14       12         10         8       SEG:6   OFS:4

	MOV	SAVEDS,	DS	; Need to save DS because MOVSB needs it
	MOV	SAVEBP,	BP	; Save BP in the fisrt word of driver
        MOV	BP,	SP      ;

  	MOV	DI,	[BP+12]	; First Point
  	MOV	AX,	DI
  	SHL	DI,	8
  	SHL	AX,	6
  	ADD	DI,	AX
  	ADD	DI,	[BP+14]
  	MOV	ES,	VGA	; ES:DI = screen

  	MOV  	DX,	320     ; How much add to DI every loop?
	MOV	BX,	[BP+10] ; 320 - width
  	SUB	DX,	BX

  	MOV	DS,	[BP+6]	; DS:SI = pic
        MOV	SI,	[BP+4]
  	MOV	AX,	[BP+8]	; AX = hiegth

PUT_LOOP2:
	MOV	CX,	[BP+10]	; CX = width
LOOP_X:
        MOV     BL,	[SI]
	OR	BL,	BL      ; If zero
        JZ	CONTINUE        ; Ignore it
         			; Else...
        MOV	ES:[DI],BL	; Put it on screen
CONTINUE:
        INC     DI
        INC     SI
        LOOP    LOOP_X
	ADD	DI,	DX
	DEC	AX
  	JNZ     PUT_LOOP2

        MOV	DS,	SAVEDS	; Restore DS
	MOV	BP,	SAVEBP	; Restore BP
	RETF	12

; Procedure HLine ( x , y, XLen , Color );
;                   10   8     6      4
HLINE:
	MOV	SI,	BP	; Save BP
        MOV	BP,	SP

	MOV	ES,	VGA
        MOV	DI,	[BP+8] ; y*320
        LEA 	DI,	[EDI+EDI*4]
        SHL	DI,	6
        ADD	DI,	[BP+10]	; y*320+x
	MOV	AL,	[BP+4]
        MOV	CX,	[BP+6]	; [BP+6] = XLen
        REP	STOSB

        MOV	BP,	SI
        RETF	8

; Procedure VLine( x , y, YLen, Color )
;
VLine:
	MOV	SI,	BP	; SAVE BP
        MOV	BP,	SP

	MOV	ES,	VGA
        MOV	DI,	[BP+8] ; y*320
        LEA 	DI,	[EDI+EDI*4]
        SHL	DI,	6
        ADD	DI,	[BP+10]	; y*320+x
	MOV	AL,	[BP+4]
        MOV	CX,	[BP+6]
VLINE_LOOPY:
	MOV	ES:[DI],AL
        ADD	DI,	MaxX
        LOOP	VLINE_LOOPY

        MOV	BP,	SI
        RETF	8

Code    Ends

End Procs
