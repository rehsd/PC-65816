  .setting "RegA16", false

lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta VIA2_DDRA
lcdbusy:
  lda #RW
  sta VIA2_PORTA
  lda #(RW | E)                           
  sta VIA2_PORTA
  lda VIA2_PORTA       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta VIA2_PORTA
  lda #(RW | E)
  sta VIA2_PORTA
  lda VIA2_PORTA       ; Read low nibble   
  pla             ; Get high nibble off stack
  and #%00001000                            
  bne lcdbusy                              

  lda #RW
  sta VIA2_PORTA
  lda #%11111111  ; LCD data is output
  sta VIA2_DDRA                            
  pla
  
  rts
lcd_init:
  //.setting "RegA16", false
  sep #$20            ;set acumulator to 8-bit
    
  //jsr  Delay
  ;see page 42 of https://eater.net/datasheets/HD44780.pdf
  lda #%00000010 ; Set 4-bit mode
  sta VIA2_PORTA
  ora #E
  sta VIA2_PORTA
  and #%00001111
  sta VIA2_PORTA

  //.setting "RegA16", true
  rep #$20            ;set acumulator to 16-bit
  
  rts
lcd_instruction:
  sep #$20            ;set acumulator to 8-bit

  ;send an instruction to the 2-line LCD
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta VIA2_PORTA
  ora #E         ; Set E bit to send instruction
  sta VIA2_PORTA
  eor #E         ; Clear E bit
  sta VIA2_PORTA
  pla
  and #%00001111 ; Send low 4 bits
  sta VIA2_PORTA
  ora #E         ; Set E bit to send instruction
  sta VIA2_PORTA
  eor #E         ; Clear E bit
  sta VIA2_PORTA

  rep #$20            ;set acumulator to 16-bit

  rts
print_char_lcd:
  sep #$20            ;set acumulator to 8-bit
  
  ;print a character on the 2-line LCD
  jsr lcd_wait
  pha                                      
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta VIA2_PORTA
  ora #E          ; Set E bit to send instruction
  sta VIA2_PORTA
  eor #E          ; Clear E bit
  sta VIA2_PORTA
  pla
  pha
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta VIA2_PORTA
  ora #E          ; Set E bit to send instruction
  sta VIA2_PORTA
  eor #E          ; Clear E bit
  sta VIA2_PORTA
  pla

  //.setting "RegA16", true
  rep #$20            ;set acumulator to 16-bit

  rts

print_hex_lcd:
  sep #$20            ;set acumulator to 8-bit

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

  rep #$20            ;set acumulator to 16-bit

  rts


hexOutLookup: .byte "0123456789ABCDEF"
