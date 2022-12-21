org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

; FAT 文档: https://wiki.osdev.org/FAT#FAT_12

; ################################
; # FAT12 header
; # BPB (BIOS Parameter Block)
; ################################
jmp short start
nop

bdb_oem:                  db 'MSWIN4.1'
bdb_bytes_per_sector:     dw 512
bdb_sectors_per_cluster:  db 1
bdb_reserved_sectors:     dw 1
bdb_fat_count:            db 2
bdb_dir_entries_count:    dw 0E0h
bdb_total_sector:         dw 2880
bdb_media_descritor_type: db 0F0h
bdb_sector_per_fat:       dw 9
bdb_sectors_per_track:    dw 18
bdb_heads:                dw 2
bdb_hidden_sectors:       dd 0
bdb_large_sector_count:   dd 0

; Extended Boot Record
ebr_drive_number:         db 0
						  db 0
ebr_signature:            db 29h
ebr_volume_id:            db 12h, 34h, 56h, 78h
ebr_volume_label:         db 'NANOBYTE OS'
ebr_system_id:            db 'FAT12'

start:
	jmp main

;
; Prints a string to the screen.
; Params;
;	- ds:si points to sring
;
puts:
	; save registers we will modify
	push si
	push ax

.loop:
	lodsb	; loads next character in al
	or al, al	; verify if next character is null ?
	jz .done

	mov ah, 0x0e	; call bios interrupt
	int 0x10

	jmp .loop

.done
	pop ax
	pop si
	ret

main:
	; set up data segments
	mov ax, 0    ; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00      ; stack grows downwards from where we are loaded in memory

	; read something from floppy disk
	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl
	mov ax, 1					; LBA=1, secod sector from dis
	mov cl, 1					; 1 sector to read
	mov bx, 0x7E00				; data should be after the bootloader

	call disk_read

	; print message
	mov si, msg_hello
	call puts
	cli
	hlt

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h				; wait for keypress
	jmp 0FFFFh:0		; jump to beginning of BIOS, should reboot


.halt:
	cli
	hlt

;
; Disk routines
; 
; Converts an LBA address to a CHS address
; Parameters:
; 	- ax: LBA address
; Returns:
; 	- cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;	- dh: header

lba_to_chs:

	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA / SectorsPerTrack

	inc dx								; dx = (LBA % SectorsPerTrack +1) = sector
	mov cx, dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										; dx = (LBA / SectorsPerTrack) % Heads = head

	mov dh, dl 							; dl = head
	mov ch, al 							; ch = cylinder *lower 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al							; restore DL
	pop ax
	ret

; 
; Reads sectors from a dis
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- es:bx: memotry address where to store read data
disk_read:
	push ax				; save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx				; temporarily save CL (number of sectors to read)
	call lba_to_chs		; compute CHS
	pop ax				; AL = numbder of sectors to read

	mov ah, 02h
	mov di, 3

.retry:
	pusha
	stc
	int 13h
	jmp .done

	; railed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa
	pop ax
	pop bx
	pop cx
	pop dx
	pop di							; restore registers we will modify
	ret

;
; Reset disk controller
; Parameters:
; 	dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
