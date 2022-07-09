  .setting "RegA16", false

//commented out as this card has been removed from the system -- using SPI LCD instead

// lcd_wait:
//   pha
//   lda #%11110000  ; LCD data is input
//   sta VIA2_DDRA
// lcdbusy:
//   lda #RW
//   sta VIA2_PORTA
//   lda #(RW | E)                           
//   sta VIA2_PORTA
//   lda VIA2_PORTA       ; Read high nibble
//   pha             ; and put on stack since it has the busy flag
//   lda #RW
//   sta VIA2_PORTA
//   lda #(RW | E)
//   sta VIA2_PORTA
//   lda VIA2_PORTA       ; Read low nibble   
//   pla             ; Get high nibble off stack
//   and #%00001000                            
//   bne lcdbusy                              

//   lda #RW
//   sta VIA2_PORTA
//   lda #%11111111  ; LCD data is output
//   sta VIA2_DDRA                            
//   pla
  
//   rts
// lcd_init:
//   //.setting "RegA16", false
//   sep #$20            ;set acumulator to 8-bit
    
//   //jsr  Delay
//   ;see page 42 of https://eater.net/datasheets/HD44780.pdf
//   lda #%00000010 ; Set 4-bit mode
//   sta VIA2_PORTA
//   ora #E
//   sta VIA2_PORTA
//   and #%00001111
//   sta VIA2_PORTA

//   //.setting "RegA16", true
//   rep #$20            ;set acumulator to 16-bit
  
//   rts
// lcd_instruction:
//   sep #$20            ;set acumulator to 8-bit

//   ;send an instruction to the 2-line LCD
//   jsr lcd_wait
//   pha
//   lsr
//   lsr
//   lsr
//   lsr            ; Send high 4 bits
//   sta VIA2_PORTA
//   ora #E         ; Set E bit to send instruction
//   sta VIA2_PORTA
//   eor #E         ; Clear E bit
//   sta VIA2_PORTA
//   pla
//   and #%00001111 ; Send low 4 bits
//   sta VIA2_PORTA
//   ora #E         ; Set E bit to send instruction
//   sta VIA2_PORTA
//   eor #E         ; Clear E bit
//   sta VIA2_PORTA

//   rep #$20            ;set acumulator to 16-bit

//   rts
// lcd_clear:
//   pha

//   sep #$30            ;set acumulator to 8-bit

//   lda #%00000001 ; Clear display
//   jsr lcd_instruction

//   rep #$30            ;set acumulator to 16-bit

//   pla
//   rts
// lcd_line2:
//   pha
//   sep #$30            ;set acumulator to 8-bit

//   lda #%10101000 ; put cursor at position 40
//   jsr lcd_instruction
//   rep #$30            ;set acumulator to 16-bit
//   pla
//   rts
// print_char_lcd:
//   .setting "RegA16", false
//   sep #$30            ;set acumulator to 8-bit
  
//   ;print a character on the 2-line LCD
//   jsr lcd_wait
//   pha                                      
//   lsr
//   lsr
//   lsr
//   lsr             ; Send high 4 bits
//   ora #RS         ; Set RS
//   sta VIA2_PORTA
//   ora #E          ; Set E bit to send instruction
//   sta VIA2_PORTA
//   eor #E          ; Clear E bit
//   sta VIA2_PORTA
//   pla
//   pha
//   and #%00001111  ; Send low 4 bits
//   ora #RS         ; Set RS
//   sta VIA2_PORTA
//   ora #E          ; Set E bit to send instruction
//   sta VIA2_PORTA
//   eor #E          ; Clear E bit
//   sta VIA2_PORTA
//   pla

//   rep #$30            ;set acumulator to 16-bit

//   rts
// print_hex_lcd:
  
//   pha ;a to stack
//   phx ;x to stack
//   phy ;y to stack

//   .setting "RegA16", false
//   .setting "RegXY16", false
//   sep #$30            ;set acumulator to 8-bit

//   ;convert scancode/ascii value/other hex to individual chars and display
//   ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
//   ;accumulator has the value of the scancode

//   sta TMP   ;$65     ;store A so we can keep using original value

//   ;lda #$30    ;'0'
//   ;jsr print_char_lcd
//   lda #'x'  // #$78    ;'x'
//   jsr print_char_lcd
//   sep #$30            ;set acumulator to 8-bit
//   // lda #'x'  // #$78    ;'x'
//   // jsr print_char_lcd
//   // sep #$30            ;set acumulator to 8-bit

//   ;high nibble
//   lda TMP
//   // jsr print_char_lcd
//   // sep #$30            ;set acumulator to 8-bit
//   and #%11110000
//   lsr ;shift high nibble to low nibble
//   lsr
//   lsr
//   lsr
//   tax
//   lda hexOutLookup, x
//   jsr print_char_lcd
//   sep #$30            ;set acumulator to 8-bit

//   ;low nibble
//   lda TMP
//   and #%00001111
//   tax
//   lda hexOutLookup, x
//   jsr print_char_lcd
//   sep #$30            ;set acumulator to 8-bit

//   rep #$30            ;set acumulator to 16-bit

//   ;return items from stack
//   ply ;stack to y
//   plx ;stack to x
//   pla ;stack to a
//   rts
// print_hex_lcd_16:
//   pha ;a to stack
//   phx ;x to stack
//   phy ;y to stack

//   sta TMP2
//   and #$FF00
//   lsr
//   lsr
//   lsr
//   lsr
//   lsr
//   lsr
//   lsr
//   lsr
//   jsr print_hex_lcd

//   lda TMP2
//   and #$00FF
//   jsr print_hex_lcd

//   ply ;stack to y
//   plx ;stack to x
//   pla ;stack to a
//   rts



// //.setting "RegA16", false
// //.setting "RegXY16", false  
hexOutLookup: .byte "0123456789ABCDEF"
