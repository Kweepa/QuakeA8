; Copy the staged tab.prg payload from TAB_STAGE into the high-RAM LUTs.
; File order: alog 512, log 256, sin 320, invzl 128, invzh 128.
; Boot has already skipped the 2-byte CBM header.
!zone a8tabs

a8_bind_tabs
	lda #<TAB_STAGE
	sta src_ptr
	lda #>TAB_STAGE
	sta src_ptr+1
	lda #<ALOGTAB
	ldy #>ALOGTAB
	ldx #1
	jsr a8_copy_pages
	lda #<ALOGHI
	ldy #>ALOGHI
	ldx #1
	jsr a8_copy_pages
	lda #<LOGTAB
	ldy #>LOGTAB
	ldx #1
	jsr a8_copy_pages
	lda #<SINTAB
	ldy #>SINTAB
	ldx #1
	jsr a8_copy_pages
	lda #<$fd00			; rest of sin, then invzl, then invzh
	ldy #>$fd00
	ldx #1
	jsr a8_copy_pages
	ldy #64
	jsr a8_copy_tail
	lda effects_vol
	bne +
	lda #$0f
	sta effects_vol
+
	rts

; A/Y = dest. X = full pages. src_ptr advances.
a8_copy_pages
	sta dst_ptr
	sty dst_ptr+1
.pg
	ldy #0
-
	lda (src_ptr),y
	sta (dst_ptr),y
	iny
	bne -
	inc src_ptr+1
	inc dst_ptr+1
	dex
	bne .pg
	rts

; Y = extra bytes. dst_ptr is the page a8_copy_pages just finished.
a8_copy_tail
	sty a8_tail_n
	ldy #0
-
	lda (src_ptr),y
	sta (dst_ptr),y
	iny
	cpy a8_tail_n
	bne -
	rts

a8_tail_n	!byte 0
