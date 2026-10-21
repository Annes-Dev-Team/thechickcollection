bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    ; --- Seed the LCG random number generator from BIOS timer ---
    mov ax, 0x0040
    mov es, ax              ; ES points to BIOS Data Area (BDA)
    mov ax, [es:0x006C]     ; Read low word of the system timer tick counter
    mov [rand_seed], ax     ; Store it as our starting seed
    ; -----------------------------------------------------------

    ; Set VGA Mode 13h
    mov ax, 0x0013
    int 0x10

    ; Initial draw
    mov ax, 100         ; X
    mov bx, 80          ; Y
    mov cx, 50          ; Width
    mov dx, 50          ; Height
    mov si, 14          ; Color
    call draw_rect

loop:
    inc word [bomb_y]

; Check keyboard via BIOS
check_input:
    mov ah, 0x01        ; BIOS function: Check keyboard buffer
    int 0x16
    jz move_player      ; If Zero Flag is set, no key is waiting, just update movement

    ; A key is waiting, read it so it clears from the buffer
    mov ah, 0x00
    int 0x16

    cmp al, 'a'         ; Lowercase 'a'
    je a_down
    cmp al, 'A'         ; Uppercase 'A'
    je a_down
    cmp al, 'd'         ; Lowercase 'd'
    je d_down
    cmp al, 'D'         ; Uppercase 'D'
    je d_down

move_player:
    cmp byte [a_held], 1
    jne check_d
    cmp word [player_x], 10
    jb render_frame
    sub word [player_x], 10

check_d:
    cmp byte [d_held], 1
    jne render_frame
    cmp word [player_x], 260
    ja render_frame
    add word [player_x], 10

render_frame:
    ; Clear screen (background)
    mov ax, 0
    mov bx, 0
    mov cx, 320
    mov dx, 200
    mov si, 15          ; White/Light Gray
    call draw_rect

    ; draw bomb
    mov ax, [bomb_x]
    mov bx, [bomb_y]
    mov cx, 30
    mov dx, 30
    mov si, 0          ; black
    call draw_rect

    ; Draw player
    mov ax, [player_x]
    mov bx, 80
    mov cx, 50
    mov dx, 50
    mov si, 14          ; Yellow
    call draw_rect

    ; Score counter
    mov ax, 0
    mov bx, 0
    mov cx, [score]
    mov dx, 5
    mov si, 10          ; lime
    call draw_rect

; is the player gonna die by touching a bomb?
die_cond:
    call check_collision
    cmp al, 1
    je game_over

bomb_spawn_cond:
    ; did the bomb fall all the way down?
    cmp word [bomb_y], 175
    je spawn_da_bomb

    jmp timerf

loop.3:
    jmp loop

game_over:
    mov ax, 0x0003 ; text mode
    int 0x10

    mov ax, 0xA000
    mov es, ax

    call .print_score_val

.halt_loop:
    cli
    hlt
    jmp .halt_loop

.print_score_val:
    ; Convert byte score to ASCII and print
    mov al, [score]
    add al, '0'         ; Simple single-digit ASCII conversion
    mov ah, 0x0E
    int 0x10
    ret

spawn_da_bomb:
    call random_number
    mov [bomb_x], ax
    mov [bomb_y], 0
    inc byte [score]

    jmp timerf

timerf:
    inc word [timer]
    cmp word [timer], 15000   ; Frame delay
    jb timerf
    mov word [timer], 0
    
    ; Optional: Simple release simulation for continuous movement testing
    ; (Since BIOS key-up events are tricky, tapping the key moves the player)
    mov byte [a_held], 0
    mov byte [d_held], 0
    
    jmp loop.3

a_down:
    mov byte [a_held], 1
    mov byte [d_held], 0    ; Clear opposite key
    jmp move_player

d_down:
    mov byte [d_held], 1
    mov byte [a_held], 0    ; Clear opposite key
    jmp move_player

a_held db 0
d_held db 0

; --------------------------------
; draw_rect (unchanged)
; --------------------------------

draw_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es

    mov [rect_x], ax
    mov [rect_y], bx
    mov [rect_w], cx
    mov [rect_h], dx
    mov ax, si
    mov [rect_color], al

    mov ax, 0xA000
    mov es, ax

    mov bx, [rect_y]
    mov bp, [rect_h]

    cld

.row:
    mov ax, bx
    mov dx, 320
    mul dx
    add ax, [rect_x]
    mov di, ax

    mov cx, [rect_w]
    mov al, [rect_color]
    rep stosb

    inc bx
    dec bp
    jnz .row

    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------
; Generates a pseudo-random number from 0 to 170 in AX
; Output: AX = random number
; --------------------------------
rand_seed dw 0

random_number:
    push dx
    
    ; LCG constants: Next = (25173 * seed + 13849)
    mov ax, [rand_seed]
    mov dx, 25173
    mul dx             ; DX:AX = AX * 25173
    add ax, 13849      ; Add constant
    mov [rand_seed], ax ; Save new seed
    
    xor dx,dx ; make sure division isnt drunk
    mov cx, 290
    div cx
    mov ax, dx

    pop dx
    ret

; --------------------------------
; Checks collision between player and bomb
; Returns: AL = 1 if colliding, AL = 0 if safe
; --------------------------------
check_collision:
    push dx

    ; 1. Check if player_right <= bomb_x
    mov ax, [player_x]
    add ax, 50              ; player_x + width (50)
    cmp ax, [bomb_x]
    jle .no_collision

    ; 2. Check if bomb_right <= player_x
    mov ax, [bomb_x]
    add ax, 30              ; bomb_x + width (30)
    cmp ax, [player_x]
    jle .no_collision

    ; 3. Check if player_bottom <= bomb_y
    mov ax, 50
    add ax, 50              ; player_y + height (50)
    cmp ax, [bomb_y]
    jle .no_collision

    ; 4. Check if bomb_bottom <= player_y
    mov ax, [bomb_y]
    add ax, 30              ; bomb_y + height (30)
    cmp ax, 50
    jle .no_collision

    ; If it passes all checks, they are overlapping!
    mov al, 1
    pop dx
    ret

.no_collision:
    mov al, 0
    pop dx
    ret

rect_x     dw 0
rect_y     dw 0
rect_w     dw 0
rect_h     dw 0
rect_color db 0

player_x   dw 160
bomb_x dw 0
bomb_y dw 0

score db 0
timer      dw 0

times 510-($-$$) db 0
dw 0xAA55