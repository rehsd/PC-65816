sound_init:
    rep #$20  ;set acumulator to 16-bit
    .setting "RegA16", true
    
    lda #$0042  ;'B'
    sta $100002 ;dpram on sound card

    rts