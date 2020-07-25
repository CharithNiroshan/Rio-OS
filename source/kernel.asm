;                                                            Rio Operating System Kernel
;=================================================================================================================================================

;*************************************************************start of the kernel code****************************************************
[org 0x0000]
[bits 16]

	%DEFINE KEY_ESC		27

; ------------------------------------------------------------------
; OS CALL VECTORS -- Static locations for system call vectors
; Note: these cannot be moved, or it'll break the calls!

; The comments show exact locations of instructions in this section,
; and are used in programs/mikedev.inc so that an external program can
; use a MikeOS system call without having to know its exact position
; in the kernel source code...

os_call_vectors:
	jmp os_main			; 0000h -- Called from bootloader
	jmp printing_string		; 0003h
	jmp os_move_cursor		; 0006h
	jmp os_wait_for_key		; 0012h
	jmp os_draw_background		; 002Ah
	jmp os_dialog_box		; 003Ch
	jmp os_show_cursor		; 008Ah
	jmp os_hide_cursor		; 008Dh
	jmp os_draw_block		; 00B4h


; ----------------------------------------------------------------------------------------------------------------------------------------

;Text Segment Of the Rio OS Kernel
;-----------------------------------------------------------------------------------------------------------------------------------------

[SEGMENT .text]

os_main:

	cli				; Clear interrupts
	mov ax, 0
	mov ss, ax			; Set stack segment and pointer
	mov sp, 0FFFFh
	sti				; Restore interrupts

	cld				; The default direction for string operations
					; will be 'up' - incrementing address in RAM

	mov ax, 2000h			; Set all segments to match where kernel is loaded
	mov ds, ax			; After this, we don't need to bother with
	mov es, ax			; segments ever again, as MikeOS and its programs
	mov fs, ax			; live entirely in 64K
	mov gs, ax
	
	cmp dl, 0
	je no_change


no_change:

	mov ax, 1003h			; Set text output with certain attributes
	mov bx, 0			; to be bright, and not blinking
	int 10h
       
option_screen:

	mov ax, str_welcomemessage
	mov bx, rioos_version
	mov cx, 10001111b
	call os_draw_background
	
	mov ax, dialog_string_1		; Ask if user wants Hardware Information or to exit
	mov bx, dialog_string_2
	mov cx, dialog_string_3
	mov dx, 1			; We want a two-option dialog box (Hardware Info or Cancel)
	call os_dialog_box

	cmp ax, 1			; If Hardware Info (option=0) chosen, start hardware screen
	jne hardwareinfo_screen

	call os_exit		; Otherwise exit
	

hardwareinfo_screen:

	mov ax, str_hardwareinfo               ; Printing Hardware Information screen it's other strings
	mov bx, rioos_version
	mov cx, 10001111b
	call os_draw_background

	call _display_endl
	
	
	mov si, str_processorinfo		 ; Calling functions to Print Processor information on screen
	call printing_string
	call _display_endl
	call _display_endl
	call printing_cpuVendorID
	call printing_cpuType
	
	call _display_endl
	call _display_endl
	
	mov si, str_memoryinfo		; Calling functions to Print Memory information on screen
	call printing_string
	call _display_endl
	call printing_Basememory
	call printing_Extendedmemory
	call printing_Extended2memory
	call printing_Totalmemory
	
	call _display_endl
	call _display_endl
	
	mov si, str_otherinfo		; Calling functions to Other Hardware information on screen
	call printing_string
	call _display_endl
	call printing_Hardinfo
	call printing_Serialports
	
	call _display_endl		; Printing Message of press esc on screen
	call _display_endl
	mov si, str_back
	call printing_string
	
	call go_back			; Calling function to wait till user press esc

go_back:

	call os_wait_for_key			; Get input

	cmp al, KEY_ESC				; Go back if Esc pressed
	je option_screen
	
	call go_back			; If any other key ( not esc ) pressed again repeat the process

	ret
	
printing_cpuVendorID:			; Function to Print Processor VendorID information on screen

	mov eax,0
	cpuid;call cpuid command
	mov [strcpuid],ebx       ;load last string
	mov [strcpuid+4],edx     ; load middle string
	mov [strcpuid+8],ecx	  ; load first string
	
	mov si, strVendorID;
	call printing_string	 
	mov si, strcpuid;print CPU vender ID
	call printing_string
	ret
	
printing_cpuType:			; Function to Print Processor Type and Speed information on screen

	mov eax,0x80000002
	cpuid; call cpuid command
	mov [strcputype]   ,eax
	mov [strcputype+4] ,ebx
	mov [strcputype+8] ,ecx
	mov [strcputype+12],edx
	
	mov eax,0x80000003
	cpuid; call cpuid command
	mov [strcputype+16],eax
	mov [strcputype+20],ebx
	mov [strcputype+24],ecx
	mov [strcputype+28],edx
	
	mov eax,0x80000004
	cpuid; call cpuid command
	mov [strcputype+32],eax
	mov [strcputype+36],ebx
	mov [strcputype+40],ecx
	mov [strcputype+44],edx
	
	
	call _display_endl
	mov si, strProcessor;
	call printing_string
	mov si, strcputype 
	call printing_string
	
	ret
	
printing_Basememory:				; Function to Print Base Memory information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strBasememory;
	call printing_string
	
	int 0x12		; call interrupt 12 to get base mem size
	mov dx,ax
	mov [basemem],ax
	call printing_integers		; display the number in decimal
	mov al, 0x6b
        mov ah, 0x0E            ; BIOS teletype acts on 'K' 
        mov bh, 0x00
        mov bl, 0x07
        int 0x10
	
	pop ax
	pop dx
	ret

printing_Extendedmemory:			; Function to Print Extended Memory1 information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strExtendedmemory;
	call printing_string
	
	xor cx, cx		; Clear CX
	xor dx, dx		; clear DX
	mov ax, 0xE801
	int 0x15		; call interrupt 15h
	mov dx, ax		; save memory value in DX as the procedure argument
	mov [extendedmem1],ax
	call printing_integers		; print the decimal value in DX
	mov al, 0x6b
        mov ah, 0x0E            ; BIOS teletype acts on 'K'
        mov bh, 0x00
        mov bl, 0x07
        int 0x10
        
	pop ax
	pop dx
	ret
	
printing_Extended2memory:			; Function to Print Extended Memory2 information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strExtended2memory;
	call printing_string
	
	xor cx, cx		; clear CX
        xor dx, dx		; clear DX
        mov ax, 0xE801
        int 0x15		; call interrupt 15h
	mov ax, dx		; save memory value in AX for division
	mov [extendedmem2],ax
	xor dx, dx
	mov si , 16
	div si			; divide AX value to get the number of MB
	mov dx, ax
	push dx			; save dx value
	
	pop dx			; retrieve DX for printing
	call printing_integers
	mov al, 0x4D
        mov ah, 0x0E            ; BIOS teletype acts on 'M'
        mov bh, 0x00
        mov bl, 0x07
        int 0x10
        
	pop ax
	pop dx
	ret
	
printing_Totalmemory:			; Function to Print Total Memory information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strTotalmemory;
	call printing_string
	
	mov ax, [basemem]	
	add ax, [extendedmem1]	; ax = ax + extmem1
	shr ax, 10
	add ax, [extendedmem2]	; ax = ax + extmem2
	mov dx, ax
	call printing_integers
	mov al, 0x4D            
	mov ah, 0x0E            ; BIOS teletype acts on 'M'
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	
	pop ax
	pop dx
	ret
	
printing_Hardinfo:			; Function to Print No of Hard Drives information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strNoofharddisks;
	call printing_string

	mov ax,0040h             ; look at 0040:0075 for a number
	mov es,ax                ;
	mov dl,[es:0075h]        ; move the number into DL register
	add dl,30h		; add 48 to get ASCII value            
	mov al, dl
        mov ah, 0x0E            ; BIOS teletype acts on character 
        mov bh, 0x00
        mov bl, 0x07
        int 0x10
        
        pop ax
	pop dx
        
        ret
        
printing_Serialports:			; Function to Print No of Serail Ports information on screen

	push ax
	push dx
	
	call _display_endl
	mov si, strNoofserialports;
	call printing_string
	
	mov ax, [es:0x10]
	shr ax, 9
	and ax, 0x0007
	add al, 30h
	mov ah, 0x0E            ; BIOS teletype acts on character
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	
	; Reading base I/O addresses
	;Base I/O address for serial port 1 (communications port 1 - COM 1)
	mov ax, [es:0000h]	; Read address for serial port 1
	cmp ax, 0
	je _end
	call _display_endl
	mov si, strSerialports1
        call printing_string	

	mov dx, ax
	call printing_integers
	
	pop ax
	pop dx
	
	ret
	
_end:
	
	pop ax
	pop dx
	
	ret
	
os_exit:					; Function to Quit the OS if Esc pressed
	mov ax, 5307h
	mov cx, 3
 	mov bx, 1
	int 15h
	
_display_endl:					; Function to Print New Line on screen

    mov ah, 0x0E        ; BIOS teletype acts on newline!
    mov al, 0x0D
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    
    mov ah, 0x0E        ; BIOS teletype acts on linefeed!
    mov al, 0x0A
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    ret
    
    

printing_integers:				; Function to Print an Integer on screen
	push ax			; save AX
	push cx			; save CX
	push si			; save SI
	mov ax,dx		; copy number to AX
	mov si,10		; SI is used as the divisor
	xor cx,cx		; clear CX

_non_zero:

	xor dx,dx		; clear DX
	div si			; divide by 10
	push dx			; push number onto the stack
	inc cx			; increment CX to do it more times
	or ax,ax		; clear AX
	jne _non_zero		; if not go to _non_zero

_prepare_digits:

	pop dx			; get the digit from DX
	add dl,0x30		; add 30 to get the ASCII value
	call _print_char	; print char
	loop _prepare_digits	; loop till cx == 0

	pop si			; restore SI
	pop cx			; restore CX
	pop ax			; restore AX
	ret                      

_print_char:
	push ax			; save AX 
	mov al, dl
        mov ah, 0x0E		; BIOS teletype acts on printing char
        mov bh, 0x00
        mov bl, 0x07
        int 0x10

	pop ax			; restore AX
	ret

_save_string:
	mov dword [si], eax
	mov dword [si+4], ebx
	mov dword [si+8], ecx
	mov dword [si+12], edx
	ret
	
;=================================================================================================================================================
    
	; FEATURES -- Code to pull into the kernel


	%INCLUDE "features/keyboard.asm"
	%INCLUDE "features/screen.asm"
	
;=================================================================================================================================================

[SEGMENT .data]

	;All data Needed for the Kernel

    	str_welcomemessage   db  "***************************** Welcome to Rio OS ******************************", 0x00
    	str_hardwareinfo db "**************************** Hardware Information ****************************", 0x00
    	rioos_version   db  " Version 1.0.0                                By Charith Niroshan Wijebandara",0x00
    	str_back   db   "                    Press Esc Key to go back...........",0x00
    	str_processorinfo	db  "  Processor Details ",0x00
    	str_memoryinfo	db  "  Main Memory Details ",0x00
    	str_otherinfo	db  "  Secondary Memory and Other Details ",0x00
    	
    	strProcessor    db  "  Processor Type and Speed : ", 0x00
    	strVendorID    db  "  Processor VendorID  : ", 0x00
	strSerialNo   db  "  Serail No : ", 0x00
	strBasememory   db  "  Base Memory : ", 0x00
	strExtendedmemory    db  "  Extended Memory Between ( 1M -16M ) : ", 0x00
    	strExtended2memory   db  "  Extended Memory Above 16M : ", 0x00
	strTotalmemory  db  "  Total Memory : ", 0x00
	strNoofharddisks   db  "  No of Hard Drives : ", 0x00
	strNoofserialports  db  "  No of Serial Ports : ", 0x00
	strSerialports1  db  "  Base I/O address for serial port 1 (communications port 1 - COM 1) : ", 0x00
	
	dialog_string_1	db 'Thanks for trying out Rio Operating System.', 0x00
	dialog_string_2	db 'Please select Hardware Info Hardware ', 0x00
	dialog_string_3	db 'Please Select a Option to Continue.........', 0x00
	
;=================================================================================================================================================

[SEGMENT .bss]

   strcpuid resb   32
   strcputype resb   256
   strserialno resb   32
   basemem     resb   2
   extendedmem1     resb   2
   extendedmem2     resb   2
   
;**********************************************************end of the kernel code ********************************************************
