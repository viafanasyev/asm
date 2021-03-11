.model tiny
.code
org 100h

X		equ 40
Y		equ 5
ROWS		equ 25
COLUMNS		equ 80
COLOR		equ 0Fh
SPACE		equ 20h

Start:		mov bx, 0B800h
		mov es, bx
		mov di, (Y * COLUMNS + X) * 2
		
		; cx - direction
		;	 | -+ for up-down
		;	 |	   | -+ for left-right 
		;	 V         V
		mov cx, (COLUMNS + 1) * 2 

LoopInit:	mov si, offset Message

		; print Message
LoopStart:	mov dl, [si]
		mov dh, COLOR
		cmp dl, SPACE	; if ([si] == ' ') color = black
		jne LoopStart2
		xor dh, dh
LoopStart2:	cmp dl, 0
		je  LoopEnd	; if ([si] == 0) goto LoopEnd

		mov es:[di], dx
		inc si
		inc di
		inc di
		jmp LoopStart

LoopEnd:	mov ax, 0100h
		int 16h		; if any key pressed -> exit
		jnz Exit
		
		; sleep for ~FFFFh ms
		mov ax, 0FFFFh
DelayStart:	cmp ax, 0
		je  ClrScr
		dec ax
		jmp DelayStart

		; paint all screen black
ClrScr:		mov dx, di
		xor di, di
ClrScrLoop:	mov es:[di], ax
		cmp di, (ROWS * COLUMNS - 1) * 2
		je  CheckBottom
		inc di
		inc di
		jmp ClrScrLoop

CheckBottom:	mov di, dx
		cmp di, (ROWS * COLUMNS - COLUMNS) * 2
		jge TurnUp

CheckRight:	xor dx, dx
		mov ax, di
		mov bx, 2
		div bx		; di div 2 -> ax = RightColumnNumber + BottomRowNumber * COLUMNS
		xor dx, dx
		mov bx, COLUMNS
		div bx		; di/2 div COLUMNS -> dx = RightColumnNumber
		cmp dx, COLUMNS - 1
		jge TurnLeft

RestoreTopLeft:	sub si, offset Message
		add si, si
		sub di, si

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

CollisionEnd:	add di, cx	
		jmp LoopInit

TurnUp:		sub cx, 4 * COLUMNS ; (COLUMNS +- 1) * 2 -> (-COLUMNS +- 1) * 2
	       	jmp CheckRight
TurnDown:	add cx, 4 * COLUMNS ; (-COLUMNS +- 1) * 2 -> (COLUMNS +- 1) * 2
		jmp CheckLeft
TurnLeft:	sub cx, 4	    ; (+-COLUMNS + 1) * 2 -> (+-COLUMNS - 1) * 2
		jmp RestoreTopLeft
TurnRight:	add cx, 4	    ; (+-COLUMNS - 1) * 2 -> (+-COLUMNS + 1) * 2
		jmp CollisionEnd

Exit:		xor ax, ax
		int 16h		; getch()

		mov ax, 0600h
		mov cx, 0
		mov dx, (ROWS * 100h + COLUMNS)
		mov bx, 0700h
		int 10h		; cls

		mov ax, 4C00h
		int 21h 	; return 0

Message		db "/==========\                                                                    "
		db "|          |                                                                    "
		db "|  Press   |                                                                    "
		db "| any  key |                                                                    "
		db "|    to    |                                                                    "
		db "| continue |                                                                    "
		db "|          |                                                                    "
		db "\==========/", 0

end 		Start