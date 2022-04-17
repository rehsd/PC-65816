    ;Music example
    .org $C000
    PlaySongFromSDCard:
        ;TO DO: Add supporting to start at different addresses on SD Card. For now, starting to read music at 0x0.
        
        lda #<SND_RESET
        sta TUNE_PTR_LO
        lda #>SND_RESET
        sta TUNE_PTR_HI

        jsr AY1_PlayTune
        jsr AY2_PlayTune
        jsr AY3_PlayTune
        jsr AY4_PlayTune
        
        jsr newline_fpga
        jsr PrintString_FPGA_ReadingBytes
        jsr newline_fpga

        ;CMD18 (READ_MULTIPLE_BLOCK), argument is address, crc not checked. Send CMD12 (STOP_TRANSMISSION) to end read.
            ;If needing to set specific the starting address other than 0x0
                ;lda #$52           ;CMD18
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand
                ;lda #$00        ;address
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand
                ;lda #$00        ;address
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand
                ;lda #$00        ;address
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand
                ;lda #$00        ;address
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand
                ;lda #$01           ; crc (not checked)
                ;sta SPI_SDCard_Next_Command
                ;jsr SPI_SDCard_SendCommand

        jsr SPI_SDCard_SendCommand18    ;starting address of 0x0
        jsr SPI_SDCard_ReadByteWait
        jsr print_hex_FPGA
        jsr newline_fpga
        cmp #$FE
        ;beq PlaySongFromSDCard_ReadSuccess
        beq PlaySongFromSDCard_ReadHaveData
        rts
    PlaySongFromSDCard_ReadSuccess:
        ;unused procedure
        jsr SPI_SDCard_ReadByteWait
        cmp #$fe  ;always look for #$FE to see if we have data
        beq PlaySongFromSDCard_ReadHaveData
        rts
    PlaySongFromSDCard_ReadHaveData:
        ; Read until 0x1C (File Separator) is found. Possibly 0xFF (End of Music), but not checking for this right now.
        PlaySongFromSDCard_readLoop:
            ;lda #$2e        ;''.''
            ;jsr print_char_FPGA
            
            jsr SPI_SDCard_ReceiveByte
            ;jsr print_hex_FPGA

            cmp #$1C  ;file separator
            beq PlaySongFromSDCard_readLoopComplete    ;if we hit a file separator, we're done reading the file

            cmp #$1D    ;PSG (AY) selector
            beq SetPSG

            ;Check for supported PSG commands - likely a more efficient way of checking for PSG command numbers
            cmp #$00    ;ChA tone period - fine tune
            beq SetPSGRegister
            cmp #$01    ;ChA tone period - course tune
            beq SetPSGRegister
            cmp #$02    ;ChB tone period - fine tune
            beq SetPSGRegister
            cmp #$03    ;ChB tone period - course tune
            beq SetPSGRegister
            cmp #$04    ;ChC tone period - fine tune
            beq SetPSGRegister
            cmp #$05    ;ChC tone period - course tune
            beq SetPSGRegister
            cmp #$08    ;ChA amplitude
            beq SetPSGRegister
            cmp #$09    ;ChB amplitude
            beq SetPSGRegister
            cmp #$0A    ;ChC amplitude
            beq SetPSGRegister

            cmp #$11    ;Delay
            beq SetDelay

            sei                   ;Set the interrupt disable flag to one.
            lda kb_rptr
            cmp kb_wptr
            cli                   ;Clear Interrupt Disable
            bne key_pressed_inMusic
            
            bra PlaySongFromSDCard_readLoop     ;always loop - end of loop check above, looking for 0x1C

        PlaySongFromSDCard_readLoopComplete:
            jsr newline_fpga
            jsr SPI_SDCard_SendCommand12
            jsr SPI_SDCard_ReadByteWait
            jsr newline_fpga
            jsr PrintString_Music_EOF
            rts
    SetPSG:
        ;read next byte to get the value
        ;jsr PrintString_Music_SetPSG
        jsr SPI_SDCard_ReceiveByte  ;we are in the 0x1D CMD already - next byte is the PSG number (1-4). 1=Left A,B,C. 3=Left D,E,F. 2=Right A,B,C. 4=Right D,E,F.
        sta SND_PSG
        ;jsr print_hex_FPGA
        bra PlaySongFromSDCard_readLoop
    SetPSGRegister:
        ;jsr PrintString_Music_SetPSGRegister
        sta SND_CMD
        ;jsr print_hex_FPGA
        ;lda #$3A    ;':'
        ;jsr print_char_FPGA
        jsr SPI_SDCard_ReceiveByte  ;get the value for the CMD        
        sta SND_VAL
        ;jsr print_hex_FPGA
        ;jsr newline_fpga
        ;lda #$2C    ;','
        ;jsr print_char_FPGA
        
        ;call procedure to change registers
        ;PSG# stored in SND_PSG
        ;Command# stored in SND_CMD
        ;Command value stored in SND_VAL
        lda SND_PSG
        cmp #$01
        beq SetPSG1
        cmp #$02
        beq SetPSG2
        cmp #$03
        beq SetPSG3
        cmp #$04
        beq SetPSG4

        ;shouldn't get to this
        jmp PlaySongFromSDCard_readLoop
    SetPSG1:
        lda SND_CMD
        jsr AY1_setreg
        lda SND_VAL
        jsr AY1_writedata        
        ;bra PlaySongFromSDCard_readLoop
        ;for now, set PSG2 the same as PSG1 (mirror left channel to right channel) (i.e., don't bra here, fall into SetPSG2)
    SetPSG2:
        lda SND_CMD
        jsr AY2_setreg
        lda SND_VAL
        jsr AY2_writedata
        jmp PlaySongFromSDCard_readLoop
    SetPSG3:
        lda SND_CMD
        jsr AY3_setreg
        lda SND_VAL
        jsr AY3_writedata
        ;bra PlaySongFromSDCard_readLoop
        ;for now, set PSG4 the same as PSG3 (mirror left channel to right channel) (i.e., don't bra here, fall into SetPSG4)
    SetPSG4:
        lda SND_CMD
        jsr AY4_setreg
        lda SND_VAL
        jsr AY4_writedata
        jmp PlaySongFromSDCard_readLoop
    SetDelay:
        ;jsr PrintString_Music_SetDelay
        jsr SPI_SDCard_ReceiveByte  ;get the delay value
        ;jsr print_hex_FPGA
        cmp #$01
        beq SoundTick
        cmp #$02
        beq SoundTickHalf
        cmp #$03
        beq SoundTickQuarter
        cmp #$00
        beq SoundTickMinimal
        jmp PlaySongFromSDCard_readLoop
    SoundTick:
        jsr Delay00
        jsr Delay00
        jsr Delay00
        jsr Delay00
        jmp PlaySongFromSDCard_readLoop
    SoundTickHalf:
        jsr Delay00
        jsr Delay00
        jmp PlaySongFromSDCard_readLoop
    SoundTickQuarter:
        jsr Delay00
        jmp PlaySongFromSDCard_readLoop
    SoundTickMinimal:
        jsr Delay80
        jmp PlaySongFromSDCard_readLoop
    ;SND_TONES
        SND_TONE_D5_CHC:
            .BYTE $04, $D4                      ;ChanA tone period fine tune
            .BYTE $05, $00                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D5_CHC_OFF:
            .BYTE $04, $D4                      ;ChanA tone period fine tune
            .BYTE $05, $00                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G4:
            .BYTE $00, $3E                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G4_OFF:
            .BYTE $00, $3E                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_F4S:
            .BYTE $00, $51           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_F4S_OFF:
            .BYTE $00, $51           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_F4S_CHC:
            .BYTE $04, $51                      ;ChanA tone period fine tune
            .BYTE $05, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_F4S_CHC_OFF:
            .BYTE $04, $51                      ;ChanA tone period fine tune
            .BYTE $05, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4S:
            .BYTE $00, $91                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4S_OFF:
            .BYTE $00, $91                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4S_CHC:
            .BYTE $04, $91                      ;ChanA tone period fine tune
            .BYTE $05, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4S_CHC_OFF:
            .BYTE $04, $91                      ;ChanA tone period fine tune
            .BYTE $05, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4:
            .BYTE $00, $A9                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4_OFF:
            .BYTE $00, $A9                      ;ChanA tone period fine tune
            .BYTE $01, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4_CHB:
            .BYTE $02, $A9                      ;ChanA tone period fine tune
            .BYTE $03, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D4_CHB_OFF:
            .BYTE $02, $A9                      ;ChanA tone period fine tune
            .BYTE $03, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_C4S:
            .BYTE $00, $C2           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_C4S_OFF:
            .BYTE $00, $C2           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_C4S_CHB:
            .BYTE $02, $C2           ;ChanA tone period fine tune
            .BYTE $03, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_C4S_CHB_OFF:
            .BYTE $02, $C2           ;ChanA tone period fine tune
            .BYTE $03, $01           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_B4:
            .BYTE $00, $FD                      ;ChanA tone period fine tune
            .BYTE $01, $00                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_B4_OFF:
            .BYTE $00, $FD                      ;ChanA tone period fine tune
            .BYTE $01, $00                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A4S_CHB
            .BYTE $02, $0C                      ;ChanB tone period fine tune
            .BYTE $03, $01                      ;ChanB tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF  
        SND_TONE_A4S_CHB_OFF
            .BYTE $02, $0C                      ;ChanB tone period fine tune
            .BYTE $03, $01                      ;ChanB tone period coarse tune
            .BYTE $08, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF  
        SND_TONE_A4_CHB:
            .BYTE $02, $1C           ;ChanA tone period fine tune
            .BYTE $03, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_A4_CHB_OFF:
            .BYTE $02, $1C           ;ChanA tone period fine tune
            .BYTE $03, $01           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF        
        SND_TONE_A4:
            .BYTE $00, $1C           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_A4_OFF:
            .BYTE $00, $1C           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF        
        SND_TONE_B3:
            .BYTE $00, $FA           ;ChanA tone period fine tune
            .BYTE $01, $01           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_B3_CHB:
            .BYTE $02, $FA                      ;ChanA tone period fine tune
            .BYTE $03, $01                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_B3_CHB_OFF:
            .BYTE $02, $FA                      ;ChanA tone period fine tune
            .BYTE $03, $01                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A3S:
            .BYTE $00, $18           ;ChanA tone period fine tune
            .BYTE $01, $02           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_A3S_CHB:
            .BYTE $02, $18                      ;ChanA tone period fine tune
            .BYTE $03, $02                      ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A3S_CHB_OFF:
            .BYTE $02, $18                      ;ChanA tone period fine tune
            .BYTE $03, $02                      ;ChanA tone period coarse tune
            .BYTE $08, $00                      ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3:
            .BYTE $00, $7D                      ;ChanB tone period fine tune
            .BYTE $01, $02                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3_OFF:
            .BYTE $00, $7D                      ;ChanB tone period fine tune
            .BYTE $01, $02                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3_CHB:
            .BYTE $02, $7D                      ;ChanB tone period fine tune
            .BYTE $03, $02                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3_CHB_OFF:
            .BYTE $02, $7D                      ;ChanB tone period fine tune
            .BYTE $03, $02                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3_CHC:
            .BYTE $04, $7D                      ;ChanB tone period fine tune
            .BYTE $05, $02                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G3_CHC_OFF:
            .BYTE $04, $7D                      ;ChanB tone period fine tune
            .BYTE $05, $02                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_F3S_CHC:
            .BYTE $04, $A3                      ;ChanB tone period fine tune
            .BYTE $05, $02                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_F3S_CHC_OFF:
            .BYTE $04, $A3                      ;ChanB tone period fine tune
            .BYTE $05, $02                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D3S_CHB:
            .BYTE $02, $23           ;ChanB tone period fine tune
            .BYTE $03, $03           ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT           ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_D3S_CHB_OFF:
            .BYTE $02, $23           ;ChanB tone period fine tune
            .BYTE $03, $03           ;ChanB tone period coarse tune
            .BYTE $09, $00           ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_D3S_CHC:
            .BYTE $04, $23                      ;ChanB tone period fine tune
            .BYTE $05, $03                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                          ; EOF
        SND_TONE_D3S_CHC_OFF:
            .BYTE $04, $23                      ;ChanB tone period fine tune
            .BYTE $05, $03                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D3_CHB:
            .BYTE $02, $53                      ;ChanB tone period fine tune
            .BYTE $03, $03                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D3_CHB_OFF:
            .BYTE $02, $53                      ;ChanB tone period fine tune
            .BYTE $03, $03                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
                        ; EOF
        SND_TONE_D3_CHC:
            .BYTE $04, $53                      ;ChanB tone period fine tune
            .BYTE $05, $03                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D3_CHC_OFF:
            .BYTE $04, $53                      ;ChanB tone period fine tune
            .BYTE $05, $03                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G2:
            .BYTE $00, $FB                      ;ChanB tone period fine tune
            .BYTE $01, $04                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G2_OFF:
            .BYTE $00, $FB                      ;ChanB tone period fine tune
            .BYTE $01, $04                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G2_CHB:
            .BYTE $02, $FB                      ;ChanB tone period fine tune
            .BYTE $03, $04                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF 
        SND_TONE_G2_CHB_OFF:
            .BYTE $02, $FB                      ;ChanB tone period fine tune
            .BYTE $03, $04                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G2_CHC:
            .BYTE $04, $FB                      ;ChanB tone period fine tune
            .BYTE $05, $04                      ;ChanB tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF 
        SND_TONE_G2_CHC_OFF:
            .BYTE $04, $FB                      ;ChanB tone period fine tune
            .BYTE $05, $04                      ;ChanB tone period coarse tune
            .BYTE $09, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D2S_CHC:
            .BYTE $04, $47                      ;ChanC tone period fine tune
            .BYTE $05, $06                      ;ChanC tone period coarse tune
            .BYTE $09, SOUND_LEVEL_DEFAULT      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_D2S_CHC_OFF:
            .BYTE $04, $47                      ;ChanC tone period fine tune
            .BYTE $05, $06                      ;ChanC tone period coarse tune
            .BYTE $09, $00                      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_B2_CHB:
            .BYTE $02, $F4           ;ChanA tone period fine tune
            .BYTE $03, $03           ;ChanA tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_B2_CHB_OFF:
            .BYTE $02, $F4           ;ChanA tone period fine tune
            .BYTE $03, $03           ;ChanA tone period coarse tune
            .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
            .BYTE $FF, $FF           ; EOF
        SND_TONE_A2S_CHB:
            .BYTE $02, $30                      ;ChanB tone period fine tune
            .BYTE $03, $04                      ;ChanB tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A2S_CHB_OFF:
            .BYTE $02, $30                      ;ChanB tone period fine tune
            .BYTE $03, $04                      ;ChanB tone period coarse tune
            .BYTE $08, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A2S_CHC:
            .BYTE $04, $30                      ;ChanB tone period fine tune
            .BYTE $05, $04                      ;ChanB tone period coarse tune
            .BYTE $08, SOUND_LEVEL_DEFAULT      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A2S_CHC_OFF:
            .BYTE $04, $30                      ;ChanB tone period fine tune
            .BYTE $05, $04                      ;ChanB tone period coarse tune
            .BYTE $08, $00                      ;ChanB amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_B1_CHC:
            .BYTE $04, $E8                      ;ChanC tone period fine tune
            .BYTE $05, $07                      ;ChanC tone period coarse tune
            .BYTE $0A, SOUND_LEVEL_DEFAULT      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                          ; EOF
        SND_TONE_B1_CHC_OFF:
            .BYTE $04, $E8                      ;ChanC tone period fine tune
            .BYTE $05, $07                      ;ChanC tone period coarse tune
            .BYTE $0A, $00                      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_A1S_CHC:
            .BYTE $04, $61                      ;ChanC tone period fine tune
            .BYTE $05, $08                      ;ChanC tone period coarse tune
            .BYTE $0A, SOUND_LEVEL_DEFAULT      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF        
        SND_TONE_A1S_CHC_OFF:
            .BYTE $04, $61                      ;ChanC tone period fine tune
            .BYTE $05, $08                      ;ChanC tone period coarse tune
            .BYTE $0A, $00                      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G1_CHC:
            .BYTE $04, $F7                      ;ChanC tone period fine tune
            .BYTE $05, $09                      ;ChanC tone period coarse tune
            .BYTE $0A, SOUND_LEVEL_DEFAULT      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF        
        SND_TONE_G1_CHC_OFF:
            .BYTE $04, $F7                      ;ChanC tone period fine tune
            .BYTE $05, $09                      ;ChanC tone period coarse tune
            .BYTE $0A, $00                      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF
        SND_TONE_G1:
            .BYTE $00, $F7                      ;ChanC tone period fine tune
            .BYTE $01, $09                      ;ChanC tone period coarse tune
            .BYTE $0A, SOUND_LEVEL_DEFAULT      ;ChanC amplitude    0F = fixed, max
            .BYTE $FF, $FF                      ; EOF        
        SND_TONE_G1_OFF:
        .BYTE $00, $F7                      ;ChanC tone period fine tune
        .BYTE $01, $09                      ;ChanC tone period coarse tune
        .BYTE $0A, $00                      ;ChanC amplitude    0F = fixed, max
        .BYTE $FF, $FF                      ; EOF
    PlaySong:       ;Initial prototyping for playing music. This can be removed.

        pha ;a to stack
        phx ;x to stack
        phy ;y to stack

        lda #$FF    ;write
        sta DDR4A
        sta DDR4B

        jsr SoundTick
        jsr SoundTick
        jsr SoundTick
        jsr SoundTick

        ResetPSGs:
            ;*************** sound to AY1_2_3_4 (SND_RESET) ***************
                lda #<SND_RESET
                sta TUNE_PTR_LO
                lda #>SND_RESET
                sta TUNE_PTR_HI

                jsr AY1_PlayTune
                jsr AY2_PlayTune
                jsr AY3_PlayTune
                jsr AY4_PlayTune


        Measure1_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure1:
            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure2_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure1

        Measure2_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure2:
    

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure3_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure2

        Measure3_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure3:


            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure4_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure3

        Measure4_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure4:

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure5_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure4

        Measure5_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure5:
    
            ;*************** sound to AY1_2_3_4 (SND_RESET) ***************
                lda #<SND_RESET
                sta TUNE_PTR_LO
                lda #>SND_RESET
                sta TUNE_PTR_HI

                jsr AY1_PlayTune
                jsr AY2_PlayTune
                jsr AY3_PlayTune
                jsr AY4_PlayTune

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure6_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure5

        Measure6_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure6:
    

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure7_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure6

        Measure7_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure7:


            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure8_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure7

        Measure8_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure8:

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune                
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
             ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure9_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure8

        Measure9_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure9:
    
            ;*************** sound to AY1_2_3_4 (SND_RESET) ***************
                lda #<SND_RESET
                sta TUNE_PTR_LO
                lda #>SND_RESET
                sta TUNE_PTR_HI

                jsr AY1_PlayTune
                jsr AY2_PlayTune
                jsr AY3_PlayTune
                jsr AY4_PlayTune

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_G1_CHC) ***************
                lda #<SND_TONE_G1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_D4) ***************
                lda #<SND_TONE_D4
                sta TUNE_PTR_LO
                lda #>SND_TONE_D4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G2_CHB) ***************
                lda #<SND_TONE_G2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_G2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_G1_CHC_OFF) ***************
                lda #<SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_G1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure10_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure9

        Measure10_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure10:
    

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_A1S_CHC) ***************
                lda #<SND_TONE_A1S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_C4S) ***************
                lda #<SND_TONE_C4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_C4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A2S_CHB) ***************
                lda #<SND_TONE_A2S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_A2S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_A1S_CHC_OFF) ***************
                lda #<SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A1S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            cmp #$01
            beq Measure11_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure10

        Measure11_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure11:


            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_G4) ***************
                lda #<SND_TONE_G4
                sta TUNE_PTR_LO
                lda #>SND_TONE_G4
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_D2S_CHC) ***************
                lda #<SND_TONE_D2S_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_A3S) ***************
                lda #<SND_TONE_A3S
                sta TUNE_PTR_LO
                lda #>SND_TONE_A3S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D3S_CHB) ***************
                lda #<SND_TONE_D3S_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_D3S_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_D2S_CHC_OFF) ***************
                lda #<SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_D2S_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure12_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure11

        Measure12_top:
            ;play twice
            lda #0
            sta PlaySong_MeasureLoop
        Measure12:

            ;1/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune                
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune


                jsr SoundTick

            ;2/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
             ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;3/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;4/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;5/12
            ;*************** sound to AY1_2 (SND_TONE_F4S) ***************
                lda #<SND_TONE_F4S
                sta TUNE_PTR_LO
                lda #>SND_TONE_F4S
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4) ***************
                lda #<SND_TONE_A4
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
                ;*************** sound to AY1_2 (SND_TONE_B1_CHC) ***************
                lda #<SND_TONE_B1_CHC
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            ;6/12
            ;*************** sound to AY1_2 (SND_TONE_B3) ***************
                lda #<SND_TONE_B3
                sta TUNE_PTR_LO
                lda #>SND_TONE_B3
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY3_4 (SND_TONE_A4_OFF) ***************
                lda #<SND_TONE_A4_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_A4_OFF
                sta TUNE_PTR_HI
                jsr AY3_PlayTune
                jsr AY4_PlayTune 
            ;*************** sound to AY1_2 (SND_TONE_B2_CHB) ***************
                lda #<SND_TONE_B2_CHB
                sta TUNE_PTR_LO
                lda #>SND_TONE_B2_CHB
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune
            ;*************** sound to AY1_2 (SND_TONE_B1_CHC_OFF) ***************
                lda #<SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_LO
                lda #>SND_TONE_B1_CHC_OFF
                sta TUNE_PTR_HI
                jsr AY1_PlayTune
                jsr AY2_PlayTune

                jsr SoundTick

            lda PlaySong_MeasureLoop
            jsr print_hex_lcd
            cmp #$01
            beq Measure13_top
            lda #01
            sta PlaySong_MeasureLoop
            jmp Measure12
            
            
        Measure13_top:
        //moved to holding.asm for now

        MusicOut:
        ;*************** sound to AY1_2_3_4 (OFF) ***************
            lda #<SND_OFF_ALL
            sta TUNE_PTR_LO
            lda #>SND_OFF_ALL
            sta TUNE_PTR_HI
            jsr AY1_PlayTune
            jsr AY2_PlayTune
            jsr AY3_PlayTune
            jsr AY4_PlayTune  
        ply ;stack to y
        plx ;stack to x
        pla ;stack to a                      
        rts
    ;PrintString calls for this .asm
        PrintString_Music_SetPSG
            phx
            pha
            ldx #0
            psM_SetPSG_top:
                lda messageSetPSG,x
                beq psM_SetPSG_out
                jsr print_char_FPGA
                ;jsr DelayF0
                inx
                jmp psM_SetPSG_top
            psM_SetPSG_out:
                pla
                plx
                rts        
        PrintString_Music_SetPSGRegister
            phx
            pha
            ldx #0
            psM_SetPSGRegister_top:
                lda messageSetPSGRegister,x
                beq psM_SetPSGRegister_out
                jsr print_char_FPGA
                ;jsr DelayF0
                inx
                jmp psM_SetPSGRegister_top
            psM_SetPSGRegister_out:
                pla
                plx
                rts  
        PrintString_Music_SetDelay
            phx
            pha
            ldx #0
            psM_SetDelay_top:
                lda messageSetDelay,x
                beq psM_SetDelay_out
                jsr print_char_FPGA
                ;jsr DelayF0
                inx
                jmp psM_SetDelay_top
            psM_SetDelay_out:
                pla
                plx
                rts 
        PrintString_Music_EOF
            phx
            pha
            ldx #0
            psM_EOF_top:
                lda messageSetEOF,x
                beq psM_EOF_out
                jsr print_char_FPGA
                ;jsr DelayF0
                inx
                jmp psM_EOF_top
            psM_EOF_out:
                pla
                plx
                rts 
        ;Predefined messages
            messageSetPSG:                  .asciiz   "Set PSG: "
            messageSetPSGRegister:          .asciiz   "Reg: "
            messageSetDelay:                .asciiz   "Delay: "
            messageSetEOF:                  .asciiz   "End of File"