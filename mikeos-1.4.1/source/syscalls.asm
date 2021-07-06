; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2008 MikeOS Developers -- see LICENSE.TXT
;
; SYSTEM CALL SECTION -- Accessible to user programs
; =================================================================


; -----------------------------------------------------------------
; os_print_string -- Displays text
; IN: SI = message location (zero-terminated string)
; OUT: Nothing (registers preserved)

os_print_string:
	pusha

	mov ah, 0Eh		; int 10h teletype function
                                ; Some BIOS will change DX and/or BP

.repeat:
	lodsb			; Get char from string
	cmp al, 0
	je .done		; If char is zero, end of string

	int 10h			; Otherwise, print it
	jmp .repeat

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_move_cursor -- Moves cursor in text mode
; IN: DH, DL = row, column; OUT: Nothing (registers preserved)

os_move_cursor:
	pusha

	xor bh, bh
	mov ah, 2
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_get_cursor_pos -- Return position of text cursor
; OUT: DH, DL = row, column

os_get_cursor_pos:
	pusha

	xor bh, bh
	mov ah, 3
	int 10h

	mov [.tmp], dx
	popa
	mov dx, [.tmp]
	ret


	.tmp dw 0


; -----------------------------------------------------------------
; os_show_cursor -- Turns on cursor in text mode
; IN/OUT: Nothing!

os_show_cursor:
	pusha

	mov ch, 0			; Set cursor to solid block
	mov cl, 7
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_hide_cursor -- Turns off cursor in text mode
; IN/OUT: Nothing!

os_hide_cursor:
	pusha

	mov ch, 32
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_draw_block -- Render block of specified colour
; IN: BL/DL/DH/SI/DI = colour/start X pos/start Y pos/width/finish Y pos

os_draw_block:
	pusha

.more:
	call os_move_cursor		; Move to block starting position

	mov ah, 09h			; Draw colour section
	xor bh, bh
	mov cx, si
	mov al, ' '
	int 10h

	inc dh				; Get ready for next line

	xor ax, ax
	mov al, dh			; Get current Y position into DL
	cmp ax, di			; Reached finishing point (DI)?
	jne .more			; If not, keep drawing

	popa
	ret


; -----------------------------------------------------------------
; os_file_selector -- Show a file selection dialog
; IN: Nothing; OUT: AX = location of filename string (or 0 if Esc pressed)

os_file_selector:
	pusha

	call os_hide_cursor

	mov bl, 01001111b		; White on red
	mov dl, 20			; Start X position
	mov dh, 2			; Start Y position
	mov si, 40			; Width
	mov di, 23			; Finish Y position
	call os_draw_block		; Draw file selector window

	mov dl, 21			; Show first line of help text...
	mov dh, 3
	call os_move_cursor
	mov si, .title_string_1
	call os_print_string

	inc dh				; ...and the second
	call os_move_cursor
	mov si, .title_string_2
	call os_print_string

	mov bl, 01110000b		; Black on grey for file list box
	mov dl, 21
	mov dh, 6
	mov si, 38
	mov di, 22
	call os_draw_block

	mov dl, 33			; Get into position for file list text
	mov dh, 7
	call os_move_cursor

	mov ax, .buffer
	call os_get_file_list

	mov si, ax			; SI = location of file list string

	mov word [.filename], 0		; Terminate string in case leave without select
	mov bx, 0			; Counter for total number of files

.next_name:
	mov cx, 0			; Counter for dot in filename

.more:
	lodsb				; get next character in file name, increment pointer

	cmp al, 0			; End of string?
	je .done_list

	cmp al, ','			; Next filename? (String is comma-separated)
	je .newline

	inc cx				; Valid character in name
	cmp cx, 9			; At dot position? (processed first 8 characters)
	jne .print_name
	cmp al, ' '			; No extension?
	je .more

	pusha
	mov al, '.'			; Print dot in filename
	mov ah, 0Eh
	int 10h
	popa

.print_name:
	cmp al, ' '			; Skip spaces
	je .more

	pusha				; Some BIOSes corrupt DX and BP
	mov ah, 0Eh			; Not a space, print it!
	int 10h
	popa
	jmp .more

.newline:
	mov dl, 33			; Go back to starting X position
	inc dh				; But jump down a line
	call os_move_cursor

	inc bx				; Update the number-of-files counter
	cmp bx, 14			; Limit to one page of names
	jl .next_name


.done_list:
	cmp bx, 0			; BX is our number-of-files counter
	jle .leave			; No files to process

	add bl, 7			; Last file -> line number (file 1 on line 7)

	mov dl, 25			; Set up starting position for selector
	mov dh, 7

.more_select:
	call os_move_cursor

	mov si, .position_string	; Show '>>>>>' next to filename
	call os_print_string

.another_key:
	call os_wait_for_key		; Move / select filename
	cmp ah, 48h			; Up pressed?
	je .go_up
	cmp ah, 50h			; Down pressed?
	je .go_down
	cmp al, 13			; Enter pressed?
	je .file_selected
	cmp al, 27			; Esc pressed?
	je .esc_pressed
	jmp .more_select		; If not, wait for another key


.go_up:
	cmp dh, 7			; Already at top?
	jle .another_key

	mov dl, 25
	call os_move_cursor

	mov si, .position_string_blank	; Otherwise overwrite '>>>>>'
	call os_print_string

	dec dh                          ; Row to select (increasing down)
	jmp .more_select


.go_down:				; Already at bottom?
	cmp dh, bl
	jae .another_key

	mov dl, 25
	call os_move_cursor

	mov si, .position_string_blank	; Otherwise overwrite '>>>>>'
	call os_print_string

	inc dh
	jmp .more_select


.file_selected:
	sub dh, 7			; Started printing list at 7 chars
					; down, so remove that to get the
					; starting point of the file list

	mov ax, 12			; Then multiply that by 12 to get position
	mul dh                          ; in file list (filenames are 11 chars
                                        ; plus 1 for comma seperator in the list)

	mov si, .buffer			; Going to put selected filename into
	add si, ax			; The .filename string has appropriate spaces,
	mov cx, 11			; but does not include 0 terminator
	mov di, .filename
	rep movsb
	mov ax, 0
	stosw				; Shouldn't exceed .filename size with terminator

.leave:
	popa

	call os_show_cursor

	mov ax, .filename		; Filename string location in AX

	ret


.esc_pressed:
	popa

	call os_show_cursor

	mov ax, 0

	ret


	.title_string_1	db 'Please select a file and press Enter', 0
	.title_string_2	db 'to choose, or Esc to cancel...', 0

	.position_string_blank	db '     ', 0
	.position_string	db '>>>>>', 0

	.buffer		times 255 db 0
	.filename	times 15 db 0


; -----------------------------------------------------------------
; os_draw_background -- Clear screen with white top and bottom bars,
; containing text, and a coloured middle section.
; IN: AX/BX = top/bottom string locations, CX = colour

os_draw_background:
	pusha

	push ax				; Store params to pop out later
	push bx
	push cx

	call os_clear_screen

	mov ah, 09h			; Draw white bar at top
	xor bh, bh
	mov cx, 80
	mov bl, 01110000b
	mov al, ' '
	int 10h

	mov dh, 1
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw colour section
	mov cx, 1840
	pop bx				; Get colour param (originally in CX)
	xor bh, bh
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at bottom
	xor bh, bh
	mov cx, 80
	mov bl, 01110000b
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 1
	call os_move_cursor
	pop bx				; Get bottom string param
	mov si, bx
	call os_print_string

	mov dh, 0
	mov dl, 1
	call os_move_cursor
	pop ax				; Get top string param
	mov si, ax
	call os_print_string

	mov dh, 1			; Ready for app text
	mov dl, 0
	call os_move_cursor

	popa
	ret


; -----------------------------------------------------------------
; os_clear_screen -- Clears the screen to background
; IN/OUT: Nothing (registers preserved)

os_clear_screen:
	pusha

	mov dx, 0			; Position cursor at top-left
	call os_move_cursor

	mov ah, 6			; Scroll full-screen
	mov al, 0			; Normal white on black
	mov bh, 7			;
	mov cx, 0			; Top-left
	mov dh, 24			; Bottom-right
	mov dl, 79
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_bcd_to_int -- Converts binary coded decimal number to an integer
; IN: AL = BCD number; OUT: AX = integer value

os_bcd_to_int:
	pusha

	mov bl, al			; Store entire number for now

	and ax, 0xF			; Zero-out high bits
	mov cx, ax			; CH/CL = lower BCD number, zero extended

	shr bl, 4			; Move higher BCD number into lower bits, zero fill msb
	mov al, 10
	mul bl				; AX = 10 * BL

	add ax, cx			; Add lower BCD to 10*higher
	mov [.tmp], ax

	popa
	mov ax, [.tmp]			; And return it in AX!
	ret


	.tmp	dw 0


; -----------------------------------------------------------------
; os_send_via_serial -- Send a byte via the serial port
; IN: AL = byte to send via serial; OUT: AH = Bit 7 clear on success

os_send_via_serial:
	pusha

	mov ah, 01h
	mov dx, 0		; COM1, as it's configured by the OS

	int 14h

	mov [.tmp], ax

	popa

	mov ax, [.tmp]

	ret


	.tmp dw 0


; -----------------------------------------------------------------
; os_get_via_serial -- Get a byte from the serial port
; OUT: AL = byte that was received; OUT: AH = Bit 7 clear on success

os_get_via_serial:
	pusha

	mov ah, 02h
	mov dx, 0		; COM1, as it's configured by the OS

	int 14h

	mov [.tmp], ax

	popa

	mov ax, [.tmp]

	ret


	.tmp dw 0


; -----------------------------------------------------------------
; os_set_time_fmt -- Set time reporting format (eg '10:25 AM' or '2300 hours')
; IN: AL = format flag, 0 = 12-hr format

os_set_time_fmt:
	pusha
	cmp al, 0
	je .store
	mov al, 0FFh
.store:
	mov [fmt_12_24], al
	popa
	ret


; -----------------------------------------------------------------
; os_get_time_string -- Get current time in a string (eg '10:25')
; IN/OUT: BX = string location

os_get_time_string:
	pusha

	mov di, bx			; Location to place time string

	clc				; For buggy BIOSes
        mov ah, 0x02			; Get time data from BIOS in BCD format
        int 0x1A
	jnc .read

	clc
        mov ah, 0x02			; BIOS was updating (~1 in 500 chance), so try again
        int 0x1A

.read:
	mov al, ch			; Convert hours to integer for AM/PM test
	call os_bcd_to_int
	mov dx, ax			; Save

        mov al,	ch			; Hour
	shr al, 4			; Tens digit - move higher BCD number into lower bits
	and ch, 0x0F			; Ones digit
	test byte [fmt_12_24], 0FFh
	jz .twelve_hr

	call .add_digit			; BCD already in 24-hour format
	mov al, ch
	call .add_digit
	jmp short .minutes

.twelve_hr:
	cmp dx, 0			; If 00mm, make 12 AM
	je .midnight

	cmp dx, 10			; Before 1000, OK to store 1 digit
	jl .twelve_st1

	cmp dx, 12			; Between 1000 and 1300, OK to store 2 digits
	jle .twelve_st2

	mov ax, dx			; Change from 24 to 12-hour format
	sub ax, 12
	mov bl, 10
	div bl
	mov ch, ah

	cmp al, 0			; 1-9 PM
	je .twelve_st1

	jmp short .twelve_st2		; 10-11 PM

.midnight:
	mov al, 1
	mov ch, 2

.twelve_st2:
	call .add_digit			; Modified BCD, 2-digit hour
.twelve_st1:
	mov al, ch
	call .add_digit

	mov al, ':'			; Time separator (12-hr format)
	stosb

.minutes:
        mov al, cl			; Minute
	shr al, 4			; Tens digit - move higher BCD number into lower bits
	and cl, 0x0F			; Ones digit
	call .add_digit
	mov al, cl
	call .add_digit

	mov al, ' '			; Separate time designation
	stosb

	mov si, .hours_string		; Assume 24-hr format
	test byte [fmt_12_24], 0FFh
	jnz .copy

	mov si, .pm_string		; Assume PM
	cmp dx, 12			; Test for AM/PM
	jg .copy

	mov si, .am_string		; Was actually AM

.copy:
	lodsb				; Copy designation, including terminator
	stosb
	cmp al, 0
	jne .copy

	popa
	ret


.add_digit:
	add al, '0'			; Convert to ASCII
	stosb				; Put into string buffer
	ret


	.hours_string	db 'hours', 0
	.am_string 	db 'AM', 0
	.pm_string 	db 'PM', 0


; -----------------------------------------------------------------
; os_set_date_fmt -- Set date reporting format (M/D/Y, D/M/Y or Y/M/D - 0, 1, 2)
; IN: AX = format flag, 0-2
; If AX bit 7 = 1 = use name for months
; If AX bit 7 = 0, high byte = separator character

os_set_date_fmt:
	pusha
	test al, 0x80		; ASCII months (bit 7)?
	jnz .fmt_clear

	and ax, 0x7F03		; 7-bit ASCII separator and format number
	jmp short .fmt_test

.fmt_clear:
	and ax, 0003		; Ensure separator is clear

.fmt_test:
	cmp al, 3		; Only allow 0, 1 and 2
	jae .leave
	mov [fmt_date], ax

.leave:
	popa
	ret


; -----------------------------------------------------------------
; os_get_date_string -- Get current date in a string (eg '12/31/2007')
; IN/OUT: BX = string location

os_get_date_string:
	pusha

	mov di, bx			; Store string location for now
	mov bx, [fmt_date]		; BL = format code
	and bx, 0x7F03			; BH = separator, 0 = use month names

	clc				; For buggy BIOSes
        mov ah, 0x04			; Get date data from BIOS in BCD format
        int 0x1A
	jnc .read

	clc
        mov ah, 0x04			; BIOS was updating (~1 in 500 chance), so try again
        int 0x1A

.read:
	cmp bl, 2			; YYYY/MM/DD format, suitable for sorting
	jne .try_fmt1

	mov ah, ch			; Always provide 4-digit year
	call .add_2digits
	mov ah, cl
	call .add_2digits		; And '/' as separator
	mov al, '/'
	stosb

	mov ah, dh			; Always 2-digit month
	call .add_2digits
	mov al, '/'			; And '/' as separator
	stosb

	mov ah, dl			; Always 2-digit day
	call .add_2digits
	jmp short .done

.try_fmt1:
	cmp bl, 1			; D/M/Y format (military and Europe)
	jne .do_fmt0

	mov ah, dl			; Day
	call .add_1or2digits

	mov al, bh
	cmp bh, 0
	jne .fmt1_day

	mov al, ' '			; If ASCII months, use space as separator

.fmt1_day:
	stosb				; Day-month separator

	mov ah,	dh			; Month
	cmp bh, 0			; ASCII?
	jne .fmt1_month

	call .add_month			; Yes, add to string
	mov ax, ', '
	stosw
	jmp short .fmt1_century

.fmt1_month:
	call .add_1or2digits		; No, use digits and separator
	mov al, bh
	stosb

.fmt1_century:
	mov ah,	ch			; Century present?
	cmp ah, 0
	je .fmt1_year

	call .add_1or2digits		; Yes, add it to string (most likely 2 digits)

.fmt1_year:
	mov ah, cl			; Year
	call .add_2digits		; At least 2 digits for year, always

	jmp short .done

.do_fmt0:				; Default format, M/D/Y (US and others)
	mov ah,	dh			; Month
	cmp bh, 0			; ASCII?
	jne .fmt0_month

	call .add_month			; Yes, add to string and space
	mov al, ' '
	stosb
	jmp short .fmt0_day

.fmt0_month:
	call .add_1or2digits		; No, use digits and separator
	mov al, bh
	stosb

.fmt0_day:
	mov ah, dl			; Day
	call .add_1or2digits

	mov al, bh
	cmp bh, 0			; ASCII?
	jne .fmt0_day2

	mov al, ','			; Yes, separator = comma space
	stosb
	mov al, ' '

.fmt0_day2:
	stosb

.fmt0_century:
	mov ah,	ch			; Century present?
	cmp ah, 0
	je .fmt0_year

	call .add_1or2digits		; Yes, add it to string (most likely 2 digits)

.fmt0_year:
	mov ah, cl			; Year
	call .add_2digits		; At least 2 digits for year, always


.done:
	mov ax, 0			; Terminate date string
	stosw

	popa
	ret


.add_1or2digits:
	test ah, 0x0F0
	jz .only_one
	call .add_2digits
	jmp short .two_done
.only_one:
	mov al, ah
	and al, 0x0F
	call .add_digit
.two_done:
	ret

.add_2digits:
	mov al, ah			; Convert AH to 2 ASCII digits
	shr al, 4
	call .add_digit
	mov al, ah
	and al, 0x0F
	call .add_digit
	ret

.add_digit:
	add al, '0'			; Convert AL to ASCII
	stosb				; Put into string buffer
	ret

.add_month:
	push bx
	push cx
	mov al, ah			; Convert month to integer to index print table
	call os_bcd_to_int
	dec al				; January = 0
	mov bl, 4			; Multiply month by 4 characters/month
	mul bl
	mov si, .months
	add si, ax
	mov cx, 4
	rep movsb
	cmp byte [di-1], ' '		; May?
	jne .done_month			; Yes, eliminate extra space
	dec di
.done_month:
	pop cx
	pop bx
	ret


	.months db 'Jan.Feb.Mar.Apr.May JuneJulyAug.SeptOct.Nov.Dec.'


; -----------------------------------------------------------------
; os_print_horiz_line -- Draw a horizontal line on the screen
; IN: AX = line type (1 for double, otherwise single)
; OUT: Nothing (registers preserved)

os_print_horiz_line:
	pusha

	mov cx, ax			; Store line type param
	mov al, 196			; Default is single-line code

	cmp cx, 1			; Was double-line specified in AX?
	jne .ready
	mov al, 205			; If so, here's the code

.ready:
	mov cx, 0			; Counter
	mov ah, 0Eh			; BIOS output char routine

.restart:
	int 10h
	inc cx
	cmp cx, 80			; Drawn 80 chars yet?
	je .done
	jmp .restart

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line
; IN/OUT: Nothing (registers preserved)

os_print_newline:
	pusha

	mov ah, 0Eh			; BIOS output char code

	mov al, 13
	int 10h
	mov al, 10
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_wait_for_key -- Waits for keypress and returns key
; IN: Nothing; OUT: AX = key pressed, other regs preserved

os_wait_for_key:
	pusha

	xor ax, ax
	mov ah, 00			; BIOS call to wait for key
	int 16h

	mov [.tmp_buf], ax		; Store resulting keypress

	popa				; But restore all other regs
	mov ax, [.tmp_buf]
	ret


	.tmp_buf	dw 0


; -----------------------------------------------------------------
; os_check_for_key -- Scans keyboard for input, but doesn't wait
; IN: Nothing; OUT: AL = 0 if no key pressed, otherwise ASCII code

os_check_for_key:
	pusha

	xor ax, ax
	mov ah, 01			; BIOS call to check for key
	int 16h

	jz .nokey			; If no key, skip to end

	xor ax, ax			; Otherwise get it from buffer
	mov ah, 00
	int 16h

	mov [.tmp_buf], al		; Store resulting keypress

	popa				; But restore all other regs
	mov al, [.tmp_buf]
	ret

.nokey:
	popa
	mov al, 0			; Zero result if no key pressed
	ret


	.tmp_buf	db 0


; -----------------------------------------------------------------
; os_dump_registers -- Displays register contents in hex on the screen
; IN/OUT: AX/BX/CX/DX = registers to show

os_dump_registers:
	pusha

	call os_print_newline
	push dx
	push cx
	push bx

	mov si, .ax_string
	call os_print_string
	call os_print_4hex

	pop ax
	mov si, .bx_string
	call os_print_string
	call os_print_4hex

	pop ax
	mov si, .cx_string
	call os_print_string
	call os_print_4hex

	pop ax
	mov si, .dx_string
	call os_print_string
	call os_print_4hex

	call os_print_newline

	popa
	ret


	.ax_string		db 'AX:', 0
	.bx_string		db ' BX:', 0
	.cx_string		db ' CX:', 0
	.dx_string		db ' DX:', 0


; -----------------------------------------------------------------
; os_int_to_string -- Convert value in AX to string
; IN: AX = integer, BX = location of string
; OUT: BX = location of converted string (other regs preserved)
;
; NOTE: Based on public domain code

os_int_to_string:
	pusha

	mov di, bx

	mov byte [.zerow], 0x00
	mov word [.varbuff], ax
	xor ax, ax
	xor cx, cx
	xor dx, dx
 	mov bx, 10000
	mov word [.deel], bx

.mainl:
	mov bx, word [.deel]
	mov ax, word [.varbuff]
	xor dx, dx
	xor cx, cx
	div bx
	mov word [.varbuff], dx

.vdisp:
	cmp ax, 0
	je .firstzero
	jmp .ydisp

.firstzero:
	cmp byte [.zerow], 0x00
	je .nodisp

.ydisp:
	add al, 48                              ; Make it numeric (0123456789)
	mov [di], al
	inc di
	mov byte [.zerow], 0x01
	jmp .yydis

.nodisp:
.yydis:
	xor dx, dx
	xor cx, cx
	xor bx, bx
	mov ax, word [.deel]
	cmp ax, 1
	je .bver
	cmp ax, 0
	je .bver
	mov bx, 10
	div bx
	mov word [.deel], ax
	jmp .mainl

.bver:
	mov byte [di], 0

	popa
	ret


	.deel		dw 0x0000
	.varbuff	dw 0x0000
	.zerow		db 0x00


; -----------------------------------------------------------------
; os_speaker_tone -- Generate PC speaker tone (call os_speaker_off after)
; IN: AX = note frequency; OUT: Nothing (registers preserved)

os_speaker_tone:
	pusha

	mov cx, ax		; Store note value for now

	mov al, 182
	out 43h, al
	mov ax, cx		; Set up frequency
	out 42h, al
	mov al, ah
	out 42h, al

	in al, 61h		; Switch PC speaker on
	or al, 03h
	out 61h, al

	popa
	ret


; -----------------------------------------------------------------
; os_speaker_off -- Turn off PC speaker
; IN/OUT: Nothing (registers preserved)

os_speaker_off:
	pusha

	in al, 61h		; Switch PC speaker off
	and al, 0FCh
	out 61h, al

	popa
	ret


; -----------------------------------------------------------------
; os_dialog_box -- Print dialog box in middle of screen, with button(s)
; IN: AX, BX, CX = string locations (set registers to 0 for no display)
; IN: DX = 0 for single 'OK' dialog, 1 for two-button 'OK' and 'Cancel'
; OUT: If two-button mode, AX = 0 for OK and 1 for cancel
; NOTE: Each string is limited to 40 characters

os_dialog_box:
	pusha

	mov [.tmp], dx

	push ax				; Store first string location...
	call os_string_length		; ...because this converts AX to a number
	cmp ax, 40			; Check to see if it's less than 30 chars
	jg .string_too_long

	mov ax, bx			; Check second string length
	call os_string_length
	cmp ax, 40
	jg .string_too_long

	mov ax, cx			; Check third string length
	call os_string_length
	cmp ax, 40
	jg .string_too_long

	pop ax				; Get first string location back
	jmp .strings_ok			; All string lengths OK, so let's move on


.string_too_long:
	pop ax				; We pushed this before
	mov ax, .err_msg_string_length
	call os_fatal_error


.strings_ok:
	call os_hide_cursor

	mov dh, 9			; First, draw red background box
	mov dl, 19

.redbox:				; Loop to draw all lines of box
	call os_move_cursor

	pusha
	mov ah, 09h
	xor bh, bh
	mov cx, 42
	mov bl, 01001111b		; White on red
	mov al, ' '
	int 10h
	popa

	inc dh
	cmp dh, 16
	je .boxdone
	jmp .redbox


.boxdone:
	cmp ax, 0			; Skip string params if zero
	je .no_first_string
	mov dl, 20
	mov dh, 10
	call os_move_cursor

	mov si, ax			; First string
	call os_print_string

.no_first_string:
	cmp bx, 0
	je .no_second_string
	mov dl, 20
	mov dh, 11
	call os_move_cursor

	mov si, bx			; Second string
	call os_print_string

.no_second_string:
	cmp cx, 0
	je .no_third_string
	mov dl, 20
	mov dh, 12
	call os_move_cursor

	mov si, cx			; Third string
	call os_print_string

.no_third_string:
	mov dx, [.tmp]
	cmp dx, 0
	je .one_button
	cmp dx, 1
	je .two_button


.one_button:
	mov dl, 35			; OK button, centered at bottom of box
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	jmp .one_button_wait


.two_button:
	mov dl, 27			; OK button
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_noselect
	call os_print_string

	mov cx, 0			; Default button = 0
	jmp .two_button_wait



.one_button_wait:
	call os_wait_for_key
	cmp al, 13			; Wait for enter key (13) to be pressed
	jne .one_button_wait

	call os_show_cursor

	popa
	ret


.two_button_wait:
	call os_wait_for_key

	cmp ah, 75			; Left cursor key pressed?
	jne .noleft

	mov dl, 27			; If so, change printed buttons
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_noselect
	call os_print_string

	mov cx, 0			; And update result we'll return
	jmp .two_button_wait


.noleft:
	cmp ah, 77			; Right cursor key pressed?
	jne .noright

	mov dl, 27			; If so, change printed buttons
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_noselect
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_string
	call os_print_string

	mov cx, 1			; And update result we'll return
	jmp .two_button_wait


.noright:
	cmp al, 13			; Wait for enter key (13) to be pressed
	jne .two_button_wait

	call os_show_cursor

	mov [.tmp], cx			; Keep result after restoring all regs
	popa
	mov ax, [.tmp]

	ret


	.err_msg_string_length	db 'os_dialog_box: Supplied string too long', 0
	.ok_button_string	db '[= OK =]', 0
	.cancel_button_string	db '[= Cancel =]', 0
	.ok_button_noselect	db '   OK   ', 0
	.cancel_button_noselect	db '   Cancel   ', 0

	.tmp dw 0


; -----------------------------------------------------------------
; os_input_string -- Take string from keyboard entry
; IN/OUT: AX = location of string, other regs preserved
; (Location will contain up to 250 characters and 1-2 terminating 0s)

os_input_string:
	pusha

	mov di, ax		; DI is where we'll store input (buffer)
	mov cx, 0		; Character received counter for backspace


.more:				; Now onto string getting
	call os_wait_for_key

	cmp al, 13		; If Enter key pressed, finish
	je .done

	cmp al, 8		; Backspace pressed?
	je .backspace		; If not, skip following checks

	cmp al, ' '		; In ASCII range (32 - 126)?
	jb .more		; Ignore most nonprinting characters

	cmp al, '~'
	ja .more

	jmp .nobackspace


.backspace:
	cmp cx, 0			; Backspaced at start of line?
	je .more			; Ignore it.

	pusha
	mov ah, 0Eh			; If not, write space and move cursor back
	mov al, 8
	int 10h				; Backspace twice, to clear space
	mov al, 32
	int 10h
	mov al, 8
	int 10h
	popa

	dec di				; Character positon will be overwritten by new
					; character or terminator at end

	dec cx				; Step back counter

	jmp .more


.nobackspace:
	pusha
	mov ah, 0Eh			; Output entered, printable character
	int 10h
	popa

	stosb				; Store character in designated buffer
	inc cx				; Characters processed += 1
	cmp cx, 250			; Make sure we don't exhaust buffer
	jae near .done

	jmp near .more			; Still room for more


.done:
	xor ax, ax			; Ensure string is properly terminated
	stosw

	popa
	ret


; -----------------------------------------------------------------
; os_string_length -- Return length of a string
; IN: AX = string location
; OUT AX = length (other regs preserved)

os_string_length:
	pusha

	mov bx, ax		; Location of string now in BX
	mov cx, 0

.more:
	cmp byte [bx], 0	; Zero (end of string) yet?
	je .done
	inc bx			; If not, keep adding
	inc cx
	jmp .more


.done:
	mov word [.tmp_counter], cx
	popa

	mov ax, [.tmp_counter]
	ret


	.tmp_counter	dw 0


; -----------------------------------------------------------------
; os_find_char_in_string -- Find location of character in a string
; IN: SI = string location, AL = character to find
; OUT: AX = location in string, or 0 if char not present

os_find_char_in_string:
	pusha

	mov cx, 1		; Counter -- start at first char

.more:
	cmp byte [si], al
	je .done
	cmp byte [si], 0
	je .notfound
	inc si
	inc cx
	jmp .more

.done:
	mov [.tmp], cx
	popa
	mov ax, [.tmp]
	ret

.notfound:
	popa
	mov ax, 0
	ret


	.tmp	dw 0


; -----------------------------------------------------------------
; os_string_uppercase -- Convert zero-terminated string to upper case
; IN/OUT: AX = string location

os_string_uppercase:
	pusha

	mov si, ax			; Use SI to access string

.more:
	cmp byte [si], 0		; Zero-termination of string?
	je .done			; If so, quit

	cmp byte [si], 'a'		; In the lower case A to Z range?
	jb .noatoz
	cmp byte [si], 'z'
	ja .noatoz

	sub byte [si], 20h		; If so, convert input char to upper case

	inc si
	jmp .more

.noatoz:
	inc si
	jmp .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_lowercase -- Convert zero-terminated string to lower case
; IN/OUT: AX = string location

os_string_lowercase:
	pusha

	mov si, ax			; Use SI to access string

.more:
	cmp byte [si], 0		; Zero-termination of string?
	je .done			; If so, quit

	cmp byte [si], 'A'		; In the upper case A to Z range?
	jb .noatoz
	cmp byte [si], 'Z'
	ja .noatoz

	add byte [si], 20h		; If so, convert input char to lower case

	inc si
	jmp .more

.noatoz:
	inc si
	jmp .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_copy -- Copy one string into another
; IN/OUT: SI = source, DI = destination (programmer ensure sufficient room)

os_string_copy:
	pusha

.more:
	mov al, [si]		; Transfer contents (at least one byte terminator)
	mov [di], al
	inc si
	inc di
	cmp byte al, 0		; If source string is empty, quit out
	jne .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_truncate -- Chop string down to specified number of characters
; IN: SI = string location, AX = number of characters
; OUT: String modified, registers preserved

os_string_truncate:
	pusha

	add si, ax
	mov byte [si], 0

	popa
	ret


; -----------------------------------------------------------------
; os_string_join -- Join two strings into a third string
; IN/OUT: AX = string one, BX = string two, CX = destination string

os_string_join:
	pusha

	mov si, ax		; Put first string into CX
	mov di, cx
	call os_string_copy

	call os_string_length	; Get length of first string

	add cx, ax		; Position at end of first string

	mov si, bx		; Add second string onto it
	mov di, cx
	call os_string_copy

	popa
	ret


; -----------------------------------------------------------------
; os_string_chomp -- Strip leading and trailing spaces from a string
; IN: AX = string location

os_string_chomp:
	pusha

	mov dx, ax			; Save string location

	mov di, ax			; Put location into DI
	mov cx, 0			; Space counter

.keepcounting:				; Get number of leading spaces into BX
	cmp byte [di], ' '
	jne .counted
	inc cx
	inc di
	jmp .keepcounting

.counted:
	cmp cx, 0			; No leading spaces?
	je .finished_copy

	mov si, di			; Address of first non-space character
	mov di, dx			; DI = original string start

.keep_copying:
	mov al, [si]			; Copy SI into DI
	mov [di], al			; Including terminator
	cmp al, 0
	je .finished_copy
	inc si
	inc di
	jmp .keep_copying

.finished_copy:
	mov ax, dx			; AX = original string start

	call os_string_length
	cmp ax, 0			; If empty or all blank, done, return 'null'
	je .done

	mov si, dx
	add si, ax			; Move to end of string

.more:
	dec si
	cmp byte [si], ' '
	jne .done
	mov byte [si], 0		; Fill end spaces with 0s
	jmp .more			; (First 0 will be the string terminator)

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_strip -- Removes specified character from a string
; IN: SI = string location, AL = character to remove

os_string_strip:
	pusha

	mov dx, si			; Store string location for later

	mov di, os_buffer		; Temporary storage

.more:
	mov bl, [si]

	cmp bl, 0
	je .done

	inc si
	cmp bl, al
	je .more

	mov [di], bl
	inc di
	jmp .more

.done:
	mov bh, bl			; Ensure the output string is terminated
	mov [di], bx

	mov si, os_buffer		; Copy working buffer back to original string
	mov di, dx
	call os_string_copy

	popa
	ret


; -----------------------------------------------------------------
; os_string_compare -- See if two strings match
; IN: SI = string one, DI = string two
; OUT: carry set if same, clear if different

os_string_compare:
	pusha

.more:
	mov al, [si]			; Retrieve string contents
	mov bl, [di]

	cmp al, bl			; Compare characters at current location
	jne .not_same

	cmp al, 0			; End of first string?  Must also be end of second
	je .terminated

	inc si
	inc di
	jmp .more


.not_same:				; If unequal lengths with same beginning, the byte
	popa				; comparison fails at shortest string terminator
	clc				; Clear carry flag
	ret


.terminated:				; Both strings terminated at the same position
	popa
	stc				; Set carry flag
	ret


; -----------------------------------------------------------------
; os_print_space -- Print a space to the screen
; IN/OUT: nothing

os_print_space:
	pusha

	mov ah, 0Eh		; BIOS teletype function
	mov al, 20h		; Space is character 0x20
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_dump_string -- Dump string as hex bytes and printable characters
; IN: SI = points to string to dump

os_dump_string:
	pusha

	mov bx, si		; Save for final print

.line:
	mov di, si		; Save current pointer
	mov cx, 0		; Byte counter

.more_hex:
	lodsb
	cmp al, 0
	je .chr_print

	call os_print_2hex
	call os_print_space	; Single space most bytes
	inc cx

	cmp cx, 8
	jne .q_next_line

	call os_print_space	; Double space center of line
	jmp .more_hex

.q_next_line:
	cmp cx, 16
	jne .more_hex

.chr_print:
	call os_print_space
	mov ah, 0Eh		; BIOS teletype function
	mov al, '|'		; Break between hex and character
	int 10h
	call os_print_space

	mov si, di		; Go back to beginning of this line
	mov cx, 0

.more_chr:
	lodsb
	cmp al, 0
	je .done

	cmp al, ' '
	jae .tst_high

	jmp short .not_printable

.tst_high:
	cmp al, '~'
	jbe .output

.not_printable:
	mov al, '.'

.output:
	mov ah, 0Eh
	int 10h

	inc cx
	cmp cx, 16
	jl .more_chr

	call os_print_newline	; Go to next line
	jmp .line

.done:
	call os_print_newline	; Go to next line

	popa
	ret


; -----------------------------------------------------------------
; os_print_digit -- Displays contents of AX as a single digit
; Works up to base 37, ie digits 0-Z
; IN: AX = "digit" to format and print

os_print_digit:
	pusha

	cmp ax, 9		; There is a break in ASCII table between 9 and A
	jle .digit_format

	add ax, 'A'-'9'-1	; Correct for the skipped punctuation

.digit_format:
	add ax, '0'		; 0 will display as '0', etc.	

	mov ah, 0Eh		; May modify other registers
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_print_1hex -- Displays low nibble of AL in hex format
; IN: AL = number to format and print

os_print_1hex:
	pusha

	and ax, 0Fh		; Mask off data to display
	call os_print_digit

	popa
	ret


; -----------------------------------------------------------------
; os_print_2hex -- Displays AL in hex format
; IN: AL = number to format and print

os_print_2hex:
	pusha

	push ax			; Output high nibble
	shr ax, 4
	call os_print_1hex

	pop ax			; Output low nibble
	call os_print_1hex

	popa
	ret


; -----------------------------------------------------------------
; os_print_4hex -- Displays AX in hex format
; IN: AX = number to format and print

os_print_4hex:
	pusha

	push ax			; Output high byte
	mov al, ah
	call os_print_2hex

	pop ax			; Output low byte
	call os_print_2hex

	popa
	ret


; -----------------------------------------------------------------
; os_long_int_to_string -- Convert value in DX:AX to string
; IN: DX:AX = long unsigned integer, BX = number base, DI = string location
; OUT: DI = location of converted string

os_long_int_to_string:
	pusha

	mov si, di		; Prepare for later data movement

	mov word [di], 0	; Terminate string, creates 'null'

	cmp bx, 37		; Base > 37 or < 0 not supported, return null
	ja .done

	cmp bx, 0		; Base = 0 produces overflow, return null
	je .done

.conversion_loop:
	mov cx, 0		; Zero extend unsigned integer, number = CX:DX:AX
				; If number = 0, goes through loop once and stores '0'

	xchg ax, cx		; Number order DX:AX:CX for high order division
	xchg ax, dx
	div bx			; AX = high quotient, DX = high remainder

	xchg ax, cx		; Number order for low order division
	div bx			; CX = high quotient, AX = low quotient, DX = remainder
	xchg cx, dx		; CX = digit to send

.save_digit:
	cmp cx, 9		; Eliminate punctuation between '9' and 'A'
	jle .convert_digit

	add cx, 'A'-'9'-1

.convert_digit:
	add cx, '0'		; Convert to ASCII

	push ax			; Load this ASCII digit into the beginning of the string
	push bx
	mov ax, si
	call os_string_length	; AX = length of string, less terminator
	mov di, si
	add di, ax		; DI = end of string
	inc ax			; AX = nunber of characters to move, including terminator

.move_string_up:
	mov bl, [di]		; Put digits in correct order
	mov [di+1], bl
	dec di
	dec ax
	jnz .move_string_up

	pop bx
	pop ax
	mov [si], cl		; Last digit (lsd) will print first (on left)

.test_end:
	mov cx, dx		; DX = high word, again
	or cx, ax		; Nothing left?
	jnz .conversion_loop

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_long_int_negate -- Multiply value in DX:AX by -1
; IN: DX:AX = long integer; OUT: DX:AX = -(initial DX:AX)

os_long_int_negate:
	neg ax
	adc dx, 0
	neg dx
	ret


; -----------------------------------------------------------------
; os_pause -- Delay execution for specified microseconds
; IN: CX:DX = number of microseconds to wait

os_pause:
	pusha

	mov ah, 86h
	int 15h

	popa
	ret


; -----------------------------------------------------------------
; os_get_api_version -- Return current version of MikeOS API
; IN: Nothing; OUT: AL = API version number

os_get_api_version:
	mov al, MIKEOS_API_VER
	ret


; -----------------------------------------------------------------
; os_get_int_handler -- Get the segment:offset of an interrupt handler
; IN: AX = int number; OUT: ES:BX = contents of handler location

os_get_int_handler:
	push ax				; A pusha won't allow parameter return
	push cx
	push ds

	and ax, 0FFh			; Ensure number is within range
	mov cl, 4			; Beginning address = base + 4 * number
	mul cl				; Base = 0000, 4 bytes per entry
	mov si, ax

	xor ax, ax			; Interrupt table is in segment 0
	mov ds, ax

	mov bx, [ds:si]			; Get interrupt service address
	mov ax, [ds:si+2]		; Get interrupt service segment
	mov es, ax

	pop ds
	pop cx
	pop ax

	ret


; -----------------------------------------------------------------
; os_modify_int_handler -- Change location of interrupt handler
; IN: CX = int number, SI = handler location

os_modify_int_handler:
	pusha

	cli

	mov dx, es			; Store original ES

	xor ax, ax			; Clear AX for new ES value
	mov es, ax

	mov al, cl			; Move supplied int into AL

	mov bl, 4			; Multiply by four to get position
	mul bl				; (Interrupt table = 4 byte sections)
	mov bx, ax

	mov [es:bx], si			; First store offset
	add bx, 2

	mov ax, 0x2000			; Then segment of our handler
	mov [es:bx], ax

	mov es, dx			; Finally, restore data segment

	sti

	popa
	ret


; -----------------------------------------------------------------
; os_fatal_error -- Display error message, take keypress, and restart OS
; IN: AX = error message string location

os_fatal_error:
	mov bx, ax			; Store string location for now

	mov dh, 0
	mov dl, 0
	call os_move_cursor

	pusha
	mov ah, 09h			; Draw red bar at top
	xor bh, bh
	mov cx, 240
	mov bl, 01001111b
	mov al, ' '
	int 10h
	popa

	mov dh, 0
	mov dl, 0
	call os_move_cursor

	mov si, .msg_inform		; Inform of fatal error
	call os_print_string

	mov si, bx			; Program-supplied error message
	call os_print_string

	call os_print_newline

	mov si, .msg_prompt		; Restart prompt
	call os_print_string

	xor ax, ax
	mov ah, 00			; BIOS call to wait for key
	int 16h

	jmp os_int_reboot


	.msg_inform		db '>>> FATAL OPERATING SYSTEM ERROR', 13, 10, 0
	.msg_prompt		db 'Press a key to restart MikeOS...', 0


; -----------------------------------------------------------------
; os_get_file_list -- Generate comma-separated string of files on floppy
; IN/OUT: AX = location of string to store filenames

os_get_file_list:
	pusha

	mov word [.file_list_tmp], ax	; Store string location

	xor eax, eax			; Needed for some older BIOSes

	call os_int_reset_floppy	; Just in case disk was changed
	jnc .floppy_ok			; Did the floppy reset OK?

	mov ax, .err_msg_floppy_reset	; If not, bail out
	jmp os_fatal_error


.floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call os_int_l2hts

	lea si, [os_buffer]		; ES:BX should point to our buffer
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	pusha				; Prepare to enter loop


.read_root_dir:
	popa
	pusha

	stc
	int 13h				; Read sectors
	call os_int_reset_floppy	; Check we've read them OK
	jnc .show_dir_init		; No errors, continue

	call os_int_reset_floppy	; Error = reset controller and try again
	jnc .read_root_dir
	jmp .done			; Double error, exit 'dir' routine

.show_dir_init:
	popa

	xor ax, ax
	mov si, os_buffer		; Data reader from start of filenames

	mov word di, [.file_list_tmp]	; Name destination buffer


.start_entry:
	mov al, [si+11]			; File attributes for entry
	cmp al, 0Fh			; Windows marker, skip it
	je .skip

	test al, 10h			; Is this a directory entry?
	jnz .skip			; Yes, ignore it

	mov al, [si]
	cmp al, 229			; If we read 229 = deleted filename
	je .skip

	cmp al, 0			; 1st byte = entry never used
	je .done


	mov cx, 1			; Set char counter
	mov dx, si			; Beginning of possible entry

.testdirentry:
	inc si
	mov al, [si]			; Test for most unusable characters
	cmp al, ' '			; Windows sometimes puts 0 (UTF-8) or 0FFh
	jl .nxtdirentry
	cmp al, '~'
	ja .nxtdirentry

	inc cx
	cmp cx, 11			; Done 11 char filename?
	je .gotfilename
	jmp .testdirentry


.gotfilename:				; Got a filename that passes testing
	mov si, dx			; DX = where getting string
	mov cx, 11
	rep movsb
	mov ax, ','			; Use comma to separate for next file
	stosb

.nxtdirentry:
	mov si, dx			; Start of entry, pretend to skip to next

.skip:
	add si, 32			; Shift to next 32 bytes (next filename)
	jmp .start_entry


.done:
	dec di				; Zero-terminate string
	mov ax, 0			; Don't want to keep last comma!
	stosb

	popa
	ret


	.file_list_tmp	dw 0
	.err_msg_floppy_reset	db 'os_get_file_list: Floppy failed to reset', 0


; -----------------------------------------------------------------
; os_load_file -- Load file into bottom-half of MikeOS RAM
; (NOTE: Must be 32K or less, including load offset address)
; IN: AX = location of filename, CX = location in RAM to load file
; OUT: BX = file size (in sectors), carry set if program not found
; on the disk or too big

; NOTE: Based on free bootloader code by E Dehling

os_load_file:
	mov [.filename_loc], ax		; Store filename location
	mov [.load_position], cx	; And where to load the file!

	xor eax, eax			; Needed for some older BIOSes

	call os_int_reset_floppy	; In case floppy has been changed
	jnc .floppy_ok			; Did the floppy reset OK?

	mov ax, .err_msg_floppy_reset	; If not, bail out
	jmp os_fatal_error


.floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call os_int_l2hts

	lea si, [os_buffer]		; ES:BX should point to our buffer
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; 14 root directory sectors

	pusha				; Prepare to enter loop


.read_root_dir:
	popa
	pusha

	stc				; A few BIOSes clear, but don't set properly
	int 13h				; Read sectors
	jnc .search_root_dir		; No errors = continue

	call os_int_reset_floppy	; Problem = reset controller and try again
	jnc .read_root_dir

	popa
	jmp .root_problem		; Double error = exit

.search_root_dir:
	popa

	mov cx, word 224		; Search all entries in root dir
	mov bx, -32			; Begin searching at offset 0 in root dir

.next_root_entry:
	add bx, 32			; Bump searched entries by 1 (offset + 32 bytes)
	lea di, [os_buffer]		; Point root dir at next entry
	add di, bx

	mov al, [di]			; First character of name

	cmp al, 0			; Last file name already checked?
	je .root_problem

	cmp al, 229			; Was this file deleted?
	je .next_root_entry		; If yes, skip it

	mov al, [di+11]			; Get the attribute byte

	cmp al, 0Fh			; Is this a special Windows entry?
	je .next_root_entry

	test al, 10h			; Is this a directory entry?
	jnz .next_root_entry

	mov byte [di+11], 0		; Add a terminator to directory name entry

	mov ax, di			; Convert root buffer name to upper case
	call os_string_uppercase

	mov si, [.filename_loc]		; DS:SI = location of filename to load

	call os_string_compare		; Current entry same as requested?
	jc .found_file_to_load

	loop .next_root_entry

.root_problem:
	mov bx, 0			; If file not found or major disk error,
	stc				; return with size = 0 and carry set
	ret


.found_file_to_load:			; Now fetch cluster and load FAT into RAM
	mov ax, [di+28]			; Check size will fit in available RAM
	mov dx, [di+30]
	add ax, [.load_position]	; Add starting location
	adc dx, 0
	add ax, 511			; Round up to next sector size
	adc dx, 0
	mov cx, 512
	div cx				; AX = number of sectors to load
	mov [.file_size], ax		; Save for return parameter
	cmp ax, 64			; Maximimum sectors that will fit
	jle .initial_fat_read
	jmp .file_too_big

.initial_fat_read:
	mov ax, [di+26]			; Now fetch cluster and load FAT into RAM
	mov word [.cluster], ax

	mov ax, 1			; Sector 1 = first sector of first FAT
	call os_int_l2hts

	lea di, [os_buffer]		; ES:BX points to our buffer
	mov bx, di

	mov ah, 0x02			; int 13h params: read sectors
	mov al, 0x09			; And read 9 of them

	pusha

.read_fat:
	popa				; In case registers altered by int 13h
	pusha

	stc
	int 13h
	jnc .read_fat_ok

	call os_int_reset_floppy
	jnc .read_fat

	popa
	jmp .root_problem


.read_fat_ok:
	popa


.load_file_sector:
	mov ax, word [.cluster]		; Convert sector to logical
	add ax, 31

	call os_int_l2hts		; Make appropriate params for int 13h

	mov bx, [.load_position]


	mov ah, 02			; AH = read sectors, AL = 1 at a time
	mov al, 01

	stc
	int 13h
	jnc .calculate_next_cluster	; If there's no error...

	call os_int_reset_floppy	; Otherwise, reset floppy and retry
	jnc .load_file_sector

	mov ax, .err_msg_floppy_reset	; Reset failed, bail out
	jmp os_fatal_error


.calculate_next_cluster:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [CLUSTER] mod 2
	lea si, [os_buffer]		; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0 [CLUSTER] = even, if DX = 1 then odd

	jz .even			; If [CLUSTER] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits

.odd:
	shr ax, 4			; Shift out first 4 bits (belong to another entry)
	jmp .calculate_cluster_cont	; Onto next sector!

.even:
	and ax, 0x0FFF			; Mask out top (last) 4 bits

.calculate_cluster_cont:
	mov word [.cluster], ax		; Store cluster

	cmp ax, 0x0FF8
	jae .end

	add word [.load_position], 512
	jmp .load_file_sector		; Onto next sector!


.end:
	mov bx, [.file_size]		; Get file size to pass back in BX
	clc				; Carry clear = good load
	ret


.file_too_big:				; AX = integer number of sectors
	mov si, .err_msg_big_file
	call os_print_string
	mov bx, .string_buff
	call os_int_to_string
	mov si, bx
	call os_print_string
	call os_print_newline
	mov bx, 0
	stc
	ret


	.bootd		db 0 		; Boot device number
	.cluster	dw 0 		; Cluster of the file we want to load
	.pointer	dw 0 		; Pointer into os_buffer, for loading 'file2load'

	.filename_loc	dw 0		; Temporary store of filename location
	.load_position	dw 0		; Where we'll load the file
	.file_size	dw 0		; Size of the file

	.string_buff	times 12 db 0	; For size (integer) printing

	.err_msg_floppy_reset	db 'os_load_file: Floppy failed to reset', 0
	.err_msg_big_file	db 'os_load_file: File too big to fit in available RAM: ', 0



; -----------------------------------------------------------------
; os_execute_program -- Run code loaded at 100h in RAM (current CS)
; IN: BX = 1 if screen is to be cleared first, otherwise 0
; OUT: Nothing (registers may be corrupt)

os_execute_program:
	cmp bx, 1
	jne .run_program

	call os_clear_screen


.run_program:

	; The following four lines set up a very basic Program Segment Prefix,
	; aka PSP, which provides some information for DOS programs. For
	; instance, CD 20 = 'int 20h', or 'return to DOS' -- a program can
	; use this code to quit

	mov byte [0], 0xCD		; int 20h
	mov byte [1], 0x20
	mov byte [2], 0xA0		; Always 0xA000 for COM executables
	mov byte [3], 0x00


	pusha                           ; Save all registers and stack pointer
	push ds
	push es
	mov [.mainstack], sp
	xor ax, ax			; Clear registers to be DOS compatible
	xor bx, bx
	xor cx, cx
	xor dx, dx
	xor si, si
	xor di, di
	xor bp, bp
	mov byte [now_run_a_program], 1

	call 0x0100			; Jump to newly-loaded program!

.end_the_program:			; End of the program run
	mov byte [now_run_a_program], 0
	mov sp, [.mainstack]		; Restore stack, segment and
	pop es				; common registers
	pop ds
	popa
	clc

	ret


        .mainstack dw 0
         now_run_a_program db 0



; =================================================================
; INTERNAL OS ROUTINES -- Not accessible to user programs

; -----------------------------------------------------------------
; Reboot machine via keyboard controller

os_int_reboot:
	; XXX -- We should check that keyboard buffer is empty first
	mov al, 0xFE
	out 0x64, al


; -----------------------------------------------------------------
; Reset floppy drive

os_int_reset_floppy:
	push ax
	push dx
	xor ax, ax
	mov dl, 0
	stc
	int 13h
	pop dx
	pop ax
	ret


; -----------------------------------------------------------------
; Convert floppy sector from logical to physical

os_int_l2hts:		; Calculate head, track and sector settings for int 13h
			; IN: AX = logical sector; OUT: correct regs for int 13h
	push bx
	push ax

	mov bx, ax			; Save logical sector

	xor dx, dx			; First the sector
	div word [.sectors_per_track]
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	xor dx, dx			; Now calculate the head
	div word [.sectors_per_track]
	xor dx, dx
	div word [.sides]
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

	mov dl, 0			; Boot device = 0

	ret


	.sectors_per_track	dw 18	; Floppy disc info
	.sides			dw 2


; =================================================================

