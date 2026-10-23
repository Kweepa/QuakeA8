; A = GTIA byte written for NTSC. PAL: high nibble through a8_pal_hue
; (menu wrote it at $06D5). NTSC (video_ms ≠ 20) returns A unchanged.
; Clobbers Y. Not for the seam DLI — init patches those immediates once.
!zone a8hue
a8_to_pal
	ldy video_ms
	cpy #SAMPLE_MS_PAL
	bne .keep
	pha
	and #$0f
	sta a8_hue_lo
	pla
	lsr
	lsr
	lsr
	lsr
	tay
	lda a8_pal_hue,y
	ora a8_hue_lo
.keep
	rts
