; -----------------------------------------------------------------
; Include file for MikeOS program development (API version 6)
; -----------------------------------------------------------------

; -----------------------------------------------------------------
; IMPORTANT LOCATIONS

os_main			equ	0x8000	; Jump here to completely restart OS
os_buffer		equ	0xE000	; 8K scratchpad space


; -----------------------------------------------------------------
; SYSTEM CALLS

; Screen control

os_clear_screen		equ	0x8009	; (Nothing used)
os_print_string		equ	0x8003	; SI = zero-terminated string location
os_move_cursor		equ	0x8006	; DH, DL = row, column
os_print_horiz_line	equ	0x800C	; AX = 1 for double line, else single
os_print_newline	equ	0x800F	; (Nothing used)
os_draw_background	equ	0x802A	; AX, BX = strings, CX = colour
os_dialog_box		equ	0x803C	; AX, BX, CX = strings, DX = type
os_file_selector	equ	0x805D	; Returns filename in AX
os_get_cursor_pos	equ	0x806C	; OUT: DH = row, DL = column
os_print_space		equ	0x8072	; (Nothing used)
os_dump_string		equ	0x8075	; SI = string location
os_print_digit		equ	0x8078	; AX = digit to print
os_print_1hex		equ	0x807B	; Display low nibble of AL in hex
os_print_2hex		equ	0x807E	; Display AL in hex
os_print_4hex		equ	0x8081	; Display AX in hex
os_show_cursor		equ	0x8090	; (Nothing used)
os_hide_cursor		equ	0x8093	; (Nothing used)
os_dump_registers	equ	0x8096	; Shows contents of AX, BX, CX, DX


; Keyboard handling

os_wait_for_key		equ	0x8012	; Returns AL = key pressed
os_check_for_key	equ	0x8015	; Returns AL = key pressed


; File handling

os_get_file_list	equ	0x8045	; AX = string to store filenames
os_load_file		equ	0x8021	; AX = filename string location,
					; CX = location to load file

; Sound

os_speaker_tone		equ	0x801B	; AX = note frequency
os_speaker_off		equ	0x801E	; (Nothing used)


; String handling

os_int_to_string	equ	0x8018	; AX = integer, BX = string location
os_string_length	equ	0x802D	; AX = string loc, returns AX = length
os_string_uppercase	equ	0x8030	; SI = zero-terminated string
os_string_lowercase	equ	0x8033	; SI = zero-terminated string
os_input_string		equ	0x8036	; AX = string location
os_string_copy		equ	0x8039	; SI = source, DI = dest strings
os_string_join		equ	0x803F  ; AX, BX = source strings, CX = dest
os_string_compare	equ	0x8048	; SI, DI = strings, carry set if same
os_string_chomp		equ	0x804B	; AX = string location
os_string_strip		equ	0x804E	; SI = string, AX = char to remove
os_string_truncate	equ	0x8051	; SI = string, AX = number of chars
os_set_time_fmt		equ	0x808A	; AL = format (see syscalls.asm)
os_set_date_fmt		equ	0x808D	; AX = format (see syscalls.asm)
os_get_time_string	equ	0x8057	; BX = string location for eg '20:41'
os_get_date_string	equ	0x8060	; BX = string loc for eg '12/31/2007'
os_find_char_in_string	equ	0x8069	; IN: SI = string, AL = char to find
os_long_int_to_string	equ	0x8084	; DX:AX = num, BX = base, DI = string


; Maths routines

os_bcd_to_int		equ	0x8054	; AL = BCD number, returns AX = integer
os_long_int_negate	equ	0x8087	; DX:AX = number


; Serial port

os_send_via_serial	equ	0x8063	; AL = byte to send
os_get_via_serial	equ	0x8066	; Returns AL = byte received
					; OUT: AX = location, or 0 if not found


; Misc OS functions

os_get_api_version	equ	0x805A	; Returns API version in AL
os_get_int_handler	equ	0x806F	; IN: AX = int, OUT: ES:BX = handler loc
os_modify_int_handler	equ	0x8042	; CX = int number, SI = handler loc
os_pause		equ	0x8024	; AX = 18ths of a second to wait
os_fatal_error		equ	0x8027	; AX = error string location


; -----------------------------------------------------------------
; COLOURS

%DEFINE WHITE_ON_LIGHT_RED	11001111b	; Colours for os_dialog_box
%DEFINE RED_ON_LIGHT_GREEN	10100100b


; -----------------------------------------------------------------

