; VBI + DLI. Joystick in port 1, Pro-Line button 2 (POT0 / pin 9) strafes.
; ST mouse in port 2 (Options): X turns, left button fires, stick left/right strafes.
; Keys 1-4 select weapons. Start is use.
!zone a8irq

; Hue 4, lum 0. Blood is COLPF1 $46, so the splat stays brighter than the flash.
COL_HURT_A8	= $40

pot_prev	!byte $e0
stick_bits	!byte 0
dli_phase	!byte 0
dli_paper	!byte 0				; seam colours, set by the VBI
dli_ink		!byte 0
m_snap		!byte 0				; read_input copy of mouse_turn
m_snap_h	!byte 0
m_base		!byte 0				; mouse_turn already consumed
m_base_h	!byte 0
m_end		!byte 0				; mouse_turn as read this frame
m_end_h		!byte 0
MOUSE_FAST	= 8				; empty samples before fast decode times out
SEAM_VC		= 48				; VCOUNT of the blank-line DLI (scanline 96)
vbi_count_l	!byte 0
vbi_count_h	!byte 0
vbi_last_l	!byte 0
vbi_last_h	!byte 0

nmi_rti
	rti

install_irq_vectors
	lda #<a8_nmi
	sta $fffa
	lda #>a8_nmi
	sta $fffb
	lda #<nmi_rti
	sta $fffe
	lda #>nmi_rti
	sta $ffff
	rts

init_irq
	jsr install_irq_vectors
	lda #0
	sta irq_phase
	sta frame_flag
	sta turn_acc_l
	sta turn_acc_h
	sta wish_dx
	sta wish_dxh
	sta wish_dz
	sta wish_dzh
	sta sfx_q_len
	sta in_qsave
	sta in_qload
	sta spd_trip
	ldx #11
-
	sta in_fwd,x
	dex
	bpl -
	lda video_ms				; menu wrote 20 or 17; anything else is NTSC
	cmp #SAMPLE_MS_PAL
	beq +
	lda #SAMPLE_MS_NTSC
+
	sta sample_ms
	sta sample_ms_chk
	lda #$e0
	sta pot_prev
	lda #0
	sta vbi_count_l
	sta vbi_count_h
	sta vbi_last_l
	sta vbi_last_h
	sta pub_ff
	lda #0
	sta $d208				; AUDCTL: 64 kHz, no filters
	lda #$03
	sta $d20f				; SKCTL: keys + pot scan
	sta $d20b				; POTGO
	lda #0
	sta $d20e				; IRQEN off — vector is $00FF until we own it
	sta $d40e				; NMI off while the quadrature baseline is cleared
	lda $d300				; baseline: current pins 1-2 of port 2
	lsr
	lsr
	lsr
	lsr
	and #$03
	sta mouse_x
	lda #0
	sta mouse_turn
	sta mouse_turn_h
	sta m_base
	sta m_base_h
	sta mouse_rem
	sta mouse_v
	sta mouse_f
	sta dli_phase
	lda #$46
	jsr a8_to_pal
	sta dli_blood+1
	lda #COL_HURT_A8
	jsr a8_to_pal
	sta hurt_col+1
	lda #$c0				; VBI + DLI
	sta $d40e
	rts

a8_nmi_on
	lda #$c0
	sta $d40e
	cli
	rts

a8_nmi
	pha
	; Seam DLI fast path. WSYNC must be hit before cycle ~104 of the blank
	; line or it releases a scanline late, the first bitmap line is fetched
	; at normal width and the whole bitmap shifts 8 bytes. Only A is saved
	; before WSYNC; DMACTL is the first store after it.
	lda $d40f
	and #$c0
	cmp #$80				; DLI only
	bne .nm_slow
	; Phases: mouse off stat/msg/seam = 0/1/2, mouse on = 1/3/4.
	lda mouse_en
	beq .nm_off
	lda dli_phase
	cmp #4
	beq .nm_seam
	lda $d40b
	cmp #SEAM_VC
	beq .nm_seam
	jmp .nm_rest_on
.nm_off
	lda dli_phase
	cmp #2
	beq .nm_seam
	lda $d40b				; a slipped phase still finds the seam line
	cmp #SEAM_VC
	beq .nm_seam
	jmp .nm_rest_off
.nm_seam
	sta $d40f				; ack
	lda #$21				; narrow playfield, no players
	sta $d40a				; WSYNC
	sta $d400
	lda mouse_en
	beq +
	lda #5					; seam phase 4
	bne ++
+	lda #3					; seam phase 2
++	sta dli_phase
	lda dli_paper
	sta $d016				; COLPF0 paper (pixel 01). COLBK stays black
	lda dli_ink
	sta $d018				; COLPF2 ink (pixel 11), same hue, bright
dli_blood
	lda #$46				; COLPF1 blood (pixel %10). PAL init rewrites the hue.
	sta $d017
	txa
	pha
	tya
	pha
	jsr mouse_poll
	jsr check_cheats			; second sample, mid-frame
	jmp a8_nmi_out
.nm_slow
	txa
	pha
	tya
	pha
	lda $d40f
	sta $d40f				; ack DLI and VBI
	and #$40
	beq a8_nmi_out
	jsr a8_vbi				; (a DLI never coincides with the VBI)
a8_nmi_out
	pla
	tay
	pla
	tax
	pla
	rti

.nm_rest_on
	lda dli_phase
	cmp #1
	beq .nm_stat
	cmp #3
	beq .nm_msg
	bne .nm_samp
.nm_rest_off
	lda dli_phase
	beq .nm_stat				; phase 0
	cmp #1
	beq .nm_msg
.nm_samp
	; Mouse sample only (top blank, nail row, bitmap). Top and nail exist with the mouse on.
	inc dli_phase
	sta $d40f				; ack
	txa
	pha
	jsr mouse_poll_go
	pla
	tax
	pla
	rti
.nm_stat
	inc dli_phase
	sta $d40f
	lda #HUD_PF2_STAT
	sta $d40a				; WSYNC: gap under the map, then the stat rows
	sta $d018
	lda #HUD_PF1_STAT
	sta $d017
	txa
	pha
	jsr mouse_poll
	pla
	tax
	pla
	rti
.nm_msg
	inc dli_phase
	sta $d40f
	lda #HUD_PF2_STAT
	sta $d40a
	sta $d018
	lda #HUD_PF1_MSG
	sta $d017
	txa
	pha
	jsr mouse_poll
	pla
	tax
	pla
	rti

; Port 2 ST mouse, X pair only. A,X clobbered (Y untouched). Called from
; the DLI. mouse_x is the previous raw pin state (active low, no eor).
; Table is negated: mouse-right subtracts from yaw. $80 = both bits
; flipped: two steps of the last direction.
mouse_poll
	lda mouse_en
	beq .mp_rts
mouse_poll_go
	lda $d300
	lsr
	lsr
	lsr
	lsr
	and #$03
	asl
	asl
	ora mouse_x				; (new << 2) | old
	tax
	lsr
	lsr
	sta mouse_x				; new state
	lda quad_dx,x
	beq .mp_none
	cmp #$80
	beq .mp_pair
	; Single step s=±1. mouse_f != 0 is fast mode (a 2-step sample was
	; seen within the last MOUSE_FAST samples). There the direction is
	; locked to mouse_v: s along it is +1, s against it is a 3-step
	; alias (3 forward reads as 1 back) and counts 3 along it.
	ldx mouse_f
	beq .mp_slow
	ldx #MOUSE_FAST
	stx mouse_f
	cmp mouse_v
	beq .mp_acc
	lda mouse_v				; mouse_v is ±1: 3 * v
	asl
	clc
	adc mouse_v
	bne .mp_acc
.mp_pair
	ldx #MOUSE_FAST				; two steps: enter or stay in fast mode
	stx mouse_f
	lda mouse_v				; ... in the direction of last motion
	beq .mp_rts
	asl					; 2 * v
	bne .mp_acc
.mp_slow
	sta mouse_v				; slow: direction follows each step
.mp_acc
	ldx #0
	cmp #$80
	bcc .mp_ext
	dex					; high byte of a negative step
.mp_ext
	clc
	adc mouse_turn
	sta mouse_turn
	txa
	adc mouse_turn_h
	sta mouse_turn_h
.mp_rts
	rts
.mp_none
	lda mouse_f				; no transition: fast mode times out
	beq .mp_rts
	dec mouse_f
	rts

; Index (new << 2) | old, raw pin states.
quad_dx	!byte 0, 1, $ff, $80
	!byte $ff, 0, $80, 1
	!byte 1, $80, 0, $ff
	!byte $80, $ff, 1, 0

a8_vbi
	lda #0
	sta dli_phase
	jsr mouse_poll				; sample in the vblank gap too
	; SIOV runs the OS immediate VBI, which copies the page-2 shadows
	; (SDLSTL/SDMCTL/CHBAS/GPRIOR) into the hardware. The enemy load
	; installs the boot snapshot there, so the pointer comes back as the
	; OS list and the viewport stays blank after the room streams in.
	lda #<dl_top
	sta $d402
	lda #>dl_top
	sta $d403
	lda #$f8
	sta $d409				; CHBASE
	lda #0
	sta $d401				; CHACTL
	sta $d01b				; PRIOR
	lda hurt_flash_l
	ora hurt_flash_h
	beq .nb
hurt_col
	lda #COL_HURT_A8			; PAL init rewrites the hue
	sta $d01a				; COLBK
	bne .pp
.nb
	sta $d01a				; A = 0
	lda col_bg
.pp
	sta dli_paper				; seam DLI colours, precomputed so the
						; handler does nothing before WSYNC
	and #$f0
	ora #$0e
	sta dli_ink
	lda #HUD_PF2_TOP			; orange hue, lum 0: title and map
	sta $d018
	lda #HUD_PF1_TOP
	sta $d017
	lda #$22				; normal 40-col width, no players
	ldx den_arm				; 1 = hold DMA off until main publishes
	dex					; a frame (LoadLevel, quickload)
	bne +
	txa
+
	sta $d400				; 0 also stops the DL, so no seam DLI either
	inc frame_flag
	inc vbi_count_l
	bne +
	inc vbi_count_h
+
	; Only writer of the bitmap LMS. show_buf is one byte, so a publish
	; cannot tear into the other buffer for a single video frame.
	lda show_buf
	bne .lms_b
	lda #>BMP_A
	bne .lms_w
.lms_b
	lda #>BMP_B
.lms_w
	sta DL_LMS+1
	lda #<BMP_A
	sta DL_LMS
	jsr a8_stick
	jsr a8_keys
	jsr check_cheats
	jsr flush_sfx
	jsr update_sfx
	jmp a8_noise

a8_stick
	lda pot_prev
	cmp #$20
	lda #0
	rol
	eor #1					; pot < $20 → A=1 strafe
	sta stick_bits
	lda $d200
	sta pot_prev
	sta $d20b
	lda stick_bits
	and #1
	pha					; strafe flag
	lda $d300
	eor #$ff
	and #$0f
	sta stick_bits
	and #1
	beq .nup
	ldy #0
	jsr irq_add_ms
.nup
	lda stick_bits
	and #2
	beq .ndn
	ldy #2
	jsr irq_add_ms
.ndn
	pla
	ora mouse_en				; mouse on: left/right always strafe
	bne .strafe
	lda stick_bits
	and #4
	beq .nl
	ldy #8
	jsr irq_add_ms
.nl
	lda stick_bits
	and #8
	beq .fire
	ldy #10
	jsr irq_add_ms
	jmp .fire
.strafe
	lda stick_bits
	and #4
	beq .nsl
	ldy #4
	jsr irq_add_ms
.nsl
	lda stick_bits
	and #8
	beq .fire
	ldy #6
	jsr irq_add_ms
.fire
	lda $d010
	beq .shot
	lda mouse_en
	beq .nof
	lda $d011				; port 2 left button
	bne .nof
.shot
	lda #1
	sta in_fire
.nof
	rts

a8_keys
	lda $d20f
	and #$04
	bne .nku
	lda $d209
	and #$3f
	cmp #$1f				; 1 axe
	bne .k2
	lda #1
	sta in_wpn_axe
	rts
.k2
	cmp #$1e				; 2 shotgun
	bne .k3
	lda #1
	sta in_wpn_shot
	rts
.k3
	cmp #$1a				; 3 nail
	bne .k4
	lda #1
	sta in_wpn_nail
	rts
.k4
	cmp #$18				; 4 grenade
	bne .ks
	lda #1
	sta in_wpn_gren
	rts
.ks
	ldx #0					; Shift-S quicksave, Shift-L quickload.
	cmp #$3e				; One latch per press: qk_held.
	beq .kq
	inx
	cmp #$00
	bne .nk
.kq
	lda $d20f
	and #$08				; SKSTAT bit 3 clear = shift down
	bne .nk
	lda qk_held
	bne .nk
	lda #1
	sta qk_held
	sta in_qsave,x
	rts
.nku
	lda #0
	sta qk_held
.nk
	rts

; World channel: elevator rumble or Shambler/Chthon crackle when idle.
a8_noise
	lda sfx_index+2
	bpl .rts
	lda ch_bolt_l
	ora ch_bolt_h
	ora sham_arc
	beq .elev
	jsr rnd8
	and #$3f
	clc
	adc #$20
	sta $d204				; AUDF3
	lda effects_vol
	and #$0f
	ora #$80				; noise
	sta $d205
	rts
.elev
	lda elev_noise_n
	beq .off
	lda #$30
	sta $d204
	lda effects_vol
	and #$0f
	ora #$80
	sta $d205
	rts
.off
	lda #0
	sta $d205
.rts
	rts

; Y = 0,2,4,… offset from in_fwd; add sample_ms, saturate at 65535.
irq_add_ms
	clc
	lda in_fwd,y
	adc sample_ms
	sta in_fwd,y
	lda in_fwd+1,y
	adc #0
	sta in_fwd+1,y
	bcc .iam_ok
	lda #$ff
	sta in_fwd,y
	sta in_fwd+1,y
.iam_ok
	rts

; Snapshot then build turn + wish from hold_*.
read_input
	jsr snapshot_input
	lda #0
	sta wish_dx
	sta wish_dxh
	sta wish_dz
	sta wish_dzh

	lda hold_turn_r + 1
	cmp hold_turn_l + 1
	bne .tcmp
	lda hold_turn_r
	cmp hold_turn_l
.tcmp
	beq .tnone
	bcs .tright
	sec
	lda hold_turn_l
	sbc hold_turn_r
	sta vel_ms
	lda hold_turn_l + 1
	sbc hold_turn_r + 1
	sta vel_msh
	jsr turn_deliver
	eor #$ff
	clc
	adc #1
	clc
	adc yaw
	sta yaw
	jmp .tnone
.tright
	sec
	lda hold_turn_r
	sbc hold_turn_l
	sta vel_ms
	lda hold_turn_r + 1
	sbc hold_turn_l + 1
	sta vel_msh
	jsr turn_deliver
	clc
	adc yaw
	sta yaw
.tnone
	lda mouse_en
	bne .m_go
	rts
.m_go
	; ticks = sum / 2 (remainder carried), clamped to dt/8 (2x stick).
	lda dt_msh				; dt >= 2048 ms wraps: one tiny-limit frame
	asl
	asl
	asl
	asl
	asl
	sta mouse_lim
	lda dt_ms
	lsr
	lsr
	lsr
	ora mouse_lim
	bne .m_lset
	lda #1					; never a zero limit
.m_lset
	sta mouse_lim
	; mouse_turn is free-running and only the DLI writes it. Read a consistent
	; pair (hi, lo, hi again) and keep our own base: masking NMIEN here could
	; swallow a DLI and slip dli_phase off the seam.
.m_rd
	lda mouse_turn_h
	sta m_snap_h
	lda mouse_turn
	sta m_snap
	lda mouse_turn_h
	cmp m_snap_h
	bne .m_rd
	sta m_end_h
	lda m_snap
	sta m_end
	sec					; delta = sum - base
	sbc m_base
	sta m_snap
	lda m_snap_h
	sbc m_base_h
	sta m_snap_h
	lda m_snap
	and #1
	sta mouse_rem
	lda m_snap_h				; arithmetic >> 1
	cmp #$80
	ror m_snap_h
	ror m_snap
	lda m_snap_h
	bmi .m_neg
	bne .m_pclamp
	lda m_snap
	cmp mouse_lim
	bcc .m_apply				; below the limit: A = ticks
.m_pclamp
	lda #0
	sta mouse_rem				; clamped: drop the excess, no wind-up
	lda mouse_lim
	bne .m_apply
.m_neg
	lda mouse_lim				; mouse_lim = -limit from here on
	eor #$ff
	clc
	adc #1
	sta mouse_lim
	lda m_snap_h
	cmp #$ff
	bne .m_nclamp
	lda m_snap
	cmp mouse_lim
	bcs .m_apply				; ticks >= -limit: A = ticks
.m_nclamp
	lda #0
	sta mouse_rem
	lda mouse_lim
.m_apply
	clc
	adc yaw
	sta yaw
	sec					; base = sum - remainder (clamped: remainder is 0)
	lda m_end
	sbc mouse_rem
	sta m_base
	lda m_end_h
	sbc #0
	sta m_base_h
	rts

snapshot_input
	ldx #0
.si_ms
	lda in_fwd,x
	sta hold_fwd,x
	lda in_fwd+1,x
	sta hold_fwd+1,x
	lda #0
	sta in_fwd,x
	sta in_fwd+1,x
	inx
	inx
	cpx #12
	bcc .si_ms
	ldx #3
-
	lda in_wpn_axe,x
	sta key_wpn_axe,x
	lda #0
	sta in_wpn_axe,x
	dex
	bpl -
	lda in_fire
	sta key_fire
	lda #0
	sta in_fire
	rts

turn_deliver
	lda vel_ms
	sta pp_tmp_l
	lda vel_msh
	sta pp_tmp_h
	lda #0
	sta hud_n
	ldx #6
.tdsh
	asl pp_tmp_l
	rol pp_tmp_h
	rol hud_n
	dex
	bne .tdsh
	clc
	lda turn_acc_l
	adc pp_tmp_l
	sta turn_acc_l
	lda turn_acc_h
	adc pp_tmp_h
	sta pp_tmp_h
	lda hud_n
	adc #0
	sta hud_n
	lda pp_tmp_h
	and #3
	sta turn_acc_h
	lda pp_tmp_h
	lsr
	lsr
	sta pp_tmp_l
	lda hud_n
	asl
	asl
	asl
	asl
	asl
	asl
	ora pp_tmp_l
	ldx hud_n
	cpx #4
	bcc +
	lda #255
+
	rts
