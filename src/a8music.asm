; Menu music (Atari). Decodes the stream tools/genpokey.py writes into
; menu_music_data.asm and drives POKEY from the menu VBI (a8_music_tick).
; ch1+2 joined 16-bit @1.79 MHz (AUDCTL bit 4+6), ch3 / ch4 8-bit.
;
; Stream: LZ tokens into a 4 KB ring, giving mask + changed-column bytes per
; SID tick (format in tools/genpokey.py). A phase accumulator steps the stream
; at the tune's own tick rate on any VBI rate. Each channel runs a per-VBI
; SID-ish envelope from its (AD, SR) pair; the data carries no volumes.
;
; Runs inside the NMI: no ZP, no X/Y survive (a8_nmi saves them). All state is
; address-only BSS below the ring. The menu must end below MUS_BSS.

!zone a8music

MUS_RING	= $7000			; 4 KB, below the A8 bitmap at $8000
MUS_BSS		= $6F00			; one page under the ring, not in the PRG

mus_col		= MUS_BSS		; 7: AUDF1 AUDF2 AUDF3 AUDF4 E_pair E_ch3 E_ch4
mus_ph		= MUS_BSS + 7		; 3: 0 attack, 1 decay / sustain, 2 release
mus_lvl		= MUS_BSS + 10		; 3: envelope 0..255
mus_frac	= MUS_BSS + 13		; 3: step fraction
mus_audc	= MUS_BSS + 16		; 3: AUDC2 / AUDC3 / AUDC4 for this frame
mus_en		= MUS_BSS + 19
mus_ntsc	= MUS_BSS + 20
mus_ac_l	= MUS_BSS + 21		; tick phase accumulator
mus_ac_h	= MUS_BSS + 37
mus_rl		= MUS_BSS + 38		; ticks per VBI, 0.16
mus_rh		= MUS_BSS + 39
mus_spfb	= MUS_BSS + 40		; 0 PAL, 16 NTSC (offset into the SPF table)
mus_mask	= MUS_BSS + 22
mus_flags	= MUS_BSS + 23
mus_mlen	= MUS_BSS + 24
mus_b0		= MUS_BSS + 25
mus_b1		= MUS_BSS + 26
mus_tmp		= MUS_BSS + 27
mus_a0		= MUS_BSS + 28
mus_a1		= MUS_BSS + 29
mus_tgt		= MUS_BSS + 30
mus_m		= MUS_BSS + 31
mus_v		= MUS_BSS + 32
mus_loop_l	= MUS_BSS + 33
mus_loop_h	= MUS_BSS + 34
mus_ad		= MUS_BSS + 35
mus_sr		= MUS_BSS + 36

; Caller holds I=1 (run_menu). POKEY is already zeroed by a8_init_vic.
a8_music_start
	lda #0
	sta mus_en
	lda #<mus_tokens
	sta mus_fetch + 1
	lda #>mus_tokens
	sta mus_fetch + 2
	jsr mus_state
	jsr mus_reset
	lda $d014				; PAL reads $01, NTSC $0F
	and #$0e
	beq .pal
	lda #1
.pal
	sta mus_ntsc
	tay
	lda mus_rate_lo,y
	sta mus_rl
	lda mus_rate_hi,y
	sta mus_rh
	lda #0
	sta mus_ac_l
	lda #$80				; half a VBI of slack either way
	sta mus_ac_h
	lda mus_ntsc
	asl
	asl
	asl
	asl
	sta mus_spfb				; 16 SPF entries per video standard
	jsr set_video_ms
	lda mus_audctl
	sta $d208
	lda #1
	sta mus_en
	rts

; $D014 → video_ms (20 PAL / 17 NTSC), and plant the PAL hue table at
; a8_pal_hue. Menu calls this before the first colour note. GAME loads
; at $0900 and does not touch $06D5. The game copies video_ms in init_irq
; and reads the table from a8_to_pal.
set_video_ms
	lda $d014				; PAL reads $01, NTSC $0F
	and #$0e
	beq .vms_pal
	lda #SAMPLE_MS_NTSC
	bne .vms_st
.vms_pal
	lda #SAMPLE_MS_PAL
.vms_st
	sta video_ms
	ldy #15
-
	lda .vms_hue,y
	sta a8_pal_hue,y
	dey
	bpl -
	rts
; NTSC hue → PAL high nibble (lum 0). Nearest atari800 colour, delay
; 26.8° NTSC / 23.2° PAL, averaged over lum 4..14. Hue 0 stays grey.
.vms_hue
	!byte $00,$d0,$e0,$10,$30,$40,$50,$60
	!byte $70,$70,$90,$a0,$a0,$b0,$d0,$e0

a8_music_stop
	lda #0
	sta mus_en
	ldx #7
.z
	sta $d200,x
	dex
	bpl .z
	sta $d208
	rts

; Column state and envelopes, once at start. LOOPMARK / END keep them: the
; first frame of the body rewrites every column and the SID state is continuous
; across the wrap, so held notes carry on instead of dropping out.
mus_state
	lda #0
	ldx #6
.c
	sta mus_col,x
	dex
	bpl .c
	ldx #2
.p
	lda #0
	sta mus_lvl,x
	sta mus_frac,x
	lda #2
	sta mus_ph,x
	dex
	bpl .p
	rts

; Ring write position and token state back to a stream (re)start.
mus_reset
	lda #0
	sta mus_flags				; next token starts a flag byte
	sta mus_mlen
	sta mus_wr + 1
	lda #>MUS_RING
	sta mus_wr + 2
	rts

; Every VBI. The stream advances one SID tick whenever the 16-bit phase
; accumulator carries (tick rate / VBI rate, PAL or NTSC); envelopes and POKEY
; update on every VBI, so NTSC needs no dropped frames.
a8_music_tick
	lda mus_en
	beq .rts
	clc
	lda mus_ac_l
	adc mus_rl
	sta mus_ac_l
	lda mus_ac_h
	adc mus_rh
	sta mus_ac_h
	bcc .nt
	jsr mus_tick
.nt
	ldx #0
.env
	jsr mus_env
	inx
	cpx #3
	bne .env
	lda mus_col
	sta $d200
	lda mus_col + 1
	sta $d202
	lda mus_col + 2
	sta $d204
	lda mus_col + 3
	sta $d206
	lda #0
	sta $d201				; ch1 is the low half of the pair
	lda mus_audc
	sta $d203
	lda mus_audc + 1
	sta $d205
	lda mus_audc + 2
	sta $d207
.rts
	rts

; One stream tick: mask + changed columns.
mus_tick
	jsr mus_next				; mask (may run a LOOPMARK / END reset)
	sta mus_mask
	ldx #0
.col
	lsr mus_mask
	bcc .skip
	jsr mus_next
	cpx #4
	bcs .ev
	sta mus_col,x
	jmp .skip
.ev
	sta mus_tmp
	and #$7f
	sta mus_col,x
	lda mus_tmp
	bmi .att
	and #$40
	bne .skip				; gate held, no retrigger
	lda #2
	sta mus_ph - 4,x			; gate off: release
	bne .skip
.att
	lda #0
	sta mus_ph - 4,x
.skip
	inx
	cpx #7
	bne .col
	rts

; X = channel. Steps the envelope one frame, leaves AUDC in mus_audc,x.
mus_env
	lda mus_col + 4,x
	and #$0f
	asl
	tay
	lda mus_inst,y
	sta mus_ad
	lda mus_inst + 1,y
	sta mus_sr
	lda mus_ph,x
	beq .atk
	cmp #1
	beq .dec
	lda #0					; release to 0
	sta mus_tgt
	lda mus_sr
	and #$0f
	jsr mus_down
	jmp .out
.dec
	lda mus_sr				; sustain = (sr >> 4) * 17
	and #$f0
	sta mus_tgt
	lsr
	lsr
	lsr
	lsr
	ora mus_tgt
	sta mus_tgt
	lda mus_ad
	and #$0f
	jsr mus_down
	jmp .out
.atk
	lda mus_ad
	lsr
	lsr
	lsr
	lsr
	tay
	jsr mus_spf
	jsr mus_acc
	clc
	adc mus_lvl,x
	bcs .top
	sta mus_lvl,x
	cmp #255
	bne .out
.top
	lda #255
	sta mus_lvl,x
	lda #1
	sta mus_ph,x
.out
	lda mus_lvl,x
	lsr
	lsr
	lsr
	lsr
	sta mus_v
	lda effects_vol
	and #$0f
	cmp #$0f
	beq .vfull
	clc
	adc #1
	sta mus_m
	lda #0
	ldy #4
.ml
	lsr mus_m
	bcc .mn
	clc
	adc mus_v
.mn
	asl mus_v
	dey
	bne .ml
	lsr
	lsr
	lsr
	lsr
	sta mus_v
.vfull
	lda mus_col + 4,x
	lsr
	lsr
	lsr
	lsr
	and #3
	tay
	lda mus_v
	and mus_vmask,y
	ora mus_dist,y
	sta mus_audc,x
	rts

; A = rate 0..15, X = channel, mus_tgt = floor. Decay / release step.
mus_down
	tay
	lda mus_lvl,x
	cmp mus_tgt
	beq .nd
	bcc .nd
	jsr mus_spf
	lda mus_lvl,x
	ldy #0
	cmp #$5e				; exponential segments, as the SID counter
	bcs .sh
	iny
	cmp #$37
	bcs .sh
	iny
	cmp #$1b
	bcs .sh
	iny
	cmp #$0f
	bcs .sh
	iny
	cmp #$07
	bcs .sh
	iny
.sh
	tya
	beq .ns
.sl
	lsr mus_a1
	ror mus_a0
	dey
	bne .sl
.ns
	jsr mus_acc
	sta mus_a1
	lda mus_lvl,x
	sec
	sbc mus_a1
	bcc .tg
	cmp mus_tgt
	bcs .st
.tg
	lda mus_tgt
.st
	sta mus_lvl,x
.nd
	rts

; Y = rate → mus_a1:mus_a0 = steps per frame (8.8). X kept.
mus_spf
	tya
	clc
	adc mus_spfb
	tay
	lda mus_spf_lo,y
	sta mus_a0
	lda mus_spf_hi,y
	sta mus_a1
	rts

; frac[x] += a (16-bit). Returns steps in A (255 on overflow), frac updated.
mus_acc
	clc
	lda mus_a0
	adc mus_frac,x
	sta mus_frac,x
	lda mus_a1
	adc #0
	bcc .a
	lda #$ff
.a
	rts

; Next decoded stream byte in A. Uses no X or Y.
mus_next
	lda mus_mlen
	beq .tok
	dec mus_mlen
.rd
	lda MUS_RING
	inc .rd + 1
	beq .rwrap
	jmp mus_put
.rwrap
	pha
	inc .rd + 2
	lda .rd + 2
	cmp #(>MUS_RING) + $10
	bne .rw
	lda #>MUS_RING
	sta .rd + 2
.rw
	pla
	jmp mus_put
.tok
	lsr mus_flags
	bne .bit
	jsr mus_fetch				; flag byte, sentinel in bit 7
	sec
	ror
	sta mus_flags
.bit
	bcc .match
	jsr mus_fetch				; literal
	jmp mus_put
.match
	jsr mus_fetch
	sta mus_b0
	jsr mus_fetch
	sta mus_b1
	and #$0f
	beq .ctl
	cmp #15
	beq .long
	clc
	adc #2
	jmp .len
.long
	jsr mus_fetch
	clc
	adc #17
.len
	sta mus_mlen
	lda mus_b1				; read pointer = write pointer - distance
	lsr
	lsr
	lsr
	lsr
	sta mus_tmp
	sec
	lda mus_wr + 1
	sbc mus_b0
	sta .rd + 1
	lda mus_wr + 2
	sbc mus_tmp
	cmp #>MUS_RING
	bcs .rp
	adc #$10
.rp
	sta .rd + 2
	jmp mus_next
.ctl
	lda mus_b0
	bne .end
	lda mus_fetch + 1			; LOOPMARK: remember where the body starts
	sta mus_loop_l
	lda mus_fetch + 2
	sta mus_loop_h
	jsr mus_reset
	jmp mus_next
.end
	lda mus_loop_l				; END: back to the body
	sta mus_fetch + 1
	lda mus_loop_h
	sta mus_fetch + 2
	jsr mus_reset
	jmp mus_next

; A = byte → ring at the write pointer; A kept.
mus_put
mus_wr
	sta MUS_RING
	inc mus_wr + 1
	bne .pd
	pha
	inc mus_wr + 2
	lda mus_wr + 2
	cmp #(>MUS_RING) + $10
	bne .pw
	lda #>MUS_RING
	sta mus_wr + 2
.pw
	pla
.pd
	rts

; Next byte of the packed stream.
mus_fetch
	lda $ffff
	inc mus_fetch + 1
	bne .f
	inc mus_fetch + 2
.f
	rts

mus_dist	!byte $a0, $c0, $80, $00	; pure, poly4, noise, silent
mus_vmask	!byte $0f, $0f, $0f, $00

!source "menu_music_data.asm"
