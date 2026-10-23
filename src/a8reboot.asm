; Episode end: restore the OS database, load MENU over GAME, jsr it, load GAME.
; The stub runs at $0480 (map BSS is dead). Page 2 must already be the OS
; image captured at $BC00 on the first LoadPrg. Selectors $08FD–$08FF stay.
!zone a8reboot

a8_reboot_menu
	jsr load_irq_off
	ldx #0
.pg
	lda $bc00,x
	sta $0200,x
	lda $bd00,x
	sta $0300,x
	inx
	bne .pg
	lda #$ff
	sta $d301
	lda #<reboot_stub_src
	sta $90
	lda #>reboot_stub_src
	sta $91
	lda #<$0480
	sta $92
	lda #>$0480
	sta $93
	lda #<reboot_stub_len
	sta $94
	lda #>reboot_stub_len
	sta $95
.cp
	lda $94
	ora $95
	beq .go
	ldy #0
	lda ($90),y
	sta ($92),y
	inc $90
	bne .c1
	inc $91
.c1
	inc $92
	bne .c2
	inc $93
.c2
	lda $94
	bne .c3
	dec $95
.c3
	dec $94
	jmp .cp
.go
	jmp $0480

reboot_stub_src
!pseudopc $0480 {
	cli
	lda #<stub_menu
	sta $90
	lda #>stub_menu
	sta $91
	jsr stub_load
	bcs stub_hang
	jsr $0900
	cli
	lda #<stub_game
	sta $90
	lda #>stub_game
	sta $91
	jsr stub_load
	bcs stub_hang
	sei
	lda #0
	sta $d40e
	lda #$fe
	sta $d301
	jmp $0900

stub_hang
	lda #$42
	sta $d017
.hh	jmp .hh

; Name at ($90) → payload at $0900. Skips the 2-byte PRG header.
stub_load
	lda #<$0900
	sta $92
	lda #>$0900
	sta $93
	jsr stub_dir
	bcs .ldbad
	jsr stub_find
	bcs .ldbad
	lda #2
	sta $06f0			; skip. SIOV clobbers ZP $98.
.ld
	lda $96
	ora $97
	beq .ldok
	lda #<$bf80
	sta $9d
	lda #>$bf80
	sta $9e
	jsr stub_read
	bcs .ldbad
	jsr stub_take
	inc $94
	bne .ld
	inc $95
	jmp .ld
.ldok
	clc
	rts
.ldbad
	sec
	rts

stub_dir
	lda #20
	sta $94
	lda #0
	sta $95
	lda #<$be00
	sta $06f1
	lda #>$be00
	sta $06f2
	lda #4
	sta $06f3
.dr
	lda $06f1
	sta $9d
	lda $06f2
	sta $9e
	jsr stub_read
	bcs .drbad
	inc $94
	clc
	lda $06f1
	adc #128
	sta $06f1
	bcc .dr2
	inc $06f2
.dr2
	dec $06f3
	bne .dr
	clc
	rts
.drbad
	sec
	rts

stub_find
	lda #<$be00
	sta $9b
	lda #>$be00
	sta $9c
.fe
	ldy #0
	lda ($9b),y
	beq .fbad
.fc
	lda ($90),y
	beq .fend
	cmp ($9b),y
	bne .fnext
	iny
	cpy #8
	bcc .fc
	jmp .fhit
.fend
	lda ($9b),y
	bne .fnext
.fhit
	ldy #8
	lda ($9b),y
	sta $94
	iny
	lda ($9b),y
	sta $95
	ldy #12
	lda ($9b),y
	sta $96
	iny
	lda ($9b),y
	sta $97
	clc
	rts
.fnext
	clc
	lda $9b
	adc #16
	sta $9b
	bcc .fe
	inc $9c
	jmp .fe
.fbad
	sec
	rts

stub_take
	lda $97
	bne .full
	lda $96
	cmp #128
	bcs .full
	sta $99
	jmp .got
.full
	lda #128
	sta $99
.got
	lda $99
	sec
	sbc $06f0
	sta $9a
	beq .adv
	bcc .adv
	ldy #0
.tc
	tya
	clc
	adc $06f0
	tax
	lda $bf80,x
	sta ($92),y
	iny
	cpy $9a
	bne .tc
	clc
	lda $92
	adc $9a
	sta $92
	bcc .adv
	inc $93
.adv
	sec
	lda $96
	sbc $99
	sta $96
	lda $97
	sbc #0
	sta $97
	lda #0
	sta $06f0
	clc
	rts

stub_read
	lda #$31
	sta $0300
	lda #1
	sta $0301
	lda #$52
	sta $0302
	lda #$40
	sta $0303
	lda $9d
	sta $0304
	lda $9e
	sta $0305
	lda #7
	sta $0306
	lda #128
	sta $0308
	lda #0
	sta $0309
	lda $94
	sta $030a
	lda $95
	sta $030b
	jsr $e459
	lda $0303
	cmp #1
	beq .rok
	sec
	rts
.rok
	clc
	rts

stub_menu	!text "MENU", 0
stub_game	!text "GAME", 0
}
reboot_stub_end
reboot_stub_len = reboot_stub_end - reboot_stub_src
!if reboot_stub_len > $0280 {
	!error "reboot stub runs into EDATA; len=", reboot_stub_len
}
