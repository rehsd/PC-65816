video_init:

  lda #0    ;black
  jsr gfx_fillscreen
  jsr gfx_TestPattern
  jsr gfx_TestPattern_Animated_Ship_WithTransparency
  video_init_skipTestPattern:
  lda #%00100101    ;gray
  jsr gfx_fillscreen

  rep #$20  ;set acumulator to 16-bit
  .setting "RegA16", true
  lda #$00
  sta char_y_offset
  lda #07
  sta char_vp_x    ;0 to 319
  lda #07
  sta char_vp_y    ;0 to 239
  jsr gfx_SetCharVpByXY
  lda #%00011111
  sta char_color
  lda #$08
  sta message_to_process
  jsr PrintString

  lda #$00  ;done processing pre-defined strings
  sta message_to_process

  lda #$00
  sta char_y_offset
  lda #07
  sta char_vp_x    ;0 to 319
  lda #16
  sta char_vp_y    ;0 to 239
  jsr gfx_SetCharVpByXY
  lda #%11111111
  sta char_color
  lda #$3E  ;'>'  
  jsr print_char_vga

  rts
gfx_FillScreen:
  //a = fill color
  sta color
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack

  //set vidpage back to start
  lda #$0020
  sta vidpage + 2
  lda #$0000
  sta vidpage
  
  ldy #$00                ;start counter - pixels in row
  ldx #$00                ;row number

  _gfx_fillscreen_loop:
    ;draw a line
    lda color           
    ;sta [vidpage], y                                                                        ;8031
    jsr WriteVidPage
    iny     
    tya
    cmp #320        ;rollover        ;stop at 320 pixels in the row
    bne _gfx_fillscreen_loop                                                                          ;8038

    ;next row...
    clc
    lda vidpage                                                                             ;803D
    adc #512    ;skip pixels 320 to 511, go to next row                                     ;803F
    sta vidpage                                                                             ;8042
    ldy #0
    inx
    txa
    cmp #128    ;once 128 rows are processed, increment vidpage+2 to go to the next page
    bne _gfx_fillscreen_loop
    sta row
    ldx #0
    ldy #0
    clc
    lda vidpage+2
    adc #$0001
    sta vidpage+2   
    cmp #$22        ;20-21 are valid for video, 22 is next I/O range, so done with video
    bne _gfx_fillscreen_loop


  ply ;stack to y
  plx ;stack to x
  pla ;stack to a
  rts
gfx_FillRegion:
  ;inputs: fill_region_start_x, fill_region_start_y, fill_region_end_x, fill_region_end_y, fill_region_color
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack
  
  ;store current 'cursor' location
  lda vidpage + 2
  sta vidpagePrev + 2
  lda vidpage
  sta vidpagePrev
  gfx_FillRegionLoopStart:
    ;start location
    lda fill_region_start_y
    sta jump_to_line_y

    jsr gfx_JumpToLine

    ldx fill_region_end_x
    inx
    ;stx $53 ; column# end comparison
    stx col_end ; column# end comparison
    
    lda fill_region_end_y
    sec
    sbc fill_region_start_y
    sta rows_remain ; rows remaining
    inc rows_remain ; add one to get count of rows to process

    gfx_FillRegionLoopYloop:
        ldy fill_region_start_x     ;horizontal pixel location, 0 to 319
        lda fill_region_color
            
        gfx_FillRegionLoopXloop:
            jsr WriteVidPage
            iny
            cpy col_end
            beq gfx_FRLX_done    ;done with this row
            jmp gfx_FillRegionLoopXloop
        gfx_FRLX_done:
            ;move on to next row
            dec rows_remain
            beq gfx_FRLY_done
            lda vidpage
            clc
            adc #512
            sta vidpage    
            lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
            adc #$00          ;add carry
            sta vidpage + 2                  
            jmp gfx_FillRegionLoopYloop
        gfx_FRLY_done:
        
    ;put things back and return to sender
    lda vidpagePrev+2
    sta vidpage + 2
    lda vidpagePrev
    sta vidpage

    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
gfx_FillRegion_FrameBuffer:
  ;inputs: fill_region_start_x, fill_region_start_y, fill_region_end_x, fill_region_end_y, fill_region_color
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack
  
  ;store current 'cursor' location
  lda vidpage_buffer + 2
  sta vidpagePrev_buffer + 2
  lda vidpage_buffer
  sta vidpagePrev_buffer
  gfx_FillRegionLoopStart_fb:
    ;start location
    lda fill_region_start_y
    sta jump_to_line_y

    jsr gfx_JumpToLine_FrameBuffer

    ldx fill_region_end_x
    inx
    stx col_end ; column# end comparison
    
    lda fill_region_end_y
    sec
    sbc fill_region_start_y
    sta rows_remain ; rows remaining
    inc rows_remain ; add one to get count of rows to process

    gfx_FillRegionLoopYloop_fb:
        ldy fill_region_start_x     ;horizontal pixel location, 0 to 319
        lda fill_region_color
            
        gfx_FillRegionLoopXloop_fb:
            ;sta [vidpage_buffer], y; write A register (color) to address vidpage + y
            jsr WriteVidPageBuffer
            iny
            cpy col_end
            beq gfx_FRLX_done_fb    ;done with this row
            jmp gfx_FillRegionLoopXloop_fb
        gfx_FRLX_done_fb:
            ;move on to next row
            dec rows_remain
            beq gfx_FRLY_done_fb
            lda vidpage_buffer
            clc
            adc #512
            sta vidpage_buffer    
            lda vidpage_buffer + 2   ;do not clc... need the carry bit to roll to the second (high) byte
            adc #$00          ;add carry
            sta vidpage_buffer + 2                  
            jmp gfx_FillRegionLoopYloop_fb
        gfx_FRLY_done_fb:
        
    ;put things back and return to sender
    lda vidpagePrev_buffer+2
    sta vidpage_buffer + 2
    lda vidpagePrev_buffer
    sta vidpage_buffer

    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
gfx_JumpToLine:
    pha
    phx
    phy

    ;set vidpage back to start
    lda #$0020
    sta vidpage + 2
    lda #$0000
    sta vidpage

    ldx jump_to_line_y
    ;if jump_to_line_y is 0, we are done
    cpx #$00
    ;TO DO Verify jump_to_line_y does not exceed 239
    beq gfx_JumpToLineDone

    gfx_JumpToLineLoop:
    jsr gfx_NextVGALine     ;there has to be a better way that to call this loop -- more of a direct calculation -- TBD
    dex
    bne gfx_JumpToLineLoop
    
    gfx_JumpToLineDone:

    ply
    plx
    pla
    rts
gfx_JumpToLine_FrameBuffer:
    pha
    phx
    phy

    ;set vidpage back to start
    lda #$000E
    sta vidpage_buffer + 2
    lda #$0000
    sta vidpage_buffer

    ldx jump_to_line_y
    ;if jump_to_line_y is 0, we are done
    cpx #$00
    ;TO DO Verify jump_to_line_y does not exceed 239
    beq gfx_JumpToLineDone_fb

    gfx_JumpToLineLoop_fb:
    jsr gfx_NextVGALine_FrameBufffer     ;there has to be a better way that to call this loop -- more of a direct calculation -- TBD
    dex
    bne gfx_JumpToLineLoop_fb
    
    gfx_JumpToLineDone_fb:

    ply
    plx
    pla
    rts
gfx_NextVGALine:
    pha
    ;move the location for writing to the screen down one line
    clc
    lda vidpage
    adc #512         ;add 512 to move to next row
    sta vidpage    
    lda vidpage + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    adc #$00          ;add carry
    sta vidpage + 2
    pla
    rts
gfx_CRLF:
    pha
    ;move the location for writing to the screen down one line
    clc
    lda char_vp
    adc #5120         ;add 512 to move to next row (pixel)
    sta char_vp    
    lda char_vp + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    adc #0          ;add carry
    sta char_vp + 2

    lda #$00
    sta char_y_offset

    pla
    rts
gfx_NextVGALine_FrameBufffer:
    pha
    ;move the location for writing to the screen down one line
    clc
    lda vidpage_buffer
    adc #512         ;add 512 to move to next row
    sta vidpage_buffer    
    lda vidpage_buffer + 2   ;do not clc... need the carry bit to roll to the second (high) byte
    adc #$00          ;add carry
    sta vidpage_buffer + 2
    pla
    rts
gfx_TestPattern:
  pha
  phx
  phy
  ;draw screen frame
    ;top bar
    lda #0
    sta fill_region_start_x
    lda #0
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #2
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion

    ;bottom bar
    lda #0
    sta fill_region_start_x
    lda #237
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #239
    sta fill_region_end_y
    jsr gfx_FillRegion

    ;left bar
    lda #0
    sta fill_region_start_x
    lda #3
    sta fill_region_start_y
    lda #2
    sta fill_region_end_x
    lda #236
    sta fill_region_end_y
    jsr gfx_FillRegion

    ;right bar
    lda #317
    sta fill_region_start_x
    lda #3
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #236
    sta fill_region_end_y
    jsr gfx_FillRegion

  ;draw red gradient
    lda #40
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion
    
    lda #70
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%00100000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #100
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%01000000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #130
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%01100000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #160
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%10000000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #190
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%10100000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #220
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%11000000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #250
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%11100000
    sta fill_region_color
    jsr gfx_FillRegion

  ;draw green gradient
    lda #40
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion
    
    lda #70
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00000100
    sta fill_region_color
    jsr gfx_FillRegion

    lda #100
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00001000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #130
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00001100
    sta fill_region_color
    jsr gfx_FillRegion

    lda #160
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00010000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #190
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00010100
    sta fill_region_color
    jsr gfx_FillRegion

    lda #220
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00011000
    sta fill_region_color
    jsr gfx_FillRegion

    lda #250
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00011100
    sta fill_region_color
    jsr gfx_FillRegion

  ;draw blue gradient
    lda #40
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion
    
    lda #100
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000001
    sta fill_region_color
    jsr gfx_FillRegion

    lda #160
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000010
    sta fill_region_color
    jsr gfx_FillRegion

    lda #220
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000011
    sta fill_region_color
    jsr gfx_FillRegion

  ;draw white gradient
    lda #40
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion
    
    lda #70
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%00100100
    sta fill_region_color
    jsr gfx_FillRegion

    lda #100
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%01001001
    sta fill_region_color
    jsr gfx_FillRegion

    lda #130
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%01101101
    sta fill_region_color
    jsr gfx_FillRegion

    lda #160
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%10010010
    sta fill_region_color
    jsr gfx_FillRegion

    lda #190
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%10110110
    sta fill_region_color
    jsr gfx_FillRegion

    lda #220
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%11011011
    sta fill_region_color
    jsr gfx_FillRegion

    lda #250
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion

  ;draw color gradient
    ldx #0  ;color
    ldy #32  ;x pos
    colorGradientLoop:
    tya
    sta fill_region_start_x
    sta fill_region_end_x
    lda #150
    sta fill_region_start_y
    lda #169
    sta fill_region_end_y
    txa
    sta fill_region_color
    jsr gfx_FillRegion
    inx
    iny
    txa
    cmp #256  ;finished with all color options (0-255)
    bne colorGradientLoop    
    
  ;draw corner marks
    ;upper left
    lda #35
    sta fill_region_start_x
    lda #25
    sta fill_region_start_y
    lda #35
    sta fill_region_end_x
    lda #29
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion

    lda #30
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #34
    sta fill_region_end_x
    lda #30
    sta fill_region_end_y
    jsr gfx_FillRegion

    ;upper right
    lda #279
    sta fill_region_start_x
    lda #25
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #29
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion

    lda #280
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #284
    sta fill_region_end_x
    lda #30
    sta fill_region_end_y
    jsr gfx_FillRegion
  
  ;add labels
    lda #$00
    sta char_y_offset
    
    lda #%11111111
    sta char_color

    lda #58
    sta char_vp_x    ;0 to 319
    lda #10
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #06
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #51
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #01
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #81
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #02
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #111
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #03
    sta message_to_process
    jsr PrintString
    
    lda #$00
    sta char_y_offset
    lda #60
    sta char_vp_x    ;0 to 319
    lda #141
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #04
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #171
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #05
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #20
    sta char_vp_x    ;0 to 319
    lda #220
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #07
    sta message_to_process
    jsr PrintString

  ply
  plx
  pla
  rts
gfx_TestPattern_FrameBuffer:
  pha
  phx
  phy
  ;draw screen frame
    ;top bar
    lda #0
    sta fill_region_start_x
    lda #0
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #2
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    ;bottom bar
    lda #0
    sta fill_region_start_x
    lda #237
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #239
    sta fill_region_end_y
    jsr gfx_FillRegion_FrameBuffer

    ;left bar
    lda #0
    sta fill_region_start_x
    lda #3
    sta fill_region_start_y
    lda #2
    sta fill_region_end_x
    lda #236
    sta fill_region_end_y
    jsr gfx_FillRegion_FrameBuffer

    ;right bar
    lda #317
    sta fill_region_start_x
    lda #3
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    lda #236
    sta fill_region_end_y
    jsr gfx_FillRegion_FrameBuffer

  ;draw red gradient
    lda #40
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer
    
    lda #70
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%00100000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #100
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%01000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #130
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%01100000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #160
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%10000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #190
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%10100000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #220
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%11000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #250
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #49
    sta fill_region_end_y
    lda #%11100000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

  ;draw green gradient
    lda #40
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer
    
    lda #70
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00000100
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #100
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00001000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #130
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00001100
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #160
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00010000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #190
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00010100
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #220
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00011000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #250
    sta fill_region_start_x
    lda #60
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #79
    sta fill_region_end_y
    lda #%00011100
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

  ;draw blue gradient
    lda #40
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer
    
    lda #100
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000001
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #160
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000010
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #220
    sta fill_region_start_x
    lda #90
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #109
    sta fill_region_end_y
    lda #%00000011
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

  ;draw white gradient
    lda #40
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #69
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer
    
    lda #70
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #99
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%00100100
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #100
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #129
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%01001001
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #130
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #159
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%01101101
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #160
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #189
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%10010010
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #190
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #219
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%10110110
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #220
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #249
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%11011011
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #250
    sta fill_region_start_x
    lda #120
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #139
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

  ;draw color gradient
    ldx #0  ;color
    ldy #32  ;x pos
    colorGradientLoop_fb:
    tya
    sta fill_region_start_x
    sta fill_region_end_x
    lda #150
    sta fill_region_start_y
    lda #169
    sta fill_region_end_y
    txa
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer
    inx
    iny
    txa
    cmp #256  ;finished with all color options (0-255)
    bne colorGradientLoop_fb    
    
  ;draw corner marks
    ;upper left
    lda #35
    sta fill_region_start_x
    lda #25
    sta fill_region_start_y
    lda #35
    sta fill_region_end_x
    lda #29
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #30
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #34
    sta fill_region_end_x
    lda #30
    sta fill_region_end_y
    jsr gfx_FillRegion_FrameBuffer

    ;upper right
    lda #279
    sta fill_region_start_x
    lda #25
    sta fill_region_start_y
    lda #279
    sta fill_region_end_x
    lda #29
    sta fill_region_end_y
    lda #%11111111
    sta fill_region_color
    jsr gfx_FillRegion_FrameBuffer

    lda #280
    sta fill_region_start_x
    lda #30
    sta fill_region_start_y
    lda #284
    sta fill_region_end_x
    lda #30
    sta fill_region_end_y
    jsr gfx_FillRegion_FrameBuffer
  
  jmp skipLabels
  ;add labels
    lda #$00
    sta char_y_offset
    
    lda #%11111111
    sta char_color

    lda #58
    sta char_vp_x    ;0 to 319
    lda #10
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #06
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #51
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #01
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #81
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #02
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #111
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #03
    sta message_to_process
    jsr PrintString
    
    lda #$00
    sta char_y_offset
    lda #60
    sta char_vp_x    ;0 to 319
    lda #141
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #04
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #120
    sta char_vp_x    ;0 to 319
    lda #171
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #05
    sta message_to_process
    jsr PrintString

    lda #$00
    sta char_y_offset
    lda #20
    sta char_vp_x    ;0 to 319
    lda #220
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY
    lda #07
    sta message_to_process
    jsr PrintString
  skipLabels:

  
    // ;copy frame buffer to video RAM
    // ;x = source addr, y = dest addr, a = length-1
    // ;mvn destBank, sourceBank
    // ldx #$0000
    // ldy #$0000
    // lda #$FFFF
    // phb
    // mvn $20, $0E    ;21 is bottom half of video frame, 0F is the second half of the frame buffer in extended RAM
    // mvn $21, $0F    ;21 is bottom half of video frame, 0F is the second half of the frame buffer in extended RAM
    // plb

    jsr gfx_frameBufferToVideo
  ply
  plx
  pla
  rts
gfx_TextPattern_Animated_Ship_Background_Buffer:
  ;TO DO - break things into tiles and do this more efficiently
  pha
  phx
  phy

  // ;clear the drawing area   ;TO DO do this by tile -- only those tiles that need it - the following code is sloppy and for testing only
  // lda #10
  // sta fill_region_start_x
  // lda #183
  // sta fill_region_start_y
  // lda #315
  // sta fill_region_end_x
  // lda #215
  // sta fill_region_end_y
  // lda #%00000000
  // sta fill_region_color
  // jsr gfx_FillRegion

  lda #120
  sta fill_region_start_x
  lda #183
  sta fill_region_start_y
  lda #149
  sta fill_region_end_x
  lda #215
  sta fill_region_end_y
  lda #%11100000
  sta fill_region_color
  jsr gfx_FillRegion_FrameBuffer

  lda #150
  sta fill_region_start_x
  lda #179
  sta fill_region_end_x
  lda #%00011100
  sta fill_region_color
  jsr gfx_FillRegion_FrameBuffer

  lda #180
  sta fill_region_start_x
  lda #209
  sta fill_region_end_x
  lda #%00000011
  sta fill_region_color
  jsr gfx_FillRegion_FrameBuffer

  ply
  plx
  pla
  rts
gfx_TextPattern_Animated_Ship_Background:
  ;TO DO - break things into tiles and do this more efficiently
  pha
  phx
  phy

  lda #120
  sta fill_region_start_x
  lda #183
  sta fill_region_start_y
  lda #149
  sta fill_region_end_x
  lda #215
  sta fill_region_end_y
  lda #%11111100
  sta fill_region_color
  jsr gfx_FillRegion

  lda #150
  sta fill_region_start_x
  lda #179
  sta fill_region_end_x
  lda #%00011111
  sta fill_region_color
  jsr gfx_FillRegion

  lda #180
  sta fill_region_start_x
  lda #209
  sta fill_region_end_x
  lda #%11100011
  sta fill_region_color
  jsr gfx_FillRegion

  ply
  plx
  pla
  rts
gfx_TestPattern_Animated_Ship:
  ;ship sprite stored on ROM at ;$020000 to $0203FF (with transparency)
  ;ship sprite stored on ROM at ;$020400 to $0207FF (without transparency)
  ;VGA is at $200000
  pha
  phx
  phy
  ;x = source addr, y = dest addr, a = length-1
  ;mvn destBank, sourceBank

  lda #0
  sta move_frame_counter
  lda #$7010  ;position at appropriate vertical position
  sta move_dest

  ship_frame_loop:
    lda #31    ;number of bytes per row
    sta move_size
    lda #$0400
    sta move_source
    lda #32   ;number of rows to process
    sta move_counter

    ship_line_loop:
      lda move_size     ;size (64 bytes)
      ldx move_source ;from
      ldy move_dest ;to
      phb
      mvn $21, $02    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored
      plb
      lda move_source
      clc
      adc #32
      sta move_source
      lda move_dest
      clc
      adc #512  ;next row
      sta move_dest
      dec move_counter
      bne ship_line_loop

    jsr delay
    inc move_frame_counter
    lda #$7010
    clc
    adc move_frame_counter
    sta move_dest
    lda move_frame_counter
    cmp #260
    bne ship_frame_loop

  ;clear the final ship
    lda #275
    sta fill_region_start_x
    lda #185
    sta fill_region_start_y
    lda #315
    sta fill_region_end_x
    lda #215
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion

  ply
  plx
  pla
  rts
gfx_BackupBand:
  pha
  phx
  phy
  
  ;copy original band to ERAM
  ldx #$7010    ;starting position of band in vram
  ldy #$0000    ;startint position in eram to copy vram
  lda #$4000    ;32 rows of 512 wide
  phb
  mvn $0F, $21    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored -- copy from vram to eram
  plb

  ply
  plx
  pla
  rts
gfx_RestoreBandToBuffer:
  pha
  phx
  phy
  
  ;copy backup from ERAM to vram
  ldx #$0000    ;starting position of band in vram
  ldy #$0000    ;starting position in eram to copy vram
  lda #$4000    ;32 rows of 512 wide
  phb
  mvn $0D, $0F    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored -- copy from vram to eram
  plb

  ply
  plx
  pla
  rts
gfx_WriteBufferToVideo:
  pha
  phx
  phy
  
  // ;copy buffer to vram
  // ldx #$0000    ;starting position of band in eram
  // ldy #$7010    ;starting position in vram to copy
  // lda #$4000    ;32 rows of 512 wide
  // phb
  // mvn $21, $0D    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored -- copy from vram to eram
  // plb

  //only write out the part of the buffer where the sprite was recently moved
  //move_frame_counter then #512 per row
  // ldx move_frame_counter
  // lda #$FF
  // sta $7010, x    //spli $210000 & $7010 out

  //32 rows
  lda #32 ;rows to process
  sta move_counter_wb
  lda move_frame_counter
  sta move_source_wb
  lda #$7010
  clc
  adc move_frame_counter
  sta move_dest_wb

  anotherRow:
    lda move_size
    ldx move_source_wb
    ldy move_dest_wb

    phb
    mvn $21, $0D    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored -- copy from vram to eram
    plb

    lda move_source_wb
    clc
    adc #512
    sta move_source_wb
    lda move_dest_wb
    clc
    adc #512
    sta move_dest_wb
    dec move_counter_wb
    bne anotherRow

  ply
  plx
  pla
  rts
gfx_TestPattern_Animated_Ship_WithTransparency:
  ;ship sprite stored on ROM at ;$020000 to $0203FF (with transparency)
  ;ship sprite stored on ROM at ;$020400 to $0207FF (without transparency)
  ;VGA is at $200000
  pha
  phx
  phy
  ;x = source addr, y = dest addr, a = length-1
  ;mvn destBank, sourceBank

  jsr gfx_TextPattern_Animated_Ship_Background
  jsr gfx_BackupBand

  lda #0
  sta move_frame_counter
  sta move_dest

  ship_frame_loop_wt:
    jsr gfx_RestoreBandToBuffer
    lda #31    ;number of bytes per row
    sta move_size
    lda #$00
    sta move_source
    lda #32   ;number of rows to process
    sta move_counter

    ship_line_loop_wt:
      lda move_size   
      ldx move_source ;from
      ldy move_dest ;to
      phb
      ;mvn $21, $02    ;21 is bottom half of video frame, 02 is ROM page where this sprite is stored
      jsr mvn_withtransparency

      plb
      lda move_source
      clc
      adc #32
      sta move_source
      lda move_dest
      clc
      adc #512  ;next row
      sta move_dest
      dec move_counter
      bne ship_line_loop_wt

    
    jsr gfx_WriteBufferToVideo

    ;jsr delay
    inc move_frame_counter
    inc move_frame_counter
    lda #$0
    clc
    adc move_frame_counter
    sta move_dest
    lda move_frame_counter
    cmp #260
    bne ship_frame_loop_wt

  ;clear the final ship
    lda #275
    sta fill_region_start_x
    lda #185
    sta fill_region_start_y
    lda #315
    sta fill_region_end_x
    lda #215
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion

  ply
  plx
  pla
  rts
mvn_withtransparency:
  ;pha 
  ;phx
  ;phy
  ;.setting "RegA16", false
  ;sep #$20            ;set acumulator to 8-bit

  ;x = source addr, y = dest addr, a = length-1
  ;sta mvn_wtransp_src_bank
  ;sta mvn_wtransp_dest_bank
  sta mvn_wtransp_length
  inc mvn_wtransp_length  //a = length -1; branch logic below checks for 0
  mvn_withtransparency_loop:
    lda $020000,x   ;load from ROM
    inx
    phx
    tyx
    and #$00FF  ;in 16-bit mode, pulling double-byte -- only want to look at the lsb
    cmp #%00100100    ;RGB value for transparent pixel
    beq skipPixel

    ;sta $0D0000, x    ;write to buffer
    sep #$20            ;set acumulator to 8-bit
    sta $0D0000, x    ;write to buffer
    rep #$20            ;set acumulator to 16-bit

    skipPixel:
    inx
    txy
    plx
    dec mvn_wtransp_length
    bne mvn_withtransparency_loop


  ;.setting "RegA16", true
  ;rep #$20            ;set acumulator to 16-bit
  ;ply
  ;plx
  ;pla
  rts
gfx_frameBufferToVideo:
  pha
  phx
  phy
  ;copy frame buffer to video RAM
  ;x = source addr, y = dest addr, a = length-1
  ;mvn destBank, sourceBank
  ldx #$0000
  ldy #$0000
  lda #$FFFF
  phb
  mvn $21, $0F    ;21 is bottom half of video frame, 0F is the second half of the frame buffer in extended RAM
  mvn $20, $0E    ;21 is bottom half of video frame, 0F is the second half of the frame buffer in extended RAM
  plb
  ply
  plx
  pla
  rts
gfx_test_screen:
    lda #$0020
    sta vidpage + 2
    lda #$0000
    ;sta vidpage + 1
    sta vidpage
    
    lda #$00FF    ;white
    sta color
    ldy #$00                ;start counter - pixels in row
    ldx #$00                ;row number

  _fgx_test_scren_loop:
      ;draw a line
      lda color           
      ;sta [vidpage], y
      jsr WriteVidPage
      iny     
      tya
      //cmp #$00FF    ;rollover        ;stop at this many pixels in the row
      cmp #320        ;rollover        ;stop at 320 pixels in the row
      bne _fgx_test_scren_loop                                                                          ;8038

      ;next row...
      dec color
      clc
      lda vidpage                                                                             ;803D
      adc #512    ;skip pixels 320 to 511, go to next row                                     ;803F
      sta vidpage                                                                             ;8042
      ldy #0
      inx
      txa
      cmp #128    ;once 128 rows are processed, increment vidpage+2
      bne _fgx_test_scren_loop
      sta row
      ldx #0
      ldy #0
      clc
      lda vidpage+2
      adc #$0001
      sta vidpage+2   
      cmp #$22        ;20-21 are valid for video, 22 is next I/O range, so done with video
      bne _fgx_test_scren_loop
  finished_label:
      ;rts
      jmp gfx_test_screen
gfx_StartScreen:
  ;top bar - red
  lda #0
  sta fill_region_start_x
  lda #0
  sta fill_region_start_y
  lda #319
  sta fill_region_end_x
  lda #2
  sta fill_region_end_y
  lda #%11100000
  sta fill_region_color
  jsr gfx_FillRegion

  ;bottom bar - yellow
  lda #0
  sta fill_region_start_x
  lda #237
  sta fill_region_start_y
  lda #319
  sta fill_region_end_x
  lda #239
  sta fill_region_end_y
  lda #%11111100
  sta fill_region_color
  jsr gfx_FillRegion

  ;left bar - green
  lda #0
  sta fill_region_start_x
  lda #3
  sta fill_region_start_y
  lda #2
  sta fill_region_end_x
  lda #236
  sta fill_region_end_y
  lda #%00011100
  sta fill_region_color
  jsr gfx_FillRegion

  ;right bar - blue
  lda #317
  sta fill_region_start_x
  lda #3
  sta fill_region_start_y
  lda #319
  sta fill_region_end_x
  lda #236
  sta fill_region_end_y
  lda #%00000011
  sta fill_region_color
  jsr gfx_FillRegion
  rts
gfx_SetCharVpByXY:
  ;TO DO safety code (keep in bounds)
  pha
  phx
  phy
  ;convert x,y position to char_vp and char_vp+2
  ;char_vp_x    0 to 319
  ;char_vp_y    0 to 239
  ;char_vp      512 bytes per row, max of 320 rows -- all zero-based
  
  ;reset to default location of 0020:0000, or pixel 9,0
  lda #$0020
  sta char_vp+2
  lda #$0000
  sta char_vp

  ;for each y, add 512
  ldy char_vp_y
  cpy #0    ;if 0, don't add for y, since top row
  beq addX_step
  y_loop:
    clc
    lda char_vp
    adc #512
    sta char_vp
    lda char_vp+2
    adc #0    ;no clc, to carry to next word
    sta char_vp+2
    dec char_vp_y
    bne y_loop

  ;add X
  addX_step:
    clc
    lda char_vp
    adc char_vp_x
    sta char_vp
    lda char_vp+2
    adc #0    ;no clc, to carry to next word
    sta char_vp + 2

  ply
  plx
  pla
  rts
print_char_vga:
  ; TO DO safety code... this function assumes a valid ascii char that is supported
  ;current char is in A(ccumulator)
  sta char_current_val
  lda char_vp+2
  sta vidpage+2
  lda char_vp
  sta vidpage
      
  ldy char_y_offset  ;column start
  cpy #300    ;cols - past this will CRLF
  bcc pcv_cont
    jsr gfx_CRLF
  pcv_cont:
  sty char_y_offset_orig   ;remember this offset, so we can come back each row

  ldx #$00
  ;stx $52   ;character pixel row loop counter
  stx charPixelRowLoopCounter   ;character pixel row loop counter

  ; https://www.asc.ohio-state.edu/demarneffe.1/LING5050/material/ASCII-Table.png
  
  _nextRow:
    lda char_current_val
    sec
    sbc #$20  ;translate from ASCII value to address in ROM   ;example: 'a' 0x61 minus 0x20 = 0x41 for location in charmap
    ;multiply by 8 (8 bits per byte)
    asl   ;double
    asl   ;double again
    asl   ;double a third time
    clc
    adc charPixelRowLoopCounter   ;for each loop through rows of pixel, increase this by one, so that following logic fetches the correct char pixel row
    clc
    ;adc #$07 ;advance to the next char
    tax
    lda charmap, x
    AND #$00FF      ; 16-bit adjustment to code
    sta char_from_charmap
    jmp CharMap_Selected
print_hex_vga:
    ;convert scancode/ascii value/other hex to individual chars and display
    ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ;sta $65     ;store A so we can keep using original value
    sta tmpHex
    
    lda #$78    ;'x'
    jsr print_char_vga

    ;high nibble
    lda tmpHex
    and #%11110000
    lsr ;shift high nibble to low nibble
    lsr
    lsr
    lsr
    tay
    lda hexOutLookup, y
    and #$00FF    ;16-bit adjustment
    jsr print_char_vga

    ;low nibble
    lda tmpHex
    and #%00001111
    tay
    lda hexOutLookup, y
    and #$00FF    ;16-bit adjustment
    jsr print_char_vga

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
CharMap_Selected:
    charpix_col1:
      ;lda $50   ;stored current char from appropriate charmap
      lda char_from_charmap   ;stored current char from appropriate charmap
      and #PIXEL_COL1   ;look at the first column of the pixel row and see if the pixel should be set
      beq charpix_col2  ;if the first bit is not a 1 go to the next pixel, otherwise, continue and print the pixel
      lda char_color	;load color stored above
      ;sta [vidpage], y ; write A register to address vidpage + y
      jsr WriteVidPage
    charpix_col2:
      iny   ;shift pixel writing location one to the right
      lda char_from_charmap
      and #PIXEL_COL2
      beq charpix_col3
      lda char_color	;load color stored above
      ;sta [vidpage], y ; write A register to address vidpage + y
      jsr WriteVidPage
    charpix_col3:
      iny
      ;lda charmap1, x
      lda char_from_charmap
      and #PIXEL_COL3
      beq charpix_col4
      lda char_color	;load color stored above
      ;sta [vidpage], y ; write A register to address vidpage + y
      jsr WriteVidPage
    charpix_col4:
      iny
      lda char_from_charmap
      and #PIXEL_COL4
      beq charpix_col5
      lda char_color	;load color stored above
      ;sta [vidpage], y ; write A register to address vidpage + y
      jsr WriteVidPage
    charpix_col5:
      iny
      lda char_from_charmap
      and #PIXEL_COL5
      beq charpix_rowdone
      lda char_color	;load color stored above
      ;sta [vidpage], y ; write A register to address vidpage + y
      jsr WriteVidPage
    ;could expand support beyond 5 colums (up to 8, based on charmap)
    charpix_rowdone:
      jsr gfx_NextVGALine   ;shift pixel writing location down one pixel
      ldy char_y_offset_orig   ;back to first column

      ;check if we are through the 7 rows. if so, jump out. otherwise, start next row of font character.
      inc charPixelRowLoopCounter   ;inc row loop counter
      lda charPixelRowLoopCounter
      cmp #$08  ;see if we have made it through all 7 rows
      bne _nextRow  ;if we have not processed all 7 rows, branch to repeat. otherwise, go to next line

      ;no more rows to process in this character
      ldx #$00
      stx charPixelRowLoopCounter   ;row loop counter
      jmp NextChar  
NextChar:
  ;move the 'cursor' to the right by 6 pixels
  inc char_y_offset
  inc char_y_offset
  inc char_y_offset
  inc char_y_offset
  inc char_y_offset
  inc char_y_offset
  inc rows_remain   ;string char# tracker
  ldx rows_remain
  jmp PrintStringLoop
WriteVidPage:
  ;.setting "RegA16", false
  sep #$20            ;set acumulator to 8-bit
  sta [vidpage], y; write A register (color) to address vidpage + y
  ;.setting "RegA16", true
  rep #$20            ;set acumulator to 16-bit
  rts
WriteVidPageBuffer:
  ;.setting "RegA16", false
  sep #$20            ;set acumulator to 8-bit
  sta [vidpage_buffer], y; write A register (color) to address vidpage + y
  ;.setting "RegA16", true
  rep #$20            ;set acumulator to 16-bit
  rts
PrintString:
  stx xtmp   ;store x
  
  ldx #$00
  stx rows_remain   ;printstring current char tracking
  ;falls into PrintStringLoop
    PrintStringLoop:
      lda message_to_process
      cmp #$00
        beq NoMessage
      cmp #$01
        beq SelectMessage1
      cmp #$02
        beq SelectMessage2
      cmp #$03
        beq SelectMessage3
      cmp #$04
        beq SelectMessage4
      cmp #$05
        beq SelectMessage5
      cmp #$06
        beq SelectMessage6
      cmp #$07
        beq SelectMessage7
      cmp #$08
        beq SelectMessage8
     ;falls into PrintStringLoopCont
PrintStringLoopCont:
  bne print_char_vga    ;where to go when there are chars to process
  ldx xtmp   ;set x back to orig value
  rts
gfx_TestPattern_Animated_HorizontalBar:
  pha
  phx
  phy

  lda #0
  //sta $7002 ;iterations
  sta anim_count ;iterations
  lda #%00000011
  //sta $7000 ;color
  sta anim_color ;color
  ldx #0
  testPatternAnimated_loop_H:
    lda #0
    sta fill_region_start_x
    txa
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    txa
    sta fill_region_end_y
    lda anim_color
    sta fill_region_color
    jsr gfx_FillRegion
    clc
    inx
    cpx #%00000111
    bcc checkLoop_H

    txa
    tay
    dey
    dey
    dey
    dey
    dey
    dey
    dey
    lda #0
    sta fill_region_start_x
    tya
    sta fill_region_start_y
    lda #319
    sta fill_region_end_x
    tya
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion

    checkLoop_H:
    txa
    cmp #240
    bne testPatternAnimated_loop_H
    inc anim_count
    lda anim_count
    cmp #3
    beq animated_out_H

    ldx #0

    lda anim_color
    asl
    asl
    asl
    sta anim_color ;color
    jmp testPatternAnimated_loop_H

  animated_out_H:
  lda #0
  jsr gfx_fillscreen
  ply
  plx
  pla
  rts
gfx_TestPattern_Animated_VerticalBar:
  pha
  phx
  phy

  lda #0
  sta anim_count ;iterations
  lda #%00000011
  sta anim_color ;color
  ldx #0
  testPatternAnimated_loop_V:
    txa
    sta fill_region_start_x
    lda #0
    sta fill_region_start_y
    txa
    sta fill_region_end_x
    lda #239
    sta fill_region_end_y
    lda anim_color
    sta fill_region_color
    jsr gfx_FillRegion
    clc
    inx
    cpx #%00000111
    bcc checkLoop_V

    txa
    tay
    dey
    dey
    dey
    dey
    dey
    dey
    dey
    tya
    sta fill_region_start_x
    lda #0
    sta fill_region_start_y
    tya
    sta fill_region_end_x
    lda #239
    sta fill_region_end_y
    lda #%00000000
    sta fill_region_color
    jsr gfx_FillRegion

    checkLoop_V:
    txa
    cmp #320
    bne testPatternAnimated_loop_V
    inc anim_count
    lda anim_count
    cmp #3
    beq animated_out_V

    ldx #0

    lda anim_color
    asl
    asl
    asl
    sta anim_color ;color
    jmp testPatternAnimated_loop_V

  animated_out_V:
    lda #0
    jsr gfx_fillscreen

  ply
  plx
  pla
  rts
gfx_DrawPixel:

  ;put items on stack, so we can return them
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack

  ;testing...
  ;lda #$44
  ;jsr print_char_vga

  ;should already be filled in with desired pixel location:
  ;sta fill_region_start_x
  ;sta fill_region_start_y
  ;push registers to stack?

  ;store current 'cursor' location
  lda vidpage + 2
  pha
  lda vidpage
  pha
  phy
  tya

  lda fill_region_start_y
  sta jump_to_line_y
  jsr gfx_JumpToLine

  ldy fill_region_start_x     ;horizontal pixel location, 0 to 99
  lda fill_region_color
    
  ;sta (vidpage), y; write A register (color) to address vidpage + y
  jsr WriteVidPage

  ;put things back and return to sender
  ply
  pla
  sta vidpage
  pla
  sta vidpage + 2

  ;return items from stack
  ply ;stack to y
  plx ;stack to x
  pla ;stack to a

  rts

;SelectMessge subroutines
    NoMessage:
      ;ldx $40   ;set x back to orig value
      ldx xtmp   ;set x back to orig value
      rts
    SelectMessage1:
      lda message1,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage2:
      lda message2,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage3:
      lda message3,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage4:
      lda message4,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage5:
      lda message5,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage6:
      lda message6,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage7:
      lda message7,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont
    SelectMessage8:
      lda message8,x
      AND #$00FF      ; 16-bit adjustment to code
      jmp PrintStringLoopCont  

;Predefined messages
message1: .asciiz "Red 0-7 (3 bits)"
message2: .asciiz "Green 0-7 (3 bits)"
message3: .asciiz "Blue 0-3 (2 bits)"
message4: .asciiz "White (mix of bits per column above)"
message5: .asciiz "RGB 0-255 (8 bits)"
message6: .asciiz "Dynamically-generated Test Pattern"
message7: .asciiz "320x240x1B (RRRGGGBB)  -- 5x7 fixed width font"
message8: .asciiz "Welcome!"
