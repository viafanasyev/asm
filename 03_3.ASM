.model tiny
.code
org 100h

TIMER_INT	equ 8 * 4
KYBD_INT	equ 9 * 4
PORT_B_8255	equ 61h
COMMAND_REG	equ 43h
CHANNEL_2	equ 42h

F11_RELEASE	equ 0D7h
F12_RELEASE	equ 0D8h

ROWS		equ 25
COLUMNS		equ 80
COLOR		equ 0Fh
SPACE		equ 20h
DOT		equ 2Eh
X		equ 0
Y		equ 0

;
; Small octave
;
C__		equ	9121	; ~= 1193180 / 130.82
CS_		equ	8609	; ~= 1193180 / 138.59
D__		equ	8071	; ~= 1193180 / 147.83
DS_		equ	7670	; ~= 1193180 / 155.56
E__		equ	7240	; ~= 1193180 / 164.81
F__		equ	6833	; ~= 1193180 / 174.62
FS_		equ	6450	; ~= 1193180 / 185.00
G__		equ	6088	; ~= 1193180 / 196.00
GS_		equ	5764	; ~= 1193180 / 207.00
A__		equ	5424	; ~= 1193180 / 220.00
AS_		equ	5119	; ~= 1193180 / 233.08
B__		equ	4832	; ~= 1193180 / 246.96

;
; First octave
;
C_1		equ	4561	; ~= 1193180 / 261.63
CS1		equ	4305	; ~= 1193180 / 277.18
D_1		equ	4063	; ~= 1193180 / 293.66
DS1		equ	3835	; ~= 1193180 / 311.13
E_1		equ	3620	; ~= 1193180 / 329.63
F_1		equ	3417	; ~= 1193180 / 349.23
FS1		equ	3225	; ~= 1193180 / 369.99
G_1		equ	3045	; ~= 1193180 / 392.00
GS1		equ	2873	; ~= 1193180 / 415.30
A_1		equ	2712	; ~= 1193180 / 440.00
AS1		equ	2560	; ~= 1193180 / 466.16
B_1		equ	2416	; ~= 1193180 / 493.88

;
; Second octave
;
C_2		equ	2280	; ~= 1193180 / 523.25
CS2		equ	2152	; ~= 1193180 / 554.36
D_2		equ	2032	; ~= 1193180 / 587.32
DS2		equ	1918	; ~= 1193180 / 622.26
E_2		equ	1810	; ~= 1193180 / 659.26
F_2		equ	1708	; ~= 1193180 / 698.46
FS2		equ	1612	; ~= 1193180 / 739.98
G_2		equ	1522	; ~= 1193180 / 784.00
GS2		equ	1437	; ~= 1193180 / 830.60
A_2		equ	1356	; ~= 1193180 / 880.00
AS2		equ	1280	; ~= 1193180 / 932.32
B_2		equ	1208	; ~= 1193180 / 987.75

___		equ	1	; No tone

SEP_DURATION	equ	5489


Start:		xor bx, bx
		mov es, bx

		mov ax, offset NewTimerHandler
		mov bx, TIMER_INT
		mov di, offset OldTimerHandler
		call NewIntHandler

		mov ax, offset NewKybdHandler
		mov bx, KYBD_INT
		mov di, offset OldKybdHandler
		call NewIntHandler

		mov ax, 3100h
		mov dx, offset EndOfProgram
		shr dx, 4
		inc dx
		int 21h		; Stay resident

;===============================================================================
NewIntHandler	proc
; Registers params:
;		es = 0
;		ax = offset of the new handler
;		bx = interruption number * 4 (e.g. 8*4 = timer, 9*4 = keyboard)
;		di = address for saving old interruption handler there
;-------------------------------------------------------------------------------
; Saves old and sets new handler for the given interruption.
;===============================================================================
		push ax
		cli

		; Save old interruption handler
		mov ax, es:[bx]
		mov [di], ax
		mov ax, es:[bx+2]
		mov [di+2], ax

		; Set new interruption handler
		mov ax, cs
		mov es:[bx+2], ax
		pop ax
		mov es:[bx], ax

		sti
		ret 0
NewIntHandler	endp

;===============================================================================
NewTimerHandler	proc
;-------------------------------------------------------------------------------
; Handler for timer interruption 
;   that draws moving frame with values of 
;   registers ax, bx, cx, dx printed in it
;===============================================================================
		push bp di es dx cx bx ax
		mov bp, sp

		mov di, offset FrameVisible
		mov al, cs:[di]
		cmp al, 0
		je  DontDraw 

		mov bp, sp
		mov ax, 0B800h
		mov es, ax
		call DrawFrame

		; Print ax
		mov dl, 'A'
		mov di, ((Y+1) * COLUMNS + (X+9)) * 2
		mov es:[di], dl
		inc di
		inc di
		mov dl, 'X'
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		mov ax, [bp+0]
		call PrintAll

		; Print bx
		mov dl, 'B'
		mov di, ((Y+1) * COLUMNS + (X+27)) * 2
		mov es:[di], dl
		inc di
		inc di
		mov dl, 'X'
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		mov ax, [bp+2]
		call PrintAll

		; Print cx
		mov dl, 'C'
		mov di, ((Y+6) * COLUMNS + (X+9)) * 2
		mov es:[di], dl
		inc di
		inc di
		mov dl, 'X'
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		mov ax, [bp+4]
		call PrintAll

		; Print dx
		mov dl, 'D'
		mov di, ((Y+6) * COLUMNS + (X+27)) * 2
		mov es:[di], dl
		inc di
		inc di
		mov dl, 'X'
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		mov ax, [bp+6]
		call PrintAll

DontDraw:	mov di, offset CurNoteDur
		mov ax, cs:[di]
		cmp ax, 0
		je  ChangeNote
		dec ax
		mov cs:[di], ax
		jmp DontChangeNote
	
ChangeNote:	mov di, offset NextNotePos
		mov ax, cs:[di]
		cmp ax, 0FFFFh
		je  StopPlaying
		call SepNote
		call PlayNextNote
		jmp DontChangeNote

StopPlaying:	call SpeakerOff
DontChangeNote:	pop ax bx cx dx es di bp

		db 0EAh		; jmp far
OldTimerHandler	dd 0

NewTimerHandler	endp

;===============================================================================
NewKybdHandler	proc
;-------------------------------------------------------------------------------
; Handler for keyboard interruption that handles next keys:
;	F11 - play music
;	F12 - show/hide frame with values of registers ax, bx, cx, dx
;===============================================================================
		push ax

		in  al, 60h
		cmp al, F11_RELEASE
		je  HandleMusicKey
		cmp al, F12_RELEASE
		je  HandleFrameKey

		pop ax
		db 0EAh		; jmp far
OldKybdHandler	dd 0

HandleMusicKey:	push si

		; Continue key reading
		in al, 61h
		mov ah, al
		or al, 80h
		out 61h, al
		mov al, ah
		out 61h, al

		call SpeakerOn
		mov si, offset NextNotePos
		xor ax, ax
		mov cs:[si], ax

		pop si
		jmp EndKeyHandle

HandleFrameKey:	push bx di

		; Continue key reading
		in  al, 61h
		mov ah, al
		or  al, 80h
		out 61h, al
		mov al, ah
		out 61h, al

		; Invert frame visibility
		mov di, offset FrameVisible
		mov al, cs:[di]
		xor al, 1
		mov cs:[di], al

		; Clear screen
;		mov ah, 0Fh
;		int 10h		; ! Trashes bx
;		mov ah, 0
;		int 10h

		pop di bx
		jmp EndKeyHandle

		; Send EOI
EndKeyHandle:	mov al, 20h
		out 20h, al

		pop ax
		iret
NewKybdHandler	endp

;===============================================================================
PlayNextNote	proc
;-------------------------------------------------------------------------------
; Plays next note from the melody
;===============================================================================
		push ax bx si di

		mov si, offset NextNotePos
		mov di, cs:[si]
		mov si, offset Melody
		add si, di
		mov ax, cs:[si]
		mov si, offset Duration
		add si, di
		mov bx, cs:[si]

		out CHANNEL_2, al
		mov al, ah
		out CHANNEL_2, al
		mov si, offset CurNoteDur
		mov cs:[si], bx

		; Move to next note
		mov di, offset NextNotePos
		mov ax, cs:[di]
		inc ax
		inc ax
		mov si, offset Melody
		add si, ax
		mov bx, cs:[si]
		cmp bx, 0
		jne NextNoteExists
		mov ax, 0FFFFh
NextNoteExists:	mov cs:[di], ax

		pop di si bx ax
		ret 0
PlayNextNote	endp

;===============================================================================
SepNote		proc
;-------------------------------------------------------------------------------
; Disables speaker for a short time to separate single notes
;===============================================================================
		push ax bx cx dx

		xor al, al
		out CHANNEL_2, al
		out CHANNEL_2, al

;		DOESN'T WORK! WHY?!
;
;		mov ax, 8600h
;		xor cx, cx
;		mov dx, SEP_DURATION
;		int 15h			; Wait

		mov bx, SEP_DURATION
StillSep:	dec bx
		jne StillSep

		pop dx cx bx ax
		ret 0
SepNote		endp

;===============================================================================
SpeakerOn	proc
;-------------------------------------------------------------------------------
; Turn speaker on (8255 PPI)
;===============================================================================
		push ax

		; Prevent playing sound that is left in channel 2
		xor al, al
		out CHANNEL_2, al
		out CHANNEL_2, al

		in  al, PORT_B_8255
		or  al, 00000011b	; Speaker and timer
		out PORT_B_8255, al

		mov al, 10110110b
		out COMMAND_REG, al	; Channel 2 and square-wave rate generator

		pop ax
		ret 0
SpeakerOn	endp

;===============================================================================
SpeakerOff	proc
;-------------------------------------------------------------------------------
; Turn speaker off (8255 PPI)
;===============================================================================
		push ax

		in  al, PORT_B_8255
		and al, 11111100b
		out PORT_B_8255, al

		; Clear channel 2
		xor al, al
		out CHANNEL_2, al
		out CHANNEL_2, al

		pop ax
		ret 0
SpeakerOff	endp

;===============================================================================
PrintAll	proc
; Registers params:
;		ax = value to print
; 		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in hexadecimal, decimal, octal and binary
;   into video memory
; 
; Value is printed like this:
;
; |-- di start position (top-left corner)
; V
; _     FFFFh
; 65535d    177777q
; 1111111111111111b_
;                  ^
;                  |-- di end position (next position after 'b' symbol)
;===============================================================================
		add di, 6 * 2
		call PrintHex

		add di, (COLUMNS - 11) * 2
		call PrintDec

		add di, 4 * 2
		call PrintOct

		add di, (COLUMNS - 17) * 2
		call PrintBin

		ret 0
PrintAll	endp

;===============================================================================
PrintDec	proc
; Registers params:
;		ax = value to print
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in decimal into video memory
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push ax bx cx dx si

		mov bx, 10
		mov cx, 5
		add di, 5 * 2	; Move di to point after last digit
		mov dh, COLOR
		mov dl, 'd'
		mov es:[di], dx

PrintDecLoop:	dec di
		dec di
		xor dx, dx
		div bx		; ax = ax div 10, dx = ax mod 10
		add dx, offset Digits
		mov si, dx
		mov dh, COLOR
		mov dl, cs:[si]
		mov es:[di], dx
		loop PrintDecLoop

		add di, 6 * 2	; Move di to point after 'd' symbol
		pop si dx cx bx ax
		pop bp
		ret 0
PrintDec	endp

;===============================================================================
PrintHex	proc
; Registers params:
;		ax = value to print
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in hexadecimal into video memory
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push dx

		push 0404h
		call PrintByBits
		mov dh, COLOR
		mov dl, 'h'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 0
PrintHex	endp

;===============================================================================
PrintOct	proc
; Registers params:
;		ax = value to print
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in octal into video memory
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push dx

		push 0603h
		call PrintByBits
		mov dh, COLOR
		mov dl, 'q'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 0
PrintOct	endp

;===============================================================================
PrintBin	proc
; Registers params:
;		ax = value to print
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in binary into video memory
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push dx

		push 1001h
		call PrintByBits
		mov dh, COLOR
		mov dl, 'b'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 0
PrintBin	endp

;===============================================================================
PrintByBits     proc
; Stack params:
;		resultLen(byte)
;		maskLen(byte)
; Register params:
;		ax = value to print
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in 2^maskLen number system into video memory
; Parameter resultLen stands for number of decimal places printed
; Example: 
;	resultLen = 6, maskLen = 3, ax = 1050d
;	(Print 1050d in octal using 6 decimal places)
;	Result = 002032
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push ax bx cx dx si

		mov cx, [bp+4]

		; Move di to point after last digit
		mov bx, cx
		and bx, 0FF00h	; bx = 2^8 * resultLen
		shr bx, 7	; bx = 2 * resultLen
		add di, bx	; di += 2 * resultLen
		push di

		mov bx, 1
		shl bx, cl
		dec bx		; bx = 2^maskLen - 1 = maskLen ones

		mov dh, COLOR

PrintBitsLoop:	dec di
		dec di
		mov si, bx
		and si, ax
		add si, offset Digits
		mov dl, cs:[si]
		mov es:[di], dx

		shr ax, cl
		dec ch
		jg  PrintBitsLoop

		; Move di to point after last printed digit
		pop di

		pop si dx cx bx ax
		pop bp
		ret 1+1
PrintByBits	endp

;===============================================================================
DrawFrame	proc
; Register params:
;		es = B800h
;-------------------------------------------------------------------------------
; Moves and draws a frame (see below) by writing it directly into video memory
;===============================================================================
		push bp
		mov bp, sp
		push ax si di

		mov di, (Y * COLUMNS + X) * 2
		mov si, offset Frame

DrawLoop:	mov al, cs:[si]
		cmp al, DOT	; if (symbol == '.') don't draw it
		je  DrawSkip
		mov ah, COLOR
		cmp al, SPACE	; if (symbol == ' ') color = black
		jne DrawNotBlack
		xor ah, ah
DrawNotBlack:	cmp al, 0
		je  DrawEnd	; if ([si] == 0) goto LoopEnd

		mov es:[di], ax
DrawSkip:	inc si
		inc di
		inc di
		jmp DrawLoop

DrawEnd:	pop di si ax
		pop bp
		ret 0

DrawFrame	endp

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; 1, if frame with registers' values should be shown, 0 otherwise
FrameVisible	db 0

; Digits for 2-16 number systems
Digits		db "0123456789ABCDEF"

Frame		db "/-------------------------------------\........................................."
		db "|        AX                BX         |........................................."
		db "|       FFFFh             FFFFh       |........................................."
		db "| 65535d    177777q 65535d    177777q |........................................."
		db "| 1111111111111111b 1111111111111111b |........................................."
		db "|                                     |........................................."
		db "|        CX                DX         |........................................."
		db "|       FFFFh             FFFFh       |........................................."
		db "| 65535d    177777q 65535d    177777q |........................................."
		db "| 1111111111111111b 1111111111111111b |........................................."
		db "\-------------------------------------/", 0

Melody		dw E_1, D_1, FS_, FS1, FS1, E_1, D_1, FS_, FS1, FS1
		dw E_1, D_1, FS_, FS1, DS_, FS1, CS_, F_1, F_1
		dw DS1, CS1, CS_, F_1, F_1, DS1, CS1, CS_, F_1, F_1
		dw DS1, CS1, CS_, F_1, DS_, F_1, FS_, FS1, FS1
		
		dw ___, FS_, FS1, DS_, FS1, CS_, F_1, F_1
		dw ___, CS_, F_1, DS_, F_1, FS_, FS1, FS1
		dw ___, FS_, FS1, DS_, FS1, CS_, F_1, F_1
		dw ___, CS_, F_1, DS_, F_1, FS_, FS1, FS1

		dw 0

		; 4 -> 1/8, 8 -> 1/4
Duration	dw 4, 4, 8, 8, 8, 4, 4, 8, 8, 8
		dw 4, 4, 8, 8, 8, 8, 8, 8, 8
		dw 4, 4, 8, 8, 8, 4, 4, 8, 8, 8
		dw 4, 4, 8, 8, 8, 8, 8, 8, 8

		dw 8, 8, 8, 8, 8, 8, 8, 8
		dw 8, 8, 8, 8, 8, 8, 8, 8
		dw 8, 8, 8, 8, 8, 8, 8, 8
		dw 8, 8, 8, 8, 8, 8, 8, 8

		dw 0

NextNotePos	dw 0FFFFh
CurNoteDur	dw 0

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

EndOfProgram:
end		Start
