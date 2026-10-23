; Mode-E stroke. Callers pass hires x 0..191. draw_line halves both ends,
; then an unrolled body walks colour-clock pixels (0..95). y stays 0..127.
; plot_pixel is the particle dots. The muzzle stores mode-E bytes.
!zone line

BMP_STRIDE	= 32
BMP_MARGIN	= 4

line_tab_init
	rts

; x0,y0. Clips. Y ends 0.
plot_pixel
	lda y0
	cmp #128
	bcs .pp_rts
	lda x0
	cmp #96
	bcs .pp_rts
	jsr a8_addr
	lda x0
	and #3
	tax
	ldy #0
	lda (colptr),y
	ora a8_pair,x
	sta (colptr),y
.pp_rts
	rts

; Pixel 11 (COLPF2). MSB first, four pixels per byte.
a8_pair
	!byte $c0,$30,$0c,$03

; colptr = bmp + y*32 + 4 + (x>>2). x is a colour-clock pixel. Uses x0,y0.
; BMP_A/BMP_B are page aligned on a 4K boundary: bmp_lo is 0 and bmp_hi's low
; nibble is 0. Low byte (y&7)<<5 + x>>2 + 4 <= 251, so no carry; hi = y>>3 | bmp_hi.
a8_addr
	lda y0
	asl
	asl
	asl
	asl
	asl
	sta colptr
	lda x0
	lsr
	lsr
	clc
	adc colptr
	adc #BMP_MARGIN
	sta colptr
	lda y0
	lsr
	lsr
	lsr
	ora bmp_hi
	sta colptr+1
	rts

draw_line
	lsr x0
	lsr x1
	lda x0
	cmp x1
	bcc .ord
	beq .ord
	ldx x1
	sta x1
	stx x0
	lda y0
	ldx y1
	sta y1
	stx y0
.ord
	lda x1
	sec
	sbc x0
	sta dx
	lda y1
	sec
	sbc y0
	bcs .ydn
	eor #$ff
	clc
	adc #1
	ldx #$ff
	bne .yst
.ydn
	ldx #1
.yst
	sta dy
	stx sy
	lda dx
	ora dy
	bne .draw
	jmp plot_pixel
.draw
	jsr a8_addr
	ldy #0
	lda x0
	and #3
	tax
	lda dx
	cmp dy
	bcc .steep

	lda dx
	lsr
	sta err_l
	lda sy
	bmi .xu
	lda esdn_l,x
	sta .jd+1
	lda esdn_h,x
	sta .jd+2
	ldx dx
	inx
	sec
.jd	jmp esd0
.xu
	lda esup_l,x
	sta .ju+1
	lda esup_h,x
	sta .ju+2
	ldx dx
	inx
	sec
.ju	jmp esu0

.steep
	lda dy
	lsr
	sta err_l
	lda sy
	bmi .yu
	lda etdn_l,x
	sta .js+1
	lda etdn_h,x
	sta .js+2
	ldx dy
	inx
	sec
.js	jmp etd0
.yu
	lda etup_l,x
	sta .jt+1
	lda etup_h,x
	sta .jt+2
	ldx dy
	inx
	sec
.jt	jmp etu0

!source "_a8line_bodies.asm"
