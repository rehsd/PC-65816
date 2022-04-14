gfx_fillscreen:
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
    sta [vidpage], y                                                                        ;8031
    ;sta vidpage, y                                                                        ;8031
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
    ;sta $54 ; rows remaining
    sta rows_remain ; rows remaining
    inc rows_remain ; add one to get count of rows to process

    gfx_FillRegionLoopYloop:
        ldy fill_region_start_x     ;horizontal pixel location, 0 to 319
        lda fill_region_color
            
        gfx_FillRegionLoopXloop:
            ;sta (vidpage), y; write A register (color) to address vidpage + y
            sta [vidpage], y; write A register (color) to address vidpage + y
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
gfx_TestPattern_Animated_Ship:
  ;ship sprite stored on ROM at ;$020000 to $0203FF
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
    lda #$0
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
      sta [vidpage], y                                                                        ;8031
      ;sta vidpage, y                                                                        ;8031
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
  //TO DO If offset is at bounds, move to the next line
  ;sty $44   ;remember this offset, so we can come back each row
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
CharMap_Selected:
    charpix_col1:
      ;lda $50   ;stored current char from appropriate charmap
      lda char_from_charmap   ;stored current char from appropriate charmap
      and #PIXEL_COL1   ;look at the first column of the pixel row and see if the pixel should be set
      beq charpix_col2  ;if the first bit is not a 1 go to the next pixel, otherwise, continue and print the pixel
      lda char_color	;load color stored above
      ;sta (vidpage), y ; write A register to address vidpage + y
      sta [vidpage], y ; write A register to address vidpage + y
    charpix_col2:
      iny   ;shift pixel writing location one to the right
      lda char_from_charmap
      and #PIXEL_COL2
      beq charpix_col3
      lda char_color	;load color stored above
      sta [vidpage], y ; write A register to address vidpage + y
    charpix_col3:
      iny
      ;lda charmap1, x
      lda char_from_charmap
      and #PIXEL_COL3
      beq charpix_col4
      lda char_color	;load color stored above
      sta [vidpage], y ; write A register to address vidpage + y
    charpix_col4:
      iny
      lda char_from_charmap
      and #PIXEL_COL4
      beq charpix_col5
      lda char_color	;load color stored above
      sta [vidpage], y ; write A register to address vidpage + y
    charpix_col5:
      iny
      lda char_from_charmap
      and #PIXEL_COL5
      beq charpix_rowdone
      lda char_color	;load color stored above
      sta [vidpage], y ; write A register to address vidpage + y
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
message8: .asciiz "..."
