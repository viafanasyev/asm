.model tiny
.code
org 100h

PORT_B_8255	equ	61h
COMMAND_REG	equ	43h
CHANNEL_2	equ	42h

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

DURATION	equ	5
SEP_DURATION	equ	1000

Start:		in  al, PORT_B_8255
		or  al, 00000011b	; Speaker and timer
		out PORT_B_8255, al

		mov al, 10110110b	; Channel 2 and square-wave rate generator
		out COMMAND_REG, al

		; Play melody
		mov si, offset Melody
MelodyLoop:	mov ax, [si]
		cmp ax, 0
		je  Exit

		; Play single note
		out CHANNEL_2, al
		mov al, ah
		out CHANNEL_2, al

		mov ah, 0
		int 1Ah		; Read system ticks in cx:dx
		mov bx, dx
		add bx, DURATION

StillSound:	int 1Ah
		cmp dx, bx
		jne StillSound

		; Separate notes
		mov al, 0
		out CHANNEL_2, al
		out CHANNEL_2, al
		mov bx, SEP_DURATION
StillSep:	dec bx
		jne StillSep

		inc si
		inc si
		jmp MelodyLoop

		; Turn sound off
Exit:		in  al, PORT_B_8255
		and al, 11111100b
		out PORT_B_8255, al

		mov ax, 4C00h
		int 21h		; return 0

Melody		dw E_2, D_2, FS1, FS2, FS2
		dw E_2, D_2, FS1, FS2, FS2
		dw E_2, D_2, FS1, FS2, DS1, FS2, CS1, F_2, F_2
		
		dw DS2, CS2, CS1, F_2, F_2
		dw DS2, CS2, CS1, F_2, F_2
		dw DS2, CS2, CS1, F_2, DS1, F_2, FS1, FS2, FS2
		
		dw FS1, FS2
		dw DS1, FS2
		dw CS1, F_2, F_2

		dw CS1, F_2
		dw DS1, F_2
		dw FS1, FS2, FS2

		dw FS1, FS2
		dw DS1, FS2
		dw CS1, F_2, F_2

		dw CS1, F_2
		dw DS1, F_2
		dw FS1, FS2, FS2

		dw 0

end		Start