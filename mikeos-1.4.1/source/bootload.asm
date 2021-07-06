; =================================================================
; The Mike Operating System bootloader
; Copyright (C) 2006 - 2008 MikeOS Developers -- see LICENSE.TXT
;
; Based on a free boot loader by E Dehling. Scans the FAT12
; floppy for MIKEKERN.BIN (the kernel), loads it and executes it.
; This must stay in 512 bytes, with the final two bytes being the
; boot signature (0xAA55). Assemble with NASM and write to floppy.
;
; =================================================================


	BITS 16

	jmp short bootloader_start    ; Jump past disk description section
	nop                           ; Standard practice


; -----------------------------------------------------------------
; Disk description table, to make it a valid floppy
; Note: some of these values are hard-coded in the source!
; Values are those used by IBM for 1.44 MB, 3.5" diskette

OEMLabel		db "MIKEBOOT"	; Disk label
BytesPerSector		dw 512		; Bytes per sector
SectorsPerCluster	db 1		; Sectors per cluster
ReservedForBoot		dw 1		; Reserved sectors for boot record
NumberOfFats		db 2		; Number of copies of the FAT
RootDirEntries		dw 224		; Number of entries in root dir
					; (224 * 32 = 7168 = 14 sectors to read)
LogicalSectors		dw 2880		; Number of logical sectors
MediumByte		db 0xF0		; Medium descriptor byte
SectorsPerFat		dw 9		; Sectors per FAT
SectorsPerTrack		dw 18		; Sectors per track (36/cylinder)
Sides			dw 2		; Number of sides/heads
HiddenSectors		dd 0		; Number of hidden sectors
LargeSectors		dd 0		; Number of LBA sectors
DriveNo			dw 0		; Drive No: 0
Signature		db 41		; Drive signature: 41 for floppy
VolumeID		dd 0x00000000	; Volume ID: any number
VolumeLabel		db "MIKEOS     "; Volume Label: any 11 chars
FileSystem		db "FAT12   "	; File system type: don't change!


; -----------------------------------------------------------------
; Main bootloader code

bootloader_start:
	mov ax, 0x07C0			; Set up 4K of stack space above buffer
	add ax, 544			; 8k buffer = 512 paragraphs + 32 paragraphs (loader)
	cli				; No interrupts while changing stack
	mov ss, ax
	mov sp, 4096
	sti

	mov ax, 0x07C0			; Set data segment to where we're loaded
	mov ds, ax

	; A few early BIOSes are reported to improperly set DL

	mov byte [bootdev], dl		; Save boot device number

	xor eax, eax			; Needed for some older BIOSes


; Start of root = ReservedForBoot + NumberOfFats * SectorsPerFat = logical 19
; Number of root = RootDirEntries * 32 bytes/entry / 512 bytes/sector = 14
; Start of user data = (start of root) + (number of root) = logical 33

floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call l2hts

	lea si, [buffer]		; Set ES:BX to point to our buffer (for dir)
	mov bx, ds
	mov es, bx
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	pusha                           ; Prepare to enter loop


read_root_dir:
	popa
	pusha

	stc				; A few BIOSes do not set properly on error
	int 13h				; Read sectors

	jnc search_dir
	call reset_floppy		; Reset controller and try again
	jnc read_root_dir		; Floppy reset OK?

	jmp reboot			; Fatal double error


search_dir:
	popa

	mov ax, ds			; Root dir is now in [buffer]
	mov es, ax			; Set DI to this info
	lea di, [buffer]

	mov cx, word [RootDirEntries]	; Search all (224) entries
        xor ax, ax			; Searching at offset 0


next_root_entry:
	xchg cx, dx			; We use CX in the inner loop...

	lea si, [kern_filename]		; Start searching for kernel filename
	mov cx, 11
	rep cmpsb
	je found_file_to_load           ; Pointer DI will be at offset 11

	add ax, 32			; Bump searched entries by 1 (32 bytes/entry)

	lea di, [buffer]		; Point to next entry
	add di, ax

	xchg dx, cx			; Get the original CX back
	loop next_root_entry

	mov si, file_not_found		; If kernel not found, bail out
	call print_string
        jmp reboot


found_file_to_load:			; Fetch cluster and load FAT into RAM
	mov ax, word [es:di+0x0F]       ; Offset 11 + 15 = 26, contains 1st cluster
	mov word [cluster], ax

	mov ax, 1			; Sector 1 = first sector of first FAT
	call l2hts

	lea di, [buffer]		; ES:BX points to our buffer
	mov bx, di

	mov ah, 0x02                    ; int 13h params: read (FAT) sectors
	mov al, 0x09                    ; All 9 sectors of 1st table

	pusha                           ; Prepare to enter loop


read_fat:
	popa				; In case regs altered by int 13h
	pusha

	stc
	int 13h

	jnc read_fat_ok
	call reset_floppy		; Reset controller and try again
	jnc read_fat			; Floppy reset OK?

	mov si, disk_error              ; If not, print error message and reboot
	call print_string
	jmp reboot			; Fatal double error


read_fat_ok:
	popa

	mov ax, 0x2000			; Where we'll load the kernel
	mov es, ax
	xor bx, bx

	mov ah, 0x02			; int 13h floppy read params
	mov al, 0x01

	push ax				; Save in case we (or int calls) lose it


; FAT byte 0 = media descriptor = 0F0h
; FAT byte 1 = filler byte      = 0FFh
; Cluster start = ((cluster number) - 2) * SectorsPerCluster + (start of user)
;               = (cluster number) + 31

load_file_sector:
	mov ax, word [cluster]		; Convert sector to logical
	add ax, 31

	call l2hts			; Make appropriate params for int 13h

	mov ax, 0x2000			; Set buffer past what we've already read
	mov es, ax
	mov bx, word [pointer]

	pop ax				; Save in case we (or int calls) lose it
	push ax

	stc
	int 13h

	jnc calculate_next_cluster	; If there's no error...

	call reset_floppy		; Otherwise, reset floppy and retry
	jmp load_file_sector


calculate_next_cluster:
	mov ax, [cluster]
	xor dx, dx
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [CLUSTER] mod 2
	lea si, [buffer]
	add si, ax			; AX = word in FAT for the 12 bit entry
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0 [CLUSTER] = even, if DX = 1 then odd

	jz even				; If [CLUSTER] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits

odd:
	shr ax, 4			; Shift out first 4 bits (belong to another entry)
	jmp short next_cluster_cont


even:
	and ax, 0x0FFF			; Mask out last 4 bits


next_cluster_cont:
	mov word [cluster], ax		; Store cluster

        cmp ax, 0x0FF8                  ; 0x0FF8 = end of file marker in FAT12
	jae end

	add word [pointer], 512		; Increase buffer pointer 1 sector length
	jmp load_file_sector


end:
	pop ax				; Clear stack
	mov dl, byte [bootdev]		; Provide kernel with boot device info

	jmp 0x2000:0x8000		; Jump to entry point of loaded kernel!
					; Kernel loaded at 0x2000:0x0000, but the
					; first 32K is blank (app space)


; -----------------------------------------------------------------
; Subroutines

reboot:
	xor ax, ax
	int 0x16                        ; Wait for keystroke
	xor ax, ax
	int 0x19                        ; Reboot the system


print_string:				; Output string in SI to screen
	pusha

	mov ah, 0Eh			; int 10h teletype function
                                        ; Some BIOSes may change DX and BP inappropriately

.repeat:
	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string
	int 10h				; Otherwise, print it
	jmp short .repeat

.done:
	popa
	ret


reset_floppy:		; IN: BOOTD = boot device / OUT: CF = set on error
	push ax
	push dx
	xor ax, ax
	mov dl, byte [bootdev]
	stc
	int 13h
	pop dx
	pop ax
	ret


l2hts:			; Calculate head, track and sector settings for int 13h
			; IN: logical sector in AX, OUT: correct registers for int 13h
	push bx
	push ax

	mov bx, ax			; Save logical sector

	xor dx, dx			; First the sector
	div word [SectorsPerTrack]
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	xor dx, dx			; Now calculate the head
	div word [SectorsPerTrack]
	xor dx, dx
	div word [Sides]
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

	mov dl, byte [bootdev]		; Set correct device

	ret


; -----------------------------------------------------------------
; Strings and variables

	kern_filename	db "MIKEKERNBIN"	; MikeOS kernel filename

	disk_error      db "Floppy error! Press any key...", 0
	file_not_found  db "MIKEKERN.BIN not found!", 0

	bootdev		db 0 	; Boot device number
	cluster		dw 0 	; Cluster of the file we want to load
	pointer		dw 0 	; Pointer into Buffer, for loading kernel


; -----------------------------------------------------------------
; Remainder of boot sector

	times 510-($-$$) db 0   ; Pad remainder of MBR sector with 0s
	dw 0xAA55		; Boot signature (DO NOT CHANGE!)


buffer:				; Disk buffer begins (8k after this, stack starts)


; =================================================================

