.setting "HandleLongBranch", true

Mouse_Interrupt_Handler:
    ;Only using interrupts for PortB - don't need to check port source

    ;sep #$20            ;set acumulator to 8-bit
    lda VIA3_PORTB                ;clear interrupt
    and #$00FF                    ;16-bit adjustment
    sta tmpMouseInterrupt         ;store original value read from port
    and #%00111100                ;the bits used for mouse move
    sta tmpMouseInterruptMasked   ;store masked portion for mouse move

    eor #MOUSE_LEFT
    beq Handle_Mouse_Left

    lda tmpMouseInterruptMasked
    eor #MOUSE_UP
    beq Handle_Mouse_Up

    lda tmpMouseInterruptMasked
    eor #MOUSE_RIGHT
    beq Handle_Mouse_Right

    lda tmpMouseInterruptMasked
    eor #MOUSE_DOWN
    beq Handle_Mouse_Down

    lda tmpMouseInterruptMasked
    eor #MOUSE_LEFT_UP
    beq Handle_Mouse_Left_Up

    lda tmpMouseInterruptMasked
    eor #MOUSE_RIGHT_UP
    beq Handle_Mouse_Right_Up

    lda tmpMouseInterruptMasked
    eor #MOUSE_RIGHT_DOWN
    beq Handle_Mouse_Right_Down

    lda tmpMouseInterruptMasked
    eor #MOUSE_LEFT_DOWN
    beq Handle_Mouse_Left_Down

    lda tmpMouseInterrupt ;get original info from port read - need to check for mouse buttons

    and #%00000011      ;mouse button mask
    sta tmpMouseInterruptMasked

    eor #MOUSE_CLICK_LEFT
    beq Handle_Mouse_Click_Left

    lda tmpMouseInterruptMasked
    eor #MOUSE_CLICK_MIDDLE
    beq Handle_Mouse_Click_Middle

    lda tmpMouseInterruptMasked
    eor #MOUSE_CLICK_RIGHT
    beq Handle_Mouse_Click_Right
      
    rts //shouldn't get here
Handle_Mouse_Left_Up:
    ;jsr DisplayXYonLCD
    ldx fill_region_start_x
    cpx #$0006          ;left side margin to a) keep mouse in bounds and to prevent a negative x pos (more safety code needed)
    bmi hmlu_out
    dex
    dex
    stx fill_region_start_x

    ;subtract from fill_region_start_y to move the pixel up
    ldx fill_region_start_y
    cpx #$0006
    bmi hmlu_out
    dex 
    dex 
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer
    hmlu_out:
    rts
Handle_Mouse_Left_Down:
    ;jsr DisplayXYonLCD

    ldx fill_region_start_x
    cpx #$0006          ;left side margin to a) keep mouse in bounds and to prevent a negative x pos (more safety code needed)
    bmi hmld_out
    dex
    dex
    stx fill_region_start_x

    ;add to fill_region_start_y to move the pixel down
    ldx fill_region_start_y
    cpx #$00EB      ;bottom screen margin
    bpl hmld_out     ;at bounds, don't move mouse further
    inx  
    inx  
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer

    hmld_out:
    rts
Handle_Mouse_Right_Down:
    ;jsr DisplayXYonLCD
    ;add to fill_region_start_x to move the pixel right
    ldx fill_region_start_x
    cpx #$013C      ;right screen margin
    bpl hmrd_out
    inx
    inx
    stx fill_region_start_x
    jsr StorePrevPixelInfo

    ;add to fill_region_start_y to move the pixel down
    ldx fill_region_start_y
    cpx #$00EB      ;bottom screen margin
    bpl hmrd_out     ;at bounds, don't move mouse further
    inx  
    inx  
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer
    hmrd_out:
    rts
Handle_Mouse_Right_Up:
    ;jsr DisplayXYonLCD

    ldx fill_region_start_x
    cpx #$0136      ;310
    bpl hmru_out
    inx
    inx
    stx fill_region_start_x

    ;subtract from fill_region_start_y to move the pixel up
    ldx fill_region_start_y
    cpx #$0006
    bmi hmru_out
    dex 
    dex 
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer
    hmru_out:
    rts
Handle_Mouse_Down:
    ;jsr DisplayXYonLCD

    ;add to fill_region_start_y to move the pixel down
    ldx fill_region_start_y
    cpx #$00EB      ;bottom screen margin
    bpl hmd_out     ;at bounds, don't move mouse further
    inx  
    inx  
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer

    hmd_out:
    rts
Handle_Mouse_Left:
    ;jsr DisplayXYonLCD
    ldx fill_region_start_x
    cpx #$0006          ;left side margin to a) keep mouse in bounds and to prevent a negative x pos (more safety code needed)
    bmi hml_out
    dex
    dex
    stx fill_region_start_x

    jsr RestoreTile
    jsr DrawMousePointer
    hml_out:
    rts
Handle_Mouse_Up:
    //jsr DisplayXYonLCD

    ;subtract from fill_region_start_y to move the pixel up
    ldx fill_region_start_y
    cpx #$0006
    bmi hmu_out
    dex
    dex
    stx fill_region_start_y

    jsr RestoreTile
    jsr DrawMousePointer
    hmu_out:
    rts   
Handle_Mouse_Right:
    ;jsr DisplayXYonLCD
    
    ;add to fill_region_start_x to move the pixel right
    ldx fill_region_start_x
    cpx #$013C
    bpl hmru_out
    inx
    inx
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    
    jsr RestoreTile
    jsr DrawMousePointer

    rts
Handle_Mouse_Click_Left:
    ;lda #$F000  ;start counting up at this value; higher # = shorter delay
    ;sta delayDuration
    ;jsr Delay
    ;jsr Delay0

    ;fill_region_start_x between 7 and 41
    ;fill_region_start_y between 226 and 239
    ;obj_mask_start_btn
    ;   0000x000 = right of left edge
    ;   00000x00 = left of right edge
    ;   000000x0 = below top edge
    ;   0000000x = above bottom edge
    ;   00001111 = within button

    ;*** Start button click check ***

    //check for click of Start button
    //TO DO turn this into a resuable procedure to check pixel within bounds of an object
    stz obj_mask_start_btn
    lda fill_region_start_x
    cmp #7
    bcc regionCheck1
    lda obj_mask_start_btn
    clc
    adc #%00001000
    sta obj_mask_start_btn
    regionCheck1:
    lda fill_region_start_x
    cmp #41
    bcs regionCheck2
    lda obj_mask_start_btn
    clc
    adc #%00000100
    sta obj_mask_start_btn
    regionCheck2:
    lda fill_region_start_y
    cmp #226
    bcc regionCheck3
    lda obj_mask_start_btn
    clc
    adc #%00000010
    sta obj_mask_start_btn
    regionCheck3:
    lda fill_region_start_y
    cmp #239
    bcs regionCheckOut
    lda obj_mask_start_btn
    clc
    adc #%00000001
    sta obj_mask_start_btn

    regionCheckOut:
    lda obj_mask_start_btn
    cmp #%00001111
    bne check_for_item_music  //start wasn't clicked, check for menu item clicks, starting with the first one to follow
    jsr gfx_DrawStartMenu
    bra hmc_out

    ;*** /Start button click check ***

    ;Menu item check *** MUSIC ***
        check_for_item_music:
            stz obj_mask_start_btn
            lda fill_region_start_x
            cmp #5
            bcc regionCheck1_itemMusic
            lda obj_mask_start_btn
            clc
            adc #%00001000
            sta obj_mask_start_btn
            regionCheck1_itemMusic:
            lda fill_region_start_x
            cmp #60
            bcs regionCheck2_itemMusic
            lda obj_mask_start_btn
            clc
            adc #%00000100
            sta obj_mask_start_btn
            regionCheck2_itemMusic:
            lda fill_region_start_y
            cmp #205
            bcc regionCheck3_itemMusic
            lda obj_mask_start_btn
            clc
            adc #%00000010
            sta obj_mask_start_btn
            regionCheck3_itemMusic:
            lda fill_region_start_y
            cmp #214
            bcs regionCheckOut_itemMusic
            lda obj_mask_start_btn
            clc
            adc #%00000001
            sta obj_mask_start_btn

        regionCheckOut_itemMusic:
        lda obj_mask_start_btn
        cmp #%00001111
        bne check_for_item_viatest  ;go to the next menu item test
        jsr music_start
        bra hmc_out
    ;Menu item check *** /MUSIC ***

    ;Menu item check *** VIA TEST ***
        check_for_item_viatest:
            stz obj_mask_start_btn
            lda fill_region_start_x
            cmp #5
            bcc regionCheck1_itemVia
            lda obj_mask_start_btn
            clc
            adc #%00001000
            sta obj_mask_start_btn
            regionCheck1_itemVia:
            lda fill_region_start_x
            cmp #60
            bcs regionCheck2_itemVia
            lda obj_mask_start_btn
            clc
            adc #%00000100
            sta obj_mask_start_btn
            regionCheck2_itemVia:
            lda fill_region_start_y
            cmp #195
            bcc regionCheck3_itemVia
            lda obj_mask_start_btn
            clc
            adc #%00000010
            sta obj_mask_start_btn
            regionCheck3_itemVia:
            lda fill_region_start_y
            cmp #204
            bcs regionCheckOut_itemVia
            lda obj_mask_start_btn
            clc
            adc #%00000001
            sta obj_mask_start_btn

        regionCheckOut_itemVia:
        lda obj_mask_start_btn
        cmp #%00001111
        bne hmc_next          //item wasn't clicked, last item in list, get out
        jsr via_test_start
        bra hmc_out
    ;Menu item check *** /VIA TEST ***


    hmc_next:
    lda currently_drawing
    and #$00FF
    cmp #$01
    beq JS_turnDrawingOff_MouseL
    lda #$01   ;otherwise, turn it on
    jmp handleJSpress_out_MouseL
    JS_turnDrawingOff_MouseL:
    lda #$00
    handleJSpress_out_MouseL:
    sta currently_drawing

    hmc_out:
    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    rts
Handle_Mouse_Click_Middle:
    ;inc fill_region_color
    lda fill_region_color
    clc
    adc #03
    ;cmp #$FF
    ;beq resetColorToZero_hmcm
    bcs resetColorToZero_hmcm
    jmp handleNKP_Plus_out_hmcm
    resetColorToZero_hmcm:
    lda #$00
    handleNKP_Plus_out_hmcm:
    sta fill_region_color
    jsr gfx_DrawPixelTILES
    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    rts
Handle_Mouse_Click_Right:

    lda mouseFillRegionStarted
    cmp #$01
    beq clickRightFill  ;if we know region start already, jump to filling. otherwise, capture current location as start position.

    ;record region start
    lda fill_region_start_x
    sta fill_region_clk_start_x
    lda fill_region_start_y
    sta fill_region_clk_start_y
    lda #$01
    sta mouseFillRegionStarted
    bra clickRightOut

    clickRightFill:
        ;currently, start of region must be upper left point, with end of region at lower right point (cannot use reverse, or other corners)

        lda fill_region_start_x   ;end shape at current position
        sta fill_region_end_x     ;end is hard-coded for now
        lda fill_region_start_y
        sta fill_region_end_y

        lda fill_region_clk_start_x
        sta fill_region_start_x
        lda fill_region_clk_start_y
        sta fill_region_start_y
      
        lda fill_region_color
        ;sta fill_region_color    ;user current color - should not need to modify
        sta pixel_prev_color      
        jsr gfx_FillRegionTILES
        jsr gfx_FillRegionVRAM
        lda #$00
        sta mouseFillRegionStarted
    clickRightOut:
    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    rts
RestoreCurrentPixelInfo:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    lda fill_region_start_y
    sta jump_to_line_y
    jsr gfx_JumpToLineTILES
    jsr gfx_JumpToLineVRAM
    ldy fill_region_start_x     ;horizontal pixel location, 0 to 319
    
    ;if not currently drawing, restore pixel, otherwise, paint new color for pixel
    lda currently_drawing
    and #$0001   //***tmp
    cmp #$01
    beq newColor
    lda pixel_prev_color
    jmp restoreCurrentPixelExit
    newColor:
      lda fill_region_color
    restoreCurrentPixelExit:
        ;sta (vidpage), y; write A register (color) to address vidpage + y
        //TO DO call routine to restore a tile from TILES page (under moving pointer)
        jsr WriteVidPageTILES
        jsr WriteVidPageVRAM
    
        ply ;stack to y
        plx ;stack to x
        pla ;stack to a
        rts
RestoreTile:
    pha ;a to stack
    ;phx ;x to stack
    ;phy ;y to stack

    lda fill_region_start_y
    sec
    sbc #4
    sta gfx_tile_start_y
    lda fill_region_start_x
    sec
    sbc #4
    sta gfx_tile_start_x

    ;since VRAM is split between two banks, check if we're on the edge, and if so, fill the tile in the other bank
    ;if y pos is between 103 and 136, draw the two tiles on the border
    lda gfx_tile_start_y
    cmp #130        ;check for first video bank
    bcs restoreTileOutsideMargin      ;above the margin, perform normal tile copy
    cmp #112           
    bcc restoreTileOutsideMargin      ;below the margin, perform normal tile copy
    ;in the margin, draw both tiles. use x pos, but then specify the two y's manually
    lda #113                ;draw tile just above middle line, starting at this position
    sta gfx_tile_start_y
    jsr gfx_CopyTileToVRAM
    lda #128                ;draw tile just below middle line, starting at this position
    sta gfx_tile_start_y
    jsr gfx_CopyTileToVRAM
    ;bra restoreTileExit

    restoreTileOutsideMargin:
        jsr gfx_CopyTileToVRAM

    restoreTileExit:
    ;ply ;stack to y
    ;plx ;stack to x
    pla ;stack to a
    rts
StorePrevPixelInfo:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    lda fill_region_start_x
    sta pixel_prev_x
    lda fill_region_start_y
    sta pixel_prev_y
    ldy pixel_prev_x
    ;need the color of the pixel at the location - convert x,y position to memory location 
    
    //lda (vidpage), y        ;issue line
        //   ;.setting "RegA16", false
        //   sep #$20            ;set acumulator to 8-bit
        //   sta [vidpage], y; write A register (color) to address vidpage + y
        //   ;.setting "RegA16", true
        //   rep #$20            ;set acumulator to 16-bit
      ;.setting "RegA16", false
    lda [vidpageTILES], y; write A register (color) to address vidpage + y
    //lda [vidpageVRAM], y; write A register (color) to address vidpage + y
    and #$00FF
    sta pixel_prev_color

    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
DrawMousePointer:
    pha
    phy

    //TO DO Move this mouse pointer data to a byte array in ROM
    ;target:8x8 mouse pointer

    ;row 1
        lda fill_region_start_y
        sta jump_to_line_y
        jsr gfx_JumpToLineVRAM
        ldy fill_region_start_x     ;horizontal pixel location, 0 to 319
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;black
        jsr WriteVidPageVRAM

    ;row 2
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 3
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 4
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 5
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 6
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 7
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        lda #$00    ;black
        jsr WriteVidPageVRAM

        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$FF    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM

    ;row 8
        //inc jump_to_line_y ;move down
        //jsr gfx_JumpToLineVRAM
        jsr gfx_NextVGALineVRAM
        ldy fill_region_start_x
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
        iny ;move to the right one pixel
        lda #$00    ;
        jsr WriteVidPageVRAM
    pointerOut:
    ply
    pla
    rts
// DisplayXYonLCD:
    //     pha
    //     jsr lcd_clear
    //     lda fill_region_start_x
    //     jsr print_hex_lcd_16
    //     jsr lcd_line2
    //     lda fill_region_start_y
    //     jsr print_hex_lcd_16
    //     pla
    //     rts