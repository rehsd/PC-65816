MyCode.65816.asm
.setting "HandleLongBranch", true
.setting "RegA16", true
.setting "RegXY16", true
.include "vars.asm"
.include "romData.asm"


.org $0000          ;wasted portion of ROM
    .word $ABCD     ;need something to write at $00 -- wasting first 32K of ROM and using addresses for RAM
                    ;if starting with .org $8000, assembler ends up writing it to $0000, which won't work
.org $8000          ;start of usable ROM

.include "graphics.asm"
.include "lcd.asm"
.include "keyboard.asm"

reset:
    sei               ;disable interrupts
    cld               ;disable BCD
    ;ldx #$ff          ;initialize stack    - old
    ;txs               ;initialize stack

    clc
    xce
    rep #$30            ;set 16-bit mode

    ; ******* KEYBOARD *******    init keyboard handling memory **************
    lda #$00
    sta kb_flags
    sta kb_flags2
    sta kb_buffer

    sta kb_wptr
    sta kb_rptr    
    ; ************************************************************************

    ;VIA config
    ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    //lda #%0000000001111111	        ; Disable all interrupts
    lda #%0000000010000010	        ; Enable CA1 interrupt (keyboard)

    sta VIA1_IER

    lda #%0000000011111111 
    sta VIA1_DDRB           ; Set all for LCD to output      ;LCD
    lda #%0000000000000000 
    sta VIA1_DDRA           ; Set all pins on port A to input       ;Keyboard

    lda #$FFFE  ;start counting up at this value; higher # = shorter delay
    sta delayDuration

    ; ******* LCD *******
    ;see page 42 of https://eater.net/datasheets/HD44780.pdf
    ;when running 6502 at ~5.0 MHz (versus 1.0 MHz), sometimes init needs additional call or delay
    jsr lcd_init

    lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
    jsr lcd_instruction
    ;call again for higher clock speed setup
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

    
    lda #0    ;black
    jsr gfx_fillscreen

    // lda #%11100000    ;
    // jsr gfx_fillscreen

    // lda #%00011100    ;
    // jsr gfx_fillscreen

    // lda #%00000011    ;
    // jsr gfx_fillscreen

    // lda #%11111111    ;
    // jsr gfx_fillscreen

    // lda #0    ;black
    // jsr gfx_fillscreen

    // lda #%00000001 ; Clear display
    // jsr lcd_instruction

    // ldx #0
    // lda #10
    // sta fill_region_start_x
    // lda #10
    // sta fill_region_start_y
    // lda #30
    // sta fill_region_end_x
    // lda #30
    // sta fill_region_end_y
    // animTestLoop:
    //   lda #%11111100
    //   sta fill_region_color
    //   jsr gfx_FillRegion

    //   lda #0
    //   sta fill_region_color
    //   jsr gfx_FillRegion
    //   jsr delay
    //   inc fill_region_start_x
    //   inc fill_region_start_y
    //   inc fill_region_end_x
    //   inc fill_region_end_y

    //   inx
    //   cpx #200
    //   bne animTestLoop

    ;jsr gfx_StartScreen
    ;jsr gfx_TestPattern_Animated_HorizontalBar
    ;jsr gfx_TestPattern_Animated_VerticalBar
    jsr gfx_TestPattern
    lda #0
    jsr delay
    jsr delay
    jsr delay

    ;lda #%10010010    ;grey
    ;jsr gfx_fillscreen

    lda #$F000
    sta delayDuration
    shipLoop:
      jsr gfx_TestPattern_Animated_Ship
      clc
      lda delayDuration
      adc #$111
      bcs cont1
      sta delayDuration
      jmp shipLoop
    
    cont1:
    lda #$00  ;done processing pre-defined strings
    sta message_to_process

    // lda #100
    // sta char_vp_x    ;0 to 319
    // lda #100
    // sta char_vp_y    ;0 to 239
    // jsr gfx_SetCharVpByXY
    // lda #%00011111
    // sta char_color
    // lda #$47  ;'G'  
    // jsr print_char_vga
    // lda #$6F  ;'o'  
    // jsr print_char_vga

    cli   ;enable interrupts
    jmp loop_label

Delay:
    pha       ;save current accumulator
    lda delayDuration	;counter start - increase number to shorten delay
    Delayloop:
        clc
        adc #01
        bne Delayloop
    pla
    rts

loop_label:
  ;sit here and loop, process key presses via interrupts as they come in
  sei
  lda kb_rptr
  AND #$00FF      ; 16-bit adjustment to code
  cmp kb_wptr
  cli                   ;Clear Interrupt Disable
  bne key_pressed

  ;Handle KB flags
  jmp Handle_KB_flags

irq_label:
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack

  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code
  AND #RELEASE   ; check if we're releasing a key
  beq read_key   ; otherwise, read the key

  lda kb_flags
  AND #$00FF      ; 16-bit adjustment to code
  eor #RELEASE   ; flip the releasing bit

  sta kb_flags

  lda VIA1_PORTA      ; read key value that is being released
  AND #$00FF      ; 16-bit adjustment to code
  
  cmp #$12       ; left shift
  beq shift_up
  cmp #$59       ; right shift
  beq shift_up 

  jmp irq_done
irq_done:
  ;return items from stack
  ply ;stack to y
  plx ;stack to x
  pla ;stack to a
  rti


;Convert keyboard scan codes to ASCII values
; *** Set 1 *** See http://www.vetra.com/scancodes.html
; Used for keyboard when running emulator
; This set is incomplete and needs full testing.
keymap:
  .byte "??1234567890-=??qwertyuiop[]??asdfghjkl;'`??zxcvbnm,./????????"
  .byte "????????????????????????????????????????????????????????????????"
  .byte "????????????????????????????????????????????????????????????????"
  .byte "????????????????????????????????????????????????????????????????"
keymap_shifted:
  .byte "?!@#$%^&*()_+??QWERTYUIOP{}??ASDFGHJKL:?~?ZXCVBNM<>?????????"
  .byte "????????????????????????????????????????????????????????????????"
  .byte "????????????????????????????????????????????????????????????????"
  .byte "????????????????????????????????????????????????????????????????"


// ;PS/2 keyboard scan codes -- Set 2 or 3
// keymap:
//   .byte "????????????? `?"          ; 00-0F
//   .byte "?????q1???zsaw2?"          ; 10-1F
//   .byte "?cxde43?? vftr5?"          ; 20-2F
//   .byte "?nbhgy6???mju78?"          ; 30-3F
//   .byte "?,kio09??./l;p-?"          ; 40-4F
//   .byte "??'?[=????",$0a,"]?",$5c,"??"    ; 50-5F     orig:"??'?[=????",$0a,"]?\??"   '\' causes issue with retro assembler - swapped out with hex value 5c
//   .byte "?????????1?47???"          ; 60-6F0
//   .byte "0.2568",$1b,"??+3-*9??"    ; 70-7F
//   .byte "????????????????"          ; 80-8F
//   .byte "????????????????"          ; 90-9F
//   .byte "????????????????"          ; A0-AF
//   .byte "????????????????"          ; B0-BF
//   .byte "????????????????"          ; C0-CF
//   .byte "????????????????"          ; D0-DF
//   .byte "????????????????"          ; E0-EF
//   .byte "????????????????"          ; F0-FF
// keymap_shifted:
//   .byte "????????????? ~?"          ; 00-0F
//   .byte "?????Q!???ZSAW@?"          ; 10-1F
//   .byte "?CXDE#$?? VFTR%?"          ; 20-2F
//   .byte "?NBHGY^???MJU&*?"          ; 30-3F
//   .byte "?<KIO)(??>?L:P_?"          ; 40-4F
//   .byte "??",$22,"?{+?????}?|??"          ; 50-5F      orig:"??"?{+?????}?|??"  ;nested quote - compiler doesn't like - swapped out with hex value 22
//   .byte "?????????1?47???"          ; 60-6F
//   .byte "0.2568???+3-*9??"          ; 70-7F
//   .byte "????????????????"          ; 80-8F
//   .byte "????????????????"          ; 90-9F
//   .byte "????????????????"          ; A0-AF
//   .byte "????????????????"          ; B0-BF
//   .byte "????????????????"          ; C0-CF
//   .byte "????????????????"          ; D0-DF
//   .byte "????????????????"          ; E0-EF
//   .byte "????????????????"          ; F0-FF


.org $FFEE
    .word irq_label   //native 16-bit mode interrupt vector

.org $FFFC
    .word reset
    //.word irq_label   //emulation interrupt vector
    