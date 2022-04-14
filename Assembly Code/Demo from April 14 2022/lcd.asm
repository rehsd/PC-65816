lcd_wait:
  pha
  lda #%11110000  ; LCD data is input       ;8042
  sta VIA1_DDRB
lcdbusy:
  lda #RW
  sta VIA1_PORTB
  lda #(RW | E)                             ;805A
  sta VIA1_PORTB
  lda VIA1_PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta VIA1_PORTB
  lda #(RW | E)
  sta VIA1_PORTB
  lda VIA1_PORTB       ; Read low nibble    ;8074
  pla             ; Get high nibble off stack
  and #%00001000                            
  bne lcdbusy                               ;807C

  lda #RW
  sta VIA1_PORTB
  lda #%11111111  ; LCD data is output
  sta VIA1_DDRB                             ;8088
  pla
  rts
lcd_init:
  ;wait a bit before initializing the screen - helpful at higher 6502 clock speeds
  jsr  Delay

  ;see page 42 of https://eater.net/datasheets/HD44780.pdf
  lda #%00000010 ; Set 4-bit mode
  sta VIA1_PORTB
  ;jsr  Delay
  ora #E
  sta VIA1_PORTB
  ;jsr  Delay
  and #%00001111
  sta VIA1_PORTB

  rts
lcd_instruction:
  ;send an instruction to the 2-line LCD
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta VIA1_PORTB
  ora #E         ; Set E bit to send instruction
  sta VIA1_PORTB
  eor #E         ; Clear E bit
  sta VIA1_PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta VIA1_PORTB
  ora #E         ; Set E bit to send instruction
  sta VIA1_PORTB
  eor #E         ; Clear E bit
  sta VIA1_PORTB
  rts
print_char_lcd:
  ;print a character on the 2-line LCD
  jsr lcd_wait
  pha                                       ;80E1
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta VIA1_PORTB
  ora #E          ; Set E bit to send instruction
  sta VIA1_PORTB
  eor #E          ; Clear E bit
  sta VIA1_PORTB
  pla
  pha
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta VIA1_PORTB
  ora #E          ; Set E bit to send instruction
  sta VIA1_PORTB
  eor #E          ; Clear E bit
  sta VIA1_PORTB
  pla
  rts

print_hex_lcd:
    ;convert scancode/ascii value/other hex to individual chars and display
    ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    sta $4A ;$65     ;store A so we can keep using original value
    
    ;lda #$30    ;'0'
    ;jsr print_char_lcd
    lda #$78    ;'x'
    jsr print_char_lcd

    ;high nibble
    lda $4A
    and #%0000000011110000
    lsr ;shift high nibble to low nibble
    lsr
    lsr
    lsr
    tay
    lda hexOutLookup, y
    AND #$00FF      ; 16-bit adjustment to code

    jsr print_char_lcd

    ;low nibble
    lda $4A
    and #%0000000000001111
    tay
    lda hexOutLookup, y
    AND #$00FF      ; 16-bit adjustment to code
    jsr print_char_lcd

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts


hexOutLookup: .byte "0123456789ABCDEF"
