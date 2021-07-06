; -----------------------------------------------------------------
; Music keyboard -- be the Bachster (well, a monophonic Bach)
; Use Z key rightwards for an octave
; -----------------------------------------------------------------


	BITS 16

 	%INCLUDE "mikedev.inc"

	ORG 100h


music_keyboard:
	call os_clear_screen

	mov ax, mus_kbd_title_msg	; Set up screen
	mov bx, mus_kbd_footer_msg
	mov cx, WHITE_ON_LIGHT_RED
	call os_draw_background

	call os_print_newline


.retry:
	call os_wait_for_key

;	cmp al, 0		; Owt?
;	je .retry		; Nowt, so go back


	push ax
	mov ah, 0Eh		; Otherwise print space for notes below
	mov al, 32
	int 10h
	pop ax

.nokey:				; And start matching keys with notes
	cmp al, 'z'
	jne .x
	mov al, 'C'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 4000
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.x:
	cmp al, 'x'
	jne .c
	mov al, 'D'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 3600
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.c:
	cmp al, 'c'
	jne .v
	mov al, 'E'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 3200
	mov bx, 0
	call os_speaker_tone
	jmp .retry


.v:
	cmp al, 'v'
	jne .b
	mov al, 'F'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 3000
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.b:
	cmp al, 'b'
	jne .n
	mov al, 'G'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 2700
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.n:
	cmp al, 'n'
	jne .m
	mov al, 'A'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 2400
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.m:
	cmp al, 'm'
	jne .comma
	mov al, 'B'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 2100
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.comma:
	cmp al, ','
	jne .space
	mov al, 'C'
	mov ah, 0x0E		; Print note
	int 10h
	mov ax, 2000
	mov bx, 0
	call os_speaker_tone
	jmp .retry

.space:
	cmp al, ' '
	jne .q
	call os_speaker_off
	jmp .retry

.q:
	cmp al, 'q'
	je .end
	cmp al, 'Q'
	je .end
	jmp .nowt

.nowt:
	jmp .retry

.end:
	call os_speaker_off
	call os_clear_screen
	ret			; Back to OS


	mus_kbd_title_msg	db 'MikeOS music keyboard', 0
	mus_kbd_footer_msg	db 'Z key onwards to play notes, space to stop note, Q to quit', 0


; -----------------------------------------------------------------

