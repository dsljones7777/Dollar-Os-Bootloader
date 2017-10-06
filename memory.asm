USE16
createMemoryMap16:
		xor ax, ax
		mov es, ax
		mov dword [MEM_TOTAL_MAPPINGS_ADDR], 0
		mov di, MEM_MAPADDR
		xor ebx, ebx
		mov edx, 0534D4150h
		mov eax, 0E820h
		mov ecx, 24
	.getMapLoop:
		int 015h
		cmp eax, 0534D4150h
		jne errorOccurred
		inc dword [MEM_TOTAL_MAPPINGS_ADDR]
		test ebx, 0FFFFFFFFh
		jz .doneMapping
		add di, 24
		mov eax, 0E820h
		mov ecx, 24
		jmp .getMapLoop
	.doneMapping:
		ret
USE32
