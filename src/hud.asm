; 40-col HUD — Quake 8×8 font in UI charset $F800 (ASCII screen codes)
; Single-buffered in matrix A. Raster HUD / flyback always D018_A_UI; the
; viewport still flips A/B. Colour RAM is shared.
!zone hud

init_hud
	; Seven stored rows, 280 bytes. Not sta $0200,x — hi $02 is the
	; map reloc sentinel. The tail is $0300.
	lda #<HUD_SCR
	sta init_ptr
	lda #>HUD_SCR
	sta init_ptr+1
	lda #HUD_CH_SP
	ldy #0
-	sta (init_ptr),y
	iny
	bne -
	ldx #0
-	sta HUD_SCR + 256,x
	inx
	cpx #24					; 256 + 24 = 7 * 40
	bne -

	ldx #0

	lda #<HUD_SCR + HUD_OFF_TITLE + HUD_TITLE_COL
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_TITLE + HUD_TITLE_COL
	sta init_ptr+1

-	lda hud_str_title,x
	beq +

	jsr hud_stax

	lda #COL_HUD_DIM

	inx
	bne -
+
	ldy #0
-	+lda_my map_name
	beq +
	iny
	cpy #HUD_MSG_W
	bcc -
+	sty hud_n
	lda #HUD_MSG_W
	sec
	sbc hud_n
	lsr
	tax
	ldy #0

	lda #<HUD_SCR + HUD_OFF_MAP
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_MAP
	sta init_ptr+1

.imap
	+lda_my map_name
	beq .imap_done

	jsr hud_stax

	lda #COL_HUD_DIM

	inx
	iny
	cpy #HUD_MSG_W
	bcc .imap
.imap_done

	lda #HUD_CH_SHELL
	sta HUD_SCR + HUD_OFF_SHELL + HUD_AMMO_ICON
	lda #HUD_CH_NAIL
	sta HUD_SCR + HUD_OFF_NAIL + HUD_AMMO_ICON
	lda #HUD_CH_GREN
	sta HUD_SCR + HUD_OFF_GREN + HUD_AMMO_ICON
	lda #COL_HUD_DIM


	ldx #0

	lda #<HUD_SCR + HUD_OFF_SHELL + HUD_HP_LABEL
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_SHELL + HUD_HP_LABEL
	sta init_ptr+1

-	lda hud_str_health,x
	beq +

	jsr hud_stax

	lda #COL_HUD_DIM

	inx
	bne -
+
	ldx #0

	lda #<HUD_SCR + HUD_OFF_SHELL + HUD_AR_LABEL
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_SHELL + HUD_AR_LABEL
	sta init_ptr+1

-	lda hud_str_armour,x
	beq +

	jsr hud_stax

	lda #COL_HUD_DIM

	inx
	bne -
+


!if  PROFILE = 1 {
	lda #HUD_CH_R
	sta HUD_SCR + HUD_OFF + 4
	lda #HUD_CH_P
	sta HUD_SCR + HUD_OFF + 9
	lda #HUD_CH_K
	sta HUD_SCR + HUD_OFF + 14
	lda #HUD_CH_D
	sta HUD_SCR + HUD_OFF + 19
	lda #HUD_CH_C
	sta HUD_SCR + HUD_OFF + 24
	lda #HUD_CH_U
	sta HUD_SCR + HUD_OFF + 29
	lda #COL_HUD_DIM


	lda #HUD_CH_R
	sta HUD_SCR + HUD_OFF_MAP
	lda #HUD_CH_P
	sta HUD_SCR + HUD_OFF_MAP + 4
	lda #HUD_CH_K
	sta HUD_SCR + HUD_OFF_MAP + 8
	lda #COL_HUD_DIM


}

!if  HUD_POS = 1 {
	lda #HUD_CH_X
	sta HUD_SCR + HUD_OFF2
	lda #HUD_CH_Y
	sta HUD_SCR + HUD_OFF2 + 5
	lda #HUD_CH_Z
	sta HUD_SCR + HUD_OFF2 + 10
	lda #HUD_CH_H
	sta HUD_SCR + HUD_OFF2 + 15
	lda #HUD_CH_P
	sta HUD_SCR + HUD_OFF2 + 19
	lda #COL_HUD_DIM


}
	jmp hud_powerup

; X = column, A = char. init_ptr = row base. Saves Y. Not abs,x (map sentinel).

hud_stax
	sta hud_ch
	tya
	pha
	txa
	tay
	lda hud_ch
	sta (init_ptr),y
	pla
	tay
	lda hud_ch
	rts
hud_ch	!byte 0


; Row 0: R/P/K/D/C/U milliseconds. D is unused (lines are inside K).
; C is clear. U is everything after the last clip.
; Map line: R/P/K vertex and edge counts.
hud_print
!if  HUD_FRAME_MS = 1 {
	ldx #0
	lda dt_msh
	ldy dt_ms
	jsr .dec3
}
!if  PROFILE = 1 {
	ldx #5
	lda prof_cy + PROF_ROT * 4 + 2
	ldy prof_cy + PROF_ROT * 4 + 1
	jsr .ms4
	ldx #10
	lda prof_cy + PROF_PROJ * 4 + 2
	ldy prof_cy + PROF_PROJ * 4 + 1
	jsr .ms4
	ldx #15
	lda prof_cy + PROF_CLIP * 4 + 2
	ldy prof_cy + PROF_CLIP * 4 + 1
	jsr .ms4
	ldx #20
	lda prof_cy + PROF_DRAW * 4 + 2
	ldy prof_cy + PROF_DRAW * 4 + 1
	jsr .ms4
	ldx #25
	lda prof_cy + PROF_CLEAR * 4 + 2
	ldy prof_cy + PROF_CLEAR * 4 + 1
	jsr .ms4
	ldx #30
	lda prof_cy + PROF_UPDATE * 4 + 2
	ldy prof_cy + PROF_UPDATE * 4 + 1
	jsr .ms4

	ldx #1
	lda nv_rot + 1
	ldy nv_rot
	jsr .dec3n
	ldx #5
	lda nv_proj + 1
	ldy nv_proj
	jsr .dec3n
	ldx #9
	lda nv_clip + 1
	ldy nv_clip
	jsr .dec3n
}
!if  HUD_POS = 1 {
	ldx #1
	lda cam_xh
	jsr .s8_3
	ldx #6
	lda cam_yh
	jsr .s8_3
	ldx #11
	lda cam_zh
	jsr .s8_3
	ldx #16
	lda yaw
	jsr .u8_3
	ldx #20
	lda pitch
	jsr .s8_3
}
	rts

; Ammo + health + armour. Call on init, spend, backpack, damage — not every frame.
hud_ammo
	lda #<HUD_SCR + HUD_OFF_SHELL
	sta dst_ptr
	lda #>HUD_SCR + HUD_OFF_SHELL
	sta dst_ptr+1
	ldx #HUD_AMMO_NUM
	lda ammo_shells
	jsr .u8_3at
	lda #<HUD_SCR + HUD_OFF_NAIL
	sta dst_ptr
	lda #>HUD_SCR + HUD_OFF_NAIL
	sta dst_ptr+1
	ldx #HUD_AMMO_NUM
	lda ammo_nails
	jsr .u8_3at
	lda #<HUD_SCR + HUD_OFF_GREN
	sta dst_ptr
	lda #>HUD_SCR + HUD_OFF_GREN
	sta dst_ptr+1
	ldx #HUD_AMMO_NUM
	lda ammo_grenades
	jsr .u8_3at
	ldx #HUD_HP_NUM
	lda player_hp
	jsr .u8_3at
	ldx #HUD_AR_NUM
	lda player_armour
	; fall through

; A unsigned -> 3 digits at (dst_ptr)+X, matrix A
.u8_3at
	stx pp_col
	sta pp_tmp_l
	ldx #0
.uh3h
	lda pp_tmp_l
	cmp #100
	bcc .uh3t
	sbc #100
	sta pp_tmp_l
	inx
	bne .uh3h
.uh3t
	stx hud_n
	ldy #0
.uh3tl
	lda pp_tmp_l
	cmp #10
	bcc .uh3o
	sbc #10
	sta pp_tmp_l
	iny
	bne .uh3tl
.uh3o
	tya
	ora #$30
	sta pp_tmp_h
	lda hud_n
	ora #$30
	ldy pp_col
	sta (dst_ptr),y
	iny
	lda pp_tmp_h
	sta (dst_ptr),y
	iny
	lda pp_tmp_l
	ora #$30
	sta (dst_ptr),y
	rts

!if  HUD_POS = 1 {
; A signed → sign + 3 digits at HUD_OFF2+X (horizon pitch = 0)
.s8_3
	stx pp_col
	cmp #0
	bpl .spos
	ldx pp_col
	pha
	lda #HUD_CH_MINUS
	sta HUD_SCR + HUD_OFF2,x
	pla
	eor #$ff
	clc
	adc #1
	inx
	stx pp_col
	jmp .u8_3
.spos
	ldx pp_col
	pha
	lda #HUD_CH_PLUS
	sta HUD_SCR + HUD_OFF2,x
	pla
	inx
	stx pp_col
	jmp .u8_3
}

; A unsigned 0–255 → 3 ASCII digits at HUD_OFF2+X (also pp_col)
.u8_3
	stx pp_col
	sta pp_tmp_l
	ldx #0
.uhund
	lda pp_tmp_l
	cmp #100
	bcc .utens
	sbc #100
	sta pp_tmp_l
	inx
	bne .uhund
.utens
	ldy #0
.utenlp
	lda pp_tmp_l
	cmp #10
	bcc .uones
	sbc #10
	sta pp_tmp_l
	iny
	bne .utenlp
.uones
	txa
	ora #$30
	ldx pp_col
	sta HUD_SCR + HUD_OFF2,x
	inx
	tya
	ora #$30
	sta HUD_SCR + HUD_OFF2,x
	inx
	lda pp_tmp_l
	ora #$30
	sta HUD_SCR + HUD_OFF2,x
	rts

!if  PROFILE = 1 {
; A:Y = cy[2]:cy[1] → ms (>>2) then 4 digits at HUD_OFF+X
.ms4
	sta pp_tmp_h
	sty pp_tmp_l
	lsr pp_tmp_h
	ror pp_tmp_l
	lsr pp_tmp_h
	ror pp_tmp_l
	lda pp_tmp_h
	ldy pp_tmp_l
	; fall through

; A:Y = 16-bit → 4 ASCII digits at HUD_OFF+X; saturate 9999
.dec4
	stx pp_col
	sta pp_tmp_h
	sty pp_tmp_l
	cmp #>10000
	bcc .d4go
	bne .d4sat
	cpy #<10000
	bcc .d4go
.d4sat
	lda #$39
	sta hud_n
	sta pp_tmp_h
	sta pp_tmp_l
	ldy #$39
	jmp .d4out
.d4go
	ldx #0
.d4thou
	lda pp_tmp_h
	cmp #>1000
	bcc .d4hund
	bne .d4tsub
	lda pp_tmp_l
	cmp #<1000
	bcc .d4hund
.d4tsub
	sec
	lda pp_tmp_l
	sbc #<1000
	sta pp_tmp_l
	lda pp_tmp_h
	sbc #>1000
	sta pp_tmp_h
	inx
	bne .d4thou
.d4hund
	stx hud_n			; thousands 0–9
	ldx #0
.d4hlp
	lda pp_tmp_h
	bne .d4hsub
	lda pp_tmp_l
	cmp #100
	bcc .d4tens
.d4hsub
	sec
	lda pp_tmp_l
	sbc #100
	sta pp_tmp_l
	lda pp_tmp_h
	sbc #0
	sta pp_tmp_h
	inx
	bne .d4hlp
.d4tens
	ldy #0
.d4tlp
	lda pp_tmp_l
	cmp #10
	bcc .d4ones
	sbc #10
	sta pp_tmp_l
	iny
	bne .d4tlp
.d4ones
	txa
	ora #$30
	sta pp_tmp_h			; hundreds ASCII
	tya
	ora #$30
	tay				; tens ASCII
	lda hud_n
	ora #$30
	sta hud_n			; thousands ASCII
	lda pp_tmp_l
	ora #$30
	sta pp_tmp_l			; ones ASCII
.d4out
	ldx pp_col

	lda #<HUD_SCR + HUD_OFF
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF
	sta init_ptr+1
	lda hud_n
	jsr hud_stax
	inx
	lda pp_tmp_h
	jsr hud_stax
	inx
	tya
	jsr hud_stax
	inx
	lda pp_tmp_l
	jmp hud_stax

}

; A:Y = 16-bit → 3 ASCII digits; saturate 999. .dec3 → HUD_OFF, .dec3n → map line
!if  HUD_FRAME_MS = 1 {
.dec3
	stx pp_col
	jsr .d3conv

	lda #<HUD_SCR + HUD_OFF
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF
	sta init_ptr+1
	ldx pp_col
	lda hud_n
	jsr hud_stax
	inx
	lda pp_tmp_h
	jsr hud_stax
	inx
	lda pp_tmp_l
	jmp hud_stax

}
!if  PROFILE = 1 {
.dec3n
	stx pp_col
	jsr .d3conv
	ldx pp_col

	lda #<HUD_SCR + HUD_OFF3
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF3
	sta init_ptr+1
	lda hud_n
	jsr hud_stax
	inx
	lda pp_tmp_h
	jsr hud_stax
	inx
	lda pp_tmp_l
	jmp hud_stax

}
!if  HUD_FRAME_MS + PROFILE > 0 {
.d3conv
	sta pp_tmp_h
	sty pp_tmp_l
	cmp #>1000
	bcc .d3go
	bne .d3sat
	cpy #<1000
	bcc .d3go
.d3sat
	lda #$39
	sta hud_n
	sta pp_tmp_h
	sta pp_tmp_l
	rts
.d3go
	ldx #0
.d3hlp
	lda pp_tmp_h
	bne .d3hsub
	lda pp_tmp_l
	cmp #100
	bcc .d3tens
.d3hsub
	sec
	lda pp_tmp_l
	sbc #100
	sta pp_tmp_l
	lda pp_tmp_h
	sbc #0
	sta pp_tmp_h
	inx
	bne .d3hlp
.d3tens
	stx hud_n
	ldy #0
.d3tlp
	lda pp_tmp_l
	cmp #10
	bcc .d3ones
	sbc #10
	sta pp_tmp_l
	iny
	bne .d3tlp
.d3ones
	lda hud_n
	ora #$30
	sta hud_n
	tya
	ora #$30
	sta pp_tmp_h
	lda pp_tmp_l
	ora #$30
	sta pp_tmp_l
	rts
}

; Message trigger on HUD_ROW4, centered. Call on enter/leave only.
hud_message
	lda #0
	sta status_ms_l
	sta status_ms_h
	lda msg_on
	bne .hm_show
	jmp hud_msg_blank
.hm_show
	jsr hud_msg_blank
	clc
	lda	map_text
	adc msg_off
	sta src_ptr
	lda	map_text+1
	adc #0
	sta src_ptr+1
	jmp hud_msg_center

hud_msg_blank
	ldx #0
	lda #HUD_CH_SP
.hmb
	sta HUD_SCR + HUD_OFF4,x
	inx
	cpx #HUD_MSG_W
	bne .hmb
	rts

; src_ptr → NUL string, already blanked, centered on HUD_OFF4
hud_msg_center
	ldy #0
.hm_len
	lda (src_ptr),y
	beq .hm_got
	iny
	cpy #HUD_MSG_W
	bcc .hm_len
.hm_got
	sty hud_n			; length
	lda #HUD_MSG_W
	sec
	sbc hud_n
	lsr
	tax				; dest col = (W - len) / 2
	ldy #0
.hm_cp
	lda (src_ptr),y
	beq .hm_done
	sta HUD_SCR + HUD_OFF4,x
	inx
	iny
	cpy #HUD_MSG_W
	bcc .hm_cp
.hm_done
	rts

; Name at HUD_OFF_GREN + HUD_PU_LABEL (row below 2×2 icon on SHELL/NAIL).
hud_powerup
	lda pu_kind
	cmp #BP_QUAD
	beq .hpu_quad
	cmp #BP_PENT
	beq .hpu_pent
	cmp #BP_RING
	beq .hpu_ring
	lda #HUD_CH_SP
	ldx #5

	lda #<HUD_SCR + HUD_OFF_GREN + HUD_PU_LABEL
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_GREN + HUD_PU_LABEL
	sta init_ptr+1
	lda #HUD_CH_SP

.hpu_clab

	jsr hud_stax

	dex
	bpl .hpu_clab
	sta HUD_SCR + HUD_OFF_SHELL + HUD_PU_COL
	sta HUD_SCR + HUD_OFF_SHELL + HUD_PU_COL + 1
	sta HUD_SCR + HUD_OFF_NAIL + HUD_PU_COL
	sta HUD_SCR + HUD_OFF_NAIL + HUD_PU_COL + 1
	rts
.hpu_quad
	ldx #0
	lda #HUD_CH_QUAD
	jmp .hpu_draw
.hpu_pent
	ldx #hud_str_shield - hud_str_damage
	lda #HUD_CH_PENT
	jmp .hpu_draw
.hpu_ring
	ldx #hud_str_shadow - hud_str_damage
	lda #HUD_CH_RING
.hpu_draw
	sta HUD_SCR + HUD_OFF_SHELL + HUD_PU_COL
	clc
	adc #1
	sta HUD_SCR + HUD_OFF_SHELL + HUD_PU_COL + 1
	adc #1
	sta HUD_SCR + HUD_OFF_NAIL + HUD_PU_COL
	adc #1
	sta HUD_SCR + HUD_OFF_NAIL + HUD_PU_COL + 1
	ldy #0

	lda #<HUD_SCR + HUD_OFF_GREN + HUD_PU_LABEL
	sta init_ptr
	lda #>HUD_SCR + HUD_OFF_GREN + HUD_PU_LABEL
	sta init_ptr+1

.hpu_lab
	lda hud_str_damage,x

	sta (init_ptr),y

	inx
	iny
	cpy #6
	bne .hpu_lab
	rts

; A = BP_* type. "Got the <name>" for 5s on HUD_ROW4.
; Quad/pent/ring: name only (no prefix).
hud_got
	cmp #BP_NTYPES
	bcc .hg_ok
	rts
.hg_ok
	sta rot2
	tay
	lda bp_name_lo,y
	sta src_ptr
	lda bp_name_hi,y
	sta src_ptr+1
	jsr hud_msg_blank
	lda rot2
	cmp #BP_QUAD
	bcc .hg_got
	cmp #BP_SILVER
	bcc .hg_nameonly
.hg_got
	ldy #0
.hg_nl
	lda (src_ptr),y
	beq .hg_nlen
	iny
	cpy #HUD_MSG_W
	bcc .hg_nl
.hg_nlen
	tya
	clc
	adc #HUD_GOT_LEN
	sta hud_n
	lda #HUD_MSG_W
	sec
	sbc hud_n
	lsr
	tax
	ldy #0
.hg_pre
	lda hud_str_got,y
	beq .hg_name
	sta HUD_SCR + HUD_OFF4,x
	inx
	iny
	bne .hg_pre
.hg_name
	ldy #0
.hg_cp
	lda (src_ptr),y
	beq .hg_arm
	sta HUD_SCR + HUD_OFF4,x
	inx
	iny
	bne .hg_cp
.hg_arm
	lda #<STATUS_MS
	sta status_ms_l
	lda #>STATUS_MS
	sta status_ms_h
	rts
.hg_nameonly
	jsr hud_msg_center
	jmp .hg_arm

; A = DOOR_KEY_SILVER / DOOR_KEY_GOLD / DOOR_KEY_REMOTE. HUD_ROW4, STATUS_MS.
hud_key_req
	cmp #DOOR_KEY_REMOTE
	beq .hkr_remote
	cmp #DOOR_KEY_GOLD
	beq .hkr_gold
	lda #<hud_str_silver_req
	sta src_ptr
	lda #>hud_str_silver_req
	sta src_ptr+1
	jmp .hkr_show
.hkr_gold
	lda #<hud_str_gold_req
	sta src_ptr
	lda #>hud_str_gold_req
	sta src_ptr+1
	jmp .hkr_show
.hkr_remote
	lda #<hud_str_remote_req
	sta src_ptr
	lda #>hud_str_remote_req
	sta src_ptr+1
.hkr_show
	jsr hud_msg_blank
	jsr hud_msg_center
	lda #<STATUS_MS
	sta status_ms_l
	lda #>STATUS_MS
	sta status_ms_h
	rts

; Tick status line; blank and clear msg_on when the timer expires.
update_status
	lda status_ms_l
	ora status_ms_h
	beq .us_rts
	sec
	lda status_ms_l
	sbc dt_ms
	sta status_ms_l
	lda status_ms_h
	sbc dt_msh
	sta status_ms_h
	bcs .us_rts
	lda #0
	sta status_ms_l
	sta status_ms_h
	sta msg_on
	jmp hud_msg_blank
.us_rts
	rts

HUD_GOT_LEN	= 8			; "Got the "
hud_str_got	!text "Got the ",0
hud_str_silver_req	!text "Silver key required",0
hud_str_gold_req	!text "Gold key required",0
hud_str_remote_req	!text "This door is opened elsewhere",0
bpn_shells	!text "shells",0
bpn_nailgun	!text "nailgun",0
bpn_nails	!text "nails",0
bpn_gl		!text "grenade launcher",0
bpn_grenades	!text "grenades",0
bpn_health	!text "health",0
bpn_armour	!text "armour",0
bpn_quad	!text "quad damage",0
bpn_pent	!text "pentagram of protection",0
bpn_ring	!text "ring of shadows",0
bpn_silver	!text "silver key",0
bpn_gold	!text "gold key",0
bpn_rune	!text "rune of earth magic",0
bp_name_lo
	!byte <bpn_shells, <bpn_nailgun, <bpn_nails, <bpn_gl
	!byte <bpn_grenades, <bpn_health, <bpn_health, <bpn_shells, <bpn_armour
	!byte <bpn_quad, <bpn_pent, <bpn_ring, <bpn_silver, <bpn_gold, <bpn_rune
bp_name_hi
	!byte >bpn_shells, >bpn_nailgun, >bpn_nails, >bpn_gl
	!byte >bpn_grenades, >bpn_health, >bpn_health, >bpn_shells, >bpn_armour
	!byte >bpn_quad, >bpn_pent, >bpn_ring, >bpn_silver, >bpn_gold, >bpn_rune

; ASCII (UI charset), not PETSCII
hud_str_title	!text "QuakeA8",0
hud_str_health	!text "health",0
hud_str_armour	!text "armour",0
hud_str_damage	!text "Damage",0
hud_str_shield	!text "Shield",0
hud_str_shadow	!text "Shadow",0
