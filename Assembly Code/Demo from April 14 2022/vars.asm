;************************* Basic RAM Use Summary ($0000 to $07FF) ************************
;   $0040 to $004F          Keyboard
;   $0050 to $009F          VGA
;   $1000 to $10FF          Keyboard
;   $1100 to $11FF          MISC
;
;************************* /Basic RAM Use Summary*****************************************

;************************* ROM Use Summary ($008000 to $07FFFF) **************************
;   $000000 to $007FFF      Unavailable - used by Basic RAM
;   $008000 to $00FFFF      Primary code
;   $010000                 Charmap(s)
;   $020000                 Embedded graphics
;************************* /ROM Use Summary***********************************************

;************************* Extended RAM Use Summary ($080000 to $0FFFFF) *****************
;   $080000 to $0...         ...available
;************************* /ROM Use Summary***********************************************

;************************* VIAs *************************************
    ;These addresses are never to be used by themselves, rather to add to specific VIA base addresses
    ;VIA Registers
    VIA_PORTB = $00
    VIA_PORTA = $01
    VIA_DDRB  = $02
    VIA_DDRA  = $03
    VIA_T1C_L = $04
    VIA_T1C_H = $05
    VIA_T1L_L = $06
    VIA_T1L_H = $07
    VIA_T2C_L = $08
    VIA_T2C_H = $09
    VIA_SR    = $0A
    VIA_ACR   = $0B
    VIA_PCR   = $0C
    VIA_IFR   = $0D
    VIA_IER   = $0E

    ;VIA1 Address Line A15 - %00010000:10000000:00000000 - $10:8000
    VIA1_ADDR  = $108000
    VIA1_PORTB = VIA1_ADDR + VIA_PORTB
    VIA1_PORTA = VIA1_ADDR + VIA_PORTA
    VIA1_DDRB  = VIA1_ADDR + VIA_DDRB
    VIA1_DDRA  = VIA1_ADDR + VIA_DDRA
    VIA1_IFR   = VIA1_ADDR + VIA_IFR
    VIA1_IER   = VIA1_ADDR + VIA_IER

    ;VIA2 Address Line A14 - %00010000:01000000:00000000 - $10:4000
    ;VIA2_ADDR  = $104000
    ;VIA3 Address Line A13 - %00010000:00100000:00000000 - $10:2000
    ;VIA3_ADDR  = $102000
    ;VIA4 Address Line A12 - %00010000:00010000:00000000 - $10:1000
    ;VIA4_ADDR  = $101000
    ;VIA5 Address Line A11 - %00010000:00001000:00000000 - $10:0800
    ;VIA5_ADDR  = $100800

    ;Remaining addresses in $10:0000 reserved for sound card dual-port addressing
    ;%00010000:00000000:00000000 - $10:0000
    ;The remaining 10 bits after A10 (A10-A0) are used to address full dual-port RAM on sound card
    ;Sound card address range: $10:0000 to $10:07FF
    ;Can use IRQs previously reserved for VIA7-8 (for joysticks, etc.)
    
;************************* /VIAs *************************************

;************************* LCD *************************************
    E   = %01000000
    RW  = %00100000
    RS  = %00010000
;************************* /LCD *************************************

;************************* Keyboard *************************************
;   Using $0040 to $004F, $1000 to $10FF
;   procedure internal      $004A to $004F
    RELEASE                 = %0000000000000001
    SHIFT                   = %0000000000000010
    ARROW_LEFT              = %0000000000000100
    ARROW_RIGHT             = %0000000000001000
    ARROW_UP                = %0000000000010000
    ARROW_DOWN              = %0000000000100000
    NKP5                    = %0000000001000000
    NKP_PLUS                = %0000000010000000

    ;for kb_flags2
    NKP_INSERT              = %0000000000000001
    NKP_DELETE              = %0000000000000010
    NKP_MINUS               = %0000000000000100
    NKP_ASTERISK            = %0000000000001000
    PRINTSCREEN             = %0000000000010000
    ;room for four more

    kb_wptr                 = $0040
    kb_rptr                 = $0042
    kb_flags                = $0044
    kb_flags2               = $0046
    kb_buffer               = $1000  ; 256-byte kb buffer 1000-10FF

;************************* /Keyboard *************************************



;************************* Audio *************************************
;************************* /Audio *************************************


;************************* MISC *************************************
;   Using $1100 to $11FF
    delayDuration   = $1100     ;Count from this number (high byte) to FF - higher number results in shorter delay
;************************* /MISC *************************************

;************************* VGA *************************************
;   Using $0050 to $00FF
;   procedure internal      $0050 to $005F
    color                   = $0060     ;2 bytes
    row                     = $0062     ;2 bytes
    vidpage                 = $0064     ;4 bytes
    vidpagePrev             = $0068     ;4 bytes
    fill_region_start_x     = $006C     ;Horizontal pixel position, 0 to 319
    fill_region_start_y     = $006E     ;Vertical pixel position,   0 to 239
    fill_region_end_x       = $0070     ;Horizontal pixel position, 0 to 319
    fill_region_end_y       = $0072     ;Vertical pixel position,   0 to 239
    fill_region_color       = $0074     ;Color for fill,            0 to 255  
    jump_to_line_y          = $0076     ;Line to jump to,           0 to 239
    col_end                 = $0078     ;Used in FillRegion to track end column for fill
    rows_remain             = $007A     ;Used in FillRegion to track number of rows to process
    ;pixel_prev_x            = $A6       ;Previous pixel x position  0 to 99
    ;pixel_prev_y            = $A7       ;Previous pixel y position  0 to 63
    ;pixel_prev_color        = $A8       ;Previous pixel COLOR       0 to 63
    ;currently_drawing       = $A9       ;0x01 if yes
    ;fill_region_clk_start_x = $AA       ;when drawing rectangles by using keyboard, joystick, mouse... capture the start of bounds
    ;fill_region_clk_start_y = $AB
    char_vp                 = $007C     ;4 bytes - position for character to be drawn
    char_color              = $0080
    char_y_offset           = $0082
    char_y_offset_orig      = $0084
    charPixelRowLoopCounter = $0088     ;character pixel row loop counter
    char_current_val        = $008A
    char_from_charmap       = $008C     ;stored current char from appropriate charmap
    message_to_process      = $008E
    xtmp                    = $0090
    char_vp_x               = $0092
    char_vp_y               = $0094
    anim_color              = $0096
    anim_count              = $0098
    move_size               = $009A
    move_source             = $009C
    move_dest               = $009E
    move_counter            = $00A0
    move_frame_counter      = $00A2
    ;ASCII_CHARMAP           = %11100000
    PIXEL_COL1              = %10000000
    PIXEL_COL2              = %01000000
    PIXEL_COL3              = %00100000
    PIXEL_COL4              = %00010000
    PIXEL_COL5              = %00001000
    
;************************* /VGA *************************************


