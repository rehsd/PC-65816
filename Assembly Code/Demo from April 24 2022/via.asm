via_init:
    ;Set compiler to store numbers in 8-bit (one byte in ROM)
    .setting "RegA16", false
    sep #$20            ;set acumulator to 8-bit

    ;VIA config
    ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    lda #%01111111	        ; Disable all interrupts
    sta VIA1_IER
    sta VIA2_IER
    sta VIA3_IER

    lda #%00000000          ;input
    sta VIA1_DDRA           ; Set all pins on port A to input       ;Keyboard
    lda VIA1_PORTA
    lda #%11111111 
    sta VIA1_DDRB           ; Set all pins on port B to output

    lda #%11111111          ;output
    sta VIA2_DDRA           ; Set all for LCD to output         ;LCD
    sta VIA2_DDRB           ; Set all for bar graph to output   ;bar graph

    lda #%00000000          ;input
    sta VIA3_DDRA           ; Set all pins on port A to input       ;unused
    sta VIA3_DDRB           ; Set all pins on port A to input       ;USB mouse

    ; bar graph
    lda #%00000001
    sta barGraphVal
    sta VIA2_PORTB

    barRight:
        jsr Delay0
        .setting "RegA16", false
        sep #$20            ;set acumulator to 8-bit
        lda barGraphVal
        asl
        sta barGraphVal
        sta VIA2_PORTB
        bne barRight

                            ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    lda #%10000010	        ; Enable CA1 interrupt (keyboard)
    sta VIA1_IER
    lda #%10010000	        ; Enable CB1 interrupt (USB mouse)
    sta VIA3_IER

    .setting "RegA16", true
     rep #$20            ;set acumulator to 16-bit

    ; ******* LCD *******
    ;see page 42 of https://eater.net/datasheets/HD44780.pdf
    ;when running 6502 at ~5.0 MHz (versus 1.0 MHz), sometimes init needs additional call or delay
    jsr lcd_init

    lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
    jsr lcd_instruction

    ;call again for higher clock speed setup (helps when resetting the system)
    lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
    jsr lcd_instruction

    lda #%00001110 ; Display on; cursor on; blink off
    jsr lcd_instruction

    lda #%00000110 ; Increment and shift cursor; don't shift display
    jsr lcd_instruction
    lda #%00000001 ; Clear display
    jsr lcd_instruction
    lda #%00001110 ; Display on; cursor on; blink off
    jsr lcd_instruction

    lda #$52    ;'R'
    jsr print_char_lcd
    lda #$65    ;'e'
    jsr print_char_lcd
    lda #$61    ;'a'
    jsr print_char_lcd
    lda #$64    ;'d'
    jsr print_char_lcd
    lda #$79    ;'y'
    jsr print_char_lcd

    lda #%10101000 ; put cursor at position 40
    jsr lcd_instruction

    lda #$3E    ;'>'
    jsr print_char_lcd

    rts