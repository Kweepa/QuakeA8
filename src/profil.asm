; Frame timer. VBI ticks in a8irq; PROFILE=1 adds R/P/K/D buckets.
!zone profil

!if  PROFILE = 1 {
NV_ROT		= 0
NV_PROJ		= 2
NV_CLIP		= 4
}


; ticks*17. PAL prof_init overwrites dt_add with jmp dt_pal_x4 (the *4
; that turns it into *20) and dt_one+1 with 20. NTSC never patches, so
; the bytes through the rts stay the *17 sequence.

prof_init
	lda #0
	sta vbi_count_l
	sta vbi_count_h
	sta vbi_last_l
	sta vbi_last_h
	sta frame_cy
	sta frame_cy + 1
	sta frame_cy + 2
	sta frame_cy + 3
	lda sample_ms
	sta dt_ms
	lda #0
	sta dt_msh
	lda sample_ms
	cmp #SAMPLE_MS_PAL
	bne .pi_rts
	lda #$4c				; jmp dt_pal_x4 over clc / lda dt_ms
	sta dt_add
	lda #<dt_pal_x4
	sta dt_add + 1
	lda #>dt_pal_x4
	sta dt_add + 2
	lda #SAMPLE_MS_PAL
	sta dt_one + 1
!if  PROFILE = 1 {
	lda #$f0				; 35568
	sta prof_ld_clo + 1
	lda #$8a
	sta prof_ld_chi + 1
	lda #32					; VCOUNT 124..155 before wrap
	sta prof_adc_wrap + 1
}
.pi_rts
	rts

; VBI ticks since the last sample, times sample_ms. 0 ticks → one frame.
calc_frame_dt
	sec
	lda vbi_count_l
	sbc vbi_last_l
	sta dt_ms
	lda vbi_count_h
	sbc vbi_last_h
	sta dt_msh
	lda vbi_count_l
	sta vbi_last_l
	lda vbi_count_h
	sta vbi_last_h
	lda dt_ms
	ora dt_msh
	bne .pscale
dt_one
	lda #SAMPLE_MS_NTSC			; PAL init stores 20 here
	sta dt_ms
	lda #0
	sta dt_msh
	rts
.pscale
	lda dt_ms
	sta dt_mul_l
	lda dt_msh
	sta dt_mul_h
	asl dt_mul_l
	rol dt_mul_h
	asl dt_mul_l
	rol dt_mul_h
	asl dt_mul_l
	rol dt_mul_h
	asl dt_mul_l
	rol dt_mul_h
dt_add
	clc					; PAL init: jmp dt_pal_x4 (3 bytes, with lda)
	lda dt_ms
dt_add_end
	adc dt_mul_l
	sta dt_ms
	lda dt_msh
	adc dt_mul_h
	sta dt_msh
	rts
!if (dt_add_end - dt_add) != 3 {
	!error "PAL jmp site is not 3 bytes"
}

; ticks*4, then the same add as dt_add. Reached only by the PAL jmp.
dt_pal_x4
	asl dt_ms
	rol dt_msh
	asl dt_ms
	rol dt_msh
	clc
	lda dt_ms
	adc dt_mul_l
	sta dt_ms
	lda dt_msh
	adc dt_mul_h
	sta dt_msh
	rts

prof_frame_sample
	rts

!if  PROFILE = 1 {
; VBI is scanline 248 (VCOUNT 124) on both. Clock counts up in CPU cycles:
; vbi_count * 29868 (PAL init patches 35568) + (VCOUNT steps since 124) * 228.
; Buckets store cycles * 146/256, which the shared >>10 HUD reads as milliseconds.
prof_reset_frame
	ldx #PROF_NBUCKET * 4 - 1
	lda #0
-
	sta prof_cy,x
	dex
	bpl -
	sta nv_rot
	sta nv_rot + 1
	sta nv_proj
	sta nv_proj + 1
	sta nv_clip
	sta nv_clip + 1
	lda #$ff
	sta mesh_vmask
	jmp prof_snap

prof_snap
	jsr prof_read_casc
	lda casc_now
	sta casc_snap
	lda casc_now + 1
	sta casc_snap + 1
	lda casc_now + 2
	sta casc_snap + 2
	lda casc_now + 3
	sta casc_snap + 3
	rts

prof_read_casc
.retry
	lda vbi_count_h
	sta prof_vbh
	lda vbi_count_l
	sta prof_vbl
	lda $d40b
	ldx vbi_count_h
	cpx prof_vbh
	bne .retry
	ldx vbi_count_l
	cpx prof_vbl
	bne .retry
	cmp #124
	bcs .at
	clc
prof_adc_wrap
	adc #7					; PAL init: 32 (VCOUNT runs to 155)
	bcc .got
.at
	sec
	sbc #124
.got
	sta prof_vc
	jsr prof_intra
	jsr prof_vmul
	clc
	lda casc_now
	adc prof_wrk
	sta casc_now
	lda casc_now + 1
	adc prof_wrk + 1
	sta casc_now + 1
	lda casc_now + 2
	adc #0
	sta casc_now + 2
	lda casc_now + 3
	adc #0
	sta casc_now + 3
	rts

; prof_vc → prof_wrk = *228 (two scanlines per VCOUNT step).
prof_intra
	lda prof_vc
	sta prof_wrk
	lda #0
	sta prof_wrk + 1
	asl prof_wrk
	rol prof_wrk + 1
	asl prof_wrk
	rol prof_wrk + 1
	lda prof_wrk
	sta prof_sh
	lda prof_wrk + 1
	sta prof_sh + 1
	asl prof_wrk
	rol prof_wrk + 1
	clc
	lda prof_sh
	adc prof_wrk
	sta prof_sh
	lda prof_sh + 1
	adc prof_wrk + 1
	sta prof_sh + 1
	asl prof_wrk
	rol prof_wrk + 1
	clc
	lda prof_sh
	adc prof_wrk
	sta prof_sh
	lda prof_sh + 1
	adc prof_wrk + 1
	sta prof_sh + 1
	lda #0
	sta prof_wrk
	lda prof_vc
	sta prof_wrk + 1
	sec
	lda prof_wrk
	sbc prof_sh
	sta prof_wrk
	lda prof_wrk + 1
	sbc prof_sh + 1
	sta prof_wrk + 1
	lda #0
	sta prof_wrk + 2
	sta prof_wrk + 3
	rts

; casc_now = prof_vbl:prof_vbh * 29868. PAL init patches the immediates to 35568.
prof_vmul
	lda prof_vbl
	sta prof_sh
	lda prof_vbh
	sta prof_sh + 1
	lda #0
	sta prof_sh + 2
	sta prof_sh + 3
	sta casc_now
	sta casc_now + 1
	sta casc_now + 2
	sta casc_now + 3
prof_ld_clo
	lda #$ac
	sta prof_mlo
prof_ld_chi
	lda #$74
	sta prof_mhi
	ldx #16
.mlp
	lsr prof_mhi
	ror prof_mlo
	bcc .no
	clc
	lda casc_now
	adc prof_sh
	sta casc_now
	lda casc_now + 1
	adc prof_sh + 1
	sta casc_now + 1
	lda casc_now + 2
	adc prof_sh + 2
	sta casc_now + 2
	lda casc_now + 3
	adc prof_sh + 3
	sta casc_now + 3
.no
	asl prof_sh
	rol prof_sh + 1
	rol prof_sh + 2
	rol prof_sh + 3
	dex
	bne .mlp
	rts

; X = NV_ROT / NV_PROJ / NV_CLIP. Add mesh_nwork into that counter.
prof_add_nv
	clc
	lda nv_cnt,x
	adc mesh_nwork
	sta nv_cnt,x
	lda nv_cnt + 1,x
	adc #0
	sta nv_cnt + 1,x
	rts

; Y = bucket. Add (now − snap), scaled to the C64 millisecond shift.
prof_add_bucket
	jsr prof_read_casc
	sec
	lda casc_now
	sbc casc_snap
	sta prof_dt
	lda casc_now + 1
	sbc casc_snap + 1
	sta prof_dt + 1
	lda casc_now + 2
	sbc casc_snap + 2
	sta prof_dt + 2
	lda casc_now + 3
	sbc casc_snap + 3
	sta prof_dt + 3
	lda casc_now
	sta casc_snap
	lda casc_now + 1
	sta casc_snap + 1
	lda casc_now + 2
	sta casc_snap + 2
	lda casc_now + 3
	sta casc_snap + 3
	jsr prof_to_ms
	tya
	asl
	asl
	tax
	clc
	lda prof_cy,x
	adc prof_dt
	sta prof_cy,x
	lda prof_cy + 1,x
	adc prof_dt + 1
	sta prof_cy + 1,x
	lda prof_cy + 2,x
	adc prof_dt + 2
	sta prof_cy + 2,x
	lda prof_cy + 3,x
	adc prof_dt + 3
	sta prof_cy + 3,x
	rts

; prof_dt = prof_dt * 146 / 256. Preserves Y.
prof_to_ms
	ldx #3
-
	lda prof_dt,x
	sta casc_now,x
	dex
	bpl -
	lda #0
	sta prof_sh
	sta prof_sh + 1
	sta prof_sh + 2
	sta prof_sh + 3
	ldx #1
	jsr prof_shr_add
	ldx #4
	jsr prof_shr_add
	ldx #7
	jsr prof_shr_add
	ldx #3
-
	lda prof_sh,x
	sta prof_dt,x
	dex
	bpl -
	rts

prof_shr_add
	lda casc_now
	sta prof_wrk
	lda casc_now + 1
	sta prof_wrk + 1
	lda casc_now + 2
	sta prof_wrk + 2
	lda casc_now + 3
	sta prof_wrk + 3
-
	lsr prof_wrk + 3
	ror prof_wrk + 2
	ror prof_wrk + 1
	ror prof_wrk
	dex
	bne -
	clc
	lda prof_sh
	adc prof_wrk
	sta prof_sh
	lda prof_sh + 1
	adc prof_wrk + 1
	sta prof_sh + 1
	lda prof_sh + 2
	adc prof_wrk + 2
	sta prof_sh + 2
	lda prof_sh + 3
	adc prof_wrk + 3
	sta prof_sh + 3
	rts

prof_vbl	!byte 0
prof_vbh	!byte 0
prof_vc		!byte 0
prof_mlo	!byte 0
prof_mhi	!byte 0
prof_wrk	!fill 4, 0
prof_sh		!fill 4, 0
}

dt_mul_l	!byte 0
dt_mul_h	!byte 0


!if  PROFILE = 0 {
prof_add_bucket
	rts
}

