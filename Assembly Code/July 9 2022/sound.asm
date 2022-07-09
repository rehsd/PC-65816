;Sound card to system on IRQ 7

sound_init:
    rep #$20  ;set acumulator to 16-bit
    .setting "RegA16", true
    rts
sound_raise_interrupt_on_card:
    .setting "RegA16", false
    pha
    sep #$20            ;set acumulator to 8-bit

    ;set interrupt to trigger sound card to read the value
    //lda #0  ;assuming no other values set on this port yet -- TO DO: AND out the bit
    lda VIA1_PORTB
    and #%11111110
    sta VIA1_PORTB

    //lda #IRQ_SOUND_CARD  ;bring it back high to turn off interrupt
    eor #%00000001
    sta VIA1_PORTB

    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit
    pla
    rts
music_start:
    ;Start menu item for MUSIC
        ;if we made it to this point, tests have passed
    //jsr video_init_skipTestPattern  //clear start menu (redraw screen)

    ;remember previous pixel location before drawing
    lda fill_region_start_x
    sta pixel_prev_x
    lda fill_region_start_y
    sta pixel_prev_y
    
    lda #0 ;black
    jsr gfx_FillScreenTILES  
    jsr gfx_DrawStartButton
    jsr gfx_Render_Full_Page
    lda #%11111111  ;white text
    sta char_color
    lda #$00
    sta char_y_offset
    lda #$05
    sta char_vp_x    ;0 to 319
    lda #$19  ;#25
    sta char_vp_y    ;0 to 239
    //jsr gfx_SetCharVpByXY
    jsr gfx_SetCharVpByXY_TILES
    lda #$0D  ;#13     ;pass message
    sta message_to_process
    jsr PrintString
    lda #0  //turn off message strings, back to single char keyboard input
    sta message_to_process

    ;restore previous location
    lda pixel_prev_x
    sta fill_region_start_x
    lda pixel_prev_y
    sta fill_region_start_y
    
    rts