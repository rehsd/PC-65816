;Comments
  ;SPI SD Card routines
  ;Code based on SPI Card by rehsd.
  ;Using HiLetgo Micro SD TF Card Reader - https://www.amazon.com/gp/product/B07BJ2P6X6
  ;
  ;SPI LED example from https://github.com/rehsd/VGA-6502/blob/main/6502%20Assembly/PCB_ROM_20211008.s
  ;Adapted work from https://hackaday.io/project/174867-reading-sd-cards-on-a-65026522-computer
  ;
  ;    sta DDR3B/PORT3B     ;CONTROL -all pins output
  ;                           OE      = %00000001      ;589 OEB   When set (high), disables output of the shift register to the MOSI line. Generally, this should not be set when writing to PORT3B, as MOSI output can always be enabled.
  ;                           SCK     = %00000010
  ;                           RCK_OUT = %00000100      ;589 RCK
  ;                           SLOAD   = %00001000      ;589 SLOAD   **This should always be included when writing to PORT3B - keep inputs on parallel versus serial into 589
  ;                           RCK_IN  = %00010000      ;595 RCK        (serial to parallel)
  ;
  ;    sta DDR3A           ;DATA -all pins output
  ;
  ;    sta DDR2A           ;CONTROL_EX -all pins output -VIA2, PORTA added for additional clock/control options
  ;                           SPI_SCK = %00000001      ;Used for separate SCK on devices without OE, such as SPI 8 char 7-segment LED display with MAX7219
  ;                           OEB595  = %00000010      ;74HC595 serial to parallel shift register OE (SPI to VIA) -- used to be on 74HC138
  ;                          
  ;
  ;Two VIAs. DDR3A is shared data bus for VIA, out to 74HC589, and in from 74HC595.
  ;       OEB595 and OE (used for 589 OEB) -- only one can be active at a time. If both VIA are 595 are active to write on the bus at the same time, issues will arise.
  ;       Keep unused 595 or 589 high unless wanting to activate it. These signals on the ICs are active low.
  ;
  ;All timing / delays based on 5 MHz 6502. May need to be adjusted if using another clock speed.
  ;
  ;https://developpaper.com/sd-card-command-details/
  ;https://www.kingston.com/datasheets/SDCIT-specsheet-64gb_en.pdf
  ;
  ;TO DO SPI routines here and in the main .asm file could be consolidated

SPI_SDCard_Testing:
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ;SPI connection to SPI Card initialization
      lda #%11111111      ;output
      sta DDR3B           ;CONTROL -all pins output
      sta DDR3A           ;DATA -all pins output
      sta DDR2A           ;CONTROL_EX -all pins output -VIA2, PORTA added for additional clock/control options

      lda #%00000001 ; Clear display
      jsr lcd_instruction

      lda #$30                  ;to look into... need to send a couple of chars to get thing the _fpga output primed
      jsr print_char_FPGA
      ;jsr Delay00
      lda #$30
      jsr print_char_FPGA

      ;*** fpga vga *** - clear display
      lda #$1b      ;escape ASCII code to pass to fpga vga
      sta PORT5B
      lda #%10000001    ;printchar
      sta PORT5A
      jsr Delay80
      lda #%00000001    ;printchar
      sta PORT5A
      jsr Delay80

      jsr SPI_SDCard_Init

      lda #(SLOAD)
      sta PORT3B

      try0:
        ;jsr newline_fpga
        ;jsr DelayC0 ;important
        jsr CS_Enable

        jsr SPI_SDCard_SendCommand0
          jsr CS_Disable
          ;jsr PrintResult
          ;jsr newline_fpga
          cmp #$01
          bne try0
        ;jsr Delay40

      ;jsr newline_fpga
      try8:
        jsr CS_Enable
        jsr SPI_SDCard_SendCommand8
          ;jsr PrintResult
          ;jsr newline_fpga
          ; Read 32-bit return value, but ignore it
          jsr SPI_SDCard_ReceiveByte
          jsr SPI_SDCard_ReceiveByte
          jsr SPI_SDCard_ReceiveByte
          jsr SPI_SDCard_ReceiveByte
        jsr CS_Disable
        ;jsr newline_fpga

      try55:
        jsr CS_Enable
        jsr Delay80
        ;jsr newline_fpga
        jsr Delay80

        jsr SPI_SDCard_SendCommand55
        ;jsr PrintResult
        jsr CS_Disable

      lda #(SLOAD)  ;No SPI_DEV5_SDCARD
      sta PORT3B

      ;jsr newline_fpga
      try41:
      jsr CS_Enable

      jsr SPI_SDCard_SendCommand41
        jsr CS_Disable
        ;jsr Delay00
        ;jsr newline_fpga
        ;jsr PrintResult
        ;should have a result of $0 if successful
        cmp #$00
        beq SDCardInitComplete
        cmp #$01    ;if not initialized and if received a 01, give it some time and try again - any other result is an error
        ;cmp #$05    ;testing
        bne SDCardFail
        jsr Delay00
        bra try55
      ;jsr Delay40

      SDCardInitComplete:
        ;jsr newline_fpga
        jsr PrintString_FPGA_InitComplete
      
    ;jsr SPI_SDCard_ReadBytes
    jsr PlaySongFromSDCard

    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts

SDCardFail:
    jsr PrintString_FPGA_Failure

    ;try CMD1
    ;jsr SPI_SDCard_SendCommand1
    ;  jsr PrintResult
    ;jsr Delay40
   

    ;for testing, try to read bytes to see what happens
    ;jsr SPI_SDCard_ReadBytes
  rts
CS_Enable:
    pha
    jsr SendGarbageByte
    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    jsr SendGarbageByte
    pla
    rts
CS_Disable:
    pha
    jsr SendGarbageByte
    lda #(SLOAD)  ;No SPI_DEV5_SDCARD
    sta PORT3B
    jsr SendGarbageByte
    pla
    rts
SendGarbageByte:
    pha
    
    lda #%11111111      ;output
    sta DDR3A           ;DATA -all pins output

    jsr Set_MOSI_High

    lda #(SLOAD | SPI_DEV5_SDCARD)   ;shift clock and receive/latch clock
    sta PORT3B
    ;jsr DelayF0

    ;start low
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    ;cycle the clock, doesn't matter what data is being sent
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 
    
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0 
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayF0 

    pla
  rts
ToggleCS:
    pha

    ;toggle CS
    lda #(SLOAD)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0 

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    lda #(OEB595)    
    sta PORT2A
    ;jsr DelayC0

    pla
  rts

;Separate command routines that are essentially the same
;Can consolidate later... left this way for initial prototyping and debugging
SPI_SDCard_SendCommand0:
    ;.cmd0 ; GO_IDLE_STATE - resets card to idle state, and SPI mode
    ;jsr ToggleCS
    
    
    lda #<cmd0_bytes
    sta zp_sd_cmd_address
    lda #>cmd0_bytes
    sta zp_sd_cmd_address+1

    ;lda #$30  ;0
    ;jsr print_char_FPGA
    ;lda #$3A  ; ':'
    ;jsr print_char_FPGA

    ldy #0
    SPI_SDCard_SendCommand0_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand0_loop

    jsr SPI_SDCard_waitresult
    ; Expect status response $01 (not initialized)
    cmp #$01
    ;bne Initfailed

  rts
SPI_SDCard_SendCommand8:
    ;.cmd8 ; SEND_IF_COND - tell the card how we want it to operate (3.3V, etc)
    lda #<cmd8_bytes
    sta zp_sd_cmd_address
    lda #>cmd8_bytes
    sta zp_sd_cmd_address+1
    ;lda #$38  ;8
    ;jsr print_char_FPGA
    ;lda #$3A  ; ':'
    ;jsr print_char_FPGA
    ldy #0
    SPI_SDCard_SendCommand8_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        ;jsr print_hex_FPGA
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand8_loop

    ;jsr SPI_SDCard_SendExtraClocks
    ;jsr newline_fpga
    jsr SPI_SDCard_waitresult
    ; Expect status response $01 (not initialized)
    cmp #$01
    ;bne Initfailed

  rts
SPI_SDCard_SendCommand12:
    ;.cmd18 ; READ_MULTIPLE_BLOCK
    lda #<cmd12_bytes
    sta zp_sd_cmd_address
    lda #>cmd12_bytes
    sta zp_sd_cmd_address+1

    lda #$31  ;1
    jsr print_char_FPGA
    lda #$32  ;2
    jsr print_char_FPGA
    lda #$3A  ; ':'
    jsr print_char_FPGA
    ldy #0
    SPI_SDCard_SendCommand12_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand12_loop
    jsr SPI_SDCard_waitresult
    cmp #$01
    ;bne Initfailed
  rts  
SPI_SDCard_SendCommand18:
    ;.cmd18 ; READ_MULTIPLE_BLOCK
    lda #<cmd18_bytes
    sta zp_sd_cmd_address
    lda #>cmd18_bytes
    sta zp_sd_cmd_address+1

    lda #$31  ;1
    jsr print_char_FPGA
    lda #$38  ;8
    jsr print_char_FPGA
    lda #$3A  ; ':'
    jsr print_char_FPGA
    ldy #0
    SPI_SDCard_SendCommand18_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand18_loop
    jsr SPI_SDCard_waitresult
    ;cmp #$01
    ;bne Initfailed
    rts
SPI_SDCard_SendCommand55:
    ;.cmd55 ; APP_CMD - required prefix for ACMD commands
    lda #<cmd55_bytes
    sta zp_sd_cmd_address
    lda #>cmd55_bytes
    sta zp_sd_cmd_address+1

    ;lda #$35  ;5
    ;jsr print_char_FPGA
    ;jsr print_char_FPGA
    ;lda #$3A  ; ':'
    ;jsr print_char_FPGA
    ldy #0
    SPI_SDCard_SendCommand55_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        ;jsr print_hex_FPGA
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand55_loop

    ;jsr SPI_SDCard_SendExtraClocks
    ;jsr newline_fpga
    jsr SPI_SDCard_waitresult
    ; Expect status response $01 (not initialized)
    cmp #$01
    ;bne Initfailed

  rts
SPI_SDCard_SendCommand41:
    ;jsr ToggleCS
    
    ;.cmd41 ; APP_SEND_OP_COND - send operating conditions, initialize car
    lda #<cmd41_bytes
    sta zp_sd_cmd_address
    lda #>cmd41_bytes
    sta zp_sd_cmd_address+1
    ;lda #$34  ;4
    ;jsr print_char_FPGA
    ;lda #$31  ;1
    ;jsr print_char_FPGA
    ;lda #$3A  ; ':'
    ;jsr print_char_FPGA
    ldy #0
    SPI_SDCard_SendCommand41_loop:
        lda (zp_sd_cmd_address),y
        sta SPI_SDCard_Next_Command
        ;jsr print_hex_FPGA
        jsr SPI_SDCard_SendCommand
        iny
        tya
        cmp #$06    ;iterate loop a total of six times
        bne SPI_SDCard_SendCommand41_loop

    jsr SPI_SDCard_waitresult
    ; Expect status response $00 (initialized)
    cmp #$00
    ;beq Initialized

  rts
SPI_SDCard_waitresult:
  ; Wait for the SD card to return something other than $ff
  jsr SPI_SDCard_ReceiveByte
  ;jsr print_hex_FPGA
  ;pha
  ;lda #$20  ;ascii ' '
  ;jsr print_char_FPGA
  ;pla
  cmp #$ff
  beq SPI_SDCard_waitresult
  rts
SPI_SDCard_Init:

    jsr SPI_SDCard_StartSession
    jsr DelayC0

    //MOSI high
    jsr Set_MOSI_High    
    ldx #80     ;need 80 clock cycles for SD Card start up
    ;ldx #$FF      ;testing
    SPI_SDCard_Init_LoopTop:
        ;cycle 80 times

        ;CS/OEB
        ;lda #(SCK | SPI_DEV5_SDCARD)
        ;or no CS/OEB
        lda #(SLOAD)
        sta PORT3B

        lda #(OEB595)
        sta PORT2A
        ;jsr DelayA0                     ;need to test different delays

        lda #(SPI_SCK | OEB595)     ;Keep 595 turned off until we are reading back in from SPI
        sta PORT2A
        ;jsr DelayA0                     ;need to test different delays

        ;lda #(SCK | SLOAD)
        ;sta PORT3B

        lda #(OEB595)
        sta PORT2A
        ;jsr DelayA0                     ;need to test different delays

        dex
        bne SPI_SDCard_Init_LoopTop

        lda #(OEB595)
        sta PORT2A
        ;jsr DelayA0 
    rts
Set_MOSI_High:
    pha
    phx

    ;jsr DelayC0

    lda #%11111111      ;output
    sta DDR3A 

    ;lda #(SLOAD | SCK | RCK_OUT | SPI_DEV5_SDCARD)   ;shift clock and receive/latch clock
    ;sta PORT3B
    ;jsr DelayC0

    ;lda #(SLOAD | SPI_DEV5_SDCARD)
    ;sta PORT3B
    ;jsr DelayC0

    ;lda #(SLOAD | SCK | SPI_DEV5_SDCARD)
    ;sta PORT3B
    ;jsr DelayC0

    lda #(OE | SCK | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    lda #$FF    ;data to send
    sta PORT3A
    ;jsr DelayC0

    lda #(OE | SPI_DEV5_SDCARD | RCK_OUT)
    sta PORT3B
    ;jsr DelayC0

    lda #(OE | SCK | RCK_OUT | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    lda #(OE | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    ;lda #(SLOAD | OE | SCK)
    ;sta PORT3B
    ;jsr DelayC0

    lda #(SLOAD | OE | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    ;Data is in the shift register, now shift it out
    ;;;;;
    ;SPI card design issue -- reset shift register?

    ;ldx #1
    ;shiftLoop:
    ;  lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit shifted out
    ;  sta PORT3B
    ;  jsr DelayF0
    ;  lda #(SLOAD | SPI_DEV5_SDCARD)
    ;  sta PORT3B
    ;  jsr DelayF0
    ;  dex
    ;  bne shiftLoop

    plx
    pla
    rts
SPI_SDCard_StartSession:
    lda #$D0    ;FE works
    sta delayDurationHighByte

    lda #%11111111      ;output
    sta DDR3B           ;CONTROL -all pins output
    sta DDR3A           ;DATA -all pins output
    sta DDR2A           ;CONTROL_EX -all pins output -VIA2, PORTA added for additional clock/control options
    
   
    lda #(SLOAD | OE | SCK | RCK_OUT | SPI_DEV0) ;#%00000111      ;dev0 to toggle others off
    sta PORT3B
    ;jmp DelayC0
    lda #(SLOAD)
    sta PORT3B

    rts
SPI_SDCard_EndSession:
    lda #(SLOAD)
    sta PORT3B

    lda #(SLOAD | SCK)
    sta PORT3B

    rts
SPI_SDCard_SendCommand:
    lda #%11111111      ;output
    sta DDR3A           ;DATA -all pins output
    
    ;jsr DelayF0

    lda #(SLOAD | SCK | RCK_OUT| SPI_DEV5_SDCARD)   ;shift clock and receive/latch clock
    sta PORT3B
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(SLOAD | SCK| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SCK | SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda SPI_SDCard_Next_Command    ;data to send (i.e., instruction #)
    sta PORT3A

    ;jsr print_hex_FPGA                   ;****** DATA IS HERE OK *********
    ;jsr DelayF0

    lda #(OE | SLOAD| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SLOAD| SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SLOAD| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SLOAD | SCK | RCK_OUT| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SLOAD| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(OE | SLOAD| SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayF0

    lda #(SLOAD| SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    
    lda #(SLOAD | SCK | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    lda #(SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0

    ;lda #(SLOAD | SCK | SPI_DEV5_SDCARD)
    ;sta PORT3B
    ;jsr DelayF0

    ;lda #(SLOAD | SPI_DEV5_SDCARD)
    ;sta PORT3B
    ;jsr DelayF0

    ;Data is in the shift register, now shift it out
    ;;;;;


    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit1 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit2 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit3 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit4 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit5 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit6 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit7 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)        ;bit8 shifted out
    sta PORT3B
    ;jsr DelayF0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayF0
    lda #OEB595
    sta PORT2A
    ;jsr DelayF0

    ;jsr DelayF0
    ;jsr newline_fpga
    ;jsr DelayF0
    
    rts
SPI_SDCard_ReceiveByte:

    jsr Set_MOSI_High

    ;data is latched for out, can now switch to input
    ;read it back in from the receiving SPI to parallel
    ;set VIA PORTA to input

    lda #%00000000    ;all pins input - data
    sta DDR3A
    ;jsr DelayC0


    lda #(SCK | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    lda #(SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #OEB595
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | SCK)
    sta PORT3B
    ;jsr DelayC0
    lda #(SPI_SCK | OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD | RCK_IN)
    sta PORT3B
    ;jsr DelayC0
    lda #(OEB595)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SCK | SPI_DEV5_SDCARD)  ;enable inbound shift register''s data output       ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B
    ;jsr DelayC0

    lda #0              ;no OEB595: to enable it (low is enabled)
    sta PORT2A
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD)     ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B
    ;jsr DelayC0


    lda #(SLOAD | SCK | SPI_DEV5_SDCARD)    ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B
    ;jsr DelayC0

    lda #(SLOAD | SPI_DEV5_SDCARD)
    sta PORT3B
    ;jsr DelayC0

    ;load result into A register. calling procedure can use it.
    lda PORT3A
    pha
    ;jsr DelayC0

    lda #(OEB595)      ;turn off 595 output
    sta PORT2A

    pla
    rts
SPI_SDCard_ReadByteWait:
  ; Wait for the SD card to return something other than $ff
  jsr SPI_SDCard_ReceiveByte
  cmp #$ff
  beq SPI_SDCard_ReadByteWait
  rts
SPI_SDCard_ReadBytes:
  jsr newline_fpga
  ;jsr Delay80
  jsr newline_fpga
  ;jsr Delay80
  jsr PrintString_FPGA_ReadingBytes
  ;jsr Delay80
  jsr newline_fpga

  ; Command 17, arg is sector number, crc not checked
  lda #$51           ; CMD17 - READ_SINGLE_BLOCK
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  lda #$00           ; sector 24:31
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  lda #$00           ; sector 16:23
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  lda #$00           ; sector 8:15
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  lda #$00           ; sector 0:7
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  lda #$01           ; crc (not checked)
  sta SPI_SDCard_Next_Command
  jsr SPI_SDCard_SendCommand

  lda #$2E  ;.
  jsr print_char_FPGA

  jsr SPI_SDCard_ReadByteWait
  cmp #$00
  ;jsr print_hex_FPGA
  beq ReadSuccess

  lda #$21  ;'!'
  jsr print_char_FPGA

  rts
ReadSuccess:
  ; wait for data
  jsr SPI_SDCard_ReadByteWait
  ;jsr newline_fpga
  ;jsr Delay80
  ;jsr print_hex_FPGA
  cmp #$fe  ;always look for #$FE to see if we have data
  beq ReadHaveData

  rts
ReadHaveData:
  ; Need to read 512 bytes.
  lda #32     ;loop starting counter
  sta $70 ; variable to store loop counter
  readLoop:
    jsr SPI_SDCard_ReceiveByte
    cmp #$1C  ;file separator
    beq readLoopComplete    ;if we hit a file separator, we're done reading the file

    jsr print_char_FPGA     ;otherwise, print the char and repeat the loop
    dec $70 ; counter
    bne readLoop

    readLoopComplete:
  rts
PrintResult:
  ;jsr DelayF0
  jsr newline_fpga
  ;jsr DelayF0
  jsr newline_fpga
  ;jsr DelayF0
  jsr PrintString_FPGA_Result
  ;jsr DelayF0
  jsr print_hex_FPGA
  jsr newline_fpga
  jsr newline_fpga
  ;jsr DelayF0
  rts
PrintString_FPGA_SendCmd
    phx
    pha
    ldx #0
    psFPGA_SendCmd_top:
        lda messageSendCmd,x
        beq psFPGA_SendCmd_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_SendCmd_top
    psFPGA_SendCmd_out:
        pla
        plx
        rts
PrintString_FPGA_Received
    phx
    pha
    ldx #0
    psFPGA_Received_top:
        lda messageReceived,x
        beq psFPGA_Received_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_Received_top
    psFPGA_Received_out:
        pla
        plx
        rts
PrintString_FPGA_Result
    phx
    pha
    ldx #0
    psFPGA_Result_top:
        lda messageResult,x
        beq psFPGA_Result_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_Result_top
    psFPGA_Result_out:
        pla
        plx
        rts
PrintString_FPGA_InitComplete
    phx
    pha
    ldx #0
    psFPGA_InitComplete_top:
        lda messageInitComplete,x
        beq psFPGA_InitComplete_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_InitComplete_top
    psFPGA_InitComplete_out:
        pla 
        plx
        rts 
PrintString_FPGA_Failure
    phx
    pha
    ldx #0
    psFPGA_Failure_top:
        lda messageFailure,x
        beq psFPGA_Failure_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_Failure_top
    psFPGA_Failure_out:
        pla
        plx
        rts        
PrintString_FPGA_ReadingBytes
    phx
    pha
    ldx #0
    psFPGA_ReadingBytes_top:
        lda messageReadingBytes,x
        beq psFPGA_ReadingBytes_out
        jsr print_char_FPGA
        ;jsr DelayF0
        inx
        jmp psFPGA_ReadingBytes_top
    psFPGA_ReadingBytes_out:
        pla
        plx
        rts        
        
;Predefined messages
messageSendCmd:       .asciiz   "Sending Cmd: "
messageReceived:      .asciiz   "Response:"
messageResult:        .asciiz   "Result: "
messageFailure:       .asciiz   "Failure!"
messageInitComplete:  .asciiz   "Init"
messageReadingBytes:  .asciiz   "Reading"

;Command sequences
cmd0_bytes    ;0x40 + command number    ;GO_IDLE_STATE
  .byte $40, $00, $00, $00, $00, $95
cmd1_bytes                              ;SEND_OP_COND
  .byte $41, $00, $00, $00, $00, $F9
cmd8_bytes                              ;SEND_IF_COND
  .byte $48, $00, $00, $01, $aa, $87
cmd12_bytes                             ;STOP_TRANSMISSION
  .byte $4C, $00, $00, $00, $00, $61    
cmd18_bytes                             ;READ_MULTIPLE_BLOCK, starting at 0x0
  .byte $52, $00, $00, $00, $00, $E1
cmd41_bytes                             ;SD_SEND_OP_COND
  .byte $69, $40, $00, $00, $00, $77
cmd55_bytes                             ;APP_CMD
  .byte $77, $00, $00, $00, $00, $65

