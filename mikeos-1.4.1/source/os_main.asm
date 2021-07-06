; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2008 MikeOS Developers -- see LICENSE.TXT
;
; This is loaded from floppy, by BOOTLOAD.BIN, as MIKEKERN.BIN.
; First section is 32K of empty space for program data (which we
; can load from disk and execute). Then we have the system call
; vectors, which start at a static point for programs to jump to.
; Following that is the main kernel code and system calls.
; =================================================================


	BITS 16

	%DEFINE MIKEOS_VER '1.4.1'
	%DEFINE MIKEOS_API_VER 6


; -----------------------------------------------------------------
; Program data section -- Pad out for app space (DO NOT CHANGE)

os_app_data:
	times 32768-($-$$)	db 0	; 32K of program space


; -----------------------------------------------------------------
; OS call vectors -- Static locations for system calls
; NOTE: THESE CANNOT BE MOVED -- it'll break the calls!
; Comments show exact locations of instructions in this section.

os_call_vectors:
	jmp os_main			; 0x8000 -- Called from bootloader

	jmp os_print_string		; 0x8003

	jmp os_move_cursor		; 0x8006

	jmp os_clear_screen		; 0x8009

	jmp os_print_horiz_line		; 0x800C

	jmp os_print_newline		; 0x800F

	jmp os_wait_for_key		; 0x8012

	jmp os_check_for_key		; 0x8015

	jmp os_int_to_string		; 0x8018

	jmp os_speaker_tone		; 0x801B

	jmp os_speaker_off		; 0x801E

	jmp os_load_file		; 0x8021

	jmp os_pause			; 0x8024

	jmp os_fatal_error		; 0x8027

	jmp os_draw_background		; 0x802A

	jmp os_string_length		; 0x802D

	jmp os_string_uppercase		; 0x8030

	jmp os_string_lowercase		; 0x8033

	jmp os_input_string		; 0x8036

	jmp os_string_copy		; 0x8039

	jmp os_dialog_box		; 0x803C

	jmp os_string_join		; 0x803F

	jmp os_modify_int_handler	; 0x8042

	jmp os_get_file_list		; 0x8045

	jmp os_string_compare		; 0x8048

	jmp os_string_chomp		; 0x804B

	jmp os_string_strip		; 0x804E

	jmp os_string_truncate		; 0x8051

	jmp os_bcd_to_int		; 0x8054

	jmp os_get_time_string		; 0x8057

	jmp os_get_api_version		; 0x805A

	jmp os_file_selector		; 0x805D

	jmp os_get_date_string		; 0x8060

	jmp os_send_via_serial		; 0x8063

	jmp os_get_via_serial		; 0x8066

	jmp os_find_char_in_string	; 0x8069

	jmp os_get_cursor_pos		; 0x806C

	jmp os_get_int_handler		; 0x806F

	jmp os_print_space		; 0x8072

	jmp os_dump_string		; 0x8075

	jmp os_print_digit		; 0x8078

	jmp os_print_1hex		; 0x807B

	jmp os_print_2hex		; 0x807E

	jmp os_print_4hex		; 0x8081

	jmp os_long_int_to_string	; 0x8084

	jmp os_long_int_negate		; 0x8087

	jmp os_set_time_fmt		; 0x808A

	jmp os_set_date_fmt		; 0x808D

	jmp os_show_cursor		; 0x8090

	jmp os_hide_cursor		; 0x8093

	jmp os_dump_registers		; 0x8096


; =================================================================
; START OF MAIN KERNEL CODE

os_main:
	cli				; Clear interrupts
	mov ax, 0
	mov ss, ax			; Set stack segment and pointer
	mov sp, 0xF000
	sti				; Restore interrupts

	cld				; The default direction for string operations
					; will be 'up' - incrementing address

	mov ax, 0x2000
	mov ds, ax			; Set data segments to where we loaded
	mov es, ax

	mov cx, 00h                     ; Divide by 0 error handler
	mov si, os_compat_int00
	call os_modify_int_handler

	mov cx, 20h			; Set up DOS compatibility...
	mov si, os_compat_int20		; ...for interrupts 20h and 21h
	call os_modify_int_handler

	mov cx, 21h
	mov si, os_compat_int21
	call os_modify_int_handler

	mov dx, 0			; Configure serial port 1
	mov al, 11100011b		; 9600 baud, no parity, 8 data bits, 1 stop bit
	mov ah, 0
	int 14h

	mov ax, 03			; Set to normal (80x25 text) video mode
	int 10h

.redraw_select:
	mov ax, 1003h			; For text intensity (no blinking)
	mov bx, 0
	int 10h

	mov ch, 0			; Set cursor to solid block
	mov cl, 7
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	mov ax, os_init_msg		; Set up screen
	mov bx, os_version_msg
	mov cx, 10011111b		; White text on light blue
	call os_draw_background

	mov ax, dialog_string_1		; Ask if user wants app selector or CLI
	mov bx, dialog_string_2
	mov cx, dialog_string_3
	mov dx, 1
	call os_dialog_box

	cmp ax, 1			; If Cancel selected, start CLI
	je .command_line

.more_apps:
	call app_selector		; Otherwise show program menu

	call os_clear_screen		; When program finished, clear screen
	jmp .redraw_select		; and offer command line or menu again


.command_line:
	call os_command_line

	jmp .redraw_select		; Offer menu after exiting from CLI



	os_init_msg		db 'Welcome to MikeOS', 0
	os_version_msg		db 'Version ', MIKEOS_VER, 0

	dialog_string_1		db 'Thanks for trying out MikeOS!', 0
	dialog_string_2		db 'Contact okachi@gmail.com for more info.', 0
	dialog_string_3		db 'OK for program selector, Cancel for CLI.', 0


app_selector:
	mov ax, os_init_msg		; Redraw screen to remove dialog box
	mov bx, os_version_msg
	mov cx, 10011111b
	call os_draw_background

	call os_file_selector		; Get user to select a file, and store
					; the resulting string in AX (other registers are undetermined)

	cmp ax, 0			; No filename selected?
	je .done			; Return to the CLI / menu choice screen

	mov si, ax			; User tried to run MIKEKERN.BIN?
	mov di, kern_file_name
	call os_string_compare
	jc no_kernel_execute


	mov cx, 100h			; Where to load the file (.COM and our .BIN)

	call os_load_file		; Load filename pointed to by AX
	mov bx, 1			; Clear screen before running!
	call os_execute_program		; And execute the code!


	mov dh, 22			; Move below selection block
	mov dl, 0
	call os_move_cursor

	mov si, prog_finished_string	; When finished, print a message
	call os_print_string
	call os_wait_for_key

.done:
	ret				; And go back to the prog list



no_kernel_execute:			; Warning about executing kernel!
	mov ax, os_init_msg		; Redraw screen to remove file selector
	mov bx, os_version_msg
	mov cx, 10011111b
	call os_draw_background

	mov dx, 0			; One button for dialog box
	mov ax, kerndlg_string_1
	mov bx, kerndlg_string_2
	mov cx, kerndlg_string_3
	call os_dialog_box

	jmp app_selector		; Start over again...


	prog_finished_string	db 10, 13, '>>> Program has terminated - press a key', 10, 13, 0

	kern_file_name		db 'MIKEKERNBIN', 0

	kerndlg_string_1	db 'Cannot load and execute MikeOS kernel!', 0
	kerndlg_string_2	db 'MIKEKERN.BIN is the core of MikeOS, and', 0
	kerndlg_string_3	db 'is not a normal program.', 0



; =================================================================
; SYSTEM VARIABLES -- Settings for programs and system calls


	; Time and date formatting

	fmt_12_24 db 0		; Non-zero = 24-hr format

	fmt_date  db 0, '/'	; 0, 1, 2 = M/D/Y, D/M/Y or Y/M/D
				; Bit 7 = use name for months
				; If bit 7 = 0, second byte = separator character


; =================================================================
; SYSTEM CALL SECTION -- Accessible to user programs


        %INCLUDE "syscalls.asm"


; =================================================================
; TEST ZONE -- A place to try out new code without changing the OS


        %INCLUDE "testzone.asm"


; =================================================================
; COMMAND LINE INTERFACE


	%INCLUDE "os_cli.asm"


; =================================================================
; DOS COMPATIBILITY INTERRUPT HANDLERS


	%INCLUDE "os_dos.asm"


; =================================================================
; END OF KERNEL

	times 57344-($-$$)	db 0		; Pad up to 56K

os_buffer:
	times 8192		db 0		; Final 8K is generic buffer


; =================================================================

