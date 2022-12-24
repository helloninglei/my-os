org 0x7C00
bits 16

; %define 指示符
; 这个指示符和C中的#define非常相似。它通常用来定义一个宏常量，像在C里面一样。

%define ENDL 0x0D, 0x0A

;
; FAT12 header
; 
; 跳转至start标号处执行指令
jmp short start
nop

; 数据指示符，变量定义
; db:字节，dw:字, dd:双字, dq:四字, dt:10个字节
bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'NANOBYTE OS'        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes


;14个寄存器：「AX，BX，CX，DX，SP，BP，SI，DI，IP，FLAG，CS，DS，SS，ES」
;16位表示能存储2^16 = 64k

;通用寄存器: 
	; AX(Accumulator Register) ：累加寄存器，它主要用于输入/输出和大规模的指令运算。
	; BX(Base Register)：基址寄存器，用来存储基础访问地址
	; CX(Count Register)：计数寄存器，CX 寄存器在迭代的操作中会循环计数
	; DX(data Register)：数据寄存器，它也用于输入/输出操作。它还与 AX 寄存器以及 DX 一起使用，用于涉及大数值的乘法和除法运算。
;段寄存器:
	; CS(Code Segment) ：代码寄存器，程序代码的基础位置
	; DS(Data Segment)：数据寄存器，变量的基本位置
	; SS(Stack Segment)：栈寄存器，栈的基础位置
	; ES(Extra Segment)：其他寄存器，内存中变量的其他基本位置。
;索引寄存器:
	; BP(Base Pointer)：基础指针，它是栈寄存器上的偏移量，用来定位栈上变量
	; SP(Stack Pointer): 栈指针，它是栈寄存器上的偏移量，用来定位栈顶
	; SI(Source Index): 变址寄存器，用来拷贝源字符串
	; DI(Destination Index): 目标变址寄存器，用来复制到目标字符串
;状态和控制寄存器:
	; IP(Instruction Pointer)：指令指针寄存器，它是从 Code Segment 代码寄存器处的偏移来存储执行的下一条指令
	; FLAG : Flag 寄存器用于存储当前进程的状态，这些状态有
		; 位置 (Direction)：用于数据块的传输方向，是向上传输还是向下传输
		; 中断标志位 (Interrupt) ：1 - 允许；0 - 禁止
		; 陷入位 (Trap) ：确定每条指令执行完成后，CPU 是否应该停止。1 - 开启，0 - 关闭
		; 进位 (Carry) : 设置最后一个无符号算术运算是否带有进位
		; 溢出 (Overflow) : 设置最后一个有符号运算是否溢出
		; 符号 (Sign) : 如果最后一次算术运算为负，则设置  1 =负，0 =正
		; 零位 (Zero) : 如果最后一次算术运算结果为零，1 = 零
		; 辅助进位 (Aux Carry) ：用于第三位到第四位的进位
		; 奇偶校验 (Parity) : 用于奇偶校验

; Code goes here
;
; MOV指令：传送字或字节
; mov 寄存器，数据    比如：mov ax,8
; mov 寄存器,寄存器   比如：mov ax,bx
; mov 寄存器，内存单元 比如：mov ax,[0]
; mov 内存单元，寄存器 比如：mov[0], ax
; mov 段寄存器，寄存器 比如：mov ds,ax

; PUSH    把字压入堆栈. 

start:
    ; setup data segments
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we are loaded in memory

    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
    ; expected location
    push es
    push word .after
	; RETF 无条件转移指令，过程返回
    retf

.after:

    ; read something from floppy disk
    ; BIOS should set DL to drive number
	; dl 为DX寄存器低8位
    mov [ebr_drive_number], dl   ; 将DL寄存器中的值存入内存单元ebr_drive_number中

    ; show loading message
	; si 为变址寄存器
    mov si, msg_loading 		; 将内存单元msg_loading的值放到si中
	; call: 过程调用(将寄存器的值转移到栈中)
    call puts

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error		; JC:有进位时跳转
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    ; note: this section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
	; mul: 无符号乘法.结果回送AH和AL(字节运算),或DX和AX(字运算)
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
	; shl: 逻辑左移.
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after					; JZ: 等于零时跳转
    inc ax                              ; division remainder != 0, add 1
                                        ; this means we have a sector only partially filled with entries
.root_dir_after:

    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                          ; compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:

    ; di should have the address to the entry
    mov ax, [di + 26]                   ; first logical cluster field (offset 26)
    mov [kernel_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    
    ; Read next cluster
    mov ax, [kernel_cluster]
    
    ; not nice :( hardcoded value
    add ax, 31                          ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
                                        ; start sector = reserved + fats + root directory size = 1 + 18 + 134 = 33
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    
    ; jump to our kernel
    mov dl, [ebr_drive_number]          ; boot device in dl

    mov ax, KERNEL_LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot             ; should never happen

    cli                                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot

.halt:
    cli                         ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; 因为寄存器会被修改，所以将寄存器中的值存入栈中
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:   db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
kernel_cluster:         dw 0

; equ 指示符
; equ指示符可以用来定义一个符号。符号被命名为可以在汇编程序里使用的常量。格式是：变量名 equ 变量值

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


times 510-($-$$) db 0
dw 0AA55h

buffer: