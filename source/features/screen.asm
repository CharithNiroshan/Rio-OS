;                                                            Rio Operating System Kernel
;=================================================================================================================================================
;
;                                                           SCREEN HANDLING SYSTEM CALLS
; ================================================================================================================================================


printing_string:

	lodsb                                   ; load next character
	or  al, al                              ; test for NUL character
	jz  .DONE
	mov ah, 0x0E                            ; BIOS teletype
	mov bh, 0x00                            ; display page 0
	mov bl, 0x07                            ; text attribute
	int 0x10                                ; invoke BIOS
	jmp printing_string
   .DONE:
	ret
	
; ------------------------------------------------------------------
; os_show_cursor -- Turns on cursor in text mode
; IN/OUT: Nothing

os_show_cursor:
	pusha

	mov ch, 6
	mov cl, 7
	mov ah, 1
	mov al, 3
	int 10h

	popa
	ret


; ------------------------------------------------------------------
; os_hide_cursor -- Turns off cursor in text mode
; IN/OUT: Nothing

os_hide_cursor:
	pusha

	mov ch, 32
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret


; ------------------------------------------------------------------
; os_draw_block -- Render block of specified colour
; IN: BL/DL/DH/SI/DI = colour/start X pos/start Y pos/width/finish Y pos


; ------------------------------------------------------------------
; os_draw_background -- Clear screen with white top and bottom bars
; containing text, and a coloured middle section.
; IN: AX/BX = top/bottom string locations, CX = colour

os_draw_background:
	pusha

	push ax				; Store params to pop out later
	push bx
	push cx

	mov dl, 0
	mov dh, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at top
	mov bh, 0
	mov cx, 80
	mov bl, 00001111b
	mov al, ' '
	int 10h

	mov dh, 1
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw colour section
	mov cx, 1840
	pop bx				; Get colour param (originally in CX)
	mov bh, 0
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at bottom
	mov bh, 0
	mov cx, 80
	mov bl, 00001111b
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 1
	call os_move_cursor
	pop bx				; Get bottom string param
	mov si, bx
	call printing_string

	mov dh, 0
	mov dl, 1
	call os_move_cursor
	pop ax				; Get top string param
	mov si, ax
	call printing_string

	mov dh, 1			; Ready for app text
	mov dl, 0
	call os_move_cursor

	popa
	ret

; ------------------------------------------------------------------
; os_draw_block -- Render block of specified colour
; IN: BL/DL/DH/SI/DI = colour/start X pos/start Y pos/width/finish Y pos

os_draw_block:
	pusha

.more:
	call os_move_cursor		; Move to block starting position

	mov ah, 09h			; Draw colour section
	mov bh, 0
	mov cx, si
	mov al, ' '
	int 10h

	inc dh				; Get ready for next line

	mov ax, 0
	mov al, dh			; Get current Y position into DL
	cmp ax, di			; Reached finishing point (DI)?
	jne .more			; If not, keep drawing

	popa
	ret


; ------------------------------------------------------------------
; os_move_cursor -- Moves cursor in text mode
; IN: DH, DL = row, column; OUT: Nothing (registers preserved)

os_move_cursor:
	pusha

	mov bh, 0
	mov ah, 2
	int 10h				; BIOS interrupt to move cursor

	popa
	ret





; ------------------------------------------------------------------
; os_dialog_box -- Print dialog box in middle of screen, with button(s)
; IN: AX, BX, CX = string locations (set registers to 0 for no display)
; IN: DX = 0 for single 'OK' dialog, 1 for two-button 'OK' and 'Cancel'
; OUT: If two-button mode, AX = 0 for OK and 1 for cancel
; NOTE: Each string is limited to 40 characters


os_dialog_box:

	pusha

	mov [.tmp], dx

	call os_hide_cursor

	mov dh, 8			; First, draw red background box
	mov dl, 15

.redbox:				; Loop to draw all lines of box

	call os_move_cursor

	pusha
	mov ah, 09h
	mov bh, 0
	mov cx, 50
	mov bl, 00011111b		; White on red
	mov al, ' '
	int 10h
	popa

	inc dh
	cmp dh, 17
	je .boxdone
	jmp .redbox


.boxdone:
	cmp ax, 0			; Skip string params if zero
	je .no_third_string
	mov dl, 19
	mov dh, 10
	call os_move_cursor

	mov si, ax			; First string
	call printing_string

.no_second_string:
	cmp cx, 0
	je .no_third_string
	mov dl, 19
	mov dh, 11
	call os_move_cursor

	mov si, cx			; Third string
	call printing_string

.no_third_string:
	mov dx, [.tmp]
	cmp dx, 0
	je .one_button
	cmp dx, 1
	je .two_button

.one_button:

	mov bl, 11110000b		; Black on white
	mov dh, 14
	mov dl, 35
	mov si, 10
	mov di, 15
	call os_draw_block

	mov dl, 38			; OK button, centred at bottom of box
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call printing_string

	jmp .one_button_wait


.two_button:

	mov bl, 11110000b		; Black on white
	mov dh, 14
	mov dl, 25
	mov si, 16
	mov di, 15
	call os_draw_block

	mov dl, 27			; OK button
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call printing_string

	mov dl, 45			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_string
	call printing_string

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

	mov bl, 11110000b		; Black on white
	mov dh, 14
	mov dl, 25
	mov si, 16
	mov di, 15
	call os_draw_block

	mov dl, 27			; OK button
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call printing_string

	mov bl, 00011111b		; White on red for cancel button
	mov dh, 14
	mov dl, 43
	mov si, 9
	mov di, 15
	call os_draw_block

	mov dl, 45			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_string
	call printing_string

	mov cx, 0			; And update result we'll return
	jmp .two_button_wait


.noleft:

	cmp ah, 77			; Right cursor key pressed?
	jne .noright


	mov bl, 00011111b		; Black on white
	mov dh, 14
	mov dl, 25
	mov si, 16
	mov di, 15
	call os_draw_block

	mov dl, 27			; OK button
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call printing_string

	mov bl, 11110000b		; White on red for cancel button
	mov dh, 14
	mov dl, 43
	mov si, 8
	mov di, 15
	call os_draw_block

	mov dl, 45			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_string
	call printing_string

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


	.ok_button_string	db 'Hardware Info', 0
	.cancel_button_string	db 'Exit', 0
	.ok_button_noselect	db '   OK   ', 0
	.cancel_button_noselect	db '   Cancel   ', 0

	.tmp dw 0
	
	
; ================================================================================================================
