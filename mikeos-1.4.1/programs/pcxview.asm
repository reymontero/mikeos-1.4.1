; -----------------------------------------------------------------
; Program to display PCX images (320x200, 8-bit only)
; -----------------------------------------------------------------


	BITS 16
	%INCLUDE "mikedev.inc"
	ORG 100h


start:
	call os_clear_screen

	mov dx, 0			; One button for dialog box
	mov ax, .dlg_string_1
	mov bx, .dlg_string_2
	mov cx, .dlg_string_3
	call os_dialog_box

	call os_clear_screen

	mov ax, .title_msg		; Set up screen
	mov bx, .footer_msg
	mov cx, RED_ON_LIGHT_GREEN
	call os_draw_background

	call os_file_selector		; Get filename

	cmp ax, 0			; If Esc pressed in file dialog
	je .finish


	mov cx, 1000h			; Load PCX at 1000h
	call os_load_file


	mov ah, 0			; Switch to graphics mode
	mov al, 13h
	int 10h


	mov ax, 0A000h			; ES = video memory
	mov es, ax


	mov si, 1080h			; Move source to start of image data
					; (First 80h bytes is header)

	xor di, di			; Start our loop at top of video RAM

.decode:
	mov cx, 1
	lodsb
	cmp al, 192			; Single pixel or string?
	jb .single
	and al, 63			; String, so 'mod 64' it
	mov cl, al			; Result in CL for following 'rep'
	lodsb				; Get byte to put on screen
.single:
	rep stosb			; And show it (or all of them)
	cmp di, 64001
	jb .decode


	mov dx, 3c8h			; Palette index register
	xor al, al			; Start at color 0
	out dx, al			; Tell VGA controller that...
	inc dx				; ...3c9h = palette data register

	mov cx, 768			; 256 colours, 3 bytes each
.setpal:
	lodsb				; Grab the next byte.
	shr al, 2			; Palettes divided by 4, so undo
	out dx, al			; Send to VGA controller
	loop .setpal


	call os_wait_for_key

	mov ah, 0			; Back to text video mode
	mov al, 03h
	int 10h

.finish:
	call os_clear_screen
	ret


	.dlg_string_1	db 'This program displays 320x200, 8-bit PCX', 0
	.dlg_string_2	db 'images. Select a file in the next dialog', 0
	.dlg_string_3	db 'and press a key to finish displaying.', 0

	.title_msg      db 'MikeOS PCX image loader', 0
	.footer_msg     db 'Select a PCX file to view...', 0


; -----------------------------------------------------------------

