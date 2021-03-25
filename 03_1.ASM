.model tiny
.code
org 100h

TIMER_INT	equ 8 * 4
ROWS		equ 25
COLUMNS		equ 80
COLOR		equ 0Fh
SPACE		equ 20h
X		equ 5
Y		equ 5

Start:		xor bx, bx
		mov es, bx
		mov bx, TIMER_INT

		cli

		; Save old interruption handler
		mov ax, es:[bx]
		mov word ptr OldHandler, ax
		mov ax, es:[bx+2]
		mov word ptr OldHandler+2, ax

		; Set new interruption handler
		mov es:[bx], offset NewHandler
		mov ax, cs
		mov es:[bx+2], ax

		sti

		mov ax, 3100h
		mov dx, offset EndOfProgram
		shr dx, 4
		inc dx
		int 21h		; Stay resident

;===============================================================================
NewHandler	proc
;-------------------------------------------------------------------------------
; Handler for timer interruption 
;   that draws moving frame with values of 
;   registers ax, bx, cx, dx printed in it
;===============================================================================
		push ax bx cx dx es si di

		push dx cx bx ax
		mov dx, 0B800h
		mov es, dx

		; Redraw frame every 1/10 of second
		mov ah, 2Ch
		int 21h		; Get Sys Time
		and dx, 00FFh
		mov ax, dx
		mov dl, 10
		div dl
		cmp ah, 0
		jne DontRedraw
		call DrawMoveFrame

DontRedraw:	mov si, offset Position

		; Print ax
		mov dl, 'A'
		mov di, cs:[si]
		add di, (1*COLUMNS + 09) * 2
		mov es:[di], dl
		mov dl, 'X'
		inc di
		inc di
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		call PrintAll

		; Print bx
		mov dl, 'B'
		mov di, cs:[si]
		add di, (1*COLUMNS + 27) * 2
		mov es:[di], dl
		mov dl, 'X'
		inc di
		inc di
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		call PrintAll

		; Print cx
		mov dl, 'C'
		mov di, cs:[si]
		add di, (6*COLUMNS + 09) * 2
		mov es:[di], dl
		mov dl, 'X'
		inc di
		inc di
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		call PrintAll

		; Print dx
		mov dl, 'D'
		mov di, cs:[si]
		add di, (6*COLUMNS + 27) * 2
		mov es:[di], dl
		mov dl, 'X'
		inc di
		inc di
		mov es:[di], dl
		add di, (COLUMNS - 8) * 2
		call PrintAll

		pop di si es dx cx bx ax

		db 0EAh		; jmp far
OldHandler	dd 0

NewHandler	endp

;===============================================================================
PrintAll	proc
; Stack params:
; 		value(word)
; Registers params:
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
		push bp
		mov bp, sp
		push ax

		mov ax, [bp+4]
		push ax ax ax ax
		add di, 6 * 2
		call PrintHex
		add di, (COLUMNS - 11) * 2
		call PrintDec
		add di, 4 * 2
		call PrintOct
		add di, (COLUMNS - 17) * 2
		call PrintBin

		pop ax
		pop bp
		ret 2
PrintAll	endp

;===============================================================================
PrintDec	proc
; Stack params:
;		value(word)
; Registers params:
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

		mov ax, [bp+4]
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
		ret 2
PrintDec	endp

;===============================================================================
PrintHex	proc
; Stack params:
;		value(word)
; Registers params:
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
		push [bp+4]
		call PrintByBits
		mov dh, COLOR
		mov dl, 'h'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 2
PrintHex	endp

;===============================================================================
PrintOct	proc
; Stack params:
;		value(word)
; Registers params:
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
		push [bp+4]
		call PrintByBits
		mov dh, COLOR
		mov dl, 'q'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 2
PrintOct	endp

;===============================================================================
PrintBin	proc
; Stack params:
;		value(word)
; Registers params:
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
		push [bp+4]
		call PrintByBits
		mov dh, COLOR
		mov dl, 'b'
		mov es:[di], dx
		inc di
		inc di

		pop dx
		pop bp
		ret 2
PrintBin	endp

;===============================================================================
PrintByBits     proc
; Stack params:
;		resultLen(byte)
;		maskLen(byte)
;		value(word) 
; Register params:
;		es = B800h
;		di = position to start printing from
;-------------------------------------------------------------------------------
; Prints given value in 2^maskLen number system into video memory
; Parameter resultLen stands for number of decimal places printed
; Example: 
;	resultLen = 6, maskLen = 3, value = 1050d
;	(Print 1050d in octal using 6 decimal places)
;	Result = 002032
;
; Value of di is changed and points after last printed symbol
;===============================================================================
		push bp
		mov bp, sp
		push ax bx cx dx si

		mov cx, [bp+6]
		mov ax, 1
		shl ax, cl
		dec ax		; ax = 2^maskLen - 1 = maskLen ones

		; Move di to point after last digit
		mov bx, cx
		and bx, 0FF00h	; bx = 2^8 * ch
		shr bx, 7	; bx = 2 * ch
		add di, bx	; di += 2 * ch
		push di

		mov bx, [bp+4]
		mov dh, COLOR

PrintBitsLoop:	dec di
		dec di
		mov si, ax
		and si, bx
		add si, offset Digits
		mov dl, cs:[si]
		mov es:[di], dx

		shr bx, cl
		dec ch
		jg  PrintBitsLoop

		; Move di to point after last printed digit
		pop di

		pop si dx cx bx ax
		pop bp
		ret 1+1+2
PrintByBits	endp

;===============================================================================
DrawMoveFrame	proc
; Register params:
;		es = B800h
;-------------------------------------------------------------------------------
; Moves and draws a frame (see below) by writing it directly into video memory
;===============================================================================
		push bp
		mov bp, sp
		push ax bx cx dx si di

		mov si, offset Direction
		mov cx, cs:[si]
		mov si, offset Position
		mov di, cs:[si]
		add di, cx
		mov cs:[si], di

		; Paint all screen black
		xor di, di
		xor ax, ax
ClrScrLoop:	mov es:[di], ax
		cmp di, (ROWS * COLUMNS - 1) * 2
		je DrawStart
		inc di
		inc di
		jmp ClrScrLoop

DrawStart:	mov di, cs:[si]
		mov si, offset Frame

DrawLoop:	mov dl, cs:[si]
		mov dh, COLOR
		cmp dl, SPACE	; if (symbol == ' ') color = black
		jne DrawNotBlack
		xor dh, dh
DrawNotBlack:	cmp dl, 0
		je  CheckBottom	; if ([si] == 0) goto LoopEnd

		mov es:[di], dx
		inc si
		inc di
		inc di
		jmp DrawLoop

CheckBottom:	dec di
		dec di
		cmp di, (ROWS * COLUMNS - COLUMNS) * 2
		jge TurnUp

CheckRight:	xor dx, dx
		mov ax, di
		mov bx, 2
		div bx		; di div 2 -> ax = RightColumnNumber + BottomRowNumber * COLUMNS
		xor dx, dx
		mov bx, COLUMNS
		div bx		; di/2 div COLUMNS -> dx = RightColumnNumber
		cmp dx, COLUMNS	- 1
		jge TurnLeft

RestoreTopLeft:	sub si, offset Frame
		add si, si
		sub di, si
		inc di
		inc di

CheckTop:	cmp di, (COLUMNS - 1) * 2
		jle TurnDown

CheckLeft:	xor dx, dx
		mov ax, di
		mov bx, 2
		div bx		; di div 2 -> ax = LeftColumnNumber + TopRowNumber * COLUMNS
		xor dx, dx
		mov bx, COLUMNS
		div bx		; di/2 mod COLUMNS -> dx = LeftColumnNumber
		cmp dx, 0
		jle TurnRight

CollisionEnd:	mov si, offset Direction
		mov cs:[si], cx

		pop di si dx cx bx ax
		pop bp
		ret 0

TurnUp:		sub cx, 4 * COLUMNS ; (COLUMNS +- 1) * 2 -> (-COLUMNS +- 1) * 2
	       	jmp CheckRight
TurnDown:	add cx, 4 * COLUMNS ; (-COLUMNS +- 1) * 2 -> (COLUMNS +- 1) * 2
		jmp CheckLeft
TurnLeft:	sub cx, 4	    ; (+-COLUMNS + 1) * 2 -> (+-COLUMNS - 1) * 2
		jmp RestoreTopLeft
TurnRight:	add cx, 4	    ; (+-COLUMNS - 1) * 2 -> (+-COLUMNS + 1) * 2
		jmp CollisionEnd

DrawMoveFrame	endp

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Digits for 2-16 number systems
Digits		db "0123456789ABCDEF"

; Direction of current frame movement
;                   | -+ for up-down
;                   |       | -+ for left-right
;                   V       V
Direction	dw (COLUMNS + 1) * 2

; Current position of the top-left corner of the frame
Position	dw (Y * COLUMNS + X) * 2

Frame		db "/_=================_=================_\                                         "
		db "|        AX                BX         |                                         "
		db "|       FFFFh             FFFFh       |                                         "
		db "| 65535d    177777q 65535d    177777q |                                         "
		db "| 1111111111111111b 1111111111111111b |                                         "
		db "|                                     |                                         "
		db "|        CX                DX         |                                         "
		db "|       FFFFh             FFFFh       |                                         "
		db "| 65535d    177777q 65535d    177777q |                                         "
		db "| 1111111111111111b 1111111111111111b |                                         "
		db "\_=================_=================_/", 0

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

EndOfProgram:
end		Start
