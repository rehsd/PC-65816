key_pressed:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ldx kb_rptr
    AND #$00FF      ; 16-bit adjustment to code

    lda kb_buffer, x
    AND #$00FF      ; 16-bit adjustment to code

    cmp #$0a           ; enter - go to next line
    beq enter_pressed
    cmp #$1b           ; escape - clear display
    beq esc_pressed

    jsr print_char_lcd
    jsr print_char_vga
    inc kb_rptr
    ;inc kb_rptr

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    bra loop_label
enter_pressed:
    ;*** lcd ***
    lda #%10101000 ; put cursor at position 40
    jsr lcd_instruction

    ;inc kb_rptr
    inc kb_rptr
    jmp loop_label 
esc_pressed:
    ;*** lcd ***
    lda #%00000001 ; Clear display
    jsr lcd_instruction
    ;inc kb_rptr
    inc kb_rptr
    jmp loop_label
Handle_KB_flags:
  ;TOOD :?: pha   ;remember A

  ;process arrow keys (would not have been handled in code above, as not ASCII codes)
  lda kb_flags

  ;bit #ARROW_UP   
  ;bne Handle_Arrow_Up
  
  ;bit #ARROW_LEFT 
  ;bne Handle_Arrow_Left
  
  ;bit #ARROW_RIGHT  
  ;bne Handle_Arrow_Right

  ;bit #ARROW_DOWN   
  ;bne Handle_Arrow_Down

  ;bit #NKP5      
  ;bne Handle_NKP5

  ;bit #NKP_PLUS
  ;bne Handle_NKP_Plus

  jmp Handle_KB_flags2
Handle_Arrow_Up:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    lda kb_flags
    eor #ARROW_UP  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    jmp loop_label
Handle_Arrow_Left:

    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    lda kb_flags
    eor #ARROW_LEFT  ; flip the left arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_Arrow_Right:

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    lda kb_flags
    eor #ARROW_RIGHT  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_Arrow_Down:

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    lda kb_flags
    eor #ARROW_DOWN  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_NKP5:
    ;put items on stack, so we can return them
    pha ;a to stack

    lda kb_flags
    eor #NKP5  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    pla ;stack to a

    jmp loop_label
Handle_NKP_Plus:

      lda kb_flags
      eor #NKP_PLUS  ; flip the left arrow bit
      sta kb_flags
      jmp loop_label
Handle_NKP_Insert:
    lda kb_flags2
    eor #NKP_INSERT
    sta kb_flags2
    jmp loop_label
Handle_KB_flags2:
  lda kb_flags2

  ;bit #NKP_INSERT
  ;bne Handle_NKP_Insert

  ;bit #NKP_DELETE
  ;bne Handle_NKP_Delete

  ;bit #NKP_MINUS
  ;bne Handle_NKP_Minus

  ;bit #NKP_ASTERISK
  ;bne Handle_NKP_Asterisk

  ;bit #PRINTSCREEN
  ;bne Handle_PrintScreen
  
  jmp loop_label
Handle_NKP_Delete:
    lda kb_flags2
    eor #NKP_DELETE
    sta kb_flags2
    jmp loop_label
Handle_NKP_Minus:
    lda kb_flags2
    eor #NKP_MINUS
    sta kb_flags2
    jmp loop_label
Handle_NKP_Asterisk:
    ;draw region   

    lda kb_flags2
    eor #NKP_ASTERISK
    sta kb_flags2
    jmp loop_label
Handle_PrintScreen:
    ;sei     //turn off interrupts
    lda kb_flags2
    eor #PRINTSCREEN
    sta kb_flags2
    ;cli
    jmp loop_label
shift_up:
  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code

  eor #SHIFT  ; flip the shift bit
  sta kb_flags
  jmp irq_done
key_release:
  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code

  ora #RELEASE
  AND #$00FF      ; 16-bit adjustment to code

  sta kb_flags
  AND #$00FF      ; 16-bit adjustment to code
  jmp irq_done
shift_down:
  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code

  ora #SHIFT
  sta kb_flags
  jmp irq_done
arrow_left_down:
  lda kb_flags
  ora #ARROW_LEFT
  sta kb_flags
  jmp irq_done
arrow_up_down:
  lda kb_flags
  ora #ARROW_UP
  sta kb_flags
  jmp irq_done
nkp5_down:
  lda kb_flags
  ora #NKP5
  sta kb_flags
  jmp irq_done
nkpinsert_down:
  lda kb_flags2
  ora #NKP_INSERT
  sta kb_flags2
  jmp irq_done
nkpdelete_down:
  lda kb_flags2
  ora #NKP_DELETE
  sta kb_flags2
  jmp irq_done
nkpminus_down:
  lda kb_flags2
  ora #NKP_MINUS
  sta kb_flags2
  jmp irq_done
nkpasterisk_down:
  lda kb_flags2
  ora #NKP_ASTERISK
  sta kb_flags2
  jmp irq_done
printscreen_down:
  lda kb_flags2
  ora #PRINTSCREEN
  sta kb_flags2
  jmp irq_done
keyscan_ignore:
  jmp irq_done
shifted_key:
  lda keymap_shifted, x   ; map to character code
  AND #$00FF      ; 16-bit adjustment to code

  ;fall into push_key
push_key:
  ldx kb_wptr
  ;AND #$00FF      ; 16-bit adjustment to code   ;***IMPORTANT***

  sta kb_buffer, x
  ;inc kb_wptr
  inc kb_wptr
  jmp irq_done
read_key:
  lda VIA1_PORTA
  AND #$00FF      ; 16-bit adjustment to code   ;***IMPORTANT***
  
  ;jsr print_dec_lcd ;***

  cmp #$00F0        ; if releasing a key
  beq key_release ; set the releasing bit
  cmp #$12        ; left shift
  beq shift_down
  cmp #$59        ; right shift
  beq shift_down
  ;cmp #$6b           ; left arrow
  ;beq arrow_left_down
  ;cmp #$74           ; right arrow
  ;beq arrow_right_down
  ;cmp #$75           ; up arrow
  ;beq arrow_up_down
  ;cmp #$72           ; down arrow
  ;beq arrow_down_down
  ;cmp #$73           ; numberic keypad '5'
  ;beq nkp5_down
  ;cmp #$79           ; numeric keypad '+'
  ;beq nkpplus_down
  ;cmp #$70           ; numeric keypad insert
  ;beq nkpinsert_down
  ;cmp #$71           ; numeric keypad delete
  ;beq nkpdelete_down
  ;cmp #$7b           ; numeric keypay minus
  ;beq nkpminus_down
  ;cmp #$7c           ; numeric keypad asterisk
  ;beq nkpasterisk_down
  ;cmp #$07           ; F12
  ;beq printscreen_down
  cmp #$E0           ;trying to filter out '?' 0xe0 from printscreen key
  beq keyscan_ignore

  AND #$00FF      ; 16-bit adjustment to code
  tax
  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code

  and #SHIFT
  bne shifted_key

  lda keymap, x   ; map to character code ;******
  AND #$00FF      ; 16-bit adjustment to code
  
  jmp push_key

nkpplus_down:
  lda kb_flags
  ora #NKP_PLUS
  sta kb_flags
  jmp irq_done
arrow_down_down:
  lda kb_flags
  ora #ARROW_DOWN
  sta kb_flags
  jmp irq_done
arrow_right_down:
  lda kb_flags
  ora #ARROW_RIGHT
  sta kb_flags
  jmp irq_done


