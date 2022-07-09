.setting "HandleLongBranch", true
.setting "RegA16", true
.setting "RegXY16", true

;Vars
    BarGraphStartX              = $080000
    BarGraphStartY              = $080002
    BarGraphBodyColor           = $080004
    BarGraphLED_On_Color        = $080006
    BarGraphLED_Off_Color       = $080008
    RAMValuesTextColor          = $08000A
    LabelColor                  = $08000C
    BarGraph3DColor             = $08000E
    BarGraph3DColor2            = $080010
    ClockLED_On_Color           = $080012
    SevenSegment_On_Color       = $080014
    SevenSegment_Off_Color      = $080016
    ClockLED_Start_X            = $080018
    ClockLED_Start_Y            = $08001A
    ClockLED_End_X              = $08001C
    ClockLED_End_Y              = $08001E
    BarGraphNewValue            = $080020
    ShiftedInstruction          = $080022
    ShiftedStep                 = $080024
    SevenSegment_Start_X        = $080026
    SevenSegment_Start_Y        = $080028

    Eater8CPU_Clock_Val         = $080100
    Eater8CPU_Register_A        = $080102
    Eater8CPU_Register_B        = $080104
    Eater8CPU_Register_INST     = $080106
    Eater8CPU_ProgramCounter    = $080108
    Eater8CPU_Bus               = $08010A
    Eater8CPU_Memory            = $08010C
    Eater8CPU_ControlBits       = $08010E   ;using both bytes
    Eater8CPU_Flags             = $080110   ;using lowest two bits only
    Eater8CPU_Sum               = $080112
    Eater8PCU_Step              = $080114
    Eater8CPU_Memory_Address    = $080116


    Eater8CPU_RAM_0             = $080200
    Eater8CPU_RAM_1             = $080202
    Eater8CPU_RAM_2             = $080204
    Eater8CPU_RAM_3             = $080206
    Eater8CPU_RAM_4             = $080208
    Eater8CPU_RAM_5             = $08020A
    Eater8CPU_RAM_6             = $08020C
    Eater8CPU_RAM_7             = $08020E
    Eater8CPU_RAM_8             = $080210
    Eater8CPU_RAM_9             = $080212
    Eater8CPU_RAM_A             = $080214
    Eater8CPU_RAM_B             = $080216
    Eater8CPU_RAM_C             = $080218
    Eater8CPU_RAM_D             = $08021A
    Eater8CPU_RAM_E             = $08021C
    Eater8CPU_RAM_F             = $08021E

    FLAG_HALT                   = %1000000000000000     ;HLT
    FLAG_MEMORY_ADDRESS_IN      = %0100000000000000     ;MI

    FLAG_MEMORY_OUT             = %0001000000000000     ;RO
    FLAG_INSTRUCTION_REG_OUT    = %0000100000000000     ;IO
    FLAG_INSTRUCTION_REG_IN     = %0000010000000000     ;II
    FLAG_A_REG_IN               = %0000001000000000     ;AI
    FLAG_A_REG_OUT              = %0000000100000000     ;AO
    FLAG_SUM_OUT                = %0000000010000000     ;SO
    FLAG_B_REG_IN               = %0000000000100000     ;BI
    FLAG_OUT_ENABLE             = %0000000000010000     ;OI
    FLAG_COUNTER_ENABLE         = %0000000000001000     ;CE
    FLAG_COUNTER_OUT            = %0000000000000100     ;CO

Eater8_Init:
    pha

    lda #0
    sta Eater8CPU_Memory_Address
    sta Eater8CPU_Memory
    sta Eater8CPU_Clock_Val
    sta Eater8CPU_ProgramCounter
    sta Eater8CPU_Register_INST
    sta Eater8CPU_Register_A
    sta Eater8CPU_Register_B
    sta Eater8CPU_Bus
    sta Eater8CPU_ControlBits
    sta Eater8CPU_Flags
    sta Eater8CPU_Sum
    sta Eater8PCU_Step


    lda #%00000000
    sta BarGraphBodyColor
    lda #%00101001
    sta BarGraphLED_Off_Color
    lda #%11100000
    sta BarGraphLED_On_Color
    lda #%11111100
    sta RAMValuesTextColor
    lda #%11100011
    sta LabelColor
    lda #%10010010
    sta BarGraph3DColor
    lda #%01001001
    sta BarGraph3DColor2
    lda #%11111100
    sta ClockLED_On_Color
    lda #%11011011
    sta SevenSegment_On_Color
    lda #%01001001
    sta SevenSegment_Off_Color

    jsr Eater8_Draw_HeaderText
    jsr Eater8_Draw_BarGraphs

    lda #96
    sta BarGraphStartX
    lda #127
    sta BarGraphStartY
    jsr Eater8_Draw_Clock
    
    jsr Eater8_Draw_Labels

    lda #254
    sta BarGraphStartX
    lda #172
    sta BarGraphStartY
    jsr Eater8_Draw_SevenSegment

    //jsr gfx_Render_Full_Page
    jsr Eater8_LoadRAM
    
    jsr Eater8_GetRAMfromAddress
    jsr Eater8_Draw_ProgramRAM

    jsr Eater8_Update_Screen

    pla
    rts
Eater8_LoadRAM:
    lda #%0000000000011110      ;LDA 14     ;0x1E
    sta Eater8CPU_RAM_0
    lda #%0000000000101111      ;ADD 15     ;0x2F
    sta Eater8CPU_RAM_1
    lda #%0000000011100000      ;OUT        ;0xE0
    sta Eater8CPU_RAM_2
    lda #%0000000011110000      ;HLT        ;0xF0
    sta Eater8CPU_RAM_3

    lda #0
    sta Eater8CPU_RAM_4
    sta Eater8CPU_RAM_5
    sta Eater8CPU_RAM_6
    sta Eater8CPU_RAM_7
    sta Eater8CPU_RAM_8
    sta Eater8CPU_RAM_9
    sta Eater8CPU_RAM_A
    sta Eater8CPU_RAM_B
    sta Eater8CPU_RAM_C
    sta Eater8CPU_RAM_D

    lda #28                                 ;0x1C
    sta Eater8CPU_RAM_E
    lda #14                                 ;0x0E
    sta Eater8CPU_RAM_F
    rts
Eater8_ClockTick:
    pha
    lda Eater8CPU_Clock_Val
    eor #%00000001
    sta Eater8CPU_Clock_Val
    jsr Eater8_Update_Clock
    lda Eater8CPU_Clock_Val
    beq clockFalling
    ;if rising edge of clock, run next steps
        jsr ProcessControl
        bra ect_out
    clockFalling:
        jsr Eater8_Increment_Step
        jsr Eater8_GetControlBits
    ect_out:
        jsr Eater8_Update_Screen
        jsr Eater8_Delay
        jsr Eater8_Delay
        jsr Eater8_Delay
    pla
    rts
ProcessControl:
    ;current control bits were set on previous clock falling edge    
    pc_CounterEnable:   //out
        lda Eater8CPU_ControlBits
        and #FLAG_COUNTER_ENABLE
        beq pc_CounterOut //***
        ;pc out flag is set, so enable program counter (i.e., increment it)
        jsr Eater8_Increment_ProgramCounter
    pc_CounterOut:
        lda Eater8CPU_ControlBits
        and #FLAG_COUNTER_OUT
        beq pc_MemoryOut
        ;counter out flag is set, so copy counter to bus
        lda Eater8CPU_ProgramCounter
        sta Eater8CPU_Bus
    pc_MemoryOut:           //RO
        lda Eater8CPU_ControlBits
        and #FLAG_MEMORY_OUT
        beq pc_InstructionRegisterOut
        ;memory out flag is set, so copy to bus
        lda Eater8CPU_Memory
        sta Eater8CPU_Bus
    pc_InstructionRegisterOut:  //IO
        lda Eater8CPU_ControlBits
        and #FLAG_INSTRUCTION_REG_OUT
        beq pc_SumOut
        ;instruction out flag is set, so copy instruction register to bus
        lda Eater8CPU_Register_INST
        and #$000F      //just the four lower bits of the instruction register go out to the bus
        sta Eater8CPU_Bus
    pc_SumOut:              //SO
        lda Eater8CPU_ControlBits
        and #FLAG_SUM_OUT
        beq pc_AOut
        ;flag set
        lda Eater8CPU_Sum
        sta Eater8CPU_Bus
    pc_AOut:                //AO
        lda Eater8CPU_ControlBits
        and #FLAG_A_REG_OUT
        beq pc_InstructionRegisterIn
        ;flag set
        lda Eater8CPU_Register_A
        sta Eater8CPU_Bus
    pc_InstructionRegisterIn:   //II
        lda Eater8CPU_ControlBits
        and #FLAG_INSTRUCTION_REG_IN
        beq pc_MemoryAddressIn
        ;instruction in flag is set, so copy from bus
        lda Eater8CPU_Bus
        sta Eater8CPU_Register_INST
    pc_MemoryAddressIn:     //MI
        lda Eater8CPU_ControlBits
        and #FLAG_MEMORY_ADDRESS_IN
        beq pc_ARegisterIn
        ;memory address in flag is set, so copy bus to memory address
        lda Eater8CPU_Bus
        sta Eater8CPU_Memory_Address
        jsr Eater8_GetRAMfromAddress
    pc_ARegisterIn          //AI
        lda Eater8CPU_ControlBits
        and #FLAG_A_REG_IN
        beq pc_BRegisterIn
        lda Eater8CPU_Bus
        sta Eater8CPU_Register_A
        jsr UpdateSumOut
    pc_BRegisterIn          //BI
        lda Eater8CPU_ControlBits
        and #FLAG_B_REG_IN
        beq pc_OutEnable
        lda Eater8CPU_Bus
        sta Eater8CPU_Register_B   
        jsr UpdateSumOut
    pc_OutEnable:           //OI
        lda Eater8CPU_ControlBits
        and #FLAG_OUT_ENABLE
        beq pc_Halt
        jsr Eater8_Update_SevenSegment
    pc_Halt:
        lda Eater8CPU_ControlBits
        and #FLAG_HALT
        beq pc_out
        stp
    pc_out:
    rts
UpdateSumOut:
    pha
    lda Eater8CPU_Register_A
    clc
    adc Eater8CPU_Register_B
    sta Eater8CPU_Sum
    pla
    rts
Eater8_Increment_Step:
    pha
    ;support counting 0 to 5 (six steps)
    lda Eater8PCU_Step
    clc
    adc #1
    cmp #6
    bne eis_out
    lda #0
    eis_out:
    sta Eater8PCU_Step
    pla
    rts
Eater8_Increment_ProgramCounter:
    pha
    lda Eater8CPU_ProgramCounter
    clc
    adc #$0001
    cmp #16
    bne eipc_out
    lda #0  ;reset back to zero
    eipc_out:
    sta Eater8CPU_ProgramCounter
    pla
    rts
Eater8_GetRAMfromAddress:
    pha
    phx
    lda Eater8CPU_Memory_Address
    and #$000F
    asl             ;stored in 2-bytes, rotating so that we can index from the first RAM entry of _0
    tax
    lda Eater8CPU_RAM_0, x    
    sta Eater8CPU_Memory
    plx
    pla
    rts
Eater8_GetControlBits:
    pha
    phx
    ;8-bit instruction set data is stored at .org $030000, offset by Instruction,Step,Flags
    
    lda Eater8CPU_Register_INST     ;4 bits
    and #$00F0
    asl
    sta ShiftedInstruction

    lda Eater8PCU_Step    ;3 bits
    and #$0007
    asl
    asl
    eor ShiftedInstruction
    eor Eater8CPU_Flags

    asl             ;stored in 2-bytes, rotating so that we can index from the entry point

    tax
    lda $030000, x
    sta Eater8CPU_ControlBits
    plx
    pla
    rts
Eater8_Update_Screen:
    ;row 1
        ;memory address
        lda #80
        sta BarGraphStartX
        lda #35
        sta BarGraphStartY
        lda Eater8CPU_Memory_Address
        jsr Eater8_Update_BarGraph

        ;memory value
        lda #135
        sta BarGraphStartX
        lda #35
        sta BarGraphStartY
        lda Eater8CPU_Memory
        jsr Eater8_Update_BarGraph  

        ;bus
        lda #190
        sta BarGraphStartX
        lda #35
        sta BarGraphStartY
        lda Eater8CPU_Bus
        jsr Eater8_Update_BarGraph  

        ;program counter
        lda #245
        sta BarGraphStartX
        lda #35
        sta BarGraphStartY
        lda Eater8CPU_ProgramCounter
        jsr Eater8_Update_BarGraph  


    ;row two
        ;instruction
        lda #80
        sta BarGraphStartX
        lda #80
        sta BarGraphStartY
        lda Eater8CPU_Register_INST
        jsr Eater8_Update_BarGraph  

        ;sum
        lda #190
        sta BarGraphStartX
        lda #80
        sta BarGraphStartY
        lda Eater8CPU_Sum
        jsr Eater8_Update_BarGraph  

        ;reg A
        lda #245
        sta BarGraphStartX
        lda #80
        sta BarGraphStartY
        lda Eater8CPU_Register_A
        jsr Eater8_Update_BarGraph  

    ;row 3
        ;flags
        lda #135
        sta BarGraphStartX
        lda #125
        sta BarGraphStartY
        lda Eater8CPU_Flags
        jsr Eater8_Update_BarGraph  

        ;step
        lda #190
        sta BarGraphStartX
        lda #125
        sta BarGraphStartY
        lda Eater8PCU_Step
        jsr Eater8_Update_BarGraph  

        ;reg B
        lda #245
        sta BarGraphStartX
        lda #125
        sta BarGraphStartY
        lda Eater8CPU_Register_B
        jsr Eater8_Update_BarGraph  

    //row 4
    lda #80
    sta BarGraphStartX
    lda #170
    sta BarGraphStartY
    lda Eater8CPU_ControlBits
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    jsr Eater8_Update_BarGraph
    lda #130
    sta BarGraphStartX
    lda Eater8CPU_ControlBits
    //lda #%11000011
    jsr Eater8_Update_BarGraph


    jsr gfx_Render_Full_Page

    rts
Eater8_Draw_HeaderText:
    lda #0
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #5
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda #%11111111
    sta char_color
    lda #'E'  
    jsr print_char_vga
    lda #'a'  
    jsr print_char_vga
    lda #'t'  
    jsr print_char_vga
    lda #'e'  
    jsr print_char_vga
    lda #'r'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'8'  
    jsr print_char_vga
    lda #'-'  
    jsr print_char_vga
    lda #'b'  
    jsr print_char_vga
    lda #'i'  
    jsr print_char_vga
    lda #'t'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'C'  
    jsr print_char_vga
    lda #'P'  
    jsr print_char_vga
    lda #'U'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'E'  
    jsr print_char_vga
    lda #'m'  
    jsr print_char_vga
    lda #'u'  
    jsr print_char_vga
    lda #'l'  
    jsr print_char_vga
    lda #'a'  
    jsr print_char_vga
    lda #'t'  
    jsr print_char_vga
    lda #'o'  
    jsr print_char_vga
    lda #'r'  
    jsr print_char_vga
    rts
Eater8_Draw_ProgramRAM:
    lda #0
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #25
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda #%00011111
    sta char_color
    lda #'P'  
    jsr print_char_vga
    lda #'R'  
    jsr print_char_vga
    lda #'O'  
    jsr print_char_vga
    lda #'G'  
    jsr print_char_vga
    lda #'R'  
    jsr print_char_vga
    lda #'A'  
    jsr print_char_vga
    lda #'M'  
    jsr print_char_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #35
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'0'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_0
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #45
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'1'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_1
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #55
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'2'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_2
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #65
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'3'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_3
    jsr print_hex_vga
    
    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #75
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'4'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_4
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #85
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'5'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_5
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #95
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'6'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_6
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #105
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'7'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_7
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #115
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'8'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_8
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #125
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'9'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_9
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #135
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'A'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_A
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #145
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'B'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_B
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #155
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'C'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_C
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #165
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'D'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_D
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #175
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'E'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_E
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #10
    sta char_vp_x    ;0 to 319
    lda #185
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda RAMValuesTextColor
    sta char_color
    lda #'F'  
    jsr print_char_vga
    lda #':'  
    jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    // lda #'0'  
    // jsr print_char_vga
    lda Eater8CPU_RAM_F
    jsr print_hex_vga

    lda #0
    sta char_y_offset
    lda #5
    sta char_vp_x    ;0 to 319
    lda #210
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda #%00011111
    sta char_color
    lda #'*'  
    jsr print_char_vga
    lda #'A'  
    jsr print_char_vga
    lda #'d'  
    jsr print_char_vga
    lda #'d'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'2'  
    jsr print_char_vga
    lda #'8'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'a'  
    jsr print_char_vga
    lda #'n'  
    jsr print_char_vga
    lda #'d'  
    jsr print_char_vga
    lda #' '  
    jsr print_char_vga
    lda #'1'  
    jsr print_char_vga
    lda #'4'  
    jsr print_char_vga

    rts
Eater8_Draw_Labels:
    //row 1
        lda #0
        sta char_y_offset
        lda #81
        sta char_vp_x    ;0 to 319
        lda #25
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'M'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'M'  
        jsr print_char_vga
        lda #'-'  
        jsr print_char_vga
        lda #'A'  
        jsr print_char_vga
        lda #'D'  
        jsr print_char_vga
        lda #'D'  
        jsr print_char_vga
        lda #'R'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #139
        sta char_vp_x    ;0 to 319
        lda #25
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'M'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'M'  
        jsr print_char_vga
        lda #'-'  
        jsr print_char_vga
        lda #'V'  
        jsr print_char_vga
        lda #'A'  
        jsr print_char_vga
        lda #'L'  
        jsr print_char_vga
        
        lda #0
        sta char_y_offset
        lda #205
        sta char_vp_x    ;0 to 319
        lda #25
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'B'  
        jsr print_char_vga
        lda #'U'  
        jsr print_char_vga
        lda #'S'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #249
        sta char_vp_x    ;0 to 319
        lda #25
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'C'  
        jsr print_char_vga
        lda #'O'  
        jsr print_char_vga
        lda #'U'  
        jsr print_char_vga
        lda #'N'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'R'  
        jsr print_char_vga

    //row 2
        lda #0
        sta char_y_offset
        lda #93
        sta char_vp_x    ;0 to 319
        lda #70
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'I'  
        jsr print_char_vga
        lda #'N'  
        jsr print_char_vga
        lda #'S'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #205
        sta char_vp_x    ;0 to 319
        lda #70
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'S'  
        jsr print_char_vga
        lda #'U'  
        jsr print_char_vga
        lda #'M'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #256
        sta char_vp_x    ;0 to 319
        lda #70
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'R'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'G'  
        jsr print_char_vga
        lda #' '  
        jsr print_char_vga
        lda #'A'  
        jsr print_char_vga

    //row 3
        lda #0
        sta char_y_offset
        lda #90
        sta char_vp_x    ;0 to 319
        lda #115
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'C'  
        jsr print_char_vga
        lda #'L'  
        jsr print_char_vga
        lda #'O'  
        jsr print_char_vga
        lda #'C'  
        jsr print_char_vga
        lda #'K'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #146
        sta char_vp_x    ;0 to 319
        lda #115
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'F'  
        jsr print_char_vga
        lda #'L'  
        jsr print_char_vga
        lda #'A'  
        jsr print_char_vga
        lda #'G'  
        jsr print_char_vga
        lda #'S'  
        jsr print_char_vga
        
        lda #0
        sta char_y_offset
        lda #203
        sta char_vp_x    ;0 to 319
        lda #115
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'S'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'P'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #256
        sta char_vp_x    ;0 to 319
        lda #115
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'R'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'G'  
        jsr print_char_vga
        lda #' '  
        jsr print_char_vga
        lda #'B'  
        jsr print_char_vga

    //row 4
        lda #0
        sta char_y_offset
        lda #90
        sta char_vp_x    ;0 to 319
        lda #160
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'C'  
        jsr print_char_vga
        lda #'O'  
        jsr print_char_vga
        lda #'N'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga
        lda #'R'  
        jsr print_char_vga
        lda #'O'  
        jsr print_char_vga
        lda #'L'  
        jsr print_char_vga
        lda #' '  
        jsr print_char_vga
        lda #'R'  
        jsr print_char_vga
        lda #'E'  
        jsr print_char_vga
        lda #'G'  
        jsr print_char_vga

        lda #0
        sta char_y_offset
        lda #256
        sta char_vp_x    ;0 to 319
        lda #160
        sta char_vp_y    ;0 to 239
        jsr gfx_SetCharVpByXY_TILES
        lda LabelColor
        sta char_color
        lda #'O'  
        jsr print_char_vga
        lda #'U'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga
        lda #'P'  
        jsr print_char_vga
        lda #'U'  
        jsr print_char_vga
        lda #'T'  
        jsr print_char_vga

    rts
Eater8_Draw_BarGraphs
    //row 1
    lda #80
    sta BarGraphStartX
    lda #35
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #135
    sta BarGraphStartX
    lda #35
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #190
    sta BarGraphStartX
    lda #35
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #245
    sta BarGraphStartX
    lda #35
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    //row two
    lda #80
    sta BarGraphStartX
    lda #80
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #190
    sta BarGraphStartX
    lda #80
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #245
    sta BarGraphStartX
    lda #80
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    //row 3
    lda #135
    sta BarGraphStartX
    lda #125
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #190
    sta BarGraphStartX
    lda #125
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    lda #245
    sta BarGraphStartX
    lda #125
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph  

    //row 4
    lda #80
    sta BarGraphStartX
    lda #170
    sta BarGraphStartY
    jsr Eater8_Draw_BarGraph
    lda #130
    sta BarGraphStartX
    jsr Eater8_Draw_BarGraph

    rts
Eater8_Draw_BarGraph:
    pha

    ;body
        lda BarGraphStartX
        sta fill_region_start_x
        clc
        adc #48     ;width of bargraph
        sta fill_region_end_x
        lda BarGraphStartY
        sta fill_region_start_y
        clc
        adc #20     ;height of bargraph
        sta fill_region_end_y
        lda BarGraphBodyColor
        sta fill_region_color
        jsr gfx_FillRegionTILES

    ;3D lower
        lda BarGraphStartY
        clc
        adc #21
        sta fill_region_start_y
        sta fill_region_end_y
        inc fill_region_start_x
        inc fill_region_end_x
        lda BarGraph3DColor
        sta fill_region_color
        jsr gfx_FillRegionTILES
        
        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

    ;3D right
        lda BarGraphStartX
        clc
        adc #49
        sta fill_region_start_x
        sta fill_region_end_x
        lda BarGraphStartY
        clc
        adc #1
        sta fill_region_start_y
        adc #20
        sta fill_region_end_y
        lda BarGraph3DColor2
        sta fill_region_color
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES

    ;LEDs
        lda BarGraphStartX
        clc
        adc #5
        sta fill_region_start_x
        adc #3
        sta fill_region_end_x
        lda BarGraphStartY
        clc
        adc #4
        sta fill_region_start_y
        adc #12
        sta fill_region_end_y
        lda BarGraphLED_Off_Color
        sta fill_region_color
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES


        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        jsr gfx_FillRegionTILES

    pla
    rts
Eater8_Update_BarGraph:
    pha
    sta BarGraphNewValue
    ;LEDs
        lda BarGraphStartX
        clc
        adc #5
        sta fill_region_start_x
        adc #3
        sta fill_region_end_x
        lda BarGraphStartY
        clc
        adc #4
        sta fill_region_start_y
        adc #12
        sta fill_region_end_y
        lda BarGraphNewValue
        and #%10000000
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%01000000
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES


        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00100000
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00010000
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00001000
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00000100
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00000010
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

        lda fill_region_start_x
        clc
        adc #5
        sta fill_region_start_x
        lda fill_region_end_x
        clc
        adc #5
        sta fill_region_end_x
        lda BarGraphNewValue
        and #%00000001
        jsr SetBargraphLEDcolor
        jsr gfx_FillRegionTILES

    pla
    rts
Eater8_Draw_Clock:
    pha

    ;body
        lda BarGraphStartX
        sta fill_region_start_x
        clc
        adc #12     ;width of bargraph
        sta fill_region_end_x
        lda BarGraphStartY
        sta fill_region_start_y
        clc
        adc #14     ;height of bargraph
        sta fill_region_end_y
        lda BarGraphBodyColor
        sta fill_region_color
        jsr gfx_FillRegionTILES

    ;3D lower
        lda BarGraphStartY
        clc
        adc #15
        sta fill_region_start_y
        sta fill_region_end_y
        inc fill_region_start_x
        inc fill_region_end_x
        lda BarGraph3DColor
        sta fill_region_color
        jsr gfx_FillRegionTILES
        
        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

    ;3D right
        lda BarGraphStartX
        clc
        adc #13
        sta fill_region_start_x
        sta fill_region_end_x
        lda BarGraphStartY
        clc
        adc #1
        sta fill_region_start_y
        adc #14
        sta fill_region_end_y
        lda BarGraph3DColor2
        sta fill_region_color
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES

    ;LED
        lda BarGraphStartX
        clc
        adc #3
        sta fill_region_start_x
        sta ClockLED_Start_X
        adc #6
        sta fill_region_end_x
        sta ClockLED_End_X
        lda BarGraphStartY
        clc
        adc #3
        sta fill_region_start_y
        sta ClockLED_Start_Y
        adc #8
        sta fill_region_end_y
        sta ClockLED_End_Y
        lda BarGraphLED_Off_Color
        sta fill_region_color
        jsr gfx_FillRegionTILES

    pla
    rts
Eater8_Update_Clock:
    pha
    lda ClockLED_Start_X
    sta fill_region_start_x
    lda ClockLED_End_X
    sta fill_region_end_x
    lda ClockLED_Start_Y
    sta fill_region_start_y
    lda ClockLED_End_Y
    sta fill_region_end_y

    lda Eater8CPU_Clock_Val
    cmp #1
    bne clockOff
    lda ClockLED_On_Color
    sta fill_region_color
    bra euc_out
    clockOff:
    lda BarGraphLED_Off_Color
    sta fill_region_color
    euc_out:
    jsr gfx_FillRegionTILES 
    //jsr gfx_FillRegionVRAM      ;since the clock update can happen without all other updates (falling edge)
    pla
    rts
Eater8_Draw_SevenSegment:
    pha

    ;body
        lda BarGraphStartX
        sta fill_region_start_x
        clc
        adc #35     ;width of bargraph
        sta fill_region_end_x
        lda BarGraphStartY
        sta fill_region_start_y
        clc
        adc #17     ;height of bargraph
        sta fill_region_end_y
        lda BarGraphBodyColor
        sta fill_region_color
        jsr gfx_FillRegionTILES

    ;3D lower
        lda BarGraphStartY
        clc
        adc #18
        sta fill_region_start_y
        sta fill_region_end_y
        inc fill_region_start_x
        inc fill_region_end_x
        lda BarGraph3DColor
        sta fill_region_color
        jsr gfx_FillRegionTILES
        
        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_x
        inc fill_region_end_y
        jsr gfx_FillRegionTILES

    ;3D right
        lda BarGraphStartX
        clc
        adc #36
        sta fill_region_start_x
        sta fill_region_end_x
        lda BarGraphStartY
        clc
        adc #1
        sta fill_region_start_y
        adc #17
        sta fill_region_end_y
        lda BarGraph3DColor2
        sta fill_region_color
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES

        inc fill_region_start_y
        inc fill_region_start_x
        inc fill_region_end_y
        inc fill_region_end_x
        jsr gfx_FillRegionTILES


    ;Seven-segment
        //lda #0
        //sta char_y_offset
        lda BarGraphStartX
        clc
        adc #5
        //sta char_vp_x    ;0 to 319
        sta SevenSegment_Start_X
        lda BarGraphStartY
        clc
        adc #4
        //sta char_vp_y    ;0 to 239
        sta SevenSegment_Start_Y


    // ;Seven-segment
    //     lda #0
    //     sta char_y_offset
    //     lda BarGraphStartX
    //     clc
    //     adc #5
    //     sta char_vp_x    ;0 to 319
    //     sta SevenSegment_Start_X
    //     lda BarGraphStartY
    //     clc
    //     adc #5
    //     sta char_vp_y    ;0 to 239
    //     sta SevenSegment_Start_Y
    //     jsr gfx_SetCharVpByXY_TILES
    //     lda SevenSegment_Off_Color
    //     sta char_color
    //     lda #'0'  
    //     jsr print_char_vga
    //     inc char_y_offset
    //     lda #'0'  
    //     jsr print_char_vga
    //     inc char_y_offset
    //     lda #'0'  
    //     jsr print_char_vga
    //     inc char_y_offset
    //     lda #'0'  
    //     jsr print_char_vga

       ;body
        lda SevenSegment_Start_X
        sta fill_region_start_x
        clc
        adc #25     ;width of bargraph
        sta fill_region_end_x
        lda SevenSegment_Start_Y
        sta fill_region_start_y
        clc
        adc #10     ;height of bargraph
        sta fill_region_end_y
        //lda BarGraphBodyColor
        lda #%00000011
        sta fill_region_color
        jsr gfx_FillRegionTILES
    pla
    rts
Eater8_Update_SevenSegment:
    pha
    ;body
        lda SevenSegment_Start_X
        sta fill_region_start_x
        clc
        adc #25     ;width of bargraph
        sta fill_region_end_x
        lda SevenSegment_Start_Y
        sta fill_region_start_y
        clc
        adc #10     ;height of bargraph
        sta fill_region_end_y
        //lda BarGraphBodyColor
        lda #%00000011
        sta fill_region_color
        jsr gfx_FillRegionTILES


    lda #0
    sta char_y_offset
    lda SevenSegment_Start_X
    clc
    adc #4
    sta char_vp_x    ;0 to 319
    lda SevenSegment_Start_Y
    clc
    adc #2
    sta char_vp_y    ;0 to 239
    jsr gfx_SetCharVpByXY_TILES
    lda SevenSegment_On_Color
    sta char_color

    lda Eater8CPU_Bus
    jsr print_dec_vga
    
    pla
    rts
Eater8_Delay:
    pha       ;save current accumulator
    //lda #0
    lda #$A000
    EaterDelayloop0:
        clc
        adc #01
        bne EaterDelayloop0
    pla
    rts
SetBargraphLEDcolor:
    pha
    cmp #0
    beq ledOff
        lda BarGraphLED_On_Color
        sta fill_region_color
        bra ledColorOut
    ledOff:
        lda BarGraphLED_Off_Color
        sta fill_region_color
    ledColorOut:
    pla
    rts
print_dec_vga:
    ;convert scancode/ascii value/other hex to individual chars (as decimals) and display
    ;e.g., scancode = #$12 (left shift) but want to show '018' on LCD
    ;accumulator has the value of the scancode

    ;put items on stack, so we can return them
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    sta toDecimal_orig  // $65     ;store A so we can keep using original value
    lda #0
    sta toDecimal_100s  // $66     ;100s
    sta toDecimal_10s   // $67     ;10s
    sta toDecimal_1s    // $68     ;1s

    HundredsLoop:
        lda toDecimal_orig
        cmp #100             ; compare 100
        bcc TensLoop         ; if binary < 100, all done with hundreds digit
        lda toDecimal_orig
        sec
        sbc #100
        sta toDecimal_orig             ; subtract 100 and store remainder
        inc toDecimal_100s             ; increment the digit result
        jmp HundredsLoop

    TensLoop:
        lda toDecimal_orig
        cmp #10              ; compare 10
        bcc OnesLoop         ; if binary < 10, all done with tens digit
        lda toDecimal_orig
        sec
        sbc #10
        sta toDecimal_orig              ; subtract 10, store remainder
        inc toDecimal_10s              ; increment the digit result
        jmp TensLoop

    OnesLoop:
        lda toDecimal_orig
        sta toDecimal_1s        ; copy what is remaining for singles digit

    ;output the three digits
    
    // ldy toDecimal_10s
    // lda hexOutLookup2, y
    // jsr print_hex_vga

    ldy toDecimal_100s
    lda hexOutLookup2, y
    and #$00FF
    jsr print_char_vga
    ldy toDecimal_10s
    lda hexOutLookup2, y
    and #$00FF
    jsr print_char_vga
    ldy toDecimal_1s
    lda hexOutLookup2, y
    and #$00FF
    jsr print_char_vga
    
    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
hexOutLookup2: .byte "0123456789ABCDEF"


