USE16
getVgaInfo16:
		;Get VGA info
		mov ax, 04f00h
		mov di, VGA_BLOCK_INFO_ADDR
		int 010h
		cmp ax, 04fh
		jne errorOccurred
		cmp dword[VGA_BLOCK_INFO_ADDR],'VESA'
		jne errorOccurred
		call checkModes16
		ret
getSvgaInfo16:
		;Get extended SVGA info
		mov ax, 04F01h
		mov cx, 0105h
		mov di, VGA_MODE_INFO_ADDR
		int 010h
		;Make sure an error did not occur
		cmp al, 04Fh
		jne unsupportedError
		test ah, 0FFh
		jnz errorOccurred
		ret
checkModes16:
		mov ecx, 256
		xor dx, dx
		;Search for the highest compatible mode for $OS
		lds si, [VGA_BLOCK_INFO_ADDR + 0eh]
	checkModeLoop16:
		lodsw
		;Check for each mode
		cmp ax, 011bh
		je compatibleModeFound
		cmp ax, 0107h
		je compatibleModeFound
		cmp ax, 0105h
		je compatibleModeFound
		cmp ax, 0103h
		je compatibleModeFound
		cmp ax, 0101h
		je compatibleModeFound
		cmp ax, 0013h
		je compatibleModeFound
		cmp ax, 0012h
		je compatibleModeFound
		cmp ax, 0011h
		je compatibleModeFound
		cmp ax, 0010h
		je compatibleModeFound
		cmp ax, 000fh
		je compatibleModeFound
		cmp ax, 000eh
		je compatibleModeFound
		cmp ax, 000dh
		je compatibleModeFound
		cmp ax, 0
		je checkModeLoop16
		cmp ax, 0007h
		jbe compatibleModeFound
		cmp ax, 0ffffh
		je doneFindingMode
		loop checkModeLoop16
	doneFindingMode:
		xor bx, bx
		mov ds, bx
		test dx, 0FFFFh
		jz errorOccurred
		mov [VGA_CURRENT_MODE_ADDR], dx
		ret
	compatibleModeFound:
		cmp ax, dx
		jle checkModeLoop16
		mov dx, ax
		jmp checkModeLoop16
createCharMap16:
		;Set up default char map
		mov ax, 01124h
		mov bl, 02h
		int 010h
		;Get the char map
		mov ax, 01130h
		mov bh, 01h
		int 010h
		cmp cx, 16
		jne errorOccurred
		mov [VGA_CHARS_PER_SCAN_LINE_ADDR], cx
		and ecx, 0FFFFh
		shl cx, 6
		mov ax, es
		mov ds, ax
		xor ax, ax
		mov es, ax
		mov si, bp
		mov di, VGA_CHAR_MAP_ADDR
		rep movsd
		xor ax, ax
		mov ds, ax
		ret
convertNumberToStr16:	;converts the number in eax to a string
		mov di, endOfConversionBuffer - 1
		mov ebx, 10
	convertLoop:
		xor edx, edx
		div ebx
		or dl, 030h
		mov [di], dl
		dec di
		test eax, 0FFFFFFFFh
		jnz convertLoop
	doneConvert:
		inc di
		ret
switchToDisplayMode16:
		;Switch to a color mode
		xor ax, ax
		mov ds, ax
		mov ax, 04f02h
		mov bx, [VGA_CURRENT_MODE_ADDR]
		;or bx, 1 << 14
		int 010h
		ret
getProtectedModeInfo16:
		mov dword[VGA_PROTECTED_MODE_ADDR], 0
		mov ax, 04f0Ah
		xor bl, bl
		int 010h
		cmp ax, 04fh
		jne .endGetProtected
		mov word[VGA_PROTECTED_MODE_ADDR], di
		mov word[VGA_PROTECTED_MODE_ADDR + 2], es
		mov [VGA_PROTECTED_MODE_SIZE], cx
	.endGetProtected:
		xor ax, ax
		mov es, ax
		ret
USE32
clearScreen:
		;Clear the screen.
		mov dword [VGA_CURSOR_COLUMN_ADDR],0
		mov dword [VGA_CURSOR_ROW_ADDR], 0
		mov ecx, 030000h
		xor eax, eax
		mov edi, dword [VGA_MODE_INFO_ADDR + 028h]
		rep stosd
		ret
convertToHexStr:	;Number in eax is converted to a hex string in 0x format
		mov esi, endOfConversionBuffer - 1
		mov ebx, 16
	convertHexLoop32:
		xor edx, edx
		div ebx
		cmp dl, 9
		ja past9Hex
		or dl, 030h
	storeHexChar:
		mov [esi], dl
		dec esi
		test eax, 0FFFFFFFFh
		jnz convertHexLoop32
		dec esi
		mov ax, '0x'
		mov [esi], ax
		ret
	past9Hex:
		add  dl, 'A' - 10
		jmp storeHexChar
		
writeFormattedNumString: ;edi contains the string to write, eax contains the number to append
		push eax
		call writeString32
		pop eax
		call convertNumberToStr32
		call writeString32
		mov esi, newLineStr
		call writeString32
		ret
		
writeFormattedHexString:
		push eax
		call writeString32
		pop eax
		call convertToHexStr
		call writeString32
		mov esi, newLineStr
		call writeString32
		ret
		
convertNumberToStr32:	;converts the number in eax to a string. esi contains the string returned
		mov esi, endOfConversionBuffer - 1
		mov ebx, 10
	convertLoop32:
		xor edx, edx
		div ebx
		or dl, 030h
		mov [esi], dl
		dec esi
		test eax, 0FFFFFFFFh
		jnz convertLoop32
		inc esi
		ret

writeCharacter:	;edi contains the video memory address 
	USE32
		and eax, 0FFh
		mov esi, VGA_CHAR_MAP_ADDR
		shl eax, 4
		add esi, eax
		mov ecx, 16
		cld
	charLoopWrite:
		lodsb
		test al, 0FFh
		jz postLoopCharWrite
		shl al, 1
		jnc setBit1
		mov byte [edi], 03fh
	setBit1:
		shl al, 1
		jnc setBit2
		mov byte [edi + 1], 03fh
	setBit2:
		shl al, 1
		jnc setBit3
		mov byte [edi + 2], 03fh
	setBit3:
		shl al, 1
		jnc setBit4
		mov byte [edi + 3], 03fh
	setBit4:
		shl al, 1
		jnc setBit5
		mov byte [edi + 4], 03fh
	setBit5:
		shl al, 1
		jnc setBit6
		mov byte [edi + 5], 03fh
	setBit6:
		shl al, 1
		jnc setBit7
		mov byte [edi + 6], 03fh
	setBit7:
		shl al, 1
		jnc postLoopCharWrite
		mov byte [edi + 7], 03fh
	postLoopCharWrite:	
		add edi, 1024
		loop charLoopWrite
		ret
		
writeStringCenter: ;es:esi contains the string to write ; al returns 0 on success
		mov edi , esi
		mov ecx, 0FFFFh
		xor al,al
		repnz scasb
		not cx
		dec cx
		jz writeGStringErr
		
		mov ebx, 128
		sub ebx, ecx
		and ebx, 0FFFEh
		shl ebx, 2
		mov edx, [VGA_CURSOR_ROW_ADDR]
		jmp displayStringCharLoop
		
writeString32: ;es:esi contains the string to write ; al returns 0 on success
		;Get the row and column to write to
		mov ebx, [VGA_CURSOR_COLUMN_ADDR]
writeStringAt:	;es:esi contains the string to write ; ebx contains the column to display in.  al returns 0 on success
		cmp ebx, 128
		jae writeGStringErr
		shl ebx, 3
		mov edx, [VGA_CURSOR_ROW_ADDR]
	displayStringCharLoop:
		lodsb 
		
		test al, 0xFF
		jz doneDisplayingStr
		
		cmp al, 0Ah
		je adjustColumn
		
		cmp al, 0Dh
		je crFound
		
		push esi
		push ebx
		push edx
		
		mov edi, edx
		shl edi, 14
		add edi, ebx
		add edi, dword[VGA_MODE_INFO_ADDR + 028h]
		call writeCharacter
		
		pop edx
		pop ebx
		pop esi
		
		add ebx, 8
	checkColumnOverflow:
		cmp ebx, 1024
		jae adjustColumn
	afterAdjustCol:
		cmp edx, 48
		jae adjustRow
		jmp displayStringCharLoop
	doneDisplayingStr:
		mov [VGA_CURSOR_ROW_ADDR], edx
		shr ebx, 3
		mov [VGA_CURSOR_COLUMN_ADDR], ebx
		xor al,al
		ret
	adjustColumn:
		inc edx
		xor ebx, ebx
		jmp afterAdjustCol
	adjustRow:
		push esi
		mov ecx, 47
		mov edi, dword[VGA_MODE_INFO_ADDR + 028h]
		hlt
		mov esi, edi
		add esi, 16384
		mov ecx, 02F000h
		rep movsd
		mov ecx, 4096
		xor eax, eax
		rep stosd 
		pop esi
		mov edx, 47
		jmp displayStringCharLoop
	writeGStringErr:
		or al, 0FFh
		ret
	crFound:
		xor ebx, ebx
		jmp displayStringCharLoop
		
OS_DISPLAY:

conversionBuffer 				times 11 db 0
endOfConversionBuffer:
								db 0
periodStr						db '.',0
newLineStr						db 0Ah,0Dh,0