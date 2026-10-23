; Atari menu hardware: ANTIC display list, GTIA players, POKEY.
; Rows 0-4: mode E (160, 4 grey levels) for the logo, bitmap at $8000.
; Rows 5-23: ANTIC mode 2 text. Screen at $A000, font at $A400.
; Spinning Q: four players (multicolour pairs), missiles as a black plate,
; and nine mode-2 glyphs on top for the hires luminance.
; Display list at $AE00. Menu code must end below $8000.
; Do not write $0200-$06FF: page 2 is the OS database, $0480 is the reboot stub.
; Exception: set_video_ms fills the PAL hue table at $06D5.

!zone
; $C000 is only 4K before the $D000 I/O hole. A 7680-byte clear from
; there zeroes GTIA, POKEY, PIA and ANTIC (DMA off, PORTB 0).
A8_BMP		= $8000
!zone
A8_BMP_BYTES	= 24 * 320
!zone
A8_DL		= $AE00
!zone
A8_SCR		= $A000			; mode-2 screen, rows 5..23 (19*40)
!zone
A8_TEXT0	= BAR_TOP + MENU_TITLE_ROWS	; first text row; rows above are mode E
!zone
A8_FONT		= $A400			; 1K, index 0 = ASCII space
!zone
A8_CURS_CH	= 'q' - 32
!zone
A8_ROWS		= 24
!zone
A8_PM		= $B800
!zone
A8_PM_Y0	= 24			; 3×8 blank lines before bitmap line 0
!zone
A8_COLPF0	= $d016
!zone
A8_COLPF1	= $d017
!zone
A8_COLBK	= $d01a
!zone
A8_DMACTL	= $d400
!zone
A8_NMIEN	= $d40e
!zone
A8_PMBASE	= $d407
!zone
A8_GRACTL	= $d01d
!zone
A8_PRIOR	= $d01b
!zone
A8_HPOSP0	= $d000
!zone
A8_COLPM0	= $d012
!zone
A8_COLPF2	= $d018
!zone
A8_COLPF3	= $d019
!zone
A8_HPOSM0	= $d004
!zone
A8_SIZEM	= $d00c
!zone
A8_CUR_CH0	= 96			; font slots 96..104: cursor glyphs
!zone
A8_CUR_FONT	= A8_FONT + A8_CUR_CH0 * 8
!zone
A8_KB_ESC	= $1c

!zone
a8_vbi_n	!byte 0
!zone
a8_rowi		!byte 0
!zone
a8_nmist	!byte 0
!zone
a8_sx		!byte 0
!zone
a8_sy		!byte 0
!zone
a8_colpack	!byte 0
!zone
a8_gi		!byte 0
!zone
a8_gb		!byte 0
!zone
a8_si		!byte 0
!zone
a8_vx		!byte 0
!zone
a8_vxh		!byte 0
!zone
a8_bx		!byte 0
!zone
a8_bxh		!byte 0
!zone
a8_by		!byte 0
!zone
a8_px		!byte 0
!zone
a8_pxh		!byte 0
!zone
a8_py		!byte 0
!zone
a8_biti		!byte 0
!zone
a8_sl		= $f3
!zone
a8_sh		= $f4
!zone
a8_pmm		!fill 21, 0		; missile plate
!zone
a8_cglyph	!fill 72, 0		; nine cursor glyphs, 3 rows × 3 columns
!zone
a8_cy		!byte 0			; playfield line of Q line 0
!zone
a8_crow0	!byte 0			; text row holding Q line 0
!zone
a8_g0		!byte 0
!zone
a8_g1		!byte 0
!zone
a8_g2		!byte 0
!zone
a8_cur_orow	!byte $ff		; cells holding cursor codes, $ff = none
!zone
a8_cur_ocol	!byte 0
!zone
a8_cur_r	!byte 0
!zone
a8_cur_code	!byte 0
!zone
a8_r24		!byte 0, 24, 48
!zone
a8_pw0		!fill 21, 0
!zone
a8_pw1		!fill 21, 0
!zone
a8_pg0		!fill 21, 0
!zone
a8_pg1		!fill 21, 0
!zone
a8_cur_hx	!byte 0
!zone
a8_cur_oy	!byte $ff
!zone
a8_cur_dirty	!byte 0

; C64 0..15 → GTIA hue/lum. Same map as a8vic.asm.
!zone
a8_c64pal
	!byte $00,$0e,$42,$a6,$64,$c4,$84,$1c
	!byte $26,$24,$4a,$06,$08,$ca,$9a,$0c

!zone
a8_pf0		!fill A8_ROWS, $00
!zone
a8_pf1		!fill A8_ROWS, $1c
!zone
a8_pf2		!fill A8_ROWS, $00
!zone
a8_colbk	!fill A8_ROWS, $00
!zone
a8_pmbit	!byte $01,$02,$04,$08,$10

; A = packed C64 colour (ink in the high nybble, paper in the low). pr_row set.
; Mode 2 takes the glyph hue from PF2, so black paper keeps PF2 luminance
; at 0 and parks the ink hue there. Title rows are left on the grey ramp.
; Preserves X and Y.
!zone
a8_note_col
	sta a8_colpack
	stx a8_sx
	sty a8_sy
	ldx pr_row
	cpx #A8_ROWS
	bcs .nc_x
	cpx #A8_TEXT0
	bcc .nc_x
	and #$0f
	tay
	lda a8_c64pal,y
	jsr a8_to_pal
	sta a8_gb
	lda a8_colpack
	lsr
	lsr
	lsr
	lsr
	tay
	lda a8_c64pal,y
	jsr a8_to_pal
	sta a8_pf1,x
	lda #0
	sta a8_colbk,x
	sta a8_pf0,x
	lda a8_gb
	bne .paper
	lda a8_pf1,x
	and #$f0
	sta a8_pf2,x
	jmp .nc_x
.paper
	sta a8_pf2,x
.nc_x
	ldx a8_sx
	ldy a8_sy
	rts

!zone
a8_init_vic
	sei
	lda #0
	sta $d40e				; VBI off before RAM covers the OS vector
	lda #$fe
	sta $d301
	lda #0
	sta a8_vbi_n
	sta a8_rowi
	ldx #7
	lda #0
.sil
	sta $d200,x
	dex
	bpl .sil
	lda #$03
	sta $d20f				; SKCTL: keyboard scan
	lda #0
	sta A8_DMACTL
	sta A8_GRACTL
	sta A8_COLPF2
	sta A8_COLPF3				; fifth player (missile plate) is black
	lda #$31
	sta A8_PRIOR				; players over playfield, P0|P1 P2|P3 OR, fifth player
	lda #0
	ldx #3
.szp
	sta $d008,x				; SIZEP normal
	dex
	bpl .szp
	lda #$15
	sta A8_SIZEM				; M0-M2 double width
	lda #$0e
	ldx #3
.pcol
	sta A8_COLPM0,x
	dex
	bpl .pcol
	jsr a8_clear_pm
	jsr a8_build_dl
	ldx #7
	lda #0
.hp
	sta $d000,x				; HPOSP/M off screen
	dex
	bpl .hp
	jsr a8_title_cols
	jsr a8_load_font
	lda #0
	sta $d401				; CHACTL
	lda #>A8_FONT
	sta $d409				; CHBASE
	lda #<A8_DL
	sta $d402
	lda #>A8_DL
	sta $d403
	lda #>A8_PM
	sta A8_PMBASE
	lda #<a8_nmi
	sta $fffa
	lda #>a8_nmi
	sta $fffb
	lda #$c0
	sta A8_NMIEN
	rts

!zone
a8_clear_pm
	lda #<A8_PM
	sta ptr_l
	lda #>A8_PM
	sta ptr_h
	ldx #8
	ldy #0
	lda #0
.cp
	sta (ptr_l),y
	iny
	bne .cp
	inc ptr_h
	dex
	bne .cp
	rts

; 3×8 blank, mode-E logo rows, then mode-2 text through row 23.
; DLI on every row except the last, so the next row's colours land in time.
!zone
a8_build_dl
	lda #<A8_DL
	sta ptr_l
	lda #>A8_DL
	sta ptr_h
	ldy #0
	lda #$70
	jsr a8_dl_byte
	jsr a8_dl_byte
	jsr a8_dl_byte
	ldx #0
.bmp
	stx a8_si
	cpx #A8_TEXT0
	bcs .text
	lda #$4e				; LMS + mode E
	jsr a8_dl_byte
	lda #0
	sta a8_pxh
	lda a8_si
	asl
	rol a8_pxh
	asl
	rol a8_pxh
	asl
	rol a8_pxh
	asl
	rol a8_pxh
	asl
	rol a8_pxh
	asl
	rol a8_pxh			; *64
	sta a8_px
	lda a8_si
	clc
	adc a8_pxh			; *320
	sta a8_pxh
	lda a8_px
	clc
	adc #<A8_BMP
	jsr a8_dl_byte
	lda a8_pxh
	adc #>A8_BMP
	jsr a8_dl_byte
	ldy #5
	lda #$0e
.m
	jsr a8_dl_byte
	dey
	bne .m
	lda #$8e				; one line early: the handler lands on the last line
	jsr a8_dl_byte
	lda #$0e
	jsr a8_dl_byte
	ldx a8_si
	inx
	jmp .bmp
.text
	lda #$c2				; LMS + DLI + mode 2, first text row
	jsr a8_dl_byte
	lda #<A8_SCR
	jsr a8_dl_byte
	lda #>A8_SCR
	jsr a8_dl_byte
	ldy #17				; through row 22
	lda #$82
.t
	jsr a8_dl_byte
	dey
	bne .t
	lda #$02				; row 23
	jsr a8_dl_byte
	lda #$41
	jsr a8_dl_byte
	lda #<A8_DL
	jsr a8_dl_byte
	lda #>A8_DL
	jmp a8_dl_byte

!zone
a8_dl_byte
	sty a8_sy
	ldy #0
	sta (ptr_l),y
	inc ptr_l
	bne .db
	inc ptr_h
.db
	ldy a8_sy
	rts

!zone
a8_nmi
	pha
	txa
	pha
	lda $d40f
	sta a8_nmist
	lda #0
	sta $d40f
	lda a8_nmist
	bpl .vbi
	inc a8_rowi
	ldx a8_rowi
	cpx #A8_ROWS
	bcs .dout
	lda a8_pf0,x
	sta A8_COLPF0
	lda a8_pf1,x
	sta A8_COLPF1
	lda a8_pf2,x
	sta A8_COLPF2
	lda a8_colbk,x
	sta A8_COLBK
.dout
	pla
	tax
	pla
	rti
.vbi
	tya
	pha
	inc a8_vbi_n
	lda #0
	sta a8_rowi
	tax
	lda a8_pf0
	sta A8_COLPF0
	lda a8_pf1
	sta A8_COLPF1
	lda a8_pf2
	sta A8_COLPF2
	lda a8_colbk
	sta A8_COLBK
	jsr a8_cursor_vbi
	jsr a8_music_tick
	pla
	tay
	pla
	tax
	pla
	rti

!zone
a8_clear_screen
	lda #<(A8_BMP + BRAND_KEEP_ROWS * 320)
	sta ptr_l
	lda #>(A8_BMP + BRAND_KEEP_ROWS * 320)
	sta ptr_h
	ldx #22
	jsr a8_zero_pages
	ldy #0
	lda #0
.cs128
	sta (ptr_l),y
	iny
	cpy #128
	bne .cs128
	ldx #BRAND_KEEP_ROWS
.csr
	stx pr_row
	lda clear_bg
	jsr a8_note_col
	inx
	cpx #A8_ROWS
	bcc .csr
	jmp a8_clear_text

!zone
a8_clear_all
	lda #<A8_BMP
	sta ptr_l
	lda #>A8_BMP
	sta ptr_h
	ldx #30
	jsr a8_zero_pages
	ldx #0
.csa
	stx pr_row
	lda clear_bg
	jsr a8_note_col
	inx
	cpx #A8_ROWS
	bcc .csa
	jmp a8_clear_text

; X = page count. ptr = start. Y clobbered, A = 0 on exit.
!zone
a8_zero_pages
	ldy #0
	lda #0
.zp
	sta (ptr_l),y
	iny
	bne .zp
	inc ptr_h
	dex
	bne .zp
	rts

!zone
a8_bmp_cell_addr
	sta pr_col
	stx pr_row
	lda #0
	sta ptr_h
	lda pr_row
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	asl
	rol ptr_h
	sta ptr_l
	lda pr_row
	clc
	adc ptr_h
	sta ptr_h
	lda ptr_l
	clc
	adc pr_col
	sta ptr_l
	bcc .ca
	inc ptr_h
.ca
	clc
	lda ptr_l
	adc #<A8_BMP
	sta ptr_l
	lda ptr_h
	adc #>A8_BMP
	sta ptr_h
	rts

; Y = column offset from ptr. Text rows clear one screen byte. Keeps ptr and Y.
!zone
a8_blank_cell
	lda pr_row
	cmp #A8_TEXT0
	bcc .bbmp
	sty a8_sy
	tya
	clc
	adc pr_col
	cmp #40
	bcs .bout
	tay
	lda pr_row
	jsr a8_scr_row
	ldy a8_sy
	tya
	clc
	adc pr_col
	tay
	lda #0
	sta (ptr_l),y
.bout
	ldy a8_sy
	rts
.bbmp
	sty a8_sy
	tya
	clc
	adc ptr_l
	sta a8_sl
	lda ptr_h
	adc #0
	sta a8_sh
	ldx #8
	ldy #0
.bc
	lda #0
	sta (a8_sl),y
	clc
	lda a8_sl
	adc #40
	sta a8_sl
	bcc .bc2
	inc a8_sh
.bc2
	dex
	bne .bc
	ldy a8_sy
	rts

!zone
a8_blit_z
	ldy #0
.bz
	lda (gptr_l),y
	sty a8_gi
	ldy #0
	ora (ptr_l),y
	sta (ptr_l),y
	jsr a8_ptr_down
	ldy a8_gi
	iny
	cpy #8
	bne .bz
	jmp bmp_advance

!zone
a8_blit_nd
	ldy #0
.bn
	lda (gptr_l),y
	jsr do_shift
	sta a8_gb
	sty a8_gi
	ldy #0
	lda a8_gb
	ora (ptr_l),y
	sta (ptr_l),y
	lda ft_right
	beq .bn0
	lda pr_col
	cmp #39
	bcs .bn0
	lda ft_right
	ora (ptr_r_l),y
	sta (ptr_r_l),y
	lda #1
	sta ft_spill
.bn0
	jsr a8_ptr_down
	lda pr_col
	cmp #39
	bcs .bn1
	clc
	lda ptr_r_l
	adc #40
	sta ptr_r_l
	bcc .bn1
	inc ptr_r_h
.bn1
	ldy a8_gi
	iny
	cpy #8
	bne .bn
	jmp bmp_advance

!zone
a8_ptr_down
	clc
	lda ptr_l
	adc #40
	sta ptr_l
	bcc .pd
	inc ptr_h
.pd
	rts

; Cell-ordered title art → linear bitmap, then the yellow glints.
!zone
a8_blit_title
	lda #<menu_title_data
	sta a8_sl
	lda #>menu_title_data
	sta a8_sh
	ldx #0
.tr
	stx a8_si
	txa
	clc
	adc #BAR_TOP
	sta pr_row
	ldy #0
.tc
	sty a8_sy
	lda a8_sy
	clc
	adc #MENU_TITLE_LEFT
	sta pr_col
	ldx pr_row
	jsr a8_bmp_cell_addr
	ldx #0
.tb
	txa
	tay
	lda (a8_sl),y
	ldy #0
	sta (ptr_l),y
	jsr a8_ptr_down
	inx
	cpx #8
	bne .tb
	lda a8_sl
	clc
	adc #8
	sta a8_sl
	bcc .tn
	inc a8_sh
.tn
	; ptr walked 8 scanlines; the next cell redoes cell_addr from pr_row
	ldy a8_sy
	iny
	cpy #MENU_TITLE_COLS
	bcc .tc
	ldx a8_si
	inx
	cpx #MENU_TITLE_ROWS
	bcc .tr
	jsr a8_title_cols
	jsr a8_bake_highlights
	jmp a8_title_sides

; Mode E ramp on the logo rows: black, dark grey, light grey, white.
!zone
a8_title_cols
	ldx #0
.tc
	lda #$06
	sta a8_pf0,x
	lda #$0a
	sta a8_pf1,x
	lda #$0e
	sta a8_pf2,x
	lda #0
	sta a8_colbk,x
	inx
	cpx #A8_TEXT0
	bcc .tc
	rts

; Columns outside the packed title cells. The letter cells stay.
!zone
a8_title_sides
	ldx #0
.ls
	cpx #MENU_TITLE_LEFT
	bcs .rs
	jsr a8_col_clear
	inx
	jmp .ls
.rs
	ldx #MENU_TITLE_LEFT + MENU_TITLE_COLS
.rc
	cpx #40
	bcs .sd
	jsr a8_col_clear
	inx
	jmp .rc
.sd
	rts

!zone
a8_title_trim
	ldx #0
.f1
	jsr a8_col_ink
	bne .i1
	inx
	cpx #40
	bcc .f1
	rts
.i1
.s1
	jsr a8_col_ink
	beq .g1
	inx
	cpx #40
	bcs .back
	jmp .s1
.g1
	stx a8_si
	ldx #0
.c1
	cpx a8_si
	bcs .back
	jsr a8_col_clear
	inx
	jmp .c1
.back
	ldx #39
.f2
	jsr a8_col_ink
	bne .i2
	dex
	bpl .f2
	rts
.i2
.s2
	jsr a8_col_ink
	beq .g2
	dex
	bpl .s2
	rts
.g2
	inx
.c2
	cpx #40
	bcs .td
	jsr a8_col_clear
	inx
	jmp .c2
.td
	rts

; X = column in the title rows. Z = 1 if those 24 bytes are clear. Keeps X.
!zone
a8_col_ink
	stx a8_sx
	lda #BAR_TOP
	sta a8_by
.r
	lda a8_by
	jsr a8_row320
	ldy a8_sx
	ldx #8
.c
	lda (ptr_l),y
	bne .yes
	jsr a8_ptr_down
	dex
	bne .c
	inc a8_by
	lda a8_by
	cmp #BAR_TOP + MENU_TITLE_ROWS
	bcc .r
	ldx a8_sx
	lda #0
	rts
.yes
	ldx a8_sx
	lda #1
	rts

!zone
a8_col_clear
	stx a8_sx
	lda #BAR_TOP
	sta a8_by
.r
	lda a8_by
	jsr a8_row320
	ldy a8_sx
	ldx #8
.c
	lda #0					; a8_ptr_down clobbers A
	sta (ptr_l),y
	jsr a8_ptr_down
	dex
	bne .c
	inc a8_by
	lda a8_by
	cmp #BAR_TOP + MENU_TITLE_ROWS
	bcc .r
	ldx a8_sx
	rts

; A = character row → ptr = that row in the bitmap.
!zone
a8_row320
	sta a8_vx
	lda #0
	sta a8_vxh
	lda a8_vx
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	sta ptr_l
	lda a8_vx
	clc
	adc a8_vxh
	sta ptr_h
	lda ptr_l
	clc
	adc #<A8_BMP
	sta ptr_l
	lda ptr_h
	adc #>A8_BMP
	sta ptr_h
	rts

!zone
a8_bake_highlights
	ldx #0
.hs
	stx a8_si
	lda title_spr_x,x
	sta a8_vx
	lda #0
	sta a8_vxh
	lda title_spr_xmsb
	and a8_pmbit,x
	beq .hn
	inc a8_vxh
.hn
	lda a8_vx
	sec
	sbc #24
	sta a8_bx
	lda a8_vxh
	sbc #0
	sta a8_bxh
	lda #BAR_TOP * 8 + MENU_TITLE_PAD_Y
	sta a8_by
	jsr a8_or_sprite
	ldx a8_si
	inx
	cpx #TITLE_SPR_COUNT
	bcc .hs
	rts

; Sprite index a8_si → (a8_sl) = menu_title_spr + index*64.
!zone
a8_spr_ptr
	lda #0
	sta a8_sh
	lda a8_si
	asl
	rol a8_sh
	asl
	rol a8_sh
	asl
	rol a8_sh
	asl
	rol a8_sh
	asl
	rol a8_sh
	asl
	rol a8_sh
	clc
	adc #<menu_title_spr
	sta a8_sl
	lda a8_sh
	adc #>menu_title_spr
	sta a8_sh
	rts

; Sprite index a8_si. OR its 24×21 hires bits onto the bitmap.
!zone
a8_or_sprite
	jsr a8_spr_ptr
	ldx #0
.or
	stx a8_biti
	ldy #0
.ob
	sty a8_sy
	lda a8_biti
	asl
	clc
	adc a8_biti
	clc
	adc a8_sy
	tay
	lda (a8_sl),y
	sta a8_gb
	ldx #0
.obit
	asl a8_gb
	bcc .osk
	stx a8_gi
	lda a8_sy
	asl
	asl
	asl
	clc
	adc a8_gi
	clc
	adc a8_bx
	sta a8_px
	lda a8_bxh
	adc #0
	sta a8_pxh
	lda a8_by
	clc
	adc a8_biti
	sta a8_py
	jsr a8_set_px
	ldx a8_gi
.osk
	inx
	cpx #8
	bcc .obit
	ldy a8_sy
	iny
	cpy #3
	bcc .ob
	ldx a8_biti
	inx
	cpx #21
	bcc .or
	rts

; A = y → ptr = y*40. Clobbers a8_vx / a8_vxh.
!zone
a8_mul40
	sta a8_vx
	lda #0
	sta a8_vxh
	lda a8_vx
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	asl
	rol a8_vxh
	sta a8_vx			; *8 lo, a8_vxh = *8 hi
	sta ptr_l
	lda a8_vxh
	sta ptr_h
	asl ptr_l
	rol ptr_h
	asl ptr_l
	rol ptr_h			; *32
	clc
	lda ptr_l
	adc a8_vx
	sta ptr_l
	lda ptr_h
	adc a8_vxh
	sta ptr_h
	rts

!zone
a8_set_px
	lda a8_py
	cmp #192
	bcs .spx
	lda a8_pxh
	beq .spok
	cmp #1
	bne .spx
	lda a8_px
	cmp #64				; 256..319
	bcs .spx
.spok
	lda a8_px
	and #7
	pha
	lda a8_py
	jsr a8_mul40
	lsr a8_pxh
	ror a8_px
	lsr a8_pxh
	ror a8_px
	lsr a8_pxh
	ror a8_px			; a8_px = x/8
	clc
	lda ptr_l
	adc a8_px
	sta ptr_l
	lda ptr_h
	adc a8_pxh
	sta ptr_h
	clc
	lda ptr_l
	adc #<A8_BMP
	sta ptr_l
	lda ptr_h
	adc #>A8_BMP
	sta ptr_h
	pla
	tax
	lda a8_epair,x
	ldy #0
	ora (ptr_l),y
	sta (ptr_l),y
.spx
	rts

!zone
a8_pxmask
	!byte $80,$40,$20,$10,$08,$04,$02,$01
; Mode E: a highlight forces both bits of its colour clock (pixel = 11).
!zone
a8_epair
	!byte $c0,$c0,$30,$30,$0c,$0c,$03,$03

; Left 16 hires bits → one player, white, at the sprite's bitmap X.
!zone
a8_sprite_player
	jsr a8_spr_ptr
	lda a8_bxh
	lsr
	lda a8_bx
	ror
	clc
	adc #48
	ldx a8_si
	sta A8_HPOSP0,x
	ldx #0
.sp
	stx a8_gi
	txa
	asl
	clc
	adc a8_gi
	tay
	lda (a8_sl),y
	jsr a8_pack4
	asl
	asl
	asl
	asl
	sta a8_gb
	iny
	lda (a8_sl),y
	jsr a8_pack4
	ora a8_gb
	sta a8_gb
	lda #A8_PM_Y0 + BAR_TOP * 8 + MENU_TITLE_PAD_Y
	clc
	adc a8_gi
	tay
	lda a8_si
	clc
	adc #$bc			; player 0 page at $B800+$400
	sta .spm + 2
	lda a8_gb
.spm	sta $bc00,y
	ldx a8_gi
	inx
	cpx #21
	bcc .sp
	rts

; A = hires byte → A = 4 colour-clock bits in bits 3..0 (bit 3 = leftmost).
!zone
a8_pack4
	sta a8_colpack
	lda #0
	ldx #4
.pk
	asl
	asl a8_colpack
	bcc .pk0
	ora #1
	asl a8_colpack
	dex
	bne .pk
	rts
.pk0
	asl a8_colpack
	bcc .pk1
	ora #1
.pk1
	dex
	bne .pk
	rts

!zone
a8_setup_pm
	jsr a8_clear_pm
	; Shapes are written when the title is blitted (positions + pixels).
	rts

!zone
a8_menu_blank
	lda #0
	sta hint_spr_en
	sta cursor_spr_en
	sta a8_cur_dirty
	jsr a8_cur_cells_off
	lda #$ff
	sta a8_cur_oy
	lda #0
	ldx #0
.cl
	sta $bb00,x
	sta $bc00,x
	sta $bd00,x
	sta $be00,x
	sta $bf00,x
	inx
	bne .cl
	rts

!zone
a8_menu_unblank
	jsr a8_stamp_cursor
	lda #$3e				; DL DMA, 1-line players + missiles, normal playfield
	sta A8_DMACTL
	lda #$03
	sta A8_GRACTL
	rts

!zone
a8_menu_exit
	sei
	lda #0
	sta A8_NMIEN
	sta A8_DMACTL
	sta A8_GRACTL
	jsr a8_stage_dl
	lda #$ff
	sta $d301
	rts

; Game display list, staged above LoadPrg's $C000 context pages. The game
; copies it to DL after the OS page snapshot. JVB target is filled there.
!zone
a8_stage_dl
	lda #<GAME_DL_STAGE
	sta ptr_l
	lda #>GAME_DL_STAGE
	sta ptr_h
	ldx #0
-	lda a8_game_dl,x
	jsr a8_dl_byte
	inx
	cpx #a8_game_dl_n
	bne -
	lda mouse_en
	beq .nom
	lda #$f0				; top blank + DLI
	sta GAME_DL_STAGE
	lda #$82				; nails + DLI
	sta GAME_DL_STAGE + 7
.nom
	lda #<BMP_A
	jsr a8_dl_byte
	lda #>BMP_A
	jsr a8_dl_byte
	ldx #0
.bmp
	lda mouse_en
	beq .be
	txa
	and #15
	cmp #15
	bne .be
	lda #$8e				; every 16th bitmap line
	bne .bw
.be
	lda #$0e
.bw
	jsr a8_dl_byte
	inx
	cpx #127
	bne .bmp
	lda #$41				; JVB
	jsr a8_dl_byte
	lda #0
	jsr a8_dl_byte
	jmp a8_dl_byte

a8_game_dl
	!byte $70				; 8 blanks (16 with dl_top)
	!byte $42				; mode 2 + LMS
	!word HUD_SCR				; title
	!byte $82				; map + DLI
	!byte $70				; 8 blanks
	!byte $02				; shells
	!byte $02				; nails
	!byte $82				; grenades + DLI
	!byte $70				; 8 blanks
	!byte $02				; message
	!byte $02				; seam
	!byte $80				; 1 blank + DLI
	!byte $4e				; mode E + LMS
a8_game_dl_n	= * - a8_game_dl
!if a8_game_dl_n != 14 {
	!error "game display-list head must stay 14 so DL_LMS is DL+14"
}

!zone
a8_quit
	jsr a8_menu_exit
	ldx #$ff
	txs
	jmp $e477

!zone
a8_wait_frame
	lda a8_vbi_n
.wf
	cmp a8_vbi_n
	beq .wf
	inc cursor_tick
	lda cursor_tick
	cmp #5
	bcc .wfr
	lda #0
	sta cursor_tick
	lda cursor_spr_en
	beq .adv
	jsr a8_cursor_erase
.adv
	inc cursor_frame
	lda cursor_frame
	cmp #CURSOR_FRAMES
	bcc .st
	lda #0
	sta cursor_frame
.st
	lda cursor_spr_en
	beq .wfr
	jsr a8_stamp_cursor
.wfr
	rts

!zone
a8_draw_hint
	ldx #HINT_ROW
	stx pr_row
	lda #TEXT_COL
	asl
	asl
	asl
	asl
	ora #HINT_BG				; orange bar, lighter text
	jsr a8_note_col
	lda #HINT_BG
	sta cell_bg
	lda #TEXT_COL
	sta ui_text_col
	ldx #HINT_ROW
	lda #<str_hint_a8
	ldy #>str_hint_a8
	jmp print_centered

!zone
a8_ui_read
	lda ui_keys
	sta ui_old
	lda #0
	sta ui_keys
	lda $d300
	eor #$ff
	and #$0f
	sta a8_gb
	and #1
	beq .nu
	lda #UI_UP
	jsr a8_ui_or
.nu
	lda a8_gb
	and #2
	beq .nd
	lda #UI_DOWN
	jsr a8_ui_or
.nd
	lda a8_gb
	and #4
	beq .nl
	lda #UI_LEFT
	jsr a8_ui_or
.nl
	lda a8_gb
	and #8
	beq .nr
	lda #UI_RIGHT
	jsr a8_ui_or
.nr
	lda $d010
	bne .nf
	lda #UI_SELECT
	jsr a8_ui_or
.nf
	lda $d20f
	and #$04
	bne .nk
	lda $d209
	and #$3f
	cmp #A8_KB_ESC
	bne .nk
	lda #UI_ESC
	jsr a8_ui_or
.nk
	lda ui_old
	eor #$ff
	and ui_keys
	sta ui_pressed
	rts

!zone
a8_ui_or
	ora ui_keys
	sta ui_keys
	rts

!zone
a8_wait_any
.wau
	jsr a8_wait_frame
	jsr a8_idle
	bcs .wau
	ldx #2
.was
	jsr a8_wait_frame
	jsr a8_idle
	bcs .wau
	dex
	bne .was
.wad
	jsr a8_wait_frame
	jsr a8_idle
	bcc .wad
.war
	jsr a8_wait_frame
	jsr a8_idle
	bcs .war
	rts

; C=1 while stick, fire, or a key is down.
!zone
a8_idle
	lda $d300
	and #$0f
	cmp #$0f
	bne .busy
	lda $d010
	beq .busy
	lda $d20f
	and #$04
	beq .busy
	clc
	rts
.busy
	sec
	rts

; A = character row (>= BRAND_KEEP_ROWS) → ptr = that mode-2 line.
!zone
a8_scr_row
	sec
	sbc #A8_TEXT0
	jsr a8_mul40
	clc
	lda ptr_l
	adc #<A8_SCR
	sta ptr_l
	lda ptr_h
	adc #>A8_SCR
	sta ptr_h
	rts

; 18*40 = 720 bytes.
!zone
a8_clear_text
	lda #<A8_SCR
	sta ptr_l
	lda #>A8_SCR
	sta ptr_h
	ldx #2
	jsr a8_zero_pages
	ldy #0
	lda #0
.ct
	sta (ptr_l),y
	iny
	cpy #248				; 19*40 - 512
	bne .ct
	rts

; 96 glyphs. Byte 0 is left blank: the row colour arrives one scanline
; into the cell, so the top ink has to start on line 1.
!zone
a8_load_font
	lda #<MENU_FONT
	sta ptr_l
	lda #>MENU_FONT
	sta ptr_h
	lda #<A8_FONT
	sta a8_sl
	lda #>A8_FONT
	sta a8_sh
	ldx #96
.g
	ldy #0
	lda #0
	sta (a8_sl),y
.b
	lda (ptr_l),y
	iny
	sta (a8_sl),y
	cpy #7
	bcc .b
	lda ptr_l
	clc
	adc #8
	sta ptr_l
	bcc .gs
	inc ptr_h
.gs
	lda a8_sl
	clc
	adc #8
	sta a8_sl
	bcc .gd
	inc a8_sh
.gd
	dex
	bne .g
	ldy #0
	lda #0
.z
	sta (a8_sl),y
	iny
	bne .z
	rts

; A = !scr byte. One cell on the mode-2 row. Notes the row colour.
!zone
a8_text_putc
	pha
	lda pr_setcol
	beq .nc
	lda ui_text_col
	asl
	asl
	asl
	asl
	ora cell_bg
	jsr a8_note_col
.nc
	pla
	jsr scr_to_font
	sta a8_gb
	lda pr_col
	cmp #40
	bcs .drop
	lda pr_row
	jsr a8_scr_row
	ldy pr_col
	lda a8_gb
	sta (ptr_l),y
	inc pr_col
.drop
	rts

; Character count * 8, so the existing centre / box math is in cells.
; Skips ^ markers. pr_len / pr_len_h.
!zone
a8_pix_len
	lda #0
	sta pr_len
	sta pr_len_h
	sta pr_mono
	ldy #0
.pl
	lda (ui_str_l),y
	beq .pd
	cmp #MARK_CARET
	beq .ps
	lda pr_len
	clc
	adc #8
	sta pr_len
	bcc .ps
	inc pr_len_h
.ps
	iny
	bne .pl
.pd
	rts

; Players are rewritten in the VBI, so a mid-frame erase does not shimmer.
!zone
a8_cursor_erase
	rts

; Per Q line: pick the table for the luminance PF1 has on that scanline
; (a row's first scanline still shows the previous row's colours), copy
; the player, plate and glyph bytes. Pixels go to the hardware in the VBI.
!zone
a8_stamp_cursor
	lda cursor_spr_en
	bne .on
	rts
.on
	lda #0
	sta a8_cur_dirty
	lda cursor_row
	asl
	asl
	asl
	sec
	sbc #6
	sta a8_cy
	lsr
	lsr
	lsr
	sta a8_crow0
	cmp a8_cur_orow
	bne .mv
	lda cursor_col
	cmp a8_cur_ocol
	beq .same				; codes already there; no blank frame
.mv
	jsr a8_cur_cells_off
.same
	ldx #71
	lda #0
.zg
	sta a8_cglyph,x
	dex
	bpl .zg
	ldx cursor_frame
	lda a8ct_plo,x
	sta .pa + 1
	sta .pb + 1
	sta .pc + 1
	lda a8ct_phi,x
	sta .pa + 2
	sta .pb + 2
	sta .pc + 2
	lda a8ct_glo,x
	sta .ga + 1
	sta .gb + 1
	sta .gc + 1
	lda a8ct_ghi,x
	sta .ga + 2
	sta .gb + 2
	sta .gc + 2
	lda a8ct_mlo,x
	sta .m + 1
	lda a8ct_mhi,x
	sta .m + 2
	ldx #0
.ln
	stx a8_gi
	txa
	clc
	adc a8_cy
	sta a8_py
	tay
	and #7
	bne .nl
	dey
.nl
	tya
	lsr
	lsr
	lsr
	tay
	lda a8_pf1,y
	and #$0f
	ldy #0
	cmp #6
	bcc .l0
	ldy #3
	cmp #$0d
	bcc .l0
	ldy #6
.l0
	sty a8_gb
	txa
	asl
	asl
	asl
	clc
	adc a8_gi
	adc a8_gb				; i*9 + lum*3
	tay
.pa	lda $ffff,y
	sta a8_pw0,x
.ga	lda $ffff,y
	sta a8_g0
	iny
.pb	lda $ffff,y
	sta a8_pw1,x
.gb	lda $ffff,y
	sta a8_g1
	iny
.pc	lda $ffff,y
	pha
	and #$f0
	sta a8_pg0,x
	pla
	asl
	asl
	asl
	asl
	sta a8_pg1,x
.gc	lda $ffff,y
	sta a8_g2
.m	lda $ffff,x
	sta a8_pmm,x
	lda a8_py
	lsr
	lsr
	lsr
	sec
	sbc a8_crow0
	tay
	lda a8_r24,y
	sta a8_gb
	lda a8_py
	and #7
	clc
	adc a8_gb
	tay
	lda a8_g0
	sta a8_cglyph,y
	lda a8_g1
	sta a8_cglyph + 8,y
	lda a8_g2
	sta a8_cglyph + 16,y
	ldx a8_gi
	inx
	cpx #21
	bcs .ld
	jmp .ln
.ld
	lda a8_crow0
	sta a8_cur_orow
	lda cursor_col
	sta a8_cur_ocol
	lda #A8_CUR_CH0
	jsr a8_cur_cells
	jsr a8_cursor_ypos
	lda cursor_col
	asl
	asl
	clc
	adc #48
	sta a8_cur_hx
	lda #1
	sta a8_cur_dirty
	rts

!zone
a8_cur_cells_off
	lda a8_cur_orow
	cmp #$ff
	beq .x
	lda #0
	jsr a8_cur_cells
	lda #$ff
	sta a8_cur_orow
.x
	rts

; A = first code, or 0 to clear. Writes the 3×3 cell block at
; a8_cur_orow/ocol, leaving any cell that holds real text alone.
!zone
a8_cur_cells
	sta a8_cur_code
	lda #0
	sta a8_cur_r
.r
	lda a8_cur_orow
	clc
	adc a8_cur_r
	cmp #A8_TEXT0
	bcc .nr
	cmp #A8_ROWS
	bcs .nr
	jsr a8_scr_row
	ldx #0
.c
	txa
	clc
	adc a8_cur_ocol
	cmp #40
	bcs .nr
	tay
	lda (ptr_l),y
	beq .w
	cmp #A8_CUR_CH0
	bcc .nc
	cmp #A8_CUR_CH0 + 9
	bcs .nc
.w
	lda a8_cur_code
	beq .st
	clc
	adc a8_cur_r
	adc a8_cur_r
	adc a8_cur_r
	stx a8_gb
	adc a8_gb
.st
	sta (ptr_l),y
.nc
	inx
	cpx #3
	bcc .c
.nr
	inc a8_cur_r
	lda a8_cur_r
	cmp #3
	bcc .r
	rts

; cursor_row*8 - 6 + 8, plus the 24 blank lines above the list.
!zone
a8_cursor_ypos
	lda cursor_row
	asl
	asl
	asl
	sec
	sbc #6
	clc
	adc #A8_PM_Y0
	clc
	adc #8
	sta a8_by
	rts

!zone
a8_cursor_vbi
	lda a8_cur_dirty
	bne .go
	rts
.go
	lda #0
	sta a8_cur_dirty
	lda a8_cur_oy
	cmp a8_by
	beq .put
	cmp #$ff
	beq .noy
	jsr a8_wipe_y
.noy
	lda a8_by
	sta a8_cur_oy
.put
	lda a8_cur_hx
	sta A8_HPOSP0
	sta A8_HPOSP0 + 1
	sta A8_HPOSM0
	clc
	adc #4
	sta A8_HPOSM0 + 1
	adc #4
	sta A8_HPOSP0 + 2
	sta A8_HPOSP0 + 3
	sta A8_HPOSM0 + 2
	lda #A8CUR_CA
	sta A8_COLPM0
	sta A8_COLPM0 + 2
	lda #A8CUR_CB
	sta A8_COLPM0 + 1
	sta A8_COLPM0 + 3
	ldy a8_by
	ldx #0
.c
	lda a8_pw0,x
	sta $bc00,y
	lda a8_pw1,x
	sta $bd00,y
	lda a8_pg0,x
	sta $be00,y
	lda a8_pg1,x
	sta $bf00,y
	lda a8_pmm,x
	sta $bb00,y
	iny
	inx
	cpx #21
	bcc .c
	ldx #71
.f
	lda a8_cglyph,x
	sta A8_CUR_FONT,x
	dex
	bpl .f
	rts

; A = player Y to clear on all four players and the plate.
!zone
a8_wipe_y
	tay
	ldx #21
	lda #0
.w
	sta $bb00,y
	sta $bc00,y
	sta $bd00,y
	sta $be00,y
	sta $bf00,y
	iny
	dex
	bne .w
	rts

; Menu music (a8music.asm). Raster off / done silence POKEY before the game.
!zone
menu_sfx_init
	jmp a8_music_start
!zone
menu_raster_off
	jmp a8_music_stop
!zone
menu_sfx_done
	jmp a8_music_stop

!zone
str_hint_a8	!scr "QuakeA8 by Steve McCrea 2026",0

!zone
!source "a8_cursor_tab.asm"
!source "a8hue.asm"
