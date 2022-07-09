;Stack pointer set to 0x7FFF
;Native mode, 16-bit registers assumed. Any procedure changing, should set back at end of procedure.

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
.include "via.asm"
.include "lcd.asm"
.include "keyboard.asm"
.include "mouse.asm"
.include "sound.asm"
.include "joystick.asm"
.include "spi.asm"
.include "Eater8bit.asm"

reset:
  sei               ;disable interrupts
  cld               ;disable BCD
  clc
  xce
  rep #$30            ;set 16-bit mode
  lda #$7FFF
  tcs               ;move stack pointer to #$7FF

  jsr via_init
  jsr sound_init
  rep #$20  ;set acumulator to 16-bit
  .setting "RegA16", true

  stz kb_enable
  jsr keyboard_init
  jsr video_init
  jsr joystick_init

  ;starting center pixel for drawing
  lda #160
  sta fill_region_start_x
  lda #$0050  //#120
  sta fill_region_start_y
  lda #%11111111  ;white
  sta fill_region_color
  //lda #%00100101
  //lda #%11100000    ;set to initial screen fill color
  //sta pixel_prev_color
  stz currently_drawing
  //jsr gfx_DrawPixelTILES

  lda #$FF00
  sta VIA1_TIMER1_Counter

  jsr SPI_Init

  
  ;startup complete
  jsr SPI_LCD_Print_Ready
  cli   ;enable interrupts

  jsr Eater8_Init

  jmp loop_label

loop_label:
  ;sit here and loop, process key presses via interrupts as they come in
  sei
  lda kb_rptr
  AND #$00FF      ; 16-bit adjustment to code
  cmp kb_wptr
  cli                   ;Clear Interrupt Disable
  bne key_pressed
  jsr Eater8_ClockTick

  jsr Poll_Controller
  ;Handle KB flags
  ;jmp Handle_KB_flags
  jmp loop_label
irq_label:
  phb
  phd
  rep #$30    ;16-bit registers
  pha ;a to stack
  phx ;x to stack
  phy ;y to stack
  
  ;check interrupts in order of priority
  lda  VIA1_IFR		        ; Check status register for VIA1        ; PS/2 keyboard, Timer1
  and #%10000000
  bne  VIA1_IRQ_Handler		; Branch if VIA1 is interrupt source

  lda  VIA3_IFR		        ; Check status register for VIA3        ; USB mouse
  and #%10000000
  bne  VIA3_IRQ_Handler		; Branch if VIA3 is interrupt source

  lda VIA4_IFR            ; Joystick, NES controller
  and #%10000000
  bne VIA4_IRQ_Handler

  lda  VIA2_IFR		       ; Check status register for VIA2        ; LCD, bar graph
  and #%10000000
  bne  VIA2_IRQ_Handler			     ; Branch if VIA2 is interrupt source

  ;Should never get here unless missing a branch above for the interrupt source
  bra irq_done
VIA1_IRQ_Handler:     ;PS/2 Keyboard, Timer 1
  ;check interrupt source on VIA IER (T1, T2, CB1, CB2, SR, CA1, CA2)
  lda VIA1_IFR
  and VIA1_IER
  sta IRQ_SOURCE
  and #%01000000
    bne VIA1_T1_handler   ;--Timer 1
  lda IRQ_SOURCE
  and #%00000010
    bne VIA1_CA1_handler   ;--PS/2 Keyboard
  bra irq_done  //shouldn't get here
VIA2_IRQ_Handler:     ;Timer 1
  ;check interrupt source on VIA IER (T1, T2, CB1, CB2, SR, CA1, CA2)
  // lda VIA2_IFR
  // and VIA2_IER
  // asl
  //   bmi VIA2_T1_handler   ;--Timer 1
    //bra VIA2_T1_handler
  // asl
  //   ;bmi VIA2_T2_handler
  // asl
  //   ;bmi VIA2_CB1_handler
  // asl
  //   ;bmi VIA2_CB2_handler
  // asl
  //   ;bmi VIA2_SR_handler
  // asl
  //   ;bmi VIA2_CA1_handler
  // asl
  //   ;bmi VIA1_CA2_handler

  // bra irq_done
VIA1_CA1_handler:   ;--PS/2 Keyboard
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
  bra irq_done
VIA1_T1_handler:    ;--Timer 1 handler
  pha
  jsr TIMER_ROUTINE
  T1_out:
  lda VIA1_T1C_L
  pla
  bra irq_done
TIMER_ROUTINE:
  pha
  inc VIA1_TIMER1_Counter
  bne tr_out
  //stuff to do at timer interval:
  //lda #'T'
  //jsr print_char_vga
  lda #$FF00
  sta VIA1_TIMER1_Counter
  tr_out:
  pla
  rts
VIA3_IRQ_Handler:     ;USB Mouse
  jsr Mouse_Interrupt_Handler
  bra irq_done
VIA4_IRQ_Handler:     ;Joystick
  jsr Joystick_Interrupt_Handler
  bra irq_done
irq_done:
  ;return items from stack
  rep #%00110000    ;16-bit registers
  ply ;stack to y
  plx ;stack to x
  pla ;stack to a
  pld
  plb
  rti
Delay:
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    pha       ;save current accumulator
    lda delayDuration	;counter start - increase number to shorten delay
    Delayloop:
        clc
        adc #01
        bne Delayloop
    pla
    rts
Delay0:
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    pha       ;save current accumulator
    lda #0
    Delayloop0:
        clc
        adc #01
        bne Delayloop0
    pla
    rts

;Convert keyboard scan codes to ASCII values
; *** Set 1 *** See http://www.vetra.com/scancodes.html
; Used for keyboard when running emulator
; This set is incomplete and needs full testing.
// keymap:
//   .byte "?",$1B,"1234567890-=??qwertyuiop[]",$0A,"?asdfghjkl;'`??zxcvbnm,./???",$20,"????"
//   .byte "????????????????????????????????????????????????????????????????"
//   .byte "????????????????????????????????????????????????????????????????"
//   .byte "????????????????????????????????????????????????????????????????"
// keymap_shifted:
//   .byte "?!@#$%^&*()_+??QWERTYUIOP{}??ASDFGHJKL:?~?ZXCVBNM<>?????????"
//   .byte "????????????????????????????????????????????????????????????????"
//   .byte "????????????????????????????????????????????????????????????????"
//   .byte "????????????????????????????????????????????????????????????????"


;PS/2 keyboard scan codes -- Set 2 or 3
keymap:
  .byte "????????????? `?"          ; 00-0F
  .byte "?????q1???zsaw2?"          ; 10-1F
  .byte "?cxde43?? vftr5?"          ; 20-2F
  .byte "?nbhgy6???mju78?"          ; 30-3F
  .byte "?,kio09??./l;p-?"          ; 40-4F
  .byte "??'?[=????",$0a,"]?",$5c,"??"    ; 50-5F     orig:"??'?[=????",$0a,"]?\??"   '\' causes issue with retro assembler - swapped out with hex value 5c
  .byte "?????????1?47???"          ; 60-6F0
  .byte "0.2568",$1b,"??+3-*9??"    ; 70-7F
  .byte "????????????????"          ; 80-8F
  .byte "????????????????"          ; 90-9F
  .byte "????????????????"          ; A0-AF
  .byte "????????????????"          ; B0-BF
  .byte "????????????????"          ; C0-CF
  .byte "????????????????"          ; D0-DF
  .byte "????????????????"          ; E0-EF
  .byte "????????????????"          ; F0-FF
keymap_shifted:
  .byte "????????????? ~?"          ; 00-0F
  .byte "?????Q!???ZSAW@?"          ; 10-1F
  .byte "?CXDE#$?? VFTR%?"          ; 20-2F
  .byte "?NBHGY^???MJU&*?"          ; 30-3F
  .byte "?<KIO)(??>?L:P_?"          ; 40-4F
  .byte "??",$22,"?{+?????}?|??"          ; 50-5F      orig:"??"?{+?????}?|??"  ;nested quote - compiler doesn't like - swapped out with hex value 22
  .byte "?????????1?47???"          ; 60-6F
  .byte "0.2568???+3-*9??"          ; 70-7F
  .byte "????????????????"          ; 80-8F
  .byte "????????????????"          ; 90-9F
  .byte "????????????????"          ; A0-AF
  .byte "????????????????"          ; B0-BF
  .byte "????????????????"          ; C0-CF
  .byte "????????????????"          ; D0-DF
  .byte "????????????????"          ; E0-EF
  .byte "????????????????"          ; F0-FF


.org $FFEE
    .word irq_label   //native 16-bit mode interrupt vector

.org $FFFC
    .word reset
    .word irq_label   //emulation interrupt vector
    