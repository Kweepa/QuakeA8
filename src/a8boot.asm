; Sector-1 boot. OS loads this at $0400, JSRs binit, then jumps to $0406.
; SIOV is legal here: page 2 is still the OS database.
!cpu 6502
!to "a8boot.bin", plain
*= $0400

name_l	= $90
name_h	= $91
dest_l	= $92
dest_h	= $93
sec_l	= $94
sec_h	= $95
left_l	= $96
left_h	= $97
skip_n	= $06f0			; past the boot image; SIOV may use ZP $98
max_l	= $99
max_h	= $9a
take_n	= $9b
copy_n	= $9c
dir_l	= $9e
dir_h	= $9f
pay_l	= $a0
pay_h	= $a1

DIRBUF	= $be00
SECBUF	= $0800

	!byte 0				; flags
	!byte 1				; OS loads this sector only
	!word $0400
	!word stage_init
	jmp stage_main
stage_init
	clc
	rts

; mkatr.py overwrites this with (boot sectors - 1). 4 matches a 5-sector stub.
stage_nsec	!byte 4

stage_main
	lda #2
	sta sec_l
	lda #0
	sta sec_h
	lda #<$0480
	sta dest_l
	lda #>$0480
	sta dest_h
	lda stage_nsec
	sta copy_n
.s0
	jsr stage_read
	bcs stage_hang
	inc sec_l
	clc
	lda dest_l
	adc #128
	sta dest_l
	bcc +
	inc dest_h
+
	dec copy_n
	bne .s0
	jmp $0480

stage_hang
	lda #$42
	sta $d01a
-
	jmp -

stage_read
	ldy #6
-
	lda s0dcb,y
	sta $0300,y
	dey
	bpl -
	lda dest_l
	sta $0304
	lda dest_h
	sta $0305
	lda #128
	sta $0308
	lda #0
	sta $0309
	lda sec_l
	sta $030a
	lda sec_h
	sta $030b
	jsr $e459
	lda $0303
	cmp #$01
	beq +
	sec
	rts
+
	clc
	rts

s0dcb	!byte $31, 1, $52, $40, 0, 0, 7

stage0_end = *
!if stage0_end > $0480 {
	!error "boot stub exceeds one sector"
}
*= $0480

bmain
	jsr load_dir
	bcs bhang

	ldx #0
.jobs
	lda job_nl,x
	beq .run
	sta name_l
	lda job_nh,x
	sta name_h
	lda job_dl,x
	sta dest_l
	lda job_dh,x
	sta dest_h
	lda job_ml,x
	sta max_l
	lda job_mh,x
	sta max_h
	txa
	pha
	jsr load_one
	pla
	tax
	bcs bhang
	inx
	bne .jobs
.run
	lda #$0f
	sta $08fd			; effects_vol — menu may change it; do not write it again
	lda #0
	sta $cd				; mouse_en (mem.asm). Menu toggles ST mouse.
	lda #1
	sta $08fc			; level_num
	jsr $0900			; MENU. Returns with OS mapped, NMI off, I=1.
	cli				; SIOV needs the serial IRQ
	jsr load_dir			; menu PMBASE $B800 cleared DIRBUF
	bcs bhang
	lda #<n_game
	sta name_l
	lda #>n_game
	sta name_h
	lda #<$0900
	sta dest_l
	lda #>$0900
	sta dest_h
	lda #$ff
	sta max_l
	sta max_h
	jsr load_one
	bcs bhang
	lda #0
	sta $d40e			; NMI off before the OS ROM goes away
	sei
	lda #$fe			; bit 0 clear: RAM at $C000/$D800/$F000
	sta $d301
	jmp $0900

bhang
	lda #$42
	sta $d01a
.hh
	jmp .hh

; Sectors 20..23 → DIRBUF. Menu players own $B800–$BFFF, so the boot copy
; is gone when MENU returns. $9d: SIOV destroys X.
load_dir
	lda #20
	sta sec_l
	lda #0
	sta sec_h
	lda #<DIRBUF
	sta dest_l
	lda #>DIRBUF
	sta dest_h
	lda #4
	sta $9d
.ldloop
	jsr readsec
	bcs .ldbad
	inc sec_l
	clc
	lda dest_l
	adc #128
	sta dest_l
	bcc +
	inc dest_h
+
	dec $9d
	bne .ldloop
	clc
.ldbad
	rts

dir_find
	lda #<DIRBUF
	sta dir_l
	lda #>DIRBUF
	sta dir_h
.ent
	ldy #0
	lda (dir_l),y
	bne .have
	sec
	rts
.have
	ldy #0
.cm
	lda (name_l),y
	beq .endn
	cmp (dir_l),y
	bne .next
	iny
	cpy #8
	bcc .cm
	jmp .hit
.endn
	lda (dir_l),y
	bne .next
.hit
	ldy #8
	lda (dir_l),y
	sta sec_l
	iny
	lda (dir_l),y
	sta sec_h
	ldy #12
	lda (dir_l),y
	sta left_l
	iny
	lda (dir_l),y
	sta left_h
	clc
	rts
.next
	clc
	lda dir_l
	adc #16
	sta dir_l
	bcc .ent
	inc dir_h
	jmp .ent

take_sec_body
	lda left_h
	bne .full
	lda left_l
	cmp #128
	bcs .full
	sta take_n
	jmp .got
.full
	lda #128
	sta take_n
.got
	lda take_n
	sec
	sbc skip_n
	sta copy_n
	beq .adv
	bcc .adv
	lda max_h
	bne .cap_ok
	lda max_l
	cmp copy_n
	bcs .cap_ok
	sta copy_n
.cap_ok
	ldy #0
.cp
	tya
	clc
	adc skip_n
	tax
	lda SECBUF,x
	sta (pay_l),y
	iny
	cpy copy_n
	bne .cp
	clc
	lda pay_l
	adc copy_n
	sta pay_l
	bcc .submax
	inc pay_h
.submax
	sec
	lda max_l
	sbc copy_n
	sta max_l
	lda max_h
	sbc #0
	sta max_h
.adv
	sec
	lda left_l
	sbc take_n
	sta left_l
	lda left_h
	sbc #0
	sta left_h
	lda #0
	sta skip_n
	clc
	rts

readsec
	lda #$31
	sta $0300
	lda #1
	sta $0301
	lda #$52
	sta $0302
	lda #$40
	sta $0303
	lda dest_l
	sta $0304
	lda dest_h
	sta $0305
	lda #7
	sta $0306
	lda #128
	sta $0308
	lda #0
	sta $0309
	lda sec_l
	sta $030a
	lda sec_h
	sta $030b
	jsr $e459
	lda $0303
	cmp #$01
	beq .siook
	sec
	rts
.siook
	clc
	rts

load_one
	jsr dir_find
	bcs .bad
	lda dest_l
	sta pay_l
	lda dest_h
	sta pay_h
	lda #2
	sta skip_n
.loop
	lda left_l
	ora left_h
	beq .ok
	lda max_l
	ora max_h
	beq .ok
	lda #<SECBUF
	sta dest_l
	lda #>SECBUF
	sta dest_h
	jsr readsec
	bcs .bad
	lda #0
	sta $d40e
	lda #$fe
	sta $d301			; sector copy can land in the OS window
	jsr take_sec_body
	lda #$ff
	sta $d301			; OS back for the next SIOV
	lda #$40
	sta $d40e
	inc sec_l
	bne .loop
	inc sec_h
	jmp .loop
.ok
	clc
.bad
	rts

job_nl	!byte <n_edata, <n_sqt, <n_fnt, <n_tab, <n_menu, 0
job_nh	!byte >n_edata, >n_sqt, >n_fnt, >n_tab, >n_menu
; TAB dest must match TAB_STAGE in mem.asm. MENU then GAME both own $0900.
job_dl	!byte <$0701, <$f000, <$f800, <$b000, <$0900
job_dh	!byte >$0701, >$f000, >$f800, >$b000, >$0900
job_ml	!byte $ff, $ff, $00, $ff, $ff
job_mh	!byte $ff, $ff, $04, $ff, $ff

n_edata	!text "EDATA", 0
n_game	!text "GAME", 0
n_menu	!text "MENU", 0
n_sqt	!text "SQT", 0
n_fnt	!text "FNT", 0
n_tab	!text "TAB", 0

boot_end = *
!if boot_end > skip_n {
	!error "boot image overlaps skip_n"
}
!if boot_end > $0701 {
	!error "boot image overlaps EDATA"
}
