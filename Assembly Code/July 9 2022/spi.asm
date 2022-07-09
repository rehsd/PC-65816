.setting "HandleLongBranch", true
.setting "RegA16", false
.setting "RegXY16", false

;this code is all 8-bit
;incoming top-level calls should switch to 8-bit registers and return to 16-bit at the end of routine

;Comments
    ;SPI LED example from https://github.com/rehsd/VGA-6502/blob/main/6502%20Assembly/PCB_ROM_20211008.s
    ;In var.asm:
    ;VIA1 PORTB - SPI SD Card data and commands (PORTA unused)
    ;SPI_MISO        = %00010000     
    ;SPI_MOSI        = %00100000     
    ;SPI_SCK         = %01000000     
    ;SPI_CS          = %10000000 

SPI_Test:
    //to do -- need to read lower four bits and keep as-is. These bits are used for non-SPI items (e.g., sound card irq).
    //to do -- update sound card irq code to keep other seven bits the same
    pha
    phx
    phy

    sep #$30        //to 8

    // lda #'A'
    // jsr print_char_lcd
    // sep #$30        //to 8
    
    jsr SPI_Init

    rep #$30        //to 16

    lda #'Z'
    jsr print_char_vga

    stp

    ply
    plx
    pla
    rts
SPI_Init:
    pha
    phx
    phy
    sep #$30        //to 8

    lda VIA1_PORTB
    eor #SPI_Mega_Reset     ;bring the reset line high (active low reset)
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #(SPI_Mega_CS | SPI_SCK | SPI_MOSI)      ;SPI_MISO is input
    sta VIA1_PORTB
    //jsr DelayC0test

    //lda #(SPI_CS | SPI_MOSI)
    ldx #160            ;80 full clock cycles to give card time to initiatlize

    init_loop:
        eor #SPI_SCK
        sta VIA1_PORTB
        //jsr DelayC0test
        dex
        bne init_loop

    ;reset
        lda #<cmd0_bytes
        sta spi_cmd
        lda #>cmd0_bytes
        sta spi_cmd+1
        jsr SPI_SendCommand
        
        ; check return if applicable
        ;cmp #$00

    //jsr DelayC0

    rep #$30        //to 16

    ply
    plx
    pla

    rts
SPI_Send_Char:
    pha
    phx
    phy

    sep #$30        //to 8

    ldx #0

    sta char_to_print
    
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #SPI_MOSI           ; pull CS low to begin command
    sta VIA1_PORTB
    //jsr DelayC0test

    lda #$01            ;cmd 0
    jsr SPI_WriteByte
    lda #$00            ;data high byte
    jsr SPI_WriteByte
    lda char_to_print   ;data low byte
    jsr SPI_WriteByte

    jsr SPI_ReadByte

    pha
    ; End command
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #(SPI_Mega_CS | SPI_MOSI)   ; set CS high again
    sta VIA1_PORTB
    //jsr DelayC0test
    pla   ; restore result code
    ;sta ...        ; put result somewhere...

    rep #$30        //to 16

    ply
    plx
    pla
    rts
SPI_LCD_Print_Binary16:
    pha
    phx
    phy

    sep #$30        //to 8

    ldx #0

    sta char_to_print   //not the best name, but fine for now
    
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #SPI_MOSI           ; pull CS low to begin command
    sta VIA1_PORTB
    //jsr DelayC0test

    lda #$03            ;cmd 3 print binary 16
    jsr SPI_WriteByte
    lda #$00            ;data high byte
    jsr SPI_WriteByte
    lda char_to_print   ;data low byte
    jsr SPI_WriteByte

    jsr SPI_ReadByte

    pha
    ; End command
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #(SPI_Mega_CS | SPI_MOSI)   ; set CS high again
    sta VIA1_PORTB
    //jsr DelayC0test
    pla   ; restore result code
    ;sta ...        ; put result somewhere...

    rep #$30        //to 16

    ply
    plx
    pla
    rts

SPI_LCD_Update_Controller_Screen:
    pha
    phx
    phy

    sep #$30        //to 8

    ldx #0

    sta char_to_print   //not the best name, but fine for now
    
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #SPI_MOSI           ; pull CS low to begin command
    sta VIA1_PORTB
    //jsr DelayC0test

    lda #$04            ;cmd 4 update controller screen
    jsr SPI_WriteByte
    lda #$00            ;data high byte
    jsr SPI_WriteByte
    lda char_to_print   ;data low byte
    jsr SPI_WriteByte

    jsr SPI_ReadByte

    pha
    ; End command
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    eor #(SPI_Mega_CS | SPI_MOSI)   ; set CS high again
    sta VIA1_PORTB
    //jsr DelayC0test
    pla   ; restore result code
    ;sta ...        ; put result somewhere...

    rep #$30        //to 16

    ply
    plx
    pla
    rts

SPI_SendCommand:

  ldx #0
  //lda (spi_cmd,x)


    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
  eor #SPI_MOSI           ; pull CS low to begin command
  sta VIA1_PORTB
        //jsr DelayC0test

  ldy #0
  lda (spi_cmd),y    ; command byte
  jsr SPI_WriteByte
  ldy #1
  lda (spi_cmd),y    ; data 1
  jsr SPI_WriteByte
  ldy #2
  lda (spi_cmd),y    ; data 2
  jsr SPI_WriteByte
  ldy #3

  jsr SPI_ReadByte

  pha

  ; End command
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
  eor #(SPI_Mega_CS | SPI_MOSI)   ; set CS high again
  sta VIA1_PORTB
        //jsr DelayC0test

  pla   ; restore result code
  rts
SPI_WriteByte:
  ; Tick the clock 8 times with descending bits on MOSI
  ; SD communication is mostly half-duplex so we ignore anything it sends back here
    ldx #8                      ; send 8 bits
    writebyte_loop:
    asl                         ; shift next bit into carry
    tay                         ; save remaining bits for later

    //lda #0
    lda VIA1_PORTB
    and #%00001111      ;keep the lower, non-SPI-related bits
    
    bcc sendbit                ; if carry clear, don't set MOSI for this bit
    ora #SPI_MOSI

    sendbit:
        sta VIA1_PORTB                   ; set MOSI (or not) first with SCK low
        jsr DelayC0test
        eor #SPI_SCK
        sta VIA1_PORTB                   ; raise SCK keeping MOSI the same, to send the bit
        jsr DelayC0test
        tya                         ; restore remaining bits to send
        dex
        bne writebyte_loop                   ; loop if there are more bits to send
    rts
SPI_ReadByte:
  ; Enable the card and tick the clock 8 times with MOSI high, 
  ; capturing bits from MISO and returning them

    ldx #8                      ; we'll read 8 bits
    readByteLoop:
        lda VIA1_PORTB
        and #%00001111      ;keep the lower, non-SPI-related bits
        eor #SPI_MOSI                ; enable card (CS low), set MOSI (resting state), SCK low
        sta VIA1_PORTB
        //jsr DelayC0test
        //lda #(SPI_MOSI | SPI_SCK)       ; toggle the clock high

        eor SPI_SCK
        sta VIA1_PORTB
        //jsr DelayC0test

        //TO DO clean up this code so that sound card IRQ is not messed up
        lda VIA1_PORTB                   ; read next bit
        and #(%00001111 | SPI_MISO)
        //and #SPI_MISO

        clc                         ; default to clearing the bottom bit
        beq readByteBitNotSet              ; unless MISO was set
        sec                         ; in which case get ready to set the bottom bit
    readByteBitNotSet:
        tya                         ; transfer partial result from Y
        rol                         ; rotate carry bit into read result
        tay                         ; save partial result back to Y

        dex                         ; decrement counter
        bne readByteLoop                   ; loop if we need to read more bits
  rts
Init_Failure:
    //lda #'X'
    //jsr print_char_lcd
    stp     //just give up and quit :)

;Print standard strings
SPI_LCD_Print_Ready:
    pha
    phx
    phy

    .setting "RegA16", true

    // sep #$30        //to 8
    
    //lda #$1B    ;ESC
    lda #$0A    ;line feed
    jsr SPI_Send_Char
    lda #'R'
    jsr SPI_Send_Char
    lda #'E'
    jsr SPI_Send_Char
    lda #'A'
    jsr SPI_Send_Char
    lda #'D'
    jsr SPI_Send_Char
    lda #'Y'
    jsr SPI_Send_Char
    lda #'>'
    jsr SPI_Send_Char
    // lda #$0A    ;line feed
    // jsr SPI_Send_Char
    
    // rep #$30        //to 16

    .setting "RegA16", false

    ply
    plx
    pla
    rts

DelayC0test:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    pha
    //TO DO Adjust timer value when using faster processor clock
    lda #$FD	  ;counter start - increase number to shorten delay //65816 at 22.5 MHz, this needs to be FD or lower
    sta SPI_Timer       ; store high byte

    DelayC0Looptest:
        adc #01
        bne DelayC0Looptest
        clc
        inc SPI_Timer
        bne DelayC0Looptest
        clc
    pla
    rts
DelayC0:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    pha
    //TO DO Adjust timer value when using faster processor clock
    lda #$FE	  ;counter start - increase number to shorten delay
    sta SPI_Timer       ; store high byte

    DelayC0Loop:
        adc #01
        bne DelayC0Loop
        clc
        inc SPI_Timer
        bne DelayC0Loop
        clc
    pla
    rts

;Command sequences
    ;command 1byte, data 2bytes
    cmd0_bytes                  ;RESET
    .byte $00, $00, $00
    cmd1_bytes                  ;PRINT_CHAR_A
    .byte $01, $00, $41
