.286
.model tiny
.code
org 100h

VIDEO_MEMORY	equ	0A000h
BUFFER		equ	0B000h
COLUMNS		equ	320
ROWS		equ	200
COLORS		equ	256

RND_INIT	equ	0BEEFh
RND_MULT	equ	0DEADh
RND_ADD		equ	0F00Dh
RND_FILT	equ	00EDAh

Start:		mov ax, 0013h
		int 10h		; Set video mode (graphical, 320x200, 256 colors)

		call InitPalette

		mov ax, VIDEO_MEMORY
		mov es, ax
		mov ax, BUFFER
		mov ds, ax

		call SetRandomState

		; Copy current generation from buffer to video memory
GameLoop:	xor si, si
		xor di, di
		mov cx, 08000h
		cld
		rep movsw

		; Compute new generation in buffer
		xor bx, bx
NewGenLoop:	mov ah, [bx]
		call CntNeighbours
		call NewState
		mov [bx], ah
		inc bx
		cmp bx, ROWS * COLUMNS
		jne NewGenLoop

		; Exit, if any key pressed
		mov ax, 0100h
		int 16h
		jnz Exit

		jmp GameLoop

Exit:		xor ax, ax
		int 16h		; getch()
		mov ax, 4C00h
		int 21h		; return 0

;===============================================================================
InitPalette	proc
;-------------------------------------------------------------------------------
; Initializes palette in a following way:
; Values XXXXXXX1 acquire color 1
; Values XXXXXX10 - color 2
; ...
; Value  10000000 - color 8
; Value  00000000 - color 9
;===============================================================================
		push ax bx cx dx di si

		mov di, offset PALETTE

		; Color 0 is set manually to prevent infinite CntZerosLoop
		mov ch, [di+8]
		mov cl, [di+8]
		mov dh, [di+8]
		call SetPaletteColor

		mov bx, COLORS
PaletteLoop:	mov dx, bx
		mov si, di

CntZerosLoop:	mov cx, dx
		and cx, 1
		jne PaletteSet
		inc si
		shr dx, 1
		jmp CntZerosLoop
	
PaletteSet:	mov ch, [si]
		mov cl, [si]
		mov dh, [si]
		call SetPaletteColor
		dec bx
		jne PaletteLoop

		pop si di dx cx bx ax
		ret 0
InitPalette	endp


;===============================================================================
SetRandomState	proc
;-------------------------------------------------------------------------------
; Generates random state for the Game of Life using linear congruential method
;===============================================================================
		push ax bx cx dx di

		mov di, ROWS * COLUMNS

		mov ax, RND_INIT
		mov bx, RND_MULT
		mov cx, RND_ADD

RndLoop:	mul bx		; !Trashes dx
		add ax, cx
		cmp ax, RND_FILT
		jle RndSetDead

RndSetAlive:	mov byte ptr es:[di-1], 1
		jmp RndLoopEnd

RndSetDead:	mov byte ptr es:[di-1], 0

RndLoopEnd:	dec di
		jne RndLoop

		pop di dx cx bx ax
		ret 0
SetRandomState	endp


;===============================================================================
SetPaletteColor	proc
; Registers params:
;		bx = color register to set (0-255)
;		ch = green value (00h - 3Fh)
;		cl = blue value (00h - 3Fh)
;		dh = red value (00h - 3Fh)
;-------------------------------------------------------------------------------
; Sets color for the single color register
;===============================================================================
		push ax

		mov ax, 1010h
		int 10h

		pop ax
		ret 0
SetPaletteColor	endp

;===============================================================================
CntNeighbours	proc
; Registers params:
;		bx = address of the cell (0 - ROWS * COLUMNS - 1)
; Returns:
;		al = number of alive neighbours
;
; ! TRASHES cl
;-------------------------------------------------------------------------------
; Counts number of alive neighbours for the given cell
;===============================================================================
		; Top-left
		mov al, es:[bx - COLUMNS - 1]
		and al, 1

		; Top
		mov cl, es:[bx - COLUMNS]
		and cl, 1
		add al, cl

		; Top-right
		mov cl, es:[bx - COLUMNS + 1]
		and cl, 1
		add al, cl

		; Left
		mov cl, es:[bx - 1]
		and cl, 1
		add al, cl

		; Right
		mov cl, es:[bx + 1]
		and cl, 1
		add al, cl

		; Bottom-left
		mov cl, es:[bx + COLUMNS - 1]
		and cl, 1
		add al, cl

		; Bottom
		mov cl, es:[bx + COLUMNS]
		and cl, 1
		add al, cl

		; Bottom-right
		mov cl, es:[bx + COLUMNS + 1]
		and cl, 1
		add al, cl

		ret 0
CntNeighbours	endp

;===============================================================================
NewState	proc
; Registers params:
;		al = number of alive neighbours
;		ah = current state
; Returns:
;		ah = new state
;
; ! TRASHES cl
;-------------------------------------------------------------------------------
; Calculates new state for the given cell using next algorithm
;   If cell is alive:
;     If number of alive neighbours is equal to 2 or 3 -> set alive
;     Else -> set dead
;   If cell is dead:
;     If number of alive neighbours is equalt 3 -> set alive
;     Else -> set dead
;===============================================================================
		mov cl, ah
		shl ah, 1
		and cl, 1
		jne OldStateAlive

OldStateDead:	cmp al, 3
		jne NewStateEnd
		xor ah, 1
		jmp NewStateEnd

OldStateAlive:	cmp al, 3
		jg  NewStateEnd
		cmp al, 2
		jl  NewStateEnd
		xor ah, 1

NewStateEnd:	ret 0
NewState	endp

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; No trace
PALETTE		db	3Fh, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h

; Smooth trace for 2 generations
;PALETTE		db	3Fh, 1Fh, 00h, 00h, 00h, 00h, 00h, 00h, 00h

; Smooth trace for 3 generations
;PALETTE		db	3Fh, 2Ah, 15h, 00h, 00h, 00h, 00h, 00h, 00h

; VERY Smooth trace for 8 generations
;PALETTE		db	3Fh, 38h, 30h, 28h, 20h, 18h, 10h, 08h, 00h

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

end		Start
