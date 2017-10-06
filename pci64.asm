USE16 
queryPCI16:
	;Query pci information
		mov ax, 0B101h
		int 01Ah
		jc .noPCI16
		test ah, 0FFh
		jnz .noPCI16
		cmp edx, 020494350h
		jne .noPCI16
		mov byte[PCI_IS_VALID], 1
		mov [PCI_HW_CHARACTERISTICS_ADDR], al
		mov [PCI_VERSION_ADDR], bx
		mov [PCI_LAST_BUS_ADDR], cl
		xor eax, eax
		ret
	.noPCI16:
		or eax, 0FFFFFFFFh
		ret



