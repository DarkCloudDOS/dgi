	     .386
Code    Segment Para 'Code' use16

Assume  cs:Code
Org 100h

; *****************
; *  File Header  *
; *****************

; Offset of procedures
Procs     DW      SetMode, ClearScreen, PutPixel, GetPixel
          DW      Box, PutImage, GetImage, PutImage2
	  DW      HLine, VLine, 0

; Signature and Driver name
Signature DB      'DGI DRIVER',26
DrvName   DB      'VESA mode 640x480x256',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Screen size for this driver
MaxX      DW      640
MaxY      DW      480


; **************************
; *  Initilized Variables  *
; **************************
VGA       DW      0A000H

; ****************************
; *  UnInitilized Variables  *
; ****************************
SAVEBP 	  DW      ?
SAVEDS    DW      ?
W_VAR1 	  DW      ?
W_VAR2    DW      ?
W_VAR3	  DW      ?
D_VAR     DD      ?

; ***************
; *  Constants  *
; ***************
ThisDriverMode    EQU    0101H			; 640x480x256
NumberOfPlanes	  EQU	 5

; ******************
; *  VESA buffers  *
; ******************
SetBankProcedure  EQU  	 DWORD PTR  CS:[0CH]    ; The procedure for changing banks
BytesPerLine	  EQU    WORD PTR   CS:[10C]	; How much bytes in every line
PlaneNum          EQU    BYTE PTR   CS:[18H]	; Number of memory planes in this mode
BankNum           EQU    BYTE PTR   CS:[1AH]	; Number of banks

; ************
; *  Macros  *
; ************
SET_BANK Macro BANK_NUM

	MOV	DX,	BANK_NUM
	MOV	GS,	DX
	XOR	BX,	BX	; Window a
	CALL	SetBankProcedure; in DL Bank number

	MOV	DX,	GS
	MOV	BX,	1
	CALL	SetBankProcedure; in DL Bank number
ENDM

CALC_FIRST_POINT Macro x, y
;
;  in call: parameters define the x and y locations on screen
;
;  in back: 16 lower bits of EDI = offset
;           16 higher bits of EDI = bank
;

	XOR	EDI,	EDI
        XOR	EDX,	EDX
	MOV	DI,	y
        MOV	DX,	DI

        SHL	EDI,	9	; y*512
        SHL	EDX,	7	; y*128
        ADD	EDI,	EDX	; y*640

        XOR	EDX,	EDX
	MOV	DX,	x
        ADD	EDI,	EDX	; y*640+x
ENDM

REP_MOVS_NO_ZERO Macro
Local NEXT_LOOP, THE_LOOP

;
;  works just like the command: REP MOVSB, but it does not
;  move a byte containing 0.
;
;  in call : DS:SI - Source, where to copy from
;            ES:DI - Destination, where to copy to
;            CX    - count, how musch byte to copy

THE_LOOP:
	MOV	AL,	[SI]
        OR	AL,	AL
        JZ	NEXT_LOOP
	MOV	ES:[DI],AL
NEXT_LOOP:
	INC	SI
        INC	DI
	LOOP	THE_LOOP
ENDM


; ***********************************
; *  Main procedures implementaion  *
; ***********************************

SetMode:
	MOV	AX,	4F01H	; AH = 4F, Call VESA
        			; AL = 01, function 1 get SVGA mode information

	MOV	CX,	ThisDriverMode
   	PUSH	CS
        POP	ES
        XOR	DI,	DI	; ES:DI = points to buffer to store infromation
        INT	10H		; VGA interrupt

	MOV	AX,	4F02H   ; AH = 4F, Call VESA
				; AL = 02, function 2 set SVGA mode
        MOV	BX,	ThisDriverMode	; BX = desired mode
        INT	10H

        PUSH    0040H
        POP     ES
        MOV     BYTE PTR ES:[49H],6h

	RETF


ClearScreen:

Counter	EQU	CS:W_VAR1
AColor	EQU	CS:D_VAR

	MOV	SI,	BP	; Save BP in SI
	MOV	BP,	SP

        MOV	AL,	[BP+4]	; [BP+4] = Color
        MOV	AH,	AL
	MOV	DX,	AX
	SHL	EAX,	16
	MOV	AX,	DX
        MOV	AColor,	EAX	; Fill AColor with a byte

	MOV	ES,	VGA
        XOR	DI,	DI
	MOV	Counter,0
CLEAR_LOOP:
	MOV	AX,	Counter
	SET_BANK Counter
        MOV	EAX,	AColor
        MOV	CX,	4000H  ; Clear it all
        REP	STOSD

	INC	Counter
        CMP	Counter,NumberOfPlanes
        JNE	CLEAR_LOOP

        MOV	BP,	SI	; Restore BP
	RETF 	2

PutPixel:
        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	BP,	SP

	CALC_FIRST_POINT [BP+8], [BP+6]	; [BP+8] = x, [BP+6] = y
	MOV	EDX,	EDI
        SHR	EDX,	16
	SET_BANK DX
        MOV	AL,	[BP+4]
        MOV	ES,	VGA
        MOV	ES:[DI],AL

        MOV	BP,	CS:SAVEBP
	RETF	6

GetPixel:
        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	BP,	SP

	CALC_FIRST_POINT [BP+6], [BP+4]	; [BP+6] = x, [BP+4] = y
	MOV	EDX,	EDI
        SHR	EDX,	16
	SET_BANK DX
        SUB	AH,	AH
        MOV	ES,	VGA
        MOV	AL,	ES:[DI]

        MOV	BP,	CS:SAVEBP
	RETF	4


;
; This "variables" are used by the procedures
;   BOX, PUTIMAGE, GETIMAGE, PUTIMAGE2
;

PLANE   EQU CS:W_VAR1
COUNT   EQU CS:W_VAR2
BOUNDS  EQU CS:W_VAR3


Box:

        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	BP,	SP

        MOV	ES,		VGA
	CALC_FIRST_POINT [BP+12],[BP+10]; [BP+12] = x, [BP+10] = y
	MOV		EDX,		EDI
        SHR		EDX,		16
        MOV		PLANE,	DX
	SET_BANK	PLANE

	MOV	AX,	[BP+6]	; [BP+6] = dy
	MOV	COUNT,	AX	; Counter for the Y loop

	MOV	AX,	[BP+8]	; [BP+8] = dx
        MOV	BOUNDS,	0FFFFH
        SUB	BOUNDS,      AX	; BOX_BOUND = 0FFFFH - dx


BOX_LOOP_Y:
	CMP	DI,	BOUNDS
        JNB	BOX_CHANGE_PLANE

        MOV	AL,	[BP+4]	; [BP+4] = Color
	MOV	CX,	[BP+8]	; [BP+8] = dx
        REP	STOSB

        SUB	DI,	[BP+8]	; [BP+8] = dx
	ADC	DI,	CS:MaxX
        JNC	BOX_1
      	INC	PLANE
	SET_BANK	PLANE
        JMP	BOX_1

BOX_CHANGE_PLANE:
	MOV	CX,	0	; I cant write 10000H...
        SUB	CX,	DI
        MOV	BX,	CX
	MOV	AX,	[BP+8]	; [BP+8] = dx
        SUB	AX,	BX
	PUSH	AX

        MOV	AL,	[BP+4]	; [BP+4] = Color
        REP	STOSB

        INC		PLANE
        SET_BANK	PLANE
        POP		CX
        MOV		AL,	[BP+4]	; [BP+4] = Color
        REP		STOSB

	ADD	DI,	CS:MaxX
        SUB	DI,	[BP+8]	; [BP+8] = dx

BOX_1:	DEC	COUNT
	JNZ	BOX_LOOP_Y

        MOV	BP,	CS:SAVEBP
	RETF	10

PutImage:

        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	CS:SAVEDS,	DS	; Save DS
	MOV	BP,	SP

        MOV		ES,	VGA
	CALC_FIRST_POINT [BP+14],[BP+12]; [BP+14] = x, [BP+12] = y
	MOV		EDX,	EDI
        SHR		EDX,	16      ; ES:DI points to screen
        MOV		PLANE,	DX
	SET_BANK	PLANE          ; Set first bank
  	MOV		DS,	[BP+6]
        MOV		SI,	[BP+4]  ; DS:SI = pic

	MOV		AX,	[BP+8]	; [BP+8] = dy
	MOV		COUNT,	AX	; Counter for the Y loop
	MOV		AX,	[BP+10]	; [BP+10] = dx
        MOV		BOUNDS,	0FFFFH
        SUB		BOUNDS, AX	; BOX_BOUND = 0FFFFH - dx


; Main loop...
IMAGE_LOOP_Y:
	CMP	DI,	BOUNDS
        JNB	IMAGE_CHANGE_PLANE

; If dont need to change the bank in the midle of the line...
	MOV	CX,	[BP+10]	; [BP+10] = dx
        REP	MOVSB

        SUB	DI,	[BP+10]	; [BP+10] = dx
	ADC	DI,	CS:MaxX
        JNC	IMAGE1
      	INC	PLANE
	SET_BANK	PLANE
IMAGE1: DEC	COUNT
	JNZ	IMAGE_LOOP_Y
	JMP	END_PUT_IMAGE

IMAGE_CHANGE_PLANE:
	XOR		CX,	CX
        SUB		CX,	DI
        MOV		BX,	CX
	MOV		AX,	[BP+10]	; [BP+10] = dx
        SUB		AX,	BX
	PUSH		AX
        REP		MOVSB
        INC		PLANE
        SET_BANK	PLANE
        POP		CX
        REP		MOVSB
	ADD	DI,	CS:MaxX
        SUB	DI,	[BP+10]	; [BP+10] = dx

	DEC	COUNT
	JNZ	IMAGE_LOOP_Y

END_PUT_IMAGE:
	MOV	DS,	CS:SAVEDS	; Save DS
        MOV	BP,	CS:SAVEBP
	RETF	12

GetImage:

        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	CS:SAVEDS,	DS	; Save DS
	MOV	BP,	SP

        MOV		ES,	VGA
	CALC_FIRST_POINT [BP+14],[BP+12]; [BP+14] = x, [BP+12] = y
	MOV		EDX,	EDI
        SHR		EDX,	16      ; ES:DI points to screen
        MOV		PLANE,	DX
	SET_BANK	PLANE          ; Set first bank
  	MOV		DS,	[BP+6]
        MOV		SI,	[BP+4]  ; DS:SI = pic

        XCHG		EDI,	ESI
        PUSH		DS
        PUSH		ES		; Now:
        POP		DS		;  destination - ES:DI (Image)
        POP		ES		;  source      - DS:SI (srceen)

	MOV		AX,	[BP+8]	; [BP+8] = dy
	MOV		COUNT,	AX	; Counter for the Y loop
	MOV		AX,	[BP+10]	; [BP+10] = dx
        MOV		BOUNDS,	0FFFFH
        SUB		BOUNDS, AX	; BOX_BOUND = 0FFFFH - dx


; Main loop...
GET_IMAGE_LOOP_Y:
	CMP	SI,	BOUNDS
        JNB	GET_IMAGE_CHANGE_PLANE

; If dont need to change the bank in the midle of the line...
	MOV	CX,	[BP+10]	; [BP+10] = dx
        REP	MOVSB
        SUB	SI,	[BP+10]	; [BP+10] = dx
	ADC	SI,	CS:MaxX
        JNC	GET_IMAGE1
      	INC	PLANE
	SET_BANK	PLANE

GET_IMAGE1:
	DEC	COUNT
	JNZ	GET_IMAGE_LOOP_Y
	JMP	END_GET_IMAGE

GET_IMAGE_CHANGE_PLANE:
	XOR		CX,	CX
        SUB		CX,	SI
        MOV		BX,	CX
	MOV		AX,	[BP+10]	; [BP+10] = dx
        SUB		AX,	BX
	PUSH		AX
        REP		MOVSB
        INC		PLANE
        SET_BANK	PLANE
        POP		CX
        REP		MOVSB
	ADD	SI,	CS:MaxX
        SUB	SI,	[BP+10]	; [BP+10] = dx

	DEC	COUNT
	JNZ	GET_IMAGE_LOOP_Y

END_GET_IMAGE:
	MOV	DS,	CS:SAVEDS	; Save DS
        MOV	BP,	CS:SAVEBP
	RETF	12

PutImage2:
        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	CS:SAVEDS,	DS	; Save DS
	MOV	BP,	SP

        MOV		ES,	VGA
	CALC_FIRST_POINT [BP+14],[BP+12]; [BP+14] = x, [BP+12] = y
	MOV		EDX,	EDI
        SHR		EDX,	16      ; ES:DI points to screen
        MOV		PLANE,	DX
	SET_BANK	PLANE          ; Set first bank
  	MOV		DS,	[BP+6]
        MOV		SI,	[BP+4]  ; DS:SI = pic

	MOV		AX,	[BP+8]	; [BP+8] = dy
	MOV		COUNT,	AX	; Counter for the Y loop
	MOV		AX,	[BP+10]	; [BP+10] = dx
        MOV		BOUNDS,	0FFFFH
        SUB		BOUNDS, AX	; BOX_BOUND = 0FFFFH - dx


; Main loop...
IMAGE2_LOOP_Y:
	CMP	DI,	BOUNDS
        JNB	IMAGE2_CHANGE_PLANE

; If dont need to change the bank in the midle of the line...
	MOV	CX,	[BP+10]	; [BP+10] = dx
        REP_MOVS_NO_ZERO

        SUB	DI,	[BP+10]	; [BP+10] = dx
	ADC	DI,	CS:MaxX
        JNC	IMAGE2
      	INC	PLANE
	SET_BANK	PLANE
IMAGE2: DEC	COUNT
	JNZ	IMAGE2_LOOP_Y
	JMP	END_PUT_IMAGE2

IMAGE2_CHANGE_PLANE:
	XOR		CX,	CX
        SUB		CX,	DI
        MOV		BX,	CX
	MOV		AX,	[BP+10]	; [BP+10] = dx
        SUB		AX,	BX
	PUSH		AX
        REP_MOVS_NO_ZERO

        INC		PLANE
        SET_BANK	PLANE
        POP		CX
        REP_MOVS_NO_ZERO

	ADD	DI,	CS:MaxX
        SUB	DI,	[BP+10]	; [BP+10] = dx

	DEC	COUNT
	JNZ	IMAGE2_LOOP_Y

END_PUT_IMAGE2:
	MOV	DS,	CS:SAVEDS	; Save DS
        MOV	BP,	CS:SAVEBP
	RETF	12

HLine:
        MOV	CS:SAVEBP,	BP	; Save BP
	MOV	BP,	SP

        MOV	ES,		VGA
	CALC_FIRST_POINT [BP+10],[BP+8]; [BP+10] = x, [BP+8] = y
	MOV		EDX,		EDI
        SHR		EDX,		16
        MOV		PLANE,	DX
	SET_BANK	PLANE

	MOV		AX,	[BP+6]	; [BP+6] = dx
        MOV		BOUNDS,	0FFFFH
        SUB		BOUNDS, AX	; BOUNDS = 0FFFFH - dx

	CMP	DI,	BOUNDS
        JNB	HLINE_LOOP2

        MOV	AL,	[BP+4]	; [BP+4] = Color
	MOV	CX,	[BP+6]	; [BP+6] = dx
        REP	STOSB
	JMP	HLINE_END

HLINE_LOOP2:
	XOR	CX,	CX
        SUB	CX,	DI
        MOV	BX,	CX
	MOV	AX,	[BP+6]	; [BP+6] = dx
        SUB	AX,	BX
	PUSH	AX

        MOV	AL,	[BP+4]	; [BP+4] = Color
        REP	STOSB

        INC		PLANE
        SET_BANK	PLANE
        POP		CX
        MOV		AL,	[BP+4]	; [BP+4] = Color
        REP		STOSB

HLINE_END:
        MOV	BP,	CS:SAVEBP
	RETF	8

VLine:
	MOV	CS:SAVEBP,BP
        MOV	BP,	SP

	MOV	ES,	VGA
        CALC_FIRST_POINT [BP+10],[BP+8]	; [BP+8] = x, [BP+10] = y
        MOV	EAX,	EDI
        SHR	EAX,	16
        MOV	PLANE,	AX
        SET_BANK PLANE    		; Plane calculated
        MOV	AL,	[BP+4]		; [BP+4] = Color
        MOV	CX,	[BP+6]		; [BP+6] = SizeY

VLINE_LOOP:
	MOV	ES:[DI],AL
	ADC	DI,	CS:MaxX
        JNC	NEXT_VLINE_LOOP

	INC	PLANE
        SET_BANK PLANE    		; Plane calculated
        MOV	AL,	[BP+4]		; [BP+4] = Color
NEXT_VLINE_LOOP:
	LOOP	VLINE_LOOP

	MOV	BP,	CS:SAVEBP
	RETF	8

Code Ends

End Procs
