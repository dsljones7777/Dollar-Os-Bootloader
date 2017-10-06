;Author: David Jones
;This is the bootloader for DollarOs
USE16
ORG 07C00h
STACK_ADDR EQU 0F000h
STACK_SIZE EQU 512
FS_HEADER_ADDR EQU 07E00h
EXBOOT_SEG		EQU 0f00h
entryPoint:
		
		
		;Disable interrupts and set up segment and stack registers
		cli					
		cld
	startAddr:
		xor ax, ax
		mov ss, ax
		mov ds, ax
		mov es, ax
		mov sp, STACK_ADDR
		mov [bootDrive], dl
		
		;Initialize to text (80x25) video mode
		mov ax, 3
		int 010h
		
		;Load the filesystem header
		mov di, loadingFSStr
		call 0:writeString
		mov ax, 0201h
		mov dl,[bootDrive]
		mov cx, 2
		mov bx, FS_HEADER_ADDR
		xor dh, dh
		int 013h
		jc errorlbl
	FSLOADED:
		;Check the filesystem header
		mov di, dollarFsSignature
		mov si, FS_HEADER_ADDR
		mov cx, 8
		repz cmpsb
		jnz errorlbl

		;Check the header CRC
		mov si, FS_HEADER_ADDR
		mov ecx, 2
		xor eax, eax
		call calcCRC32
		add si, 12
		mov ecx, (512 - 12)/4
		call calcCRC32
		cmp eax, [FS_HEADER_ADDR + 8]
		jne errorlbl
		
		;Read the boot file sector
		mov di, loadingBootFileStr
		call 0:writeString
		
		mov eax, [FS_HEADER_ADDR + 12]
		cmp eax, 8
		jne errorlbl
		mov bx, EXBOOT_SEG
		mov es, bx
		
		
		;Calculate the number of loops that will need to be performed (each loop iteration reads 64 sectors)
		mov ecx, [FS_HEADER_ADDR + 16]
		shr ecx, 6
		push eax			;Sector number = sp + 4
		push ecx			;Sector count = sp
		jcxz afterReadLoop
	readLoop:
		;Save count and sector start number
		mov bx, sp
		mov [bx], ecx						
		mov [bx + 4], eax					
		call calcHeaderSectorCylinder
		
		;Read 64 sectors from the drive
		mov dl, [bootDrive]
		xor bx,bx
		mov ax, 0240h
		int 013h
		jc errorlbl
		
		;Adjust the memory address
		mov ax, es
		add ax, 0800h
		mov es, ax
		
		;Adjust the starting sector to read from
		mov bx, sp
		mov eax, [bx + 4]
		add eax, 64
		
		;Loop the number of loop iterations
		mov ecx, [bx]
		loop readLoop
	afterReadLoop:
		;Restore the stack
		add sp, 8
		call calcHeaderSectorCylinder
		
		;Read 64 sectors from the driver
		mov dl, [bootDrive]
		xor bx, bx
		mov eax, [FS_HEADER_ADDR + 16]
		and eax, 0111111b
		jz doneLoading
		or ax, 0200h
		int 013h
		jc errorlbl
	doneLoading:
		xor ax, ax
		mov es, ax
		;Transfer control to the boot file
		mov di, transferringControl
		call 0:writeString
		mov dl, [bootDrive]
		mov si, writeString
		jmp 0F000h
errorlbl:
		mov di, errorStr
		call 0:writeString
		hlt
writeString:	;es:di contains the string
		mov bp, di
		
		;get the row and column number the cursor is in
		mov ah, 3
		xor bh,bh
		int 010h
		
		;Determine the string length
		xor al,al
		or cx, 0FFFFh
		repnz scasb
		not cx
		dec cx
	
		;Display the string and update the cursor
		mov ax, 01301h
		mov bx, 7
		int 010h
		retf
calcCRC32:	;ds:si contains address, cx contains number of 4 byte integers, eax contains the current sum
		xor bx, bx
	calcCRC32Loop:
		add eax,  [bx + si]
		add bx, 4
		dec ecx
		jecxz doneCrc32
		jmp calcCRC32Loop
	doneCrc32:
		ret
calcHeaderSectorCylinder:	;eax contains the linear 512 sector number
		;On return ch is the track cylinder number, cl is the sector number, dh is the head number
		;Calculate Cylinder
		mov ebx, 256 * 63
		xor edx ,edx
		div ebx
		mov ecx, eax
		test ecx, 3FFh
		ja	errorlbl
		shl cx, 8
		shl cl, 6
		
		;Calculate head and sector
		mov eax, edx
		xor edx, edx
		shr ebx, 8
		div ebx
		test ah, 0FFh
		jnz errorlbl
		mov dh, al
		inc dl
		or cl, dl
		ret
vars:
bootDrive		db 0
loadingFSStr	db 'Loading FS',0Ah,0Dh,0
fsLoadedStr		db	'FS was loaded',0Ah,0Dh,0
fsSigOkStr		db 'FS signature is ok',0Ah,0Dh,0
fsCrcOkStr		db	'FS CRC ok',0Ah,0Dh,0
loadingBootFileStr	db 'Loading Boot File',0Ah,0Dh,0
transferringControl db 'Transferring Control',0Ah,0Dh,0
errorStr			db 'ERROR',0
dollarFsSignature db 'DollarFs'