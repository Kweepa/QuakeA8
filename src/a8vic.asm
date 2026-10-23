; ANTIC display: 9 rows of 40-col text, then a narrow mode-E window.
; Mode E is 128 colour-clock pixels, 2 bits each, 32 bytes/line. The game
; still projects 192 hires columns; the plotter keeps every other one, so
; the drawn 96 pixels (24 bytes) sit in the middle. The 4 zero bytes on
; each side are COLBK, so the gutters are black with no player DMA.
!zone a8vic

DL		= $0368
TEXT_ROWS	= 9
BMP_STRIDE	= 32
BMP_MARGIN	= 4
BMP_DRAW_W	= 24

bmp_lo		!byte 0
bmp_hi		!byte 0
a8_show_lo	!byte <BMP_A
a8_show_hi	!byte >BMP_A

init_vic
	lda #$fe
	sta $d301				; bit 0 clear: high RAM is RAM
	lda #0
	sta draw_buf
	sta show_buf
	sta $d01d				; GRACTL: no players
	lda #$22				; normal playfield, no players
	sta $d400
	lda #0
	sta $d01b				; PRIOR
	lda #$00
	sta $d01a				; COLBK
	lda #$00
	sta $d018				; COLPF2 HUD background
	lda #$0e
	sta $d017				; COLPF1 HUD luminance
	jsr a8_build_dl
	lda #<dl_top
	sta $d402
	lda #>dl_top
	sta $d403
	lda #$f8				; charset at $F800
	sta $d409
	jsr set_draw_ptrs
	jsr a8_init_margin		; bytes 0–3 and 28–31, once per buffer
	jsr clear_draw			; buffer A, before the first show
	lda #1
	sta draw_buf
	jsr set_draw_ptrs
	jsr a8_init_margin
	jsr clear_draw			; buffer B ($E000, one 4K block)
	lda #0
	sta draw_buf
	jmp set_draw_ptrs

; +8 blank lines ahead of the 8 in the list. The picture is 201 lines
; (72 text + 1 seam + 128 bitmap) and NTSC runs the list across 240
; (scanlines 8-247), so this is 16 above and 23 below. Kept out of DL:
; that list is packed through $03F9.
dl_top	!byte $70				; 8
	!byte $01				; JMP
	!word DL
!if (dl_top & $03ff) > $03fc {
	!error "dl_top crosses a 1K boundary"
}

a8_build_dl
	lda #0
	ldx mouse_en
	beq .seam
	lda #5					; top blank + 4 HUD-row DLIs, then the seam
.seam
	sta dli_seam
	lda #<DL
	sta dst_ptr
	lda #>DL
	sta dst_ptr+1
	ldy #0
	lda #$70				; 8 blank lines (16 with dl_top)
	ldx mouse_en
	beq .tb
	lda #$f0				; + DLI: mouse sample ahead of the HUD
.tb
	jsr a8_dl_byte
	lda #$42				; mode 2 + LMS
	jsr a8_dl_byte
	lda #<HUD_SCR
	jsr a8_dl_byte
	lda #>HUD_SCR
	jsr a8_dl_byte
	ldx #8
.hud
	ldy mouse_en
	beq .hudp
	txa
	and #1					; DLI on every other row (X = 8,6,4,2). None
	bne .hudp				; on the last row: it would still be running
	lda #$82				; at the seam DLI
	bne .hudw
.hudp
	lda #$02
.hudw
	ldy #0					; a8_dl_byte stores (dst_ptr),y
	jsr a8_dl_byte
	dex
	bne .hud
	lda #$80				; 1 blank + DLI (switch to narrow bitmap)
	jsr a8_dl_byte
	lda #$4e				; mode E + LMS
	jsr a8_dl_byte
	lda a8_show_lo
	jsr a8_dl_byte
	lda a8_show_hi
	jsr a8_dl_byte
	ldx #0
.bmp
	lda mouse_en
	beq .bmpe
	txa
	and #15
	cmp #15
	bne .bmpe
	lda #$8e				; every 16th bitmap line
	bne .bmpw
.bmpe
	lda #$0e
.bmpw
	jsr a8_dl_byte
	inx
	cpx #127
	bne .bmp
	lda #$41				; JVB
	jsr a8_dl_byte
	lda #<dl_top
	jsr a8_dl_byte
	lda #>dl_top
	jsr a8_dl_byte
	rts

a8_dl_byte
	sta (dst_ptr),y
	inc dst_ptr
	bne +
	inc dst_ptr+1
+
	rts

; LMS of the bitmap sits 1+3+8+1+1 = 14 bytes into the list.
DL_LMS		= DL + 14

set_draw_ptrs
	lda draw_buf
	bne .b
	lda #<BMP_A
	ldx #>BMP_A
	bne .st
.b
	lda #<BMP_B
	ldx #>BMP_B
.st
	sta bmp_lo
	stx bmp_hi
	rts

; show_buf is the publish. The VBI copies it into DL_LMS during vblank.
apply_show
	lda show_buf
	bne .sb
	lda #<BMP_A
	ldx #>BMP_A
	bne .sp
.sb
	lda #<BMP_B
	ldx #>BMP_B
.sp
	sta a8_show_lo
	stx a8_show_hi
	lda frame_flag
	sta pub_ff
	rts

wait_draw_free
-
	lda frame_flag
	cmp pub_ff
	beq -
	rts

; Gutters are COLBK. Zero them once per buffer; the plotter and the
; weapon blit only address bytes 4..27, so a frame clear must not touch them.
a8_init_margin
	lda #0
	sta dst_ptr
	lda bmp_hi
	sta dst_ptr+1
	ldx #128
.mg0
	ldy #0
	lda #0
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	ldy #BMP_MARGIN+BMP_DRAW_W
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	iny
	sta (dst_ptr),y
	clc
	lda dst_ptr
	adc #BMP_STRIDE
	sta dst_ptr
	bcc .mg1
	inc dst_ptr+1
.mg1
	dex
	bne .mg0
	rts

; One 4K block per buffer, 128 rows of 32. A page is eight rows, and each
; row's centre is a 24-byte X range on sta page,x. Sixteen sta per pass,
; eight passes, two copies so the high bytes stay immediate.
a8_clear_x
	!byte 4,36,68,100,132,164,196,228
a8_clear_end
	!byte 28,60,92,124,156,188,220,252
a8_clear_lim
	!byte 0

!macro a8_clear_pages .base {
	!for .page, 0, 15 {
		sta .base + .page * $100, x
	}
}

clear_draw
	lda bmp_hi
	cmp #>BMP_B
	bne clear_a
	jmp clear_b
clear_a
	ldy #0
.ca
	ldx a8_clear_x,y
	lda a8_clear_end,y
	sta a8_clear_lim
	lda #$55
.ca_x
	+a8_clear_pages BMP_A
	inx
	cpx a8_clear_lim
	bne .ca_x
	iny
	cpy #8
	bne .ca
	rts
clear_b
	ldy #0
.cb
	ldx a8_clear_x,y
	lda a8_clear_end,y
	sta a8_clear_lim
	lda #$55
.cb_x
	+a8_clear_pages BMP_B
	inx
	cpx a8_clear_lim
	bne .cb_x
	iny
	cpy #8
	bne .cb
	rts

clear_charsets
fill_margin_glyph
fill_colour
fill_viewport_colour
	rts

; room_idx → col_bg (Atari paper byte, made by the editor). The DLI publishes it.
apply_room_palette
	ldx room_idx
	+lda_mx room_bg
	jsr a8_to_pal
	sta col_bg
	lda #1
	sta palette_dirty
	lda room_idx
	sta palette_room
	rts

maybe_room_palette
	lda room_idx
	cmp palette_room
	beq .mrpdone
	jsr apply_room_palette
.mrpdone
	rts

!source "a8hue.asm"
