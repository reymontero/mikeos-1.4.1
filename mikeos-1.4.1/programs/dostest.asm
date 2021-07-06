; Very simple DOS program -- works under DOS/Windows and MikeOS

	ORG 100h

start:
	xor ax, ax

	mov dx, message
	mov ah, 9		; Print text
	int 21h			; Call DOS

	int 20h			; Exit app

	message db 'This is a DOS program!$'

