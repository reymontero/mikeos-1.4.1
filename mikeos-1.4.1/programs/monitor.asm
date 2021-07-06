;--------------------------------------------------
; Monitor program 1.0 for MikeOS -- by Yutaka Saito
; (updated by Mike Saunders)
;
; Accepts code in hex format, ORGed to the second
; 16K of RAM (16384)
;--------------------------------------------------


	BITS 16
	%INCLUDE "mikedev.inc"
	ORG 100h

	; This line determines where the machine code will
	; be generated -- if you change it, you will need to
	; ORG the code you enter at the new address
	CODELOC	equ 16384


start:
	call os_print_newline

	mov si, helpmsg1		; Print help text
	call os_print_string

	mov si, helpmsg2
	call os_print_string

.noinput:
	call os_print_newline

	mov si, prompt			; Print prompt
	call os_print_string

	mov ax, input			; Get hex string
	call os_input_string

	mov ax, input
	call os_string_length
	cmp ax, 0
	je .noinput

	mov si, input			; Convert to machine code...
	mov di, run


.more:
	cmp byte [si], '$'	; If char in string is '$', end of code
	je .done
	cmp byte [si], ' '	; If space, move on to next char
	je .space
	cmp byte [si], 'r'	; If 'r' entered, re-run existing code
	je .runprog
	cmp byte [si], 'x'	; Or if 'x' entered, return to OS
	jne .noexit
	call os_print_newline
	ret
.noexit:
	mov al, [si]
	and al, 0xF0
	cmp al, 0x40
	je .H_A_to_F
.H_1_to_9:
	mov al, [si]
	sub al, 0x30
	mov ah, al
	sal ah, 4
	jmp .H_end
.H_A_to_F:
	mov al, [si]
	sub al, 0x37
	mov ah, al
	sal ah, 4
.H_end:
	inc si
	mov al, [si]
	and al,0xF0
	cmp al,0x40
	je .L_A_to_F
.L_1_to_9:
	mov al, [si]
	sub al, 0x30
	jmp .L_end
.L_A_to_F:
	mov al, [si]
	sub al, 0x37
.L_end:
	or al, ah
	mov [di], al
	inc di
.space:
	inc si
	jmp .more
.done:
	mov byte [di], 0	; Write terminating zero

	mov si, run		; Copy machine code to second 16K of RAM
	mov di, CODELOC
	mov cx, 255
	cld
	rep movsb


.runprog:
	call os_print_newline

	call CODELOC		; Run program

	call os_print_newline

	jmp start


	input		times 255 db 0
	run		times 255 db 0
	helpmsg1	db 'Enter instructions in hex, terminated by $ sign', 10, 13, 0
	helpmsg2	db 'Commands: r = re-run previous code, x = exit', 10, 13, 0
	prompt		db '= ', 0


; -----------------------------------------------------------------

