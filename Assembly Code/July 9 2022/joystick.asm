.setting "HandleLongBranch", true
.setting "RegA16", true
.setting "RegXY16", true

joystick_init:
    stz game_mario_left_sprite_next
    lda #$80
    sta game_mario_right_sprite_next
    stz game_mario_sprite_next

    rts
Poll_Controller:
    //test routine for now... eventually to go in timer or other location
        lda VIA4_PORTB
        and #$00FF
        cmp tmpJoystickPreviousValue
        beq pollOut
        sta tmpJoystickPreviousValue
        jsr SPI_LCD_Update_Controller_Screen
        jsr Delay0
        jsr Delay0
        jsr Delay0
        pollOut:
    rts
Joystick_Interrupt_Handler:
    lda VIA4_PORTB
    and #$00FF                    ;16-bit adjustment -- only need LSB
    sta tmpJoystickInterrupt
    jsr SPI_LCD_Print_Binary16
    jsr Delay0
    jsr Delay0
    jsr Delay0
    jsr Delay0
    rts

    lda VIA4_PORTB
    sta tmpJoystickInterrupt
    eor #%10000000
    beq nes7
    lda tmpJoystickInterrupt
    eor #%01000000
    beq nes6
    lda tmpJoystickInterrupt
    eor #%00100000
    beq nes5
    lda tmpJoystickInterrupt
    eor #%00010000
    beq nes4
    lda tmpJoystickInterrupt
    eor #%00001000
    beq nes3
    lda tmpJoystickInterrupt
    eor #%00000100
    beq nes2
    lda tmpJoystickInterrupt
    eor #%00000010
    beq nes1
    lda tmpJoystickInterrupt
    eor #%00000001
    beq nes0

    rts

    // // sep #$30
    // lda VIA4_PORTA                ;clear interrupt
    // // rep #$30
    // and #$00FF                    ;16-bit adjustment -- only need LSB
    // sta tmpJoystickInterrupt         ;store original value read from port

    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE
    // jsr TIMER_ROUTINE

    // jih_next:
    // eor #JOYSTICK_LEFT
    // beq Handle_Joystick_Left

    // lda tmpJoystickInterrupt
    // eor #JOYSTICK_UP
    // beq Handle_Joystick_Up

    // lda tmpJoystickInterrupt
    // eor #JOYSTICK_RIGHT
    // beq Handle_Joystick_Right

    // lda tmpJoystickInterrupt
    // eor #JOYSTICK_DOWN
    // beq Handle_Joystick_Down

    // lda tmpJoystickInterrupt
    // eor #JOYSTICK_BUTTON
    // beq Handle_Joystick_Button

    rts
Update_Controller_Debug_Screen:
    pha
    phx
    phy
    
    .setting "RegA16", true

    jsr SPI_LCD_Update_Controller_Screen

    ply
    plx
    pla

    .setting "RegA16", false
    rts
nes7:
    pha
    phx
    phy
    
    .setting "RegA16", true

    lda #'7'
    jsr SPI_Send_Char

    ply
    plx
    pla

    .setting "RegA16", false

    bra Joystick_Interrupt_Handler

nes6:
    lda #'6'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes5:
    lda #'5'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes4:
    lda #'4'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes3:
    lda #'3'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes2:
    lda #'2'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes1:
    lda #'1'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler
nes0:
    lda #'0'
    jsr SPI_Send_Char
    bra Joystick_Interrupt_Handler

Handle_Joystick_Left:
    // lda #'L'
    // jsr print_char_lcd

    ldx fill_region_start_x
    //cpx #$0006          ;left side margin to a) keep mouse in bounds and to prevent a negative x pos (more safety code needed)
    //bmi hml_out
    dex
    dex
    dex
    stx fill_region_start_x

    jsr RestoreTileMario
    jsr MarioMoveLeft
    jsr DrawMario
    
    jsr Delay0
    bra Joystick_Interrupt_Handler
    //hml_out:

    rts

Handle_Joystick_Up:
    // lda #'U'
    // jsr print_char_lcd
    rts

Handle_Joystick_Right:
    // lda #'R'
    // jsr print_char_lcd

    ldx fill_region_start_x
    //cpx #$0006          ;left side margin to a) keep mouse in bounds and to prevent a negative x pos (more safety code needed)
    //bmi hml_out
    inx
    inx
    inx
    stx fill_region_start_x

    jsr RestoreTileMario
    jsr MarioMoveRight
    jsr DrawMario

    jsr Delay0
    bra Joystick_Interrupt_Handler

    rts

Handle_Joystick_Down:
    // lda #'D'
    // jsr print_char_lcd
    rts

Handle_Joystick_Button:
    // lda #'B'
    // jsr print_char_lcd
    rts

MarioMoveLeft:
    pha
    lda game_mario_left_sprite_next
    cmp #$50
    beq mml_toZero
    clc
    adc #$10
    sta game_mario_left_sprite_next
    bra mml_exit
    mml_toZero:
        stz game_mario_left_sprite_next

    mml_exit:
    lda game_mario_left_sprite_next
    sta game_mario_sprite_next
    //jsr print_hex_lcd_16
    pla 
    rts

MarioMoveRight:
    pha
    lda game_mario_right_sprite_next
    cmp #$B0
    beq mmr_to60
    clc
    adc #$10
    sta game_mario_right_sprite_next
    bra mmr_exit
    mmr_to60:
        lda #$60
        sta game_mario_right_sprite_next

    mmr_exit:
    lda game_mario_right_sprite_next
    sta game_mario_sprite_next
    //jsr print_hex_lcd_16
    pla
    rts
DrawMario:
    pha
    //lda #$0000
    lda game_mario_sprite_next
    //jsr print_hex_lcd_16
    sta gfx_ERAM_source_address
    //lda #$0000
    //lda #150
    //sei
    //sbc fill_region_start_x
    lda #$A000
    clc
    adc fill_region_start_x
    sta gfx_VRAM_dest_address
    jsr gfx_CopySprite16ToVRAM
    pla
    rts

RestoreTileMario:
    pha ;a to stack
    ;phx ;x to stack
    ;phy ;y to stack

    lda fill_region_start_y
    sta gfx_tile_start_y
    lda fill_region_start_x
    adc #15
    sta gfx_tile_start_x

    // ;since VRAM is split between two banks, check if we're on the edge, and if so, fill the tile in the other bank
    // ;if y pos is between 103 and 136, draw the two tiles on the border
    // lda gfx_tile_start_y
    // cmp #130        ;check for first video bank
    // bcs restoreTileOutsideMargin      ;above the margin, perform normal tile copy
    // cmp #112           
    // bcc restoreTileOutsideMargin      ;below the margin, perform normal tile copy
    // ;in the margin, draw both tiles. use x pos, but then specify the two y's manually
    // lda #113                ;draw tile just above middle line, starting at this position
    // sta gfx_tile_start_y
    // jsr gfx_CopyTileToVRAM
    // lda #128                ;draw tile just below middle line, starting at this position
    // sta gfx_tile_start_y
    // jsr gfx_CopyTileToVRAM
    // ;bra restoreTileExit

    // restoreTileOutsideMargin:
    jsr gfx_CopyTileToVRAM

    sec
    sbc #32
    sta gfx_tile_start_x
    jsr gfx_CopyTileToVRAM


    // restoreTileExit:
    ;ply ;stack to y
    ;plx ;stack to x
    pla ;stack to a
    rts