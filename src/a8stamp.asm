; Body cells are inverted (ink %00, clear %11) and ANDed, so the gun is black.
; Player flashes are ink %11. Phase 1 ORs line colour; phase 2 writes
; pixel %10 (COLPF1). The enemy muzzle and the splats are mode-E rows,
; snapped to a byte: three stores per row. Muzzle always writes %10.
!zone a8stamp

stamp_x		!byte 0
stamp_xh	!byte 0
stamp_y		!byte 0
stamp_yb	!byte 0
stamp_slot	!byte 0
stamp_en	!byte 0
stamp_base	!byte 0
stamp_w		!byte 0
stamp_h		!byte 0
stamp_xb	!byte 0
stamp_and	!byte 0			; 1 = AND the plane (black body)
stamp_red	!byte 0			; 1 = flash fade, pixel %10
stamp_bl	!byte 0			; splat byte column, signed
stamp_bh	!byte 0
stamp_tmp	!byte 0

stamp_view
	lda wpn_x
	sec
	sbc #VIEW_SPR_X0
	lsr
	lsr
	lsr
	sta stamp_base
	ldx cur_weapon
	lda wpn_fr_base,x
	cpx #WPN_NAIL
	bne .body
	clc
	adc wpn_fr
.body
	tax
	lda wpn_fr_lo,x
	sta init_ptr
	lda wpn_fr_hi,x
	sta init_ptr+1
	lda #1
	sta stamp_and
	lda #0
	sta stamp_red
	jsr blit_list
	lda #0
	sta stamp_and

	lda flash_phase
	beq .no4
	ldx cur_weapon
	lda wpn_fl4_lo,x
	sta init_ptr
	lda wpn_fl4_hi,x
	sta init_ptr+1
	lda flash_phase
	jsr stamp_flash
.no4
	lda flash5_phase
	beq .no5
	lda #<spr_nail_fr_b
	sta init_ptr
	lda #>spr_nail_fr_b
	sta init_ptr+1
	lda flash5_phase
	jsr stamp_flash
.no5
	lda emuz_on
	beq .noe
	lda emuz_vx
	ldx emuz_xmsb
	jsr stamp_set_xmsb
	lda emuz_vy
	jsr stamp_set_y
	jsr stamp_emuz
.noe
	lda splat_on
	beq .nos
	lda splat_vx
	ldx splat_xmsb
	jsr stamp_set_xmsb
	lda splat_vy
	jsr stamp_set_y
	jsr stamp_splat
.nos
	rts

; init_ptr set. A is the phase (1 = line colour, 2 = red). X is absolute.
stamp_flash
	ldx #0
	cmp #2
	bne .yel
	inx
.yel
	stx stamp_red
	lda #0
	sta stamp_base
	jmp blit_list

; init_ptr = cell list (count, then x_byte, y, width, height, image).
; stamp_base is added to each x_byte. Rows stop at y = 128.
blit_list
	ldy #0
	lda (init_ptr),y
	bne .go
	rts
.go
	sta stamp_slot
	inc init_ptr
	bne .cell
	inc init_ptr+1
.cell
	ldy #0
	lda (init_ptr),y
	clc
	adc stamp_base
	sta stamp_xb
	iny
	lda (init_ptr),y
	sta stamp_yb
	iny
	lda (init_ptr),y
	sta stamp_w
	iny
	lda (init_ptr),y
	sta stamp_h
	clc
	lda init_ptr
	adc #4
	sta init_ptr
	sta src_ptr
	lda init_ptr+1
	adc #0
	sta init_ptr+1
	sta src_ptr+1
	lda wpn_y
	sec
	sbc #VIEW_SPR_Y0
	clc
	adc stamp_yb
	sta stamp_y
.bl_row
	lda stamp_y
	cmp #128
	bcs .adv
	jsr blit_row
.adv
	clc
	lda src_ptr
	adc stamp_w
	sta src_ptr
	bcc +
	inc src_ptr+1
+
	inc stamp_y
	dec stamp_h
	bne .bl_row
	lda src_ptr
	sta init_ptr
	lda src_ptr+1
	sta init_ptr+1
	dec stamp_slot
	beq .bl_done
	jmp .cell
.bl_done
	rts

blit_row
	lda #0
	sta dst_ptr+1
	lda stamp_y
	sta dst_ptr
	ldx #5
-
	asl dst_ptr
	rol dst_ptr+1
	dex
	bne -
	clc
	lda dst_ptr
	adc #BMP_MARGIN
	adc stamp_xb
	sta dst_ptr
	lda dst_ptr+1
	adc #0
	adc bmp_hi
	sta dst_ptr+1
	ldy #0
.b
	lda stamp_and
	bne .and
	lda stamp_red
	bne .red
	lda (dst_ptr),y
	ora (src_ptr),y
	jmp .st
.red
	lda (src_ptr),y
	sta stamp_tmp
	and #$55
	pha
	lda (dst_ptr),y
	ora stamp_tmp
	sta stamp_tmp
	pla
	eor stamp_tmp
	jmp .st
.and
	lda (dst_ptr),y
	and (src_ptr),y
.st
	sta (dst_ptr),y
	iny
	cpy stamp_w
	bne .b
	rts

; A = VIC x, X = msb flag (nonzero → +256)
stamp_set_xmsb
	sec
	sbc #VIEW_SPR_X0
	sta stamp_x
	lda #0
	sbc #0
	cpx #1
	bcc .nm
	clc
	adc #1
.nm
	sta stamp_xh
	rts

; A = VIC y
stamp_set_y
	sec
	sbc #VIEW_SPR_Y0
	sta stamp_y
	rts

; Mode-E muzzle. emuz_src is 21×3, phase 0. Always pixel %10.
stamp_emuz
	lda emuz_src
	sta src_ptr
	lda emuz_src+1
	sta src_ptr+1
	lda #1
	sta stamp_en
	jmp stamp_place

; Mode-E splat. splat_src is 21 rows of 3 bytes, phase 0.
; Hit: V = (P OR V) EOR ($55 AND P) → pixel %10 (COLPF1). Miss: V = V OR P.
stamp_splat
	lda splat_src
	sta src_ptr
	lda splat_src+1
	sta src_ptr+1
	lda #0
	sta stamp_en
	lda splat_col
	cmp #COL_SPLAT_HIT
	bne stamp_place
	inc stamp_en

; src_ptr and stamp_en are set. Snap to a byte, clamp the 3×21 inside
; the viewport, then store three bytes per row with no edge test.
stamp_place
	clc
	lda stamp_x
	adc #4
	sta stamp_bl
	lda stamp_xh
	adc #0
	sta stamp_bh
	ldx #3
-
	lda stamp_bh
	cmp #$80
	ror stamp_bh
	ror stamp_bl			; signed (hires+4)>>3, nearest byte
	dex
	bne -
	lda stamp_bh
	bmi .xlo
	bne .xhi
	lda stamp_bl
	cmp #BMP_DRAW_W-2		; 3 bytes must end by column 23
	bcc .yfix
.xhi
	lda #BMP_DRAW_W-3
	sta stamp_bl
	jmp .yfix
.xlo
	lda #0
	sta stamp_bl
.yfix
	lda stamp_y
	bpl .ypos
	lda #0
	sta stamp_y
	beq .arm
.ypos
	cmp #128-20
	bcc .arm
	lda #128-21
	sta stamp_y
.arm
	lda #21
	sta stamp_h
.srow
	jsr stamp_splat_row
	clc
	lda src_ptr
	adc #3
	sta src_ptr
	bcc +
	inc src_ptr+1
+
	inc stamp_y
	dec stamp_h
	bne .srow
	rts

stamp_splat_row
	lda #0
	sta dst_ptr+1
	lda stamp_y
	sta dst_ptr
	ldx #5
-
	asl dst_ptr
	rol dst_ptr+1
	dex
	bne -
	clc
	lda dst_ptr
	adc #BMP_MARGIN
	sta dst_ptr
	lda dst_ptr+1
	adc #0
	adc bmp_hi
	sta dst_ptr+1
	ldx #0
.spx
	txa
	tay
	lda (src_ptr),y
	sta stamp_tmp
	txa
	clc
	adc stamp_bl
	tay
	lda stamp_en
	beq .sora
	lda stamp_tmp
	and #$55
	sta stamp_xb
	lda (dst_ptr),y
	ora stamp_tmp
	eor stamp_xb
	jmp .sput
.sora
	lda (dst_ptr),y
	ora stamp_tmp
.sput
	sta (dst_ptr),y
.snx
	inx
	cpx #3
	bne .spx
	rts
