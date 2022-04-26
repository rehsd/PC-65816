.setting "HandleLongBranch", true


Mouse_Interrupt_Handler:
    ;Only using interrupts for PortB - don't need to check port source

;.setting "RegA16", false
;sep #$20            ;set acumulator to 8-bit
    lda VIA3_PORTB                ;clear interrupt
    and #$00FF                      ;16-bit adjustment
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

    ;jsr print_hex_lcd

    and #%00000011      ;mouse button mask
    ;jsr print_hex_lcd
    sta tmpMouseInterruptMasked

    eor #MOUSE_CLICK_LEFT
    beq Handle_Mouse_Click_Left

    lda tmpMouseInterruptMasked
    eor #MOUSE_CLICK_MIDDLE
    beq Handle_Mouse_Click_Middle

    lda tmpMouseInterruptMasked
    eor #MOUSE_CLICK_RIGHT
    beq Handle_Mouse_Click_Right

    ;test code:
      // lda VIA3_PORTB
      // and #%00111100  ;mouse move bits

      // cmp #%00000100  ;up
      // bne ru
      //   lda #$55    ;U
      //   jsr print_char_vga
      // ru:

      // cmp #%00001000  ;rightup
      // bne r
      //   lda #$52    ;R
      //   jsr print_char_vga
      //   lda #$55    ;U
      //   jsr print_char_vga 
      // r:

      // cmp #%00001100  ;right
      // bne rd    
      //   lda #$52    ;R
      //   jsr print_char_vga
      // rd:

      // cmp #%00010000  ;rightdown
      // bne d
      //   lda #$52    ;R
      //   jsr print_char_vga
      //   lda #$44    ;D
      //   jsr print_char_vga
      // d:

      // cmp #%00010100  ;down
      //   bne ld
      //   lda #$44    ;D
      //   jsr print_char_vga 
      // ld:

      // cmp #%00011000  ;leftdown
      //   bne l
      //   lda #$4C    ;L
      //   jsr print_char_vga     
      //   lda #$44    ;D
      //   jsr print_char_vga 
      // l:

      // cmp #%00011100  ;left
      //   bne lu
      //   lda #$4C    ;L
      //   jsr print_char_vga     
      // lu:

      // cmp #%00100000  ;leftup
      //   bne v3irqh_out
      //   lda #$4C    ;L
      //   jsr print_char_vga     
      //   lda #$55    ;U
      //   jsr print_char_vga     

      // v3irqh_out:

      
    jmp irq_done
Handle_Mouse_Left_Down:
    jsr RestoreCurrentPixelInfo
    ldx fill_region_start_x
    dex
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    ;jsr DrawPixel

    ;put old pixel data in current pixel, since the pointer is moving out
    jsr RestoreCurrentPixelInfo
  
    ;add to fill_region_start_y to move the pixel down
    ldx fill_region_start_y
    inx   ;need to inx 80 and manage carry
    stx fill_region_start_y

    clc
    lda vidpage
    adc #512
    sta vidpage    
    lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    adc #$00          ;add carry
    sta vidpage + 2

    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel

    jmp irq_done
Handle_Mouse_Right_Down:
    ;put old pixel data in current pixel, since the pointer is moving out
    jsr RestoreCurrentPixelInfo
    ;add to fill_region_start_x to move the pixel right
    ldx fill_region_start_x
    inx
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    ;jsr DrawPixel

    ;put old pixel data in current pixel, since the pointer is moving out
    jsr RestoreCurrentPixelInfo
  
    ;add to fill_region_start_y to move the pixel down
    ldx fill_region_start_y
    inx   ;need to inx 80 and manage carry
    stx fill_region_start_y

    clc
    lda vidpage
    adc #512
    sta vidpage    
    lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    adc #$00          ;add carry
    sta vidpage + 2

    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel

    jmp irq_done
Handle_Mouse_Down:
    pha
    lda #$44
    jsr print_char_lcd
    pla


  ;put old pixel data in current pixel, since the pointer is moving out
  jsr RestoreCurrentPixelInfo
  
  ;add to fill_region_start_y to move the pixel down
  ldx fill_region_start_y
  inx   ;need to inx 80 and manage carry
  stx fill_region_start_y

  clc
  lda vidpage
  adc #512
  sta vidpage    
  lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
  adc #$00          ;add carry
  sta vidpage + 2

  jsr StorePrevPixelInfo
  jsr gfx_DrawPixel

  jmp irq_done
Handle_Mouse_Left_Up:
    jsr RestoreCurrentPixelInfo
    ldx fill_region_start_x
    dex
    stx fill_region_start_x
    jsr StorePrevPixelInfo  ;can this be skipped?
    ;jsr DrawPixel           ;can this be skipped?
    

    ;put old pixel data in current pixel, since the cursor is moving out
    jsr RestoreCurrentPixelInfo

    ;subtract from fill_region_start_y to move the pixel up
    ldx fill_region_start_y
    dex   ;need to dex 80 and manage carry
    stx fill_region_start_y

    sec
    lda vidpage
    sbc #512
    sta vidpage    
    lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    sbc #$00          ;subtract carry
    sta vidpage + 2

    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel

    jmp irq_done
Handle_Mouse_Right_Up:
    ;put old pixel data in current pixel, since the pointer is moving out
    jsr RestoreCurrentPixelInfo
    ;add to fill_region_start_x to move the pixel right
    ldx fill_region_start_x
    inx
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    ;jsr DrawPixel

    ;put old pixel data in current pixel, since the cursor is moving out
    jsr RestoreCurrentPixelInfo

    ;subtract from fill_region_start_y to move the pixel up
    ldx fill_region_start_y
    dex   ;need to dex 80 and manage carry
    stx fill_region_start_y

    sec
    lda vidpage
    sbc #512
    sta vidpage    
    lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    sbc #$00          ;subtract carry
    sta vidpage + 2

    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel

    jmp irq_done
Handle_Mouse_Left:
    pha
    lda #$4C
    jsr print_char_lcd
    pla
    jsr RestoreCurrentPixelInfo
    ldx fill_region_start_x
    dex
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel
    jmp irq_done
Handle_Mouse_Up:
    pha
    lda #$55
    jsr print_char_lcd
    pla


  ;put old pixel data in current pixel, since the cursor is moving out
  jsr RestoreCurrentPixelInfo

  ;subtract from fill_region_start_y to move the pixel up
  ldx fill_region_start_y
  dex   ;need to dex 80 and manage carry
  stx fill_region_start_y

  sec
  lda vidpage
  sbc #512
  sta vidpage    
  lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
  sbc #$00          ;subtract carry
  sta vidpage + 2

  jsr StorePrevPixelInfo
  jsr gfx_DrawPixel

  jmp irq_done   
Handle_Mouse_Right:
    pha
    lda #$52
    jsr print_char_lcd
    pla

    ;put old pixel data in current pixel, since the pointer is moving out
    jsr RestoreCurrentPixelInfo
    ;add to fill_region_start_x to move the pixel right
    ldx fill_region_start_x
    inx
    stx fill_region_start_x
    jsr StorePrevPixelInfo
    jsr gfx_DrawPixel

    jmp irq_done
Handle_Mouse_Click_Left:
    ;jsr print_dec_lcd
    lda #$00  ;start counting up at this value; higher # = shorter delay
    sta delayDuration
    jsr Delay
    lda currently_drawing
    cmp #$01
    beq JS_turnDrawingOff_MouseL
    lda #$01   ;otherwise, turn it on
    jmp handleJSpress_out_MouseL
    JS_turnDrawingOff_MouseL:
    lda #$00
    handleJSpress_out_MouseL:
    sta currently_drawing

    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    jmp irq_done
Handle_Mouse_Click_Middle:
    inc fill_region_color
    lda fill_region_color
    cmp #$40
    beq resetColorToZero_hmcm
    jmp handleNKP_Plus_out_hmcm
    resetColorToZero_hmcm:
    lda #$00
    handleNKP_Plus_out_hmcm:
    sta fill_region_color
    jsr gfx_DrawPixel
    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    jmp irq_done
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
        jsr gfx_FillRegion
        lda #$00
        sta mouseFillRegionStarted
    clickRightOut:
    ;bit VIA3_PORTB      ;reset interrupt
    lda VIA3_PORTB      ;reset interrupt
    jmp irq_done
RestoreCurrentPixelInfo:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    lda fill_region_start_y
    sta jump_to_line_y
    jsr gfx_JumpToLine
    ldy fill_region_start_x     ;horizontal pixel location, 0 to 99
    
    ;if not currently drawing, restore pixel, otherwise, paint new color for pixel
    lda currently_drawing
    cmp #$01
    beq newColor
    lda pixel_prev_color
    jmp restoreCurrentPixelExit
    newColor:
      lda fill_region_color
    restoreCurrentPixelExit:
        sta (vidpage), y; write A register (color) to address vidpage + y
        ;return items from stack
    
        ply ;stack to y
        plx ;stack to x
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
    lda (vidpage), y        ;issue line
    sta pixel_prev_color

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts