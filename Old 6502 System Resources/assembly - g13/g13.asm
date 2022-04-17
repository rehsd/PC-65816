MyCode.65c02.asm
.setting "HandleLongBranch", true
.include "vars.asm"

;General Information
    ; Version 12 - Switched compiler to Retro Assembler (https://enginedesigns.net/retroassembler/). Updated code syntax to support this compiler.
    ;              Removed Eater VGA circuit from 6502 system, resulting in 3x speed increase.
    ;              Adjusting timing/delays (e.g., audio playback speed) accordingly.
    ;              Removing old VGA code.
    ; Project for 6502+LCD+PS2+VGA for Ben Eater circuit design
    ; This assembly code developed by rehsd with foundational elements from Ben Eater (others if noted in code)
    ; Last updated September 2021
    ; Assembly code compiled with vasm and uploaded to ROM on 6502 build
    ; Example build command line:
    ;	vasm6502_oldstyle.exe -Fbin -dotdir -wdc02 g11.s -o g11.bin

    ; *** Hardware config ***
    ; W65C02 (Ben), 5.0 MHz
    ; VGA circuit (Ben), 10.0 MHz
    ; PS2 keyboard circuit (Ben)
    ; VIA1 PortA - PS2 keyboard input
    ; VIA1 PortB - 20x04 LCD in 4-bit (nibble) mode
    ; VIA2 PortA - SPI extra control / clock
    ; VIA2 PortB - Mouse input
    ; VIA3 PortA - SPI data
    ; VIA3 PortB - SPI control / clock (using external shift registers)
    ; VIA4 PortA - AY38910 audio data
    ; VIA4 PortB - AY38910 audio control
    ; VIA5 PortA - FPGA VGA Command
    ; VIA5 PortB - FPGA VGA Data

    ; W65C51N ACIA at $4100 (data direct from 6502 data bus)
    ; *** SPI devices ***
        ; BME280 Temp/Humidity/Pressure
        ; 8-char 7-segment LED Display

    ; VGA info
    ; Use X to track the video page
    ; Use Y to track the column in the page
    ; Use A to track pixel color
    ; 'VGA' Resolution: 100 columns x 64 rows (was 75 rows with just VGA circuit, with no 6502 integration)

    ; All calls to the Delay routine are tested with a 6502 clock of ~5.0 MHz. Other clock speeds may require adjusting the duration of the delays.

    ;6502 microprocessor reference: https://www.westerndesigncenter.com/wdc/documentation/w65c02s.pdf
    ;6502 dev reference: http://www.obelisk.me.uk/6502/reference.html
    ;6522 VIA reference: https://www.westerndesigncenter.com/wdc/documentation/w65c22.pdf
    ;2-line LCD display reference:   ;see page 42 of https://eater.net/datasheets/HD44780.pdf
    
    ;VGA color info
        ;	00000000 	0 	#$00    black
        ;	00000001 	1 	#$01    red
        ;	00000010 	2 	#$02    dark red
        ;	00000011 	3	#$03    bright red
        ;	00000100 	4 	#$04    green
        ;	00001000 	8 	#$08    dark green
        ;	00001100 	12 	#$0c    bright green
        ;	00010000 	16 	#$10    blue
        ;	00100000 	32 	#$20    dark blue
        ;	00110000 	48 	#$30    bright blue 
        ;	00111111 	63 	#$3F    white
        ;   Combine bits for other colors

    ; Font: 5x7 fixed   https://fontstruct.com/fontstructions/show/847768/5x7_dot_matrix
    ; Font pixel data is stored in ROM - see charmaps at end of file
    ; Could add additional fonts, up to 8x8 pixels given the initial structure of this code

    ; Video locations start at 20 00. Increment by 00 80 to move down a line.
    ; Example VGA rows:     1 - 20 00
    ;                       2 - 20 80
    ;                       3 - 21 00
    ;                       4 - 21 80
    ;                       5 - 22 00
    ; Possible ranges: 20 00 to 3F FF
    ; See https://github.com/rehsd/VGA-6502/blob/main/Notes

; TO DO
    ; -Improve code commenting :)
    ; -ClearChar subroutine
    ; -General code optimization - removal of unecessary calls, better ways of solving problems, ...
    ; -Clean up variable memory locations
    ; -Clean up capitalization of procedures to be consistent - same with variables, etc.
    ; -Clean up indentation
    ; -SPI routines here and in SPI_SD_CARD.asm could be consolidated
;.org $8000         ;comment here for outlining in Visual Studio editor
  .org $8000
reset:

    

    sei               ;disable interrupts
    cld               ;disable BCD
    ldx #$ff          ;initialize stack
    txs               ;initialize stack

    ;Reset variables
    lda #$00
    sta mouseFillRegionStarted

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


    ; ******* INTERRUPTS *******
    lda #$01	    ;positive edge (in code from Ben)
    sta PCR1		;Set CA1 to positive edge

    lda #$00     ;edge negative
    sta PCR2
    sta PCR3
    sta PCR4
    sta PCR5

    ;** Set(1)/Clear(0)   Timer1   Timer2   CB1   CB2   ShiftRegister   CA1   CA2 **
    lda #%10000010	;Enables interrupt CA1 (PS2 keyboard), disables everything else. 
    sta IER1

    lda #%10010000    ;Enable CB1 (mouse), disable others. 
    sta IER2

    lda #%10001000	;Enable CB2 (SPI), disable others. 
    sta IER3

    lda #%10011000    ;Enable CB1 (joystick on sound card) and CB2 (FPGA VGA to 6502 interrupt), disable others.
    sta IER4

    lda #%01111111    ;Disable all interrupts for this VIA - FPGA VGA output
    sta IER5


    ;set VIA ports input/output
    lda #%11111111 ; Set all pins on port B to output
    sta DDR1B
    lda #%00000000 ; Set all pins on port A to input
    sta DDR1A

    lda #$00      ; Set all pins to input
    sta DDR2B
    sta DDR2A
    sta DDR3B
    sta DDR3A


    lda #$FF      ; Set all pins to output 
    sta DDR4B     ;sound card
    sta DDR4A
    sta DDR5B     ;FPGA VGA
    sta DDR5A

    ; ******* KEYBOARD *******    init keyboard handling memory
    lda #$00
    sta kb_flags
    sta kb_flags2
    sta kb_wptr
    sta kb_rptr

    ;Set message_to_process to 0 when transitioning to dynamic strings/chars (vs. pre-defined, stored messages)
    lda #$00  ;done processing pre-defined strings
    sta message_to_process

    jsr PlayWindowsStartSound

    lda #$00
    sta audio_data_to_write

    jsr LoadDynamicSound

    lda #%00000001 ; Clear display
    jsr lcd_instruction

    lda #$A0  ;start counting up at this value; higher # = shorter delay
    sta delayDurationHighByte

    cli           ;enable interrupts

    lda #%00000001 ; Clear display
    jsr lcd_instruction

    jsr PrintStringLCD   ;Finished message

    ;to do setup standard delays for different purposes (e.g., audio, vs keypress)
    lda #$F0  ;start counting up at this value; higher # = shorter delay
    sta delayDurationHighByte

    lda #$00
    sta Sound_ROW_JumpTo        ;default starting position of 0 when reading from audio ROM

    ;jsr PlayFromROM  ;**to do: need to finish this routine so code continues to the next line

    ;jsr PlaySong
    jsr SPI_SDCard_Testing

    jmp loop_label
;timer interrupt vars
    ticks:      .byte 0
    max_ticks:  .byte 0
Sound:
    PlayFromROM:
        ;load the data from ROM in variables
        ;only using 8 bits for address, so only 256kbit available (not using the last 3 bits)
        ;R7 EnableB     --bit7=IOB (IN low Out high) - set low so we can read ROM data on PSG:B             01000000=40
        ;               --bit6=IOA (IN low Out high) - set high so we can write out ROM address on PSG:A
        ;R14(hex) PSG I/O Port A    --write address of ROM  to access
        ;R15(hex) PSG I/O Port B    --read data from ROM at supplied ROM address

        pha ;a to stack
        phx ;x to stack
        phy ;y to stack

        ;update to read 64 bytes and store in vars, then repeat until FF is read
        
            ;lda #$0E    ;Register = I/O port A - write ROM address to be read 
            ;jsr AY1_setreg
            ;lda #$00    ;start at beginning of ROM
            ;jsr AY1_writedata
            ;lda #$0F    ;Register = I/O port B - read address at previously specified ROM address
            ;jsr AY1_setreg
            ;jsr AY1_readdata    ;result in A register
            ;jsr print_hex_lcd  ;show it on LCD
        ;loop through memory and write to variables
        ;last byte of 64 of end marker (FF if no more data for this item)
        ;start at TonePeriodCourseLA and +1 each iteration

        lda #$07    ;Select Enable Register (active low)
        jsr AY1_setreg
        lda #%01111000    ;IONNNTTT - B in (low), A out (high), Noise, Tone
        jsr AY1_writedata

        lda #$07    ;Select Enable Register (active low)
        jsr AY2_setreg
        lda #%00111000    ;IONNNTTT - B in (low), A out (high), Noise, Tone
        jsr AY2_writedata

        lda #$07    ;Select Enable Register (active low)
        jsr AY3_setreg
        lda #%00111000    ;IONNNTTT - B in (low), A out (high), Noise, Tone
        jsr AY3_writedata

        lda #$07    ;Select Enable Register (active low)
        jsr AY4_setreg
        lda #%00111000    ;IONNNTTT - B in (low), A out (high), Noise, Tone
        jsr AY4_writedata

        ldx #$00
        
        lda Sound_ROW_JumpTo
        sta Sound_ROW   ;start at row 0
        PlayFromROMLoop:

            lda #$0E    ;Register = I/O port A - write ROM address to be read 
            jsr AY1_setreg
            txa ;use x as counter to iterate through ROM
            clc
            adc Sound_ROW   ;starts at 0 unless Sound_ROW_JumpTo set differently, will increment if more than one sound row. #$40 for each row (i.e., second row at #$40)
            jsr AY1_writedata

            lda #$0F    ;Register = I/O port B - read address at previously specified ROM address
            jsr AY1_setreg
            jsr AY1_readdata    ;result in A register
            sta TonePeriodCourseLA, x       ;offset for position of storing specific value, starting with first value in series

            txa
            inx
            txa     ;1-63
            
            cmp #$40    ;done with this sequence row
            bne PlayFromROMLoop
            
            ;if done with column loop, play the sound
            jsr UpdateSoundConfig
            jmp OutXX

            ;TO DO Delay based on sequence Data
            ;For now, just do a simple delay
            ;jsr Delay  ;add longer delay to match desired tick level  **************************
            ;jsr DelayTick

            ;check if EOF flag is FF, otherwise, loop to next 'row'
            clc
            lda Sound_ROW
            adc #$40            ;increment by 64 to get to the next row in the sequence ;if last row fails to have FF to terminate, will loop around;
                                ;Current implementation - only using 8 bits of address line on ROM, so can only use first 256 addresses - more learn functionality than anything
            sta Sound_ROW
            ldx #$00            ;start at first value in new row
            
            
            lda Sound_EOF ;63 from above
            cmp #$FF
            bne PlayFromROMLoop     ;if FF, we are done with last row.            
            
        OutXX:
            ;*************** sound off ***************
            lda #<SND_OFF_ALL
            sta TUNE_PTR_LO
            lda #>SND_OFF_ALL
            sta TUNE_PTR_HI
            ;jsr AY1_PlayTune
            ;jsr AY2_PlayTune
            jsr AY3_PlayTune
            jsr AY4_PlayTune

        ply ;stack to y
        plx ;stack to x
        pla ;stack to a
        rts
    PlayWindowsStartSound:
        lda #$00
        sta delayDurationHighByte

        ;init VIA
        lda #$FF    ;write

        sta DDR4A
        sta DDR4B

        ;init AY38910 #1
        ;lda #(AY2_A9_B) ;AY1_A9_B not set, therefore AY active. AY2_A9_B set, therefore AY2 disabled
        ;lda #0
        ;sta PORT4B

        ;*************** sound to AY1_2_3_4 (SND_RESET) ***************
            lda #<SND_RESET
            sta TUNE_PTR_LO
            lda #>SND_RESET
            sta TUNE_PTR_HI

            jsr AY1_PlayTune
            jsr AY2_PlayTune
            jsr AY3_PlayTune
            jsr AY4_PlayTune


        ;*************** sound to AY1_2 (SND_TONE_E6_FLAT_A) ***************
            lda #<SND_TONE_E6_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_E6_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_F1_C) ***************
            lda #<SND_TONE_F1_C
            sta TUNE_PTR_LO
            lda #>SND_TONE_F1_C
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 3 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay

        ;*************** sound to AY1_2 (SND_OFF_A) ***************
            lda #<SND_OFF_A
            sta TUNE_PTR_LO
            lda #>SND_OFF_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_E5_FLAT_A) ***************
            lda #<SND_TONE_E5_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_E5_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 2 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay


        ;*************** sound to AY1_2 (SND_TONE_B6_FLAT_A) ***************
            lda #<SND_TONE_B6_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_B6_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 3 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay


        ;*************** sound to AY1_2 (SND_OFF_ALL) ***************
            lda #<SND_OFF_ALL
            sta TUNE_PTR_LO
            lda #>SND_OFF_ALL
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_A6_FLAT_A) ***************
            lda #<SND_TONE_A6_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_A6_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_OFF_C) ***************
            lda #<SND_OFF_C
            sta TUNE_PTR_LO
            lda #>SND_OFF_C
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_A2_FLAT_C) ***************
            lda #<SND_TONE_A2_FLAT_C
            sta TUNE_PTR_LO
            lda #>SND_TONE_A2_FLAT_C
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 5 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay


        ;*************** sound to AY1_2 (SND_OFF_A) ***************
            lda #<SND_OFF_A
            sta TUNE_PTR_LO
            lda #>SND_OFF_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune    
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_E6_FLAT_A) ***************
            lda #<SND_TONE_E6_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_E6_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 3 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay

        ;*************** sound to AY1_2 (SND_OFF_ALL) ***************
            lda #<SND_OFF_ALL
            sta TUNE_PTR_LO
            lda #>SND_OFF_ALL
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_B6_FLAT_A) ***************
            lda #<SND_TONE_B6_FLAT_A
            sta TUNE_PTR_LO
            lda #>SND_TONE_B6_FLAT_A
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_E3_FLAT_B) ***************
            lda #<SND_TONE_E3_FLAT_B
            sta TUNE_PTR_LO
            lda #>SND_TONE_E3_FLAT_B
            sta TUNE_PTR_HI
            jsr AY2_PlayTune
            jsr AY1_PlayTune
        ;*************** sound to AY1_2 (SND_TONE_B3_FLAT_C) ***************
            lda #<SND_TONE_B3_FLAT_C
            sta TUNE_PTR_LO
            lda #>SND_TONE_B3_FLAT_C
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
        ;*************** delay 8 ticks ***************
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay
            jsr Delay

        ;*************** sound to AY1_2_3_4 (off) ***************
            lda #<SND_OFF_ALL
            sta TUNE_PTR_LO
            lda #>SND_OFF_ALL
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
            jsr AY3_PlayTune
            jsr AY4_PlayTune

        rts
    LoadDynamicSound:
        lda #$60
        sta delayDurationHighByte

        ;init VIA
        lda #$FF
        sta DDR4A
        sta DDR4B

        ;init AY38910 #1 --is this needed??
        ;lda #(AY2_A9_B) ;AY1_A9_B not set, therefore AY active. AY2_A9_B set, therefore AY2 disabled
        ;lda #0
        ;sta PORT4B

        ;*************** sound to AY1_2_3_4 (SND_RESET) ***************
            lda #<SND_RESET
            sta TUNE_PTR_LO
            lda #>SND_RESET
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
            jsr AY3_PlayTune
            jsr AY4_PlayTune

        ;*************** sound to AY1_2_3_4 (SND_OFF_ALL) ***************
        lda #<SND_OFF_ALL
        sta TUNE_PTR_LO
        lda #>SND_OFF_ALL
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
        jsr AY3_PlayTune
        jsr AY4_PlayTune

        rts 
    UpdateSoundConfig:

        pha ;a to stack
        phx ;x to stack
        phy ;y to stack

        ;***** LEFT AY1 *****

            lda #$00
            jsr AY1_setreg
            lda TonePeriodFineLA
            jsr AY1_writedata

            lda #$01
            jsr AY1_setreg
            lda TonePeriodCourseLA
            jsr AY1_writedata

            lda #$02
            jsr AY1_setreg
            lda TonePeriodFineLB
            jsr AY1_writedata

            lda #$03
            jsr AY1_setreg
            lda TonePeriodCourseLB
            jsr AY1_writedata

            lda #$04
            jsr AY1_setreg
            lda TonePeriodFineLC
            jsr AY1_writedata

            lda #$05
            jsr AY1_setreg
            lda TonePeriodCourseLC
            jsr AY1_writedata

            lda #$06
            jsr AY1_setreg
            lda NoisePeriodL1
            jsr AY1_writedata

            lda #$07
            jsr AY1_setreg
            lda EnableLeft1
            jsr AY1_writedata

            lda #$08
            jsr AY1_setreg
            lda VolumeLA
            jsr AY1_writedata

            lda #$09
            jsr AY1_setreg
            lda VolumeLB
            jsr AY1_writedata

            lda #$0A
            jsr AY1_setreg
            lda VolumeLC
            jsr AY1_writedata

            lda #$0B
            jsr AY1_setreg
            lda EnvelopePeriodFineL1
            jsr AY1_writedata
        
            lda #$0C
            jsr AY1_setreg
            lda EnvelopePeriodCourseL1
            jsr AY1_writedata

            lda #$0D
            jsr AY1_setreg
            lda EnvelopeShapeCycleL1
            jsr AY1_writedata

            ;#$0E - IO Port A
            ;#$0F - IO Port B
        ;***** RIGHT AY2 *****
            lda #$00
            jsr AY2_setreg
            lda TonePeriodFineRA
            jsr AY2_writedata

            lda #$01
            jsr AY2_setreg
            lda TonePeriodCourseRA
            jsr AY2_writedata

            lda #$02
            jsr AY2_setreg
            lda TonePeriodFineRB
            jsr AY2_writedata

            lda #$03
            jsr AY2_setreg
            lda TonePeriodCourseRB
            jsr AY2_writedata

            lda #$04
            jsr AY2_setreg
            lda TonePeriodFineRC
            jsr AY2_writedata

            lda #$05
            jsr AY2_setreg
            lda TonePeriodCourseRC
            jsr AY2_writedata

            lda #$06
            jsr AY2_setreg
            lda NoisePeriodR1
            jsr AY2_writedata

            lda #$07
            jsr AY2_setreg
            lda EnableRight1
            jsr AY2_writedata

            lda #$08
            jsr AY2_setreg
            lda VolumeRA
            jsr AY2_writedata

            lda #$09
            jsr AY2_setreg
            lda VolumeRB
            jsr AY2_writedata

            lda #$0A
            jsr AY2_setreg
            lda VolumeRC
            jsr AY2_writedata

            lda #$0B
            jsr AY2_setreg
            lda EnvelopePeriodFineR1
            jsr AY2_writedata
        
            lda #$0C
            jsr AY2_setreg
            lda EnvelopePeriodCourseR1
            jsr AY2_writedata

            lda #$0D
            jsr AY2_setreg
            lda EnvelopeShapeCycleR1
            jsr AY2_writedata

            ;#$0E - IO Port A
            ;#$0F - IO Port B
        ;***** LEFT AY3 *****

            lda #$00
            jsr AY3_setreg
            lda TonePeriodFineLD
            jsr AY3_writedata

            lda #$01
            jsr AY3_setreg
            lda TonePeriodCourseLD
            jsr AY3_writedata

            lda #$02
            jsr AY3_setreg
            lda TonePeriodFineLE
            jsr AY3_writedata

            lda #$03
            jsr AY3_setreg
            lda TonePeriodCourseLE
            jsr AY3_writedata

            lda #$04
            jsr AY3_setreg
            lda TonePeriodFineLF
            jsr AY3_writedata

            lda #$05
            jsr AY3_setreg
            lda TonePeriodCourseLF
            jsr AY3_writedata

            lda #$06
            jsr AY3_setreg
            lda NoisePeriodL2
            jsr AY3_writedata

            lda #$07
            jsr AY3_setreg
            lda EnableLeft2
            jsr AY3_writedata

            lda #$08
            jsr AY3_setreg
            lda VolumeLD
            jsr AY3_writedata

            lda #$09
            jsr AY3_setreg
            lda VolumeLE
            jsr AY3_writedata

            lda #$0A
            jsr AY3_setreg
            lda VolumeLF
            jsr AY3_writedata

            lda #$0B
            jsr AY3_setreg
            lda EnvelopePeriodFineL2
            jsr AY3_writedata
        
            lda #$0C
            jsr AY3_setreg
            lda EnvelopePeriodCourseL2
            jsr AY3_writedata

            lda #$0D
            jsr AY3_setreg
            lda EnvelopeShapeCycleL2
            jsr AY3_writedata

            ;#$0E - IO Port A
            ;#$0F - IO Port B
        ;***** RIGHT AY4 *****
            lda #$00
            jsr AY4_setreg
            lda TonePeriodFineRD
            jsr AY4_writedata

            lda #$01
            jsr AY4_setreg
            lda TonePeriodCourseRD
            jsr AY4_writedata

            lda #$02
            jsr AY4_setreg
            lda TonePeriodFineRE
            jsr AY4_writedata

            lda #$03
            jsr AY4_setreg
            lda TonePeriodCourseRE
            jsr AY4_writedata

            lda #$04
            jsr AY4_setreg
            lda TonePeriodFineRF
            jsr AY4_writedata

            lda #$05
            jsr AY4_setreg
            lda TonePeriodCourseRF
            jsr AY4_writedata

            lda #$06
            jsr AY4_setreg
            lda NoisePeriodR2
            jsr AY4_writedata

            lda #$07
            jsr AY4_setreg
            lda EnableRight2
            jsr AY4_writedata

            lda #$08
            jsr AY4_setreg
            lda VolumeRD
            jsr AY4_writedata

            lda #$09
            jsr AY4_setreg
            lda VolumeRE
            jsr AY4_writedata

            lda #$0A
            jsr AY4_setreg
            lda VolumeRF
            jsr AY4_writedata

            lda #$0B
            jsr AY4_setreg
            lda EnvelopePeriodFineR2
            jsr AY4_writedata
        
            lda #$0C
            jsr AY4_setreg
            lda EnvelopePeriodCourseR2
            jsr AY4_writedata

            lda #$0D
            jsr AY4_setreg
            lda EnvelopeShapeCycleR2
            jsr AY4_writedata

            ;#$0E - IO Port A
            ;#$0F - IO Port B

        lda #$00
        sta audio_data_to_write
           
        ply ;stack to y
        plx ;stack to x
        pla ;stack to a
    
        rts

    ;The following four AYx sections could be consolidated and more dynamic, using a parameter to specify which AY is active (rather than having four unique sets of routines).
    AY1:
        AY1_PlayTune:
           ldy #0
        AY1_play_loop:
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY1_play_next
           rts
        AY1_play_next:
           jsr AY1_setreg
           iny
           lda (TUNE_PTR_LO), Y         ;y+1, so this is TUNE_PTR_HIGH
           cmp #$FF
           bne AY1_play_next2
           rts
        AY1_play_next2:
           jsr AY1_writedata
           iny
           jmp AY1_play_loop
           rts
        AY1_setreg:
            jsr AY1_inactive     ; NACT
            sta PORT4A      
            jsr AY1_latch        ; INTAK
            jsr AY1_inactive     ; NACT
            rts
        AY1_writedata:
            jsr AY1_inactive     ; NACT
            sta PORT4A
            jsr AY1_write           ; DWS
            jsr AY1_inactive
            rts
        AY1_inactive:        ; NACT
            ; BDIR  LOW
            ; BC1   LOW
            phx         
            ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
            stx PORT4B
            plx         
            rts
        AY1_latch:           ; INTAK
            ; BDIR  HIGH
            ; BC1   HIGH
            phx         
            ldx #(AY1_BDIR | AY1_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY1_write:           ; DWS
            ; BDIR  HIGH
            ; BC1   LOW
            phx         
            ldx #(AY1_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY1_readdata:
            phx
            jsr AY1_inactive
            ldx #$00    ;Read
            stx DDR4A
            jsr AY1_read

            lda PORT4A          ;value retrieved from PSG
            ldx #$FF    ;Write
            stx DDR4A
            jsr AY1_inactive
            plx
            rts
        AY1_read:           ; DTB
            ; BDIR  LOW
            ; BC1   HIGH
            phx
            ldx #(AY1_BC1)
            stx PORT4B
            plx
            rts
    AY2:
        AY2_PlayTune:
           ldy #0
        AY2_play_loop:
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY2_play_next
           rts
        AY2_play_next:
           jsr AY2_setreg
           iny
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY2_play_next2
           rts
        AY2_play_next2:
           jsr AY2_writedata
           iny
           jmp AY2_play_loop
           rts
        AY2_setreg:
            jsr AY2_inactive     ; NACT
            sta PORT4A      
            jsr AY2_latch        ; INTAK
            jsr AY2_inactive     ; NACT
            rts
        AY2_writedata:
            jsr AY2_inactive     ; NACT
            sta PORT4A
            jsr AY2_write           ; DWS
            jsr AY2_inactive
            rts
        AY2_inactive:        ; NACT
            ; BDIR  LOW
            ; BC1   LOW
            phx         
            ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
            stx PORT4B
            plx         
            rts
        AY2_latch:           ; INTAK
            ; BDIR  HIGH
            ; BC1   HIGH
            phx         
            ldx #(AY2_BDIR | AY2_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY2_write:           ; DWS
            ; BDIR  HIGH
            ; BC1   LOW
            phx         
            ldx #(AY2_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY2_readdata:
            phx
            jsr AY2_inactive
            ldx #$00    ;Read
            stx DDR4A
            jsr AY2_read

            lda PORT4A
            ldx #$FF    ;Write
            stx DDR4A
            jsr AY2_inactive
            plx
            rts
        AY2_read:           ; DTB
            ; BDIR  LOW
            ; BC1   HIGH
            phx
            ldx #(AY2_BC1)
            stx PORT4B
            plx
            rts
    AY3:
        AY3_PlayTune:
           ldy #0
        AY3_play_loop:
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY3_play_next
           rts
        AY3_play_next:
           jsr AY3_setreg
           iny
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY3_play_next2
           rts
        AY3_play_next2:
           jsr AY3_writedata
           iny
           jmp AY3_play_loop
           rts
        AY3_setreg:
            jsr AY3_inactive     ; NACT
            sta PORT4A      
            jsr AY3_latch        ; INTAK
            jsr AY3_inactive     ; NACT
            rts
        AY3_writedata:
            jsr AY3_inactive     ; NACT
            sta PORT4A
            jsr AY3_write           ; DWS
            jsr AY3_inactive
            rts
        AY3_inactive:        ; NACT
            ; BDIR  LOW
            ; BC1   LOW
            phx         
            ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
            stx PORT4B
            plx         
            rts
        AY3_latch:           ; INTAK
            ; BDIR  HIGH
            ; BC1   HIGH
            phx         
            ldx #(AY3_BDIR | AY3_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY3_write:           ; DWS
            ; BDIR  HIGH
            ; BC1   LOW
            phx         
            ldx #(AY3_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY3_readdata:
            phx
            jsr AY3_inactive
            ldx #$00    ;Read
            stx DDR4A
            jsr AY3_read

            lda PORT4A
            ;jsr print_dec_lcd
            ldx #$FF    ;Write
            stx DDR4A
            jsr AY3_inactive
            plx
            rts
        AY3_read:           ; DTB
            ; BDIR  LOW
            ; BC1   HIGH
            phx
            ;ldx #(AY3_BC1 | AY2_A9_B)
            ldx #(AY3_BC1)
            stx PORT4B
            plx
            rts
    AY4:
        AY4_PlayTune:
           ldy #0
        AY4_play_loop:
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY4_play_next
           rts
        AY4_play_next:
           jsr AY4_setreg
           iny
           lda (TUNE_PTR_LO), Y
           cmp #$FF
           bne AY4_play_next2
           rts
        AY4_play_next2:
           jsr AY4_writedata
           iny
           jmp AY4_play_loop
           rts
        AY4_setreg:
            jsr AY4_inactive     ; NACT
            sta PORT4A      
            jsr AY4_latch        ; INTAK
            jsr AY4_inactive     ; NACT
            rts
        AY4_writedata:
            jsr AY4_inactive     ; NACT
            sta PORT4A
            jsr AY4_write           ; DWS
            jsr AY4_inactive
            rts
        AY4_inactive:        ; NACT
            ; BDIR  LOW
            ; BC1   LOW
            phx         
            ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
            stx PORT4B
            plx         
            rts
        AY4_latch:           ; INTAK
            ; BDIR  HIGH
            ; BC1   HIGH
            phx         
            ldx #(AY4_BDIR | AY4_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY4_write:           ; DWS
            ; BDIR  HIGH
            ; BC1   LOW
            phx         
            ldx #(AY4_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
            stx PORT4B
            plx         
            rts
        AY4_readdata:
            phx
            jsr AY4_inactive
            ldx #$00    ;Read
            stx DDR4A
            jsr AY4_read

            lda PORT4A
            ;jsr print_dec_lcd
            ldx #$FF    ;Write
            stx DDR4A
            jsr AY4_inactive
            plx
            rts
        AY4_read:           ; DTB
            ; BDIR  LOW
            ; BC1   HIGH
            phx
            ;ldx #(AY4_BC1 | AY1_A9_B)
            ldx #(AY4_BC1)
            stx PORT4B
            plx
            rts
    WonderfulSounds:    ;)
        SND_RESET:
           .BYTE $00, $00           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $00           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $00           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $06, $00           ;Noise Period
           .BYTE $07, $38           ;EnableB        ;all channels enabled, IO set to read for both ports
           .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $09, $0F           ;ChanB amplitude
           .BYTE $0A, $0F           ;ChanC amplitude
           .BYTE $0B, $00           ;Envelope period fine tune
           .BYTE $0C, $00           ;Envelope period coarse tune
           .BYTE $0D, $00           ;Envelope shape cycle
           ;.BYTE $0E, $00           ;IO Port A
           ;.BYTE $0F, $00           ;IO Port B
           .BYTE $FF, $FF           ; EOF
        SND_OFF_ALL:
           .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
           .BYTE $09, $00           ;ChanB amplitude
           .BYTE $0A, $00           ;ChanC amplitude
           .BYTE $FF, $FF                ; EOF
        SND_OFF_A:
           .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
           .BYTE $FF, $FF           ; EOF
        SND_OFF_B:
           .BYTE $09, $00           ;ChanB amplitude
           .BYTE $FF, $FF           ; EOF
        SND_OFF_C:
           .BYTE $0A, $00           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_100:
           .BYTE $00, $E2           ;ChanA tone period fine tune
           .BYTE $01, $04           ;ChanA tone period coarse tune
           .BYTE $02, $E2           ;ChanB tone period fine tune      
           .BYTE $03, $04           ;ChanB tone period coarse tune
           .BYTE $04, $E2           ;ChanC tone period fine tune  
           .BYTE $05, $04           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $0B, $0F           ;ChanB amplitude
           .BYTE $0C, $0F           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_500:
           .BYTE $00, $FA           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $FA           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $FA           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $09, $0F           ;ChanB amplitude
           .BYTE $0A, $00           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_1K:
           .BYTE $00, $7D           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $7D           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $7D           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $0B, $0F           ;ChanB amplitude
           .BYTE $0C, $0F           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_5K:
           .BYTE $00, $19           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $19           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $19           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $0B, $0F           ;ChanB amplitude
           .BYTE $0C, $0F           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_10K:
           .BYTE $00, $0C           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $0C           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $0C           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $0B, $0F           ;ChanB amplitude
           .BYTE $0C, $0F           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        SND_TONE_15K:
           .BYTE $00, $08           ;ChanA tone period fine tune
           .BYTE $01, $00           ;ChanA tone period coarse tune
           .BYTE $02, $08           ;ChanB tone period fine tune      
           .BYTE $03, $00           ;ChanB tone period coarse tune
           .BYTE $04, $08           ;ChanC tone period fine tune  
           .BYTE $05, $00           ;ChanC tone period coarse tune
           .BYTE $07, $38           ;EnableB
           .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
           .BYTE $0B, $0F           ;ChanB amplitude
           .BYTE $0C, $0F           ;ChanC amplitude
           .BYTE $FF, $FF           ; EOF
        ;Win95 Start
            SND_TONE_B6_FLAT_A:
               .BYTE $00, $43           ;ChanA tone period fine tune
               .BYTE $01, $00           ;ChanA tone period coarse tune
               .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
               .BYTE $FF, $FF                ; EOF
            SND_TONE_A6_FLAT_A:
               .BYTE $00, $4B           ;ChanA tone period fine tune
               .BYTE $01, $00           ;ChanA tone period coarse tune
               .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
               .BYTE $FF, $FF           ; EOF
            SND_TONE_E6_FLAT_A:
               .BYTE $00, $64           ;ChanA tone period fine tune
               .BYTE $01, $00           ;ChanA tone period coarse tune
               .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
               .BYTE $FF, $FF           ; EOF
            SND_TONE_E5_FLAT_A:
               .BYTE $00, $C8           ;ChanA tone period fine tune
               .BYTE $01, $00           ;ChanA tone period coarse tune
               .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
               .BYTE $FF, $FF           ; EOF
            SND_TONE_B3_FLAT_C:
               .BYTE $04, $18           ;ChanC tone period fine tune  
               .BYTE $05, $02           ;ChanC tone period coarse tune
               .BYTE $0A, $0F           ;ChanC amplitude
               .BYTE $FF, $FF           ; EOF
            SND_TONE_E3_FLAT_B:
               .BYTE $02, $23           ;ChanB tone period fine tune      
               .BYTE $03, $03           ;ChanB tone period coarse tune
               .BYTE $09, $0F           ;ChanB amplitude
               .BYTE $FF, $FF           ; EOF
            SND_TONE_A2_FLAT_C:
               .BYTE $04, $B3           ;ChanA tone period fine tune
               .BYTE $05, $04           ;ChanA tone period coarse tune
               .BYTE $0A, $0F           ;ChanC amplitude    0F = fixed, max
               .BYTE $FF, $FF           ; EOF
            SND_TONE_F1_C:
               .BYTE $04, $2F           ;ChanC tone period fine tune  
               .BYTE $05, $0B           ;ChanC tone period coarse tune
               .BYTE $0A, $0F           ;ChanC amplitude
               .BYTE $FF, $FF           ; EOF
SPI_Ard_StartSession:
    lda #$FE    ;FE works
    sta delayDurationHighByte

    lda #%11111111    ;all pins output - control
    sta DDR3B
    sta DDR2A         ;VIA2, PORTA added for additional clock/control options

    lda #%11111111    ;all pins output - data
    sta DDR3A

    lda #(OE | SCK | RCK_OUT | SPI_DEV0) ;#%00000111      ;dev0 to toggle others off
    sta PORT3B

    lda #%00000000
    sta PORT3B

    rts
SPI_Ard_EndSession:


    lda #(SLOAD)
    sta PORT3B

    lda #(SLOAD | SCK)
    sta PORT3B

    rts
SPI_Ard_SendCommand:
    jsr Delay

    ;Get the data shifted into the outbound shift register
    lda #(SCK)   ;shift clock and receive/latch clock
    sta PORT3B

    lda #(SLOAD)
    sta PORT3B
  
    lda SPI_ARD_Next_Command    ;data to send (i.e., instruction #)
    sta PORT3A

    lda #(SLOAD | OE | SCK)
    sta PORT3B

    lda #(SLOAD | OE)
    sta PORT3B

    lda #(SLOAD | OE | SCK | RCK_OUT)
    sta PORT3B

    lda #(SLOAD | OE)
    sta PORT3B

    lda #(SLOAD | OE | SCK)
    sta PORT3B

    ;Data is in the shift register, now shift it out
    ;;;;;

    lda #(SCK)
    sta PORT3B


    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    ;******

    ;lda #(SLOAD | OE | SCK| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE | SCK | RCK_OUT| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE | SCK| SPI_DEV1_DUE)
    ;sta PORT3B

    rts
SPI_Ard_SendByte:
    jsr Delay

    ;Get the data shifted into the outbound shift register
    lda #(SCK)   ;shift clock and receive/latch clock
    sta PORT3B

    lda #(SLOAD)
    sta PORT3B
  
    lda SPI_ARD_Send_Next_Byte    ;byte of data to send
    sta PORT3A

    lda #(SLOAD | OE | SCK)
    sta PORT3B

    lda #(SLOAD | OE)
    sta PORT3B

    lda #(SLOAD | OE | SCK | RCK_OUT)
    sta PORT3B

    lda #(SLOAD | OE)
    sta PORT3B

    lda #(SLOAD | OE | SCK)
    sta PORT3B

    ;Data is in the shift register, now shift it out
    ;;;;;

    lda #(SCK)
    sta PORT3B


    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    ;******

    ;lda #(SLOAD | OE | SCK| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE | SCK | RCK_OUT| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE| SPI_DEV1_DUE)
    ;sta PORT3B

    ;lda #(SLOAD | OE | SCK| SPI_DEV1_DUE)
    ;sta PORT3B

    rts 
SPI_Ard_ReceiveByte:

    ;lda #$FE        ;FE works
    ;sta delayDurationHighByte

    ;data is latched for out, can now switch to input
    ;read it back in from the receiving SPI to parallel
    ;set VIA PORTA to input
    
    jsr Delay

    
    lda #%00000000    ;all pins input - data
    sta DDR3A

    lda #(SCK| SPI_DEV1_DUE)
    sta PORT3B

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | SCK)
    sta PORT3B
    lda #(SPI_SCK | OEB595)
    sta PORT2A

    lda #(SLOAD | SPI_DEV1_DUE | RCK_IN)
    sta PORT3B
    lda #OEB595
    sta PORT2A

    lda #(SLOAD | SCK)  ;enable inbound shift register''s data output       ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B

    lda #0      ;not OEB595, bring it low, enabling 595 output to the shared data bus
    sta PORT2A

    lda #(SLOAD)     ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B


    lda #(SCK)    ; | SPI_DEV7 (now OE595 on PORT2A)
    sta PORT3B

    lda #(SLOAD | SPI_DEV1_DUE)
    sta PORT3B

    ;lda #$F0
    ;sta delayDurationHighByte

    ;load result into A register. calling procedure can use it.
    lda PORT3A
    


    rts
SPI_Ard_GetStatus:
    jsr SPI_Ard_StartSession
    lda #SPI_ARD_CMD_GETSTATUS
    sta SPI_ARD_Next_Command
    jsr SPI_Ard_SendCommand

    jsr SPI_Ard_ReceiveByte
    jsr print_hex_lcd
    jsr SPI_Ard_EndSession
    rts 
SPI_Ard_PrintScreen:
    lda #$7D;
    jsr print_char_lcd

    jsr SPI_Ard_StartSession

    lda #SPI_ARD_CMD_PRINTSCREEN
    sta SPI_ARD_Next_Command
    jsr SPI_Ard_SendCommand

    ;jsr GetPixelColors

    jsr SPI_Ard_EndSession

    lda #$7B;
    jsr print_char_lcd
    rts 
Handle_Arrow_Up:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    ;*** fpga vga ***
    lda #0          ;data for Player One Move Right
    sta PORT5B
    lda #%10011000    ;cmd: player one move right
    sta PORT5A
    jsr Delay40       ;to do remove delay
    // jsr Delay       ;to do remove delay
    lda #%00011000    ;printchar
    sta PORT5A


    lda kb_flags
    eor #ARROW_UP  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    jmp loop_label
Handle_Arrow_Left:

    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    ;*** fpga vga ***
    lda #0          ;data for Player One Move Right
    sta PORT5B
    lda #%10010111    ;cmd: player one move right
    sta PORT5A
    // jsr Delay       ;to do remove delay
    jsr Delay40       ;to do remove delay
    lda #%00010111    ;printchar
    sta PORT5A

    lda kb_flags
    eor #ARROW_LEFT  ; flip the left arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_Arrow_Right:

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    ;*** fpga vga ***
    lda #0          ;data for Player One Move Right
    sta PORT5B
    lda #%10010101    ;cmd: player one move right
    sta PORT5A
    jsr Delay40       ;to do remove delay
    // jsr Delay       ;to do remove delay
    lda #%00010101    ;printchar
    sta PORT5A


    lda kb_flags
    eor #ARROW_RIGHT  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_KB_flags:
  ;TOOD :?: pha   ;remember A

  ;process arrow keys (would not have been handled in code above, as not ASCII codes)
  lda kb_flags

  bit #ARROW_UP   
  bne Handle_Arrow_Up
  
  bit #ARROW_LEFT 
  bne Handle_Arrow_Left
  
  bit #ARROW_RIGHT  
  bne Handle_Arrow_Right

  bit #ARROW_DOWN   
  bne Handle_Arrow_Down

  bit #NKP5      
  bne Handle_NKP5

  bit #NKP_PLUS
  bne Handle_NKP_Plus

  jmp Handle_KB_flags2
Handle_Arrow_Down:

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    ;phy ;y to stack

    ;*** fpga vga ***
    lda #7          ;data for Player One Move Right
    sta PORT5B
    lda #%10010110    ;cmd: player one move right
    sta PORT5A
    jsr Delay40       ;to do remove delay
    // jsr Delay       ;to do remove delay
    lda #%00010110    ;cmd: move right
    sta PORT5A

    lda kb_flags
    eor #ARROW_DOWN  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    ;ply ;stack to y
    plx ;stack to x
    pla ;stack to a

    jmp loop_label
Handle_NKP5:
    ;put items on stack, so we can return them
    pha ;a to stack

    lda #$40                ;fire rocket sound
    sta Sound_ROW_JumpTo
    jsr PlayFromROM

    ;*** fpga vga ***
    lda #$00          ;data for Player One Move Right
    sta PORT5B
    
    lda #%10011001    ;cmd: fire rocket
    sta PORT5A
    jsr Delay40       ;to do remove delay
    // lda #%00011001    ;printchar
    lda #%00011001    
    sta PORT5A
    ;jsr Delay40       ;to do remove delay

    lda kb_flags
    eor #NKP5  ; flip the arrow bit
    sta kb_flags

    ;return items from stack
    pla ;stack to a

    jmp loop_label
Handle_KB_flags2:
  lda kb_flags2

  bit #NKP_INSERT
  bne Handle_NKP_Insert

  bit #NKP_DELETE
  bne Handle_NKP_Delete

  bit #NKP_MINUS
  bne Handle_NKP_Minus

  bit #NKP_ASTERISK
  bne Handle_NKP_Asterisk

  bit #PRINTSCREEN
  bne Handle_PrintScreen
  
  jmp loop_label
Handle_NKP_Plus:
    inc fill_region_color
    lda fill_region_color
    cmp #$40
    beq resetColorToZero
    jmp handleNKP_Plus_out
    resetColorToZero:
    lda #$00
    handleNKP_Plus_out:
      sta fill_region_color

      lda kb_flags
      eor #NKP_PLUS  ; flip the left arrow bit
      sta kb_flags
      jmp loop_label
Handle_NKP_Insert:
    lda fill_region_color
    sta pixel_prev_color

    lda kb_flags2
    eor #NKP_INSERT
    sta kb_flags2
    jmp loop_label
Handle_NKP_Delete:
    lda fill_region_color   ;first, save current color
    sta $71
    lda #$00                ;set to black
    sta pixel_prev_color

    lda $71
    sta fill_region_color   ;set pixel active color back
    lda kb_flags2
    eor #NKP_DELETE
    sta kb_flags2
    jmp loop_label
Handle_NKP_Minus:
    ;record region start
    lda fill_region_start_x
    sta fill_region_clk_start_x
    lda fill_region_start_y
    sta fill_region_clk_start_y
    
    lda kb_flags2
    eor #NKP_MINUS
    sta kb_flags2
    jmp loop_label
Handle_NKP_Asterisk:
    ;draw region   

    lda kb_flags2
    eor #NKP_ASTERISK
    sta kb_flags2
    jmp loop_label
Handle_PrintScreen:
    ;sei     //turn off interrupts
    jsr SPI_Ard_PrintScreen
    lda kb_flags2
    eor #PRINTSCREEN
    sta kb_flags2
    ;cli
    jmp loop_label
key_pressed:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ldx kb_rptr
    lda kb_buffer, x

    cmp #$0a           ; enter - go to next line
    beq enter_pressed
    cmp #$1b           ; escape - clear display
    beq esc_pressed

    jsr print_char_FPGA
    jsr print_char_lcd

    inc kb_rptr

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    bra loop_label
key_pressed_inMusic:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ldx kb_rptr
    lda kb_buffer, x

    cmp #$0a           ; enter - go to next line
    beq enter_pressed
    cmp #$1b           ; escape - clear display
    beq esc_pressed

    jsr print_char_FPGA
    jsr print_char_lcd

    inc kb_rptr

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    jmp PlaySongFromSDCard_readLoop
Halt_Label:
  jmp Halt_Label  ;end of the program if sent to this subroutine... sit and spin
loop_label:
  ;sit here and loop, process key presses via interrupts as they come in

  ;see if there is incoming data config to send to PSGs
  lda audio_data_to_write
  cmp #$01
  bne loopCont  ;UpdateSoundConfig     ; loopCont ;if no audio config updates, move down to loopCont:, otherwise, jsr to update audio config
  jsr UpdateSoundConfig
  loopCont:
  sei                   ;Set the interrupt disable flag to one.
  lda kb_rptr
  cmp kb_wptr
  cli                   ;Clear Interrupt Disable
  bne key_pressed

  ;Handle KB flags
  jmp Handle_KB_flags
  ;bra loop
enter_pressed:
    ;*** lcd ***
    lda #%10101000 ; put cursor at position 40
    jsr lcd_instruction

    ;*** fpga vga ***
    lda #$0a      ;enter
    sta PORT5B
    lda #%10000001    ;printchar
    sta PORT5A
    jsr Delay40
    lda #%00000001    ;printchar
    sta PORT5A

    inc kb_rptr
    jmp loop_label  
newline_fpga:
    pha
    jsr DelayA0
    ;*** fpga vga ***
    lda #$0a      ;enter
    sta PORT5B
    lda #%10000001    ;printchar
    sta PORT5A
    jsr DelayA0
    lda #%00000001    ;printchar
    sta PORT5A
    jsr DelayA0
    pla
    rts
esc_pressed:
    ;*** lcd ***
    lda #%00000001 ; Clear display
    jsr lcd_instruction

    ;*** fpga vga ***
    lda #$1b      ;escape ASCII code to pass to fpga vga
    sta PORT5B
    lda #%10000001    ;printchar
    sta PORT5A
    jsr Delay40
    lda #%00000001    ;printchar
    sta PORT5A

    inc kb_rptr
    jmp loop_label
lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta DDR1B
lcdbusy:
  lda #RW
  sta PORT1B
  lda #(RW | E)
  sta PORT1B
  lda PORT1B       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta PORT1B
  lda #(RW | E)
  sta PORT1B
  lda PORT1B       ; Read low nibble
  pla             ; Get high nibble off stack
  and #%00001000
  bne lcdbusy

  lda #RW
  sta PORT1B
  lda #%11111111  ; LCD data is output
  sta DDR1B
  pla
  rts
lcd_init:
  ;wait a bit before initializing the screen - helpful at higher 6502 clock speeds
  jsr  Delay
  jsr  Delay

  ;see page 42 of https://eater.net/datasheets/HD44780.pdf
  lda #%00000010 ; Set 4-bit mode
  sta PORT1B
  jsr  Delay
  ora #E
  sta PORT1B
  jsr  Delay
  and #%00001111
  sta PORT1B

  rts
lcd_instruction:
  ;send an instruction to the 2-line LCD
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta PORT1B
  ora #E         ; Set E bit to send instruction
  sta PORT1B
  eor #E         ; Clear E bit
  sta PORT1B
  pla
  and #%00001111 ; Send low 4 bits
  sta PORT1B
  ora #E         ; Set E bit to send instruction
  sta PORT1B
  eor #E         ; Clear E bit
  sta PORT1B
  rts
print_char_FPGA:
    pha
    sta PORT5B
    
    lda #%10000001    ;printchar
    sta PORT5A
    jsr Delay80
    lda #%00000001    ;printchar
    sta PORT5A
    jsr Delay80
  
    pla
    rts
print_char_lcd:
  ;print a character on the 2-line LCD
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta PORT1B
  ora #E          ; Set E bit to send instruction
  sta PORT1B
  eor #E          ; Clear E bit
  sta PORT1B
  pla
  pha
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta PORT1B
  ora #E          ; Set E bit to send instruction
  sta PORT1B
  eor #E          ; Clear E bit
  sta PORT1B
  pla
  rts
print_hex_lcd:
    ;convert scancode/ascii value/other hex to individual chars and display
    ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    sta $65     ;store A so we can keep using original value
    
    ;lda #$30    ;'0'
    ;jsr print_char_lcd
    lda #$78    ;'x'
    jsr print_char_lcd

    ;high nibble
    lda $65
    and #%11110000
    lsr ;shift high nibble to low nibble
    lsr
    lsr
    lsr
    tay
    lda hexOutLookup, y
    jsr print_char_lcd

    ;low nibble
    lda $65
    and #%00001111
    tay
    lda hexOutLookup, y
    jsr print_char_lcd

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
print_dec_lcd:
    ;convert scancode/ascii value/other hex to individual chars (as decimals) and display
    ;e.g., scancode = #$12 (left shift) but want to show '018' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    sta $65     ;store A so we can keep using original value
    lda #0
    sta $66     ;100s
    sta $67     ;10s
    sta $68     ;1s

    HundredsLoop:
        lda $65
        cmp #100             ; compare 100
        bcc TensLoop         ; if binary < 100, all done with hundreds digit
        lda $65
        sec
        sbc #100
        sta $65             ; subtract 100 and store remainder
        inc $66             ; increment the digit result
        jmp HundredsLoop

    TensLoop:
        lda $65
        cmp #10              ; compare 10
        bcc OnesLoop         ; if binary < 10, all done with tens digit
        lda $65
        sec
        sbc #10
        sta $65              ; subtract 10, store remainder
        inc $67              ; increment the digit result
        jmp TensLoop

    OnesLoop:
        lda $65
        sta $68        ; copy what is remaining for singles digit

    ;output the three digits
    ldy $66
    lda hexOutLookup, y
    jsr print_char_lcd
    ldy $67
    lda hexOutLookup, y
    jsr print_char_lcd
    ldy $68
    lda hexOutLookup, y
    jsr print_char_lcd
    
    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
print_hex_FPGA:
    ;convert scancode/ascii value/other hex to individual chars and display
    ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    sta $65     ;store A so we can keep using original value
    
    ;lda #$30    ;'0'
    ;jsr print_char_lcd
    lda #$78    ;'x'
    jsr print_char_FPGA
    jsr Delay00

    ;high nibble
    lda $65
    and #%11110000
    lsr ;shift high nibble to low nibble
    lsr
    lsr
    lsr
    tay
    lda hexOutLookup, y
    jsr print_char_FPGA
    jsr Delay00

    ;low nibble
    lda $65
    and #%00001111
    tay
    lda hexOutLookup, y
    jsr print_char_FPGA
    jsr Delay00

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
irq_done:
  ;return items from stack
  ply ;stack to y
  plx ;stack to x
  pla ;stack to a
  rti
Handle_Mouse_Left_Up:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10010011    ;move up left
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00010011    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay

    pla
    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
Handle_Mouse_Right_Up:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001101    ;move right left
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00001101    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
VIA2_CB1_handler2:
  lda $6A
  eor #MOUSE_LEFT_UP
  beq Handle_Mouse_Left_Up

  lda $6A
  eor #MOUSE_RIGHT_UP
  beq Handle_Mouse_Right_Up
  
  lda $6A
  eor #MOUSE_RIGHT_DOWN
  beq Handle_Mouse_Right_Down

  lda $6A
  eor #MOUSE_LEFT_DOWN
  beq Handle_Mouse_Left_Down

  jmp VIA2_CB1_handler3
Handle_Mouse_Right_Down:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001111    ;move right down
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00001111    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
Handle_Mouse_Left_Down:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10010001    ;move left down
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00010001    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
VIA2_IRQ:               ;USB mouse.  Timer stub.
  ;check interrupt source on VIA IER (T1, T2, CB1, CB2, SR, CA1, CA2) and jump to appropriate handler
  lda IFR2
  and IER2
  asl
  ;BMI T1_handler
  asl
  ;BMI T2_handler
  asl
  ;BMI CB1_handler
  bmi VIA2_CB1_handler      ;USB mouse
  asl
  ;bmi CB2_handler
  asl
  ;bmi SR_handler
  asl
  ;bmi CA1_handler
  asl
  ;bmi CA2_handler

  jmp irq_done      ;should not get to this line if handlers above are setup
irq_label:
    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    ;check interrupts in order of priority
    BIT  IFR1				; Check status register for VIA1        ; PS2 keyboard
    BMI  VIA1_IRQ			; Branch if VIA1 is interrupt source

    BIT  IFR3				; Check status register for VIA3        ; SPI
    BMI  VIA3_IRQ			; Branch if VIA3 is interrupt source

    BIT  IFR2				; Check status register for VIA2        ; USB mouse
    BMI  VIA2_IRQ			; Branch if VIA2 is interrupt source

    BIT IFR4              ; Check status register for VIA4       ; Joystick on Sound Card
    BMI VIA4_IRQ

    ;Currently, no interrupts on VIA5
    ;BIT IFR5              ; Check status register for VIA5       ; FPGQ VGA
    ;BMI VIA5_IRQ

    ;Should never get here unless missing a BIT/BMI for the interrupt source
    jmp irq_done
VIA1_IRQ:               ;keyboard
    ;to do -- check interrupt source on VIA IER (CB1, CB2, CA1, CA2)
    jmp keyboard_interrupt
VIA4_IRQ:
    ;check interrupt source on VIA IER (T1, T2, CB1, CB2, SR, CA1, CA2)
    lda IFR4
    and IER4
    asl
    ;BMI VIA4_T1_handler
    asl
    ;BMI VIA4_T2_handler
    asl
    bmi VIA4_CB1_handler    ;joystick on sound card
    asl
    bmi VIA4_CB2_handler    ;interrupt from FPGA VGA back to 6502
    asl
    ;bmi VIA4_SR_handler
    asl
    ;bmi VIA4_CA1_handler
    asl
    ;bmi VIA4_CA2_handler

    jmp irq_done      ;should not get to this line if handlers above are setup
VIA4_CB1_handler:       ;joystick on sound card
    ;Use sound card ROM read code. Read from port B on sound card AY-3-8910.

    lda #$0F    ;0F = Register for I/O port B - read address at previously specified ROM address
    jsr AY3_setreg
    jsr AY3_readdata    ;Read result in A register  - using bits 7 downto 3 for joystick direction and button
    
    cmp #$FF                    ;no button or joystick move active  -bits are high if unset, pulled low when set
    beq VIA4_CB1_handler_OUT

    pha
    eor #$FF        ;flip bits
    and #%10000000  ;if fire button, play sound, otherwise skip sund
    beq NoFire

    lda #$40                ;fire rocket sound
    sta Sound_ROW_JumpTo
    jsr PlayFromROM
    jsr Delay00

    NoFire:
    pla

    ;*** fpga vga ***
    sta PORT5B  ;write A register to FPGA VGA as data: (contains joystick port data) 
    lda #%10011010    ;cmd: player one move fire (cmd:26)
    sta PORT5A
    jsr Delay40       
    lda #%00011010    ;cmd: player one move fire - toggle interrupt bit
    sta PORT5A

    jmp VIA4_CB1_handler    ;support holding down button/joystick

    VIA4_CB1_handler_OUT:
    bit PORT4B      ;clear interrupt by reading the port
    jmp irq_done
VIA4_CB2_handler:       ;FPGA VGA to 6502 interrupt (status update, e.g., sprite collission)

    lda #$00                ;collission sound
    sta Sound_ROW_JumpTo
    jsr PlayFromROM

    bit PORT4B
    jmp irq_done
VIA2_CB1_handler:       ;USB mouse handler
  jmp VIA2_CB1_handler1
VIA3_CB1_handler:       ;Counter for temperature sensor refresh
  bit PORT3B        ;reset VIA interrupts CA1, CB1
  jmp irq_done
VIA3_CA1_handler:       ;ACIA
    lda ACIA_DATA     
    CA1_handler_out:
        bit ACIA_STATUS   ;reset interrupt of ACIA
        bit PORT3A        ;reset VIA interrupt    ;if running ACIA interrupt direct to 6502 (i.e., no VIA), this step is not necessary
        jmp irq_done
VIA3_IRQ:               ;
  ;check interrupt source on VIA IER (T1, T2, CB1, CB2, SR, CA1, CA2)
  lda IFR3
  and IER3
  asl
  ;BMI T1_handler
  asl
  ;BMI T2_handler
  asl
  bmi VIA3_CB1_handler  ;was: temperature sensor
  asl
  bmi VIA3_CB2_handler
  asl
  ;bmi SR_handler
  asl
  bmi VIA3_CA1_handler  ;was: ACIA
  asl
  ;bmi CA2_handler

  jmp irq_done      ;should not get to this line if handlers above are setup
VIA3_CB2_handler:       ;Arduino with SPI connection to 6502
    ;used to receive audio data

    ;lda #%00000001 ; Clear display
    ;jsr lcd_instruction
    ;lda #%10101000 ; put cursor at position 40
    ;jsr lcd_instruction

    jsr SPI_Ard_StartSession
    lda #SPI_ARD_CMD_GETSOUNDINFO
    sta SPI_ARD_Next_Command
    jsr SPI_Ard_SendCommand

    ;expecting eight bytes back       -0 (status)
    jsr SPI_Ard_ReceiveByte
    ;jsr print_hex_lcd

    ;** expecting 44 bytes of data **
    ;1
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLA
    ;jsr print_hex_lcd

    ;2
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLB
    ;jsr print_hex_lcd

    ;TO DO fill out the rest of these
    ;3
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLC
    ;jsr print_hex_lcd

    ;4
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLD
    ;jsr print_hex_lcd

    ;5
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLE
    ;jsr print_hex_lcd

    ;6
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseLF
    ;jsr print_hex_lcd

    ;7
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLA
    ;jsr print_hex_lcd

    ;8
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLB
    ;jsr print_hex_lcd

    ;9
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLC
    ;jsr print_hex_lcd

    ;10
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLD
    ;jsr print_hex_lcd

    ;11
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLE
    ;jsr print_hex_lcd

    ;12
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineLF
    ;jsr print_hex_lcd

    ;13
    jsr SPI_Ard_ReceiveByte
    sta VolumeLA
    ;jsr print_hex_lcd

    ;14
    jsr SPI_Ard_ReceiveByte
    sta VolumeLB
    ;jsr print_hex_lcd

    ;15
    jsr SPI_Ard_ReceiveByte
    sta VolumeLC
    ;jsr print_hex_lcd

    ;16
    jsr SPI_Ard_ReceiveByte
    sta VolumeLD
    ;jsr print_hex_lcd

    ;17
    jsr SPI_Ard_ReceiveByte
    sta VolumeLE
    ;jsr print_hex_lcd

    ;18
    jsr SPI_Ard_ReceiveByte
    sta VolumeLF
    ;jsr print_hex_lcd

    ;19
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRA
    ;jsr print_hex_lcd

    ;20
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRB
    ;jsr print_hex_lcd

    ;21
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRC
    ;jsr print_hex_lcd

    ;22
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRD
    ;jsr print_hex_lcd

    ;23
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRE
    ;jsr print_hex_lcd

    ;24
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodCourseRF
    ;jsr print_hex_lcd

    ;25
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRA
    ;jsr print_hex_lcd

    ;26
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRB
    ;jsr print_hex_lcd

    ;27
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRC
    ;jsr print_hex_lcd

    ;28
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRD
    ;jsr print_hex_lcd

    ;29
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRE
    ;jsr print_hex_lcd

    ;30
    jsr SPI_Ard_ReceiveByte
    sta TonePeriodFineRF
    ;jsr print_hex_lcd

    ;31
    jsr SPI_Ard_ReceiveByte
    sta VolumeRA
    ;jsr print_hex_lcd

    ;32
    jsr SPI_Ard_ReceiveByte
    sta VolumeRB
    ;jsr print_hex_lcd

    ;33
    jsr SPI_Ard_ReceiveByte
    sta VolumeRC
    ;jsr print_hex_lcd

    ;34
    jsr SPI_Ard_ReceiveByte
    sta VolumeRD
    ;jsr print_hex_lcd

    ;35
    jsr SPI_Ard_ReceiveByte
    sta VolumeRE
    ;jsr print_hex_lcd

    ;36
    jsr SPI_Ard_ReceiveByte
    sta VolumeRF
    ;jsr print_hex_lcd

    ;37
    jsr SPI_Ard_ReceiveByte
    sta NoisePeriodL1
    ;jsr print_hex_lcd

    ;38
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodCourseL1
    ;jsr print_hex_lcd

    ;39
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodFineL1
    ;jsr print_hex_lcd

    ;40
    jsr SPI_Ard_ReceiveByte
    sta EnvelopeShapeCycleL1
    ;jsr print_hex_lcd

    ;41*
    jsr SPI_Ard_ReceiveByte
    sta EnableLeft1
    ;jsr print_hex_lcd

    ;42
    jsr SPI_Ard_ReceiveByte
    sta EnableRight1
    ;jsr print_hex_lcd

    ;43
    jsr SPI_Ard_ReceiveByte
    sta EnableLeft2
    ;jsr print_hex_lcd

    ;44
    jsr SPI_Ard_ReceiveByte
    sta EnableRight2
    ;jsr print_hex_lcd

    ; ***** added *****

    ;45
    jsr SPI_Ard_ReceiveByte
    sta NoisePeriodR1
    ;jsr print_hex_lcd

    ;46
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodCourseR1
    ;jsr print_hex_lcd

    ;47
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodFineR1
    ;jsr print_hex_lcd

    ;48
    jsr SPI_Ard_ReceiveByte
    sta EnvelopeShapeCycleR1
    ;jsr print_hex_lcd


    ;49
    jsr SPI_Ard_ReceiveByte
    sta NoisePeriodL2
    ;jsr print_hex_lcd

    ;50
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodCourseL2
    ;jsr print_hex_lcd

    ;51
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodFineL2
    ;jsr print_hex_lcd

    ;52
    jsr SPI_Ard_ReceiveByte
    sta EnvelopeShapeCycleL2
    ;jsr print_hex_lcd


    ;53
    jsr SPI_Ard_ReceiveByte
    sta NoisePeriodR2
    ;jsr print_hex_lcd

    ;54
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodCourseR2
    ;jsr print_hex_lcd

    ;55
    jsr SPI_Ard_ReceiveByte
    sta EnvelopePeriodFineR2
    ;jsr print_hex_lcd

    ;56
    jsr SPI_Ard_ReceiveByte
    sta EnvelopeShapeCycleR2
    ;jsr print_hex_lcd


    jsr SPI_Ard_EndSession

    bit PORT3B

    lda #$01
    sta audio_data_to_write

    jmp irq_done
VIA2_CB1_handler1:

    ;lda #%00000001 ; Clear display
    ;jsr lcd_instruction

    lda PORT2B    ;clear interrupt
    sta $69 ;store original value read from port
    and #%00111100  ;the bits used for mouse move
    sta $6A ;store masked portion for mouse move

    eor #MOUSE_LEFT
    beq Handle_Mouse_Left

    lda $6A
    eor #MOUSE_UP
    beq Handle_Mouse_Up
    
    lda $6A
    eor #MOUSE_RIGHT
    beq Handle_Mouse_Right
    
    lda $6A
    eor #MOUSE_DOWN
    beq Handle_Mouse_Down

    jmp VIA2_CB1_handler2
Handle_Mouse_Left:
    
    ;*** fpga vga    
    pha
    
    lda #$00          ;data for Player One Move Right
    sta PORT5B

    lda #%10010010    ;move left down
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00010010    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
Handle_Mouse_Up:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001100    ;move up
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00001100    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

  jmp VIA2_CB1_handler3
  ;jmp VIA2_IRQ_OUT   
Handle_Mouse_Right:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001110    ;move right
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00001110    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

    jmp VIA2_CB1_handler3
    ;jmp VIA2_IRQ_OUT
Handle_Mouse_Down:

    ;*** fpga vga    
    pha

    lda #$00          ;data for Player One Move Right
    sta PORT5B

    lda #%10010000    ;move down
    sta PORT5A
    jsr Delay       ;to do remove delay
    lda #%00010000    ;printchar
    sta PORT5A
    jsr Delay       ;to do remove delay   
    pla

  jmp VIA2_CB1_handler3
  ;jmp VIA2_IRQ_OUT
Handle_Mouse_Click_Left:
    
    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10010100    ;move left click
    sta PORT5A
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    lda #%00010100    ;printchar
    sta PORT5A
    pla
    
    ;jsr print_dec_lcd
    bit PORT2B      ;reset interrupt
    
    lda currently_drawing
    cmp #$01
    beq JS_turnDrawingOff_MouseL
    lda #$01   ;otherwise, turn it on
    jmp handleJSpress_out_MouseL
    JS_turnDrawingOff_MouseL:
    lda #$00
    handleJSpress_out_MouseL:
    sta currently_drawing

    bit PORT2B      ;reset interrupt
    jmp irq_done
VIA2_CB1_handler3:
    lda $69 ;get original info from port read - need to check for mouse buttons

    ;jsr print_hex_lcd

    and #%00000011      ;mouse button mask
    ;jsr print_hex_lcd
    sta $6A

    eor #MOUSE_CLICK_LEFT
    beq Handle_Mouse_Click_Left
    
    lda $6A
    eor #MOUSE_CLICK_MIDDLE
    beq Handle_Mouse_Click_Middle

    lda $6A
    eor #MOUSE_CLICK_RIGHT
    beq Handle_Mouse_Click_Right
    
    jmp irq_done
    ;jmp VIA2_CB1_handler3
Handle_Mouse_Click_Middle:
    
    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001011    ;move middle click
    sta PORT5A
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    lda #%00001011    ;printchar
    sta PORT5A
    pla

    bit PORT2B      ;reset interrupt
    jmp irq_done
Handle_Mouse_Click_Right:

    ;*** fpga vga    
    pha
    ;sta PORT5B
    lda #%10001010    ;move right click
    sta PORT5A
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    jsr Delay       ;to do remove delay
    lda #%10001010    ;printchar
    sta PORT5A
    pla

    bit PORT2B      ;reset interrupt
    jmp irq_done
VIA2_IRQ_OUT:
  jmp irq_done
VIA5_T1_handler:
    rts   ;unused for now
    ;timer event happens far too quickly to be usable for a temp refresh interval -- causes issues with other interrupts on 6502
    ;lda ticks
    ;clc
    ;adc #1
    ;sta ticksmouse
    ;cmp max_ticks
    ;bne VIA5_IRQ_OUT
    ;lda #0
    ;sta ticks
    ;rts
shift_up:
  lda kb_flags
  eor #SHIFT  ; flip the shift bit
  sta kb_flags
  jmp irq_done
keyboard_interrupt:
  lda kb_flags
  and #RELEASE   ; check if we're releasing a key
  beq read_key   ; otherwise, read the key

  lda kb_flags
  eor #RELEASE   ; flip the releasing bit
  sta kb_flags

  lda PORT1A      ; read key value that is being released
  
  cmp #$12       ; left shift
  beq shift_up
  cmp #$59       ; right shift
  beq shift_up 

  jmp irq_done
key_release:
  lda kb_flags
  ora #RELEASE
  sta kb_flags
  jmp irq_done
shift_down:
  lda kb_flags
  ora #SHIFT
  sta kb_flags
  jmp irq_done
read_key:
  lda PORT1A
  
  ;jsr print_dec_lcd ;***

  cmp #$f0        ; if releasing a key
  beq key_release ; set the releasing bit
  cmp #$12        ; left shift
  beq shift_down
  cmp #$59        ; right shift
  beq shift_down
  cmp #$6b           ; left arrow
  beq arrow_left_down
  cmp #$74           ; right arrow
  beq arrow_right_down
  cmp #$75           ; up arrow
  beq arrow_up_down
  cmp #$72           ; down arrow
  beq arrow_down_down
  cmp #$73           ; numberic keypad '5'
  beq nkp5_down
  cmp #$79           ; numeric keypad '+'
  beq nkpplus_down
  cmp #$70           ; numeric keypad insert
  beq nkpinsert_down
  cmp #$71           ; numeric keypad delete
  beq nkpdelete_down
  cmp #$7b           ; numeric keypay minus
  beq nkpminus_down
  cmp #$7c           ; numeric keypad asterisk
  beq nkpasterisk_down
  cmp #$07           ; F12
  beq printscreen_down
  cmp #$e0           ;trying to filter out '?' 0xe0 from printscreen key
  beq keyscan_ignore

  tax
  lda kb_flags
  and #SHIFT
  bne shifted_key

  lda keymap, x   ; map to character code
  bra push_key
shifted_key:
  lda keymap_shifted, x   ; map to character code
  ;fall into push_key
push_key:
  ldx kb_wptr
  sta kb_buffer, x
  inc kb_wptr
  jmp irq_done
arrow_left_down:
  lda kb_flags
  ora #ARROW_LEFT
  sta kb_flags
  jmp irq_done
arrow_right_down:
  lda kb_flags
  ora #ARROW_RIGHT
  sta kb_flags
  jmp irq_done
arrow_up_down:
  lda kb_flags
  ora #ARROW_UP
  sta kb_flags
  jmp irq_done
arrow_down_down:
  lda kb_flags
  ora #ARROW_DOWN
  sta kb_flags
  jmp irq_done
nkp5_down:
  lda kb_flags
  ora #NKP5
  sta kb_flags
  jmp irq_done
nkpplus_down:
  lda kb_flags
  ora #NKP_PLUS
  sta kb_flags
  jmp irq_done
nkpinsert_down:
  lda kb_flags2
  ora #NKP_INSERT
  sta kb_flags2
  jmp irq_done
nkpdelete_down:
  lda kb_flags2
  ora #NKP_DELETE
  sta kb_flags2
  jmp irq_done
nkpminus_down:
  lda kb_flags2
  ora #NKP_MINUS
  sta kb_flags2
  jmp irq_done
nkpasterisk_down:
  lda kb_flags2
  ora #NKP_ASTERISK
  sta kb_flags2
  jmp irq_done
printscreen_down:
  lda kb_flags2
  ora #PRINTSCREEN
  sta kb_flags2
  jmp irq_done
keyscan_ignore:
  jmp irq_done
PrintStringLCD:
  ;TO DO Make more dynamic, to support many different pre-defined strings
  ldx #0
  psLCDtop:
    lda message1,x
    beq psLCDout
    jsr print_char_lcd
    inx
    jmp psLCDtop
  psLCDout:
    rts
Delay:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    ;lda #$C0	  ;counter start - increase number to shorten delay
    lda delayDurationHighByte	;counter start - increase number to shorten delay
    sta $41       ; store high byte
    Delayloop:
        adc #01
        bne Delayloop
        clc
        inc $41
        bne Delayloop
        clc
        lda $40
        rts
Delay00:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #$00	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    Delay00Loop:
        adc #01
        bne Delay00Loop
        clc
        inc $41
        bne Delay00Loop
        clc
        lda $40
        rts
Delay40:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #40	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    Delay40Loop:
        adc #01
        bne Delay40Loop
        clc
        inc $41
        bne Delay40Loop
        clc
        lda $40
        rts
Delay80:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #80	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    Delay80Loop:
        adc #01
        bne Delay80Loop
        clc
        inc $41
        bne Delay80Loop
        clc
        lda $40
        rts
DelayA0:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #$A0	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    DelayA0Loop:
        adc #01
        bne DelayA0Loop
        clc
        inc $41
        bne DelayA0Loop
        clc
        lda $40
        rts
DelayC0:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #$C0	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    DelayC0Loop:
        adc #01
        bne DelayC0Loop
        clc
        inc $41
        bne DelayC0Loop
        clc
        lda $40
        rts
DelayF0:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    sta $40       ;save current accumulator
    lda #$F0	  ;counter start - increase number to shorten delay
    sta $41       ; store high byte
    DelayF0Loop:
        adc #01
        bne DelayF0Loop
        clc
        inc $41
        bne DelayF0Loop
        clc
        lda $40
        rts
DelayTick:
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    jsr Delay00
    rts
nmi_label:
  rti

.include "SPI_SD_CARD.asm"

;Predefined messages
message1: .asciiz "Ready..."
message2: .asciiz "Windows 11 BE"
message3: .asciiz "..."
message4: .asciiz "..."
message5: .asciiz "..."
message6: .asciiz "..."
message7: .asciiz "..."
message8: .asciiz "..."

;Lookups
hexOutLookup: .asciiz "0123456789ABCDEF"

 .org $fd00    ; 7d00 in ROM binary file
;These keymaps convert keyscans to ASCII values
keymap:
  .byte "????????????? `?"                  ; 00-0F
  .byte "?????q1???zsaw2?"                  ; 10-1F
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

.include "music.asm"

; Reset/IRQ vectors
    .org $fffa
    .word nmi_label
    .word reset
    .word irq_label