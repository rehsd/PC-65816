;************************* General Addressing Overview ***********************************
;   RAM			                0x000000-0x007FFF           32K
;   ROM			                0x008000-0x07FFFF           480K
;   EXT RAM			            0x080000-0x0FFFFF           512K
;   I/O 10:0000                 0x100000-0x10FFFF           64K
;     VIA1 (PS2 KBD)		        0x108000-0x10800F
;     VIA2 (LCD, BARGRAPH)	        0x104000-0x10400F
;     VIA3 (USB MOUSE)		        0x102000-0x10200F
;     VIA4 (Future VIA)             0x101000-0x10100F
;     VIA5 (Future VIA)             0x100800-0x10080F
;     SOUND CARD			        0x100000-0x1007FF
;   I/O 11-1F:0000 (Future)     0x110000-0x1FFFFF
;   VIDEO   			        0x200000-0x21FFFF           128K
;************************* /General Addressing Overview **********************************

;************************* Basic RAM Use Summary ($0000 to $07FF) ************************
;   $0040 to $004F          Keyboard
;   $0050 to $009F          VGA
;   $1000 to $10FF          Keyboard
;   $1100 to $11FF          MISC
;   $1200 to $12FF          Mouse
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
    ;Onboard VIA for PS/2 Keyboard and control lines
    ;IRQ 0
    VIA1_ADDR  = $108000
    VIA1_PORTB = VIA1_ADDR + VIA_PORTB
    VIA1_PORTA = VIA1_ADDR + VIA_PORTA
    VIA1_DDRB  = VIA1_ADDR + VIA_DDRB
    VIA1_DDRA  = VIA1_ADDR + VIA_DDRA
    VIA1_IFR   = VIA1_ADDR + VIA_IFR
    VIA1_IER   = VIA1_ADDR + VIA_IER

    ;VIA2 Address Line A14 - %00010000:01000000:00000000 - $10:4000
    ;LCD add-in card
    ;No IRQ
    VIA2_ADDR  = $104000
    VIA2_PORTB = VIA2_ADDR + VIA_PORTB
    VIA2_PORTA = VIA2_ADDR + VIA_PORTA
    VIA2_DDRB  = VIA2_ADDR + VIA_DDRB
    VIA2_DDRA  = VIA2_ADDR + VIA_DDRA
    VIA2_IFR   = VIA2_ADDR + VIA_IFR
    VIA2_IER   = VIA2_ADDR + VIA_IER

    ;VIA3 Address Line A13 - %00010000:00100000:00000000 - $10:2000
    ;USB mouse add-in card
    ;IRQ 7
    VIA3_ADDR  = $102000
    VIA3_PORTB = VIA3_ADDR + VIA_PORTB
    VIA3_PORTA = VIA3_ADDR + VIA_PORTA
    VIA3_DDRB  = VIA3_ADDR + VIA_DDRB
    VIA3_DDRA  = VIA3_ADDR + VIA_DDRA
    VIA3_IFR   = VIA3_ADDR + VIA_IFR
    VIA3_IER   = VIA3_ADDR + VIA_IER
    
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

;************************* USB Mouse *************************************
;   $1200 to $12FF
    MOUSE_UP                 = %00000100     
    MOUSE_RIGHT_UP           = %00001000     
    MOUSE_RIGHT              = %00001100     
    MOUSE_RIGHT_DOWN         = %00010000     
    MOUSE_DOWN               = %00010100     
    MOUSE_LEFT_DOWN          = %00011000     
    MOUSE_LEFT               = %00011100     
    MOUSE_LEFT_UP            = %00100000     

    MOUSE_CLICK_LEFT         = %00000001
    MOUSE_CLICK_MIDDLE       = %00000010     
    MOUSE_CLICK_RIGHT        = %00000011  

    tmpMouseInterrupt       = $1200     ;Temp variable used in mouse interrupt handling
    tmpMouseInterruptMasked = $1202     ;Temp variable used in mouse interrupt handling
;************************* /USB Mouse ************************************


;************************* Audio *************************************
;************************* /Audio *************************************


;************************* MISC *************************************
;   Using $1100 to $11FF
    delayDuration           = $1100     ;Count from this number (high byte) to FF - higher number results in shorter delay
    barGraphVal             = $1102     ;VIA2 bargraph value
;************************* /MISC *************************************

;************************* VGA *************************************
;   Using $0050 to $00FF

    ;ASCII_CHARMAP           = %11100000
    PIXEL_COL1              = %10000000
    PIXEL_COL2              = %01000000
    PIXEL_COL3              = %00100000
    PIXEL_COL4              = %00010000
    PIXEL_COL5              = %00001000
    
    ;procedure internal      $0050 to $005F
    
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
    char_vp                 = $007C     ;4 bytes - position for character to be drawn
    char_color              = $0080
    char_y_offset           = $0082
    char_y_offset_orig      = $0084
    charPixelRowLoopCounter = $0086     ;character pixel row loop counter
    char_current_val        = $0088
    char_from_charmap       = $008A     ;stored current char from appropriate charmap
    message_to_process      = $008C
    xtmp                    = $008E
    char_vp_x               = $0090
    char_vp_y               = $0092
    anim_color              = $0094
    anim_count              = $0096
    move_size               = $0098
    move_source             = $009A
    move_dest               = $009C
    move_counter            = $009E
    move_frame_counter      = $00A0
    mvn_wtransp_src_bank    = $00A2
    mvn_wtransp_dest_bank   = $00A4
    mvn_wtransp_length      = $00A6
    mvn_wtransp_src_addr    = $00A8
    mvn_wtransp_dest_addr   = $00AA
    move_counter_wb         = $00AC
    move_source_wb          = $00AE
    move_dest_wb            = $00B0
    vidpage_buffer          = $00B2     ;4 bytes
    vidpagePrev_buffer      = $00B6     ;4 bytes
    tmpHex                  = $00BA     ;2 bytes
    currently_drawing       = $00BC     ;0x01 if yes
    mouseFillRegionStarted  = $00BE     ;used to track if mouse right-button has been used to mark the start of a region to fill
    fill_region_clk_start_x = $00C0     ;when drawing rectangles by using keyboard, joystick, mouse... capture the start of bounds
    fill_region_clk_start_y = $00C2     ;when drawing rectangles by using keyboard, joystick, mouse... capture the start of bounds
    pixel_prev_color        = $00C4     ;Previous pixel COLOR       0 to 63
    pixel_prev_x            = $00C6     ;Previous pixel x position  0 to 99
    pixel_prev_y            = $00C8     ;Previous pixel y position  0 to 63



    
;************************* /VGA *************************************


