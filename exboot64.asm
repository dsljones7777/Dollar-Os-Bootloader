
PML4_TABLE_ADDRESS 				EQU 01000h
PDPE_TABLE_ADDRESS 				EQU 02000h
PDE_TABLE_ADDRESS 				EQU 03000h
PTE_TABLE_ADDRESS 				EQU 04000h
;Bios Memory Mappings - 127 entries
MEM_MAPADDR  					EQU 05000h
MEM_TOTAL_MAPPINGS_ADDR			EQU 05FE0h	;dword
MEM_TOTAL_MAPPINGS				EQU 127
;Char Map (6000h - 7000h) and VGA Info (7000h - 720Ch)
VGA_CHAR_MAP_ADDR				EQU 06000h	;4KB Map
VGA_BLOCK_INFO_ADDR				EQU 07000h	;256 byte struct
VGA_MODE_INFO_ADDR				EQU 07100h	;256 byte struct
VGA_CURRENT_MODE_ADDR			EQU 07200h	;short
VGA_CHARS_PER_SCAN_LINE_ADDR 	EQU 07204h	;short (describes size of character map char)
VGA_CURSOR_ROW_ADDR				EQU 07208h	;dword
VGA_CURSOR_COLUMN_ADDR			EQU	0720Ch	;dword
VGA_PROTECTED_MODE_ADDR			EQU 07218h  ;dword
VGA_PROTECTED_MODE_SIZE			EQU 0721Ch
;PCI Info (7210h - 7214h)
PCI_VERSION_ADDR 				EQU 07210h	;short
PCI_HW_CHARACTERISTICS_ADDR		EQU	07212h	;byte
PCI_LAST_BUS_ADDR				EQU 07213h	;byte
PCI_IS_VALID					EQU 07214h	;byte


USE16
ORG 00F000h

entryp:
		;Save function addresses and drive info
		mov word [writeString],si
		mov word [writeString + 2], 0
		mov [bootDrive], dl
		;Make sure CPUID exists
		pushfd
		pop eax
		mov ecx, eax
		xor eax, 1 << 21
		push eax
		popfd
		pushfd
		pop eax
		push ecx
		popfd
		xor eax, ecx
		jz X64_NotSupported
		
		;Make sure CPUID 64 bit mode is present
		mov eax, 080000000h
		cpuid
		cmp eax, 080000001h
		jb X64_NotSupported
		mov eax, 080000001h
		cpuid 
		test edx, 1 << 29
		jz X64_NotSupported
		
		;Create a memory map
		mov di, mmapStr
		call far word [writeString]
		call createMemoryMap16
		mov di, doneWithMap
		call far word [writeString]
		
		call queryPCI16
		jnz NOPCI
		mov di, pciSuccess
		call far word [writeString]

		;enable A20 line by BIOS
		mov ax, 02401h
		int 015h
		jc ENABLE_A20_KB
		test ah, 0FFh
		jnz ENABLE_A20_KB
		mov di, a20LineEnabledStr
	AFTER_A20:
		call  far word[writeString]
		call getVgaInfo16
		call getSvgaInfo16
		call getProtectedModeInfo16
		;Display VGA Info
		mov di, detectedSvgaStr
		call far word [writeString]
		les di, [VGA_BLOCK_INFO_ADDR + 6]
		call far word [writeString]
		
		xor ax, ax
		mov es, ax
		mov di, newLineStr
		call far word [writeString]
		mov di, svgaVerStr
		call far word[writeString]
		xor eax, eax
		mov al, [VGA_BLOCK_INFO_ADDR + 5]
		call convertNumberToStr16
		call far word [writeString]
		mov di, periodStr
		call far word [writeString]
		xor eax,eax
		mov al, [VGA_BLOCK_INFO_ADDR + 4]
		call convertNumberToStr16
		call far word [writeString]
		mov di, newLineStr
		call far word [writeString]
		;Create a character mapping
		call createCharMap16
	
		;Set up PML4 table with PML4 Entries
		xor ax, ax
		mov es, ax
		mov dword [PML4_TABLE_ADDRESS], PDPE_TABLE_ADDRESS | 1
		mov dword [PML4_TABLE_ADDRESS + 4], 0
		mov di, PML4_TABLE_ADDRESS + 8
		xor eax, eax
		mov cx, 1022
		rep stosd
		;Set up the PDP table with PDPT Entries
		mov dword [PDPE_TABLE_ADDRESS], PDE_TABLE_ADDRESS | 1	;Set to present and writeable
		mov dword [PDPE_TABLE_ADDRESS + 4], 0
		mov di, PDPE_TABLE_ADDRESS + 8
		xor eax, eax
		mov cx, 1022
		rep stosd
		
		;Set up  the PD table with PTE Entries
		mov dword[PDE_TABLE_ADDRESS], PTE_TABLE_ADDRESS | 1
		mov dword[PDE_TABLE_ADDRESS + 4], 0
		mov di, PDE_TABLE_ADDRESS + 8
		xor eax, eax
		mov cx, 1022
		rep stosd
		
		;Set up the PT entries (First 2MB is mapped without translation)
		mov di, PTE_TABLE_ADDRESS
		mov eax, 3
		mov ecx, 512
		.PAGE_SETUP_LOOP:
			mov dword [di], eax
			mov dword [di + 4], 0
			add eax, 0x1000
			add di, 8
		loop .PAGE_SETUP_LOOP
		
		;Display press any key and wait
		xor ax, ax
		mov es, ax
		mov di, pressKeyStr
		call far word [writeString]
		xor ah,ah
		int 016h
		call switchToDisplayMode16
		
		mov eax, gdtDescriptorSize
		lgdt [eax]
		
		;Switch to 64-bit compatibility mode and paging
		mov eax, cr0
		or eax, 1
		mov cr0, eax
		jmp 08h:After32Switch
	USE32
	After32Switch:
		;Enable PAE
		mov eax, CR4
		or eax, 0100000b
		mov CR4, eax
		
		;Load CR3 with PML4 table address
		mov eax, PML4_TABLE_ADDRESS
		mov cr3, eax
		;Write the model specific registers (IA32_EFER.LME = 1)
		mov ecx, 0C0000080h
		rdmsr
		or eax, 1 << 8
		wrmsr
		mov eax, cr0
		or eax, 080000000h
		mov cr0, eax
		jmp 010h:AfterSwitchTo64
	USE16
	ENABLE_A20_KB:
		mov di, a20LineFailed
		jmp AFTER_A20
	NOPCI:
		mov di, pciFailure
		call far word [writeString]
		hlt
	X64_NotSupported:
		mov di, x64NotSupportedStr
		call far word [writeString]
		hlt
	errorOccurred:
		xor ax, ax
		mov es, ax
		mov di, fatalError
		call far word[writeString]
		hlt
	unsupportedError:
		xor ax, ax
		mov es, ax
		mov di, unsupportedStr
		call far word [writeString]
		hlt
		
writeString 					dd  0
mmapStr 						db 'Creating a Memory Map',0Ah,0Dh,0
doneWithMap 					db 'Done Creating Memory Map: ',0
pciSuccess						db 'PCI information queried',0Ah,0Dh,0
pciFailure						db 'PCI information query failed',0Ah,0Dh,0
a20LineEnabledStr				db 'A20 line has been enabled', 0Ah,0Dh,0
a20LineFailed					db 'Could not enable the A20 line', 0Ah,0Dh,0
impCharTableStr					db 'Imported Character Table',0Ah,0Dh,0
newLine 						db 0Ah , 0Dh, 0
fatalError						db 'A fatal error occurred',0
unsupportedStr     				db 'The operation is not supported',0
detectedSvgaStr					db 'SVGA Adapter: ',0
svgaVerStr						db 'SVGA Version: ',0
pressKeyStr						db 'Press any key to switch to 64-bit mode...',0Ah,0Dh,0
x64NotSupportedStr				db 'X64 is not supported',0Ah,0Dh,0
ALIGN 4
gdtDescriptorSize				dw 31
gdtOffset						dd nullSeg
ALIGN 8
nullSeg:
	dw 0	;Limit (low)
	dw 0	;Base (low)						
	db 0	;Base (mid)
	db 0	;Access
	db 0	;Granularity
	db 0	;Base high
code32Seg:
	dw 0FFFFh
	dw 0
	db 0
	db 010011010b
	db 011001111b	
	db 0
codeSeg:
	dw 0				;Limit (low)
	dw 0				;Base (low)						
	db 0				;Base (mid)
	db 010011010b		;Access
	db 0100000b			;Granularity
	db 0				;Base high
dataSeg:
	dw 0				;Limit (low)
	dw 0				;Base (low)						
	db 0				;Base (mid)
	db 010010010b		;Access
	db 0				;Granularity
	db 0				;Base high
	
	;011001111 010011010
		
bootDrive						db 0						
%include 'memory.asm'
%include 'pci64.asm'
%include 'display.asm'

;This line is replaced by an external program that calculates the entry point to the kernel
CPP_ENTRY_POINT EQU 0000116720 
USE64
AfterSwitchTo64:
	cli
	mov ax, 018h
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov gs, ax
	mov fs, ax
	mov rsp, 00F000h
	call qword CPP_ENTRY_POINT
	cli
	hlt
	mov rsp, 00F000h
	push rcx
	push rdx
	push r8
	push r9
	mov ecx, 0C0000080h
	rdmsr
	and eax, ~(1 << 8)
	wrmsr
USE32
	jmp 08h:SwitchBackTo32
SwitchBackTo32:
	mov eax, cr0
	and eax, 07FFEh
	mov cr0, eax
	jmp 0:SwitchBackto16
USE16
SwitchBackto16:
	mov ax, 0
	mov ss, ax
	mov es, ax
	mov ds, ax
	pop ax
	add sp, 4
	pop bx
	add sp, 4
	pop edx
	add sp, 4
	pop ecx
	add sp, 4
	;Remove the two lines below. Save the two arguments (error code and message).
	;Then switch back to real mode and report the error
	hlt
	xor ebx, ebx
	
	