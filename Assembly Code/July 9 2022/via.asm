;VIA info from vars.asm:
;   I/O 10:0000                 0x100000-0x10FFFF           64K
;     VIA1 (PS2 KBD, SPI, Timer)    0x108000-0x10800F
;     VIA2 (LCD, BARGRAPH)	        0x104000-0x10400F
;     VIA3 (USB MOUSE)		        0x102000-0x10200F
;     VIA4 (Joystick, NES ctlr)     0x101000-0x10100F
;     VIA5 (VIA test add-in card)   0x100800-0x10080F
;     SOUND CARD			        0x100000-0x1007FF

via_init:
    ;Set compiler to store numbers in 8-bit (one byte in ROM)
    .setting "RegA16", false
    sep #$20            ;set acumulator to 8-bit

    ;VIA config
    ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    lda #%01111111	        ; Disable all interrupts
    sta VIA1_IER
    //sta VIA2_IER
    sta VIA3_IER
    sta VIA4_IER
    sta VIA5_IER

    lda #%00000000          ;input
    sta VIA1_DDRA           ; Set all pins on port A to input       ;Keyboard
    lda VIA1_PORTA          // TO DO needed for keybard ghost key?
    lda #%11111111 
    sta VIA1_DDRB           ; Set all pins on port B to output
    lda #IRQ_SOUND_CARD
    sta VIA1_PORTB

    // lda #%11111111          ;output
    // sta VIA2_DDRA           ; Set all for LCD to output         ;LCD
    // sta VIA2_DDRB           ; Set all for bar graph to output   ;bar graph

    lda #%00000000          ;input
    sta VIA3_DDRA           ; Set all pins on port A to input       ;unused
    sta VIA3_DDRB           ; Set all pins on port A to input       ;USB mouse

    lda #%00000000          ;input
    sta VIA4_DDRA           ;joystick
    sta VIA4_DDRA           ;NES
    

    // ; bar graph
    // lda #%00000000
    // ;lda #%00000001
    // sta barGraphVal
    // sta VIA2_PORTB
    // barRight:
        //     jsr Delay0
        //     .setting "RegA16", false
        //     sep #$20            ;set acumulator to 8-bit
        //     lda barGraphVal
        //     asl
        //     sta barGraphVal
        //     sta VIA2_PORTB
        //     bne barRight

                            ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2

    lda #$FF
    sta VIA1_T1C_L
    sta VIA1_T1C_H
    lda #%01000000          ;continuous interrupts (T1); disable T2, shift register, and latch
    sta VIA1_ACR
    //lda #%11000010	        ; Enable Timer1, CA1 interrupt (keyboard)
    lda #%10000010	        ; Enable CA1 interrupt (keyboard)
    sta VIA1_IER

    ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    lda #%10010000	        ; Enable CB1 interrupt (USB mouse)
    sta VIA3_IER
    //lda #%10010010	        ; Enable CA1 interrupt (joystick), CB1 (NES controller)
    //lda #%10000010	        ; Enable CA1 interrupt (joystick), CB1 (NES controller)
    lda #%01111111              ; Disable joystick and controller interrupts
    sta VIA4_IER



    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    // ; ******* LCD *******
        //     ;see page 42 of https://eater.net/datasheets/HD44780.pdf
        //     ;when running 6502 at ~5.0 MHz (versus 1.0 MHz), sometimes init needs additional call or delay
        //     jsr lcd_init

        //     lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
        //     jsr lcd_instruction

        //     ;call again for higher clock speed setup (helps when resetting the system)
        //     lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
        //     jsr lcd_instruction

        //     lda #%00001110 ; Display on; cursor on; blink off
        //     jsr lcd_instruction

        //     lda #%00000110 ; Increment and shift cursor; don't shift display
        //     jsr lcd_instruction
        //     lda #%00000001 ; Clear display
        //     jsr lcd_instruction
        //     lda #%00001110 ; Display on; cursor on; blink off
        //     jsr lcd_instruction

        //     lda #$52    ;'R'
        //     jsr print_char_lcd
        //     lda #$65    ;'e'
        //     jsr print_char_lcd
        //     lda #$61    ;'a'
        //     jsr print_char_lcd
        //     lda #$64    ;'d'
        //     jsr print_char_lcd
        //     lda #$79    ;'y'
        //     jsr print_char_lcd

        //     lda #%10101000 ; put cursor at position 40
        //     jsr lcd_instruction

        //     lda #$3E    ;'>'
        //     jsr print_char_lcd

    rts

via_test_start:
    ;remember previous pixel location before drawing
    lda fill_region_start_x
    sta pixel_prev_x
    lda fill_region_start_y
    sta pixel_prev_y

    ;jsr video_init_skipTestPattern

    // lda #5
    // sta fill_region_start_x
    // lda #5
    // sta fill_region_start_y
    // lda #%11111111  ;white
    // sta fill_region_color
    // lda #%00100101
    // sta pixel_prev_color
    // lda #0
    // sta currently_drawing
    // jsr gfx_DrawPixel

    lda #%00001100 ;mid-green
    jsr gfx_FillScreenTILES  
    jsr gfx_DrawStartButton
    jsr gfx_Render_Full_Page

    lda #%11111111
    sta char_color

    lda #$00
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #5
    sta char_vp_y    ;0 to 239
    //jsr gfx_SetCharVpByXY
    jsr gfx_SetCharVpByXY_TILES
    lda #09
    sta message_to_process
    jsr PrintString
    
    lda #$00
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #15
    sta char_vp_y    ;0 to 239
    //jsr gfx_SetCharVpByXY
    jsr gfx_SetCharVpByXY_TILES
    lda #10
    sta message_to_process
    jsr PrintString

    lda #00
    sta message_to_process

    jsr via_test1

    ;restore previous location
    lda pixel_prev_x
    sta fill_region_start_x
    lda pixel_prev_y
    sta fill_region_start_y
  
    rts
via_test1:          //basic test
    .setting "RegA16", false
    sep #$20            ;set acumulator to 8-bit

    ;A to B
        lda #$FF
        sta VIA5_DDRA      ;out
        lda #$00
        sta VIA5_DDRB      ;in

        //test 0
        lda #%00000000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00000000
        bne viaFail

        //test 1
        lda #%00000001
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00000001
        bne viaFail

        //test 2
        lda #%00000010
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00000010
        bne viaFail

        //test 4
        lda #%00000100
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00000100
        bne viaFail

        //test 8
        lda #%00001000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00001000
        bne viaFail

        //test 16
        lda #%00010000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00010000
        bne viaFail

        //test 32
        lda #%00100000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%00100000
        bne viaFail

        //test 64
        lda #%01000000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%01000000
        bne viaFail

        //test 128
        lda #%10000000
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%10000000
        bne viaFail
            
        //test 255
        lda #%11111111
        sta VIA5_PORTA
        lda VIA5_PORTB
        cmp #%11111111
        bne viaFail

    ;B to A
        lda #$00
        sta VIA5_DDRA      ;in
        lda #$FF
        sta VIA5_DDRB      ;out

        //test 0
        lda #%00000000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00000000
        bne viaFail

        //test 1
        lda #%00000001
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00000001
        bne viaFail

        //test 2
        lda #%00000010
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00000010
        bne viaFail

        //test 4
        lda #%00000100
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00000100
        bne viaFail

        //test 8
        lda #%00001000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00001000
        bne viaFail

        //test 16
        lda #%00010000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00010000
        bne viaFail

        //test 32
        lda #%00100000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%00100000
        bne viaFail

        //test 64
        lda #%01000000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%01000000
        bne viaFail

        //test 128
        lda #%10000000
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%10000000
        bne viaFail
            
        //test 255
        lda #%11111111
        sta VIA5_PORTB
        lda VIA5_PORTA
        cmp #%11111111
        bne viaFail

    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    ;if we made it to this point, tests have passed
    lda #%00011100  ;green
    sta char_color
    lda #$00
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #25
    sta char_vp_y    ;0 to 239
    //jsr gfx_SetCharVpByXY
    jsr gfx_SetCharVpByXY_TILES
    lda #11     ;pass message
    sta message_to_process
    jsr PrintString
    jmp test1_out

    viaFail:
        rep #$20            ;set acumulator to 16-bit

        lda #%11100000  ;red
        sta char_color
        lda #$00
        sta char_y_offset
        lda #5
        sta char_vp_x    ;0 to 319
        lda #25
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda #12     ;fail message
        sta message_to_process
        jsr PrintString

    test1_out:
    lda #0
    sta message_to_process
    rts