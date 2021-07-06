; -----------------------------------------------------------------
; Hello World for MikeOS
; -----------------------------------------------------------------

	BITS 16
	%INCLUDE "mikedev.inc"
	ORG 100h

start:
	mov si, message
	call os_print_string

	ret

	message	db 'Hello, world!', 13, 10, 0


; -----------------------------------------------------------------

